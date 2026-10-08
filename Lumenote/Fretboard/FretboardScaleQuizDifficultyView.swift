//

import SwiftUI

/// Chooses difficulty, scales, and position system, then runs the scale quiz in place.
/// The quiz is not pushed, so its back button returns to the feature menu.
struct FretboardScaleQuizDifficultyView: View {
    @Environment(\.appPalette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(\.learningLog) private var learningLog

    @AppStorage(FretboardScaleQuizDifficulty.storageKey)
    private var selectedDifficulty: FretboardScaleQuizDifficulty = .normal
    @AppStorage(FretboardScaleQuizDifficulty.scalesStorageKey)
    private var scalesRaw = ScaleKind.allCases.map(\.rawValue).sorted().joined(separator: ",")
    @AppStorage(FretboardScaleQuizDifficulty.systemsStorageKey)
    private var systemsRaw = FretboardScaleFormSystem.allCases.map(\.rawValue).sorted().joined(separator: ",")
    @AppStorage(FretboardScaleQuizDifficulty.questionCountStorageKey)
    private var questionCount = 10
    @State private var model: FretboardScaleQuizModel?

    private let questionCounts = [10, 20, 30, 40, 50]

    private var selectedScales: Set<ScaleKind> {
        FretboardScaleQuizSkill.scales(from: scalesRaw)
    }

    private var selectedSystems: Set<FretboardScaleFormSystem> {
        FretboardScaleQuizSkill.systems(from: systemsRaw)
    }

    private var canStart: Bool {
        FretboardScaleQuizSkill.hasQuestions(scales: selectedScales, systems: selectedSystems)
    }

    var body: some View {
        Group {
            if let model {
                if model.isFinished {
                    result(model)
                } else {
                    FretboardScaleQuizView(model: model)
                }
            } else {
                setup
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(background)
        .lumenoteCompactHeader(title: "지판 퀴즈 (스케일)", showsBackButton: true)
    }

    private var setup: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LumenoteSpacing.section) {
                Text("난이도, 스케일, 포지션 방식, 문제 수를 선택하세요.".l10n)
                    .font(LumenoteFont.callout(.medium))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                QuizDifficultyChoices(
                    options: Array(FretboardScaleQuizDifficulty.allCases),
                    title: \.title,
                    selection: selectedDifficulty
                ) { selectedDifficulty = $0 }

                Text(selectedDifficulty.detail)
                    .font(LumenoteFont.callout(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                scaleCard
                systemCard
                questionCountRow
                startButton
            }
            .padding(.horizontal, LumenoteSpacing.popupInset)
            .padding(.vertical, LumenoteSpacing.xxxl)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    private var scaleCard: some View {
        VStack(alignment: .leading, spacing: LumenoteSpacing.lg) {
            Text("출제 스케일".l10n)
                .font(LumenoteFont.body(.bold))
                .foregroundStyle(.primary)

            ForEach(ScaleCategory.allCases) { category in
                VStack(alignment: .leading, spacing: LumenoteSpacing.sm) {
                    Text(category.title.l10n)
                        .font(LumenoteFont.caption(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(category.kinds) { kind in
                        choiceButton(
                            title: kind.englishTitle,
                            detail: nil,
                            isSelected: selectedScales.contains(kind),
                            isEnabled: true
                        ) {
                            toggleScale(kind)
                        }
                    }
                }
            }
        }
        .padding(LumenoteSpacing.xxl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lumenoteCard()
    }

    private var systemCard: some View {
        VStack(alignment: .leading, spacing: LumenoteSpacing.lg) {
            Text("포지션 방식".l10n)
                .font(LumenoteFont.body(.bold))
                .foregroundStyle(.primary)

            ForEach(FretboardScaleFormSystem.allCases) { system in
                let available = FretboardScaleQuizSkill.systemIsAvailable(system, scales: selectedScales)
                choiceButton(
                    title: system.title,
                    detail: available ? nil : "선택한 스케일에는 사용할 수 없습니다".l10n,
                    isSelected: selectedSystems.contains(system),
                    isEnabled: available
                ) {
                    toggleSystem(system)
                }
            }
        }
        .padding(LumenoteSpacing.xxl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lumenoteCard()
    }

    private func choiceButton(
        title: String,
        detail: String?,
        isSelected: Bool,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: LumenoteSpacing.md) {
                Image(systemName: isSelected && isEnabled ? "checkmark.circle.fill" : "circle")
                    .font(LumenoteFont.body(.bold))
                    .foregroundStyle(.primary)
                    .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: LumenoteSpacing.xxs) {
                    Text(title)
                        .font(LumenoteFont.body(.bold))
                        .foregroundStyle(.primary)
                    if let detail {
                        Text(detail)
                            .font(LumenoteFont.callout(.medium))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected && isEnabled ? .isSelected : [])
    }

    private var questionCountRow: some View {
        HStack(spacing: LumenoteSpacing.lg) {
            Text("문제 수".l10n)
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
        .accessibilityLabel("\("문제 수".l10n) \(questionCount)")
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
        .accessibilityLabel(label.l10n)
    }

    private var startButton: some View {
        Button {
            guard canStart else { return }
            model = makeModel(
                difficulty: selectedDifficulty,
                questionLimit: questionCount,
                scales: selectedScales,
                systems: selectedSystems
            )
        } label: {
            Text("시작".l10n)
                .font(LumenoteFont.body(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, LumenoteSpacing.xxl)
                .background(
                    RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous)
                        .fill(palette.minor)
                )
                .opacity(canStart ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .disabled(!canStart)
        .accessibilityHint(
            canStart
                ? "퀴즈를 시작하려면 두 번 탭하세요".l10n
                : "스케일과 포지션 방식을 선택하세요".l10n
        )
    }

    private func result(_ model: FretboardScaleQuizModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LumenoteSpacing.section) {
                Text("퀴즈 풀이 결과".l10n)
                    .font(LumenoteFont.rounded(size: 22, weight: .bold))
                    .foregroundStyle(.primary)

                Text("\(model.difficulty.title) · \(L10n.s("\(model.questionLimit)문제"))")
                    .font(LumenoteFont.callout(.medium))
                    .foregroundStyle(.primary)

                VStack(spacing: LumenoteSpacing.md) {
                    resultRow(title: "정답", count: model.correctCount, color: palette.quizCorrect)
                    resultRow(title: "오답", count: model.incorrectCount, color: palette.quizIncorrect)
                }

                Button {
                    self.model = makeModel(
                        difficulty: model.difficulty,
                        questionLimit: model.questionLimit,
                        scales: model.scales,
                        systems: model.systems
                    )
                } label: {
                    Text("같은 설정으로 다시 풀기".l10n)
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
                .accessibilityHint("같은 설정으로 다시 풀려면 두 번 탭하세요".l10n)

                QuizReturnToSetupButton {
                    self.model = nil
                }

                Button {
                    dismiss()
                } label: {
                    Text("메뉴로 돌아가기".l10n)
                        .font(LumenoteFont.body(.bold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, LumenoteSpacing.xxl)
                        .lumenoteCard()
                }
                .buttonStyle(.plain)
                .accessibilityHint("메뉴로 돌아가려면 두 번 탭하세요".l10n)
            }
            .padding(.horizontal, LumenoteSpacing.popupInset)
            .padding(.vertical, LumenoteSpacing.xxxl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
    }

    private func makeModel(
        difficulty: FretboardScaleQuizDifficulty,
        questionLimit: Int,
        scales: Set<ScaleKind>,
        systems: Set<FretboardScaleFormSystem>
    ) -> FretboardScaleQuizModel {
        FretboardScaleQuizModel(
            difficulty: difficulty,
            questionLimit: questionLimit,
            scales: scales,
            systems: systems,
            recorder: learningLog
        )
    }

    private func toggleScale(_ kind: ScaleKind) {
        var scales = selectedScales
        if scales.contains(kind) {
            scales.remove(kind)
        } else {
            scales.insert(kind)
        }
        scalesRaw = FretboardScaleQuizSkill.rawScales(scales)
    }

    private func toggleSystem(_ system: FretboardScaleFormSystem) {
        guard FretboardScaleQuizSkill.systemIsAvailable(system, scales: selectedScales) else { return }
        var systems = selectedSystems
        if systems.contains(system) {
            systems.remove(system)
        } else {
            systems.insert(system)
        }
        systemsRaw = FretboardScaleQuizSkill.rawSystems(systems)
    }

    private func resultRow(title: String, count: Int, color: Color) -> some View {
        HStack {
            Text(title.l10n)
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
        .accessibilityLabel("\(title.l10n) \(count)")
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
        FretboardScaleQuizDifficultyView()
    }
    .lumenotePalette()
}
