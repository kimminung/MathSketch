import SwiftUI
import UIKit

/// PRD FR-5: the live composite SketchFormula (geometry only, no color — FR-4) plus the
/// "수식으로 그리기" reverse path that parses pasted text back into the canvas in one shot.
struct FormulaBarView: View {
    @Environment(SketchModel.self) private var model
    @State private var showFormulaInput = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("합성 수식").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button {
                    UIPasteboard.general.string = model.formulaText
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .disabled(model.formulaText.isEmpty)
                .accessibilityLabel(Text("합성 수식 복사"))
                Button {
                    model.formulaInputText = model.formulaText
                    model.formulaInputError = nil
                    showFormulaInput = true
                } label: {
                    Image(systemName: "function")
                }
                .accessibilityLabel(Text("수식으로 그리기"))
            }
            Text(model.formulaText.isEmpty ? "캔버스가 비어 있습니다" : model.formulaText)
                .font(.system(.footnote, design: .monospaced))
                .lineLimit(4)
                .textSelection(.enabled)
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
