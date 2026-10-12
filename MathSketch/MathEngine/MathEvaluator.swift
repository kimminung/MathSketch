import Foundation

struct MathEvaluationError: Error, CustomStringConvertible, Equatable {
    let message: String
    var description: String { message }
}

/// Evaluates a MathExpr tree against a variable binding. Ported from Formula Simplification's
/// MathEngine. In MathSketch this evaluates numeric argument expressions inside a SketchFormula
/// (e.g. `r: 40*1.5`); it never executes arbitrary code — only the fixed operator/function set below.
nonisolated enum MathEvaluator {
    nonisolated static func evaluate(_ expr: MathExpr, variables: [String: Double] = [:]) throws -> Double {
        switch expr {
        case .number(let value):
            return value
        case .variable(let name):
            if let value = variables[name] { return value }
            switch name {
            case "pi": return Double.pi
            case "e": return M_E
            default:
                throw MathEvaluationError(message: "정의되지 않은 변수 '\(name)'")
            }
        case .negate(let inner):
            return -(try evaluate(inner, variables: variables))
        case .binary(let op, let lhsExpr, let rhsExpr):
            let lhs = try evaluate(lhsExpr, variables: variables)
            let rhs = try evaluate(rhsExpr, variables: variables)
            switch op {
            case .add: return lhs + rhs
            case .subtract: return lhs - rhs
            case .multiply: return lhs * rhs
            case .divide:
                guard rhs != 0 else { throw MathEvaluationError(message: "0으로 나눌 수 없습니다") }
                return lhs / rhs
            case .power:
                return pow(lhs, rhs)
            }
        case .call(let name, let argExprs):
            let args = try argExprs.map { try evaluate($0, variables: variables) }
            return try evaluateFunction(name, args)
        }
    }

    nonisolated private static func evaluateFunction(_ name: String, _ args: [Double]) throws -> Double {
        func arity1() throws -> Double {
            guard args.count == 1 else {
                throw MathEvaluationError(message: "'\(name)'은(는) 인자를 1개 받습니다")
            }
            return args[0]
        }
        func arity2() throws -> (Double, Double) {
            guard args.count == 2 else {
                throw MathEvaluationError(message: "'\(name)'은(는) 인자를 2개 받습니다")
            }
            return (args[0], args[1])
        }

        switch name {
        case "sin": return sin(try arity1())
        case "cos": return cos(try arity1())
        case "tan": return tan(try arity1())
        case "asin": return asin(try arity1())
        case "acos": return acos(try arity1())
        case "atan": return atan(try arity1())
        case "atan2":
            let (y, x) = try arity2()
            return atan2(y, x)
        case "sqrt":
            let x = try arity1()
            guard x >= 0 else { throw MathEvaluationError(message: "'sqrt'의 인자는 0 이상이어야 합니다") }
            return sqrt(x)
        case "abs":
            return abs(try arity1())
        case "exp":
            return exp(try arity1())
        case "log":
            let x = try arity1()
            guard x > 0 else { throw MathEvaluationError(message: "'log'의 인자는 0보다 커야 합니다") }
            return log(x)
        case "min":
            let (a, b) = try arity2()
            return Swift.min(a, b)
        case "max":
            let (a, b) = try arity2()
            return Swift.max(a, b)
        case "floor":
            return floor(try arity1())
        case "ceil":
            return ceil(try arity1())
        case "round":
            return (try arity1()).rounded()
        default:
            throw MathEvaluationError(message: "알 수 없는 함수 '\(name)'")
        }
    }
}
