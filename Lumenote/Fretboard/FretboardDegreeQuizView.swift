//

import SwiftUI

struct FretboardDegreeQuizView: View {
    @Environment(\.appPalette) private var palette
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    let model: FretboardDegreeQuizModel

    private var isCompactHeight: Bool {
        verticalSizeClass == .compact
    }

    var body: some View {
        ScrollView {
            VStack(spacing: isCompactHeight ? LumenoteSpacing.md : LumenoteSpacing.section) {
                progressHeader
                promptRow
                fretboardCard
                if !isCompactHeight, model.hasAnswered {
                    advanceButton(compact: false)
                }
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
            "\(model.questionLimit)문제 중 \(model.answeredCount)문제, 맞힌 \(model.correctCount)개, 틀린 \(model.incorrectCount)개"
        )
    }

    private func segmentColor(at index: Int) -> Color {
        guard index < model.outcomes.count else {
            return Color.primary.opacity(0.12)
        }
        return model.outcomes[index] ? palette.quizCorrect : palette.quizIncorrect
    }

    private var promptRow: some View {
        ZStack {
            promptCard
            if isCompactHeight, model.hasAnswered {
                advanceButton(compact: true)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var promptCard: some View {
        Text(model.displayName)
            .font(LumenoteFont.rounded(size: 36, weight: .bold))
            .foregroundStyle(.primary)
            .padding(.horizontal, LumenoteSpacing.xxl)
            .padding(.vertical, LumenoteSpacing.md)
            .background(palette.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous)
                    .strokeBorder(palette.divider, lineWidth: LumenoteStroke.compact)
            )
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel("목표 도수 \(model.accessibilityName)")
    }

    private var fretboardCard: some View {
        GeometryReader { geo in
            let frets = model.question.fretWindow
            let minWidth = FretboardDiagramView.boardWidth(frets: frets, showsStringLabels: false)
            let needsScroll = geo.size.width < minWidth
            let diagram = FretboardDiagramView(
                accidental: model.question.accidental,
                firstFret: frets.lowerBound,
                lastFret: frets.upperBound,
                selectedPosition: model.selectedPosition,
                targetPitchClass: model.question.targetPitchClass,
                hasAnswered: model.hasAnswered,
                hintPosition: model.question.rootPosition,
                showsStringLabels: false,
                labelMode: .degree,
                rootPitchClass: model.question.rootPitchClass,
                onSelect: { model.select($0) }
            )

            Group {
                if needsScroll {
                    ScrollView(.horizontal, showsIndicators: false) {
                        diagram
                            .frame(width: minWidth)
                    }
                } else {
                    diagram
                        .frame(width: geo.size.width)
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

    private func advanceButton(compact: Bool) -> some View {
        let showsResult = model.isOnFinalAnswer
        return Button {
            if showsResult {
                model.finish()
            } else {
                model.nextQuestion()
            }
        } label: {
            Text(showsResult ? "결과 보기" : "다음 문제")
                .font(LumenoteFont.body(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, compact ? LumenoteSpacing.xxxl : 0)
                .padding(.vertical, compact ? LumenoteSpacing.md : LumenoteSpacing.xxl)
                .frame(maxWidth: compact ? nil : .infinity)
                .background(
                    RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous)
                        .fill(palette.minor)
                )
        }
        .buttonStyle(.plain)
        .accessibilityHint(showsResult ? "결과를 보려면 두 번 탭하세요" : "다음 문제로 넘어가려면 두 번 탭하세요")
    }
}

#Preview {
    NavigationStack {
        FretboardDegreeQuizDifficultyView()
    }
    .lumenotePalette()
}
