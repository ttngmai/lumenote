//

import SwiftUI

/// Textbook-style diatonic-chord lesson: concept, construction, and harmonic function.
struct DiatonicChordView: View {
    @Environment(\.appPalette) private var palette
    @AppStorage(AppearanceMode.storageKey) private var appearance: AppearanceMode = .system

    @State private var model = DiatonicChordModel()
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
                    VStack(alignment: .leading, spacing: LumenoteSpacing.section) {
                        conceptCard
                        selectionCard
                        constructionCard(
                            availableWidth: geo.size.width - LumenoteSpacing.popupInset * 2
                        )
                        patternTableCard
                        functionFlowCard
                        functionGroupsCard
                        rolesSection
                    }
                    .padding(.horizontal, LumenoteSpacing.popupInset)
                    .padding(.vertical, LumenoteSpacing.xxxl)
                    .animation(.easeOut(duration: 0.2), value: model.tonicSpelling)
                    .animation(.easeOut(duration: 0.2), value: model.kind)
                    .animation(.easeOut(duration: 0.2), value: model.voicing)
                    .animation(.easeOut(duration: 0.2), value: model.highlightedDegree)
                    .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .top)
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
        .lumenoteCompactHeader(title: "다이아토닉 코드", showsBackButton: true) {
            AppearanceToggleButton(appearance: $appearance)
        }
    }

    // MARK: - Concept

    private var conceptCard: some View {
        lessonCard {
            sectionTitle("다이아토닉 코드란?")
            Text("특정 조(Key)의 스케일에 포함된 음들만 사용하여 만든 코드입니다.")
                .font(LumenoteFont.callout(.medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Construction

    private func constructionCard(availableWidth: CGFloat) -> some View {
        let innerWidth = max(0, availableWidth - LumenoteSpacing.xxl * 2)
        let staffSpace = staffSpace(for: innerWidth)

        return lessonCard {
            HStack(alignment: .firstTextBaseline) {
                sectionTitle("만들어지는 원리")
                Spacer()
                voicingToggle
            }
            Text("각 음을 근음으로 삼고 스케일 안에서 3도 간격으로 음을 쌓으면 7개의 다이아토닉 코드가 만들어집니다.")
                .font(LumenoteFont.callout(.medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            scaleNoteRow

            ScrollView(.horizontal, showsIndicators: false) {
                DiatonicChordStaffView(
                    columns: model.staffColumns,
                    highlightedDegree: model.highlightedDegree,
                    staffSpace: staffSpace,
                    targetWidth: innerWidth,
                    lineColor: Color.primary.opacity(0.75),
                    noteColor: Color.primary,
                    highlightColor: palette.minor,
                    dimmedNoteColor: Color.primary.opacity(0.28),
                    highlightFill: palette.highlight
                )
                .padding(.vertical, LumenoteSpacing.xs)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("다이아토닉 코드 오선")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("만들어지는 원리")
    }

    private var scaleNoteRow: some View {
        VStack(alignment: .leading, spacing: LumenoteSpacing.sm) {
            Text(model.kind.englishTitle)
                .font(LumenoteFont.caption2(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: LumenoteSpacing.sm) {
                ForEach(DiatonicDegree.allCases) { degree in
                    scaleNoteButton(degree)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(model.tonicDisplayName) \(model.kind.englishTitle) 스케일")
    }

    private func scaleNoteButton(_ degree: DiatonicDegree) -> some View {
        let names = model.scaleNoteDisplayNames
        let name = names.indices.contains(degree.rawValue) ? names[degree.rawValue] : ""
        let selected = model.highlightedDegree == degree

        return Button {
            model.toggleHighlightedDegree(degree)
        } label: {
            Text(name)
                .font(LumenoteFont.caption(.bold))
                .foregroundStyle(selected ? palette.emphasisStroke : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, LumenoteSpacing.sm)
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
        .accessibilityLabel(name)
        .accessibilityHint("해당 다이아토닉 코드를 오선에서 보려면 두 번 탭하세요")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: - Selection

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

    // MARK: - Construction helpers

    private var voicingToggle: some View {
        HStack(spacing: LumenoteSpacing.xs) {
            ForEach(DiatonicVoicing.allCases) { voicing in
                let selected = model.voicing == voicing
                Button {
                    model.voicing = voicing
                } label: {
                    Text(voicing.title)
                        .font(LumenoteFont.caption2(.bold))
                        .foregroundStyle(selected ? palette.emphasisStroke : .secondary)
                        .padding(.horizontal, LumenoteSpacing.md)
                        .padding(.vertical, LumenoteSpacing.xs)
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
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("화음 구성")
    }

    // MARK: - Pattern table

    private var patternTableCard: some View {
        lessonCard {
            sectionTitle(model.voicing.title)
            Text("음계가 바뀌면 각 도수의 코드 품질도 함께 바뀝니다.")
                .font(LumenoteFont.caption(.medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    patternHeaderRow
                    ForEach(ScaleKind.allCases) { kind in
                        Rectangle()
                            .fill(palette.divider)
                            .frame(height: LumenoteStroke.hairline)
                        patternDataRow(kind)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: LumenoteRadius.softRow, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: LumenoteRadius.softRow, style: .continuous)
                    .strokeBorder(palette.divider, lineWidth: LumenoteStroke.hairline)
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(model.voicing.title) 다이아토닉 패턴")
    }

    private var patternHeaderRow: some View {
        HStack(spacing: 0) {
            Text("음계")
                .frame(width: 108, alignment: .leading)
            ForEach(DiatonicDegree.allCases) { degree in
                Text(degree.headerLabel)
                    .frame(width: patternCellWidth, alignment: .center)
            }
        }
        .font(LumenoteFont.caption2(.bold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, LumenoteSpacing.lg)
        .padding(.vertical, LumenoteSpacing.md)
        .background(palette.highlightSoft)
        .accessibilityHidden(true)
    }

    private func patternDataRow(_ kind: ScaleKind) -> some View {
        let selected = model.kind == kind
        return HStack(spacing: 0) {
            Text(kind.englishTitle)
                .font(LumenoteFont.caption2(.bold))
                .foregroundStyle(.primary)
                .frame(width: 108, alignment: .leading)
                .minimumScaleFactor(0.8)
                .lineLimit(2)
            ForEach(DiatonicDegree.allCases) { degree in
                Text(DiatonicChordModel.roman(kind: kind, voicing: model.voicing, degree: degree))
                    .font(LumenoteFont.caption2(.semibold))
                    .foregroundStyle(selected ? .primary : .secondary)
                    .frame(width: patternCellWidth, alignment: .center)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, LumenoteSpacing.lg)
        .padding(.vertical, LumenoteSpacing.lg)
        .background(selected ? palette.highlightSoft : Color.clear)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(patternRowAccessibility(kind))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var patternCellWidth: CGFloat {
        model.voicing == .seventh ? 68 : 52
    }

    private func patternRowAccessibility(_ kind: ScaleKind) -> String {
        let romans = DiatonicDegree.allCases.map {
            DiatonicChordModel.roman(kind: kind, voicing: model.voicing, degree: $0)
        }
        return "\(kind.englishTitle), \(romans.joined(separator: ", "))"
    }

    // MARK: - Function

    private var functionFlowCard: some View {
        lessonCard {
            sectionTitle("다이아토닉 코드의 기능")
            Text("메이저 키의 다이아토닉 코드는 화성적 역할에 따라 Tonic, Subdominant, Dominant로 나뉩니다.\n기본적인 흐름은 안정 → 전개 → 긴장 → 해결입니다.")
                .font(LumenoteFont.callout(.medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if model.kind != .major {
                Text("아래 역할은 메이저 키 기준이며, 코드 이름은 고른 으뜸음의 Major로 보여 줍니다.")
                    .font(LumenoteFont.caption(.medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: LumenoteSpacing.sm) {
                ForEach(Array(HarmonicMotionStep.allCases.enumerated()), id: \.element.id) { index, step in
                    if index > 0 {
                        Image(systemName: "arrow.down")
                            .font(LumenoteFont.caption(.bold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .accessibilityHidden(true)
                    }
                    motionStepRow(step)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("다이아토닉 코드의 기능, Tonic, Subdominant, Dominant, 안정, 전개, 긴장, 해결")
    }

    private func motionStepRow(_ step: HarmonicMotionStep) -> some View {
        HStack(alignment: .center, spacing: LumenoteSpacing.lg) {
            Text(step.title)
                .font(LumenoteFont.body(.bold))
                .foregroundStyle(functionTint(step.function))
                .frame(width: 44, alignment: .leading)

            VStack(alignment: .leading, spacing: LumenoteSpacing.xxs) {
                Text(step.function.englishTitle)
                    .font(LumenoteFont.callout(.bold))
                    .foregroundStyle(.primary)
                Text(step.romans)
                    .font(LumenoteFont.caption(.semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, LumenoteSpacing.lg)
        .padding(.vertical, LumenoteSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: LumenoteRadius.softRow, style: .continuous)
                .fill(functionTint(step.function).opacity(0.14))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(step.title), \(step.function.englishTitle), \(step.romans)")
    }

    private var functionGroupsCard: some View {
        lessonCard {
            VStack(alignment: .leading, spacing: LumenoteSpacing.md) {
                ForEach(HarmonicFunction.allCases) { function in
                    HStack(alignment: .firstTextBaseline, spacing: LumenoteSpacing.md) {
                        Circle()
                            .fill(functionTint(function))
                            .frame(width: 8, height: 8)
                            .padding(.top, 5)
                        VStack(alignment: .leading, spacing: LumenoteSpacing.xxs) {
                            Text("\(function.englishTitle) — \(function.memberRomans)")
                                .font(LumenoteFont.callout(.bold))
                                .foregroundStyle(.primary)
                            Text(function.motionLabel)
                                .font(LumenoteFont.caption(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(function.englishTitle), \(function.memberRomans), \(function.motionLabel)")
                }
            }
        }
    }

    // MARK: - Roles

    private var rolesSection: some View {
        VStack(alignment: .leading, spacing: LumenoteSpacing.md) {
            Text("각 코드의 역할")
                .font(LumenoteFont.caption(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, LumenoteSpacing.xs)

            ForEach(DiatonicChordModel.roles) { role in
                roleCard(role)
            }
        }
    }

    private func roleCard(_ role: DiatonicDegreeRole) -> some View {
        let example = model.majorChord(for: role.degree)
        return lessonCard {
            HStack(alignment: .firstTextBaseline, spacing: LumenoteSpacing.md) {
                Text(role.degree.functionRoman)
                    .font(LumenoteFont.headline(.bold))
                    .foregroundStyle(functionTint(role.function))
                Text(role.functionLabel)
                    .font(LumenoteFont.caption(.bold))
                    .foregroundStyle(functionTint(role.function))
                Spacer(minLength: 0)
            }

            if let example {
                Text("\(model.tonicDisplayName) Major에서는 \(example.examplePhrase)입니다.")
                    .font(LumenoteFont.caption(.semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(role.title)
                .font(LumenoteFont.callout(.bold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(roleBody(role, example: example))
                .font(LumenoteFont.callout(.medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text("핵심: \(role.takeaway)")
                .font(LumenoteFont.caption(.bold))
                .foregroundStyle(functionTint(role.function))
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(role.degree.functionRoman), \(role.functionLabel), \(example?.examplePhrase ?? ""), \(role.title), 핵심 \(role.takeaway)"
        )
    }

    private func roleBody(_ role: DiatonicDegreeRole, example: DiatonicChordEntry?) -> String {
        switch role.degree {
        case .v:
            guard let example,
                  let leading = model.majorChord(for: .vii)?.rootDisplayName
            else { return role.body }
            return "\(role.body) \(model.tonicDisplayName) Major의 \(example.compactName) 코드에서는 \(leading) → \(model.tonicDisplayName)의 움직임이 이에 해당합니다."
        case .vii:
            guard let example,
                  let tonic = model.majorChord(for: .i)
            else { return role.body }
            return "\(role.body) \(model.tonicDisplayName) Major에서는 \(example.examplePhrase) → \(tonic.examplePhrase)가 됩니다."
        default:
            return role.body
        }
    }

    // MARK: - Shared chrome

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(LumenoteFont.body(.bold))
            .foregroundStyle(.primary)
            .accessibilityAddTraits(.isHeader)
    }

    private func lessonCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: LumenoteSpacing.lg) {
            content()
        }
        .padding(LumenoteSpacing.xxl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous)
                .strokeBorder(palette.divider, lineWidth: LumenoteStroke.compact)
        )
    }

    private func functionTint(_ function: HarmonicFunction) -> Color {
        switch function {
        case .tonic: palette.quizCorrect
        case .subdominant: palette.minor
        case .dominant: palette.major
        }
    }

    private func staffSpace(for availableWidth: CGFloat) -> CGFloat {
        let fitted = availableWidth / 26
        return min(13, max(8.5, fitted))
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

private extension DiatonicDegree {
    var headerLabel: String {
        switch self {
        case .i: "I"
        case .ii: "II"
        case .iii: "III"
        case .iv: "IV"
        case .v: "V"
        case .vi: "VI"
        case .vii: "VII"
        }
    }
}

private extension View {
    func pickerStripChrome() -> some View {
        modifier(DiatonicPickerStripChrome())
    }
}

private struct DiatonicPickerStripChrome: ViewModifier {
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
        DiatonicChordView()
    }
    .lumenotePalette()
}
