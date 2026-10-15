import Foundation

/// The persisted form of a pixel-color formula backdrop (PRD FR-10): the pasted source is
/// the single source of truth — the image is always re-rendered from it, never stored.
nonisolated struct PixelFormulaArtwork: Codable, Equatable, Sendable {
    var source: String
    var width: Int
    var height: Int
    var definitionCount: Int

    init(source: String, program: PixelFormulaProgram) {
        self.source = source
        width = program.width
        height = program.height
        definitionCount = program.definitionOrder.count
    }

    var sizeCaption: String { "\(width) × \(height)" }
}

/// Where a pixel formula is in its compile → preview → full-resolution pipeline.
nonisolated enum PixelRenderPhase: Equatable, Sendable {
    case idle
    case compiling
    /// A quarter-resolution preview is on screen while the full image renders.
    case previewing
    case ready(seconds: Double)
    case failed(String)
}

/// One undo/redo entry: everything the canvas shows.
nonisolated struct CanvasSnapshot: Equatable, Sendable {
    var elements: [SketchElement]
    var pixelFormula: PixelFormulaArtwork?
}
