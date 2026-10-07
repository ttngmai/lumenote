//

import SwiftUI

/// Easy, Normal, and Hard sit in one row: left, center, right.
struct QuizDifficultyChoices<Difficulty: Hashable & Identifiable>: View {
    let options: [Difficulty]
    let title: (Difficulty) -> String
    let selection: Difficulty
    let onSelect: (Difficulty) -> Void

    @Environment(\.appPalette) private var palette

    var body: some View {
        HStack(spacing: LumenoteSpacing.md) {
            ForEach(options) { difficulty in
                let isSelected = selection == difficulty
                Button {
                    onSelect(difficulty)
                } label: {
                    HStack(spacing: LumenoteSpacing.xs) {
                        Color.clear
                            .frame(width: LumenoteSpacing.xl)
                            .padding(.leading, LumenoteSpacing.sm)
                        Text(title(difficulty))
                            .font(LumenoteFont.body(.bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity)
                        Image(systemName: "checkmark")
                            .font(LumenoteFont.caption(.bold))
                            .foregroundStyle(palette.quizCorrect)
                            .frame(width: LumenoteSpacing.xl)
                            .padding(.trailing, LumenoteSpacing.sm)
                            .opacity(isSelected ? 1 : 0)
                    }
                    .padding(.vertical, LumenoteSpacing.xxl)
                    .padding(.horizontal, LumenoteSpacing.sm)
                    .lumenoteCard(isActive: isSelected)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(title(difficulty))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .accessibilityHint("난이도를 선택하려면 두 번 탭하세요")
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Returns to the quiz setup screen. Uses the same unfilled card as the menu button.
struct QuizReturnToSetupButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("퀴즈 설정 화면으로")
                .font(LumenoteFont.body(.bold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, LumenoteSpacing.xxl)
                .lumenoteCard()
        }
        .buttonStyle(.plain)
        .accessibilityHint("퀴즈 설정 화면으로 돌아가려면 두 번 탭하세요")
    }
}

/// Portrait keeps answers in a column. Landscape places them top-left, top-right, bottom-left, bottom-right.
struct QuizChoiceLayout<Content: View>: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @ViewBuilder var content: () -> Content

    private var isLandscape: Bool {
        verticalSizeClass == .compact
    }

    var body: some View {
        if isLandscape {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: LumenoteSpacing.md, alignment: .top),
                    GridItem(.flexible(), spacing: LumenoteSpacing.md, alignment: .top),
                ],
                spacing: LumenoteSpacing.md
            ) {
                content()
            }
        } else {
            VStack(spacing: LumenoteSpacing.md) {
                content()
            }
        }
    }
}

/// Top line of a quiz explanation card.
/// A correct answer shows a green check before “정답”. A miss shows the chosen
/// answer and the right answer, each preceded by a red or green circle mark.
struct QuizFeedbackHeadline: View {
    let headline: String
    let isCorrect: Bool

    @Environment(\.appPalette) private var palette

    var body: some View {
        if let comparison = QuizMissComparison.parse(headline), !isCorrect {
            HStack(alignment: .center, spacing: LumenoteSpacing.xs) {
                verdictMark(systemImage: "xmark.circle.fill", color: palette.quizIncorrect, label: "오답")
                Text(comparison.chosen)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("→")
                    .accessibilityHidden(true)
                verdictMark(systemImage: "checkmark.circle.fill", color: palette.quizCorrect, label: "정답")
                Text(comparison.expected)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .font(LumenoteFont.body(.bold))
            .foregroundStyle(.primary)
        } else if isCorrect {
            HStack(alignment: .center, spacing: LumenoteSpacing.xs) {
                verdictMark(systemImage: "checkmark.circle.fill", color: palette.quizCorrect, label: "정답")
                    .accessibilityHidden(true)
                Text(headline.l10n)
            }
            .font(LumenoteFont.body(.bold))
            .foregroundStyle(palette.quizCorrect)
        } else {
            Text(headline.l10n)
                .font(LumenoteFont.body(.bold))
                .foregroundStyle(.primary)
        }
    }

    private func verdictMark(systemImage: String, color: Color, label: String) -> some View {
        Image(systemName: systemImage)
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, color)
            .font(LumenoteFont.rounded(size: 18, weight: .semibold))
            .accessibilityLabel(label.l10n)
    }
}

/// Splits a miss headline such as `Ebm7 ✕ → F°7 ✓` into the two answers.
private struct QuizMissComparison {
    let chosen: String
    let expected: String

    static func parse(_ headline: String) -> QuizMissComparison? {
        let separator = " ✕ → "
        let suffix = " ✓"
        guard headline.hasSuffix(suffix),
              let separatorRange = headline.range(of: separator) else { return nil }
        let chosen = String(headline[..<separatorRange.lowerBound])
        let expectedEnd = headline.index(headline.endIndex, offsetBy: -suffix.count)
        guard separatorRange.upperBound < expectedEnd else { return nil }
        let expected = String(headline[separatorRange.upperBound..<expectedEnd])
        guard !chosen.isEmpty, !expected.isEmpty else { return nil }
        return QuizMissComparison(chosen: chosen, expected: expected)
    }
}
