//

import SwiftUI

struct KeySignatureQuizView: View {
    @Environment(\.appPalette) private var palette

    let model: KeySignatureQuizModel

    var body: some View {
        ScrollView {
            VStack(spacing: LumenoteSpacing.lg) {
                progressHeader
                VStack(spacing: LumenoteSpacing.section) {
                    promptCard
                    choices
                    if model.hasAnswered {
                        advanceButton
                    }
                }
            }
            .padding(.horizontal, LumenoteSpacing.popupInset)
            .padding(.top, LumenoteSpacing.md)
            .padding(.bottom, LumenoteSpacing.xxxl)
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

    private var promptCard: some View {
        VStack(spacing: LumenoteSpacing.xl) {
            Text(promptTitle)
                .font(LumenoteFont.callout(.medium))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            switch model.question.kind {
            case .pickStaff:
                Text(model.question.promptKey.displayName)
                    .font(.system(size: 34, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(model.question.promptKey.displayName)
            case .pickKey:
                KeySignatureStaffView(
                    accidentals: model.question.promptAccidentals,
                    staffSpace: 12,
                    lineColor: Color.primary.opacity(0.75)
                )
                .frame(maxWidth: .infinity)
                .accessibilityLabel(
                    model.question.promptAccidentals.isEmpty
                        ? "조표 없는 오선"
                        : "조표가 표시된 오선"
                )
            }
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

    private var promptTitle: String {
        switch model.question.kind {
        case .pickStaff:
            return "다음 키의 조표는?"
        case .pickKey:
            return "다음 조표의 키는?"
        }
    }

    @ViewBuilder
    private var choices: some View {
        switch model.question.kind {
        case .pickStaff:
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: LumenoteSpacing.md),
                    GridItem(.flexible(), spacing: LumenoteSpacing.md),
                ],
                spacing: LumenoteSpacing.md
            ) {
                ForEach(model.question.staffChoices) { choice in
                    staffChoiceButton(choice)
                }
            }
        case .pickKey:
            VStack(spacing: LumenoteSpacing.md) {
                ForEach(model.question.keyChoices, id: \.id) { choice in
                    keyChoiceButton(choice)
                }
            }
        }
    }

    private func staffChoiceButton(_ choice: KeySignatureQuizModel.StaffChoice) -> some View {
        let answered = model.hasAnswered
        let isSelected = model.selectedChoiceID == choice.id
        let isCorrectChoice = choice.id == model.question.correctChoiceID
        let showsCorrect = answered && isCorrectChoice
        let showsIncorrect = answered && isSelected && !isCorrectChoice

        return Button {
            model.select(choiceID: choice.id)
        } label: {
            VStack(spacing: LumenoteSpacing.md) {
                KeySignatureStaffView(
                    accidentals: choice.accidentals,
                    staffSpace: 9,
                    lineColor: Color.primary.opacity(0.75)
                )
                .frame(maxWidth: .infinity)

                choiceStatusIcon(showsCorrect: showsCorrect, showsIncorrect: showsIncorrect)
                    .frame(height: 16)
            }
            .padding(.horizontal, LumenoteSpacing.md)
            .padding(.vertical, LumenoteSpacing.xl)
            .frame(maxWidth: .infinity, minHeight: 96)
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
        .accessibilityLabel(staffAccessibilityLabel(for: choice))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(answered ? "" : "답을 선택하려면 두 번 탭하세요")
    }

    private func keyChoiceButton(_ choice: KeySignatureQuizModel.QuizKey) -> some View {
        let answered = model.hasAnswered
        let isSelected = model.selectedChoiceID == choice.id
        let isCorrectChoice = choice.id == model.question.correctChoiceID
        let showsCorrect = answered && isCorrectChoice
        let showsIncorrect = answered && isSelected && !isCorrectChoice

        return Button {
            model.select(choiceID: choice.id)
        } label: {
            HStack {
                Text(choice.displayName)
                    .font(LumenoteFont.body(.bold))
                    .foregroundStyle(.primary)
                Spacer()
                choiceStatusIcon(showsCorrect: showsCorrect, showsIncorrect: showsIncorrect)
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
        .accessibilityLabel(choice.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(answered ? "" : "답을 선택하려면 두 번 탭하세요")
    }

    @ViewBuilder
    private func choiceStatusIcon(showsCorrect: Bool, showsIncorrect: Bool) -> some View {
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

    private func staffAccessibilityLabel(for choice: KeySignatureQuizModel.StaffChoice) -> String {
        if choice.accidentals.isEmpty {
            return "조표 없음"
        }
        let symbol = choice.signatureIndex > 0 ? "샵" : "플랫"
        return "\(symbol) \(abs(choice.signatureIndex))개"
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
        KeySignatureQuizDifficultyView()
    }
    .lumenotePalette()
}
