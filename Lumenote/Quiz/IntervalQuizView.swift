//

import SwiftUI

struct IntervalQuizView: View {
    @Environment(\.appPalette) private var palette

    let model: IntervalQuizModel

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
            switch model.question.task {
            case .identifyInterval:
                identifyPrompt
            case .spellTarget:
                spellPrompt
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

    private var identifyPrompt: some View {
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
    }

    private var spellPrompt: some View {
        emphasizedPrompt(spellPromptFormat, arguments: spellPromptArguments)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(spellPromptTitle)
    }

    private var spellPromptArguments: [String] {
        [
            model.question.rootDisplayName,
            model.question.intervalName.l10n,
            model.question.directionName.l10n,
        ]
    }

    private var spellPromptFormat: String {
        L10n.string("%@에서 %@ %@한 음은?")
    }

    private var spellPromptTitle: String {
        String(format: spellPromptFormat, locale: L10n.locale, arguments: spellPromptArguments)
    }

    /// Bolds each format argument so the note, interval, and direction stay emphasized
    /// after the translated sentence reorders them.
    private func emphasizedPrompt(_ format: String, arguments: [String]) -> Text {
        var result = AttributedString()
        var cursor = format.startIndex
        var nextAutomatic = 0

        while cursor < format.endIndex {
            guard format[cursor] == "%" else {
                let next = format[cursor...].dropFirst().firstIndex(of: "%") ?? format.endIndex
                result.append(promptText(String(format[cursor..<next]), emphasized: false))
                cursor = next
                continue
            }

            let afterPercent = format.index(after: cursor)
            if afterPercent < format.endIndex, format[afterPercent] == "%" {
                result.append(promptText("%", emphasized: false))
                cursor = format.index(after: afterPercent)
                continue
            }

            guard let parsed = formatArgument(in: format, from: cursor, automatic: &nextAutomatic) else {
                result.append(promptText(String(format[cursor]), emphasized: false))
                cursor = format.index(after: cursor)
                continue
            }

            let value = arguments.indices.contains(parsed.index) ? arguments[parsed.index] : ""
            result.append(promptText(value, emphasized: true))
            cursor = parsed.end
        }

        return Text(result)
    }

    private func formatArgument(
        in format: String,
        from percent: String.Index,
        automatic: inout Int
    ) -> (index: Int, end: String.Index)? {
        var cursor = format.index(after: percent)
        guard cursor < format.endIndex else { return nil }

        if format[cursor].isNumber {
            var digits = ""
            while cursor < format.endIndex, format[cursor].isNumber {
                digits.append(format[cursor])
                cursor = format.index(after: cursor)
            }
            guard cursor < format.endIndex, format[cursor] == "$" else { return nil }
            cursor = format.index(after: cursor)
            guard cursor < format.endIndex, format[cursor] == "@" else { return nil }
            guard let position = Int(digits), position > 0 else { return nil }
            return (position - 1, format.index(after: cursor))
        }

        guard format[cursor] == "@" else { return nil }
        let index = automatic
        automatic += 1
        return (index, format.index(after: cursor))
    }

    private func promptText(_ value: String, emphasized: Bool) -> AttributedString {
        var text = AttributedString(value)
        text.font = LumenoteFont.callout(emphasized ? .bold : .medium)
        text.foregroundColor = emphasized ? palette.minor : .primary
        return text
    }

    private var choices: some View {
        QuizChoiceLayout {
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
                Text(choice.l10n)
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
        .accessibilityLabel(choice.l10n)
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
            Text((showsResult ? "결과 보기" : "다음 문제").l10n)
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
        .accessibilityHint((showsResult ? "결과를 보려면 두 번 탭하세요" : "다음 문제로 넘어가려면 두 번 탭하세요").l10n)
    }
}

#Preview {
    NavigationStack {
        IntervalQuizDifficultyView()
    }
    .lumenotePalette()
}
