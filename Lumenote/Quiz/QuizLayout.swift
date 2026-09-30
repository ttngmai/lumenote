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
