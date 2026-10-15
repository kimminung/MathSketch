import Testing
import CoreGraphics
import Foundation
@testable import MathSketch

/// PRD FR-10 — pixel-color formulas: LaTeX subset parsing, CPU semantics, MSL generation and
/// GPU/CPU agreement on the bundled sample.
struct PixelFormulaParserTests {
    private func value(_ latex: String) throws -> [Double] {
        let program = try PixelFormulaParser.parse(latex)
        return PixelFormulaEvaluator(program: program).channelValues(m: 0, n: 0)
    }

    @Test func preprocessorNormalizesDelimiters() {
        let text = LaTeXPreprocessor.normalize(#"\mathrm{rgb}\Big(\left|x\right|\,\cdot 2 × 3\Big)"#)
        #expect(text == "rgb(⟦x⟧ * 2 * 3)")
    }

    @Test func tokenizerSplitsLettersIndividually() throws {
        var tokenizer = LaTeXTokenizer("us^2 + rgb(")
        let kinds = try tokenizer.tokenize().map(\.kind)
        #expect(kinds == [.letter("u"), .letter("s"), .caret, .number(2), .plus, .rgb, .leftParen, .end])
    }

    @Test func floorExpAbsFunctionMatchesHandComputedValues() throws {
        let latex = #"rgb(F(0.5), F(1.5), F(-0.1)), F(x) = \left\lfloor 255\, e^{-e^{-1000x}}\, |x|^{\,e^{-e^{1000(x-1)}}} \right\rfloor"#
        #expect(try value(latex) == [127, 255, 0])
    }

    @Test func sumIsInclusiveAndImplicitMultiplicationBindsTighterThanPlus() throws {
        let latex = #"rgb(\sum_{s=1}^{3} s^2 + 1, G(2, 3), \sin^2(1) + \cos^2(1)), G(u, s) = us^2"#
        let channels = try value(latex)
        #expect(channels[0] == 15)   // (1 + 4 + 9) + 1 — the sum body is one term
        #expect(channels[1] == 18)   // u·s² = 2·9
        #expect(abs(channels[2] - 1) < 1e-12)
    }

    @Test func bareAbsoluteValueBarsNestAndMultiply() throws {
        let channels = try value(#"rgb(\frac{1}{|-2|}, |{-3}| |2|, \left|\frac{-6}{|3|}\right|)"#)
        #expect(channels == [0.5, 6, 2])
    }

    @Test func eCaretBecomesExpAndPiIsConstant() throws {
        let channels = try value(#"rgb(e^{0}, \pi, 2^{3})"#)
        #expect(channels[0] == 1)
        #expect(abs(channels[1] - Double.pi) < 1e-12)
        #expect(channels[2] == 8)
    }

    @Test func sampleFormulaParsesCompletely() throws {
        let program = try PixelFormulaParser.parse(PixelFormulaSamples.sample)
        #expect(program.width == 2000)
        #expect(program.height == 1200)
        #expect(program.channels.count == 3)
        #expect(program.definitionOrder == ["F", "H", "B", "T", "K", "A", "L", "U", "V", "P", "Q"])
        #expect(program.functions["L"]?.subscriptParameters == ["u", "s"])
        #expect(program.functions["L"]?.parameters == ["x", "y"])
        #expect(program.functions["H"]?.subscriptParameters == ["v"])
    }

    @Test func looksLikePixelFormulaDistinguishesDSL() {
        #expect(PixelFormulaParser.looksLikePixelFormula(PixelFormulaSamples.sample))
        #expect(!PixelFormulaParser.looksLikePixelFormula("circle(r: 1) · translate(1, 2)"))
    }

    @Test func undefinedNamesAreRejected() {
        // `Z(1)` parses as Z·1, so this surfaces as an unbound variable in the channel.
        #expect(throws: PixelFormulaError.self) {
            _ = try PixelFormulaParser.parse("rgb(Z(1), 0, 0)")
        }
        // A definition may only use its own parameters.
        #expect(throws: PixelFormulaError.self) {
            _ = try PixelFormulaParser.parse("rgb(F(m), 0, 0), F(x) = x + y")
        }
        // …while pixel coordinates m, n and constants are fine in channels.
        #expect(throws: Never.self) {
            _ = try PixelFormulaParser.parse(#"rgb(m, n, e\pi)"#)
        }
    }

    @Test func arityMismatchIsRejected() {
        #expect(throws: PixelFormulaError.self) {
            _ = try PixelFormulaParser.parse("rgb(F(1, 2), 0, 0), F(x) = x")
        }
    }

