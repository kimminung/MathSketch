import Foundation

/// PRD FR-5a: maps a color to the nearest of ~50 curated Korean evocative names via
/// nearest-neighbor matching in CIE Lab space (perceptually closer than raw RGB distance).
/// Deterministic — the same hex always resolves to the same name (tested in Phase 8).
nonisolated enum PaletteNamer {
    struct NamedColor {
        let name: String
        let hex: String
    }

    static let catalog: [NamedColor] = [
        .init(name: "노을빛 주황", hex: "#FF6B35"), .init(name: "심해 남색", hex: "#0B3D64"),
        .init(name: "라임 그린", hex: "#A8E05F"), .init(name: "서리 라벤더", hex: "#C9B8E8"),
        .init(name: "벚꽃 분홍", hex: "#F7C9D1"), .init(name: "쪽빛 파랑", hex: "#1E3A8A"),
        .init(name: "가을 갈색", hex: "#8B5E34"), .init(name: "숯빛 검정", hex: "#1C1C1E"),
        .init(name: "진주 흰색", hex: "#F5F3EE"), .init(name: "민트 그린", hex: "#3EB89B"),
        .init(name: "레몬 옐로", hex: "#F4D35E"), .init(name: "산호 빨강", hex: "#FF5A5F"),
        .init(name: "자두 보라", hex: "#6B3FA0"), .init(name: "청록", hex: "#0E7C7B"),
        .init(name: "모래빛 베이지", hex: "#D8C3A5"), .init(name: "와인 레드", hex: "#6B1E2B"),
        .init(name: "하늘빛 파랑", hex: "#6EC6FF"), .init(name: "올리브 그린", hex: "#708238"),
        .init(name: "코코아 브라운", hex: "#4B3621"), .init(name: "복숭아 살구색", hex: "#FFB199"),
        .init(name: "청보라", hex: "#4B4E9E"), .init(name: "은빛 회색", hex: "#B8B8B8"),
        .init(name: "다홍", hex: "#E3432D"), .init(name: "연두", hex: "#9ACD32"),
        .init(name: "짙은 에메랄드", hex: "#046241"), .init(name: "황금빛", hex: "#D4AF37"),
        .init(name: "자홍", hex: "#C2185B"), .init(name: "담청색", hex: "#4FA3D1"),
        .init(name: "적갈색", hex: "#8C3A2B"), .init(name: "청자색", hex: "#4A6670"),
        .init(name: "플럼 핑크", hex: "#D982B5"), .init(name: "미드나잇 블루", hex: "#003366"),
        .init(name: "토파즈 옐로", hex: "#FFC94A"), .init(name: "라일락", hex: "#C8A2C8"),
        .init(name: "버건디", hex: "#800020"), .init(name: "아이보리", hex: "#FFFFF0"),
        .init(name: "카키", hex: "#8B8B5A"), .init(name: "터콰이즈", hex: "#2FBFB0"),
        .init(name: "라즈베리", hex: "#E30B5D"), .init(name: "세이지 그린", hex: "#9CAF88"),
        .init(name: "초콜릿 브라운", hex: "#3B2412"), .init(name: "피치 핑크", hex: "#FFD9C9"),
        .init(name: "코발트 블루", hex: "#0047AB"), .init(name: "머스터드 옐로", hex: "#D9A441"),
        .init(name: "자스민 화이트", hex: "#F8F4E3"), .init(name: "딥 퍼플", hex: "#4B0082"),
        .init(name: "스카이 민트", hex: "#B9EBD0"), .init(name: "로즈 골드", hex: "#B76E79"),
        .init(name: "페리윙클", hex: "#9BA5E0"), .init(name: "차콜 그레이", hex: "#36454F"),
    ]

    static func name(for color: ElementColor) -> String {
        nearest(to: color).name
    }

    static func nearest(to color: ElementColor) -> NamedColor {
        let target = lab(r: color.red, g: color.green, b: color.blue)
        var best = catalog[0]
        var bestDistance = Double.greatestFiniteMagnitude
        for candidate in catalog {
            guard let candidateColor = ElementColor(hex: candidate.hex) else { continue }
            let lab2 = lab(r: candidateColor.red, g: candidateColor.green, b: candidateColor.blue)
            let distance = sqrt(pow(target.L - lab2.L, 2) + pow(target.a - lab2.a, 2) + pow(target.b - lab2.b, 2))
            if distance < bestDistance {
                bestDistance = distance
                best = candidate
            }
        }
        return best
    }

    private static func lab(r: Double, g: Double, b: Double) -> (L: Double, a: Double, b: Double) {
        func linearize(_ c: Double) -> Double {
            c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        let rl = linearize(r), gl = linearize(g), bl = linearize(b)
        let x = rl * 0.4124564 + gl * 0.3575761 + bl * 0.1804375
        let y = rl * 0.2126729 + gl * 0.7151522 + bl * 0.0721750
        let z = rl * 0.0193339 + gl * 0.1191920 + bl * 0.9503041
        let xn = 0.95047, yn = 1.0, zn = 1.08883
        func f(_ t: Double) -> Double {
            t > 0.008856 ? pow(t, 1.0 / 3.0) : (7.787 * t + 16.0 / 116.0)
        }
        let fx = f(x / xn), fy = f(y / yn), fz = f(z / zn)
        return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz))
    }
}
