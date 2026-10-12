import Foundation

/// Standalone generic-arithmetic recursive-descent parser, ported from Formula Simplification.
/// Precedence (low to high): `+ -` < `* /` < unary `-` < `^` (right-associative) < primary.
/// Not used directly by SketchFormulaParser (which embeds its own copy of this grammar so it can
/// stop mid-stream at `,`/`)`/`·`), but kept here for engine-level unit tests and possible reuse.
nonisolated struct MathParser {
    private let tokens: [MathToken]
    private var position = 0

    private init(tokens: [MathToken]) {
        self.tokens = tokens
    }

    static func parse(_ source: String) throws -> MathExpr {
        var lexer = MathLexer(source)
        let tokens = try lexer.tokenize()
        var parser = MathParser(tokens: tokens)
        let expr = try parser.parseExpression()
        try parser.expectEnd()
        return expr
    }

    private var current: MathToken { tokens[position] }

    @discardableResult
    private mutating func advance() -> MathToken {
        let token = tokens[position]
        if position < tokens.count - 1 { position += 1 }
        return token
    }

    private func expectEnd() throws {
        guard current.kind == .end else {
            throw MathSyntaxError(message: "식이 끝나지 않았습니다", column: current.column)
        }
    }

    private mutating func parseExpression() throws -> MathExpr {
        var left = try parseTerm()
        loop: while true {
            switch current.kind {
            case .plus:
                advance()
                left = .binary(.add, left, try parseTerm())
            case .minus:
                advance()
                left = .binary(.subtract, left, try parseTerm())
            default:
                break loop
            }
        }
        return left
    }

    private mutating func parseTerm() throws -> MathExpr {
        var left = try parseUnary()
        loop: while true {
            switch current.kind {
            case .star:
                advance()
                left = .binary(.multiply, left, try parseUnary())
            case .slash:
                advance()
                left = .binary(.divide, left, try parseUnary())
            default:
                break loop
            }
        }
        return left
    }

    private mutating func parseUnary() throws -> MathExpr {
        if case .minus = current.kind {
            advance()
            return .negate(try parseUnary())
        }
        if case .plus = current.kind {
            advance()
            return try parseUnary()
        }
        return try parsePower()
    }

    private mutating func parsePower() throws -> MathExpr {
        let base = try parsePrimary()
        if case .caret = current.kind {
            advance()
            let exponent = try parseUnary()
            return .binary(.power, base, exponent)
        }
        return base
    }

    private mutating func parsePrimary() throws -> MathExpr {
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
                    args.append(try parseExpression())
                    while case .comma = current.kind {
                        advance()
                        args.append(try parseExpression())
                    }
                }
                guard case .rightParen = current.kind else {
                    throw MathSyntaxError(message: "')'가 필요합니다", column: current.column)
                }
                advance()
                return .call(name, args)
            }
            return .variable(name)
        case .leftParen:
            advance()
            let expr = try parseExpression()
            guard case .rightParen = current.kind else {
                throw MathSyntaxError(message: "')'가 필요합니다", column: current.column)
            }
            advance()
            return expr
        default:
            throw MathSyntaxError(message: "식이 필요합니다", column: token.column)
        }
    }
}
