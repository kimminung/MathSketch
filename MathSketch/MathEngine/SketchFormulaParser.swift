import Foundation

/// Parses the PRD FR-5 SketchFormula DSL: `shapeCall (· modifier)* (+ shapeCall (· modifier)*)*`.
/// Colors are never part of this grammar (FR-4/FR-5) — only shape + transform survive the
/// round trip. Reuses MathLexer's token stream and embeds a private copy of the numeric
/// expression grammar (ported from MathParser) so argument values can be `40`, `pi/2`, etc.
nonisolated enum SketchFormulaError: Error, CustomStringConvertible, Equatable {
    case syntax(MathSyntaxError)
    case unknownShape(String, column: Int)
    case unknownModifier(String, column: Int)
    case badModifierArity(String, expected: Int, column: Int)
    case tooManyElements(Int)
    case tooLong(Int)

    var description: String {
        switch self {
        case .syntax(let e): return e.description
        case .unknownShape(let name, let column): return "\(column)열: 알 수 없는 도형 '\(name)'"
        case .unknownModifier(let name, let column): return "\(column)열: 알 수 없는 변형 '\(name)'"
        case .badModifierArity(let name, let expected, let column):
            return "\(column)열: '\(name)'은(는) 인자를 \(expected)개 받습니다"
        case .tooManyElements(let n): return "요소 수가 너무 많습니다(\(n)개, 상한 \(SketchFormulaParser.maxElements)개)"
        case .tooLong(let n): return "수식 문자열이 너무 깁니다(\(n)자, 상한 \(SketchFormulaParser.maxLength)자)"
        }
    }
}

