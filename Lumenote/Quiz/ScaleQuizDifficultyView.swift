//

import SwiftUI

/// Chooses difficulty and length, then runs the scale quiz in place.
/// The quiz is not pushed, so its back button returns to the feature menu.
struct ScaleQuizDifficultyView: View {
    @Environment(\.appPalette) private var palette
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppearanceMode.storageKey) private var appearance: AppearanceMode = .system

    @State private var selectedDifficulty: ScaleQuizDifficulty = .easy
    @State private var questionCount = 10
    @State private var model: ScaleQuizModel?

    private let questionCounts = [10, 20, 30, 40, 50]

    var body: some View {
        Group {
            if let model {
                if model.isFinished {
                    result(model)
                } else {
                    ScaleQuizView(model: model)
                }
            } else {
                setup
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(background)
        .lumenoteCompactHeader(title: "스케일 퀴즈", showsBackButton: true) {
            AppearanceToggleButton(appearance: $appearance)
        }
    }

    private var setup: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LumenoteSpacing.section) {
                Text("난이도와 문제 수를 선택하세요.")
                    .font(LumenoteFont.callout(.medium))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: LumenoteSpacing.md) {
                    ForEach(ScaleQuizDifficulty.allCases) { difficulty in
                        Button {
                            selectedDifficulty = difficulty
                        } label: {
                            difficultyRow(difficulty, isSelected: selectedDifficulty == difficulty)
                        }
                        .buttonStyle(.plain)
                    }
                }

                questionCountRow

                startButton
            }
            .padding(.horizontal, LumenoteSpacing.popupInset)
            .padding(.vertical, LumenoteSpacing.xxxl)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    private func difficultyRow(_ difficulty: ScaleQuizDifficulty, isSelected: Bool) -> some View {
        HStack(spacing: LumenoteSpacing.lg) {
            VStack(alignment: .leading, spacing: LumenoteSpacing.xs) {
                Text(difficulty.title)
                    .font(LumenoteFont.body(.bold))
                    .foregroundStyle(.primary)
                Text(difficulty.subtitle)
                    .font(LumenoteFont.caption(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(LumenoteFont.callout(.bold))
                    .foregroundStyle(palette.quizCorrect)
            }
        }
        .padding(LumenoteSpacing.xxl)
        .lumenoteCard(isActive: isSelected)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(difficulty.title), \(difficulty.subtitle)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("난이도를 선택하려면 두 번 탭하세요")
    }

    private var questionCountRow: some View {
        HStack(spacing: LumenoteSpacing.lg) {
            Text("문제 수")
                .font(LumenoteFont.body(.bold))
                .foregroundStyle(.primary)

            Spacer(minLength: LumenoteSpacing.md)

            countButton(systemName: "minus", label: "10문제 줄이기") {
                questionCount = max(questionCounts[0], questionCount - 10)
            }
            .disabled(questionCount <= questionCounts[0])

            Text("\(questionCount)")
                .font(LumenoteFont.body(.bold))
                .foregroundStyle(.primary)
                .monospacedDigit()
                .frame(minWidth: 28)

            countButton(systemName: "plus", label: "10문제 늘리기") {
                questionCount = min(questionCounts[questionCounts.count - 1], questionCount + 10)
            }
            .disabled(questionCount >= questionCounts[questionCounts.count - 1])
        }
        .padding(LumenoteSpacing.xxl)
        .lumenoteCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("문제 수 \(questionCount)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                questionCount = min(50, questionCount + 10)
            case .decrement:
                questionCount = max(10, questionCount - 10)
            @unknown default:
                break
            }
        }
    }

    private func countButton(systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(LumenoteFont.callout(.bold))
                .foregroundStyle(.primary)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var startButton: some View {
        Button {
            model = ScaleQuizModel(difficulty: selectedDifficulty, questionLimit: questionCount)
        } label: {
            Text("시작")
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
        .accessibilityHint("퀴즈를 시작하려면 두 번 탭하세요")
    }

    private func result(_ model: ScaleQuizModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LumenoteSpacing.section) {
                Text("퀴즈를 마쳤습니다")
                    .font(LumenoteFont.callout(.medium))
                    .foregroundStyle(.primary)

                Text("\(model.difficulty.title) · \(model.questionLimit)문제")
                    .font(LumenoteFont.callout(.medium))
                    .foregroundStyle(.primary)

                VStack(spacing: LumenoteSpacing.md) {
                    resultRow(title: "정답", count: model.correctCount, color: palette.quizCorrect)
                    resultRow(title: "오답", count: model.incorrectCount, color: palette.quizIncorrect)
                }

                Button {
                    dismiss()
                } label: {
                    Text("메뉴로 돌아가기")
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
                .accessibilityHint("메뉴로 돌아가려면 두 번 탭하세요")
            }
            .padding(.horizontal, LumenoteSpacing.popupInset)
            .padding(.vertical, LumenoteSpacing.xxxl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
    }

    private func resultRow(title: String, count: Int, color: Color) -> some View {
        HStack {
            Text(title)
                .font(LumenoteFont.body(.bold))
                .foregroundStyle(.primary)
            Spacer()
            Text("\(count)")
                .font(LumenoteFont.body(.bold))
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .padding(LumenoteSpacing.xxl)
        .lumenoteCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(count)개")
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
        ScaleQuizDifficultyView()
    }
    .lumenotePalette()
}
