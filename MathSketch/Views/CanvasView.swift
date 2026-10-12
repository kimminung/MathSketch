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

    /// Picks the element whose actual rendered geometry is closest to the tap, not just the
    /// topmost whose padded bounding box happens to contain it — a padded-box test made
    /// adjacent or overlapping shapes impossible to tell apart (tapping right next to shape B
    /// would keep selecting shape A if A's inflated box reached that far). Ties within 0.5pt
    /// fall back to z-order (topmost wins).
    private func elementID(at location: CGPoint) -> UUID? {
        let maxDistance: CGFloat = 28
        var best: (id: UUID, distance: CGFloat, zIndex: Int)?
        for item in fitted {
            let distance = distanceToShape(location: location, item: item)
            guard distance <= maxDistance else { continue }
            if let current = best {
                if distance < current.distance - 0.5 ||
                    (abs(distance - current.distance) <= 0.5 && item.element.zIndex > current.zIndex) {
                    best = (item.element.id, distance, item.element.zIndex)
                }
            } else {
                best = (item.element.id, distance, item.element.zIndex)
            }
        }
        return best?.id
    }

    private func distanceToShape(location: CGPoint, item: SketchCanvasRenderer.FittedElement) -> CGFloat {
        switch item.element.shapeKind.renderStyle {
        case .point:
            guard let p = item.points.first else { return .greatestFiniteMagnitude }
            return hypot(location.x - p.x, location.y - p.y)
        case .fill:
            if pointInPolygon(location, polygon: item.points) { return 0 }
            return distanceToPolyline(location, points: item.points, closed: true)
        case .stroke:
            return distanceToPolyline(location, points: item.points, closed: item.element.shapeKind.isClosed)
        }
    }

    private func distanceToPolyline(_ p: CGPoint, points: [CGPoint], closed: Bool) -> CGFloat {
        guard points.count > 1 else {
            guard let only = points.first else { return .greatestFiniteMagnitude }
            return hypot(p.x - only.x, p.y - only.y)
        }
        var minDistance = CGFloat.greatestFiniteMagnitude
        for i in 0..<(points.count - 1) {
            minDistance = min(minDistance, distanceToSegment(p, points[i], points[i + 1]))
        }
        if closed, let first = points.first, let last = points.last {
            minDistance = min(minDistance, distanceToSegment(p, last, first))
        }
        return minDistance
    }

    private func distanceToSegment(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let abx = b.x - a.x, aby = b.y - a.y
        let lengthSquared = abx * abx + aby * aby
        guard lengthSquared > 0 else { return hypot(p.x - a.x, p.y - a.y) }
        var t = ((p.x - a.x) * abx + (p.y - a.y) * aby) / lengthSquared
        t = max(0, min(1, t))
        let projX = a.x + t * abx, projY = a.y + t * aby
        return hypot(p.x - projX, p.y - projY)
    }

    private func pointInPolygon(_ p: CGPoint, polygon: [CGPoint]) -> Bool {
        guard polygon.count > 2 else { return false }
        var inside = false
        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let pi = polygon[i], pj = polygon[j]
            if (pi.y > p.y) != (pj.y > p.y),
               p.x < (pj.x - pi.x) * (p.y - pi.y) / (pj.y - pi.y) + pi.x {
                inside.toggle()
            }
            j = i
        }
        return inside
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
                // Only enters the undo stack once the finger has actually moved — a plain tap
                // that merely selects a shape (translation ~0) shouldn't burn an undo entry.
                if abs(value.translation.width) > 1 || abs(value.translation.height) > 1 {
                    model.beginContinuousEdit()
                }
                let dx = Double(value.translation.width) / Double(scale)
                let dy = -Double(value.translation.height) / Double(scale)
                model.updateSelectedTransform { t in
                    t.translateX = start.translateX + dx
                    t.translateY = start.translateY + dy
                }
            }
            .onEnded { _ in
                model.endContinuousEdit()
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
                if abs(value.magnification - 1) > 0.01 { model.beginContinuousEdit() }
                model.updateSelectedTransform { t in
                    t.scaleX = start.scaleX * value.magnification
                    t.scaleY = start.scaleY * value.magnification
                }
            }
            .onEnded { _ in
                model.endContinuousEdit()
                scaleGestureStart = nil
            }
    }

    private var rotateGesture: some Gesture {
        RotateGesture()
            .onChanged { value in
                guard model.selectedElementID != nil else { return }
                if rotateGestureStart == nil { rotateGestureStart = model.selectedElement?.transform.rotationDegrees }
                guard let start = rotateGestureStart else { return }
                if abs(value.rotation.degrees) > 0.5 { model.beginContinuousEdit() }
                model.updateSelectedTransform { t in
                    t.rotationDegrees = start + value.rotation.degrees
                }
            }
            .onEnded { _ in
                model.endContinuousEdit()
                rotateGestureStart = nil
            }
    }
}
