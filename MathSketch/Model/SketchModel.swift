import Combine
import CoreGraphics
import Foundation
import Observation

/// Root state (PRD FR-9). Per-element formula labels are cheap pure-function lookups
/// (`FormulaFormatter.label(for:)`) and are *not* stored here — only the composite
/// SketchFormula text and the Palette Signature go through a 150ms debounce (FR-3/FR-5a),
/// kept separate from the 0.8s draft-autosave debounce (FR-7).
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

    private var nextZIndex = 0
    private let formulaSubject = PassthroughSubject<Void, Never>()
    private let draftSubject = PassthroughSubject<Void, Never>()
    private var cancellables = Set<AnyCancellable>()

    // MARK: Undo/redo
    // One snapshot per *discrete* action (add/delete/color/replace) or per *continuous gesture*
    // (drag/pinch/rotate/slider) — never per onChanged tick, which would flood the stack with
    // near-duplicate states. `beginContinuousEdit()` pushes once at gesture start and is a no-op
    // for the rest of that gesture; `endContinuousEdit()` just re-arms it for the next one.
    private static let maxHistory = 50
    private var undoStack: [[SketchElement]] = []
    private var redoStack: [[SketchElement]] = []
    private var isContinuousEditActive = false

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    init() {
        elements = DraftCanvasStore.shared.load()
        nextZIndex = (elements.map(\.zIndex).max() ?? -1) + 1
        recomputeDerived()

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

    func clearAll() {
        guard !elements.isEmpty else { return }
        pushUndoSnapshot()
        elements = []
        selectedElementID = nil
        nextZIndex = 0
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

    func replaceAll(with newElements: [SketchElement]) {
        pushUndoSnapshot()
        elements = newElements
        nextZIndex = (elements.map(\.zIndex).max() ?? -1) + 1
        selectedElementID = nil
        recomputeDerived()
        draftSubject.send()
    }

    func loadFromFormulaInput() {
        do {
            let parsed = try SketchFormulaParser.parse(formulaInputText)
            formulaInputError = nil
            replaceAll(with: parsed)
        } catch {
            formulaInputError = String(describing: error)
        }
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(elements)
        elements = previous
        nextZIndex = (elements.map(\.zIndex).max() ?? -1) + 1
        selectedElementID = nil
        recomputeDerived()
        draftSubject.send()
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(elements)
        elements = next
        nextZIndex = (elements.map(\.zIndex).max() ?? -1) + 1
        selectedElementID = nil
        recomputeDerived()
        draftSubject.send()
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

    // MARK: Derived state

    private func pushUndoSnapshot() {
        undoStack.append(elements)
        if undoStack.count > Self.maxHistory { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    private func recomputeDerived() {
        formulaText = SketchFormulaFormatter.format(elements)
        artisticNarrative = ArtisticFormulaFormatter.narrative(for: elements)
        paletteSwatches = PaletteSignature.swatches(for: elements)
        paletteCaption = PaletteSignature.caption(for: elements)
    }

    private func persistDraft() {
        DraftCanvasStore.shared.save(elements)
    }
}
