import Foundation

/// PRD FR-5a: the decorative, non-mathematical stand-in for color — a swatch strip plus a
/// one-line caption, derived from the colors actually in use (zIndex order, deduped).
nonisolated struct PaletteSwatch: Identifiable, Equatable {
    var id: String { hex }
    let hex: String
    let name: String
}

nonisolated enum PaletteSignature {
    static func swatches(for elements: [SketchElement]) -> [PaletteSwatch] {
        var seen = Set<String>()
        var result: [PaletteSwatch] = []
        for element in elements.sorted(by: { $0.zIndex < $1.zIndex }) {
            let hex = element.color.hex
            guard !seen.contains(hex) else { continue }
            seen.insert(hex)
            result.append(PaletteSwatch(hex: hex, name: PaletteNamer.name(for: element.color)))
        }
        return result
    }

    static func caption(for elements: [SketchElement], maxNames: Int = 3) -> String {
        swatches(for: elements).prefix(maxNames).map(\.name).joined(separator: " · ")
    }
}
