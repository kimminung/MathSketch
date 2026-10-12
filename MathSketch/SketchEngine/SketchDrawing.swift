import SwiftUI

/// Shared draw routine used by both the live CanvasView and the gallery-save thumbnail
/// renderer, so the two never visually drift apart.
nonisolated enum SketchDrawing {
    static func draw(_ item: SketchCanvasRenderer.FittedElement, into context: inout GraphicsContext,
                      selected: Bool = false, selectionColor: Color = .accentColor) {
        switch item.element.shapeKind.renderStyle {
        case .point:
            guard let p = item.points.first else { return }
            let r: CGFloat = 6
            context.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                         with: .color(item.element.color.color))
        case .stroke:
            let path = SketchCanvasRenderer.path(for: item.points, closed: item.element.shapeKind.isClosed)
            context.stroke(path, with: .color(item.element.color.color), lineWidth: selected ? 3 : 2)
        case .fill:
            let path = SketchCanvasRenderer.path(for: item.points, closed: true)
            context.fill(path, with: .color(item.element.color.color))
            if selected { context.stroke(path, with: .color(selectionColor), lineWidth: 2) }
        }
    }
}
