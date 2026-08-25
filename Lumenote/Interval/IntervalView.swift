//

import SwiftUI

struct IntervalView: View {
    @Environment(\.appPalette) private var palette
    @AppStorage(AppearanceMode.storageKey) private var appearance: AppearanceMode = .system

    @State private var model = IntervalModel()
    @State private var activePicker: NotePickerTarget?
    @State private var stripScrollPosition: String?

    private enum NotePickerTarget: Equatable {
        case root
        case target

        var title: String {
            switch self {
            case .root: return "기준음"
            case .target: return "목표음"
            }
        }
    }

    var body: some View {
        GeometryReader { geo in
            let isWide = geo.size.width > geo.size.height * 0.9

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: LumenoteSpacing.section) {
                        staffCards(isWide: isWide)
                            .overlay {
                                if activePicker != nil {
                                    Color.clear
                                        .contentShape(Rectangle())
                                        .onTapGesture { activePicker = nil }
                                }
                            }

                        noteSelectionCard
                    }
                    .padding(.horizontal, LumenoteSpacing.popupInset)
                    .padding(.vertical, LumenoteSpacing.xxxl)
                    .animation(.easeOut(duration: 0.2), value: model.rootSpelling)
                    .animation(.easeOut(duration: 0.2), value: model.targetSpelling)
                    .frame(maxWidth: .infinity)
                    .background {
                        if activePicker != nil {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture { activePicker = nil }
                        }
                    }
                }
                .scrollIndicators(.hidden)

                if let activePicker {
                    notePickerStrip(for: activePicker)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            .animation(.easeOut(duration: 0.22), value: activePicker)
        }
        .background(background)
        .lumenoteCompactHeader(title: "음정", showsBackButton: true) {
            AppearanceToggleButton(appearance: $appearance)
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func staffCards(isWide: Bool) -> some View {
        let ascending = intervalStaffSection(
            title: "상행",
            directionIcon: "arrow.up",
            notes: model.ascendingStaffNotes,
            englishName: model.ascendingIntervalNameEnglish,
            koreanName: model.ascendingIntervalName
        )
        let descending = intervalStaffSection(
            title: "하행",
            directionIcon: "arrow.down",
            notes: model.descendingStaffNotes,
            englishName: model.descendingIntervalNameEnglish,
            koreanName: model.descendingIntervalName
        )

        if isWide {
            HStack(alignment: .top, spacing: LumenoteSpacing.section) {
                ascending
                descending
            }
        } else {
            ascending
            descending
        }
    }

    private var noteSelectionCard: some View {
        HStack(alignment: .center, spacing: LumenoteSpacing.md) {
            noteHeaderButton(
                title: "기준음",
                displayName: model.rootDisplayName,
                alignment: .leading,
                isActive: activePicker == .root,
                accessibilityHint: "기준음을 변경하려면 두 번 탭하세요"
            ) {
                togglePicker(.root)
            }

            intervalArrow
                .frame(maxWidth: .infinity)

            noteHeaderButton(
                title: "목표음",
                displayName: model.targetDisplayName,
                alignment: .trailing,
                isActive: activePicker == .target,
                accessibilityHint: "목표음을 변경하려면 두 번 탭하세요"
            ) {
                togglePicker(.target)
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

    private func noteHeaderButton(
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
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(isActive ? palette.minor : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: frameAlignment)
        .accessibilityLabel("\(title) \(displayName)")
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private var intervalArrow: some View {
        HStack(spacing: 0) {
            Capsule()
                .fill(palette.minor.opacity(0.5))
                .frame(height: 2)
            IntervalArrowHead()
                .fill(palette.minor)
                .frame(width: 8, height: 10)
        }
        .frame(maxWidth: 88)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    private func intervalStaffSection(
        title: String,
        directionIcon: String,
        notes: [IntervalStaffNote],
        englishName: String,
        koreanName: String
    ) -> some View {
        VStack(spacing: LumenoteSpacing.lg) {
            HStack(spacing: LumenoteSpacing.md) {
                Text(title)
                    .font(LumenoteFont.caption(.semibold))
                Image(systemName: directionIcon)
                    .font(LumenoteFont.caption(.semibold))
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(title)

            IntervalStaffView(
                notes: notes,
                staffSpace: 12,
                lineColor: Color.primary.opacity(0.75),
                noteColor: Color.primary
            )
            .frame(maxWidth: .infinity)

            VStack(spacing: LumenoteSpacing.xxs) {
                Text(englishName)
                    .font(LumenoteFont.rounded(size: 20, weight: .bold))
                    .foregroundStyle(palette.minor)
                    .multilineTextAlignment(.center)
                Text(koreanName)
                    .font(LumenoteFont.callout(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title), \(englishName), \(koreanName)")
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

    // MARK: - Bottom note picker strip

    /// Fixed chip width so naturals, sharps, and flats share one generous size.
    private let noteChipWidth: CGFloat = 64

    private func notePickerStrip(for target: NotePickerTarget) -> some View {
        let selectedSpelling = target == .root ? model.rootSpelling : model.targetSpelling

        return VStack(spacing: LumenoteSpacing.lg) {
            HStack {
                Text(target.title)
                    .font(LumenoteFont.caption(.semibold))
                    .foregroundStyle(palette.minor)
                Spacer()
                Button {
                    activePicker = nil
                } label: {
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

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: LumenoteSpacing.md) {
                    ForEach(model.noteOptions, id: \.spelling) { option in
                        let selected = option.spelling == selectedSpelling
                        Button {
                            selectNote(option.spelling, for: target)
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
            .scrollPosition(id: $stripScrollPosition, anchor: .center)
        }
        .padding(.top, LumenoteSpacing.xxl)
        .padding(.bottom, LumenoteSpacing.xl)
        .frame(maxWidth: .infinity)
        .background(palette.cardBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(palette.divider)
                .frame(height: LumenoteStroke.hairline)
        }
        .onAppear {
            stripScrollPosition = selectedSpelling
        }
        .onChange(of: target) { _, newTarget in
            let spelling = newTarget == .root ? model.rootSpelling : model.targetSpelling
            stripScrollPosition = spelling
        }
    }

    private func togglePicker(_ target: NotePickerTarget) {
        if activePicker == target {
            activePicker = nil
        } else {
            activePicker = target
            stripScrollPosition = target == .root ? model.rootSpelling : model.targetSpelling
        }
    }

    private func selectNote(_ spelling: String, for target: NotePickerTarget) {
        switch target {
        case .root:
            model.rootSpelling = spelling
        case .target:
            model.targetSpelling = spelling
        }
        stripScrollPosition = spelling
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

/// Right-pointing triangle flush against an adjacent shaft (no symbol side bearing).
private struct IntervalArrowHead: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    NavigationStack {
        IntervalView()
    }
    .lumenotePalette()
}
