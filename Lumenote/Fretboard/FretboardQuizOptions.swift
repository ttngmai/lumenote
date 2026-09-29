//

import SwiftUI

/// Whether a fretboard quiz stays on one 5-fret window or picks a new one each question.
enum FretboardQuizFretRangeMode: String, CaseIterable, Hashable, Identifiable {
    case fixed
    case eachQuestion

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fixed: "범위 고정".l10n
        case .eachQuestion: "매 문제 변경".l10n
        }
    }

    var detail: String {
        switch self {
        case .fixed: "선택된 5프렛 범위에서 계속 출제".l10n
        case .eachQuestion: "문제마다 5프렛 범위를 무작위로 변경".l10n
        }
    }
}

/// Whether one matching fret finishes the question, or every match in the window is required.
enum FretboardQuizAnswerMode: String, CaseIterable, Hashable, Identifiable {
    case findOne
    case findAll

    var id: String { rawValue }

    var title: String {
        switch self {
        case .findOne: "하나 찾기".l10n
        case .findAll: "모두 찾기".l10n
        }
    }

    var detail: String {
        switch self {
        case .findOne: "정답 위치 중 하나만 찾으면 완료".l10n
        case .findAll: "범위 내 모든 정답 위치를 찾아야 완료".l10n
        }
    }
}

enum FretboardQuizGrading {
    enum Selection {
        case inProgress
        case finished(isCorrect: Bool)
    }

    /// Find-one finishes on the first tap. Find-all finishes when every match is chosen, or on the first miss.
    static func select(
        position: Fretboard.Position,
        answerMode: FretboardQuizAnswerMode,
        targetPitchClass: Int,
        matches: [Fretboard.Position],
        selected: inout Set<Fretboard.Position>
    ) -> Selection {
        guard !selected.contains(position) else { return .inProgress }
        let isMatch = Fretboard.pitchClass(at: position) == targetPitchClass
        switch answerMode {
        case .findOne:
            selected = [position]
            return .finished(isCorrect: isMatch)
        case .findAll:
            selected.insert(position)
            if !isMatch {
                return .finished(isCorrect: false)
            }
            if Set(matches).isSubset(of: selected) {
                return .finished(isCorrect: true)
            }
            return .inProgress
        }
    }
}

/// Fret-range and answer-mode controls shared by both fretboard quizzes.
struct FretboardQuizOptionSections: View {
    @Binding var fretRangeMode: FretboardQuizFretRangeMode
    @Binding var fretWindow: ClosedRange<Int>
    @Binding var answerMode: FretboardQuizAnswerMode

    @Environment(\.appPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: LumenoteSpacing.section) {
            fretRangeCard
            answerModeCard
        }
    }

    private var fretRangeCard: some View {
        VStack(alignment: .leading, spacing: LumenoteSpacing.lg) {
            Text("프렛 범위".l10n)
                .font(LumenoteFont.body(.bold))
                .foregroundStyle(.primary)

            ForEach(FretboardQuizFretRangeMode.allCases) { mode in
                optionButton(
                    title: mode.title,
                    detail: mode.detail,
                    isSelected: fretRangeMode == mode
                ) {
                    fretRangeMode = mode
                }
            }

            if fretRangeMode == .fixed {
                fretWindowPicker
            }
        }
        .padding(LumenoteSpacing.xxl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lumenoteCard()
    }

    private var answerModeCard: some View {
        VStack(alignment: .leading, spacing: LumenoteSpacing.lg) {
            Text("정답 방식".l10n)
                .font(LumenoteFont.body(.bold))
                .foregroundStyle(.primary)

            ForEach(FretboardQuizAnswerMode.allCases) { mode in
                optionButton(
                    title: mode.title,
                    detail: mode.detail,
                    isSelected: answerMode == mode
                ) {
                    answerMode = mode
                }
            }
        }
        .padding(LumenoteSpacing.xxl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lumenoteCard()
    }

    private var fretWindowPicker: some View {
        VStack(alignment: .leading, spacing: LumenoteSpacing.sm) {
            Text("프렛 범위".l10n)
                .font(LumenoteFont.callout(.medium))
                .foregroundStyle(.secondary)

            Menu {
                ForEach(Fretboard.quizFretWindowChoices, id: \.self) { window in
                    Button {
                        fretWindow = window
                    } label: {
                        if window == fretWindow {
                            Label(Fretboard.quizWindowTitle(window), systemImage: "checkmark")
                        } else {
                            Text(Fretboard.quizWindowTitle(window))
                        }
                    }
                }
            } label: {
                HStack(spacing: LumenoteSpacing.md) {
                    Text(Fretboard.quizWindowTitle(fretWindow))
                        .font(LumenoteFont.body(.medium))
                        .foregroundStyle(.primary)
                    Spacer(minLength: LumenoteSpacing.md)
                    Image(systemName: "chevron.down")
                        .font(LumenoteFont.caption(.bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, LumenoteSpacing.xxl)
                .padding(.vertical, LumenoteSpacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous)
                        .strokeBorder(palette.divider, lineWidth: LumenoteStroke.compact)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("프렛 범위".l10n)
            .accessibilityValue(Fretboard.quizWindowTitle(fretWindow))
            .accessibilityHint("프렛 범위를 선택하려면 두 번 탭하세요".l10n)
        }
        .padding(.top, LumenoteSpacing.sm)
    }

    private func optionButton(
        title: String,
        detail: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: LumenoteSpacing.md) {
                Image(systemName: isSelected ? "circle.fill" : "circle")
                    .font(LumenoteFont.body(.bold))
                    .foregroundStyle(.primary)
                    .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: LumenoteSpacing.xxs) {
                    Text(title)
                        .font(LumenoteFont.body(.bold))
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(LumenoteFont.callout(.medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
