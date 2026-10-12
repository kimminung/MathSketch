import SwiftUI

/// Decorative-only color (PRD FR-4) — never serialized into SketchFormula, only persisted
/// (draft/gallery) and surfaced through the Palette Signature (FR-5a).
nonisolated struct ElementColor: Codable, Sendable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double = 1

    static let defaultNeutral = ElementColor(red: 0.110, green: 0.110, blue: 0.118) // #1C1C1E

    var hex: String {
        let r = Int((red * 255).rounded()), g = Int((green * 255).rounded()), b = Int((blue * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    var color: Color { Color(red: red, green: green, blue: blue, opacity: alpha) }

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red; self.green = green; self.blue = blue; self.alpha = alpha
    }

    init?(hex: String) {
        var text = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 6, let value = UInt32(text, radix: 16) else { return nil }
        red = Double((value >> 16) & 0xFF) / 255
        green = Double((value >> 8) & 0xFF) / 255
        blue = Double(value & 0xFF) / 255
        alpha = 1
    }

    init(color: Color) {
        let resolved = color.resolve(in: .init())
        red = Double(resolved.red)
        green = Double(resolved.green)
        blue = Double(resolved.blue)
        alpha = Double(resolved.opacity)
    }

    /// HSB components, used by PaletteNamer's nearest-name matching.
    var hsb: (hue: Double, saturation: Double, brightness: Double) {
        let maxV = Swift.max(red, green, blue), minV = Swift.min(red, green, blue)
        let delta = maxV - minV
        var hue = 0.0
        if delta > 0 {
            if maxV == red { hue = ((green - blue) / delta).truncatingRemainder(dividingBy: 6) }
            else if maxV == green { hue = (blue - red) / delta + 2 }
            else { hue = (red - green) / delta + 4 }
            hue *= 60
            if hue < 0 { hue += 360 }
        }
        let saturation = maxV == 0 ? 0 : delta / maxV
        return (hue, saturation, maxV)
    }
}
