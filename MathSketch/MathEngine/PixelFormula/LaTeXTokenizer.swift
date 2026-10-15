import Foundation

/// Tokens for the LaTeX subset used by pixel-color formulas (PRD FR-10). Unlike MathLexer,
/// identifiers are *single letters* — LaTeX juxtaposition like `us^2` means u·s², so a
/// letter run is a product, not one name. The only multi-letter identifier is the reserved
/// `rgb` color constructor; everything else multi-letter arrives as a `\command`.
nonisolated enum LaTeXTokenKind: Equatable {
    case number(Double)
    case letter(String)
    case rgb
    case command(String)
    case plus, minus, star, slash, caret, underscore, equals
    case leftParen, rightParen, leftBrace, rightBrace, leftBracket, rightBracket
    case comma, bar, absOpen, absClose, floorOpen, floorClose
    case end
}

nonisolated struct LaTeXToken: Equatable {
    let kind: LaTeXTokenKind
    let column: Int
}

nonisolated struct PixelFormulaError: Error, CustomStringConvertible, Equatable {
    let message: String
    let column: Int?
    var description: String {
        if let column { return "\(column)열: \(message)" }
        return message
    }
}

/// Rewrites LaTeX layout noise into a canonical, token-friendly form before lexing.
/// `\left|`/`\right|` become distinct open/close markers so absolute values nest
/// unambiguously; bare `|` stays ambiguous and is resolved by parse position.
nonisolated enum LaTeXPreprocessor {
    static func normalize(_ source: String) -> String {
        var text = source
        let replacements: [(String, String)] = [
            ("\\mathrm{rgb}", "rgb"), ("\\operatorname{rgb}", "rgb"), ("\\text{rgb}", "rgb"),
            ("\\left\\lfloor", "⌊"), ("\\right\\rfloor", "⌋"), ("\\lfloor", "⌊"), ("\\rfloor", "⌋"),
            ("\\left\\lvert", "⟦"), ("\\right\\rvert", "⟧"), ("\\lvert", "⟦"), ("\\rvert", "⟧"),
            ("\\left|", "⟦"), ("\\right|", "⟧"),
            ("\\left(", "("), ("\\right)", ")"), ("\\left[", "("), ("\\right]", ")"),
            ("\\left\\{", "("), ("\\right\\}", ")"), ("\\left.", ""), ("\\right.", ""),
            ("\\Bigg(", "("), ("\\Bigg)", ")"), ("\\bigg(", "("), ("\\bigg)", ")"),
            ("\\Big(", "("), ("\\Big)", ")"), ("\\big(", "("), ("\\big)", ")"),
            ("\\Bigg|", "|"), ("\\bigg|", "|"), ("\\Big|", "|"), ("\\big|", "|"),
            ("\\tfrac", "\\frac"), ("\\dfrac", "\\frac"),
            ("\\cdot", "*"), ("\\times", "*"), ("×", "*"), ("·", "*"),
            ("\\,", " "), ("\\;", " "), ("\\:", " "), ("\\!", ""), ("\\quad", " "), ("\\qquad", " "),
            ("\\ ", " "), ("\\\\", " "), ("\\displaystyle", ""), ("\\textstyle", ""),
            ("\\ldots", ""), ("\\cdots", ""), ("\\dots", ""), ("…", ""),
            ("−", "-"), ("–", "-"), ("—", "-"), ("\u{2212}", "-"),
            ("\\{", "("), ("\\}", ")"), ("\\%", "%"),
            ("$$", " "), ("$", " "), ("**", " "),
        ]
        for (from, to) in replacements {
            text = text.replacingOccurrences(of: from, with: to)
        }
        return text
    }
}

nonisolated struct LaTeXTokenizer {
    private let characters: [Character]
    private var index = 0

    init(_ normalizedSource: String) {
        characters = Array(normalizedSource)
    }

    mutating func tokenize() throws -> [LaTeXToken] {
        var tokens: [LaTeXToken] = []
        while let token = try next() {
            tokens.append(token)
        }
        tokens.append(LaTeXToken(kind: .end, column: characters.count))
        return tokens
    }

    private mutating func next() throws -> LaTeXToken? {
        while index < characters.count, characters[index].isWhitespace || characters[index].isNewline {
            index += 1
        }
        guard index < characters.count else { return nil }
        let column = index
        let c = characters[index]

        if c.isNumber || (c == "." && index + 1 < characters.count && characters[index + 1].isNumber) {
            var text = ""
            while index < characters.count, characters[index].isNumber || characters[index] == "." {
                text.append(characters[index])
                index += 1
            }
            guard let value = Double(text) else {
                throw PixelFormulaError(message: "잘못된 숫자 '\(text)'", column: column)
            }
            return LaTeXToken(kind: .number(value), column: column)
        }

        if c == "\\" {
            index += 1
            var name = ""
            while index < characters.count, characters[index].isLetter {
                name.append(characters[index])
                index += 1
            }
            guard !name.isEmpty else {
                throw PixelFormulaError(message: "백슬래시 뒤에 명령 이름이 없습니다", column: column)
            }
            return LaTeXToken(kind: .command(name), column: column)
        }

        if c.isLetter {
            if matches("rgb", at: index) {
                index += 3
                return LaTeXToken(kind: .rgb, column: column)
            }
            index += 1
            return LaTeXToken(kind: .letter(String(c)), column: column)
        }

        index += 1
        switch c {
        case "+": return LaTeXToken(kind: .plus, column: column)
        case "-": return LaTeXToken(kind: .minus, column: column)
        case "*": return LaTeXToken(kind: .star, column: column)
        case "/": return LaTeXToken(kind: .slash, column: column)
        case "^": return LaTeXToken(kind: .caret, column: column)
        case "_": return LaTeXToken(kind: .underscore, column: column)
        case "=": return LaTeXToken(kind: .equals, column: column)
        case "(": return LaTeXToken(kind: .leftParen, column: column)
        case ")": return LaTeXToken(kind: .rightParen, column: column)
        case "{": return LaTeXToken(kind: .leftBrace, column: column)
        case "}": return LaTeXToken(kind: .rightBrace, column: column)
        case "[": return LaTeXToken(kind: .leftBracket, column: column)
        case "]": return LaTeXToken(kind: .rightBracket, column: column)
        case ",": return LaTeXToken(kind: .comma, column: column)
        case "|": return LaTeXToken(kind: .bar, column: column)
        case "⟦": return LaTeXToken(kind: .absOpen, column: column)
        case "⟧": return LaTeXToken(kind: .absClose, column: column)
        case "⌊": return LaTeXToken(kind: .floorOpen, column: column)
        case "⌋": return LaTeXToken(kind: .floorClose, column: column)
        default:
            throw PixelFormulaError(message: "알 수 없는 문자 '\(c)'", column: column)
        }
    }

    private func matches(_ word: String, at position: Int) -> Bool {
        let chars = Array(word)
        guard position + chars.count <= characters.count else { return false }
        for (offset, ch) in chars.enumerated() where characters[position + offset] != ch {
            return false
        }
        let after = position + chars.count
        return after >= characters.count || !characters[after].isLetter
    }
}
