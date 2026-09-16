//

import SwiftUI

struct FretboardExplorerView: View {
    @Environment(\.appPalette) private var palette
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @AppStorage(AppearanceMode.storageKey) private var appearance: AppearanceMode = .system
    @AppStorage(AccidentalPreference.fretboardStorageKey) private var accidental: AccidentalPreference = .sharp

    @State private var model = FretboardExplorerModel()

    private let noteColumns = Array(repeating: GridItem(.flexible(), spacing: LumenoteSpacing.md), count: 4)
    private let compactNoteColumns = Array(
        repeating: GridItem(.flexible(), spacing: LumenoteSpacing.xs),
        count: 6
    )

    private var isCompactHeight: Bool {
        verticalSizeClass == .compact
    }

    var body: some View {
        ScrollView {
            VStack(spacing: isCompactHeight ? LumenoteSpacing.md : LumenoteSpacing.section) {
                fretboardCard
                noteToggleCard
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
        .lumenoteCompactHeader(title: "지판 보기", showsBackButton: true) {
            AppearanceToggleButton(appearance: $appearance)
        }
    }

    private var fretboardCard: some View {
        GeometryReader { geo in
            let lastFret = Fretboard.explorerLastFret
            let minWidth = FretboardDiagramView.boardWidth(lastFret: lastFret)
            let needsScroll = geo.size.width < minWidth
            let diagram = FretboardDiagramView(
                accidental: accidental,
                lastFret: lastFret,
                visiblePitchClasses: model.visiblePitchClasses
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
        .accessibilityElement(children: .contain)
        .accessibilityLabel("기타 지판")
    }

    private var noteToggleCard: some View {
        Group {
            if isCompactHeight {
                compactNoteRow
            } else {
                VStack(spacing: LumenoteSpacing.xxl) {
                    HStack {
                        allNotesToggle
                        Spacer(minLength: 0)
                        accidentalToggle
                    }
                    LazyVGrid(columns: noteColumns, spacing: LumenoteSpacing.md) {
                        ForEach(Fretboard.pitchClasses, id: \.self) { pitchClass in
                            noteToggleButton(pitchClass)
                        }
                    }
                }
            }
        }
        .padding(isCompactHeight ? LumenoteSpacing.sm : LumenoteSpacing.xxl)
        .frame(maxWidth: .infinity)
        .background(palette.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous)
                .strokeBorder(palette.divider, lineWidth: LumenoteStroke.compact)
        )
        .transaction { $0.animation = nil }
    }

    private var compactNoteRow: some View {
        HStack(spacing: LumenoteSpacing.sm) {
            allNotesToggle
                .fixedSize()
            ViewThatFits(in: .horizontal) {
                HStack(spacing: LumenoteSpacing.xs) {
                    ForEach(Fretboard.pitchClasses, id: \.self) { pitchClass in
                        noteToggleButton(pitchClass, compact: true)
                    }
                }
                LazyVGrid(columns: compactNoteColumns, spacing: LumenoteSpacing.xs) {
                    ForEach(Fretboard.pitchClasses, id: \.self) { pitchClass in
                        noteToggleButton(pitchClass, compact: true)
                    }
                }
            }
            accidentalToggle
                .fixedSize()
        }
    }

    private var allNotesToggle: some View {
        let isOn = model.areAllVisible

        return Button {
            withoutAnimation {
                model.toggleAll()
            }
        } label: {
            Image(systemName: isOn ? "eye.slash.fill" : "eye.fill")
                .font(LumenoteFont.rounded(size: 15, weight: .bold))
                .foregroundStyle(.primary)
                .contentTransition(.identity)
                .frame(width: 34, height: 34)
                .background(Circle().fill(palette.cardBackground))
                .overlay(Circle().strokeBorder(palette.cardBorder, lineWidth: LumenoteStroke.compact))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOn ? "모든 음 숨기기" : "모든 음 표시")
        .accessibilityValue(allNotesAccessibilityValue)
        .accessibilityHint("지판의 모든 음 표시를 전환하려면 두 번 탭하세요")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private var allNotesAccessibilityValue: String {
        if model.areAllVisible {
            return "모두 표시됨"
        }
        if model.visiblePitchClasses.isEmpty {
            return "모두 숨김"
        }
        return "일부 표시됨"
    }

    private func noteToggleButton(_ pitchClass: Int, compact: Bool = false) -> some View {
        let name = Fretboard.displayName(pitchClass: pitchClass, accidental: accidental)
        let color = palette.fretboardNote(pitchClass)
        let isOn = model.isVisible(pitchClass)

        return Button {
            withoutAnimation {
                model.toggle(pitchClass)
            }
        } label: {
            NoteToggleChip(name: name, color: color, isOn: isOn, compact: compact)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityValue(isOn ? "표시됨" : "숨김")
        .accessibilityHint("지판 표시를 전환하려면 두 번 탭하세요")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private var accidentalToggle: some View {
        Button {
            withoutAnimation {
                accidental = accidental == .sharp ? .flat : .sharp
            }
        } label: {
            Text(accidental.symbol)
                .font(LumenoteFont.rounded(size: 18, weight: .bold))
                .foregroundStyle(.primary)
                .contentTransition(.identity)
                .frame(width: 34, height: 34)
                .background(Circle().fill(palette.cardBackground))
                .overlay(Circle().strokeBorder(palette.cardBorder, lineWidth: LumenoteStroke.compact))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accidental == .sharp ? "플랫 표기로 전환" : "샵 표기로 전환")
    }

    private var background: some View {
        LinearGradient(
            colors: palette.backgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private func withoutAnimation(_ action: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, action)
    }
}

private struct NoteToggleChip: View {
    let name: String
    let color: Color
    let isOn: Bool
    let compact: Bool

    var body: some View {
        Text(name)
            .font(compact ? LumenoteFont.caption(.bold) : LumenoteFont.body(.bold))
            .foregroundStyle(isOn ? Color.white : color)
            .contentTransition(.identity)
            .minimumScaleFactor(0.65)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .modifier(NoteToggleChipLayout(compact: compact))
            .background(
                RoundedRectangle(cornerRadius: LumenoteRadius.softRow, style: .continuous)
                    .fill(isOn ? color : color.opacity(0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: LumenoteRadius.softRow, style: .continuous)
                    .strokeBorder(
                        color,
                        lineWidth: isOn ? LumenoteStroke.compact : LumenoteStroke.hairline
                    )
            )
    }
}

private struct NoteToggleChipLayout: ViewModifier {
    let compact: Bool

    func body(content: Content) -> some View {
        if compact {
            content
                .frame(minWidth: 28)
                .frame(height: 34)
        } else {
            content.padding(.vertical, LumenoteSpacing.xxl)
        }
    }
}

#Preview {
    NavigationStack {
        FretboardExplorerView()
    }
    .lumenotePalette()
}
