import SwiftUI

/// PRD FR-1/T3.1: 기본 요소(점·선·면) 섹션이 맨 앞에 오는 카테고리별 팔레트. 탭하면 캔버스
/// 중앙에 추가되고, 드래그하면 `CanvasView`의 `dropDestination`이 드롭 위치에 추가한다.
struct PaletteView: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 18) {
                ForEach(ShapeKind.byCategory, id: \.category) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(group.category.rawValue)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            ForEach(group.kinds) { kind in
                                PaletteChip(kind: kind)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 96)
    }
}

private struct PaletteChip: View {
    let kind: ShapeKind
    @Environment(SketchModel.self) private var model

    var body: some View {
        VStack(spacing: 2) {
            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size).insetBy(dx: 5, dy: 5)
                let fitted = SketchCanvasRenderer.fit(elements: [SketchElement(shapeKind: kind)], in: rect)
                for item in fitted {
                    SketchDrawing.draw(item, into: &context)
                }
            }
            .frame(width: 44, height: 44)
            Text(kind.displayName)
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(width: 64, height: 72)
        .padding(6)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .draggable(kind.rawValue)
        .onTapGesture { model.addElement(kind: kind, at: .zero) }
        .accessibilityLabel(Text("\(kind.displayName) 추가"))
        .accessibilityHint(Text(kind.formulaExpression(params: [:])))
        .accessibilityAddTraits(.isButton)
    }
}
