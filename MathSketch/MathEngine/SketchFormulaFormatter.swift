import Foundation

/// Serializes `[SketchElement]` into the PRD FR-5 SketchFormula DSL string — geometry only,
/// color is never emitted (FR-4). Identity transform components are omitted for compactness;
/// `SketchFormulaParser` applies the same identity defaults when a modifier is absent, so
/// `parse(format(elements))` round-trips.
nonisolated enum SketchFormulaFormatter {
    static func format(_ elements: [SketchElement]) -> String {
        elements.sorted { $0.zIndex < $1.zIndex }
            .map(formatElement)
            .joined(separator: " + ")
    }

    private static func formatElement(_ element: SketchElement) -> String {
        var text = "\(element.shapeKind.rawValue)(\(formatShapeArgs(element)))"
        let t = element.transform
        if t.scaleX != 1 || t.scaleY != 1 {
            text += " · scale(\(NumberText.format(t.scaleX)), \(NumberText.format(t.scaleY)))"
        }
        if t.rotationDegrees != 0 {
            text += " · rotate(\(NumberText.format(t.rotationDegrees)))"
        }
        if t.shearX != 0 || t.shearY != 0 {
            text += " · shear(\(NumberText.format(t.shearX)), \(NumberText.format(t.shearY)))"
        }
        if t.translateX != 0 || t.translateY != 0 {
            text += " · translate(\(NumberText.format(t.translateX)), \(NumberText.format(t.translateY)))"
        }
        return text
    }

    private static func formatShapeArgs(_ element: SketchElement) -> String {
        element.shapeKind.parameterSchema.map { spec in
            let value = element.shapeParameters[spec.name] ?? spec.defaultValue
            return "\(spec.name): \(NumberText.format(value))"
        }.joined(separator: ", ")
    }
}
