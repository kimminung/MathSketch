import Foundation

/// Ported from Formula Simplification's MathEngine, extended with `.colon` and `.middleDot`
/// for the SketchFormula DSL (named arguments `r: 40`, modifier chains `· `).
nonisolated enum MathTokenKind: Equatable {
    case number(Double)
    case identifier(String)
    case plus, minus, star, slash, caret
    case leftParen, rightParen, comma
    case colon, middleDot
    case end
}

struct MathToken: Equatable {
    let kind: MathTokenKind
    let column: Int
}

/// A parse or evaluation failure with a 1-based column into the original expression string.
struct MathSyntaxError: Error, CustomStringConvertible, Equatable {
    let message: String
    let column: Int
    var description: String { "\(column)열: \(message)" }
}

nonisolated struct MathLexer {
    private let characters: [Character]
    private var index = 0

    init(_ source: String) {
        characters = Array(source)
    }

    mutating func tokenize() throws -> [MathToken] {
        var tokens: [MathToken] = []
        while let token = try next() {
            tokens.append(token)
        }
        tokens.append(MathToken(kind: .end, column: characters.count))
        return tokens
    }

    private mutating func next() throws -> MathToken? {
        while index < characters.count, characters[index].isWhitespace {
            index += 1
        }
        guard index < characters.count else { return nil }

        let column = index
        let c = characters[index]

        if c.isNumber || c == "." {
            var text = ""
            while index < characters.count, characters[index].isNumber || characters[index] == "." {
                text.append(characters[index])
                index += 1
            }
            guard let value = Double(text) else {
                throw MathSyntaxError(message: "잘못된 숫자 '\(text)'", column: column)
            }
            return MathToken(kind: .number(value), column: column)
        }

        if c.isLetter {
            var text = ""
            while index < characters.count, characters[index].isLetter || characters[index].isNumber {
                text.append(characters[index])
                index += 1
            }
            return MathToken(kind: .identifier(text), column: column)
        }

        index += 1
        switch c {
        case "+": return MathToken(kind: .plus, column: column)
        case "-": return MathToken(kind: .minus, column: column)
        case "*": return MathToken(kind: .star, column: column)
        case "/": return MathToken(kind: .slash, column: column)
        case "^": return MathToken(kind: .caret, column: column)
        case "(": return MathToken(kind: .leftParen, column: column)
        case ")": return MathToken(kind: .rightParen, column: column)
        case ",": return MathToken(kind: .comma, column: column)
        case ":": return MathToken(kind: .colon, column: column)
        case "·": return MathToken(kind: .middleDot, column: column)
        default:
            throw MathSyntaxError(message: "알 수 없는 문자 '\(c)'", column: column)
        }
    }
}
