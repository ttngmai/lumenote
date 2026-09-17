//

import SwiftUI

struct FretboardNoteQuizView: View {
    @Environment(\.appPalette) private var palette
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @AppStorage(AppearanceMode.storageKey) private var appearance: AppearanceMode = .system

    @State private var model = FretboardNoteQuizModel()

    private var isCompactHeight: Bool {
        verticalSizeClass == .compact
    }

    var body: some View {
        ScrollView {
            VStack(spacing: isCompactHeight ? LumenoteSpacing.md : LumenoteSpacing.section) {
                promptRow
                fretboardCard
                if !isCompactHeight, model.hasAnswered {
                    nextButton(compact: false)
                }
            }
            .padding(
                .horizontal,
                isCompactHeight ? LumenoteSpacing.lg : LumenoteSpacing.popupInset
            )
            .padding(
                .vertical,
                isCompactHeight ? LumenoteSpacing.sm : LumenoteSpacing.xxxl
            )
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(background)
        .lumenoteCompactHeader(title: "지판 퀴즈 (음이름)", showsBackButton: true) {
            AppearanceToggleButton(appearance: $appearance)
        }
    }

    private var promptRow: some View {
        ZStack {
            promptCard
            if isCompactHeight, model.hasAnswered {
                nextButton(compact: true)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var promptCard: some View {
        Text(model.displayName)
            .font(LumenoteFont.rounded(size: 36, weight: .bold))
            .foregroundStyle(.primary)
            .padding(.horizontal, LumenoteSpacing.xxl)
            .padding(.vertical, LumenoteSpacing.md)
            .background(palette.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous)
                    .strokeBorder(palette.divider, lineWidth: LumenoteStroke.compact)
            )
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel("목표음 \(model.displayName)")
    }

    private var fretboardCard: some View {
        GeometryReader { geo in
            let frets = model.question.fretWindow
            let minWidth = FretboardDiagramView.boardWidth(frets: frets, showsStringLabels: false)
            let needsScroll = geo.size.width < minWidth
            let diagram = FretboardDiagramView(
                accidental: model.question.accidental,
                firstFret: frets.lowerBound,
                lastFret: frets.upperBound,
                selectedPosition: model.selectedPosition,
                targetPitchClass: model.question.targetPitchClass,
                hasAnswered: model.hasAnswered,
                showsStringLabels: false,
                onSelect: { model.select($0) }
            )

            Group {
                if needsScroll {
                    ScrollView(.horizontal, showsIndicators: false) {
                        diagram
                            .frame(width: minWidth)
                    }
                } else {
                    diagram
                        .frame(width: geo.size.width)
                }
            }
        }
        .frame(height: FretboardDiagramView.preferredHeight)
        .padding(.horizontal, LumenoteSpacing.xs)
        .padding(.vertical, isCompactHeight ? LumenoteSpacing.xs : LumenoteSpacing.xl)
        .frame(maxWidth: .infinity)
        .background(palette.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous)
                .strokeBorder(palette.divider, lineWidth: LumenoteStroke.compact)
        )
    }

    private func nextButton(compact: Bool) -> some View {
        Button {
            model.nextQuestion()
        } label: {
            Text("다음 문제")
                .font(LumenoteFont.body(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, compact ? LumenoteSpacing.xxxl : 0)
                .padding(.vertical, compact ? LumenoteSpacing.md : LumenoteSpacing.xxl)
                .frame(maxWidth: compact ? nil : .infinity)
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
