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
        elements.removeAll { $0.id == id }
        selectedElementID = nil
        recomputeDerived()
        draftSubject.send()
    }

    func updateSelectedColor(_ color: ElementColor) {
        guard let idx = selectedIndex else { return }
        elements[idx].color = color
        recomputeDerived()
        draftSubject.send()
    }

    func replaceAll(with newElements: [SketchElement]) {
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

    // MARK: Continuous gesture updates (debounced heavy recompute, instant autosave signal)

    func updateSelectedTransform(_ mutate: (inout ElementTransform) -> Void) {
        guard let idx = selectedIndex else { return }
        mutate(&elements[idx].transform)
        elements[idx].transform.clamped()
        formulaSubject.send()
        draftSubject.send()
    }

    // MARK: Derived state

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
