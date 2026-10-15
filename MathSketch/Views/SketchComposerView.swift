import SwiftData
import SwiftUI

/// The "캔버스" tab root — palette, canvas, inspector, formula bar and palette signature
/// stacked in one scroll view. PRD FR-7 non-goal note: no bespoke iPad multi-column layout yet
/// (Docs/TASKS-MathSketch.md design notes) — this flexible stack just avoids breaking on iPad.
struct SketchComposerView: View {
    @Environment(SketchModel.self) private var model
    @Environment(\.modelContext) private var modelContext
    @State private var showSaveDialog = false
    @State private var saveTitle = ""
    @State private var showClearAllConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    PaletteView()
                    CanvasView()
                        .frame(minHeight: 240, idealHeight: 280)
                    FormulaBarView()
                    PaletteSignatureView()
                }
                .padding()
            }
            // Pinned outside the scroll flow: SwiftUI reserves safe-area space for this above
            // the floating tab-bar pill, so the sliders can never scroll underneath it (the
            // in-flow placement + fixed heights approach this replaces still let the pill cover
            // 비틀기 X/Y once the formula label wrapped to two lines — see Docs/TASKS-MathSketch.md).
            .safeAreaInset(edge: .bottom) {
                InspectorView()
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                    .background(.bar)
            }
            .navigationTitle("MathSketch")
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button {
                        model.undo()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(!model.canUndo)
                    .accessibilityLabel(Text("실행 취소"))

                    Button {
                        model.redo()
                    } label: {
                        Image(systemName: "arrow.uturn.forward")
                    }
                    .disabled(!model.canRedo)
                    .accessibilityLabel(Text("다시 실행"))
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        saveTitle = model.paletteCaption.isEmpty ? "제목 없음" : model.paletteCaption
                        showSaveDialog = true
                    } label: {
                        Label("저장", systemImage: "square.and.arrow.down")
                    }
                    .disabled(model.isCanvasEmpty)
                    .accessibilityLabel(Text("갤러리에 저장"))

                    Button(role: .destructive) {
                        model.deleteSelected()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(model.selectedElementID == nil)
                    .accessibilityLabel(Text("선택한 요소 하나 삭제"))

                    Button(role: .destructive) {
                        showClearAllConfirm = true
                    } label: {
                        Image(systemName: "trash.fill")
                    }
                    .disabled(model.isCanvasEmpty)
                    .accessibilityLabel(Text("모두 지우기"))
                }
            }
            .alert("갤러리에 저장", isPresented: $showSaveDialog) {
                TextField("제목", text: $saveTitle)
                Button("취소", role: .cancel) {}
                Button("저장") { saveToGallery() }
            }
            .alert("모두 지우기", isPresented: $showClearAllConfirm) {
                Button("취소", role: .cancel) {}
                Button("지우기", role: .destructive) { model.clearAll() }
            } message: {
                Text("캔버스의 모든 요소와 픽셀 수식 배경을 삭제합니다. 실행 취소로 되돌릴 수 있습니다.")
            }
        }
    }

    private func saveToGallery() {
        guard let sketch = SavedSketch.make(title: saveTitle, elements: model.elements,
                                            pixelFormula: model.pixelFormula, thumbnailData: renderThumbnail()) else { return }
        modelContext.insert(sketch)
    }

    private func renderThumbnail() -> Data? {
        let rect = CGRect(x: 0, y: 0, width: 300, height: 300)
        let fitted = SketchCanvasRenderer.fit(elements: model.elements, in: rect)
        let backdrop = model.pixelFormulaImage
        let renderer = ImageRenderer(content:
            Canvas { context, _ in
                if let backdrop {
                    SketchDrawing.drawBackdrop(backdrop, in: rect, into: &context)
                }
                for item in fitted {
                    SketchDrawing.draw(item, into: &context)
                }
            }
            .frame(width: rect.width, height: rect.height)
            .background(Color.white)
        )
        renderer.scale = 2
        return renderer.uiImage?.pngData()
    }
}
