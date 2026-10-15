import SwiftUI
import UIKit

/// PRD FR-5: the live composite SketchFormula (geometry only, no color — FR-4) plus the
/// "수식으로 그리기" reverse path that parses pasted text back into the canvas in one shot.
/// The typeset narrative (`ArtisticFormulaFormatter`) is the primary display — it's meant to
/// *read* like a hand-set equation; the raw, round-trippable DSL text is tucked into a
/// disclosure group below for copy/paste, since that's the only form `SketchFormulaParser`
/// understands.
///
/// FR-10: when a pixel-color formula is active, its full LaTeX source is shown above the
/// narrative — complete, never truncated — together with the GPU render status.
struct FormulaBarView: View {
    @Environment(SketchModel.self) private var model
    @State private var showFormulaInput = false
    @State private var showRawFormula = false
    @State private var showPixelSource = true

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

            if let artwork = model.pixelFormula {
                pixelFormulaSection(artwork)
            }

            // No lineLimit here on purpose — the whole equation must always be visible, never
            // truncated with an ellipsis, no matter how long the piecewise shapes make it.
            Text(narrativeText)
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

    private var narrativeText: String {
        if !model.artisticNarrative.isEmpty { return model.artisticNarrative }
        return model.pixelFormula == nil ? "캔버스가 비어 있습니다" : "도형 요소 없음 — 픽셀 수식 배경만 표시 중"
    }

    @ViewBuilder
    private func pixelFormulaSection(_ artwork: PixelFormulaArtwork) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "photo.on.rectangle.angled").foregroundStyle(.secondary)
                Text("픽셀 수식 · \(artwork.sizeCaption) · 정의 \(artwork.definitionCount)개")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                renderStatus
                Button(role: .destructive) {
                    model.clearPixelFormula()
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .accessibilityLabel(Text("픽셀 수식 지우기"))
            }
            DisclosureGroup("픽셀 수식 원문 (LaTeX · 전체)", isExpanded: $showPixelSource) {
                Text(artwork.source)
                    .font(.system(.caption2, design: .monospaced))
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .padding(.top, 4)
            }
            .font(.caption)
        }
        .padding(10)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var renderStatus: some View {
        switch model.pixelRenderPhase {
        case .idle:
            EmptyView()
        case .compiling:
            HStack(spacing: 4) {
                ProgressView().controlSize(.mini)
                Text("셰이더 컴파일 중").font(.caption2).foregroundStyle(.secondary)
            }
        case .previewing:
            HStack(spacing: 4) {
                ProgressView().controlSize(.mini)
                Text("미리보기 · 정밀 렌더링 중").font(.caption2).foregroundStyle(.secondary)
            }
        case .ready(let seconds):
            Text(seconds > 0 ? String(format: "GPU %.1f초", seconds) : "렌더 완료")
                .font(.caption2).foregroundStyle(.secondary)
        case .failed(let message):
            Text(message).font(.caption2).foregroundStyle(.red).lineLimit(2)
        }
    }
}

private struct FormulaInputSheet: View {
    @Environment(SketchModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    private var isPixelFormula: Bool { PixelFormulaParser.looksLikePixelFormula(model.formulaInputText) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: Binding(get: { model.formulaInputText }, set: { model.formulaInputText = $0 }))
                        .font(.system(.footnote, design: .monospaced))
                        .frame(minHeight: 160)
                    if let error = model.formulaInputError {
                        Text(error).font(.caption).foregroundStyle(.red)
                    }
                } header: {
                    Text(isPixelFormula ? "픽셀 수식 (LaTeX, rgb(…) + 정의)" : "SketchFormula (도형 + 변형, 색상 없음)")
                } footer: {
                    Text("SketchFormula DSL은 도형으로 그리고, rgb(…)로 시작하는 LaTeX 픽셀 수식은 GPU로 한 픽셀씩 계산해 배경으로 깔립니다.")
                }
                Section {
                    Button {
                        model.formulaInputText = PixelFormulaSamples.sample
                        model.formulaInputError = nil
                    } label: {
                        Label("예시 픽셀 수식 넣기 — \(PixelFormulaSamples.sampleTitle)", systemImage: "sparkles")
                    }
                }
            }
            .navigationTitle("수식으로 그리기")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isPixelFormula ? "렌더링" : "그리기") {
                        if model.loadFromFormulaInput() { dismiss() }
                    }
                    .disabled(model.formulaInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
