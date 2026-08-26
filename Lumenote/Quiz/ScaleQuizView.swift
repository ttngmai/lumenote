//

import SwiftUI

struct ScaleQuizView: View {
    @Environment(\.appPalette) private var palette
    @AppStorage(AppearanceMode.storageKey) private var appearance: AppearanceMode = .system

    @State private var model = ScaleQuizModel()

    var body: some View {
        ScrollView {
            VStack(spacing: LumenoteSpacing.section) {
                scoreRow
                promptCard
                choices
                if model.hasAnswered, let answer = model.selectedAnswer {
                    feedbackCard(for: answer)
                    nextButton
                }
            }
            .padding(.horizontal, LumenoteSpacing.popupInset)
            .padding(.vertical, LumenoteSpacing.xxxl)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(background)
        .lumenoteCompactHeader(title: "음계 퀴즈", showsBackButton: true) {
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
            Text(model.question.promptTitle)
                .font(LumenoteFont.callout(.medium))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            switch model.question.kind {
            case .identifyScale:
                identifyScalePrompt
            case .completeScale, .completePattern:
                tokenPrompt
            case .identifyDegree:
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

    private var identifyScalePrompt: some View {
        Group {
            if !model.question.staffNotes.isEmpty {
                ScaleStaffView(
                    notes: model.question.staffNotes,
                    intervals: model.question.staffIntervals,
                    noteNames: model.question.staffNoteNames,
                    staffSpace: 10,
                    targetWidth: nil,
                    showsNoteNames: false,
                    showsIntervalAnnotations: false,
                    lineColor: Color.primary.opacity(0.75),
                    noteColor: Color.primary,
                    accentColor: palette.minor
                )
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var tokenPrompt: some View {
        tokenFlow(model.question.promptTokens)
            .frame(maxWidth: .infinity)
    }

    private func tokenFlow(_ tokens: [ScaleQuizModel.PromptToken]) -> some View {
        // Wrapping flow so 8-note prompts stay readable on narrow phones.
        FlexibleTokenFlow(spacing: LumenoteSpacing.sm) {
            ForEach(Array(tokens.enumerated()), id: \.offset) { index, token in
                tokenView(token, index: index, total: tokens.count)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityPrompt(for: tokens))
    }

    @ViewBuilder
    private func tokenView(
        _ token: ScaleQuizModel.PromptToken,
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
            case .step(let label):
                Text(label)
                    .font(LumenoteFont.callout(.bold))
                    .foregroundStyle(.primary)
            case .stepBlank:
                Text("?")
                    .font(LumenoteFont.callout(.bold))
                    .foregroundStyle(palette.minor)
            }

            if index < total - 1 {
                separator(for: model.question.kind)
            }
        }
    }

    @ViewBuilder
    private func separator(for kind: ScaleQuizModel.QuestionKind) -> some View {
        switch kind {
        case .completeScale, .identifyScale:
            Image(systemName: "arrow.right")
                .font(LumenoteFont.caption2(.semibold))
                .foregroundStyle(palette.minor.opacity(0.85))
        case .completePattern:
            Text("-")
                .font(LumenoteFont.callout(.semibold))
                .foregroundStyle(.secondary)
        case .identifyDegree:
            EmptyView()
        }
    }

    private func accessibilityPrompt(for tokens: [ScaleQuizModel.PromptToken]) -> String {
        tokens.map { token in
            switch token {
            case .note(let name): return name
            case .blank, .stepBlank: return "빈칸"
            case .step(let label): return label
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

    private func feedbackCard(for answer: String) -> some View {
        let feedback = model.feedback(for: answer)
        let isCorrect = model.isSelectionCorrect

        return VStack(alignment: .leading, spacing: LumenoteSpacing.sm) {
            Text(feedback.headline)
                .font(LumenoteFont.body(.bold))
                .foregroundStyle(isCorrect ? palette.minor : .primary)
            if !feedback.detail.isEmpty {
                Text(feedback.detail)
                    .font(LumenoteFont.callout(.medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(LumenoteSpacing.xxl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous)
                .fill(isCorrect ? palette.highlightSoft : palette.major.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous)
                .strokeBorder(
                    isCorrect ? palette.minor.opacity(0.45) : palette.major.opacity(0.40),
                    lineWidth: LumenoteStroke.compact
                )
        )
        .accessibilityElement(children: .combine)
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

// MARK: - Wrapping token layout

/// Simple left-to-right wrapping stack for scale / pattern tokens.
private struct FlexibleTokenFlow<Content: View>: View {
    var spacing: CGFloat
    @ViewBuilder var content: () -> Content

    var body: some View {
        // iOS 16+ Layout protocol would be ideal; ViewThatFits + wrapping via
        // a custom Layout keeps dependency on project deployment target light.
        TokenWrapLayout(spacing: spacing) {
            content()
        }
    }
}

private struct TokenWrapLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(proposal: proposal, subviews: subviews)
        let width = proposal.width ?? rows.maxWidth
        return CGSize(width: width, height: rows.totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(proposal: ProposedViewSize(width: bounds.width, height: bounds.height), subviews: subviews)
        for item in rows.items {
            let origin = CGPoint(
                x: bounds.minX + item.x,
                y: bounds.minY + item.y
            )
            subviews[item.index].place(
                at: origin,
                anchor: .topLeading,
                proposal: ProposedViewSize(item.size)
            )
        }
    }

    private struct Arranged {
        struct Item {
            let index: Int
            let x: CGFloat
            let y: CGFloat
            let size: CGSize
        }

        var items: [Item] = []
        var maxWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> Arranged {
        let maxWidth = proposal.width ?? .infinity
        var result = Arranged()
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            result.items.append(Arranged.Item(index: index, x: x, y: y, size: size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            result.maxWidth = max(result.maxWidth, x - spacing)
        }
        result.totalHeight = y + rowHeight
        return result
    }
}

#Preview {
    NavigationStack {
        ScaleQuizView()
    }
    .lumenotePalette()
}
