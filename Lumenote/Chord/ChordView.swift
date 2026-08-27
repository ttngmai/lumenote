//

import SwiftUI

struct ChordView: View {
    @Environment(\.appPalette) private var palette
    @AppStorage(AppearanceMode.storageKey) private var appearance: AppearanceMode = .system

    @State private var model = ChordModel()
    @State private var activePicker: PickerTarget?
    @State private var rootStripScrollPosition: String?
    @State private var triadStripScrollPosition: String?
    @State private var seventhStripScrollPosition: String?
    @State private var showsGuide = false

    private enum PickerTarget: Equatable {
        case root
        case kind
    }

    private let noteChipWidth: CGFloat = 64
    private let kindChipMinWidth: CGFloat = 108

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: LumenoteSpacing.section) {
                        staffCard(availableWidth: geo.size.width - LumenoteSpacing.popupInset * 2)
                            .overlay {
                                if activePicker != nil {
                                    dismissTapLayer
                                }
                            }

                        selectionCard

                        dismissTapLayer
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .allowsHitTesting(activePicker != nil)
                    }
                    .padding(.horizontal, LumenoteSpacing.popupInset)
                    .padding(.vertical, LumenoteSpacing.xxxl)
                    .animation(.easeOut(duration: 0.2), value: model.rootSpelling)
                    .animation(.easeOut(duration: 0.2), value: model.kind)
                    .frame(maxWidth: .infinity)
                    .containerRelativeFrame(.vertical, alignment: .top)
                    .background {
                        if activePicker != nil {
                            dismissTapLayer
                        }
                    }
                }
                .scrollIndicators(.hidden)

                if let activePicker {
                    pickerStrip(for: activePicker)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            .animation(.easeOut(duration: 0.22), value: activePicker)
        }
        .background(background)
        .lumenoteCompactHeader(title: "화음", showsBackButton: true) {
            HStack(spacing: LumenoteSpacing.sm) {
                Button {
                    showsGuide = true
                } label: {
                    Image(systemName: "info")
                        .font(LumenoteFont.rounded(size: 15, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(palette.cardBackground))
                        .overlay(Circle().strokeBorder(palette.cardBorder, lineWidth: LumenoteStroke.compact))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("화음 정리")

                AppearanceToggleButton(appearance: $appearance)
            }
        }
        .sheet(isPresented: $showsGuide) {
            ChordGuideView()
        }
    }

    /// Nearly-invisible hit target; `Color.clear` alone can miss taps in ScrollView.
    private var dismissTapLayer: some View {
        Color.primary.opacity(0.001)
            .contentShape(Rectangle())
            .onTapGesture {
                activePicker = nil
            }
    }

    // MARK: - Sections

    private func staffCard(availableWidth: CGFloat) -> some View {
        let innerWidth = max(0, availableWidth - LumenoteSpacing.xxl * 2)
        let staffSpace = staffSpace(for: innerWidth)

        return VStack(spacing: LumenoteSpacing.xl) {
            HStack(alignment: .firstTextBaseline) {
                Text(model.kind.category.koreanTitle)
                    .font(LumenoteFont.caption(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            ChordStaffView(
                notes: model.staffNotes,
                noteNames: model.toneDisplayNames,
                degreeLabels: model.degreeLabels,
                staffSpace: staffSpace,
                targetWidth: innerWidth,
                lineColor: Color.primary.opacity(0.75),
                noteColor: Color.primary,
                accentColor: palette.minor
            )
            .padding(.vertical, LumenoteSpacing.xs)

            VStack(spacing: LumenoteSpacing.xxs) {
                Text(model.kind.englishTitle)
                    .font(LumenoteFont.rounded(size: 20, weight: .bold))
                    .foregroundStyle(palette.minor)
                    .multilineTextAlignment(.center)
                Text(model.kind.koreanTitle)
                    .font(LumenoteFont.callout(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(model.kind.englishTitle), \(model.kind.koreanTitle)")

            formulaBlock
        }
        .padding(LumenoteSpacing.xxl)
        .frame(maxWidth: .infinity)
        .lumenoteCard()
        .accessibilityElement(children: .contain)
    }

    private var formulaBlock: some View {
        VStack(alignment: .leading, spacing: LumenoteSpacing.lg) {
            labeledRow(title: "구성음") {
                HStack(spacing: LumenoteSpacing.sm) {
                    ForEach(Array(model.kind.tones.enumerated()), id: \.offset) { _, tone in
                        Text(tone.degreeLabel)
                            .font(LumenoteFont.callout(.bold))
                            .foregroundStyle(tone.isAltered ? palette.emphasisStroke : .primary)
                            .padding(.horizontal, LumenoteSpacing.md)
                            .frame(minHeight: 28)
                            .background(
                                RoundedRectangle(cornerRadius: LumenoteRadius.chip, style: .continuous)
                                    .fill(tone.isAltered ? palette.highlight : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: LumenoteRadius.chip, style: .continuous)
                                    .strokeBorder(palette.divider, lineWidth: LumenoteStroke.hairline)
                            )
                    }
                }
            }

            labeledRow(title: "표기") {
                Text(model.notations.joined(separator: "  ·  "))
                    .font(LumenoteFont.callout(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("구성음 \(model.kind.formulaText), 표기 \(model.notations.joined(separator: ", "))")
    }

    private func labeledRow<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: LumenoteSpacing.md) {
            Text(title)
                .font(LumenoteFont.caption2(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var selectionCard: some View {
        HStack(alignment: .center, spacing: LumenoteSpacing.md) {
            selectionHeaderButton(
                title: "근음",
                displayName: model.rootDisplayName,
                alignment: .leading,
                isActive: activePicker == .root,
                accessibilityHint: "근음을 변경하려면 두 번 탭하세요"
            ) {
                togglePicker(.root)
            }

            selectionHeaderButton(
                title: "화음",
                displayName: model.kind.koreanTitle,
                alignment: .trailing,
                isActive: activePicker == .kind,
                accessibilityHint: "화음을 변경하려면 두 번 탭하세요"
            ) {
                togglePicker(.kind)
            }
        }
        .padding(.horizontal, LumenoteSpacing.popupInset)
        .padding(.vertical, LumenoteSpacing.xxl)
        .frame(maxWidth: .infinity)
        .background(palette.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous)
                .strokeBorder(palette.divider, lineWidth: LumenoteStroke.compact)
        )
    }

    private func selectionHeaderButton(
        title: String,
        displayName: String,
        alignment: HorizontalAlignment,
        isActive: Bool,
        accessibilityHint: String,
        action: @escaping () -> Void
    ) -> some View {
        let frameAlignment: Alignment = alignment == .leading ? .leading : .trailing

        return Button(action: action) {
            VStack(alignment: alignment, spacing: LumenoteSpacing.xxs) {
                Text(title)
                    .font(LumenoteFont.caption2(.semibold))
                    .foregroundStyle(isActive ? palette.minor : .secondary)
                Text(displayName)
                    .font(.system(size: displayName.count > 8 ? 22 : 28, weight: .bold))
                    .foregroundStyle(isActive ? palette.minor : .primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.65)
                    .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: frameAlignment)
        .accessibilityLabel("\(title) \(displayName)")
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    // MARK: - Bottom picker strips

    @ViewBuilder
    private func pickerStrip(for target: PickerTarget) -> some View {
        switch target {
        case .root:
            rootPickerStrip
        case .kind:
            kindPickerStrip
        }
    }

    private var rootPickerStrip: some View {
        VStack(spacing: LumenoteSpacing.lg) {
            pickerStripHeader(title: "근음") {
                activePicker = nil
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: LumenoteSpacing.md) {
                    ForEach(model.noteOptions, id: \.spelling) { option in
                        let selected = option.spelling == model.rootSpelling
                        Button {
                            model.rootSpelling = option.spelling
                            rootStripScrollPosition = option.spelling
                        } label: {
                            Text(option.displayName)
                                .font(.system(size: 17, weight: selected ? .bold : .semibold))
                                .foregroundStyle(selected ? palette.emphasisStroke : .primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .frame(width: noteChipWidth, height: 40)
                                .background(
                                    RoundedRectangle(cornerRadius: LumenoteRadius.chip, style: .continuous)
                                        .fill(selected ? palette.highlight : Color.clear)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: LumenoteRadius.chip, style: .continuous)
                                        .strokeBorder(
                                            selected ? palette.cardBorderActive : palette.divider,
                                            lineWidth: selected ? LumenoteStroke.compact : LumenoteStroke.hairline
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .id(option.spelling)
                        .accessibilityLabel(option.displayName)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
                .padding(.horizontal, LumenoteSpacing.popupInset)
                .padding(.bottom, LumenoteSpacing.sm)
            }
            .scrollPosition(id: $rootStripScrollPosition, anchor: .center)
        }
        .pickerStripChrome()
        .onAppear {
            rootStripScrollPosition = model.rootSpelling
        }
    }

    private var kindPickerStrip: some View {
        VStack(spacing: LumenoteSpacing.lg) {
            pickerStripHeader(title: "화음") {
                activePicker = nil
            }

            kindChipRow(title: "3화음", kinds: ChordKind.triads, scrollPosition: $triadStripScrollPosition)
            kindChipRow(title: "7화음", kinds: ChordKind.sevenths, scrollPosition: $seventhStripScrollPosition)
        }
        .pickerStripChrome()
        .onAppear {
            syncKindStripPositions()
        }
    }

    private func kindChipRow(
        title: String,
        kinds: [ChordKind],
        scrollPosition: Binding<String?>
    ) -> some View {
        VStack(alignment: .leading, spacing: LumenoteSpacing.sm) {
            Text(title)
                .font(LumenoteFont.caption2(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, LumenoteSpacing.popupInset)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: LumenoteSpacing.md) {
                    ForEach(kinds) { kind in
                        let selected = model.kind == kind
                        Button {
                            model.kind = kind
                            scrollPosition.wrappedValue = kind.id
                        } label: {
                            Text(kind.koreanTitle)
                                .font(.system(size: 16, weight: selected ? .bold : .semibold))
                                .foregroundStyle(selected ? palette.emphasisStroke : .primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .padding(.horizontal, LumenoteSpacing.xl)
                                .frame(minWidth: kindChipMinWidth, minHeight: 40)
                                .background(
                                    RoundedRectangle(cornerRadius: LumenoteRadius.chip, style: .continuous)
                                        .fill(selected ? palette.highlight : Color.clear)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: LumenoteRadius.chip, style: .continuous)
                                        .strokeBorder(
                                            selected ? palette.cardBorderActive : palette.divider,
                                            lineWidth: selected ? LumenoteStroke.compact : LumenoteStroke.hairline
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .id(kind.id)
                        .accessibilityLabel("\(kind.koreanTitle), \(kind.englishTitle)")
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
                .padding(.horizontal, LumenoteSpacing.popupInset)
                .padding(.bottom, LumenoteSpacing.xs)
            }
            .scrollPosition(id: scrollPosition, anchor: .center)
        }
    }

    private func pickerStripHeader(title: String, dismiss: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(LumenoteFont.caption(.semibold))
                .foregroundStyle(palette.minor)
            Spacer()
            Button(action: dismiss) {
                Image(systemName: "chevron.down")
                    .font(LumenoteFont.caption(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("선택 닫기")
        }
        .padding(.horizontal, LumenoteSpacing.popupInset)
    }

    // MARK: - Helpers

    private func staffSpace(for availableWidth: CGFloat) -> CGFloat {
        let fitted = availableWidth / 22
        return min(14, max(10, fitted))
    }

    private func togglePicker(_ target: PickerTarget) {
        if activePicker == target {
            activePicker = nil
        } else {
            activePicker = target
            switch target {
            case .root:
                rootStripScrollPosition = model.rootSpelling
            case .kind:
                syncKindStripPositions()
            }
        }
    }

    private func syncKindStripPositions() {
        switch model.kind.category {
        case .triad:
            triadStripScrollPosition = model.kind.id
        case .seventh:
            seventhStripScrollPosition = model.kind.id
        }
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

private extension View {
    func pickerStripChrome() -> some View {
        modifier(ChordPickerStripChrome())
    }
}

private struct ChordPickerStripChrome: ViewModifier {
    @Environment(\.appPalette) private var palette

    func body(content: Content) -> some View {
        content
            .padding(.top, LumenoteSpacing.xxl)
            .padding(.bottom, LumenoteSpacing.xl)
            .frame(maxWidth: .infinity)
            .background(palette.cardBackground)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(palette.divider)
                    .frame(height: LumenoteStroke.hairline)
            }
    }
}

#Preview {
    NavigationStack {
        ChordView()
    }
    .lumenotePalette()
}
