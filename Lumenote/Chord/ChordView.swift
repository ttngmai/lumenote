//

import SwiftUI

struct ChordView: View {
    @Environment(\.appPalette) private var palette
    @AppStorage(AppearanceMode.storageKey) private var appearance: AppearanceMode = .system

    @State private var cards: [ChordCard] = [ChordCard()]
    @State private var activePicker: ActivePicker?
    @State private var rootStripScrollPosition: String?
    @State private var triadStripScrollPosition: String?
    @State private var seventhStripScrollPosition: String?
    @State private var scrollTarget: ChordCard.ID?
    @State private var reorderingCardID: ChordCard.ID?
    @State private var showsGuide = false

    private struct ActivePicker: Equatable {
        enum Field: Equatable {
            case root
            case kind
        }

        let cardID: ChordCard.ID
        let field: Field
    }

    private let noteChipWidth: CGFloat = 64
    private let kindChipMinWidth: CGFloat = 128

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: LumenoteSpacing.section) {
                            ForEach(cards) { card in
                                staffCard(
                                    card,
                                    availableWidth: geo.size.width - LumenoteSpacing.popupInset * 2
                                )
                                .fixedSize(horizontal: false, vertical: true)
                                .id(card.id)
                            }

                            if cards.count < ChordCard.maximumCount {
                                addCardButton
                            }

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
                        .animation(.easeOut(duration: 0.2), value: cards)
                        .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .top)
                        .background {
                            if activePicker != nil {
                                dismissTapLayer
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: scrollTarget) { _, target in
                        guard let target else { return }
                        DispatchQueue.main.async {
                            withAnimation(.easeOut(duration: 0.22)) {
                                proxy.scrollTo(target, anchor: .top)
                            }
                            scrollTarget = nil
                        }
                    }
                }

                if let activePicker {
                    pickerStrip(for: activePicker)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            .animation(.easeOut(duration: 0.22), value: activePicker)
        }
        .background(background)
        .lumenoteCompactHeader(title: "코드", showsBackButton: true) {
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
                .accessibilityLabel("코드 정리")

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

    private func staffCard(_ card: ChordCard, availableWidth: CGFloat) -> some View {
        let innerWidth = max(0, availableWidth - LumenoteSpacing.xxl * 2)
        let staffSpace = staffSpace(for: innerWidth)

        return VStack(spacing: LumenoteSpacing.section) {
            VStack(spacing: LumenoteSpacing.md) {
                selectionHeader(for: card)
                if reorderingCardID == card.id {
                    moveControls(for: card.id)
                }
            }

            ChordStaffView(
                notes: card.staffNotes,
                noteNames: card.toneDisplayNames,
                degreeLabels: card.degreeLabels,
                staffSpace: staffSpace,
                targetWidth: innerWidth,
                lineColor: Color.primary.opacity(0.75),
                noteColor: Color.primary,
                accentColor: palette.minor
            )
            .padding(.vertical, LumenoteSpacing.xs)
            .overlay {
                if activePicker != nil {
                    dismissTapLayer
                }
            }

            formulaBlock(for: card)
        }
        .padding(LumenoteSpacing.xxl)
        .frame(maxWidth: .infinity)
        .lumenoteCard()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(card.rootDisplayName) \(card.kind.englishTitle)")
    }

    private func selectionHeader(for card: ChordCard) -> some View {
        HStack(spacing: LumenoteSpacing.md) {
            compactSettingButton(
                title: "근음",
                value: card.rootDisplayName,
                isActive: activePicker == ActivePicker(cardID: card.id, field: .root),
                accessibilityHint: "근음을 변경하려면 두 번 탭하세요"
            ) {
                togglePicker(for: card.id, field: .root)
            }

            compactSettingButton(
                title: "코드",
                value: card.kind.englishTitle,
                isActive: activePicker == ActivePicker(cardID: card.id, field: .kind),
                accessibilityHint: "코드를 변경하려면 두 번 탭하세요"
            ) {
                togglePicker(for: card.id, field: .kind)
            }

            if cards.count > 1 {
                reorderToggle(card.id)
                removeCardButton(card.id)
            }
        }
    }

    private func formulaBlock(for card: ChordCard) -> some View {
        VStack(alignment: .leading, spacing: LumenoteSpacing.lg) {
            labeledRow(title: "구성음") {
                HStack(spacing: LumenoteSpacing.sm) {
                    ForEach(Array(card.kind.tones.enumerated()), id: \.offset) { _, tone in
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
                Text(card.notations.joined(separator: "  ·  "))
                    .font(LumenoteFont.callout(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("구성음 \(card.kind.formulaText), 표기 \(card.notations.joined(separator: ", "))")
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

    private var addCardButton: some View {
        Button(action: addCard) {
            HStack(spacing: LumenoteSpacing.sm) {
                Image(systemName: "plus")
                    .font(LumenoteFont.callout(.bold))
                Text("코드 추가")
                    .font(LumenoteFont.callout(.semibold))
            }
            .foregroundStyle(palette.minor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, LumenoteSpacing.xl)
            .background(
                RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous)
                    .fill(Color.primary.opacity(0.001))
            )
            .overlay(
                RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous)
                    .strokeBorder(palette.divider, lineWidth: LumenoteStroke.compact)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("코드 추가")
        .accessibilityHint("코드 카드를 추가합니다. 최대 \(ChordCard.maximumCount)개")
    }

    private func reorderToggle(_ cardID: ChordCard.ID) -> some View {
        let isActive = reorderingCardID == cardID
        return Button {
            let opening = reorderingCardID != cardID
            withAnimation(.easeOut(duration: 0.2)) {
                reorderingCardID = opening ? cardID : nil
            }
            if opening {
                activePicker = nil
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(LumenoteFont.caption2(.bold))
                .foregroundStyle(isActive ? palette.minor : .secondary)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isActive ? "순서 이동 닫기" : "순서 이동")
        .accessibilityHint("위, 아래 이동 버튼을 표시합니다")
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private func moveControls(for cardID: ChordCard.ID) -> some View {
        HStack(spacing: LumenoteSpacing.md) {
            moveCardButton(cardID, direction: -1)
            moveCardButton(cardID, direction: 1)
        }
    }

    private func moveCardButton(_ cardID: ChordCard.ID, direction: Int) -> some View {
        let index = cards.firstIndex(where: { $0.id == cardID }) ?? 0
        let enabled = direction < 0 ? index > 0 : index < cards.count - 1
        let title = direction < 0 ? "위로" : "아래로"
        let symbol = direction < 0 ? "chevron.up" : "chevron.down"

        return Button {
            moveCard(cardID, by: direction)
        } label: {
            HStack(spacing: LumenoteSpacing.xs) {
                Image(systemName: symbol)
                Text(title)
            }
            .font(LumenoteFont.caption(.semibold))
            .foregroundStyle(enabled ? palette.minor : Color.secondary.opacity(0.4))
            .frame(maxWidth: .infinity)
            .padding(.vertical, LumenoteSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: LumenoteRadius.chip, style: .continuous)
                    .fill(enabled ? palette.highlight : Color.primary.opacity(0.001))
            )
            .overlay(
                RoundedRectangle(cornerRadius: LumenoteRadius.chip, style: .continuous)
                    .strokeBorder(palette.divider, lineWidth: LumenoteStroke.hairline)
            )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(title + " 이동")
    }

    private func removeCardButton(_ cardID: ChordCard.ID) -> some View {
        Button {
            removeCard(cardID)
        } label: {
            Image(systemName: "xmark")
                .font(LumenoteFont.caption2(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("코드 카드 삭제")
    }

    private func compactSettingButton(
        title: String,
        value: String,
        isActive: Bool,
        accessibilityHint: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: LumenoteSpacing.xxs) {
                Text(title)
                    .font(LumenoteFont.caption2(.semibold))
                    .foregroundStyle(isActive ? palette.minor : .secondary)
                Text(value)
                    .font(LumenoteFont.callout(.bold))
                    .foregroundStyle(isActive ? palette.minor : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, LumenoteSpacing.lg)
            .padding(.vertical, LumenoteSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: LumenoteRadius.chip, style: .continuous)
                    .fill(isActive ? palette.highlight : Color.primary.opacity(0.001))
            )
            .overlay(
                RoundedRectangle(cornerRadius: LumenoteRadius.chip, style: .continuous)
                    .strokeBorder(
                        isActive ? palette.cardBorderActive : palette.divider,
                        lineWidth: isActive ? LumenoteStroke.compact : LumenoteStroke.hairline
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: LumenoteRadius.chip, style: .continuous))
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: LumenoteRadius.chip, style: .continuous))
        .accessibilityLabel("\(title) \(value)")
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    // MARK: - Bottom picker strips

    @ViewBuilder
    private func pickerStrip(for target: ActivePicker) -> some View {
        switch target.field {
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
                    ForEach(ChordModel.selectableNotes, id: \.spelling) { option in
                        let selected = option.spelling == activeCard?.rootSpelling
                        Button {
                            setActiveRoot(option.spelling)
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
            rootStripScrollPosition = activeCard?.rootSpelling
        }
    }

    private var kindPickerStrip: some View {
        VStack(spacing: LumenoteSpacing.lg) {
            pickerStripHeader(title: "코드") {
                activePicker = nil
            }

            kindChipRow(title: ChordCategory.triad.englishTitle, kinds: ChordKind.triads, scrollPosition: $triadStripScrollPosition)
            kindChipRow(title: ChordCategory.seventh.englishTitle, kinds: ChordKind.sevenths, scrollPosition: $seventhStripScrollPosition)
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
                        let selected = activeCard?.kind == kind
                        Button {
                            setActiveKind(kind)
                        } label: {
                            Text(kind.englishTitle)
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
                        .accessibilityLabel(kind.englishTitle)
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

    private var activeCard: ChordCard? {
        guard let cardID = activePicker?.cardID else { return nil }
        return cards.first { $0.id == cardID }
    }

    private func togglePicker(for cardID: ChordCard.ID, field: ActivePicker.Field) {
        let target = ActivePicker(cardID: cardID, field: field)
        if activePicker == target {
            activePicker = nil
            return
        }
        activePicker = target
        guard let card = cards.first(where: { $0.id == cardID }) else { return }
        switch field {
        case .root:
            rootStripScrollPosition = card.rootSpelling
        case .kind:
            syncKindStripPositions(for: card)
        }
    }

    private func setActiveRoot(_ spelling: String) {
        guard let cardID = activePicker?.cardID,
              let index = cards.firstIndex(where: { $0.id == cardID })
        else { return }
        cards[index].setRoot(spelling)
        rootStripScrollPosition = cards[index].rootSpelling
    }

    private func setActiveKind(_ kind: ChordKind) {
        guard let cardID = activePicker?.cardID,
              let index = cards.firstIndex(where: { $0.id == cardID })
        else { return }
        cards[index].kind = kind
        syncKindStripPositions(for: cards[index])
    }

    private func syncKindStripPositions() {
        guard let card = activeCard else { return }
        syncKindStripPositions(for: card)
    }

    private func syncKindStripPositions(for card: ChordCard) {
        switch card.kind.category {
        case .triad:
            triadStripScrollPosition = card.kind.id
        case .seventh:
            seventhStripScrollPosition = card.kind.id
        }
    }

    private func addCard() {
        guard cards.count < ChordCard.maximumCount else { return }
        activePicker = nil
        let next = cards.last?.addingNextKind() ?? ChordCard()
        withAnimation(.easeOut(duration: 0.22)) {
            cards.append(next)
            scrollTarget = next.id
        }
    }

    private func removeCard(_ cardID: ChordCard.ID) {
        guard cards.count > 1 else { return }
        if activePicker?.cardID == cardID {
            activePicker = nil
        }
        withAnimation(.easeOut(duration: 0.22)) {
            cards.removeAll { $0.id == cardID }
            if cards.count < 2 || reorderingCardID == cardID {
                reorderingCardID = nil
            }
        }
    }

    private func moveCard(_ cardID: ChordCard.ID, by direction: Int) {
        guard let index = cards.firstIndex(where: { $0.id == cardID }) else { return }
        let target = index + direction
        guard cards.indices.contains(target) else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            cards.swapAt(index, target)
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
