import Testing
import CoreGraphics
@testable import MathSketch

struct MathEngineTests {
    @Test func lexerTokenizesBasicExpression() throws {
        var lexer = MathLexer("3.5 + r·2")
        let tokens = try lexer.tokenize()
        #expect(tokens.count == 6) // 3.5, +, r, ·, 2, end
    }

    @Test func parserPowerIsRightAssociative() throws {
        // 2^3^2 = 2^(3^2) = 512, not (2^3)^2 = 64
        let expr = try MathParser.parse("2^3^2")
        #expect(try MathEvaluator.evaluate(expr) == 512)
    }

    @Test func unaryMinusHasLowerPrecedenceThanPower() throws {
        // -2^2 = -(2^2) = -4, not (-2)^2 = 4
        let expr = try MathParser.parse("-2^2")
        #expect(try MathEvaluator.evaluate(expr) == -4)
    }

    @Test func constantsAndFunctionsEvaluate() throws {
        let expr = try MathParser.parse("sqrt(16) + pi")
        let value = try MathEvaluator.evaluate(expr)
        #expect(abs(value - (4 + Double.pi)) < 1e-9)
    }

    @Test func divisionByZeroThrows() throws {
        let expr = try MathParser.parse("1/0")
        #expect(throws: MathEvaluationError.self) {
            _ = try MathEvaluator.evaluate(expr)
        }
    }
}

struct SketchFormulaRoundTripTests {
    @Test(arguments: ShapeKind.allCases)
    func defaultElementRoundTrips(kind: ShapeKind) throws {
        let element = SketchElement(shapeKind: kind, zIndex: 0)
        let text = SketchFormulaFormatter.format([element])
        let parsed = try SketchFormulaParser.parse(text)
        #expect(parsed.count == 1)
        #expect(parsed.first?.shapeKind == kind)
        for spec in kind.parameterSchema {
            // NumberText.format rounds to 3 decimals for compact, human-readable formulas
            // (PRD FR-5) — allow for that intentional display rounding, not exact equality.
            let original = element.shapeParameters[spec.name] ?? spec.defaultValue
            let roundTripped = parsed.first?.shapeParameters[spec.name] ?? spec.defaultValue
            #expect(abs(original - roundTripped) < 2e-3)
        }
    }

    @Test func transformedElementRoundTrips() throws {
        var element = SketchElement(shapeKind: .star, zIndex: 0)
        element.transform = ElementTransform(translateX: 120, translateY: 60, scaleX: 1.2,
                                              scaleY: 0.8, rotationDegrees: 35, shearX: 0, shearY: 0.15)
        let parsed = try SketchFormulaParser.parse(SketchFormulaFormatter.format([element]))
        #expect(parsed.count == 1)
        #expect(parsed.first?.transform == element.transform)
    }

    @Test func multiElementFormulaJoinsWithPlus() throws {
        let a = SketchElement(shapeKind: .circle, zIndex: 0)
        var b = SketchElement(shapeKind: .star, zIndex: 1)
        b.transform.rotationDegrees = 10
        b.transform.translateX = -80
        let text = SketchFormulaFormatter.format([a, b])
        #expect(text.contains(" + "))
        let parsed = try SketchFormulaParser.parse(text)
        #expect(parsed.map(\.shapeKind) == [.circle, .star])
    }

    @Test func colorIsNeverSerialized() {
        var element = SketchElement(shapeKind: .plane, zIndex: 0)
        element.color = ElementColor(red: 1, green: 0, blue: 0)
        let text = SketchFormulaFormatter.format([element])
        #expect(!text.contains("color"))
        #expect(!text.contains("#"))
    }

