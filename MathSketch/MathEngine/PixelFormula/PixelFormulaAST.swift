import Foundation

/// Expression tree for pixel-color formulas (PRD FR-10). Shared by the CPU evaluator
/// (tests, fallback preview) and the Metal transpiler (production rendering).
nonisolated indirect enum PixelExpr: Equatable, Sendable {
    case number(Double)
    /// A free variable: `x`, `y`, `m`, `n`, a sum index, or a function parameter. `e` and `pi`
    /// are resolved as constants by the evaluator/transpiler, never bound by the user.
    case variable(String)
    case negate(PixelExpr)
    case add(PixelExpr, PixelExpr)
    case subtract(PixelExpr, PixelExpr)
    case multiply(PixelExpr, PixelExpr)
    case divide(PixelExpr, PixelExpr)
    case power(PixelExpr, PixelExpr)
    /// Built-in: sin cos tan asin acos atan sinh cosh tanh exp ln log sqrt abs floor ceil.
    case call(String, [PixelExpr])
    /// A user-defined function such as `H_0(x, y)` → name "H", subscripts [0], args [x, y].
    case userCall(name: String, subscripts: [PixelExpr], args: [PixelExpr])
    /// `\sum_{variable=lower}^{upper} body`, inclusive integer bounds.
    case sum(variable: String, lower: PixelExpr, upper: PixelExpr, body: PixelExpr)
}

/// `K_v(x, y) = …` → name "K", subscriptParameters ["v"], parameters ["x", "y"].
nonisolated struct PixelFunction: Equatable, Sendable {
    var name: String
    var subscriptParameters: [String]
    var parameters: [String]
    var body: PixelExpr
}

nonisolated struct PixelFormulaProgram: Equatable, Sendable {
    /// Pixel grid the formula was written for (`2000 × 1200` in the prose, or a default).
    var width: Int
    var height: Int
    /// Red, green, blue channel expressions in terms of pixel column `m` and row `n` (1-based).
    var channels: [PixelExpr]
    var functions: [String: PixelFunction]
    /// Definitions in source order, for display.
    var definitionOrder: [String]
    var originalSource: String

    static let builtinFunctions: Set<String> = [
        "sin", "cos", "tan", "asin", "acos", "atan", "arctan", "arcsin", "arccos",
        "sinh", "cosh", "tanh", "exp", "ln", "log", "sqrt", "abs", "floor", "ceil",
    ]

    static let defaultSize = (width: 2000, height: 1200)
    static let maxPixels = 2000 * 1200
}

extension PixelExpr {
    /// Free variables, excluding `e`/`pi` constants and the names in `bound`.
    func freeVariables(bound: Set<String> = []) -> Set<String> {
        switch self {
        case .number: return []
        case .variable(let name):
            if name == "e" || name == "pi" || bound.contains(name) { return [] }
            return [name]
        case .negate(let inner): return inner.freeVariables(bound: bound)
        case .add(let l, let r), .subtract(let l, let r), .multiply(let l, let r), .divide(let l, let r), .power(let l, let r):
            return l.freeVariables(bound: bound).union(r.freeVariables(bound: bound))
        case .call(_, let args):
            return args.reduce(into: Set<String>()) { $0.formUnion($1.freeVariables(bound: bound)) }
        case .userCall(_, let subscripts, let args):
            return (subscripts + args).reduce(into: Set<String>()) { $0.formUnion($1.freeVariables(bound: bound)) }
        case .sum(let variable, let lower, let upper, let body):
            var result = lower.freeVariables(bound: bound).union(upper.freeVariables(bound: bound))
            result.formUnion(body.freeVariables(bound: bound.union([variable])))
            return result
        }
    }
}
