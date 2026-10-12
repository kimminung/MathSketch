import SwiftUI

/// PRD FR-9: sliders give precise, continuously-live access to every transform axis (including
/// non-uniform scale/shear that the on-canvas pinch/rotate gestures in CanvasView can't reach).
struct InspectorView: View {
    @Environment(SketchModel.self) private var model

    var body: some View {
        Group {
            if let element = model.selectedElement {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(element.shapeKind.displayName).font(.headline)
                        Spacer()
                        Button(role: .destructive) { model.deleteSelected() } label: {
                            Image(systemName: "trash")
                        }
                        .accessibilityLabel(Text("선택한 요소 삭제"))
                    }
                    Text(FormulaFormatter.label(for: element))
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .textSelection(.enabled)

                    sliderRow("스케일 X", value: binding(\.scaleX), range: ElementTransform.scaleRange)
                    sliderRow("스케일 Y", value: binding(\.scaleY), range: ElementTransform.scaleRange)
                    sliderRow("회전", value: binding(\.rotationDegrees), range: -180...180, suffix: "°")
                    sliderRow("비틀기 X", value: binding(\.shearX), range: ElementTransform.shearRange)
                    sliderRow("비틀기 Y", value: binding(\.shearY), range: ElementTransform.shearRange)

                    ColorPicker("색상 (장식 전용, 수식에 포함되지 않음)", selection: colorBinding, supportsOpacity: false)
                        .font(.footnote)
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
            } else {
                Text("요소를 탭하거나 팔레트에서 끌어와 선택하세요.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
    }

    private func binding(_ keyPath: WritableKeyPath<ElementTransform, Double>) -> Binding<Double> {
        Binding(
            get: { model.selectedElement?.transform[keyPath: keyPath] ?? 0 },
            set: { newValue in model.updateSelectedTransform { $0[keyPath: keyPath] = newValue } }
        )
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { model.selectedElement?.color.color ?? .black },
            set: { model.updateSelectedColor(ElementColor(color: $0)) }
        )
    }

    private func sliderRow(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, suffix: String = "") -> some View {
        HStack {
            Text(title).font(.caption).frame(width: 64, alignment: .leading)
            Slider(value: value, in: range)
                .accessibilityLabel(Text(title))
                .accessibilityValue(Text("\(NumberText.format(value.wrappedValue))\(suffix)"))
            Text("\(NumberText.format(value.wrappedValue))\(suffix)")
                .font(.caption.monospacedDigit())
                .frame(width: 52, alignment: .trailing)
        }
    }
}