    @Test func missingRGBIsRejected() {
        #expect(throws: PixelFormulaError.self) {
            _ = try PixelFormulaParser.parse("F(x) = x")
        }
    }

    @Test func signedPowerKeepsSignForOddIntegerExponents() {
        #expect(PixelFormulaEvaluator.signedPow(-2, 3) == -8)
        #expect(PixelFormulaEvaluator.signedPow(-2, 2) == 4)
        #expect(PixelFormulaEvaluator.signedPow(-2, 0.5).isNaN)
    }
}

struct MetalShaderTranspilerTests {
    @Test func sourceDeclaresFunctionsSumsAndKernel() throws {
        let program = try PixelFormulaParser.parse(PixelFormulaSamples.sample)
        let source = MetalShaderTranspiler.source(for: program)
        #expect(source.contains("kernel void pixelFormula("))
        #expect(source.contains("static float fn_H(float v_v, float v_x, float v_y)"))
        #expect(source.contains("static float fn_L(float v_u, float v_s, float v_x, float v_y)"))
        #expect(source.contains("static float sum_0("))
        #expect(source.contains("static float sum_1("))
        #expect(!source.contains("v_e"))  // Euler's number is a constant, never a variable
    }

    @Test func integerPowersUseRepeatedMultiplication() throws {
        let program = try PixelFormulaParser.parse(#"rgb(m^2, m^{-3}, m^{n})"#)
        let source = MetalShaderTranspiler.source(for: program)
        #expect(source.contains("ipow(v_m, 2)"))
        #expect(source.contains("ipow(v_m, -3)"))
        #expect(source.contains("spow(v_m, v_n)"))
    }

    @Test func sampleShaderCompilesAndAgreesWithCPUEvaluator() async throws {
        let renderer = PixelFormulaRenderer.shared
        try #require(renderer.isGPUAvailable, "Metal 장치가 없는 환경 — GPU 비교는 건너뜁니다")
        let program = try PixelFormulaParser.parse(PixelFormulaSamples.sample)
        let image = try await renderer.render(program, downsample: 20)   // 100 × 60
        #expect(image.width == 100)
        #expect(image.height == 60)

        let evaluator = PixelFormulaEvaluator(program: program)
        let data = try #require(image.dataProvider?.data)
        let bytes = try #require(CFDataGetBytePtr(data))
        var mismatches = 0
        var samples = 0
        for py in stride(from: 0, to: image.height, by: 6) {
            for px in stride(from: 0, to: image.width, by: 10) {
                let m = (Double(px) + 0.5) * 20 + 0.5
                let n = (Double(py) + 0.5) * 20 + 0.5
                let cpu = evaluator.pixelColor(m: m, n: n)
                let index = (py * image.width + px) * 4
                let gpu = (bytes[index], bytes[index + 1], bytes[index + 2])
                samples += 1
                // float32 vs double on 50-term chaotic sums: allow a few pixels to disagree
                // near the shaded discs, but the flat regions must match exactly.
                if abs(Int(gpu.0) - Int(cpu.r)) > 8 || abs(Int(gpu.1) - Int(cpu.g)) > 8 || abs(Int(gpu.2) - Int(cpu.b)) > 8 {
                    mismatches += 1
                }
            }
        }
        #expect(samples == 100)
        #expect(mismatches <= 3)
    }
}

struct PixelFormulaArtworkTests {
    @Test func artworkRoundTripsThroughJSON() throws {
        let program = try PixelFormulaParser.parse(PixelFormulaSamples.sample)
        let artwork = PixelFormulaArtwork(source: PixelFormulaSamples.sample, program: program)
        let data = try JSONEncoder().encode(artwork)
        let decoded = try JSONDecoder().decode(PixelFormulaArtwork.self, from: data)
        #expect(decoded == artwork)
        #expect(decoded.definitionCount == 11)
        #expect(decoded.sizeCaption == "2000 × 1200")
    }

    @Test func savedSketchKeepsPixelFormula() throws {
        let program = try PixelFormulaParser.parse(PixelFormulaSamples.sample)
        let artwork = PixelFormulaArtwork(source: PixelFormulaSamples.sample, program: program)
        let sketch = try #require(SavedSketch.make(title: "픽셀", elements: [], pixelFormula: artwork, thumbnailData: nil))
        #expect(sketch.pixelFormula == artwork)
        #expect(sketch.elementCount == 0)
        #expect(sketch.formulaText.isEmpty)
    }
}
