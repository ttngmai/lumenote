//

import SwiftUI

struct IntervalQuizView: View {
    @Environment(\.appPalette) private var palette
    @AppStorage(AppearanceMode.storageKey) private var appearance: AppearanceMode = .system

    @State private var model = IntervalQuizModel()

    var body: some View {
        ScrollView {
            VStack(spacing: LumenoteSpacing.section) {
                scoreRow
                promptCard
                choices
                if model.hasAnswered {
                    nextButton
                }
            }
            .padding(.horizontal, LumenoteSpacing.popupInset)
            .padding(.vertical, LumenoteSpacing.xxxl)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(background)
        .lumenoteCompactHeader(title: "음정 퀴즈", showsBackButton: true) {
            AppearanceToggleButton(appearance: $appearance)
        }
    }

    private var scoreRow: some View {
        HStack {
            Text("맞힌 문제")
                .font(LumenoteFont.caption(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(model.correctCount) / \(model.answeredCount)")
                .font(LumenoteFont.body(.bold))
                .foregroundStyle(.primary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("맞힌 문제 \(model.correctCount)개, 전체 \(model.answeredCount)개")
    }

    private var promptCard: some View {
        VStack(spacing: LumenoteSpacing.xl) {
            Text("다음 두 음의 음정은?")
                .font(LumenoteFont.caption(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            IntervalStaffView(
                notes: model.question.staffNotes,
                staffSpace: 12,
                lineColor: Color.primary.opacity(0.75),
                noteColor: Color.primary
            )
            .frame(maxWidth: .infinity)

            HStack(spacing: LumenoteSpacing.md) {
                Text(model.question.rootDisplayName)
                    .font(.system(size: 28, weight: .bold))
                Image(systemName: "arrow.right")
                    .font(LumenoteFont.callout(.semibold))
                    .foregroundStyle(palette.minor)
                Text(model.question.targetDisplayName)
                    .font(.system(size: 28, weight: .bold))
            }
            .accessibilityElement(children: .combine)
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
                        .foregroundStyle(palette.minor)
                } else if showsIncorrect {
                    Image(systemName: "xmark")
                        .font(LumenoteFont.callout(.bold))
                        .foregroundStyle(palette.major)
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
        .disabled(answered)
        .accessibilityLabel(choice)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(answered ? "" : "답을 선택하려면 두 번 탭하세요")
    }

    private func choiceBackground(showsCorrect: Bool, showsIncorrect: Bool) -> Color {
        if showsCorrect { return palette.highlightSoft }
        if showsIncorrect { return palette.major.opacity(0.12) }
        return palette.cardBackground
    }

    private func choiceBorder(showsCorrect: Bool, showsIncorrect: Bool) -> Color {
        if showsCorrect { return palette.minor.opacity(0.55) }
        if showsIncorrect { return palette.major.opacity(0.55) }
        return palette.divider
    }

    private var nextButton: some View {
        Button {
            model.nextQuestion()
        } label: {
            Text("다음 문제")
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
        .accessibilityHint("다음 문제로 넘어가려면 두 번 탭하세요")
    }

    private var background: some View {
        LinearGradient(
            colors: palette.backgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

#Preview {
    NavigationStack {
        IntervalQuizView()
    }
    .lumenotePalette()
}
