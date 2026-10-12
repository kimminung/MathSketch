import SwiftUI
import UIKit

/// PRD FR-5: the live composite SketchFormula (geometry only, no color — FR-4) plus the
/// "수식으로 그리기" reverse path that parses pasted text back into the canvas in one shot.
/// The typeset narrative (`ArtisticFormulaFormatter`) is the primary display — it's meant to
/// *read* like a hand-set equation; the raw, round-trippable DSL text is tucked into a
/// disclosure group below for copy/paste, since that's the only form `SketchFormulaParser`
/// understands.
struct FormulaBarView: View {
    @Environment(SketchModel.self) private var model
    @State private var showFormulaInput = false
    @State private var showRawFormula = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("수식").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button {
                    UIPasteboard.general.string = model.formulaText
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .disabled(model.formulaText.isEmpty)
                .accessibilityLabel(Text("수식 복사"))
                Button {
                    model.formulaInputText = model.formulaText
                    model.formulaInputError = nil
                    showFormulaInput = true
                } label: {
                    Image(systemName: "function")
                }
                .accessibilityLabel(Text("수식으로 그리기"))
            }
            // No lineLimit here on purpose — the whole equation must always be visible, never
            // truncated with an ellipsis, no matter how long the piecewise shapes make it.
            Text(model.artisticNarrative.isEmpty ? "캔버스가 비어 있습니다" : model.artisticNarrative)
                .font(.system(.footnote, design: .serif))
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            if !model.formulaText.isEmpty {
                DisclosureGroup("원본 수식 (복사·붙여넣기용)", isExpanded: $showRawFormula) {
                    Text(model.formulaText)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .padding(.top, 4)
                }
                .font(.caption)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .sheet(isPresented: $showFormulaInput) {
            FormulaInputSheet()
        }
    }
}

private struct FormulaInputSheet: View {
    @Environment(SketchModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("SketchFormula (도형 + 변형, 색상 없음)") {
                    TextEditor(text: Binding(get: { model.formulaInputText }, set: { model.formulaInputText = $0 }))
                        .font(.system(.footnote, design: .monospaced))
                        .frame(minHeight: 160)
                    if let error = model.formulaInputError {
                        Text(error).font(.caption).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("수식으로 그리기")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("그리기") {
                        model.loadFromFormulaInput()
                        if model.formulaInputError == nil { dismiss() }
                    }
                }
            }
        }
    }
}
