//

import SwiftUI

struct FretboardScaleExplorerView: View {
    @Environment(\.appPalette) private var palette
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var model = FretboardScaleExplorerModel()
    @State private var activePicker: ActivePicker?
    @State private var viewportHeight: CGFloat = 0

    private var isCompactHeight: Bool {
        verticalSizeClass == .compact
    }

    var body: some View {
        ScrollView {
            VStack(spacing: isCompactHeight ? LumenoteSpacing.sm : LumenoteSpacing.section) {
                displayControls
                fretboardCard
                toneList
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
        .background {
            GeometryReader { geo in
                Color.clear
                    .onChange(of: geo.size.height, initial: true) { _, height in
                        viewportHeight = height
                    }
            }
        }
        .lumenoteCompactHeader(title: "지판 보기 (스케일)", showsBackButton: true)
    }

    private var displayControls: some View {
        HStack(spacing: LumenoteSpacing.sm) {
            labelModeToggle
            tonicPickerButton
            scalePickerButton
                .layoutPriority(-1)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                accidental: .sharp,
                lastFret: lastFret,
                visiblePitchClasses: model.visiblePitchClasses,
                labelMode: model.labelMode,
                rootPitchClass: model.tonicPitchClass,
                pitchClassLabels: model.markerLabels(),
                pitchClassSwatches: model.markerSwatches(),
                pitchClassAccessibilityLabels: model.markerAccessibilityLabels()
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

    private var toneList: some View {
        HStack(spacing: LumenoteSpacing.md) {
            Text("구성음".l10n)
                .font(LumenoteFont.caption(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize()
                .accessibilityHidden(true)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: LumenoteSpacing.sm) {
                    ForEach(model.tones) { tone in
                        toneMarker(tone)
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("구성음".l10n)
    }

    private func toneMarker(_ tone: FretboardScaleExplorerModel.Tone) -> some View {
        let label = tone.label(for: model.labelMode)
        let color = palette.fretboardNote(
            tone.swatchPitchClass(for: model.labelMode, tonicPitchClass: model.tonicPitchClass)
        )

        return FretboardNoteMarker(name: label, color: color)
            .accessibilityLabel(tone.accessibilityLabel(for: model.labelMode))
    }

    private var fretboardAccessibilityLabel: String {
        let tonic = model.tonicDisplayName
        let scale = model.kind.englishTitle
        switch model.labelMode {
        case .noteName:
            return L10n.s("기타 지판, \(tonic) \(scale), 음이름 표시")
        case .degree:
            return L10n.s("기타 지판, \(tonic) \(scale), 도수 표시")
        }
    }

    private var labelModeToggle: some View {
        Button {
            withoutAnimation {
                model.labelMode = model.labelMode.next
            }
        } label: {
            Text(model.labelMode.title)
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

    private var tonicPickerButton: some View {
        let name = model.tonicDisplayName

        return Button {
            activePicker = activePicker == .tonic ? nil : .tonic
        } label: {
            ScaleExplorerPickerLabel(
                title: "으뜸음",
                value: name,
                isPicking: activePicker == .tonic
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: pickerBinding(.tonic), attachmentAnchor: .rect(.bounds)) {
            tonicPickerPopover
                .presentationCompactAdaptation(.popover)
        }
        .accessibilityLabel("\("으뜸음".l10n) \(name)")
        .accessibilityHint("기준음을 변경하려면 두 번 탭하세요".l10n)
        .accessibilityAddTraits(activePicker == .tonic ? .isSelected : [])
        .accessibilityValue((activePicker == .tonic ? "선택 열림" : "선택 닫힘").l10n)
    }

    private var scalePickerButton: some View {
        let name = model.kind.englishTitle

        return Button {
            activePicker = activePicker == .scale ? nil : .scale
        } label: {
            ScaleExplorerPickerLabel(
                title: "스케일",
                value: name,
                isPicking: activePicker == .scale
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: pickerBinding(.scale), attachmentAnchor: .rect(.bounds)) {
            scalePickerPopover
                .presentationCompactAdaptation(.popover)
        }
        .accessibilityLabel("\("스케일".l10n) \(name)")
        .accessibilityHint("스케일을 변경하려면 두 번 탭하세요".l10n)
        .accessibilityAddTraits(activePicker == .scale ? .isSelected : [])
        .accessibilityValue((activePicker == .scale ? "선택 열림" : "선택 닫힘").l10n)
    }

    private var tonicPickerPopover: some View {
        fittedPopover(width: 240, label: "으뜸음") {
            LazyVGrid(columns: tonicPopoverColumns, spacing: LumenoteSpacing.xs) {
                ForEach(ScaleModel.selectableNotes, id: \.spelling) { option in
                    tonicOptionButton(option.spelling, name: option.displayName)
                }
            }
            .padding(LumenoteSpacing.lg)
        }
    }

    private var tonicPopoverColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: LumenoteSpacing.xs), count: 4)
    }

    private func tonicOptionButton(_ spelling: String, name: String) -> some View {
        let selected = model.tonicSpelling == spelling

        return Button {
            withoutAnimation {
                model.selectTonic(spelling)
            }
            activePicker = nil
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
        .accessibilityHint("기준음으로 설정하려면 두 번 탭하세요".l10n)
    }

    private var scalePickerPopover: some View {
        fittedPopover(width: 236, label: "스케일") {
            VStack(alignment: .leading, spacing: LumenoteSpacing.lg) {
                ForEach(ScaleCategory.allCases) { category in
                    VStack(alignment: .leading, spacing: LumenoteSpacing.xs) {
                        Text(category.title.l10n)
                            .font(LumenoteFont.caption2(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, LumenoteSpacing.xs)

                        ForEach(category.kinds) { kind in
                            scaleOptionButton(kind)
                        }
                    }
                }
            }
            .padding(LumenoteSpacing.lg)
        }
    }

    /// Landscape popovers are shorter than the scale list. Cap the height and scroll
    /// instead of letting the system clip the extra rows.
    @ViewBuilder
    private func fittedPopover<Content: View>(
        width: CGFloat,
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Group {
            if isCompactHeight {
                ScrollView {
                    content()
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(width: width, height: compactPopoverHeight)
            } else {
                content()
                    .frame(width: width)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label.l10n)
    }

    private var compactPopoverHeight: CGFloat {
        let roomForAnchor = viewportHeight > 0 ? viewportHeight - 72 : 220
        return min(max(roomForAnchor, 160), 300)
    }

    private func scaleOptionButton(_ kind: ScaleKind) -> some View {
        let selected = model.kind == kind

        return Button {
            withoutAnimation {
                model.kind = kind
            }
            activePicker = nil
        } label: {
            Text(kind.englishTitle)
                .font(LumenoteFont.caption(.bold))
                .foregroundStyle(selected ? palette.emphasisStroke : .primary)
                .contentTransition(.identity)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, LumenoteSpacing.md)
                .frame(height: 34)
                .background(
                    RoundedRectangle(cornerRadius: LumenoteRadius.softRow, style: .continuous)
                        .fill(selected ? palette.highlight : Color.primary.opacity(0.001))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: LumenoteRadius.softRow, style: .continuous)
                        .strokeBorder(
                            selected ? palette.cardBorderActive : palette.divider,
                            lineWidth: selected ? LumenoteStroke.compact : LumenoteStroke.hairline
                        )
                )
                .contentShape(RoundedRectangle(cornerRadius: LumenoteRadius.softRow, style: .continuous))
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: LumenoteRadius.softRow, style: .continuous))
        .accessibilityLabel(kind.englishTitle)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHint("스케일로 설정하려면 두 번 탭하세요".l10n)
    }

    private var background: some View {
        LinearGradient(
            colors: palette.backgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private func pickerBinding(_ picker: ActivePicker) -> Binding<Bool> {
        Binding(
            get: { activePicker == picker },
            set: { isPresented in
                if isPresented {
                    activePicker = picker
                } else if activePicker == picker {
                    activePicker = nil
                }
            }
        )
    }

    private func withoutAnimation(_ action: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, action)
    }
}

private enum ActivePicker {
    case tonic
    case scale
}

private struct ScaleExplorerPickerLabel: View {
    let title: String
    let value: String
    let isPicking: Bool

    @Environment(\.appPalette) private var palette

    var body: some View {
        HStack(spacing: LumenoteSpacing.xs) {
            Text(title.l10n)
                .font(LumenoteFont.caption2(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(LumenoteFont.caption(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .contentTransition(.identity)
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

#Preview {
    NavigationStack {
        FretboardScaleExplorerView()
    }
    .lumenotePalette()
}
