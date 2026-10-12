import CoreGraphics
import SwiftUI

/// Stateless renderer (PRD FR-6), analogous to the reference project's MathCanvasRenderer:
/// fits every element's sampled points into one shared bounding box → view rect transform, then
/// hands back ready-to-stroke/fill `Path`s. `.line` is special-cased — an "infinite" line would
/// otherwise dominate the shared bounding box, so it is clipped directly against the view rect
/// in screen space instead of participating in the fit.
nonisolated enum SketchCanvasRenderer {
    struct FittedElement {
        let element: SketchElement
        let points: [CGPoint]
    }

    /// World↔view mapping shared by `fit`, `fitScale` (drag-delta conversion) and `worldPoint`
    /// (palette drop-location conversion), so all three agree on the same transform.
    private struct FitContext {
        let scale: CGFloat
        let boxCenter: CGPoint
        let viewCenter: CGPoint

        func toView(_ p: CGPoint) -> CGPoint {
            CGPoint(x: viewCenter.x + (p.x - boxCenter.x) * scale, y: viewCenter.y - (p.y - boxCenter.y) * scale)
        }

        func toWorld(_ p: CGPoint) -> CGPoint {
            guard scale > 0 else { return boxCenter }
            return CGPoint(x: boxCenter.x + (p.x - viewCenter.x) / scale, y: boxCenter.y - (p.y - viewCenter.y) / scale)
        }
    }

    static func fit(elements: [SketchElement], in rect: CGRect, sampleCount: Int = 128) -> [FittedElement] {
        guard rect.width > 0, rect.height > 0 else { return [] }
        let boundedElements = elements.filter { $0.shapeKind != .line }
        let worldPoints = boundedElements.map { ($0, $0.worldSamplePoints(sampleCount: sampleCount)) }
        let ctx = fitContext(worldPoints: worldPoints.flatMap(\.1), in: rect)

        var result: [FittedElement] = worldPoints.map { FittedElement(element: $0.0, points: $0.1.map(ctx.toView)) }

        for lineElement in elements where lineElement.shapeKind == .line {
            let m = lineElement.shapeParameters["m"] ?? 1
            let b = lineElement.shapeParameters["b"] ?? 0
            let anchorWorld = lineElement.transform.apply(to: [CGPoint(x: 0, y: b)]).first ?? CGPoint(x: 0, y: b)
            let directionWorld = lineElement.transform.applyToDirection(CGVector(dx: 1, dy: m).normalized)
            let anchorView = ctx.toView(anchorWorld)
            let directionView = CGVector(dx: directionWorld.dx * ctx.scale, dy: -directionWorld.dy * ctx.scale).normalized
            if let (a, b) = clipLine(point: anchorView, direction: directionView, to: rect) {
                result.append(FittedElement(element: lineElement, points: [a, b]))
            }
        }
        return result.sorted { $0.element.zIndex < $1.element.zIndex }
    }

    /// Scale factor used by `fit`, exposed so a drag gesture can convert a view-space delta
    /// into a world-space translate delta without re-deriving the whole fit.
    static func fitScale(elements: [SketchElement], in rect: CGRect, sampleCount: Int = 128) -> CGFloat {
        fitContext(worldPoints: worldPointsForFit(elements: elements, sampleCount: sampleCount), in: rect).scale
    }

    /// Inverse of the fit transform — converts a palette-drop location (view space) into the
    /// world-space coordinates a new element's `translate` should use.
    static func worldPoint(fromView viewPoint: CGPoint, elements: [SketchElement], in rect: CGRect, sampleCount: Int = 128) -> CGPoint {
        fitContext(worldPoints: worldPointsForFit(elements: elements, sampleCount: sampleCount), in: rect).toWorld(viewPoint)
    }

    static func path(for points: [CGPoint], closed: Bool) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        if closed { path.closeSubpath() }
        return path
    }

    // MARK: - Geometry helpers

    private static func worldPointsForFit(elements: [SketchElement], sampleCount: Int) -> [CGPoint] {
        elements.filter { $0.shapeKind != .line }.flatMap { $0.worldSamplePoints(sampleCount: sampleCount) }
    }

    private static func fitContext(worldPoints: [CGPoint], in rect: CGRect) -> FitContext {
        let box = boundingBox(of: worldPoints) ?? CGRect(x: -100, y: -100, width: 200, height: 200)
        let scale = fitScale(box: box, rect: rect)
        return FitContext(scale: scale, boxCenter: CGPoint(x: box.midX, y: box.midY), viewCenter: CGPoint(x: rect.midX, y: rect.midY))
    }

    /// Exact bounding box — width/height may legitimately be 0 (a single point, a horizontal
    /// line). Centering (`box.midX/midY`) must use this true box; only `fitScale` below clamps
    /// the denominator, otherwise a near-zero box drives the scale to absurd values and a tiny
    /// off-center nudge gets magnified into the shape flying off to a corner.
    private static func boundingBox(of points: [CGPoint]) -> CGRect? {
        guard let first = points.first else { return nil }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for p in points {
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minY = min(minY, p.y); maxY = max(maxY, p.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private static func fitScale(box: CGRect, rect: CGRect) -> CGFloat {
        guard rect.width > 0, rect.height > 0 else { return 1 }
        let minExtent: CGFloat = 40
        let width = max(box.width, minExtent)
        let height = max(box.height, minExtent)
        return min(rect.width / width, rect.height / height) * 0.92
    }

    /// Liang-Barsky parametric clip of the infinite line `point + t·direction` against `rect`.
    private static func clipLine(point: CGPoint, direction: CGVector, to rect: CGRect) -> (CGPoint, CGPoint)? {
        let checks: [(p: Double, q: Double)] = [
            (-direction.dx, point.x - rect.minX),
            (direction.dx, rect.maxX - point.x),
            (-direction.dy, point.y - rect.minY),
            (direction.dy, rect.maxY - point.y),
        ]
        var tMin = -Double.greatestFiniteMagnitude
        var tMax = Double.greatestFiniteMagnitude
        for (p, q) in checks {
            if p == 0 {
                if q < 0 { return nil }
            } else {
                let t = q / p
                if p < 0 { tMin = max(tMin, t) } else { tMax = min(tMax, t) }
            }
        }
        guard tMin <= tMax else { return nil }
        let a = CGPoint(x: point.x + tMin * direction.dx, y: point.y + tMin * direction.dy)
        let b = CGPoint(x: point.x + tMax * direction.dx, y: point.y + tMax * direction.dy)
        return (a, b)
    }
}
