//

import SwiftUI

struct FretboardScaleQuizView: View {
    @Environment(\.appPalette) private var palette
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    let model: FretboardScaleQuizModel

    private var isCompactHeight: Bool {
        verticalSizeClass == .compact
    }

    var body: some View {
        ScrollView {
            VStack(spacing: isCompactHeight ? LumenoteSpacing.md : LumenoteSpacing.section) {
                progressHeader
                promptCard
                fretboardCard
                actionRow
            }
            .padding(
                .horizontal,
                isCompactHeight ? LumenoteSpacing.lg : LumenoteSpacing.popupInset
            )
            .padding(
                .vertical,
                isCompactHeight ? LumenoteSpacing.sm : LumenoteSpacing.xxxl
            )
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    private var progressHeader: some View {
        HStack(spacing: model.questionLimit > 20 ? 1 : 2) {
            ForEach(0..<model.questionLimit, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(segmentColor(at: index))
                    .frame(maxWidth: .infinity)
                    .frame(height: 10)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            L10n.s(
                "\(model.questionLimit)문제 중 \(model.answeredCount)문제, 맞힌 \(model.correctCount)개, 틀린 \(model.incorrectCount)개"
            )
        )
    }

    private func segmentColor(at index: Int) -> Color {
        guard index < model.outcomes.count else {
            return Color.primary.opacity(0.12)
        }
        return model.outcomes[index] ? palette.quizCorrect : palette.quizIncorrect
    }

    private var promptCard: some View {
        VStack(alignment: .leading, spacing: LumenoteSpacing.xxs) {
            Text(model.question.promptTitle)
                .font(LumenoteFont.rounded(size: isCompactHeight ? 22 : 28, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(model.question.position.title)
                .font(LumenoteFont.body(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(model.instruction)
                .font(LumenoteFont.caption(.medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, LumenoteSpacing.xxl)
        .padding(.vertical, isCompactHeight ? LumenoteSpacing.md : LumenoteSpacing.xl)
        .background(palette.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous)
                .strokeBorder(palette.divider, lineWidth: LumenoteStroke.compact)
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityLabel(
            "\(model.question.promptTitle), \(model.question.position.title). \(model.instruction)"
        )
    }

    private var fretboardCard: some View {
        GeometryReader { geo in
            let frets = model.question.position.fretRange
            let naturalWidth = FretboardDiagramView.boardWidth(frets: frets, showsStringLabels: false)
            let available = max(geo.size.width, 1)
            let diagram = FretboardDiagramView(
                accidental: model.question.accidental,
                firstFret: frets.lowerBound,
                lastFret: frets.upperBound,
                selectedPositions: model.selectedPositions,
                hasAnswered: model.hasAnswered,
                showsStringLabels: false,
                labelMode: .degree,
                rootPitchClass: model.question.tonicPitchClass,
                scaleQuizMarks: model.question.marks,
                onSelect: { model.toggle($0) }
            )

            Group {
                if available >= naturalWidth {
                    diagram
                        .frame(width: available)
                } else {
                    let scale = available / naturalWidth
                    diagram
                        .frame(width: naturalWidth, height: FretboardDiagramView.preferredHeight)
                        .scaleEffect(scale, anchor: .center)
                        .frame(width: available, height: FretboardDiagramView.preferredHeight * scale)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(height: FretboardDiagramView.preferredHeight)
        .padding(.horizontal, LumenoteSpacing.xs)
        .padding(.vertical, isCompactHeight ? LumenoteSpacing.xs : LumenoteSpacing.xl)
        .frame(maxWidth: .infinity)
        .background(palette.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous)
                .strokeBorder(palette.divider, lineWidth: LumenoteStroke.compact)
        )
    }

    @ViewBuilder
    private var actionRow: some View {
        if model.hasAnswered {
            advanceButton
        } else {
            VStack(spacing: LumenoteSpacing.md) {
                Text(L10n.s("선택 \(model.placedCount) / \(model.answerCount)"))
                    .font(LumenoteFont.callout(.bold))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(L10n.s("선택 \(model.placedCount) / \(model.answerCount)"))

                Button {
                    model.confirm()
                } label: {
                    Text("정답 확인".l10n)
                        .font(LumenoteFont.body(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, isCompactHeight ? LumenoteSpacing.md : LumenoteSpacing.xxl)
                        .background(
                            RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous)
                                .fill(palette.minor)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityHint("정답을 확인하려면 두 번 탭하세요".l10n)
            }
        }
    }

    private var advanceButton: some View {
        let showsResult = model.isOnFinalAnswer
        return Button {
            if showsResult {
                model.finish()
            } else {
                model.nextQuestion()
            }
        } label: {
            Text((showsResult ? "결과 보기" : "다음 문제").l10n)
                .font(LumenoteFont.body(.bold))
                .foregroundStyle(.white)
                .padding(.vertical, isCompactHeight ? LumenoteSpacing.md : LumenoteSpacing.xxl)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous)
                        .fill(palette.minor)
                )
        }
        .buttonStyle(.plain)
        .accessibilityHint((showsResult ? "결과를 보려면 두 번 탭하세요" : "다음 문제로 넘어가려면 두 번 탭하세요").l10n)
    }
}

#Preview {
    NavigationStack {
        FretboardScaleQuizDifficultyView()
    }
    .lumenotePalette()
}
