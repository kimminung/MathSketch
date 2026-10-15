import Foundation

/// Reference CPU evaluator for pixel-color formulas (PRD FR-10). It is the semantic ground
/// truth the Metal transpiler must match, and the low-resolution fallback when Metal is
/// unavailable. Double precision; the GPU path uses float, so tests compare with tolerance.
nonisolated struct PixelFormulaEvaluator: Sendable {
    let program: PixelFormulaProgram

    /// Hard cap so a pasted `\sum_{s=1}^{10^9}` can't hang the app.
    static let maxSumIterations = 100_000

    init(program: PixelFormulaProgram) {
        self.program = program
    }

    // MARK: Pixel API

    /// Raw channel values for 1-based pixel column `m` / row `n` (before clamping).
    func channelValues(m: Double, n: Double) -> [Double] {
        let env: [String: Double] = ["m": m, "n": n]
        return program.channels.map { evaluate($0, env: env) }
    }

    /// Clamped 0…255 RGB bytes; NaN/∞ become 0 so a singular pixel never poisons the image.
    func pixelColor(m: Double, n: Double) -> (r: UInt8, g: UInt8, b: UInt8) {
        let values = channelValues(m: m, n: n).map(Self.toByte)
        let r = values.count > 0 ? values[0] : 0
        let g = values.count > 1 ? values[1] : 0
        let b = values.count > 2 ? values[2] : 0
        return (r, g, b)
    }

    static func toByte(_ value: Double) -> UInt8 {
        guard value.isFinite else { return 0 }
        return UInt8(min(255, max(0, value)))
    }

    // MARK: Expression evaluation

    func evaluate(_ expr: PixelExpr, env: [String: Double]) -> Double {
        switch expr {
        case .number(let value):
            return value
        case .variable(let name):
            if let bound = env[name] { return bound }
            if name == "e" { return M_E }
            if name == "pi" { return .pi }
            return .nan
        case .negate(let inner):
            return -evaluate(inner, env: env)
        case .add(let l, let r):
            return evaluate(l, env: env) + evaluate(r, env: env)
        case .subtract(let l, let r):
            return evaluate(l, env: env) - evaluate(r, env: env)
        case .multiply(let l, let r):
            return evaluate(l, env: env) * evaluate(r, env: env)
        case .divide(let l, let r):
            return evaluate(l, env: env) / evaluate(r, env: env)
        case .power(let base, let exponent):
            return Self.signedPow(evaluate(base, env: env), evaluate(exponent, env: env))
        case .call(let name, let args):
            let values = args.map { evaluate($0, env: env) }
            return Self.callBuiltin(name, values)
        case .userCall(let name, let subscripts, let args):
            guard let function = program.functions[name] else { return .nan }
            // Fresh environment per call: a function body only sees its own parameters and
            // the global constants, exactly like the Metal function it transpiles to.
            var callEnv: [String: Double] = [:]
            for (parameter, value) in zip(function.subscriptParameters, subscripts) {
                callEnv[parameter] = evaluate(value, env: env)
            }
            for (parameter, value) in zip(function.parameters, args) {
                callEnv[parameter] = evaluate(value, env: env)
            }
            return evaluate(function.body, env: callEnv)
        case .sum(let variable, let lower, let upper, let body):
            let lo = evaluate(lower, env: env), hi = evaluate(upper, env: env)
            guard lo.isFinite, hi.isFinite else { return .nan }
            let start = Int(lo.rounded()), end = Int(hi.rounded())
            guard end >= start else { return 0 }
            let count = min(end - start + 1, Self.maxSumIterations)
            var total = 0.0
            var local = env
            for index in 0..<count {
                local[variable] = Double(start + index)
                total += evaluate(body, env: local)
            }
            return total
        }
    }

    /// `pow` that keeps the sign for odd integer exponents of negative bases (so `(-2)^3 = -8`
    /// as in ordinary mathematics) instead of returning NaN.
    static func signedPow(_ base: Double, _ exponent: Double) -> Double {
        if base < 0, exponent.isFinite, exponent == exponent.rounded() {
            let magnitude = pow(-base, exponent)
            let isOdd = Int(exponent.truncatingRemainder(dividingBy: 2)) != 0
            return isOdd ? -magnitude : magnitude
        }
        return pow(base, exponent)
    }

    static func callBuiltin(_ name: String, _ args: [Double]) -> Double {
        guard let x = args.first else { return .nan }
        switch name {
        case "sin": return sin(x)
        case "cos": return cos(x)
        case "tan": return tan(x)
        case "asin", "arcsin": return asin(x)
        case "acos", "arccos": return acos(x)
        case "atan", "arctan": return atan(x)
        case "sinh": return sinh(x)
        case "cosh": return cosh(x)
        case "tanh": return tanh(x)
        case "exp": return exp(x)
        case "ln", "log": return log(x)
        case "sqrt": return sqrt(x)
        case "abs": return abs(x)
        case "floor": return floor(x)
        case "ceil": return ceil(x)
        default: return .nan
        }
    }
}
