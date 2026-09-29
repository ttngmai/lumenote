//

import SwiftUI

/// Paged guide: how C major diatonic chords are stacked, then what each degree does.
struct DiatonicChordGuideView: View {
    @Environment(\.appPalette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var page = GuidePage.principle
    @State private var voicing: DiatonicVoicing = .triad
    @State private var revealedToneCounts = Array(repeating: 0, count: 7)
    @State private var labeledDegrees: Set<Int> = []
    @State private var selectedRoleDegree: DiatonicDegree = .i

    private let scaleNoteNames = Array(
        ScaleModel.spellings(tonic: "C", kind: .major).dropLast()
    ).map(ScaleModel.formatNoteName)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    principlePage.tag(GuidePage.principle)
                    functionPage.tag(GuidePage.function)
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

    // MARK: - Principle

    private var principlePage: some View {
        GeometryReader { geo in
            let cardWidth = geo.size.width - LumenoteSpacing.popupInset * 2
            ScrollView {
                principleCard(availableWidth: cardWidth)
                    .padding(.horizontal, LumenoteSpacing.popupInset)
                    .padding(.vertical, LumenoteSpacing.xxxl)
            }
            .scrollIndicators(.hidden)
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(sheetBackground)
        .task(id: voicing) {
            await playConstruction()
        }
    }

    private func principleCard(availableWidth: CGFloat) -> some View {
        let innerWidth = max(0, availableWidth - LumenoteSpacing.xxl * 2)
        let staffSpace = staffSpace(for: innerWidth)

        return VStack(alignment: .leading, spacing: LumenoteSpacing.section) {
            Text("스케일의 각 음을 근음으로 삼고 스케일 안에서 3도 간격으로 음을 쌓으면 다이아토닉 코드가 만들어집니다.")
                .font(LumenoteFont.callout(.medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            voicingTabs

            VStack(alignment: .leading, spacing: LumenoteSpacing.md) {
                Text("C Major")
                    .font(LumenoteFont.caption(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: LumenoteSpacing.sm) {
                    ForEach(Array(scaleNoteNames.enumerated()), id: \.offset) { index, name in
                        let shown = (revealedToneCounts.indices.contains(index) ? revealedToneCounts[index] : 0) > 0
                        Text(name)
                            .font(LumenoteFont.caption(.bold))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .opacity(shown ? 1 : 0.28)
                            .animation(.easeOut(duration: 0.22), value: shown)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("C Major 스케일, \(scaleNoteNames.joined(separator: ", "))")
            }

            ScrollView(.horizontal, showsIndicators: false) {
                DiatonicChordStaffView(
                    columns: constructionColumns,
                    highlightedDegree: nil,
                    staffSpace: staffSpace,
                    targetWidth: innerWidth,
                    lineColor: Color.primary.opacity(0.75),
                    noteColor: Color.primary,
                    highlightColor: palette.minor,
                    dimmedNoteColor: Color.primary.opacity(0.28),
                    highlightFill: palette.highlight,
                    revealedToneCounts: revealedToneCounts,
                    labeledDegreeIndexes: labeledDegrees
                )
                .padding(.vertical, LumenoteSpacing.xs)
            }
            .accessibilityHidden(true)
        }
        .padding(LumenoteSpacing.xxl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous)
                .strokeBorder(palette.divider, lineWidth: LumenoteStroke.compact)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(constructionSummary)
    }

    private var voicingTabs: some View {
        HStack(spacing: LumenoteSpacing.xs) {
            ForEach(DiatonicVoicing.allCases) { option in
                let selected = voicing == option
                Button {
                    selectVoicing(option)
                } label: {
                    Text(option.title.l10n)
                        .font(LumenoteFont.caption(.bold))
                        .foregroundStyle(selected ? palette.emphasisStroke : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, LumenoteSpacing.md)
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
        .accessibilityLabel("코드 구성")
    }

    private var constructionColumns: [DiatonicStaffColumn] {
        DiatonicChordModel.staffColumns(tonic: "C", kind: .major, voicing: voicing)
    }

    private var constructionSummary: String {
        let chords = constructionColumns
            .map { "\($0.chord.roman) \($0.chord.compactName)" }
            .joined(separator: ", ")
        return "C Major 스케일 \(scaleNoteNames.joined(separator: ", ")). \(voicing.title) \(chords)"
    }

    private func selectVoicing(_ next: DiatonicVoicing) {
        guard voicing != next else { return }
        revealedToneCounts = Array(repeating: 0, count: 7)
        labeledDegrees = []
        voicing = next
    }

    private func playConstruction() async {
        let toneTotal = voicing.letterOffsets.count
        if reduceMotion {
            revealedToneCounts = Array(repeating: toneTotal, count: 7)
            labeledDegrees = Set(0..<7)
            return
        }

        revealedToneCounts = Array(repeating: 0, count: 7)
        labeledDegrees = []

        do {
            for index in 0..<7 {
                try await Task.sleep(for: .milliseconds(150))
                withAnimation(.easeOut(duration: 0.22)) {
                    revealedToneCounts[index] = 1
                }
            }

            try await Task.sleep(for: .milliseconds(420))

            for index in 0..<7 {
                var count = 1
                while count < toneTotal {
                    count += 1
                    try await Task.sleep(for: .milliseconds(280))
                    let nextCount = count
                    withAnimation(.easeOut(duration: 0.24)) {
                        revealedToneCounts[index] = nextCount
                    }
                }
                try await Task.sleep(for: .milliseconds(90))
                withAnimation(.easeOut(duration: 0.22)) {
                    labeledDegrees.insert(index)
                }
                try await Task.sleep(for: .milliseconds(180))
            }
        } catch {
            return
        }
    }

    private func staffSpace(for availableWidth: CGFloat) -> CGFloat {
        let fitted = availableWidth / 26
        return min(13, max(8.5, fitted))
    }

    // MARK: - Function

    private var functionPage: some View {
        pageCard {
            Text("같은 키에 속한 다이아토닉 코드라도 음악에서 수행하는 역할은 서로 다릅니다.")
                .font(LumenoteFont.callout(.medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text("이러한 역할을 화성 기능(Harmonic Function)이라고 하며, 대표적으로 토닉(Tonic), 서브도미넌트(Subdominant), 도미넌트(Dominant)로 구분할 수 있습니다.")
                .font(LumenoteFont.callout(.medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            harmonicFunctionGuide

            sectionTitle("각 코드의 역할")

            HStack(spacing: LumenoteSpacing.sm) {
                ForEach(DiatonicDegree.allCases) { degree in
                    roleDegreeButton(degree)
                }
            }

            if let role = DiatonicChordModel.roles.first(where: { $0.degree == selectedRoleDegree }) {
                roleDetail(role)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("다이아토닉 코드의 기능")
    }

    private var harmonicFunctionGuide: some View {
        VStack(alignment: .leading, spacing: LumenoteSpacing.section) {
            sectionTitle("세 가지 화성 기능")

            VStack(spacing: LumenoteSpacing.md) {
                ForEach(HarmonicFunctionCard.allCases) { card in
                    harmonicFunctionCard(card)
                }
            }

            Rectangle()
                .fill(palette.divider)
                .frame(height: LumenoteStroke.hairline)

            sectionTitle("대표적인 화성 진행")

            VStack(spacing: LumenoteSpacing.sm) {
                HStack(spacing: LumenoteSpacing.sm) {
                    progressBox(.tonic, letter: "T", title: "안정")
                    progressArrow
                    progressBox(.subdominant, letter: "S", title: "전개")
                    progressArrow
                    progressBox(.dominant, letter: "D", title: "긴장")
                }

                HarmonicReturnArrow()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("T 안정에서 S 전개, D 긴장으로 진행한 뒤 다시 안정으로 돌아옵니다")

            Text("안정 → 전개 → 긴장 → 안정")
                .font(LumenoteFont.caption(.medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)

            Text("대표적인 진행을 단순화한 예시이며, 모든 곡이 이 순서를 따르는 것은 아닙니다.")
                .font(LumenoteFont.caption(.medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func harmonicFunctionCard(_ card: HarmonicFunctionCard) -> some View {
        let tint = functionTint(card.function)
        return VStack(alignment: .leading, spacing: LumenoteSpacing.sm) {
            Text(card.badge.l10n)
                .font(LumenoteFont.caption2(.bold))
                .foregroundStyle(tint)
                .padding(.horizontal, LumenoteSpacing.md)
                .padding(.vertical, LumenoteSpacing.xxs)
                .background(Capsule().fill(tint.opacity(0.16)))

            Text(card.title.l10n)
                .font(LumenoteFont.headline(.bold))
                .foregroundStyle(.primary)

            Text(card.subtitle.l10n)
                .font(LumenoteFont.caption(.medium))
                .foregroundStyle(.secondary)

            Text(card.body.l10n)
                .font(LumenoteFont.callout(.medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(LumenoteSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous)
                .fill(tint.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous)
                .strokeBorder(tint.opacity(0.55), lineWidth: LumenoteStroke.compact)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(card.badge), \(card.title), \(card.subtitle), \(card.body)")
    }

    private func progressBox(_ function: HarmonicFunction, letter: String, title: String) -> some View {
        let tint = functionTint(function)
        return VStack(spacing: LumenoteSpacing.xxs) {
            Text(letter)
                .font(LumenoteFont.rounded(size: 26, weight: .bold))
            Text(title.l10n)
                .font(LumenoteFont.caption(.bold))
        }
        .foregroundStyle(tint)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 78)
        .background(
            RoundedRectangle(cornerRadius: LumenoteRadius.popup, style: .continuous)
                .fill(functionFill(function))
        )
        .overlay(
            RoundedRectangle(cornerRadius: LumenoteRadius.popup, style: .continuous)
                .strokeBorder(tint.opacity(0.7), lineWidth: LumenoteStroke.compact)
        )
    }

    private var progressArrow: some View {
        Image(systemName: "arrow.right")
            .font(LumenoteFont.caption(.bold))
            .foregroundStyle(.secondary)
            .frame(width: 16)
            .accessibilityHidden(true)
    }

    private func roleDegreeButton(_ degree: DiatonicDegree) -> some View {
        let selected = selectedRoleDegree == degree

        return Button {
            selectedRoleDegree = degree
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
                Text(role.functionLabel.l10n)
                    .font(LumenoteFont.caption(.bold))
                    .foregroundStyle(functionTint(role.function))
                Spacer(minLength: 0)
            }

            Text(role.title.l10n)
                .font(LumenoteFont.callout(.bold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(role.body.l10n)
                .font(LumenoteFont.callout(.medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text("핵심: \(role.takeaway.l10n)")
                .font(LumenoteFont.caption(.bold))
                .foregroundStyle(functionTint(role.function))
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            L10n.s("\(role.degree.functionRoman), \(role.functionLabel.l10n), \(role.title.l10n), \(role.body.l10n), 핵심 \(role.takeaway.l10n)")
        )
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
                enabled: page != .principle
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
                enabled: page != .function
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

    private func sectionTitle(_ title: String) -> some View {
        Text(title.l10n)
            .font(LumenoteFont.body(.bold))
            .foregroundStyle(.primary)
            .accessibilityAddTraits(.isHeader)
    }

    private func functionTint(_ function: HarmonicFunction) -> Color {
        switch function {
        case .tonic: palette.quizCorrect
        case .subdominant: palette.emphasisStroke
        case .dominant: palette.major
        }
    }

    private func functionFill(_ function: HarmonicFunction) -> Color {
        switch function {
        case .tonic: palette.quizCorrectBackground
        case .subdominant: palette.highlightSoft
        case .dominant: palette.quizIncorrectBackground
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
}

private enum HarmonicFunctionCard: String, CaseIterable, Identifiable {
    case tonic
    case subdominant
    case dominant

    var id: String { rawValue }

    var function: HarmonicFunction {
        switch self {
        case .tonic: .tonic
        case .subdominant: .subdominant
        case .dominant: .dominant
        }
    }

    var badge: String {
        switch self {
        case .tonic: "Tonic · T"
        case .subdominant: "Subdominant · S"
        case .dominant: "Dominant · D"
        }
    }

    var title: String {
        switch self {
        case .tonic: "토닉".l10n
        case .subdominant: "서브도미넌트".l10n
        case .dominant: "도미넌트".l10n
        }
    }

    var subtitle: String {
        switch self {
        case .tonic: "안정과 휴식".l10n
        case .subdominant: "이동과 전개".l10n
        case .dominant: "긴장과 해결".l10n
        }
    }

    var body: String {
        switch self {
        case .tonic: "곡의 중심이 되는 기능으로, 안정감과 마무리되는 느낌을 줍니다.".l10n
        case .subdominant: "토닉의 안정된 상태에서 벗어나 음악을 전개하며, 다른 기능으로 연결하는 역할을 합니다.".l10n
        case .dominant: "긴장감을 형성하며, 토닉으로 진행해 해결되려는 성향이 강합니다.".l10n
        }
    }
}

private struct HarmonicReturnArrow: View {
    var body: some View {
        Canvas { context, size in
            let arrowWidth: CGFloat = 16
            let gap = LumenoteSpacing.sm
            let boxWidth = max(0, (size.width - arrowWidth * 2 - gap * 4) / 3)
            let leftX = boxWidth / 2
            let rightX = size.width - boxWidth / 2
            let bottom = size.height - 1
            let headTip = CGPoint(x: leftX, y: 1)
            let headBase = headTip.y + 7

            var path = Path()
            path.move(to: CGPoint(x: rightX, y: 0))
            path.addLine(to: CGPoint(x: rightX, y: bottom))
            path.addLine(to: CGPoint(x: leftX, y: bottom))
            path.addLine(to: headTip)

            let stroke = Color.primary.opacity(0.55)
            context.stroke(
                path,
                with: .color(stroke),
                style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round)
            )

            var head = Path()
            head.move(to: CGPoint(x: leftX - 5, y: headBase))
            head.addLine(to: headTip)
            head.addLine(to: CGPoint(x: leftX + 5, y: headBase))
            context.stroke(
                head,
                with: .color(stroke),
                style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(height: 30)
        .accessibilityHidden(true)
    }
}

private enum GuidePage: Int, CaseIterable, Hashable {
    case principle
    case function

    var title: String {
        switch self {
        case .principle: "만들어지는 원리".l10n
        case .function: "다이아토닉 코드의 기능".l10n
        }
    }
}

#Preview {
    DiatonicChordGuideView()
}
