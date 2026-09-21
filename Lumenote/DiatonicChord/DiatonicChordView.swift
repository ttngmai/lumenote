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
                            .overlay {
                                if activePicker != nil { dismissTapLayer }
                            }

                        constructionCard(
                            availableWidth: geo.size.width - LumenoteSpacing.popupInset * 2
                        )

                        functionFlowCard
                            .overlay {
                                if activePicker != nil { dismissTapLayer }
                            }

                        rolesSection
                            .overlay {
                                if activePicker != nil { dismissTapLayer }
                            }

                        dismissTapLayer
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .layoutPriority(-1)
                            .allowsHitTesting(activePicker != nil)
                    }
                    .padding(.horizontal, LumenoteSpacing.popupInset)
                    .padding(.vertical, LumenoteSpacing.xxxl)
                    .animation(.easeOut(duration: 0.2), value: model.tonicSpelling)
                    .animation(.easeOut(duration: 0.2), value: model.kind)
                    .animation(.easeOut(duration: 0.2), value: model.voicing)
                    .animation(.easeOut(duration: 0.2), value: model.highlightedDegree)
                    .animation(.easeOut(duration: 0.2), value: model.selectedRoleDegree)
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
        .lumenoteCompactHeader(title: "다이아토닉 코드", showsBackButton: true) {
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

    // MARK: - Concept

    private var conceptCard: some View {
        lessonCard {
            sectionTitle("다이아토닉 코드")
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
            .overlay {
                if activePicker != nil { dismissTapLayer }
            }

            Text("각 음을 근음으로 삼고 스케일 안에서 3도 간격으로 음을 쌓으면 7개의 다이아토닉 코드가 만들어집니다.")
                .font(LumenoteFont.callout(.medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay {
                    if activePicker != nil { dismissTapLayer }
                }

            constructionSettings
            scaleNoteRow
                .overlay {
                    if activePicker != nil { dismissTapLayer }
                }

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
            .overlay {
                if activePicker != nil { dismissTapLayer }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("만들어지는 원리")
    }

    private var scaleNoteRow: some View {
        HStack(spacing: LumenoteSpacing.sm) {
            ForEach(DiatonicDegree.allCases) { degree in
                scaleNoteButton(degree)
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

    // MARK: - Construction helpers

    private var constructionSettings: some View {
        HStack(spacing: LumenoteSpacing.md) {
            compactSettingButton(
                title: "으뜸음",
                value: model.tonicDisplayName,
                isActive: activePicker == .tonic,
                accessibilityHint: "으뜸음을 변경하려면 두 번 탭하세요"
            ) {
                togglePicker(.tonic)
            }

            compactSettingButton(
                title: "음계",
                value: model.kind.englishTitle,
                isActive: activePicker == .kind,
                accessibilityHint: "음계를 변경하려면 두 번 탭하세요"
            ) {
                togglePicker(.kind)
            }
        }
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

    // MARK: - Function

    private var functionFlowCard: some View {
        lessonCard {
            sectionTitle("다이아토닉 코드의 기능 (메이저 키 기준)")
            Text("다이아토닉 코드는 화성적 역할에 따라 Tonic, Subdominant, Dominant로 나뉩니다.\n\n대표적인 진행은 다음과 같습니다.")
                .font(LumenoteFont.callout(.medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

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
        .accessibilityLabel("다이아토닉 코드의 기능, 메이저 키 기준, Tonic, Subdominant, Dominant, 안정, 전개, 긴장, 해결")
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

    // MARK: - Roles

    private var rolesSection: some View {
        lessonCard {
            sectionTitle("각 코드의 역할")

            HStack(spacing: LumenoteSpacing.sm) {
                ForEach(DiatonicDegree.allCases) { degree in
                    roleDegreeButton(degree)
                }
            }

            if let role = model.selectedRole {
                roleDetail(role)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("각 코드의 역할")
    }

    private func roleDegreeButton(_ degree: DiatonicDegree) -> some View {
        let selected = model.selectedRoleDegree == degree

        return Button {
            model.selectedRoleDegree = degree
        } label: {
            Text(degree.functionRoman)
                .font(LumenoteFont.caption(.bold))
                .foregroundStyle(selected ? palette.emphasisStroke : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
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
        .accessibilityLabel(degree.functionRoman)
        .accessibilityHint("이 코드의 역할을 보려면 두 번 탭하세요")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func roleDetail(_ role: DiatonicDegreeRole) -> some View {
        VStack(alignment: .leading, spacing: LumenoteSpacing.lg) {
            HStack(alignment: .firstTextBaseline, spacing: LumenoteSpacing.md) {
                Text(role.degree.functionRoman)
                    .font(LumenoteFont.headline(.bold))
                    .foregroundStyle(functionTint(role.function))
                Text(role.functionLabel)
                    .font(LumenoteFont.caption(.bold))
                    .foregroundStyle(functionTint(role.function))
                Spacer(minLength: 0)
            }

            Text(role.title)
                .font(LumenoteFont.callout(.bold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(role.body)
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
            "\(role.degree.functionRoman), \(role.functionLabel), \(role.title), \(role.body), 핵심 \(role.takeaway)"
        )
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
