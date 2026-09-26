//

import SwiftUI

struct ScaleQuizView: View {
    @Environment(\.appPalette) private var palette

    let model: ScaleQuizModel

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
            case .identifyScale:
                identifyScalePrompt
            case .completeScale, .completePattern:
                tokenPrompt
            case .identifyDegree, .excludedNote:
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
        highlightedPrompt(
            model.question.promptTitle,
            highlights: promptHighlights
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel(model.question.promptTitle)
    }

    /// Emphasized phrases in the prompt, such as the scale name and degree.
    private var promptHighlights: [String] {
        switch model.question.kind {
        case .completePattern:
            return [model.question.explanationContext.kind.englishTitle]
        case .identifyDegree:
            guard model.question.explanationContext.askedNoteDisplay == nil,
                  let degree = model.question.explanationContext.degreeNumber
            else { return [] }
            return [model.question.scaleLabel, "\(degree)도"]
        case .excludedNote:
            return [model.question.scaleLabel]
        case .completeScale:
            return [model.question.scaleLabel]
        case .identifyScale:
            return []
        }
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
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)
            case .blank:
                Text("?")
                    .font(.system(size: 18, weight: .bold))
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
        case .identifyDegree, .excludedNote:
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

    /// Caption above the degree diagram. Nil hides the diagram.
    private var scaleDiagramCaption: String? {
        switch model.question.kind {
        case .identifyScale:
            return model.question.scaleLabel
        case .identifyDegree:
            guard model.question.explanationContext.askedNoteDisplay == nil,
                  model.question.explanationContext.degreeNumber != nil
            else { return nil }
            return "\(model.question.scaleLabel) 스케일"
        case .excludedNote:
            return "\(model.question.scaleLabel) 스케일"
        case .completePattern:
            return model.question.explanationContext.kind.englishTitle
        case .completeScale:
            return "\(model.question.scaleLabel) 스케일"
        }
    }

    private var degreeScaleDiagram: some View {
        let context = model.question.explanationContext
        let card = ScaleCard(tonicSpelling: context.tonicSpelling, kind: context.kind)
        return VStack(alignment: .leading, spacing: LumenoteSpacing.md) {
            Text(scaleDiagramCaption ?? "")
                .font(LumenoteFont.caption(.semibold))
                .foregroundStyle(.primary)
            DegreeScaleFormula(card: card, accent: palette.minor)
        }
        .padding(.top, LumenoteSpacing.sm)
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
            if scaleDiagramCaption != nil {
                degreeScaleDiagram
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

/// Note names, degree labels, and step marks for a scale, fitted to the feedback card.
private struct DegreeScaleFormula: View {
    let card: ScaleCard
    let accent: Color

    @State private var width: CGFloat = 0

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ScaleStaffView(
                notes: card.staffNotes,
                intervals: card.stepIntervals,
                noteNames: card.degreeDisplayNames,
                degreeLabels: card.degreeLabels,
                staffSpace: staffSpace,
                targetWidth: width > 0 ? width : nil,
                showsStaff: false,
                lineColor: Color.primary.opacity(0.75),
                noteColor: Color.primary,
                accentColor: accent
            )
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .background {
            GeometryReader { geo in
                Color.clear
                    .onAppear { width = geo.size.width }
                    .onChange(of: geo.size.width) { _, newValue in
                        width = newValue
                    }
            }
        }
    }

    private var staffSpace: CGFloat {
        guard width > 0 else { return 10 }
        return min(12, max(8, width / 32))
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
        ScaleQuizDifficultyView()
    }
    .lumenotePalette()
}
