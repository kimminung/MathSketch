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
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        saveTitle = model.paletteCaption.isEmpty ? "제목 없음" : model.paletteCaption
                        showSaveDialog = true
                    } label: {
                        Label("저장", systemImage: "square.and.arrow.down")
                    }
                    .disabled(model.elements.isEmpty)
                    .accessibilityLabel(Text("갤러리에 저장"))
                }
            }
            .alert("갤러리에 저장", isPresented: $showSaveDialog) {
                TextField("제목", text: $saveTitle)
                Button("취소", role: .cancel) {}
                Button("저장") { saveToGallery() }
            }
        }
    }

    private func saveToGallery() {
        guard let sketch = SavedSketch.make(title: saveTitle, elements: model.elements, thumbnailData: renderThumbnail()) else { return }
        modelContext.insert(sketch)
    }

    private func renderThumbnail() -> Data? {
        let rect = CGRect(x: 0, y: 0, width: 300, height: 300)
        let fitted = SketchCanvasRenderer.fit(elements: model.elements, in: rect)
        let renderer = ImageRenderer(content:
            Canvas { context, _ in
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
