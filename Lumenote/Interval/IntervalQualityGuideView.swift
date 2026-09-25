//

import SwiftUI

/// Paged guide: natural structure, an interactive span, one accidental example, then quality-name rules.
struct IntervalQualityGuideView: View {
    @Environment(\.appPalette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var page = GuidePage.structure
    @State private var selectedDegreeName = "완전8도"

    private let connectorGap: CGFloat = 36

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    structurePage
                        .tag(GuidePage.structure)
                    explorerPage
                        .tag(GuidePage.explorer)
                    alterationPage
                        .tag(GuidePage.alteration)
                    namingPage
                        .tag(GuidePage.naming)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                pageControls
            }
            .background(sheetBackground)
            .navigationTitle(page.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                        .font(LumenoteFont.callout(.semibold))
                }
            }
        }
        .lumenotePalette()
    }

    // MARK: - Pages

    private var structurePage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LumenoteSpacing.section) {
                VStack(alignment: .leading, spacing: LumenoteSpacing.xl) {
                    Text("음정은 두 음의 음이름으로 도수를 결정하고, 두 음 사이의 반음 간격으로 음정의 성질을 결정합니다.")
                    Text("C Major 스케일을 기준으로 각 도수에 포함된 자연 반음 구간을 살펴보세요.")
                }
                .font(LumenoteFont.callout(.medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

                naturalScaleCard

                Text("도수별 자연 반음 구간")
                    .font(LumenoteFont.headline(.bold))
                    .foregroundStyle(.primary)

                degreeTable

                Text("기준은 C에서 각 도수까지 상행할 때의 구조입니다.")
                    .font(LumenoteFont.caption(.medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(LumenoteSpacing.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous)
                    .strokeBorder(palette.divider, lineWidth: LumenoteStroke.compact)
            )
            .padding(.horizontal, LumenoteSpacing.popupInset)
            .padding(.vertical, LumenoteSpacing.xxxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(sheetBackground)
    }

    private var explorerPage: some View {
        let degree = selectedDegree
        return ScrollView {
            VStack(alignment: .leading, spacing: LumenoteSpacing.section) {
                Text("C를 기준으로 음정을 선택하세요.")
                    .font(LumenoteFont.callout(.medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                degreePicker

                Rectangle()
                    .fill(palette.divider)
                    .frame(height: 1)

                Text(degree.name)
                    .font(LumenoteFont.headline(.bold))
                    .foregroundStyle(palette.fretboardQuizRoot)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)

                NaturalScaleDiagram(
                    idleFill: idleNoteFill,
                    idleForeground: idleNoteForeground,
                    rootFill: palette.fretboardQuizRoot,
                    halfStep: palette.major,
                    wholeStepDot: wholeStepDot,
                    spanEndIndex: degree.noteIndex
                )

                HStack(alignment: .top, spacing: LumenoteSpacing.xl) {
                    spanStat(title: "자연 반음 구간", value: "\(degree.naturalHalfSteps)개")
                    spanStat(title: "전체 반음 간격", value: "\(degree.semitones)")
                }
                .padding(.top, LumenoteSpacing.md)

                Text("C에서 \(degree.targetNote)까지의 상행 음정")
                    .font(LumenoteFont.caption(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
            .padding(LumenoteSpacing.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous)
                    .strokeBorder(palette.divider, lineWidth: LumenoteStroke.compact)
            )
            .padding(.horizontal, LumenoteSpacing.popupInset)
            .padding(.vertical, LumenoteSpacing.xxxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(sheetBackground)
    }

    private var degreePicker: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: LumenoteSpacing.md), count: 4)
        return LazyVGrid(columns: columns, spacing: LumenoteSpacing.md) {
            ForEach(Self.degreeRows) { row in
                let isSelected = row.name == selectedDegreeName
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedDegreeName = row.name
                    }
                } label: {
                    Text(row.name)
                        .font(LumenoteFont.caption(.semibold))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .foregroundStyle(isSelected ? selectedChipForeground : Color.primary)
                        .padding(.vertical, LumenoteSpacing.lg)
                        .frame(maxWidth: .infinity)
                        .background(
                            Capsule(style: .continuous)
                                .fill(isSelected ? selectedChipFill : unselectedChipFill)
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(
                                    isSelected ? Color.clear : unselectedChipBorder,
                                    lineWidth: LumenoteStroke.compact
                                )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    private func spanStat(title: String, value: String) -> some View {
        VStack(spacing: LumenoteSpacing.sm) {
            Text(title)
                .font(LumenoteFont.caption(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text(value)
                .font(LumenoteFont.rounded(size: 28, weight: .bold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var selectedDegree: DegreeSemitoneRow {
        Self.degreeRows.first { $0.name == selectedDegreeName } ?? Self.degreeRows[Self.degreeRows.count - 1]
    }

    private var selectedChipFill: Color {
        colorScheme == .dark ? Color.white : Color.black
    }

    private var selectedChipForeground: Color {
        colorScheme == .dark ? Color.black : Color.white
    }

    private var unselectedChipFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.7)
    }

    private var unselectedChipBorder: Color {
        colorScheme == .dark ? Color.white.opacity(0.28) : Color.black.opacity(0.16)
    }

    private var alterationPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LumenoteSpacing.section) {
                Text("C를 기준으로 목표음만 변경한 예시")
                    .font(LumenoteFont.callout(.medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: LumenoteSpacing.lg) {
                    alterationExample(
                        spelling: "C → E♯",
                        detail: "증3도 · 5반음",
                        fill: colors.augmented,
                        foreground: colors.onGreen
                    )
                    alterationArrow
                    alterationExample(
                        spelling: "C → E",
                        detail: "장3도 · 4반음",
                        fill: colors.major,
                        foreground: colors.onBlue
                    )
                    alterationArrow
                    alterationExample(
                        spelling: "C → E♭",
                        detail: "단3도 · 3반음",
                        fill: colors.minorQuality,
                        foreground: colors.onPink
                    )
                }

                Text("도수는 3도로 동일하지만 반음 간격에 따라 음정 이름이 달라집니다.")
                    .font(LumenoteFont.caption(.medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(LumenoteSpacing.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous)
                    .strokeBorder(palette.divider, lineWidth: LumenoteStroke.compact)
            )
            .padding(.horizontal, LumenoteSpacing.popupInset)
            .padding(.vertical, LumenoteSpacing.xxxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(sheetBackground)
    }

    private func alterationExample(
        spelling: String,
        detail: String,
        fill: Color,
        foreground: Color
    ) -> some View {
        VStack(spacing: LumenoteSpacing.xs) {
            Text(spelling)
                .font(LumenoteFont.headline(.bold))
            Text(detail)
                .font(LumenoteFont.subheadline(.semibold))
        }
        .foregroundStyle(foreground)
        .frame(maxWidth: .infinity)
        .padding(.vertical, LumenoteSpacing.xxl)
        .background(
            RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous)
                .fill(fill)
        )
        .accessibilityElement(children: .combine)
    }

    private var alterationArrow: some View {
        Image(systemName: "arrow.up.arrow.down")
            .font(LumenoteFont.rounded(size: 14, weight: .bold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }

    private var namingPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LumenoteSpacing.section) {
                summaryCard
                diagram
            }
            .padding(.horizontal, LumenoteSpacing.popupInset)
            .padding(.vertical, LumenoteSpacing.xxxl)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(sheetBackground)
    }

    private var pageControls: some View {
        HStack {
            pageButton(
                systemName: "chevron.left",
                label: "이전 페이지",
                enabled: page != .structure
            ) {
                move(by: -1)
            }

            Spacer()

            HStack(spacing: LumenoteSpacing.sm) {
                ForEach(GuidePage.allCases, id: \.self) { item in
                    Circle()
                        .fill(item == page ? Color.primary : Color.secondary.opacity(0.35))
                        .frame(width: 7, height: 7)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(page.rawValue + 1) / \(GuidePage.allCases.count), \(page.title)")

            Spacer()

            pageButton(
                systemName: "chevron.right",
                label: "다음 페이지",
                enabled: page != .naming
            ) {
                move(by: 1)
            }
        }
        .padding(.horizontal, LumenoteSpacing.popupInset)
        .padding(.top, LumenoteSpacing.md)
        .padding(.bottom, LumenoteSpacing.xl)
    }

    private func pageButton(
        systemName: String,
        label: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(LumenoteFont.rounded(size: 15, weight: .bold))
                .foregroundStyle(.primary)
                .frame(width: 34, height: 34)
                .background(Circle().fill(palette.cardBackground))
                .overlay(Circle().strokeBorder(palette.divider, lineWidth: LumenoteStroke.compact))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .accessibilityLabel(label)
    }

    private func move(by delta: Int) {
        guard let next = GuidePage(rawValue: page.rawValue + delta) else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            page = next
        }
    }

    // MARK: - Structure

    private var naturalScaleCard: some View {
        VStack(alignment: .leading, spacing: LumenoteSpacing.xl) {
            NaturalScaleDiagram(
                idleFill: idleNoteFill,
                idleForeground: idleNoteForeground,
                rootFill: palette.fretboardQuizRoot,
                halfStep: palette.major,
                wholeStepDot: wholeStepDot
            )

            Text("E–F, B–C는 자연 반음 구간")
                .font(LumenoteFont.subheadline(.bold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
        .padding(LumenoteSpacing.xl)
        .overlay(
            RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous)
                .strokeBorder(palette.divider, lineWidth: LumenoteStroke.compact)
        )
    }

    private var degreeTable: some View {
        VStack(spacing: 0) {
            degreeColumns(name: "음정", halves: "자연 반음 구간", semitones: "전체 반음 수")
                .font(LumenoteFont.caption(.medium))
                .foregroundStyle(.secondary)
                .padding(.bottom, LumenoteSpacing.sm)

            ForEach(Self.degreeRows) { row in
                Rectangle()
                    .fill(palette.divider)
                    .frame(height: 1)
                degreeColumns(
                    name: row.name,
                    halves: "\(row.naturalHalfSteps)개",
                    semitones: "\(row.semitones)"
                )
                .font(LumenoteFont.subheadline(.medium))
                .foregroundStyle(.primary)
                .padding(.vertical, LumenoteSpacing.xl)
            }
        }
    }

    private func degreeColumns(name: String, halves: String, semitones: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: LumenoteSpacing.md) {
            Text(name)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(halves)
                .frame(width: 88, alignment: .trailing)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(semitones)
                .frame(width: 64, alignment: .trailing)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
    }

    private var idleNoteFill: Color {
        colorScheme == .dark
            ? Color(red: 0.20, green: 0.25, blue: 0.34)
            : Color(red: 0.91, green: 0.93, blue: 0.97)
    }

    private var idleNoteForeground: Color {
        colorScheme == .dark
            ? Color(red: 0.72, green: 0.80, blue: 0.93)
            : Color(red: 0.32, green: 0.46, blue: 0.72)
    }

    private var wholeStepDot: Color {
        colorScheme == .dark
            ? Color(red: 0.55, green: 0.65, blue: 0.82)
            : Color(red: 0.62, green: 0.72, blue: 0.86)
    }

    private static let degreeRows: [DegreeSemitoneRow] = [
        .init(name: "완전1도", targetNote: "C", noteIndex: 0, naturalHalfSteps: 0, semitones: 0),
        .init(name: "장2도", targetNote: "D", noteIndex: 1, naturalHalfSteps: 0, semitones: 2),
        .init(name: "장3도", targetNote: "E", noteIndex: 2, naturalHalfSteps: 0, semitones: 4),
        .init(name: "완전4도", targetNote: "F", noteIndex: 3, naturalHalfSteps: 1, semitones: 5),
        .init(name: "완전5도", targetNote: "G", noteIndex: 4, naturalHalfSteps: 1, semitones: 7),
        .init(name: "장6도", targetNote: "A", noteIndex: 5, naturalHalfSteps: 1, semitones: 9),
        .init(name: "장7도", targetNote: "B", noteIndex: 6, naturalHalfSteps: 1, semitones: 11),
        .init(name: "완전8도", targetNote: "C", noteIndex: 7, naturalHalfSteps: 2, semitones: 12),
    ]

    // MARK: - Summary

    private var summaryCard: some View {
        Text("같은 도수에서 반음 간격이 넓어지면 ♯ 방향, 좁아지면 ♭ 방향으로 음정 이름이 바뀝니다.\n\n1·4·5·8도는 완전(Perfect), 2·3·6·7도는 장·단(Major/Minor)을 기준으로 합니다.")
            .font(LumenoteFont.callout(.medium))
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(LumenoteSpacing.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous)
                    .strokeBorder(palette.divider, lineWidth: LumenoteStroke.compact)
            )
    }

    // MARK: - Diagram

    private var diagram: some View {
        VStack(spacing: connectorGap) {
            qualityBox(
                .doublyAugmented,
                title: "Doubly Augmented(겹증)",
                fill: colors.doublyAugmented,
                foreground: colors.onGreen
            )

            qualityBox(
                .augmented,
                title: "Augmented(증)",
                fill: colors.augmented,
                foreground: colors.onGreen
            )

            HStack(alignment: .center, spacing: LumenoteSpacing.md) {
                qualityBox(
                    .perfect,
                    title: "Perfect(완전)",
                    degrees: "1, 4, 5, 8",
                    fill: colors.perfect,
                    foreground: colors.onBlue
                )

                VStack(spacing: connectorGap) {
                    qualityBox(
                        .major,
                        title: "Major(장)",
                        degrees: "2, 3, 6, 7",
                        fill: colors.major,
                        foreground: colors.onBlue
                    )
                    qualityBox(
                        .minor,
                        title: "Minor(단)",
                        degrees: "2, 3, 6, 7",
                        fill: colors.minorQuality,
                        foreground: colors.onPink
                    )
                }
            }

            qualityBox(
                .diminished,
                title: "Diminished(감)",
                fill: colors.diminished,
                foreground: colors.onRed
            )

            qualityBox(
                .doublyDiminished,
                title: "Doubly Diminished(겹감)",
                fill: colors.doublyDiminished,
                foreground: colors.onRed
            )
        }
        .padding(LumenoteSpacing.xxl)
        .frame(maxWidth: .infinity)
        .background(palette.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous)
                .strokeBorder(palette.divider, lineWidth: LumenoteStroke.compact)
        )
        .overlayPreferenceValue(QualityNodeFramesKey.self) { frames in
            GeometryReader { proxy in
                let resolved = frames.mapValues { proxy[$0] }
                QualityConnectorOverlay(
                    frames: resolved,
                    lineColor: palette.minor,
                    labelBackground: palette.cardBackground
                )
            }
            .allowsHitTesting(false)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("음정 품질 규칙 다이어그램")
    }

    private func qualityBox(
        _ id: QualityNode,
        title: String,
        degrees: String? = nil,
        fill: Color,
        foreground: Color
    ) -> some View {
        VStack(spacing: LumenoteSpacing.xxs) {
            Text(title)
                .font(LumenoteFont.caption(.bold))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
                .lineLimit(2)
            if let degrees {
                Text(degrees)
                    .font(LumenoteFont.caption2(.semibold))
                    .opacity(0.85)
            }
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, LumenoteSpacing.md)
        .padding(.vertical, LumenoteSpacing.lg)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: LumenoteRadius.softRow, style: .continuous)
                .fill(fill)
        )
        .anchorPreference(key: QualityNodeFramesKey.self, value: .bounds) { [id: $0] }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(degrees.map { "\(title), \($0)" } ?? title)
    }

    private var sheetBackground: some View {
        LinearGradient(
            colors: palette.backgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var colors: DiagramColors {
        DiagramColors(isDark: colorScheme == .dark)
    }
}

// MARK: - Guide pages

private enum GuidePage: Int, CaseIterable, Hashable {
    case structure
    case explorer
    case alteration
    case naming

    var title: String {
        switch self {
        case .structure: "음정의 기본 구조"
        case .explorer: "음정 구조 살펴보기"
        case .alteration: "기본 음정에서 변형 음정으로"
        case .naming: "음정 이름 규칙"
        }
    }
}

private struct DegreeSemitoneRow: Identifiable {
    let name: String
    let targetNote: String
    let noteIndex: Int
    let naturalHalfSteps: Int
    let semitones: Int

    var id: String { name }
}

/// C major letter row with whole-step and half-step markers between notes.
private struct NaturalScaleDiagram: View {
    let idleFill: Color
    let idleForeground: Color
    let rootFill: Color
    let halfStep: Color
    let wholeStepDot: Color
    /// Last scale degree included in the span. `nil` marks only the starting C and shows every step.
    var spanEndIndex: Int? = nil

    private let notes = ["C", "D", "E", "F", "G", "A", "B", "C"]
    private let halfStepIndexes: Set<Int> = [2, 6]
    private let spacing: CGFloat = 5
    private let tileHeight: CGFloat = 40

    var body: some View {
        GeometryReader { proxy in
            let noteWidth = max(0, (proxy.size.width - spacing * 7) / 8)
            VStack(spacing: LumenoteSpacing.sm) {
                ZStack {
                    HStack(spacing: spacing) {
                        ForEach(notes.indices, id: \.self) { index in
                            noteTile(notes[index], isEndpoint: highlightedIndexes.contains(index))
                                .opacity(isNoteDimmed(index) ? 0.28 : 1)
                                .frame(width: noteWidth, height: tileHeight)
                        }
                    }

                    ForEach(0..<7, id: \.self) { index in
                        Circle()
                            .fill(halfStepIndexes.contains(index) ? halfStep : wholeStepDot)
                            .frame(width: 4, height: 4)
                            .opacity(isStepDimmed(index) ? 0.28 : 1)
                            .position(
                                x: CGFloat(index + 1) * noteWidth + CGFloat(index) * spacing + spacing / 2,
                                y: tileHeight / 2
                            )
                    }
                }
                .frame(width: proxy.size.width, height: tileHeight)

                HStack(spacing: spacing) {
                    ForEach(0..<7, id: \.self) { index in
                        Text(halfStepIndexes.contains(index) ? "반" : "온")
                            .font(LumenoteFont.caption(.bold))
                            .foregroundStyle(halfStepIndexes.contains(index) ? halfStep : Color.primary)
                            .opacity(isStepDimmed(index) ? 0.28 : 1)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, noteWidth / 2 + spacing / 2)
            }
        }
        .frame(height: tileHeight + LumenoteSpacing.sm + 18)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabelText)
    }

    private var highlightedIndexes: Set<Int> {
        guard let spanEndIndex else { return [0] }
        return [0, spanEndIndex]
    }

    private func isNoteDimmed(_ index: Int) -> Bool {
        guard let spanEndIndex else { return false }
        return index > spanEndIndex
    }

    private func isStepDimmed(_ index: Int) -> Bool {
        guard let spanEndIndex else { return false }
        return index >= spanEndIndex
    }

    private var accessibilityLabelText: String {
        guard let spanEndIndex else {
            return "C Major 스케일. 온음, 온음, 반음, 온음, 온음, 온음, 반음. E-F와 B-C는 자연 반음 구간."
        }
        let steps = (0..<spanEndIndex).map { halfStepIndexes.contains($0) ? "반음" : "온음" }
        let stepList = steps.isEmpty ? "같은 음" : steps.joined(separator: ", ")
        return "C에서 \(notes[spanEndIndex])까지. \(stepList)."
    }

    private func noteTile(_ name: String, isEndpoint: Bool) -> some View {
        Text(name)
            .font(LumenoteFont.rounded(size: 16, weight: .bold))
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            .foregroundStyle(isEndpoint ? Color.white : idleForeground)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous)
                    .fill(isEndpoint ? rootFill : idleFill)
            )
    }
}

// MARK: - Diagram nodes & preferences

private enum QualityNode: Hashable {
    case doublyAugmented
    case augmented
    case perfect
    case major
    case minor
    case diminished
    case doublyDiminished
}

private struct QualityNodeFramesKey: PreferenceKey {
    static let defaultValue: [QualityNode: Anchor<CGRect>] = [:]

    static func reduce(
        value: inout [QualityNode: Anchor<CGRect>],
        nextValue: () -> [QualityNode: Anchor<CGRect>]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

// MARK: - Path connectors

private struct QualityConnectorOverlay: View {
    let frames: [QualityNode: CGRect]
    let lineColor: Color
    let labelBackground: Color

    /// Horizontal offset for paired up/down arrows so they sit side by side.
    private let pairLaneOffset: CGFloat = 14

    var body: some View {
        ZStack {
            Canvas { context, _ in
                for connector in connectors {
                    guard
                        let from = frames[connector.from],
                        let to = frames[connector.to]
                    else { continue }

                    let path = connector.path(from: from, to: to, laneOffset: pairLaneOffset)
                    context.stroke(
                        path,
                        with: .color(lineColor.opacity(0.75)),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                    )

                    let tip = connector.endPoint(from: from, to: to, laneOffset: pairLaneOffset)
                    let angle = connector.endAngle(from: from, to: to)
                    context.fill(
                        arrowHead(at: tip, angle: angle),
                        with: .color(lineColor.opacity(0.85))
                    )
                }
            }

            ForEach(Array(connectors.enumerated()), id: \.offset) { _, connector in
                if let from = frames[connector.from], let to = frames[connector.to] {
                    Text(connector.symbol)
                        .font(LumenoteFont.caption2(.bold))
                        .foregroundStyle(lineColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule(style: .continuous).fill(labelBackground))
                        .position(
                            connector.labelPoint(from: from, to: to, laneOffset: pairLaneOffset)
                        )
                }
            }
        }
        .accessibilityHidden(true)
    }

    private var connectors: [QualityConnector] {
        [
            // 겹증 ↔ 증: two vertical arrows
            .init(from: .augmented, to: .doublyAugmented, symbol: "#", lane: .leading),
            .init(from: .doublyAugmented, to: .augmented, symbol: "♭", lane: .trailing),

            // 증 → Perfect / Major (vertical into each column)
            .init(from: .perfect, to: .augmented, symbol: "#", lane: .center),
            .init(from: .major, to: .augmented, symbol: "#", lane: .center),

            // 장 ↔ 단: two vertical arrows
            .init(from: .minor, to: .major, symbol: "#", lane: .leading),
            .init(from: .major, to: .minor, symbol: "♭", lane: .trailing),

            // Perfect / Minor → 감
            .init(from: .perfect, to: .diminished, symbol: "♭", lane: .center),
            .init(from: .minor, to: .diminished, symbol: "♭", lane: .center),

            // 감 ↔ 겹감: two vertical arrows
            .init(from: .doublyDiminished, to: .diminished, symbol: "#", lane: .leading),
            .init(from: .diminished, to: .doublyDiminished, symbol: "♭", lane: .trailing),
        ]
    }

    private func arrowHead(at tip: CGPoint, angle: CGFloat) -> Path {
        let length: CGFloat = 7
        let width: CGFloat = 5
        var path = Path()
        path.move(to: tip)
        path.addLine(
            to: CGPoint(
                x: tip.x - length * cos(angle) + width * sin(angle),
                y: tip.y - length * sin(angle) - width * cos(angle)
            )
        )
        path.addLine(
            to: CGPoint(
                x: tip.x - length * cos(angle) - width * sin(angle),
                y: tip.y - length * sin(angle) + width * cos(angle)
            )
        )
        path.closeSubpath()
        return path
    }
}

/// A single vertical straight arrow from one box edge to another.
private struct QualityConnector {
    enum Lane {
        case leading
        case center
        case trailing
    }

    let from: QualityNode
    let to: QualityNode
    let symbol: String
    let lane: Lane

    func path(from: CGRect, to: CGRect, laneOffset: CGFloat) -> Path {
        var path = Path()
        path.move(to: startPoint(from: from, to: to, laneOffset: laneOffset))
        path.addLine(to: endPoint(from: from, to: to, laneOffset: laneOffset))
        return path
    }

    /// Vertical line uses the narrower column’s midX so Augmented/Diminished
    /// (full width) connect straight into Perfect / Major / Minor.
    func startPoint(from: CGRect, to: CGRect, laneOffset: CGFloat) -> CGPoint {
        let x = axisX(from: from, to: to, laneOffset: laneOffset)
        if from.midY < to.midY {
            // from is above → leave bottom edge downward
            return CGPoint(x: x, y: from.maxY)
        } else {
            // from is below → leave top edge upward
            return CGPoint(x: x, y: from.minY)
        }
    }

    func endPoint(from: CGRect, to: CGRect, laneOffset: CGFloat) -> CGPoint {
        let x = axisX(from: from, to: to, laneOffset: laneOffset)
        if from.midY < to.midY {
            return CGPoint(x: x, y: to.minY)
        } else {
            return CGPoint(x: x, y: to.maxY)
        }
    }

    func labelPoint(from: CGRect, to: CGRect, laneOffset: CGFloat) -> CGPoint {
        let start = startPoint(from: from, to: to, laneOffset: laneOffset)
        let end = endPoint(from: from, to: to, laneOffset: laneOffset)
        return CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
    }

    func endAngle(from: CGRect, to: CGRect) -> CGFloat {
        from.midY < to.midY ? .pi / 2 : -.pi / 2
    }

    private func axisX(from: CGRect, to: CGRect, laneOffset: CGFloat) -> CGFloat {
        // Prefer the narrower box’s center so full-width rows shoot vertical
        // shafts into the Perfect / Major / Minor columns.
        let baseX: CGFloat
        if from.width <= to.width {
            baseX = from.midX
        } else {
            baseX = to.midX
        }

        switch lane {
        case .leading: return baseX - laneOffset
        case .center: return baseX
        case .trailing: return baseX + laneOffset
        }
    }
}

private struct DiagramColors {
    let isDark: Bool

    var perfect: Color {
        isDark
            ? Self.rgb(0x32, 0x4B, 0x7B) // #324B7B, dark tint of #E4EDFF
            : Self.rgb(0xE4, 0xED, 0xFF) // #E4EDFF
    }

    var major: Color {
        isDark
            ? Self.rgb(0x36, 0x45, 0x63) // #364563, dark tint of #EAF1FF
            : Self.rgb(0xEA, 0xF1, 0xFF) // #EAF1FF
    }

    var minorQuality: Color {
        isDark
            ? Self.rgb(0x4F, 0x36, 0x68) // #4F3668, dark tint of #F1E8FA
            : Self.rgb(0xF1, 0xE8, 0xFA) // #F1E8FA
    }

    var augmented: Color {
        isDark
            ? Self.rgb(0x33, 0x5B, 0x49) // #335B49, dark tint of #E5F6EE
            : Self.rgb(0xE5, 0xF6, 0xEE) // #E5F6EE
    }

    var doublyAugmented: Color {
        isDark
            ? Self.rgb(0x33, 0x71, 0x5A) // #33715A, dark tint of #D6F1E7
            : Self.rgb(0xD6, 0xF1, 0xE7) // #D6F1E7
    }

    var diminished: Color {
        isDark
            ? Self.rgb(0x63, 0x36, 0x39) // #633639, dark tint of #FFE9EB
            : Self.rgb(0xFF, 0xE9, 0xEB) // #FFE9EB
    }

    var doublyDiminished: Color {
        isDark
            ? Self.rgb(0x76, 0x32, 0x3A) // #76323A, dark tint of #FFDDE1
            : Self.rgb(0xFF, 0xDD, 0xE1) // #FFDDE1
    }

    private static func rgb(_ red: Int, _ green: Int, _ blue: Int) -> Color {
        Color(
            red: Double(red) / 255.0,
            green: Double(green) / 255.0,
            blue: Double(blue) / 255.0
        )
    }

    var onBlue: Color { isDark ? .white : Color(red: 0.12, green: 0.22, blue: 0.42) }
    var onPink: Color { isDark ? .white : Color(red: 0.42, green: 0.12, blue: 0.28) }
    var onGreen: Color { isDark ? .white : Color(red: 0.10, green: 0.28, blue: 0.18) }
    var onRed: Color { isDark ? .white : Color(red: 0.42, green: 0.12, blue: 0.12) }
}

#Preview {
    IntervalQualityGuideView()
}
