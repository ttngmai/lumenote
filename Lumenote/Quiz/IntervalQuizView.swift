//

import SwiftUI

struct IntervalQuizView: View {
    @Environment(\.appPalette) private var palette

    let model: IntervalQuizModel

    var body: some View {
        ScrollView {
            VStack(spacing: LumenoteSpacing.section) {
                progressHeader
                promptCard
                choices
                if model.hasAnswered {
                    advanceButton
                }
            }
            .padding(.horizontal, LumenoteSpacing.popupInset)
            .padding(.vertical, LumenoteSpacing.xxxl)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: LumenoteSpacing.md) {
            Text(model.difficulty.title)
                .font(LumenoteFont.body(.bold))
                .foregroundStyle(.primary)

            HStack(spacing: model.questionLimit > 20 ? 1 : 2) {
                ForEach(0..<model.questionLimit, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(segmentColor(at: index))
                        .frame(maxWidth: .infinity)
                        .frame(height: 10)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(model.difficulty.title), \(model.questionLimit)문제 중 \(model.answeredCount)문제, 맞힌 \(model.correctCount)개, 틀린 \(model.incorrectCount)개"
        )
    }

    private func segmentColor(at index: Int) -> Color {
        guard index < model.outcomes.count else {
            return Color.primary.opacity(0.12)
        }
        return model.outcomes[index] ? palette.quizCorrect : palette.quizIncorrect
    }

    private var promptCard: some View {
        VStack(spacing: LumenoteSpacing.xl) {
            Text("다음 두 음의 음정은?")
                .font(LumenoteFont.callout(.medium))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            IntervalStaffView(
                notes: model.question.staffNotes,
                staffSpace: 12,
                lineColor: Color.primary.opacity(0.75),
                noteColor: Color.primary
            )
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(model.question.rootDisplayName)에서 \(model.question.targetDisplayName)")
        }
        .padding(LumenoteSpacing.xxl)
        .frame(maxWidth: .infinity)
        .background(palette.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous)
                .strokeBorder(palette.divider, lineWidth: LumenoteStroke.compact)
        )
    }

    private var choices: some View {
        VStack(spacing: LumenoteSpacing.md) {
            ForEach(model.question.choices, id: \.self) { choice in
                choiceButton(choice)
            }
        }
    }

    private func choiceButton(_ choice: String) -> some View {
        let answered = model.hasAnswered
        let isSelected = model.selectedAnswer == choice
        let isCorrectChoice = choice == model.question.correctAnswer
        let showsCorrect = answered && isCorrectChoice
        let showsIncorrect = answered && isSelected && !isCorrectChoice

        return Button {
            model.select(choice)
        } label: {
            HStack {
                Text(choice)
                    .font(LumenoteFont.body(.bold))
                    .foregroundStyle(.primary)
                Spacer()
                if showsCorrect {
                    Image(systemName: "checkmark")
                        .font(LumenoteFont.callout(.bold))
                        .foregroundStyle(palette.quizCorrect)
                } else if showsIncorrect {
                    Image(systemName: "xmark")
                        .font(LumenoteFont.callout(.bold))
                        .foregroundStyle(palette.quizIncorrect)
                }
            }
            .padding(.horizontal, LumenoteSpacing.xxl)
            .padding(.vertical, LumenoteSpacing.xxl)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous)
                    .fill(choiceBackground(showsCorrect: showsCorrect, showsIncorrect: showsIncorrect))
            )
            .overlay(
                RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous)
                    .strokeBorder(
                        choiceBorder(showsCorrect: showsCorrect, showsIncorrect: showsIncorrect),
                        lineWidth: (showsCorrect || showsIncorrect) ? LumenoteStroke.compact : LumenoteStroke.hairline
                    )
            )
        }
        .buttonStyle(.plain)
        .opacity(answered && !showsCorrect && !showsIncorrect ? 0.45 : 1)
        .allowsHitTesting(!answered)
        .accessibilityLabel(choice)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(answered ? "" : "답을 선택하려면 두 번 탭하세요")
    }

    private func choiceBackground(showsCorrect: Bool, showsIncorrect: Bool) -> Color {
        if showsCorrect { return palette.quizCorrectBackground }
        if showsIncorrect { return palette.quizIncorrectBackground }
        return palette.cardBackground
    }

    private func choiceBorder(showsCorrect: Bool, showsIncorrect: Bool) -> Color {
        if showsCorrect { return palette.quizCorrect }
        if showsIncorrect { return palette.quizIncorrect }
        return palette.divider
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
            Text(showsResult ? "결과 보기" : "다음 문제")
                .font(LumenoteFont.body(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, LumenoteSpacing.xxl)
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
        IntervalQuizDifficultyView()
    }
    .lumenotePalette()
}
