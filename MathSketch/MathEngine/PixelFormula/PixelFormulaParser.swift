import Foundation

/// Parses a pasted pixel-color formula document (PRD FR-10): optional prose, a
/// `rgb(…, …, …)` color statement in terms of pixel column `m` / row `n`, and a list of
/// named definitions such as `H_v(x,y) = …`, `L_{u,s}(x,y) = …`, separated by top-level commas
/// (with English connectives like "where"/"and" tolerated and dropped).
///
/// Expression grammar (LaTeX subset):
///   expr    := term (('+'|'-') term)*
///   term    := unary (('*'|'/') unary | <implicit multiplication by juxtaposition>)*
///   unary   := ('-'|'+') unary | power
///   power   := factor ('^' exponent)?            // `e^{…}` becomes exp(…)
///   factor  := number | letter | '(' expr ')' | '{' expr '}' | \frac{a}{b} | \sqrt{a}
///            | \pi | builtin['^' exponent] arg | Letter[_sub]'(' args ')' (user call)
///            | ⟦ expr ⟧ | '|' expr '|' | ⌊ expr ⌋ | \sum_{s=a}^{b} term
nonisolated struct PixelFormulaParser {
    static func looksLikePixelFormula(_ source: String) -> Bool {
        let lowered = source.lowercased()
        return lowered.contains("rgb") || lowered.contains("\\frac") || lowered.contains("\\sum")
            || lowered.contains("\\left") || lowered.contains("\\mathrm")
    }

    static func parse(_ source: String) throws -> PixelFormulaProgram {
        let size = detectSize(source) ?? PixelFormulaProgram.defaultSize
        let normalized = LaTeXPreprocessor.normalize(source)
        guard let rgbRange = normalized.range(of: "rgb") else {
            throw PixelFormulaError(message: "픽셀 색을 정의하는 rgb(…) 식을 찾을 수 없습니다", column: nil)
        }
        let body = String(normalized[rgbRange.lowerBound...])
        let statements = splitStatements(body).map(stripProse).filter { !$0.isEmpty }
        guard !statements.isEmpty else {
            throw PixelFormulaError(message: "해석할 수식이 없습니다", column: nil)
        }

        // Pass 1: collect definition names so calls like `F(` can be told apart from `F·(`.
        var tokenized: [(tokens: [LaTeXToken], text: String)] = []
        var knownFunctions = Set<String>()
        for statement in statements {
            var tokenizer = LaTeXTokenizer(statement)
            let tokens = try tokenizer.tokenize()
            tokenized.append((tokens, statement))
            if let name = definitionName(in: tokens) {
                knownFunctions.insert(name)
            }
        }

        // Pass 2: parse.
        var channels: [PixelExpr]?
        var functions: [String: PixelFunction] = [:]
        var order: [String] = []
        for entry in tokenized {
            var parser = ExpressionParser(tokens: entry.tokens, knownFunctions: knownFunctions)
            if definitionName(in: entry.tokens) != nil {
                let function = try parser.parseDefinition()
                if functions[function.name] != nil {
                    throw PixelFormulaError(message: "함수 '\(function.name)'이(가) 두 번 정의되었습니다", column: nil)
                }
                functions[function.name] = function
                order.append(function.name)
            } else {
                guard channels == nil else {
                    throw PixelFormulaError(message: "rgb(…) 색 정의가 두 번 나왔습니다", column: entry.tokens.first?.column)
                }
                channels = try parser.parseColorStatement()
            }
        }
        guard let channels else {
            throw PixelFormulaError(message: "rgb(…) 색 정의가 없습니다", column: nil)
        }

        let program = PixelFormulaProgram(width: size.width, height: size.height, channels: channels,
                                          functions: functions, definitionOrder: order, originalSource: source)
        try validate(program)
        return program
    }

    // MARK: - Statement splitting

    /// `2000 × 1200`, `2000 \times 1200`, `2000x1200` anywhere in the prose.
    private static func detectSize(_ source: String) -> (width: Int, height: Int)? {
        let pattern = #"(\d{2,5})\s*(?:×|\\times|x|X|\*)\s*(\d{2,5})"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: source, range: NSRange(source.startIndex..., in: source)),
              let wRange = Range(match.range(at: 1), in: source),
              let hRange = Range(match.range(at: 2), in: source),
              let w = Int(source[wRange]), let h = Int(source[hRange]), w > 0, h > 0 else {
            return nil
        }
        return (w, h)
    }

    private static func splitStatements(_ text: String) -> [String] {
        var statements: [String] = []
        var current = ""
        var depth = 0
        for ch in text {
            switch ch {
            case "(", "{", "[", "⟦", "⌊": depth += 1
            case ")", "}", "]", "⟧", "⌋": depth = max(0, depth - 1)
            default: break
            }
            if ch == "," && depth == 0 {
                statements.append(current)
                current = ""
            } else {
                current.append(ch)
            }
        }
        statements.append(current)
        return statements
    }

    /// Drops leading English connectives ("where", "and", "For…") and a trailing period.
    private static func stripProse(_ statement: String) -> String {
        var text = statement.trimmingCharacters(in: .whitespacesAndNewlines)
        while let match = text.range(of: #"^[A-Za-z]{2,}[\s:]+"#, options: .regularExpression),
              !text.hasPrefix("rgb") {
            text.removeSubrange(match)
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        while text.hasSuffix(".") || text.hasSuffix(";") {
            text.removeLast()
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }

    /// `F(x) = …` / `L_{u,s}(x,y) = …` → the function letter, if this statement is a definition.
    private static func definitionName(in tokens: [LaTeXToken]) -> String? {
        guard let first = tokens.first, case .letter(let name) = first.kind else { return nil }
        var depth = 0
        for token in tokens {
            switch token.kind {
            case .leftParen, .leftBrace, .leftBracket, .absOpen, .floorOpen: depth += 1
            case .rightParen, .rightBrace, .rightBracket, .absClose, .floorClose: depth -= 1
            case .equals where depth == 0: return name
            default: break
            }
        }
        return nil
    }

    private static func validate(_ program: PixelFormulaProgram) throws {
        guard program.channels.count == 3 else {
            throw PixelFormulaError(message: "rgb(…)에는 정확히 3개의 채널 식이 필요합니다", column: nil)
        }
        for name in program.definitionOrder {
            guard let function = program.functions[name] else { continue }
            try checkCalls(in: function.body, program: program)
            let bound = Set(function.subscriptParameters + function.parameters)
            if let stray = function.body.freeVariables(bound: bound).sorted().first {
                throw PixelFormulaError(message: "'\(name)'의 정의에 매개변수가 아닌 변수 '\(stray)'이(가) 있습니다", column: nil)
            }
        }
        for channel in program.channels {
            try checkCalls(in: channel, program: program)
            // Channels see only the pixel coordinates. An unknown single letter here usually
            // means a call to an undefined function (`Z(1)` parses as Z·1).
            if let stray = channel.freeVariables(bound: ["m", "n"]).sorted().first {
                throw PixelFormulaError(message: "rgb(…) 안에 정의되지 않은 이름 '\(stray)'이(가) 있습니다 (픽셀 좌표 m, n만 쓸 수 있습니다)", column: nil)
            }
        }
    }

    private static func checkCalls(in expr: PixelExpr, program: PixelFormulaProgram) throws {
        switch expr {
        case .number, .variable: return
        case .negate(let inner): try checkCalls(in: inner, program: program)
        case .add(let l, let r), .subtract(let l, let r), .multiply(let l, let r), .divide(let l, let r), .power(let l, let r):
            try checkCalls(in: l, program: program)
            try checkCalls(in: r, program: program)
        case .call(let name, let args):
            guard PixelFormulaProgram.builtinFunctions.contains(name) else {
                throw PixelFormulaError(message: "알 수 없는 함수 '\\\(name)'", column: nil)
            }
            for arg in args { try checkCalls(in: arg, program: program) }
        case .userCall(let name, let subscripts, let args):
            guard let function = program.functions[name] else {
                throw PixelFormulaError(message: "정의되지 않은 함수 '\(name)'", column: nil)
            }
            guard function.subscriptParameters.count == subscripts.count else {
                throw PixelFormulaError(message: "'\(name)'의 아래첨자 개수가 정의(\(function.subscriptParameters.count)개)와 다릅니다", column: nil)
            }
            guard function.parameters.count == args.count else {
                throw PixelFormulaError(message: "'\(name)'의 인자 개수가 정의(\(function.parameters.count)개)와 다릅니다", column: nil)
            }
            for e in subscripts + args { try checkCalls(in: e, program: program) }
        case .sum(_, let lower, let upper, let body):
            try checkCalls(in: lower, program: program)
            try checkCalls(in: upper, program: program)
            try checkCalls(in: body, program: program)
        }
    }
}

// MARK: - Expression parser

nonisolated struct ExpressionParser {
    private let tokens: [LaTeXToken]
    private let knownFunctions: Set<String>
    private var position = 0
    /// Bare `|` is ambiguous: it opens an absolute value at depth 0 and closes one inside.
    /// Parenthesised groups reset this so `\frac{Q}{|P|}` nests inside an outer `|…|` fine.
    private var openBarCount = 0

    init(tokens: [LaTeXToken], knownFunctions: Set<String>) {
        self.tokens = tokens
        self.knownFunctions = knownFunctions
    }

    private var current: LaTeXToken { tokens[position] }
    private var peekKind: LaTeXTokenKind { position + 1 < tokens.count ? tokens[position + 1].kind : .end }

    @discardableResult
    private mutating func advance() -> LaTeXToken {
        let token = tokens[position]
        if position < tokens.count - 1 { position += 1 }
        return token
    }

    private func error(_ message: String) -> PixelFormulaError {
        PixelFormulaError(message: message, column: current.column)
    }

    private mutating func expect(_ kind: LaTeXTokenKind, _ what: String) throws {
        guard current.kind == kind else { throw error("\(what)이(가) 필요합니다") }
        advance()
    }

    // MARK: Statements

    /// `rgb(r, g, b)` → three channel expressions.
    mutating func parseColorStatement() throws -> [PixelExpr] {
        guard case .rgb = current.kind else { throw error("rgb(…) 식이 필요합니다") }
        advance()
        try expect(.leftParen, "'('")
        var channels = [try parseExpression()]
        while case .comma = current.kind {
            advance()
            channels.append(try parseExpression())
        }
        try expect(.rightParen, "')'")
        guard current.kind == .end else { throw error("rgb(…) 뒤에 해석할 수 없는 내용이 있습니다") }
        return channels
    }

    /// `Name[_sub](params) = body`
    mutating func parseDefinition() throws -> PixelFunction {
        guard case .letter(let name) = current.kind else { throw error("함수 이름이 필요합니다") }
        advance()
        var subscriptParameters: [String] = []
        if case .underscore = current.kind {
            advance()
            subscriptParameters = try parseSubscriptNames()
        }
        try expect(.leftParen, "'('")
        var parameters: [String] = []
        if current.kind != .rightParen {
            parameters.append(try parseParameterName())
            while case .comma = current.kind {
                advance()
                parameters.append(try parseParameterName())
            }
        }
        try expect(.rightParen, "')'")
        try expect(.equals, "'='")
        let body = try parseExpression()
        guard current.kind == .end else { throw error("정의 끝에 해석할 수 없는 내용이 있습니다") }
        return PixelFunction(name: name, subscriptParameters: subscriptParameters, parameters: parameters, body: body)
    }

    private mutating func parseParameterName() throws -> String {
        guard case .letter(let name) = current.kind else { throw error("매개변수 이름(한 글자)이 필요합니다") }
        advance()
        return name
    }

    private mutating func parseSubscriptNames() throws -> [String] {
        if case .leftBrace = current.kind {
            advance()
            var names = [try parseParameterName()]
            while case .comma = current.kind {
                advance()
                names.append(try parseParameterName())
            }
            try expect(.rightBrace, "'}'")
            return names
        }
        return [try parseParameterName()]
    }

    // MARK: Expressions

    mutating func parseExpression() throws -> PixelExpr {
        var left = try parseTerm()
        while true {
            switch current.kind {
            case .plus:
                advance()
                left = .add(left, try parseTerm())
            case .minus:
                advance()
                left = .subtract(left, try parseTerm())
            default:
                return left
            }
        }
    }

    private mutating func parseTerm() throws -> PixelExpr {
        var left = try parseUnary()
        while true {
            switch current.kind {
            case .star:
                advance()
                left = .multiply(left, try parseUnary())
            case .slash:
                advance()
                left = .divide(left, try parseUnary())
            default:
                if canStartFactor(current.kind) {
                    left = .multiply(left, try parseUnary())
                } else {
                    return left
                }
            }
        }
    }

    private func canStartFactor(_ kind: LaTeXTokenKind) -> Bool {
        switch kind {
        case .number, .letter, .leftParen, .leftBrace, .absOpen, .floorOpen:
            return true
        case .bar:
            return openBarCount == 0
        case .command(let name):
            return name == "frac" || name == "sqrt" || name == "pi" || name == "sum"
                || PixelFormulaProgram.builtinFunctions.contains(name)
        default:
            return false
        }
    }

    private mutating func parseUnary() throws -> PixelExpr {
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

    private mutating func parsePower() throws -> PixelExpr {
        let base = try parseFactor()
        guard case .caret = current.kind else { return base }
        advance()
        let exponent = try parseExponentOperand()
        if case .variable("e") = base {
            return .call("exp", [exponent])
        }
        return .power(base, exponent)
    }

    /// `^{…}` or `^x` (a single atom). A second `^` after a bare atom is applied too, so
    /// `10^5` and `s^2` work; `x^{a}^{b}` isn't valid LaTeX and isn't supported.
    private mutating func parseExponentOperand() throws -> PixelExpr {
        if case .leftBrace = current.kind {
            return try parseGroup(closing: .rightBrace, "'}'")
        }
        if case .minus = current.kind {
            advance()
            return .negate(try parseExponentOperand())
        }
        return try parseAtom()
    }

    /// Smallest standalone operand: number, letter, \pi, \frac, or a parenthesised group.
    private mutating func parseAtom() throws -> PixelExpr {
        switch current.kind {
        case .number(let value):
            advance()
            return .number(value)
        case .letter(let name):
            advance()
            return .variable(name)
        case .command("pi"):
            advance()
            return .variable("pi")
        case .command("frac"):
            return try parseFraction()
        case .leftParen:
            return try parseGroup(closing: .rightParen, "')'")
        default:
            throw error("지수 자리에 올 수 없는 항목입니다")
        }
    }

    private mutating func parseFactor() throws -> PixelExpr {
        let token = current
        switch token.kind {
        case .number(let value):
            advance()
            return .number(value)

        case .letter(let name):
            return try parseLetter(name)

        case .leftParen:
            return try parseGroup(closing: .rightParen, "')'")

        case .leftBrace:
            return try parseGroup(closing: .rightBrace, "'}'")

        case .absOpen:
            return .call("abs", [try parseGroup(closing: .absClose, "닫는 절댓값 기호")])

        case .bar:
            advance()
            openBarCount += 1
            let inner = try parseExpression()
            try expect(.bar, "닫는 '|'")
            openBarCount -= 1
            return .call("abs", [inner])

        case .floorOpen:
            return .call("floor", [try parseGroup(closing: .floorClose, "'⌋'")])

        case .command(let name):
            return try parseCommand(name)

        case .rgb:
            throw error("rgb는 색 정의의 맨 앞에서만 쓸 수 있습니다")

        default:
            throw error("식이 필요합니다")
        }
    }

    /// Consumes the opening bracket at `current`, an expression, and `closing`. Inside the
    /// group a bare `|` opens a fresh absolute value again.
    private mutating func parseGroup(closing: LaTeXTokenKind, _ what: String) throws -> PixelExpr {
        advance()
        let savedBars = openBarCount
        openBarCount = 0
        let inner = try parseExpression()
        try expect(closing, what)
        openBarCount = savedBars
        return inner
    }

    /// A letter is a user-function call when it names a definition and is followed by
    /// `(` or by a subscript then `(`; otherwise it's a plain variable.
    private mutating func parseLetter(_ name: String) throws -> PixelExpr {
        guard knownFunctions.contains(name) else {
            advance()
            return .variable(name)
        }
        let save = position
        advance()
        var subscripts: [PixelExpr] = []
        if case .underscore = current.kind {
            advance()
            subscripts = try parseSubscriptExpressions()
        }
        guard case .leftParen = current.kind else {
            // `F` used without a call — treat as a variable named F.
            position = save
            advance()
            return .variable(name)
        }
        advance()
        let savedBars = openBarCount
        openBarCount = 0
        var args: [PixelExpr] = []
        if current.kind != .rightParen {
            args.append(try parseExpression())
            while case .comma = current.kind {
                advance()
                args.append(try parseExpression())
            }
        }
        try expect(.rightParen, "')'")
        openBarCount = savedBars
        return .userCall(name: name, subscripts: subscripts, args: args)
    }

    private mutating func parseSubscriptExpressions() throws -> [PixelExpr] {
        if case .leftBrace = current.kind {
            advance()
            var items = [try parseExpression()]
            while case .comma = current.kind {
                advance()
                items.append(try parseExpression())
            }
            try expect(.rightBrace, "'}'")
            return items
        }
        return [try parseAtom()]
    }

    private mutating func parseCommand(_ name: String) throws -> PixelExpr {
        switch name {
        case "frac":
            return try parseFraction()
        case "sqrt":
            advance()
            if case .leftBracket = current.kind {
                throw error("n제곱근(\\sqrt[n])은 지원하지 않습니다 — ^{1/n}으로 적어주세요")
            }
            let radicand = try parseBracedOrFactor()
            return .call("sqrt", [radicand])
        case "pi":
            advance()
            return .variable("pi")
        case "sum":
            return try parseSum()
        default:
            guard PixelFormulaProgram.builtinFunctions.contains(name) else {
                throw error("지원하지 않는 LaTeX 명령 '\\\(name)'")
            }
            advance()
            var exponent: PixelExpr?
            if case .caret = current.kind {
                advance()
                exponent = try parseExponentOperand()
            }
            let argument = try parseFunctionArgument()
            let callName = name == "arctan" ? "atan" : name == "arcsin" ? "asin" : name == "arccos" ? "acos" : name == "log" ? "ln" : name
            let call = PixelExpr.call(callName, [argument])
            if let exponent {
                return .power(call, exponent)
            }
            return call
        }
    }

    private mutating func parseFraction() throws -> PixelExpr {
        advance() // \frac
        try expect(.leftBrace, "'{'")
        let numerator = try parseExpression()
        try expect(.rightBrace, "'}'")
        try expect(.leftBrace, "'{'")
        let denominator = try parseExpression()
        try expect(.rightBrace, "'}'")
        return .divide(numerator, denominator)
    }

    private mutating func parseBracedOrFactor() throws -> PixelExpr {
        if case .leftBrace = current.kind {
            return try parseGroup(closing: .rightBrace, "'}'")
        }
        return try parseFactor()
    }

    /// `\sin(x)`, `\sin x`, `\ln\left(…\right)` — parenthesised argument or a single factor.
    private mutating func parseFunctionArgument() throws -> PixelExpr {
        if case .leftParen = current.kind {
            return try parseGroup(closing: .rightParen, "')'")
        }
        return try parsePower()
    }

    /// `\sum_{s=1}^{50} term` — the body is one product term, matching how the sum sign scopes
    /// typographically (it stops at the next `+`/`-` at this level).
    private mutating func parseSum() throws -> PixelExpr {
        advance() // \sum
        try expect(.underscore, "'_'")
        try expect(.leftBrace, "'{'")
        guard case .letter(let variable) = current.kind else { throw error("합의 인덱스 변수가 필요합니다") }
        advance()
        try expect(.equals, "'='")
        let lower = try parseExpression()
        try expect(.rightBrace, "'}'")
        try expect(.caret, "'^'")
        let upper = try parseExponentOperand()
        let body = try parseTerm()
        return .sum(variable: variable, lower: lower, upper: upper, body: body)
    }
}