nonisolated struct SketchFormulaParser {
    static let maxElements = 200
    static let maxLength = 20_000

    private let tokens: [MathToken]
    private var position = 0

    private init(tokens: [MathToken]) { self.tokens = tokens }

    static func parse(_ source: String) throws -> [SketchElement] {
        guard source.count <= maxLength else { throw SketchFormulaError.tooLong(source.count) }
        var lexer = MathLexer(source)
        let tokens: [MathToken]
        do {
            tokens = try lexer.tokenize()
        } catch let error as MathSyntaxError {
            throw SketchFormulaError.syntax(error)
        }
        var parser = SketchFormulaParser(tokens: tokens)
        var elements: [SketchElement] = []
        var zIndex = 0
        repeat {
            elements.append(try parser.parseElement(zIndex: zIndex))
            zIndex += 1
            if elements.count > maxElements { throw SketchFormulaError.tooManyElements(elements.count) }
        } while parser.consumePlus()
        try parser.expectEnd()
        return elements
    }

    private var current: MathToken { tokens[position] }

    @discardableResult
    private mutating func advance() -> MathToken {
        let token = tokens[position]
        if position < tokens.count - 1 { position += 1 }
        return token
    }

    private func err(_ message: String) -> SketchFormulaError {
        .syntax(MathSyntaxError(message: message, column: current.column))
    }

    private mutating func consumePlus() -> Bool {
        guard case .plus = current.kind else { return false }
        advance()
        return true
    }

    private func expectEnd() throws {
        guard current.kind == .end else { throw err("식이 끝나지 않았습니다") }
    }

    @discardableResult
    private mutating func expectIdentifier() throws -> (name: String, column: Int) {
        guard case .identifier(let name) = current.kind else { throw err("식별자가 필요합니다") }
        let column = current.column
        advance()
        return (name, column)
    }

    private mutating func expectLeftParen() throws {
        guard case .leftParen = current.kind else { throw err("'('가 필요합니다") }
        advance()
    }

    private mutating func expectRightParen() throws {
        guard case .rightParen = current.kind else { throw err("')'가 필요합니다") }
        advance()
    }

    private mutating func expectColon() throws {
        guard case .colon = current.kind else { throw err("':'가 필요합니다") }
        advance()
    }

    // MARK: Grammar

    private mutating func parseElement(zIndex: Int) throws -> SketchElement {
        let (shapeName, column) = try expectIdentifier()
        guard let kind = ShapeKind(rawValue: shapeName) else {
            throw SketchFormulaError.unknownShape(shapeName, column: column)
        }
        let shapeArgs = try parseNamedArgList()
        var transform = ElementTransform.identity
        while true {
            switch current.kind {
            case .middleDot, .star:
                advance()
                try applyModifier(to: &transform)
            default:
                transform.clamped()
                return SketchElement(shapeKind: kind, shapeParameters: shapeArgs, transform: transform, zIndex: zIndex)
            }
        }
    }

    private mutating func applyModifier(to transform: inout ElementTransform) throws {
        let (name, column) = try expectIdentifier()
        let values = try parsePositionalArgList()
        func require(_ count: Int) throws {
            guard values.count == count else { throw SketchFormulaError.badModifierArity(name, expected: count, column: column) }
        }
        switch name {
        case "scale":
            try require(2); transform.scaleX = values[0]; transform.scaleY = values[1]
        case "rotate":
            try require(1); transform.rotationDegrees = values[0]
        case "shear":
            try require(2); transform.shearX = values[0]; transform.shearY = values[1]
        case "translate":
            try require(2); transform.translateX = values[0]; transform.translateY = values[1]
        default:
            throw SketchFormulaError.unknownModifier(name, column: column)
        }
    }

    private mutating func parseNamedArgList() throws -> [String: Double] {
        try expectLeftParen()
        var result: [String: Double] = [:]
        if current.kind != .rightParen {
            try parseNamedArg(into: &result)
            while case .comma = current.kind {
                advance()
                try parseNamedArg(into: &result)
            }
        }
        try expectRightParen()
        return result
    }

    private mutating func parseNamedArg(into result: inout [String: Double]) throws {
        let (name, _) = try expectIdentifier()
        try expectColon()
        result[name] = try parseNumericExpression()
    }

    private mutating func parsePositionalArgList() throws -> [Double] {
        try expectLeftParen()
        var result: [Double] = []
        if current.kind != .rightParen {
            result.append(try parseNumericExpression())
            while case .comma = current.kind {
                advance()
                result.append(try parseNumericExpression())
            }
        }
        try expectRightParen()
        return result
    }

    // MARK: Numeric expression (embedded copy of MathParser's precedence ladder)

    private mutating func parseNumericExpression() throws -> Double {
        let expr = try parseAddSub()
        do {
            return try MathEvaluator.evaluate(expr)
        } catch let error as MathEvaluationError {
            throw err(error.message)
        }
    }

    private mutating func parseAddSub() throws -> MathExpr {
        var left = try parseMulDiv()
        loop: while true {
            switch current.kind {
            case .plus: advance(); left = .binary(.add, left, try parseMulDiv())
            case .minus: advance(); left = .binary(.subtract, left, try parseMulDiv())
            default: break loop
            }
        }
        return left
    }

    private mutating func parseMulDiv() throws -> MathExpr {
        var left = try parseUnary()
        loop: while true {
            switch current.kind {
            case .star: advance(); left = .binary(.multiply, left, try parseUnary())
            case .slash: advance(); left = .binary(.divide, left, try parseUnary())
            default: break loop
            }
        }
        return left
    }

    private mutating func parseUnary() throws -> MathExpr {
        if case .minus = current.kind { advance(); return .negate(try parseUnary()) }
        if case .plus = current.kind { advance(); return try parseUnary() }
        return try parsePowerLevel()
    }

    private mutating func parsePowerLevel() throws -> MathExpr {
        let base = try parsePrimaryLevel()
        if case .caret = current.kind {
            advance()
            return .binary(.power, base, try parseUnary())
        }
        return base
    }

    private mutating func parsePrimaryLevel() throws -> MathExpr {
        let token = current
        switch token.kind {
        case .number(let value):
            advance()
            return .number(value)
        case .identifier(let name):
            advance()
            if case .leftParen = current.kind {
                advance()
                var args: [MathExpr] = []
                if current.kind != .rightParen {
                    args.append(try parseAddSub())
                    while case .comma = current.kind {
                        advance()
                        args.append(try parseAddSub())
                    }
                }
                try expectRightParen()
                return .call(name, args)
            }
            return .variable(name)
        case .leftParen:
            advance()
            let expr = try parseAddSub()
            try expectRightParen()
            return expr
        default:
            throw err("식이 필요합니다")
        }
    }
}
