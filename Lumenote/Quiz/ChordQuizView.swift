//

import SwiftUI

struct ChordQuizView: View {
    @Environment(\.appPalette) private var palette

    let model: ChordQuizModel

    var body: some View {
        ScrollView {
            VStack(spacing: LumenoteSpacing.lg) {
                progressHeader
                VStack(spacing: LumenoteSpacing.section) {
                    promptCard
                    choices
                    if model.hasAnswered, let answer = model.selectedAnswer {
                        feedbackCard(for: answer)
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
            promptTitleView

            switch model.question.kind {
            case .identifyChord:
                identifyChordPrompt
            case .completeChord, .completeFormula:
                tokenPrompt
            case .identifyTone:
                EmptyView()
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

    private var promptTitleView: some View {
        highlightedPrompt(model.question.promptTitle, highlights: model.promptHighlights)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(model.question.promptTitle)
    }

    private func highlightedPrompt(_ title: String, highlights: [String]) -> Text {
        var attributed = AttributedString(title)
        attributed.font = LumenoteFont.callout(.medium)
        attributed.foregroundColor = .primary

        for phrase in highlights where !phrase.isEmpty {
            guard let range = attributed.range(of: phrase) else { continue }
            attributed[range].font = LumenoteFont.callout(.bold)
            attributed[range].foregroundColor = palette.minor
        }

        return Text(attributed)
    }

    private var identifyChordPrompt: some View {
        Group {
            if !model.question.staffNotes.isEmpty {
                ChordStaffView(
                    notes: model.question.staffNotes,
                    noteNames: model.question.staffNoteNames,
                    degreeLabels: [],
                    staffSpace: 10,
                    targetWidth: nil,
                    showsToneLabels: false,
                    lineColor: Color.primary.opacity(0.75),
                    noteColor: Color.primary,
                    accentColor: palette.minor
                )
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var tokenPrompt: some View {
        HStack(spacing: LumenoteSpacing.sm) {
            ForEach(Array(model.question.promptTokens.enumerated()), id: \.offset) { index, token in
                tokenView(token, index: index, total: model.question.promptTokens.count)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityPrompt(for: model.question.promptTokens))
    }

    @ViewBuilder
    private func tokenView(
        _ token: ChordQuizModel.PromptToken,
        index: Int,
        total: Int
    ) -> some View {
        HStack(spacing: LumenoteSpacing.sm) {
            switch token {
            case .note(let name):
                Text(name)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.primary)
            case .blank:
                Text("?")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(palette.minor)
            case .degree(let label):
                Text(label)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.primary)
            case .degreeBlank:
                Text("?")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(palette.minor)
            }

            if index < total - 1 {
                Text("·")
                    .font(LumenoteFont.callout(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func accessibilityPrompt(for tokens: [ChordQuizModel.PromptToken]) -> String {
        tokens.map { token in
            switch token {
            case .note(let name): return name
            case .degree(let label): return label
            case .blank, .degreeBlank: return "빈칸"
            }
        }
        .joined(separator: ", ")
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

    private func feedbackCard(for answer: String) -> some View {
        let feedback = model.feedback(for: answer)
        let isCorrect = model.isSelectionCorrect

        return VStack(alignment: .leading, spacing: LumenoteSpacing.sm) {
            Text(feedback.headline)
                .font(LumenoteFont.body(.bold))
                .foregroundStyle(isCorrect ? palette.quizCorrect : .primary)
            if !feedback.detail.isEmpty {
                Text(feedback.detail)
                    .font(LumenoteFont.callout(.medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if model.question.kind == .completeChord || model.question.kind == .identifyTone {
                explanationStaff
            }
        }
        .padding(LumenoteSpacing.xxl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous)
                .fill(isCorrect ? palette.quizCorrectBackground : palette.quizIncorrectBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous)
                .strokeBorder(
                    isCorrect ? palette.quizCorrect : palette.quizIncorrect,
                    lineWidth: LumenoteStroke.compact
                )
        )
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var explanationStaff: some View {
        if !model.question.staffNotes.isEmpty {
            ChordStaffView(
                notes: model.question.staffNotes,
                noteNames: model.question.staffNoteNames,
                degreeLabels: model.question.explanationContext.kind.tones.map(\.degreeLabel),
                staffSpace: 14,
                targetWidth: nil,
                lineColor: Color.primary.opacity(0.75),
                noteColor: Color.primary,
                accentColor: palette.minor
            )
            .frame(maxWidth: .infinity)
            .padding(.top, LumenoteSpacing.sm)
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
        ChordQuizDifficultyView()
    }
    .lumenotePalette()
}
