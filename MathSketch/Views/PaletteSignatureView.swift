import SwiftUI

/// PRD FR-5a: the decorative stand-in for color — never part of the math, always part of the
/// personality of the piece.
struct PaletteSignatureView: View {
    @Environment(SketchModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("팔레트 서명").font(.caption).foregroundStyle(.secondary)
            if model.paletteSwatches.isEmpty {
                Text("색을 칠하면 여기에 나타납니다").font(.footnote).foregroundStyle(.secondary)
            } else {
                HStack(spacing: 8) {
                    ForEach(model.paletteSwatches) { swatch in
                        Circle()
                            .fill(ElementColor(hex: swatch.hex)?.color ?? .gray)
                            .frame(width: 22, height: 22)
                            .overlay(Circle().stroke(.secondary.opacity(0.3), lineWidth: 1))
                            .accessibilityLabel(Text(swatch.name))
                    }
                    Spacer()
                }
                Text(model.paletteCaption).font(.footnote.weight(.medium))
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
