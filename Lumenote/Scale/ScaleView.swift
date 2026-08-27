//

import SwiftUI

struct ScaleView: View {
    @Environment(\.appPalette) private var palette
    @AppStorage(AppearanceMode.storageKey) private var appearance: AppearanceMode = .system

    @State private var model = ScaleModel()
    @State private var activePicker: PickerTarget?
    @State private var tonicStripScrollPosition: String?
    @State private var kindStripScrollPosition: String?

    private enum PickerTarget: Equatable {
        case tonic
        case kind
    }

    private let noteChipWidth: CGFloat = 64
    private let kindChipMinWidth: CGFloat = 120

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: LumenoteSpacing.section) {
                        staffCard(availableWidth: geo.size.width - LumenoteSpacing.popupInset * 2)
                            .fixedSize(horizontal: false, vertical: true)
                            .overlay {
                                if activePicker != nil {
                                    dismissTapLayer
                                }
                            }

                        selectionCard
                            .fixedSize(horizontal: false, vertical: true)

                        // Fills leftover viewport so taps below the cards dismiss the strip.
                        // minHeight (not containerRelativeFrame) avoids compressing cards when
                        // the bottom picker shortens the ScrollView.
                        dismissTapLayer
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .layoutPriority(-1)
                            .allowsHitTesting(activePicker != nil)
                    }
                    .padding(.horizontal, LumenoteSpacing.popupInset)
                    .padding(.vertical, LumenoteSpacing.xxxl)
                    .animation(.easeOut(duration: 0.2), value: model.tonicSpelling)
                    .animation(.easeOut(duration: 0.2), value: model.kind)
                    .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .top)
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
        .lumenoteCompactHeader(title: "음계", showsBackButton: true) {
            AppearanceToggleButton(appearance: $appearance)
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

        return ScrollView(.horizontal, showsIndicators: false) {
            ScaleStaffView(
                notes: model.staffNotes,
                intervals: model.stepIntervals,
                noteNames: model.degreeDisplayNames,
                staffSpace: staffSpace,
                targetWidth: innerWidth,
                lineColor: Color.primary.opacity(0.75),
                noteColor: Color.primary,
                accentColor: palette.minor
            )
            .padding(.vertical, LumenoteSpacing.xs)
        }
        .padding(LumenoteSpacing.xxl)
        .frame(maxWidth: .infinity)
        .lumenoteCard()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(model.kind.englishTitle)
    }

    private var selectionCard: some View {
        HStack(alignment: .center, spacing: LumenoteSpacing.md) {
            selectionHeaderButton(
                title: "으뜸음",
                displayName: model.tonicDisplayName,
                alignment: .leading,
                isActive: activePicker == .tonic,
                accessibilityHint: "으뜸음을 변경하려면 두 번 탭하세요"
            ) {
                togglePicker(.tonic)
            }

            selectionHeaderButton(
                title: "음계",
                displayName: model.kind.englishTitle,
                alignment: .trailing,
                isActive: activePicker == .kind,
                accessibilityHint: "음계를 변경하려면 두 번 탭하세요"
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
        case .tonic:
            tonicPickerStrip
        case .kind:
            kindPickerStrip
        }
    }

    private var tonicPickerStrip: some View {
        VStack(spacing: LumenoteSpacing.lg) {
            pickerStripHeader(title: "으뜸음") {
                activePicker = nil
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: LumenoteSpacing.md) {
                    ForEach(model.noteOptions, id: \.spelling) { option in
                        let selected = option.spelling == model.tonicSpelling
                        Button {
                            model.tonicSpelling = option.spelling
                            tonicStripScrollPosition = option.spelling
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
            .scrollPosition(id: $tonicStripScrollPosition, anchor: .center)
        }
        .pickerStripChrome()
        .onAppear {
            tonicStripScrollPosition = model.tonicSpelling
        }
    }

    private var kindPickerStrip: some View {
        VStack(spacing: LumenoteSpacing.lg) {
            pickerStripHeader(title: "음계") {
                activePicker = nil
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: LumenoteSpacing.md) {
                    ForEach(ScaleKind.allCases) { kind in
                        let selected = model.kind == kind
                        Button {
                            model.kind = kind
                            kindStripScrollPosition = kind.id
                        } label: {
                            Text(kind.englishTitle)
                                .font(.system(size: 17, weight: selected ? .bold : .semibold))
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
                        .accessibilityLabel(kind.englishTitle)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
                .padding(.horizontal, LumenoteSpacing.popupInset)
                .padding(.bottom, LumenoteSpacing.sm)
            }
            .scrollPosition(id: $kindStripScrollPosition, anchor: .center)
        }
        .pickerStripChrome()
        .onAppear {
            kindStripScrollPosition = model.kind.id
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
        // Grow the staff a bit on wide layouts; keep a readable floor on phones.
        let fitted = availableWidth / 28
        return min(14, max(9.5, fitted))
    }

    private func togglePicker(_ target: PickerTarget) {
        if activePicker == target {
            activePicker = nil
        } else {
            activePicker = target
            switch target {
            case .tonic:
                tonicStripScrollPosition = model.tonicSpelling
            case .kind:
                kindStripScrollPosition = model.kind.id
            }
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
        modifier(ScalePickerStripChrome())
    }
}

private struct ScalePickerStripChrome: ViewModifier {
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
        ScaleView()
    }
    .lumenotePalette()
}
