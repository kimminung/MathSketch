import Foundation

/// Display-only typesetting of the composite picture as a single mathematical narrative —
/// a "set of points" statement built from each element's own parametric curve, annotated with
/// its transform in natural language instead of DSL call syntax. Purely cosmetic: never used
/// for parsing or the round-trip (that stays `SketchFormulaFormatter`'s job); this exists only
/// so the formula panel *reads* like a hand-typeset equation rather than source code.
nonisolated enum ArtisticFormulaFormatter {
    static func narrative(for elements: [SketchElement]) -> String {
        guard !elements.isEmpty else { return "" }
        let sorted = elements.sorted { $0.zIndex < $1.zIndex }
        let header = "이 그림을 이루는 점들의 집합:"
        let lines = sorted.enumerated().map { index, element in
            componentLine(index: sorted.count > 1 ? index + 1 : nil, element: element)
        }
        return ([header] + lines).joined(separator: "\n")
    }

    private static func componentLine(index: Int?, element: SketchElement) -> String {
        let label = index.map { "𝑃\($0.subscriptDigits)(𝑡) : " } ?? "𝑃(𝑡) : "
        let equation = element.shapeKind.formulaExpression(params: element.shapeParameters)
        let annotation = transformAnnotation(element.transform)
        return annotation.isEmpty ? "  \(label)\(equation)" : "  \(label)\(equation)   —  \(annotation)"
    }

    private static func transformAnnotation(_ t: ElementTransform) -> String {
        var parts: [String] = []
        if t.scaleX != 1 || t.scaleY != 1 {
            parts.append("배율 \(NumberText.format(t.scaleX))×\(NumberText.format(t.scaleY))")
        }
        if t.rotationDegrees != 0 {
            parts.append("회전 \(NumberText.format(t.rotationDegrees))°")
        }
        if t.shearX != 0 || t.shearY != 0 {
            parts.append("비틀기 (\(NumberText.format(t.shearX)), \(NumberText.format(t.shearY)))")
        }
        if t.translateX != 0 || t.translateY != 0 {
            parts.append("이동 (\(NumberText.format(t.translateX)), \(NumberText.format(t.translateY)))")
        }
        return parts.joined(separator: ", ")
    }
}

private extension Int {
    var subscriptDigits: String {
        let map: [Character: Character] = ["0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄",
                                            "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉"]
        return String(self).compactMap { map[$0] }.map(String.init).joined()
    }
}
