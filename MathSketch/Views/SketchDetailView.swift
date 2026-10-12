import SwiftData
import SwiftUI
import UIKit

/// PRD FR-8: full formula + palette signature, "캔버스로 열기" restores the exact saved state
/// (color included) by replacing the live draft, unlike the colorless SketchFormula text alone.
struct SketchDetailView: View {
    let sketch: SavedSketch
    @Environment(SketchModel.self) private var model
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let data = sketch.thumbnailData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("합성 수식 (\(sketch.elementCount)개 요소)").font(.caption).foregroundStyle(.secondary)
                        Text(sketch.formulaText)
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("팔레트 서명").font(.caption).foregroundStyle(.secondary)
                        HStack {
                            ForEach(sketch.paletteHexes, id: \.self) { hex in
                                Circle().fill(ElementColor(hex: hex)?.color ?? .gray).frame(width: 22, height: 22)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(sketch.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        modelContext.delete(sketch)
                        dismiss()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel(Text("삭제"))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("캔버스로 열기") {
                        model.replaceAll(with: sketch.elements)
                        dismiss()
                    }
                }
            }
        }
    }
}
