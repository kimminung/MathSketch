import Combine
import CoreGraphics
import Foundation
import Observation

/// Root state (PRD FR-9). Per-element formula labels are cheap pure-function lookups
/// (`FormulaFormatter.label(for:)`) and are *not* stored here — only the composite
/// SketchFormula text and the Palette Signature go through a 150ms debounce (FR-3/FR-5a),
/// kept separate from the 0.8s draft-autosave debounce (FR-7).
///
/// FR-10 adds an optional pixel-formula backdrop: the pasted LaTeX is the persisted truth,
/// the `CGImage` is a derived cache re-rendered (GPU) whenever the source changes.
@Observable
final class SketchModel {
    var elements: [SketchElement] = []
    var selectedElementID: UUID?

    var formulaText: String = ""
    var artisticNarrative: String = ""
    var paletteSwatches: [PaletteSwatch] = []
    var paletteCaption: String = ""

    var formulaInputText: String = ""
    var formulaInputError: String?

    // MARK: Pixel formula backdrop (FR-10)
    private(set) var pixelFormula: PixelFormulaArtwork?
    private(set) var pixelFormulaImage: CGImage?
    private(set) var pixelRenderPhase: PixelRenderPhase = .idle
    private var renderTask: Task<Void, Never>?
    /// Rendered images keyed by source so undo/redo across a few formulas is instant.
    private var renderedImageCache: [String: CGImage] = [:]
    private static let maxCachedImages = 4

    private var nextZIndex = 0
    private let formulaSubject = PassthroughSubject<Void, Never>()
    private let draftSubject = PassthroughSubject<Void, Never>()
    private var cancellables = Set<AnyCancellable>()

    // MARK: Undo/redo
    // One snapshot per *discrete* action (add/delete/color/replace/pixel formula) or per
    // *continuous gesture* (drag/pinch/rotate/slider) — never per onChanged tick, which would
    // flood the stack with near-duplicate states. `beginContinuousEdit()` pushes once at
    // gesture start and is a no-op for the rest of that gesture; `endContinuousEdit()` just
    // re-arms it for the next one.
    private static let maxHistory = 50
    private var undoStack: [CanvasSnapshot] = []
    private var redoStack: [CanvasSnapshot] = []
    private var isContinuousEditActive = false

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    /// True when there is nothing on the canvas at all — no shapes and no pixel backdrop.
    var isCanvasEmpty: Bool { elements.isEmpty && pixelFormula == nil }

    init() {
        let draft = DraftCanvasStore.shared.load()
        elements = draft.elements
        pixelFormula = draft.pixelFormula
        nextZIndex = (elements.map(\.zIndex).max() ?? -1) + 1
        recomputeDerived()
        refreshPixelImage()

        formulaSubject
            .debounce(for: .seconds(0.15), scheduler: DispatchQueue.main)
            .sink { [weak self] in self?.recomputeDerived() }
            .store(in: &cancellables)

        draftSubject
            .debounce(for: .seconds(0.8), scheduler: DispatchQueue.main)
            .sink { [weak self] in self?.persistDraft() }
            .store(in: &cancellables)
    }

    var selectedElement: SketchElement? {
        guard let id = selectedElementID else { return nil }
        return elements.first { $0.id == id }
    }

    var selectedIndex: Int? {
        guard let id = selectedElementID else { return nil }
        return elements.firstIndex { $0.id == id }
    }

    // MARK: Discrete actions (recompute immediately — these aren't rapid-fire gestures)

    @discardableResult
    func addElement(kind: ShapeKind, at point: CGPoint) -> UUID {
        pushUndoSnapshot()
        var element = SketchElement(shapeKind: kind, zIndex: nextZIndex)
        nextZIndex += 1
        element.transform.translateX = point.x
        element.transform.translateY = point.y
        elements.append(element)
        selectedElementID = element.id
        recomputeDerived()
        draftSubject.send()
        return element.id
    }

    func deleteSelected() {
        guard let id = selectedElementID else { return }
        pushUndoSnapshot()
        elements.removeAll { $0.id == id }
        selectedElementID = nil
        recomputeDerived()
        draftSubject.send()
    }

    /// Clears shapes *and* the pixel backdrop — one undo step restores both.
    func clearAll() {
        guard !isCanvasEmpty else { return }
        pushUndoSnapshot()
        elements = []
        selectedElementID = nil
        nextZIndex = 0
        setPixelFormula(nil)
        recomputeDerived()
        draftSubject.send()
    }

    func updateSelectedColor(_ color: ElementColor) {
        guard let idx = selectedIndex else { return }
        pushUndoSnapshot()
        elements[idx].color = color
        recomputeDerived()
        draftSubject.send()
    }

    /// Replaces the shapes only; an existing pixel backdrop stays (the DSL has no say over it).
    func replaceAll(with newElements: [SketchElement]) {
        pushUndoSnapshot()
        elements = newElements
        nextZIndex = (elements.map(\.zIndex).max() ?? -1) + 1
        selectedElementID = nil
        recomputeDerived()
        draftSubject.send()
    }

    /// Restores a complete saved state (gallery → canvas), backdrop included.
    func restore(elements newElements: [SketchElement], pixelFormula artwork: PixelFormulaArtwork?) {
        pushUndoSnapshot()
        elements = newElements
        nextZIndex = (elements.map(\.zIndex).max() ?? -1) + 1
        selectedElementID = nil
        setPixelFormula(artwork)
        recomputeDerived()
        draftSubject.send()
    }

