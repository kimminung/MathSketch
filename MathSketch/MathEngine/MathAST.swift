/// Expression tree produced by MathParser and consumed by MathEvaluator.
/// Ported from Formula Simplification's MathEngine.
nonisolated indirect enum MathExpr {
    case number(Double)
    case variable(String)
    case negate(MathExpr)
    case binary(MathBinaryOp, MathExpr, MathExpr)
    case call(String, [MathExpr])
}

nonisolated enum MathBinaryOp {
    case add, subtract, multiply, divide, power
}
