import SwiftUI

/// PRD FR-3/FR-6: drag moves the tapped element, pinch/rotate (MagnifyGesture/RotateGesture)
/// scale/rotate it, and dropping a palette chip adds a new element at the drop location.
/// Every gesture calls `SketchModel.updateSelectedTransform`, which recomputes the per-element
/// label instantly and only debounces the heavier composite-formula/draft-save work.
struct CanvasView: View {
    @Environment(SketchModel.self) private var model
    @State private var canvasSize: CGSize = .zero

    @State private var dragStartTransform: ElementTransform?
    @State private var fitScaleSnapshot: CGFloat?
    @State private var scaleGestureStart: ElementTransform?
    @State private var rotateGestureStart: Double?

    private var canvasRect: CGRect { CGRect(origin: .zero, size: canvasSize) }
    private var fitted: [SketchCanvasRenderer.FittedElement] {
        SketchCanvasRenderer.fit(elements: model.elements, in: canvasRect)
    }

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                // Uses the size Canvas just measured, not the mirrored `canvasSize` @State
                // (which lags one layout pass behind on first appearance and left the canvas
                // blank until the first touch) — gestures below still use `canvasSize` since
                // they can't run before the view is visible anyway.
                let liveRect = CGRect(origin: .zero, size: size)
                let liveFitted = SketchCanvasRenderer.fit(elements: model.elements, in: liveRect)
                for item in liveFitted {
                    SketchDrawing.draw(item, into: &context, selected: item.element.id == model.selectedElementID)
                }
                for item in liveFitted where item.element.id == model.selectedElementID {
                    if let box = boundingBox(item.points) {
                        context.stroke(Path(box.insetBy(dx: -8, dy: -8)), with: .color(.accentColor),
                                       style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    }
                }
            }
            .contentShape(Rectangle())
            .onAppear { canvasSize = geo.size }
            .onChange(of: geo.size) { _, newValue in canvasSize = newValue }
            .gesture(dragGesture)
            .simultaneousGesture(magnifyGesture)
            .simultaneousGesture(rotateGesture)
            .dropDestination(for: String.self) { items, location in
                guard let raw = items.first, let kind = ShapeKind(rawValue: raw) else { return false }
                let world = SketchCanvasRenderer.worldPoint(fromView: location, elements: model.elements, in: canvasRect)
                model.addElement(kind: kind, at: world)
                return true
            }
        }
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("스케치 캔버스, 요소 \(model.elements.count)개"))
    }

    private func elementID(at location: CGPoint) -> UUID? {
        for item in fitted.reversed() {
            if let box = boundingBox(item.points)?.insetBy(dx: -14, dy: -14), box.contains(location) {
                return item.element.id
            }
        }
        return nil
    }

    private func boundingBox(_ points: [CGPoint]) -> CGRect? {
        guard let first = points.first else { return nil }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for p in points {
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minY = min(minY, p.y); maxY = max(maxY, p.y)
        }
        return CGRect(x: minX, y: minY, width: max(maxX - minX, 1), height: max(maxY - minY, 1))
    }

    private var dragGesture: some Gesture {
        // minimumDistance 0 so a plain tap (no movement) still registers as a selection —
        // DragGesture otherwise never fires `onChanged` for a stationary touch-down/up.
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragStartTransform == nil {
                    guard let id = elementID(at: value.startLocation) else {
                        model.selectedElementID = nil
                        return
                    }
                    model.selectedElementID = id
                    dragStartTransform = model.selectedElement?.transform
                    fitScaleSnapshot = SketchCanvasRenderer.fitScale(elements: model.elements, in: canvasRect)
                }
                guard let start = dragStartTransform, let scale = fitScaleSnapshot, scale > 0 else { return }
                let dx = Double(value.translation.width) / Double(scale)
                let dy = -Double(value.translation.height) / Double(scale)
                model.updateSelectedTransform { t in
                    t.translateX = start.translateX + dx
                    t.translateY = start.translateY + dy
                }
            }
            .onEnded { _ in
                dragStartTransform = nil
                fitScaleSnapshot = nil
            }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                guard model.selectedElementID != nil else { return }
                if scaleGestureStart == nil { scaleGestureStart = model.selectedElement?.transform }
                guard let start = scaleGestureStart else { return }
                model.updateSelectedTransform { t in
                    t.scaleX = start.scaleX * value.magnification
                    t.scaleY = start.scaleY * value.magnification
                }
            }
            .onEnded { _ in scaleGestureStart = nil }
    }

    private var rotateGesture: some Gesture {
        RotateGesture()
            .onChanged { value in
                guard model.selectedElementID != nil else { return }
                if rotateGestureStart == nil { rotateGestureStart = model.selectedElement?.transform.rotationDegrees }
                guard let start = rotateGestureStart else { return }
                model.updateSelectedTransform { t in
                    t.rotationDegrees = start + value.rotation.degrees
                }
            }
            .onEnded { _ in rotateGestureStart = nil }
    }
}
