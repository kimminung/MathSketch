import CoreGraphics
import Foundation

nonisolated enum ShapeCategory: String, CaseIterable, Sendable {
    case basics = "기본 요소"
    case lines = "직선류"
    case closedShapes = "기본 폐도형"
    case trig = "삼각함수 곡선"
    case polar = "극좌표/기하 곡선"
}

nonisolated enum RenderStyle: String, Sendable {
    case point, stroke, fill
}

nonisolated struct ShapeParameterSpec: Sendable {
    let name: String
    let defaultValue: Double
    let range: ClosedRange<Double>
}

/// The 23-item shape catalog (PRD FR-1). Each case defines its own local-space parametric
/// curve `x(t), y(t)` for `t ∈ [0,1]`; the universal transform pipeline (scale/rotate/shear/
/// translate, see ElementTransform) is then layered on top uniformly for every kind.
nonisolated enum ShapeKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case point, line, plane
    case segment, ray, polyline, arc, quadBezier, cubicBezier
    case circle, ellipse, polygon, star
    case sine, cosine, lissajous
    case spiral, logSpiral, rose, cardioid, astroid, epicycloid, hypocycloid

    var id: String { rawValue }

    static var byCategory: [(category: ShapeCategory, kinds: [ShapeKind])] {
        ShapeCategory.allCases.map { category in
            (category, ShapeKind.allCases.filter { $0.category == category })
        }
    }

    var category: ShapeCategory {
        switch self {
        case .point, .line, .plane: return .basics
        case .segment, .ray, .polyline, .arc, .quadBezier, .cubicBezier: return .lines
        case .circle, .ellipse, .polygon, .star: return .closedShapes
        case .sine, .cosine, .lissajous: return .trig
        case .spiral, .logSpiral, .rose, .cardioid, .astroid, .epicycloid, .hypocycloid: return .polar
        }
    }

    var displayName: String {
        switch self {
        case .point: return "점"
        case .line: return "직선"
        case .plane: return "면"
        case .segment: return "선분"
        case .ray: return "반직선"
        case .polyline: return "꺾은선"
        case .arc: return "원호"
        case .quadBezier: return "2차 베지어"
        case .cubicBezier: return "3차 베지어"
        case .circle: return "원"
        case .ellipse: return "타원"
        case .polygon: return "정다각형"
        case .star: return "별다각형"
        case .sine: return "사인파"
        case .cosine: return "코사인파"
        case .lissajous: return "리사주 곡선"
        case .spiral: return "아르키메데스 나선"
        case .logSpiral: return "로그 나선"
        case .rose: return "장미 곡선"
        case .cardioid: return "카디오이드"
        case .astroid: return "아스트로이드"
        case .epicycloid: return "에피사이클로이드"
        case .hypocycloid: return "하이포사이클로이드"
        }
    }

    var renderStyle: RenderStyle {
        switch self {
        case .point: return .point
        case .plane: return .fill
        default: return .stroke
        }
    }

    var isClosed: Bool {
        switch self {
        case .plane, .circle, .ellipse, .polygon, .star, .lissajous, .rose, .cardioid, .astroid:
            return true
        default:
            return false
        }
    }

    /// Default sample resolution; a few kinds override with fewer/more in `sampleCount(for:)`.
    var baseSampleCount: Int {
        switch self {
        case .point: return 1
        case .segment, .ray: return 2
        case .polyline: return 3
        case .plane: return 4
        case .polygon, .star: return 0 // vertex count derived from parameters, see samplePoints
        default: return 128
        }
    }

    var parameterSchema: [ShapeParameterSpec] {
        switch self {
        case .point:
            return [.init(name: "x", defaultValue: 0, range: -2000...2000),
                    .init(name: "y", defaultValue: 0, range: -2000...2000)]
        case .line:
            return [.init(name: "m", defaultValue: 1, range: -1000...1000),
                    .init(name: "b", defaultValue: 0, range: -2000...2000)]
        case .plane:
            return [.init(name: "w", defaultValue: 100, range: 4...2000),
                    .init(name: "h", defaultValue: 60, range: 4...2000)]
        case .segment:
            return [.init(name: "x1", defaultValue: -50, range: -2000...2000),
                    .init(name: "y1", defaultValue: 0, range: -2000...2000),
                    .init(name: "x2", defaultValue: 50, range: -2000...2000),
                    .init(name: "y2", defaultValue: 0, range: -2000...2000)]
        case .ray:
            return [.init(name: "x0", defaultValue: 0, range: -2000...2000),
                    .init(name: "y0", defaultValue: 0, range: -2000...2000),
                    .init(name: "angle", defaultValue: 0, range: -360...360),
                    .init(name: "length", defaultValue: 100, range: 1...2000)]
        case .polyline:
            return [.init(name: "x1", defaultValue: -50, range: -2000...2000),
                    .init(name: "y1", defaultValue: 30, range: -2000...2000),
                    .init(name: "x2", defaultValue: 0, range: -2000...2000),
                    .init(name: "y2", defaultValue: -30, range: -2000...2000),
                    .init(name: "x3", defaultValue: 50, range: -2000...2000),
                    .init(name: "y3", defaultValue: 30, range: -2000...2000)]
        case .arc:
            return [.init(name: "r", defaultValue: 50, range: 1...1000),
                    .init(name: "startAngle", defaultValue: 0, range: -720...720),
                    .init(name: "endAngle", defaultValue: 180, range: -720...720)]
        case .quadBezier:
            return [.init(name: "cx", defaultValue: 0, range: -1000...1000),
                    .init(name: "cy", defaultValue: 50, range: -1000...1000),
                    .init(name: "x1", defaultValue: 50, range: -1000...1000),
                    .init(name: "y1", defaultValue: 0, range: -1000...1000)]
        case .cubicBezier:
            return [.init(name: "c1x", defaultValue: -25, range: -1000...1000),
                    .init(name: "c1y", defaultValue: 55, range: -1000...1000),
                    .init(name: "c2x", defaultValue: 25, range: -1000...1000),
                    .init(name: "c2y", defaultValue: -55, range: -1000...1000)]
        case .circle:
            return [.init(name: "r", defaultValue: 50, range: 1...1000)]
        case .ellipse:
            return [.init(name: "rx", defaultValue: 50, range: 1...1000),
                    .init(name: "ry", defaultValue: 30, range: 1...1000)]
        case .polygon:
            return [.init(name: "sides", defaultValue: 5, range: 3...12),
                    .init(name: "r", defaultValue: 50, range: 1...1000)]
        case .star:
            return [.init(name: "points", defaultValue: 5, range: 3...12),
                    .init(name: "rOuter", defaultValue: 50, range: 1...1000),
                    .init(name: "rInner", defaultValue: 20, range: 1...1000)]
        case .sine, .cosine:
            return [.init(name: "amplitude", defaultValue: 25, range: 1...500),
                    .init(name: "frequency", defaultValue: 2, range: 0.1...10),
                    .init(name: "phase", defaultValue: 0, range: -.pi...(.pi))]
        case .lissajous:
            return [.init(name: "a", defaultValue: 3, range: 1...12),
                    .init(name: "b", defaultValue: 2, range: 1...12),
                    .init(name: "delta", defaultValue: .pi / 2, range: -.pi...(.pi)),
                    .init(name: "scale", defaultValue: 50, range: 1...500)]
        case .spiral:
            return [.init(name: "a", defaultValue: 5, range: 0...100),
                    .init(name: "b", defaultValue: 2.5, range: 0.1...100),
                    .init(name: "turns", defaultValue: 3, range: 0.25...12)]
        case .logSpiral:
            return [.init(name: "a", defaultValue: 5, range: 0.1...100),
                    .init(name: "b", defaultValue: 0.19, range: 0.01...1),
                    .init(name: "turns", defaultValue: 2, range: 0.25...8)]
        case .rose:
            return [.init(name: "k", defaultValue: 4, range: 1...16),
                    .init(name: "r", defaultValue: 50, range: 1...500)]
        case .cardioid:
            return [.init(name: "a", defaultValue: 35, range: 1...500)]
        case .astroid:
            return [.init(name: "a", defaultValue: 50, range: 1...500)]
        case .epicycloid:
            return [.init(name: "R", defaultValue: 30, range: 1...200),
                    .init(name: "r", defaultValue: 10, range: 1...200),
                    .init(name: "turns", defaultValue: 6, range: 0.5...24)]
        case .hypocycloid:
            return [.init(name: "R", defaultValue: 50, range: 1...200),
                    .init(name: "r", defaultValue: 15, range: 1...200),
                    .init(name: "turns", defaultValue: 6, range: 0.5...24)]
        }
    }

    /// Fills missing keys with defaults and clamps every value to its declared range.
    func resolvedParameters(_ params: [String: Double]) -> [String: Double] {
        var result: [String: Double] = [:]
        for spec in parameterSchema {
            let raw = params[spec.name] ?? spec.defaultValue
            result[spec.name] = raw.isFinite ? spec.range.clamped(raw) : spec.defaultValue
        }
        return result
    }

    /// Local-space sample points for `t ∈ [0,1]`. The number of samples is `sampleCount`
    /// for continuous curves; vertex-based shapes (polygon/star/segment/…) derive their own count.
    func samplePoints(params rawParams: [String: Double], sampleCount: Int) -> [CGPoint] {
        let p = resolvedParameters(rawParams)
        switch self {
        case .point:
            return [CGPoint(x: p["x"]!, y: p["y"]!)]

        case .line:
            let m = p["m"]!, b = p["b"]!
            let halfLength = 600.0
            let direction = CGVector(dx: 1, dy: m).normalized
            let anchor = CGPoint(x: 0, y: b)
            return [anchor.offset(by: direction, scale: -halfLength),
                    anchor.offset(by: direction, scale: halfLength)]

        case .plane:
            let w = p["w"]!, h = p["h"]!
            return [CGPoint(x: -w / 2, y: -h / 2), CGPoint(x: w / 2, y: -h / 2),
                    CGPoint(x: w / 2, y: h / 2), CGPoint(x: -w / 2, y: h / 2),
                    CGPoint(x: -w / 2, y: -h / 2)]

        case .segment:
            return [CGPoint(x: p["x1"]!, y: p["y1"]!), CGPoint(x: p["x2"]!, y: p["y2"]!)]

        case .ray:
            let start = CGPoint(x: p["x0"]!, y: p["y0"]!)
            let angle = p["angle"]! * .pi / 180
            let end = CGPoint(x: start.x + cos(angle) * p["length"]!, y: start.y + sin(angle) * p["length"]!)
            return [start, end]

        case .polyline:
            return [CGPoint(x: p["x1"]!, y: p["y1"]!), CGPoint(x: p["x2"]!, y: p["y2"]!), CGPoint(x: p["x3"]!, y: p["y3"]!)]

        case .arc:
            let r = p["r"]!
            let start = p["startAngle"]! * .pi / 180
            let end = p["endAngle"]! * .pi / 180
            let n = max(sampleCount, 2)
            return (0..<n).map { i in
                let theta = start + (end - start) * Double(i) / Double(n - 1)
                return CGPoint(x: r * cos(theta), y: r * sin(theta))
            }

        case .quadBezier:
            let p0 = CGPoint(x: -50, y: 0), c = CGPoint(x: p["cx"]!, y: p["cy"]!), p1 = CGPoint(x: p["x1"]!, y: p["y1"]!)
            let n = max(sampleCount, 2)
            return (0..<n).map { i in
                let t = Double(i) / Double(n - 1)
                let mt = 1 - t
                let x = mt * mt * p0.x + 2 * mt * t * c.x + t * t * p1.x
                let y = mt * mt * p0.y + 2 * mt * t * c.y + t * t * p1.y
                return CGPoint(x: x, y: y)
            }

        case .cubicBezier:
            let p0 = CGPoint(x: -50, y: 0), p1 = CGPoint(x: 50, y: 0)
            let c1 = CGPoint(x: p["c1x"]!, y: p["c1y"]!), c2 = CGPoint(x: p["c2x"]!, y: p["c2y"]!)
            let n = max(sampleCount, 2)
            return (0..<n).map { i in
                let t = Double(i) / Double(n - 1)
                let mt = 1 - t
                let x = mt*mt*mt*p0.x + 3*mt*mt*t*c1.x + 3*mt*t*t*c2.x + t*t*t*p1.x
                let y = mt*mt*mt*p0.y + 3*mt*mt*t*c1.y + 3*mt*t*t*c2.y + t*t*t*p1.y
                return CGPoint(x: x, y: y)
            }

        case .circle:
            let r = p["r"]!
            let n = max(sampleCount, 8)
            return (0..<n).map { i in
                let theta = 2 * .pi * Double(i) / Double(n - 1)
                return CGPoint(x: r * cos(theta), y: r * sin(theta))
            }

        case .ellipse:
            let rx = p["rx"]!, ry = p["ry"]!
            let n = max(sampleCount, 8)
            return (0..<n).map { i in
                let theta = 2 * .pi * Double(i) / Double(n - 1)
                return CGPoint(x: rx * cos(theta), y: ry * sin(theta))
            }

        case .polygon:
            let sides = max(3, Int(p["sides"]!.rounded()))
            let r = p["r"]!
            return (0...sides).map { i in
                let theta = 2 * .pi * Double(i) / Double(sides) - .pi / 2
                return CGPoint(x: r * cos(theta), y: r * sin(theta))
            }

        case .star:
            let points = max(3, Int(p["points"]!.rounded()))
            let rOuter = p["rOuter"]!, rInner = p["rInner"]!
            let count = points * 2
            return (0...count).map { i in
                let theta = .pi * Double(i) / Double(points) - .pi / 2
                let r = i.isMultiple(of: 2) ? rOuter : rInner
                return CGPoint(x: r * cos(theta), y: r * sin(theta))
            }

        case .sine, .cosine:
            let amplitude = p["amplitude"]!, frequency = p["frequency"]!, phase = p["phase"]!
            let n = max(sampleCount, 8)
            let width = 100.0
            return (0..<n).map { i in
                let t = Double(i) / Double(n - 1)
                let x = (t - 0.5) * width
                let angle = frequency * 2 * .pi * t + phase
                let y = amplitude * (self == .sine ? sin(angle) : cos(angle))
                return CGPoint(x: x, y: y)
            }

        case .lissajous:
            let a = p["a"]!, b = p["b"]!, delta = p["delta"]!, scale = p["scale"]!
            let n = max(sampleCount, 8)
            return (0..<n).map { i in
                let t = 2 * .pi * Double(i) / Double(n - 1)
                return CGPoint(x: scale * sin(a * t + delta), y: scale * sin(b * t))
            }

        case .spiral:
            let a = p["a"]!, b = p["b"]!, turns = p["turns"]!
            let n = max(sampleCount, 8)
            return (0..<n).map { i in
                let theta = turns * 2 * .pi * Double(i) / Double(n - 1)
                let r = a + b * theta
                return CGPoint(x: r * cos(theta), y: r * sin(theta))
            }

        case .logSpiral:
            let a = p["a"]!, b = p["b"]!, turns = p["turns"]!
            let n = max(sampleCount, 8)
            return (0..<n).map { i in
                let theta = turns * 2 * .pi * Double(i) / Double(n - 1)
                let r = a * exp(b * theta)
                return CGPoint(x: r * cos(theta), y: r * sin(theta))
            }

        case .rose:
            let k = p["k"]!, r = p["r"]!
            let n = max(sampleCount, 8)
            return (0..<n).map { i in
                let theta = 2 * .pi * Double(i) / Double(n - 1)
                let rr = r * cos(k * theta)
                return CGPoint(x: rr * cos(theta), y: rr * sin(theta))
            }

        case .cardioid:
            let a = p["a"]!
            let n = max(sampleCount, 8)
            return (0..<n).map { i in
                let theta = 2 * .pi * Double(i) / Double(n - 1)
                let r = a * (1 - cos(theta))
                return CGPoint(x: r * cos(theta), y: r * sin(theta))
            }

        case .astroid:
            let a = p["a"]!
            let n = max(sampleCount, 8)
            return (0..<n).map { i in
                let theta = 2 * .pi * Double(i) / Double(n - 1)
                return CGPoint(x: a * pow(cos(theta), 3), y: a * pow(sin(theta), 3))
            }

        case .epicycloid:
            let R = p["R"]!, r = p["r"]!, turns = p["turns"]!
            let n = max(sampleCount, 8)
            return (0..<n).map { i in
                let theta = turns * 2 * .pi * Double(i) / Double(n - 1)
                let x = (R + r) * cos(theta) - r * cos((R + r) / r * theta)
                let y = (R + r) * sin(theta) - r * sin((R + r) / r * theta)
                return CGPoint(x: x, y: y)
            }

        case .hypocycloid:
            let R = p["R"]!, r = p["r"]!, turns = p["turns"]!
            let n = max(sampleCount, 8)
            return (0..<n).map { i in
                let theta = turns * 2 * .pi * Double(i) / Double(n - 1)
                let x = (R - r) * cos(theta) + r * cos((R - r) / r * theta)
                let y = (R - r) * sin(theta) - r * sin((R - r) / r * theta)
                return CGPoint(x: x, y: y)
            }
        }
    }

    /// Short human-readable notation substituting the resolved parameter values.
    func formulaExpression(params rawParams: [String: Double]) -> String {
        let p = resolvedParameters(rawParams)
        func n(_ key: String) -> String { NumberText.format(p[key] ?? 0) }
        switch self {
        case .point: return "𝑃 = (\(n("x")), \(n("y")))"
        case .line: return "𝑦 = \(n("m"))·𝑥 + \(n("b"))"
        case .plane: return "{(𝑥,𝑦) : |𝑥| ≤ \(n("w"))/2, |𝑦| ≤ \(n("h"))/2}"
        case .segment: return "(\(n("x1")),\(n("y1"))) → (\(n("x2")),\(n("y2")))"
        case .ray: return "𝑃₀=(\(n("x0")),\(n("y0"))), θ=\(n("angle"))°, 𝐿=\(n("length"))"
        case .polyline: return "(\(n("x1")),\(n("y1")))→(\(n("x2")),\(n("y2")))→(\(n("x3")),\(n("y3")))"
        case .arc: return "𝑥(𝑡)=\(n("r"))·cos 𝑡, 𝑦(𝑡)=\(n("r"))·sin 𝑡, 𝑡∈[\(n("startAngle"))°,\(n("endAngle"))°]"
        case .quadBezier: return "𝐵(𝑡) = (1-𝑡)²𝑃₀ + 2(1-𝑡)𝑡·𝐶 + 𝑡²𝑃₁, 𝐶=(\(n("cx")),\(n("cy")))"
        case .cubicBezier: return "𝐵(𝑡) = 3차 베지어, 𝐶₁=(\(n("c1x")),\(n("c1y"))), 𝐶₂=(\(n("c2x")),\(n("c2y")))"
        case .circle: return "𝑥(𝑡)=\(n("r"))·cos 𝑡, 𝑦(𝑡)=\(n("r"))·sin 𝑡"
        case .ellipse: return "𝑥(𝑡)=\(n("rx"))·cos 𝑡, 𝑦(𝑡)=\(n("ry"))·sin 𝑡"
        case .polygon: return "정\(Int(p["sides"] ?? 5))각형, 𝑟=\(n("r"))"
        case .star: return "별 \(Int(p["points"] ?? 5))개 꼭짓점, 𝑟ₒ=\(n("rOuter")), 𝑟ᵢ=\(n("rInner"))"
        case .sine: return "𝑦 = \(n("amplitude"))·sin(\(n("frequency"))·𝑥 + \(n("phase")))"
        case .cosine: return "𝑦 = \(n("amplitude"))·cos(\(n("frequency"))·𝑥 + \(n("phase")))"
        case .lissajous: return "𝑥=\(n("scale"))·sin(\(n("a"))𝑡+\(n("delta"))), 𝑦=\(n("scale"))·sin(\(n("b"))𝑡)"
        case .spiral: return "𝑟 = \(n("a")) + \(n("b"))θ"
        case .logSpiral: return "𝑟 = \(n("a"))·𝑒^(\(n("b"))θ)"
        case .rose: return "𝑟 = \(n("r"))·cos(\(Int(p["k"] ?? 4))θ)"
        case .cardioid: return "𝑟 = \(n("a"))(1 - cos θ)"
        case .astroid: return "𝑥=\(n("a"))cos³θ, 𝑦=\(n("a"))sin³θ"
        case .epicycloid: return "에피사이클로이드, 𝑅=\(n("R")), 𝑟=\(n("r"))"
        case .hypocycloid: return "하이포사이클로이드, 𝑅=\(n("R")), 𝑟=\(n("r"))"
        }
    }
}

nonisolated enum NumberText {
    /// Trims trailing zeros: 35.0 -> "35", 1.20 -> "1.2".
    static func format(_ value: Double, decimals: Int = 3) -> String {
        let rounded = (value * pow(10, Double(decimals))).rounded() / pow(10, Double(decimals))
        if rounded == rounded.rounded() && abs(rounded) < 1e15 {
            return String(Int(rounded))
        }
        var text = String(format: "%.\(decimals)f", rounded)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text
    }
}

extension ClosedRange where Bound == Double {
    func clamped(_ value: Double) -> Double { Swift.min(Swift.max(value, lowerBound), upperBound) }
}

extension CGVector {
    var normalized: CGVector {
        let length = sqrt(dx * dx + dy * dy)
        guard length > 0 else { return CGVector(dx: 1, dy: 0) }
        return CGVector(dx: dx / length, dy: dy / length)
    }
}

extension CGPoint {
    func offset(by vector: CGVector, scale: Double) -> CGPoint {
        CGPoint(x: x + vector.dx * scale, y: y + vector.dy * scale)
    }
}
