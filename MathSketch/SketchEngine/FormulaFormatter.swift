import Foundation

/// Human-readable label generator (PRD FR "사람이 읽는 수식 표기") — purely for display, distinct
/// from SketchFormulaFormatter which produces the round-trippable DSL text (Phase 1).
nonisolated enum FormulaFormatter {
    static func label(for element: SketchElement) -> String {
        var parts = [element.shapeKind.formulaExpression(params: element.shapeParameters)]
        let t = element.transform
        if t.scaleX != 1 || t.scaleY != 1 {
            parts.append("scale(\(NumberText.format(t.scaleX)), \(NumberText.format(t.scaleY)))")
        }
        if t.rotationDegrees != 0 {
            parts.append("rotate(\(NumberText.format(t.rotationDegrees)))")
        }
        if t.shearX != 0 || t.shearY != 0 {
            parts.append("shear(\(NumberText.format(t.shearX)), \(NumberText.format(t.shearY)))")
        }
        if t.translateX != 0 || t.translateY != 0 {
            parts.append("translate(\(NumberText.format(t.translateX)), \(NumberText.format(t.translateY)))")
        }
        return parts.joined(separator: " · ")
    }
}