    /// Routes pasted text: LaTeX pixel formulas go to the GPU backdrop, anything else is
    /// parsed as the SketchFormula DSL. Returns true when the input was accepted.
    @discardableResult
    func loadFromFormulaInput() -> Bool {
        if PixelFormulaParser.looksLikePixelFormula(formulaInputText) {
            return applyPixelFormula(source: formulaInputText)
        }
        do {
            let parsed = try SketchFormulaParser.parse(formulaInputText)
            formulaInputError = nil
            replaceAll(with: parsed)
            return true
        } catch {
            formulaInputError = String(describing: error)
            return false
        }
    }

    /// Parses a pixel-color formula and makes it the canvas backdrop (PRD FR-10).
    @discardableResult
    func applyPixelFormula(source: String) -> Bool {
        do {
            let program = try PixelFormulaParser.parse(source)
            formulaInputError = nil
            pushUndoSnapshot()
            setPixelFormula(PixelFormulaArtwork(source: source, program: program))
            draftSubject.send()
            return true
        } catch {
            formulaInputError = String(describing: error)
            return false
        }
    }

    func clearPixelFormula() {
        guard pixelFormula != nil else { return }
        pushUndoSnapshot()
        setPixelFormula(nil)
        draftSubject.send()
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(currentSnapshot())
        apply(previous)
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(currentSnapshot())
        apply(next)
    }

    // MARK: Continuous gesture updates (debounced heavy recompute, instant autosave signal)

    /// Call once when a drag/pinch/rotate/slider interaction begins, before the first
    /// `updateSelectedTransform`. Repeated calls while the same gesture is still in progress
    /// are ignored, so the undo stack gets exactly one entry per gesture, not one per frame.
    func beginContinuousEdit() {
        guard !isContinuousEditActive else { return }
        isContinuousEditActive = true
        pushUndoSnapshot()
    }

    func endContinuousEdit() {
        isContinuousEditActive = false
    }

    func updateSelectedTransform(_ mutate: (inout ElementTransform) -> Void) {
        guard let idx = selectedIndex else { return }
        mutate(&elements[idx].transform)
        elements[idx].transform.clamped()
        formulaSubject.send()
        draftSubject.send()
    }

    // MARK: Snapshots

    private func currentSnapshot() -> CanvasSnapshot {
        CanvasSnapshot(elements: elements, pixelFormula: pixelFormula)
    }

    private func apply(_ snapshot: CanvasSnapshot) {
        elements = snapshot.elements
        nextZIndex = (elements.map(\.zIndex).max() ?? -1) + 1
        selectedElementID = nil
        setPixelFormula(snapshot.pixelFormula)
        recomputeDerived()
        draftSubject.send()
    }

    private func pushUndoSnapshot() {
        undoStack.append(currentSnapshot())
        if undoStack.count > Self.maxHistory { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    // MARK: Pixel rendering

    private func setPixelFormula(_ artwork: PixelFormulaArtwork?) {
        guard artwork != pixelFormula else { return }
        pixelFormula = artwork
        refreshPixelImage()
    }

    /// Serves the image from cache or kicks off compile → quarter preview → full render.
    private func refreshPixelImage() {
        renderTask?.cancel()
        renderTask = nil
        guard let artwork = pixelFormula else {
            pixelFormulaImage = nil
            pixelRenderPhase = .idle
            return
        }
        if let cached = renderedImageCache[artwork.source] {
            pixelFormulaImage = cached
            pixelRenderPhase = .ready(seconds: 0)
            return
        }
        guard let program = try? PixelFormulaParser.parse(artwork.source) else {
            pixelFormulaImage = nil
            pixelRenderPhase = .failed("저장된 픽셀 수식을 다시 해석할 수 없습니다")
            return
        }
        pixelRenderPhase = .compiling
        renderTask = Task { [weak self] in
            let started = Date()
            do {
                let preview = try await PixelFormulaRenderer.shared.render(program, downsample: 4)
                guard !Task.isCancelled, let self else { return }
                pixelFormulaImage = preview
                pixelRenderPhase = .previewing
                let full = try await PixelFormulaRenderer.shared.render(program, downsample: 1)
                guard !Task.isCancelled else { return }
                pixelFormulaImage = full
                cacheImage(full, for: artwork.source)
                pixelRenderPhase = .ready(seconds: Date().timeIntervalSince(started))
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, let self else { return }
                pixelRenderPhase = .failed(String(describing: error))
            }
        }
    }

    private func cacheImage(_ image: CGImage, for source: String) {
        if renderedImageCache.count >= Self.maxCachedImages, let victim = renderedImageCache.keys.first {
            renderedImageCache.removeValue(forKey: victim)
        }
        renderedImageCache[source] = image
    }

    // MARK: Derived state

    private func recomputeDerived() {
        formulaText = SketchFormulaFormatter.format(elements)
        artisticNarrative = ArtisticFormulaFormatter.narrative(for: elements)
        paletteSwatches = PaletteSignature.swatches(for: elements)
        paletteCaption = PaletteSignature.caption(for: elements)
    }

    private func persistDraft() {
        DraftCanvasStore.shared.save(elements, pixelFormula: pixelFormula)
    }
}
