//

import SwiftUI

struct FretboardNoteQuizView: View {
    @Environment(\.appPalette) private var palette
    @AppStorage(AppearanceMode.storageKey) private var appearance: AppearanceMode = .system
    @AppStorage(AccidentalPreference.fretboardStorageKey) private var accidental: AccidentalPreference = .sharp

    @State private var model = FretboardNoteQuizModel()

    var body: some View {
        ScrollView {
            VStack(spacing: LumenoteSpacing.section) {
                scoreRow
                promptCard
                fretboardCard
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
        .lumenoteCompactHeader(title: "지판 퀴즈 (음이름)", showsBackButton: true) {
            HStack(spacing: LumenoteSpacing.sm) {
                accidentalToggle
                AppearanceToggleButton(appearance: $appearance)
            }
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
        Text(model.displayName(accidental: accidental))
            .font(LumenoteFont.rounded(size: 36, weight: .bold))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(LumenoteSpacing.xxl)
            .background(palette.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous)
                    .strokeBorder(palette.divider, lineWidth: LumenoteStroke.compact)
            )
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel("목표음 \(model.displayName(accidental: accidental))")
    }

    private var fretboardCard: some View {
        GeometryReader { geo in
            let needsScroll = geo.size.width < FretboardDiagramView.minimumWidth
            let diagram = FretboardDiagramView(
                accidental: accidental,
                selectedPosition: model.selectedPosition,
                targetPitchClass: model.question.targetPitchClass,
                hasAnswered: model.hasAnswered,
                onSelect: { model.select($0) }
            )

            Group {
                if needsScroll {
                    ScrollView(.horizontal, showsIndicators: false) {
                        diagram
                            .frame(width: FretboardDiagramView.minimumWidth)
                    }
                } else {
                    diagram
                        .frame(width: geo.size.width)
                }
            }
        }
        .frame(height: FretboardDiagramView.preferredHeight)
        .padding(.horizontal, LumenoteSpacing.xs)
        .padding(.vertical, LumenoteSpacing.xl)
        .frame(maxWidth: .infinity)
        .background(palette.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous)
                .strokeBorder(palette.divider, lineWidth: LumenoteStroke.compact)
        )
    }

    private var accidentalToggle: some View {
        Button {
            accidental = accidental == .sharp ? .flat : .sharp
        } label: {
            Text(accidental.symbol)
                .font(LumenoteFont.rounded(size: 18, weight: .bold))
                .foregroundStyle(.primary)
                .frame(width: 34, height: 34)
                .background(Circle().fill(palette.cardBackground))
                .overlay(Circle().strokeBorder(palette.cardBorder, lineWidth: LumenoteStroke.compact))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accidental == .sharp ? "플랫 표기로 전환" : "샵 표기로 전환")
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
        FretboardNoteQuizView()
    }
    .lumenotePalette()
}
