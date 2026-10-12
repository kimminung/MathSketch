import CoreGraphics
import Foundation

nonisolated struct SketchElement: Identifiable, Codable, Sendable, Equatable {
    var id: UUID = UUID()
    var shapeKind: ShapeKind
    var shapeParameters: [String: Double]
    var transform: ElementTransform = .identity
    var color: ElementColor = .defaultNeutral
    var zIndex: Int = 0

    init(id: UUID = UUID(), shapeKind: ShapeKind, shapeParameters: [String: Double] = [:],
         transform: ElementTransform = .identity, color: ElementColor = .defaultNeutral, zIndex: Int = 0) {
        self.id = id
        self.shapeKind = shapeKind
        self.shapeParameters = shapeKind.resolvedParameters(shapeParameters)
        self.transform = transform
        self.color = color
        self.zIndex = zIndex
    }

    /// Local-space points (before transform), resolved against the shape's parameter schema.
    func localSamplePoints(sampleCount: Int = 128) -> [CGPoint] {
        shapeKind.samplePoints(params: shapeParameters, sampleCount: sampleCount)
    }

    /// World-space points after the element's own transform (not yet fit to a canvas rect).
    func worldSamplePoints(sampleCount: Int = 128) -> [CGPoint] {
        transform.apply(to: localSamplePoints(sampleCount: sampleCount), forPointShape: shapeKind == .point)
    }
}
