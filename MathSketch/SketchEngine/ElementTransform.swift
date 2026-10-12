import CoreGraphics
import Foundation

/// PRD FR-2: translate/scale(non-uniform)/rotate/shear("비틀기"), applied in a fixed order
/// `P' = R(θ)·Sh(shx,shy)·S(sx,sy)·P + T`.
nonisolated struct ElementTransform: Codable, Sendable, Equatable {
    var translateX: Double = 0
    var translateY: Double = 0
    var scaleX: Double = 1
    var scaleY: Double = 1
    /// Rotation in degrees, wrapped to -180...180.
    var rotationDegrees: Double = 0
    var shearX: Double = 0
    var shearY: Double = 0

    static let identity = ElementTransform()

    static let scaleRange: ClosedRange<Double> = 0.1...8.0
    static let shearRange: ClosedRange<Double> = -1.0...1.0

    var isIdentity: Bool { self == .identity }

    /// Scale and shear are meaningless for a dimensionless `.point` (see PRD FR-2 note) — only
    /// translation moves it. Callers should still store whatever the user dialed in (so the
    /// inspector doesn't silently reset their gesture), but geometry application skips them.
    func apply(to points: [CGPoint], forPointShape: Bool = false) -> [CGPoint] {
        let theta = rotationDegrees * .pi / 180
        let cosT = cos(theta), sinT = sin(theta)
        return points.map { point in
            var x = point.x, y = point.y
            if !forPointShape {
                x *= scaleX
                y *= scaleY
                let shearedX = x + shearX * y
                let shearedY = y + shearY * x
                x = shearedX
                y = shearedY
                let rotatedX = x * cosT - y * sinT
                let rotatedY = x * sinT + y * cosT
                x = rotatedX
                y = rotatedY
            }
            return CGPoint(x: x + translateX, y: y + translateY)
        }
    }

    /// The scale/rotate/shear decomposition applied to a single direction vector (no translate) —
    /// used by the `.line` special-cased renderer to find the line's world-space direction.
    func applyToDirection(_ vector: CGVector) -> CGVector {
        var x = vector.dx * scaleX
        var y = vector.dy * scaleY
        let shearedX = x + shearX * y
        let shearedY = y + shearY * x
        x = shearedX
        y = shearedY
        let theta = rotationDegrees * .pi / 180
        let cosT = cos(theta), sinT = sin(theta)
        return CGVector(dx: x * cosT - y * sinT, dy: x * sinT + y * cosT)
    }

    mutating func clamped() {
        scaleX = Self.scaleRange.clamped(scaleX)
        scaleY = Self.scaleRange.clamped(scaleY)
        shearX = Self.shearRange.clamped(shearX)
        shearY = Self.shearRange.clamped(shearY)
        rotationDegrees = Self.wrap(rotationDegrees)
    }

    private static func wrap(_ degrees: Double) -> Double {
        var d = degrees.truncatingRemainder(dividingBy: 360)
        if d > 180 { d -= 360 }
        if d < -180 { d += 360 }
        return d
    }
}
