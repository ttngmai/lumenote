//

import SwiftUI

/// Paged guide: how a scale is built, its formula and types, then relative and parallel keys.
struct ScaleGuideView: View {
    @Environment(\.appPalette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var page = GuidePage.understanding

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    understandingPage.tag(GuidePage.understanding)
                    formulasPage.tag(GuidePage.formulas)
                    relationshipsPage.tag(GuidePage.relationships)
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

    private var understandingPage: some View {
        pageCard {
            sectionTitle("스케일이란?")
            bodyText("스케일(Scale)은 음을 일정한 규칙에 따라 배열한 것입니다. 각 음 사이의 간격에 따라 다양한 스케일이 만들어지며, 멜로디와 화성을 구성하는 기초가 됩니다.")

            sectionTitle("스케일의 구성 원리")
            bodyText("스케일은 음 사이의 간격을 일정한 규칙에 따라 배열하여 만들어집니다. 이 간격을 온음과 반음으로 나타내면 스케일의 구조를 쉽게 이해할 수 있습니다.")

            relationCard {
                Text("Major 스케일의 간격 패턴".l10n)
                    .font(LumenoteFont.subheadline(.bold))
                    .foregroundStyle(.primary)

                ScaleStepPatternRow(
                    intervals: ScaleKind.major.stepIntervals,
                    color: palette.minor
                )
            }

            bodyText("이 패턴을 어떤 시작음에 적용하더라도 Major 스케일을 만들 수 있습니다.")
        }
    }

    private var formulasPage: some View {
        pageCard {
            sectionTitle("도수와 스케일 공식")
            bodyText("스케일의 각 음은 시작음을 기준으로 도수(Degree)를 가집니다. 스케일 공식은 메이저 스케일을 기준으로 각 음의 위치를 나타낸 것입니다.")

            degreeExampleCard(
                title: "C Major",
                names: Array(majorNoteNames.dropLast()),
                degrees: Array(ScaleKind.major.degreeLabels.dropLast()),
                caption: "각 음의 아래에 해당하는 도수를 표시했습니다."
            )

            bodyText("공식에서 ♭은 메이저 스케일의 해당 도수보다 반음 낮은 음을, ♯은 반음 높은 음을 나타냅니다.")

            degreeExampleCard(
                title: "예시) C Natural Minor",
                names: parallelMinorNames,
                degrees: Array(ScaleKind.naturalMinor.degreeLabels.dropLast()),
                caption: "C Major와 비교하면 3도, 6도, 7도가 반음 낮아집니다."
            )

            sectionTitle("스케일의 종류")
            bodyText("스케일은 구성음의 개수와 음 사이의 간격에 따라 다양한 종류로 나뉩니다.")

            formulaGroup(
                title: "Heptatonic 스케일",
                detail: "일곱 개의 서로 다른 음으로 구성된 스케일입니다.",
                kinds: ScaleCategory.basic.kinds
            )
            formulaGroup(
                title: "Pentatonic 스케일",
                detail: "다섯 개의 서로 다른 음으로 구성된 스케일입니다.",
                kinds: ScaleCategory.pentatonic.kinds
            )
            formulaGroup(
                title: "Blues 스케일",
                detail: "Pentatonic 스케일에 특징적인 음을 추가하여 만들어집니다.",
                kinds: ScaleCategory.blues.kinds
            )

            noteCard("Major Blues의 ♭3과 Minor Blues의 ♭5는 블루스 특유의 표현을 만드는 데 사용됩니다.")
        }
    }

    private var relationshipsPage: some View {
        pageCard {
            sectionTitle("관계장조·관계단조")
            bodyText("관계장조와 관계단조는 동일한 조표를 사용하는 장조와 단조의 관계입니다. Natural Minor 스케일을 기준으로 비교하면 구성음은 같지만 으뜸음이 서로 다릅니다.")

            relationCard {
                Text("C Major와 A Natural Minor".l10n)
                    .font(LumenoteFont.subheadline(.bold))
                    .foregroundStyle(.primary)
                spelledRow(
                    title: "C Major",
                    names: Array(majorNoteNames.dropLast()),
                    highlighted: [0]
                )
                spelledRow(
                    title: "A Natural Minor",
                    names: relativeMinorNames,
                    highlighted: [0]
                )
                exampleCaption("동일한 구성음을 사용하지만 시작하는 음이 다릅니다.")
            }

            bodyText("Major 스케일의 6도 음을 으뜸음으로 하는 Natural Minor 스케일이 관계단조이며, Natural Minor 스케일의 ♭3도 음을 으뜸음으로 하는 Major 스케일이 관계장조입니다.")

            sectionTitle("병행조")
            bodyText("병행조는 동일한 으뜸음을 사용하지만 조성이 서로 다른 장조와 단조의 관계입니다.")

            relationCard {
                Text("C Major와 C Natural Minor".l10n)
                    .font(LumenoteFont.subheadline(.bold))
                    .foregroundStyle(.primary)
                parallelComparison
                exampleCaption("Natural Minor 스케일을 기준으로 비교하면 3도, 6도, 7도가 서로 다릅니다.")
            }

            sectionTitle("핵심 정리")
            definitionRow(
                title: "관계장조·관계단조",
                detail: "조표가 같고 으뜸음이 다릅니다."
            )
            definitionRow(
                title: "병행조",
                detail: "으뜸음이 같고 조표가 다릅니다."
            )

            NavigationLink {
                CircleOfFifthsView()
            } label: {
                HStack(spacing: LumenoteSpacing.md) {
                    Image(systemName: "circle.circle")
                        .font(LumenoteFont.callout(.bold))
                        .foregroundStyle(palette.minor)
                    VStack(alignment: .leading, spacing: LumenoteSpacing.xxs) {
                        Text("5도권에서 보기".l10n)
                            .font(LumenoteFont.callout(.semibold))
                            .foregroundStyle(.primary)
                        Text("같은 조표를 사용하는 장조와 관계단조는 5도권에서 같은 칸에 표시됩니다.".l10n)
                            .font(LumenoteFont.caption(.medium))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right")
                        .font(LumenoteFont.caption(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(LumenoteSpacing.xl)
                .background(
                    RoundedRectangle(cornerRadius: LumenoteRadius.softRow, style: .continuous)
                        .fill(palette.highlightSoft)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: LumenoteRadius.softRow, style: .continuous)
                        .strokeBorder(palette.divider, lineWidth: LumenoteStroke.compact)
                )
            }
            .buttonStyle(.plain)
            .accessibilityHint("5도권 화면으로 이동합니다")
        }
    }

    // MARK: - Chrome

    private func pageCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LumenoteSpacing.section) {
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
            .padding(.horizontal, LumenoteSpacing.popupInset)
            .padding(.vertical, LumenoteSpacing.xxxl)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(sheetBackground)
    }

    private var pageControls: some View {
        HStack {
            pageButton(
                systemName: "chevron.left",
                label: "이전 페이지",
                enabled: page != .understanding
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
                enabled: page != .relationships
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

    private var sheetBackground: some View {
        LinearGradient(
            colors: palette.backgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Blocks

    private func sectionTitle(_ title: String) -> some View {
        Text(title.l10n)
            .font(LumenoteFont.headline(.bold))
            .foregroundStyle(.primary)
            .accessibilityAddTraits(.isHeader)
    }

    private func bodyText(_ text: String) -> some View {
        Text(text.l10n)
            .font(LumenoteFont.callout(.medium))
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func definitionRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: LumenoteSpacing.xxs) {
            Text(title.l10n)
                .font(LumenoteFont.subheadline(.bold))
                .foregroundStyle(.primary)
            Text(detail.l10n)
                .font(LumenoteFont.callout(.medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func relationCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: LumenoteSpacing.md) {
            content()
        }
        .padding(LumenoteSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lumenoteCard()
    }

    private func exampleCaption(_ text: String) -> some View {
        Text(text.l10n)
            .font(LumenoteFont.caption(.medium))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func degreeExampleCard(
        title: String,
        names: [String],
        degrees: [String],
        caption: String
    ) -> some View {
        VStack(alignment: .leading, spacing: LumenoteSpacing.md) {
            Text(title.l10n)
                .font(LumenoteFont.caption(.semibold))
                .foregroundStyle(.secondary)
            degreeBoard(names: names, degrees: degrees)
            exampleCaption(caption)
        }
        .padding(LumenoteSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lumenoteCard()
    }

    private func degreeBoard(names: [String], degrees: [String]) -> some View {
        HStack(spacing: LumenoteSpacing.xs) {
            ForEach(names.indices, id: \.self) { index in
                VStack(spacing: LumenoteSpacing.xxs) {
                    Text(names[index])
                        .font(LumenoteFont.callout(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(degrees[index])
                        .font(LumenoteFont.caption(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            zip(names, degrees).map { "\($0) \($1)" }.joined(separator: ", ")
        )
    }

    private func formulaGroup(title: String, detail: String, kinds: [ScaleKind]) -> some View {
        VStack(alignment: .leading, spacing: LumenoteSpacing.md) {
            Text(title.l10n)
                .font(LumenoteFont.subheadline(.bold))
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)
            Text(detail.l10n)
                .font(LumenoteFont.callout(.medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 0) {
                HStack(spacing: LumenoteSpacing.md) {
                    Text("종류".l10n)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("공식".l10n)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(LumenoteFont.caption2(.bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, LumenoteSpacing.xl)
                .padding(.vertical, LumenoteSpacing.lg)
                .background(palette.highlightSoft)
                .accessibilityHidden(true)

                ForEach(Array(kinds.enumerated()), id: \.element.id) { index, kind in
                    if index > 0 {
                        Rectangle()
                            .fill(palette.divider)
                            .frame(height: LumenoteStroke.hairline)
                    }
                    formulaRow(kind)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: LumenoteRadius.softRow, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: LumenoteRadius.softRow, style: .continuous)
                    .strokeBorder(palette.divider, lineWidth: LumenoteStroke.compact)
            )
        }
        .accessibilityElement(children: .contain)
    }

    private func formulaRow(_ kind: ScaleKind) -> some View {
        let title = kindTitle(kind)
        let tones = formula(for: kind)
        return HStack(alignment: .firstTextBaseline, spacing: LumenoteSpacing.md) {
            Text(title)
                .font(LumenoteFont.callout(.bold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(tones)
                .font(LumenoteFont.caption(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, LumenoteSpacing.xl)
        .padding(.vertical, LumenoteSpacing.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(tones)")
    }

    private func spelledRow(title: String, names: [String], highlighted: Set<Int>) -> some View {
        VStack(alignment: .leading, spacing: LumenoteSpacing.sm) {
            Text(title)
                .font(LumenoteFont.caption(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: LumenoteSpacing.xs) {
                ForEach(names.indices, id: \.self) { index in
                    let marked = highlighted.contains(index)
                    Text(names[index])
                        .font(LumenoteFont.caption(.bold))
                        .foregroundStyle(marked ? palette.emphasisStroke : .primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, LumenoteSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: LumenoteRadius.chip, style: .continuous)
                                .fill(marked ? palette.highlight : Color.clear)
                        )
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(names.joined(separator: ", "))")
    }

    private var parallelComparison: some View {
        let degrees = Array(ScaleKind.major.degreeLabels.dropLast())
        let major = Array(majorNoteNames.dropLast())
        let minor = parallelMinorNames
        let changed = Set(major.indices.filter { major[$0] != minor[$0] })

        return VStack(spacing: LumenoteSpacing.sm) {
            comparisonRow(label: "도수".l10n, values: degrees, changed: [])
            comparisonRow(label: "Major", values: major, changed: changed)
            comparisonRow(label: "Minor", values: minor, changed: changed)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(parallelAccessibilityLabel(major: major, minor: minor, changed: changed))
    }

    private func comparisonRow(label: String, values: [String], changed: Set<Int>) -> some View {
        HStack(spacing: LumenoteSpacing.xs) {
            Text(label)
                .font(LumenoteFont.caption2(.bold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 56, alignment: .leading)

            ForEach(values.indices, id: \.self) { index in
                let marked = changed.contains(index)
                Text(values[index])
                    .font(LumenoteFont.caption(.bold))
                    .foregroundStyle(marked ? palette.emphasisStroke : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, LumenoteSpacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: LumenoteRadius.chip, style: .continuous)
                            .fill(marked ? palette.highlight : Color.clear)
                    )
            }
        }
    }

    private func noteCard(_ text: String) -> some View {
        Text(text.l10n)
            .font(LumenoteFont.caption(.medium))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(LumenoteSpacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: LumenoteRadius.softRow, style: .continuous)
                    .fill(palette.highlightSoft)
            )
    }

    // MARK: - Data

    @MainActor
    private var majorNoteNames: [String] {
        ScaleModel.spellings(tonic: "C", kind: .major).map(ScaleModel.formatNoteName)
    }

    @MainActor
    private var relativeMinorNames: [String] {
        Array(ScaleModel.spellings(tonic: "A", kind: .naturalMinor).dropLast())
            .map(ScaleModel.formatNoteName)
    }

    @MainActor
    private var parallelMinorNames: [String] {
        Array(ScaleModel.spellings(tonic: "C", kind: .naturalMinor).dropLast())
            .map(ScaleModel.formatNoteName)
    }

    private func formula(for kind: ScaleKind) -> String {
        kind.degreeLabels.dropLast().joined(separator: " ")
    }

    private func kindTitle(_ kind: ScaleKind) -> String {
        if kind == .melodicMinor {
            return "\(kind.englishTitle) (\("상행".l10n))"
        }
        return kind.englishTitle
    }

    private func parallelAccessibilityLabel(major: [String], minor: [String], changed: Set<Int>) -> String {
        let degrees = changed.sorted().map { String($0 + 1) }.joined(separator: ", ")
        return "C Major \(major.joined(separator: " ")). C Natural Minor \(minor.joined(separator: " ")). \("다른 도수".l10n) \(degrees)"
    }
}

private enum GuidePage: Int, CaseIterable, Hashable {
    case understanding
    case formulas
    case relationships

    var title: String {
        switch self {
        case .understanding: "스케일의 이해".l10n
        case .formulas: "스케일의 종류와 공식".l10n
        case .relationships: "스케일 사이의 관계".l10n
        }
    }
}

#Preview {
    ScaleGuideView()
}
