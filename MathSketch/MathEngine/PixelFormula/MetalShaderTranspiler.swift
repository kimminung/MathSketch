import Foundation

/// Emits a complete Metal Shading Language compute kernel for a `PixelFormulaProgram`
/// (PRD FR-10). Every user definition becomes a `float` function; every `\sum` becomes a
/// small loop helper whose parameters are the sum's free variables, so the GPU evaluates
/// the exact same tree the CPU evaluator walks — just 2.4 million times in parallel.
nonisolated enum MetalShaderTranspiler {
    static let kernelName = "pixelFormula"

    /// Matches `PixelUniforms` in the generated MSL — keep the two in lockstep.
    struct Uniforms {
        var width: UInt32
        var height: UInt32
        var rowOffset: UInt32
        /// Rows in this dispatch — the grid is rounded up to whole threadgroups, so the
        /// kernel must discard the overhang itself.
        var bandRows: UInt32
        var scaleX: Float
        var scaleY: Float
    }

    static func source(for program: PixelFormulaProgram) -> String {
        var generator = Generator(program: program)
        return generator.emitProgram()
    }

    // MARK: - Generator

    private struct Generator {
        let program: PixelFormulaProgram
        private var helpers: [String] = []
        private var helperCount = 0

        init(program: PixelFormulaProgram) {
            self.program = program
        }

        mutating func emitProgram() -> String {
            var functionBodies: [String] = []
            var forwardDeclarations: [String] = []
            for name in program.definitionOrder {
                guard let function = program.functions[name] else { continue }
                let parameterList = (function.subscriptParameters + function.parameters)
                    .map { "float \(variable($0))" }.joined(separator: ", ")
                forwardDeclarations.append("static float \(functionName(name))(\(parameterList));")
                let body = expression(function.body)
                functionBodies.append("""
                static float \(functionName(name))(\(parameterList)) {
                    return \(body);
                }
                """)
            }
            // Channel expressions may contain sums too; generate them after the functions so
            // their helpers are appended (and therefore emitted) in dependency order.
            let channelCode = program.channels.map { expression($0) }
            let red = channelCode.count > 0 ? channelCode[0] : "0.0f"
            let green = channelCode.count > 1 ? channelCode[1] : "0.0f"
            let blue = channelCode.count > 2 ? channelCode[2] : "0.0f"

            return """
            #include <metal_stdlib>
            using namespace metal;

            struct PixelUniforms {
                uint width;
                uint height;
                uint rowOffset;
                uint bandRows;
                float scaleX;
                float scaleY;
            };

            // pow that keeps the sign for odd integer exponents of negative bases, like the
            // CPU reference evaluator (plain pow(-2, 3) is NaN in IEEE/Metal).
            static inline float spow(float b, float e) {
                if (b < 0.0f && e == floor(e)) {
                    float m = pow(-b, e);
                    return (fmod(fabs(e), 2.0f) == 1.0f) ? -m : m;
                }
                return pow(b, e);
            }

            static inline float ipow(float b, int n) {
                bool negative = n < 0;
                if (negative) n = -n;
                float r = 1.0f;
                for (int i = 0; i < n; ++i) r *= b;
                return negative ? 1.0f / r : r;
            }

            static inline uchar sanitize(float v) {
                if (isnan(v) || isinf(v)) return 0;
                return uchar(clamp(v, 0.0f, 255.0f));
            }

            \(forwardDeclarations.joined(separator: "\n"))

            \(helpers.joined(separator: "\n\n"))

            \(functionBodies.joined(separator: "\n\n"))

            kernel void \(kernelName)(device uchar4 *out [[buffer(0)]],
                                      constant PixelUniforms &u [[buffer(1)]],
                                      uint2 gid [[thread_position_in_grid]]) {
                uint row = gid.y + u.rowOffset;
                if (gid.x >= u.width || gid.y >= u.bandRows || row >= u.height) return;
                // Pixel centers mapped onto the formula's 1-based (m, n) grid; at scale 1 this is
                // exactly m = column index + 1, n = row index + 1.
                float \(variable("m")) = (float(gid.x) + 0.5f) * u.scaleX + 0.5f;
                float \(variable("n")) = (float(row) + 0.5f) * u.scaleY + 0.5f;
                float r = \(red);
                float g = \(green);
                float b = \(blue);
                out[row * u.width + gid.x] = uchar4(sanitize(r), sanitize(g), sanitize(b), 255);
            }
            """
        }

        // MARK: Expressions

        private mutating func expression(_ expr: PixelExpr) -> String {
            switch expr {
            case .number(let value):
                return literal(value)
            case .variable(let name):
                if name == "e" { return "M_E_F" }
                if name == "pi" { return "M_PI_F" }
                return variable(name)
            case .negate(let inner):
                return "(-\(expression(inner)))"
            case .add(let l, let r):
                return "(\(expression(l)) + \(expression(r)))"
            case .subtract(let l, let r):
                return "(\(expression(l)) - \(expression(r)))"
            case .multiply(let l, let r):
                return "(\(expression(l)) * \(expression(r)))"
            case .divide(let l, let r):
                return "(\(expression(l)) / \(expression(r)))"
            case .power(let base, let exponent):
                if case .number(let k) = exponent, k == k.rounded(), abs(k) <= 16 {
                    return "ipow(\(expression(base)), \(Int(k)))"
                }
                if case .negate(let inner) = exponent, case .number(let k) = inner, k == k.rounded(), abs(k) <= 16 {
                    return "ipow(\(expression(base)), \(-Int(k)))"
                }
                return "spow(\(expression(base)), \(expression(exponent)))"
            case .call(let name, let args):
                let arguments = args.map { expression($0) }.joined(separator: ", ")
                return "\(builtin(name))(\(arguments))"
            case .userCall(let name, let subscripts, let args):
                let arguments = (subscripts + args).map { expression($0) }.joined(separator: ", ")
                return "\(functionName(name))(\(arguments))"
            case .sum:
                return emitSumHelper(expr)
            }
        }

        /// `\sum_{s=a}^{b} body` → `static float sum_N(free vars…)` with an inclusive integer
        /// loop, capped like the CPU evaluator. Nested sums recurse first, so inner helpers
        /// land earlier in `helpers` and are defined before use.
        private mutating func emitSumHelper(_ expr: PixelExpr) -> String {
            guard case .sum(let indexVariable, let lower, let upper, let body) = expr else { return "0.0f" }
            let freeVariables = expr.freeVariables().sorted()
            let parameterList = freeVariables.map { "float \(variable($0))" }.joined(separator: ", ")
            let lowerCode = expression(lower)
            let upperCode = expression(upper)
            let bodyCode = expression(body)
            let name = "sum_\(helperCount)"
            helperCount += 1
            helpers.append("""
            static float \(name)(\(parameterList)) {
                float lo = \(lowerCode);
                float hi = \(upperCode);
                if (isnan(lo) || isnan(hi) || isinf(lo) || isinf(hi)) return NAN;
                int start = int(rint(lo));
                int end = min(int(rint(hi)), start + \(PixelFormulaEvaluator.maxSumIterations - 1));
                float total = 0.0f;
                for (int i = start; i <= end; ++i) {
                    float \(variable(indexVariable)) = float(i);
                    total += \(bodyCode);
                }
                return total;
            }
            """)
            let arguments = freeVariables.map { variable($0) }.joined(separator: ", ")
            return "\(name)(\(arguments))"
        }

        // MARK: Naming

        private func variable(_ name: String) -> String { "v_\(name)" }
        private func functionName(_ name: String) -> String { "fn_\(name)" }

        private func builtin(_ name: String) -> String {
            switch name {
            case "ln", "log": return "log"
            case "abs": return "fabs"
            case "arctan": return "atan"
            case "arcsin": return "asin"
            case "arccos": return "acos"
            default: return name
            }
        }

        private func literal(_ value: Double) -> String {
            if value == value.rounded(), abs(value) < 1e9 {
                return "\(Int(value)).0f"
            }
            return "\(value)f"
        }
    }
}