    @Test func unknownShapeThrows() {
        #expect(throws: SketchFormulaError.self) {
            _ = try SketchFormulaParser.parse("hexagonBlob(r: 10)")
        }
    }

    @Test func namedArgumentAcceptsArithmeticExpression() throws {
        let parsed = try SketchFormulaParser.parse("circle(r: 20*2)")
        #expect(parsed.first?.shapeParameters["r"] == 40)
    }

    @Test func tooManyElementsThrows() {
        let text = Array(repeating: "point(x: 0, y: 0)", count: 201).joined(separator: " + ")
        #expect(throws: SketchFormulaError.self) {
            _ = try SketchFormulaParser.parse(text)
        }
    }
}

struct ElementTransformTests {
    @Test func identityLeavesPointsUnchanged() {
        let points = [CGPoint(x: 10, y: 20)]
        #expect(ElementTransform.identity.apply(to: points) == points)
    }

    @Test func rotate90DegreesMapsXAxisToYAxis() {
        var transform = ElementTransform.identity
        transform.rotationDegrees = 90
        let result = transform.apply(to: [CGPoint(x: 10, y: 0)])
        #expect(abs(result[0].x - 0) < 1e-9)
        #expect(abs(result[0].y - 10) < 1e-9)
    }

    @Test func pointShapeIgnoresScaleRotateShearButKeepsTranslate() {
        var transform = ElementTransform.identity
        transform.scaleX = 5
        transform.rotationDegrees = 45
        transform.shearX = 0.5
        transform.translateX = 100
        let result = transform.apply(to: [CGPoint(x: 3, y: 4)], forPointShape: true)
        #expect(result[0].x == 103)
        #expect(result[0].y == 4)
    }

    @Test func clampingKeepsScaleAndShearInRange() {
        var transform = ElementTransform(scaleX: 50, scaleY: -5, shearX: 10, shearY: -10)
        transform.clamped()
        #expect(transform.scaleX == ElementTransform.scaleRange.upperBound)
        #expect(transform.scaleY == ElementTransform.scaleRange.lowerBound)
        #expect(transform.shearX == ElementTransform.shearRange.upperBound)
        #expect(transform.shearY == ElementTransform.shearRange.lowerBound)
    }
}

struct ShapeKindTests {
    @Test func parameterResolutionClampsOutOfRangeValues() {
        let resolved = ShapeKind.circle.resolvedParameters(["r": 99_999])
        #expect(resolved["r"] == ShapeKind.circle.parameterSchema[0].range.upperBound)
    }

    @Test func parameterResolutionFillsMissingWithDefaults() {
        let resolved = ShapeKind.plane.resolvedParameters([:])
        #expect(resolved["w"] == 100)
        #expect(resolved["h"] == 60)
    }

    @Test(arguments: ShapeKind.allCases)
    func samplePointsNeverProduceNaNOrInfinite(kind: ShapeKind) {
        let points = kind.samplePoints(params: [:], sampleCount: 64)
        #expect(!points.isEmpty)
        #expect(points.allSatisfy { $0.x.isFinite && $0.y.isFinite })
    }
}

struct PaletteNamerTests {
    @Test func sameHexAlwaysResolvesToSameName() throws {
        let color = try #require(ElementColor(hex: "#FF6B35"))
        #expect(PaletteNamer.name(for: color) == PaletteNamer.name(for: color))
    }

    @Test func exactCatalogColorMatchesItself() throws {
        let entry = PaletteNamer.catalog[5]
        let color = try #require(ElementColor(hex: entry.hex))
        #expect(PaletteNamer.name(for: color) == entry.name)
    }
}

struct SavedSketchTests {
    @Test func makeRoundTripsElementsAndOmitsColorFromFormula() throws {
        let elements = [SketchElement(shapeKind: .circle, zIndex: 0)]
        let sketch = try #require(SavedSketch.make(title: "테스트", elements: elements, thumbnailData: nil))
        #expect(sketch.elements.first?.shapeKind == .circle)
        #expect(!sketch.formulaText.contains("color"))
        #expect(sketch.paletteHexes.count == 1)
    }
}
