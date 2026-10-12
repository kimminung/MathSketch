import SwiftData
import SwiftUI
import UIKit

/// PRD FR-8: SwiftData-backed gallery grid, mirroring the reference project's GalleryView.
struct GalleryView: View {
    @Query(sort: \SavedSketch.createdAt, order: .reverse) private var sketches: [SavedSketch]
    @State private var selected: SavedSketch?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                    ForEach(sketches) { sketch in
                        Button {
                            selected = sketch
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                thumbnail(for: sketch)
                                Text(sketch.title).font(.caption).lineLimit(1).foregroundStyle(.primary)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(sketch.title))
                    }
                }
                .padding()
            }
            .navigationTitle("갤러리")
            .overlay {
                if sketches.isEmpty {
                    ContentUnavailableView("저장된 스케치가 없어요", systemImage: "square.on.circle",
                                            description: Text("캔버스 탭에서 저장을 눌러보세요."))
                }
            }
            .sheet(item: $selected) { sketch in
                SketchDetailView(sketch: sketch)
            }
        }
    }

    @ViewBuilder
    private func thumbnail(for sketch: SavedSketch) -> some View {
        if let data = sketch.thumbnailData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(.secondary.opacity(0.1))
                .frame(height: 120)
        }
    }
}
