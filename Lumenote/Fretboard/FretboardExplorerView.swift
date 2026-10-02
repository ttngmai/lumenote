//

import SwiftUI

struct FretboardExplorerView: View {
    @Environment(\.appPalette) private var palette
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @AppStorage(AccidentalPreference.fretboardStorageKey) private var accidental: AccidentalPreference = .sharp

    @State private var model = FretboardExplorerModel()
    @State private var isPickingRoot = false

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
                displayControlsCard
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
        .lumenoteCompactHeader(title: "지판 보기", showsBackButton: true)
    }

    private var displayControlsCard: some View {
        HStack(spacing: LumenoteSpacing.sm) {
            accidentalToggle
            labelModeToggle
            if model.labelMode == .degree {
                rootPickerButton
            }
            Spacer(minLength: 0)
        }
        .padding(isCompactHeight ? LumenoteSpacing.sm : LumenoteSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous)
                .strokeBorder(palette.divider, lineWidth: LumenoteStroke.compact)
        )
    }

    private var fretboardCard: some View {
        fretboardDiagram
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
            .accessibilityLabel(fretboardAccessibilityLabel)
    }

    private var fretboardDiagram: some View {
        GeometryReader { geo in
            let lastFret = Fretboard.explorerLastFret
            let minWidth = FretboardDiagramView.boardWidth(lastFret: lastFret)
            let needsScroll = geo.size.width < minWidth
            let diagram = FretboardDiagramView(
                accidental: accidental,
                lastFret: lastFret,
                visiblePitchClasses: model.visiblePitchClasses,
                labelMode: model.labelMode,
                rootPitchClass: model.rootPitchClass
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
    }

    private var noteToggleCard: some View {
        Group {
            if isCompactHeight {
                compactNoteRow
            } else {
                VStack(spacing: LumenoteSpacing.xxl) {
                    HStack(spacing: LumenoteSpacing.sm) {
                        allNotesToggle
                        Spacer(minLength: 0)
                    }
                    LazyVGrid(columns: noteColumns, spacing: LumenoteSpacing.md) {
                        ForEach(explorerPitchClasses, id: \.self) { pitchClass in
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
                    ForEach(explorerPitchClasses, id: \.self) { pitchClass in
                        noteToggleButton(pitchClass, compact: true)
                    }
                }
                LazyVGrid(columns: compactNoteColumns, spacing: LumenoteSpacing.xs) {
                    ForEach(explorerPitchClasses, id: \.self) { pitchClass in
                        noteToggleButton(pitchClass, compact: true)
                    }
                }
            }
        }
    }

    private var explorerPitchClasses: [Int] {
        Fretboard.explorerPitchClasses(
            labelMode: model.labelMode,
            rootPitchClass: model.rootPitchClass
        )
    }

    private var allNotesToggle: some View {
        let isOn = model.areAllVisible

        return Button {
            withoutAnimation {
                model.toggleAll()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(palette.cardBackground)
                if isOn {
                    Image(systemName: "checkmark")
                        .font(LumenoteFont.rounded(size: 15, weight: .bold))
                        .foregroundStyle(.primary)
                        .contentTransition(.identity)
                }
            }
            .frame(width: 34, height: 34)
            .overlay(Circle().strokeBorder(palette.cardBorder, lineWidth: LumenoteStroke.compact))
        }
        .buttonStyle(.plain)
        .accessibilityLabel((isOn ? "모든 음 숨기기" : "모든 음 표시").l10n)
        .accessibilityValue(allNotesAccessibilityValue)
        .accessibilityHint("지판의 모든 음 표시를 전환하려면 두 번 탭하세요")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private var allNotesAccessibilityValue: String {
        if model.areAllVisible {
            return "모두 표시됨".l10n
        }
        if model.visiblePitchClasses.isEmpty {
            return "모두 숨김".l10n
        }
        return "일부 표시됨".l10n
    }

    private func noteToggleButton(_ pitchClass: Int, compact: Bool = false) -> some View {
        let name = Fretboard.displayLabel(
            pitchClass: pitchClass,
            accidental: accidental,
            labelMode: model.labelMode,
            rootPitchClass: model.rootPitchClass
        )
        let color = palette.fretboardNote(
            Fretboard.swatchPitchClass(
                for: pitchClass,
                labelMode: model.labelMode,
                rootPitchClass: model.rootPitchClass
            )
        )
        let isOn = model.isVisible(pitchClass)

        return Button {
            withoutAnimation {
                model.toggle(pitchClass)
            }
        } label: {
            NoteToggleChip(name: name, color: color, isOn: isOn, compact: compact)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            Fretboard.accessibilityName(
                pitchClass: pitchClass,
                accidental: accidental,
                labelMode: model.labelMode,
                rootPitchClass: model.rootPitchClass
            )
        )
        .accessibilityValue((isOn ? "표시됨" : "숨김").l10n)
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
        .accessibilityLabel((accidental == .sharp ? "플랫 표기로 전환" : "샵 표기로 전환").l10n)
    }

    private var fretboardAccessibilityLabel: String {
        guard model.labelMode == .degree else { return "기타 지판".l10n }
        let rootName = Fretboard.displayName(
            pitchClass: model.rootPitchClass,
            accidental: accidental
        )
        return L10n.s("기타 지판, 도수 표시, 기준음 \(rootName)")
    }

    private var labelModeToggle: some View {
        Button {
            withoutAnimation {
                model.labelMode = model.labelMode.next
                if model.labelMode != .degree {
                    isPickingRoot = false
                }
            }
        } label: {
            Text(model.labelMode.title.l10n)
                .font(LumenoteFont.caption(.bold))
                .foregroundStyle(.primary)
                .contentTransition(.identity)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .padding(.horizontal, LumenoteSpacing.md)
                .frame(minWidth: 34)
                .frame(height: 34)
                .background(
                    Capsule(style: .continuous)
                        .fill(palette.cardBackground)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(palette.cardBorder, lineWidth: LumenoteStroke.compact)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(model.labelMode.toggleAccessibilityLabel)
        .accessibilityValue(model.labelMode.title)
    }

    private var rootPickerButton: some View {
        let name = Fretboard.displayName(pitchClass: model.rootPitchClass, accidental: accidental)

        return Button {
            isPickingRoot.toggle()
        } label: {
            RootPickerButtonLabel(name: name, isPicking: isPickingRoot)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPickingRoot, attachmentAnchor: .rect(.bounds)) {
            rootPickerPopover
                .presentationCompactAdaptation(.popover)
        }
        .accessibilityLabel("\("으뜸음".l10n) \(name)")
        .accessibilityHint("기준음을 변경하려면 두 번 탭하세요")
        .accessibilityAddTraits(isPickingRoot ? .isSelected : [])
        .accessibilityValue((isPickingRoot ? "선택 열림" : "선택 닫힘").l10n)
    }

    private var rootPickerPopover: some View {
        LazyVGrid(columns: rootPopoverColumns, spacing: LumenoteSpacing.xs) {
            ForEach(Fretboard.pitchClasses, id: \.self) { pitchClass in
                rootOptionButton(pitchClass)
            }
        }
        .padding(LumenoteSpacing.lg)
        .frame(width: 220)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("기준음".l10n)
    }

    private var rootPopoverColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: LumenoteSpacing.xs), count: 4)
    }

    private func rootOptionButton(_ pitchClass: Int) -> some View {
        let name = Fretboard.displayName(pitchClass: pitchClass, accidental: accidental)
        let selected = model.rootPitchClass == pitchClass

        return Button {
            withoutAnimation {
                model.selectRoot(pitchClass)
            }
            isPickingRoot = false
        } label: {
            Text(name)
                .font(LumenoteFont.caption(.bold))
                .foregroundStyle(selected ? palette.emphasisStroke : .primary)
                .contentTransition(.identity)
                .minimumScaleFactor(0.65)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(minWidth: 28)
                .frame(height: 34)
                .background(
                    RoundedRectangle(cornerRadius: LumenoteRadius.softRow, style: .continuous)
                        .fill(selected ? palette.highlight : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: LumenoteRadius.softRow, style: .continuous)
                        .strokeBorder(
                            selected ? palette.cardBorderActive : palette.divider,
                            lineWidth: selected ? LumenoteStroke.compact : LumenoteStroke.hairline
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHint("기준음으로 설정하려면 두 번 탭하세요")
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

private struct RootPickerButtonLabel: View {
    let name: String
    let isPicking: Bool

    @Environment(\.appPalette) private var palette

    var body: some View {
        HStack(spacing: LumenoteSpacing.xs) {
            Text("으뜸음".l10n)
                .font(LumenoteFont.caption2(.semibold))
                .foregroundStyle(.secondary)
            Text(name)
                .font(LumenoteFont.caption(.bold))
                .foregroundStyle(.primary)
        }
        .contentTransition(.identity)
        .minimumScaleFactor(0.7)
        .lineLimit(1)
        .padding(.horizontal, LumenoteSpacing.md)
        .frame(minWidth: 34)
        .frame(height: 34)
        .background(
            RoundedRectangle(cornerRadius: LumenoteRadius.softRow, style: .continuous)
                .fill(isPicking ? Color.primary.opacity(0.12) : palette.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LumenoteRadius.softRow, style: .continuous)
                .strokeBorder(
                    isPicking ? palette.cardBorderActive : palette.cardBorder,
                    lineWidth: LumenoteStroke.compact
                )
        )
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
