import Foundation
import SwiftData

/// PRD FR-8: explicit gallery saves (SwiftData, independent of the Core Data draft store —
/// see Docs/TASKS-MathSketch.md design notes for why the two stores stay separate).
/// `formulaText` is the pure-geometry SketchFormula (no color); `elementsJSON` keeps the full
/// per-element state including color so "캔버스로 열기" can restore an exact match.
@Model
final class SavedSketch {
    var title: String = ""
    var createdAt: Date = Date()
    @Attribute(.externalStorage) var thumbnailData: Data?
    var formulaText: String = ""
    var paletteHexes: [String] = []
    var elementsJSON: Data = Data()

    init(title: String, createdAt: Date = Date(), thumbnailData: Data?, formulaText: String,
         paletteHexes: [String], elementsJSON: Data) {
        self.title = title
        self.createdAt = createdAt
        self.thumbnailData = thumbnailData
        self.formulaText = formulaText
        self.paletteHexes = paletteHexes
        self.elementsJSON = elementsJSON
    }

    var elements: [SketchElement] {
        (try? JSONDecoder().decode([SketchElement].self, from: elementsJSON)) ?? []
    }

    var elementCount: Int { elements.count }

    static func make(title: String, elements: [SketchElement], thumbnailData: Data?) -> SavedSketch? {
        guard let json = try? JSONEncoder().encode(elements) else { return nil }
        return SavedSketch(
            title: title,
            thumbnailData: thumbnailData,
            formulaText: SketchFormulaFormatter.format(elements),
            paletteHexes: PaletteSignature.swatches(for: elements).map(\.hex),
            elementsJSON: json
        )
    }
}
