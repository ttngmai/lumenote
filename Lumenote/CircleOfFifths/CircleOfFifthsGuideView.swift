//

import SwiftUI

/// Paged guide for the circle of fifths: layout, direction, relative keys, and how to read it.
struct CircleOfFifthsGuideView: View {
    @Environment(\.appPalette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var page = GuidePage.overview
    @State private var illustration = CircleOfFifthsModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    overviewPage.tag(GuidePage.overview)
                    directionPage.tag(GuidePage.direction)
                    relativePage.tag(GuidePage.relative)
                    sharedPage.tag(GuidePage.shared)
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

    private var overviewPage: some View {
        pageCard {
            Text("5도권은 장조와 관계단조, 조표를 완전5도 관계에 따라 원형으로 배치한 도표입니다. 한 칸씩 이동하며 조표의 변화와 조성 간의 관계를 확인할 수 있습니다.")
                .font(LumenoteFont.callout(.medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            CircleOfFifthsRingView(
                model: illustration,
                isInteractive: false,
                signatureTint: palette.quizCorrect,
                noteTint: palette.major,
                relativeTint: palette.minor
            )
            .frame(maxWidth: .infinity)

            overviewSection(title: "5도권의 구성") {
                overviewItem(
                    title: "바깥쪽 고리 : 조표",
                    swatch: palette.quizCorrect,
                    paragraphs: [
                        "각 조성에서 사용하는 샵(♯) 또는 플랫(♭)의 개수를 나타냅니다.",
                    ]
                )
                overviewItem(
                    title: "중간 고리 : 장조(Major)",
                    swatch: palette.major,
                    paragraphs: [
                        "각 장조의 으뜸음을 나타냅니다.",
                    ]
                )
                overviewItem(
                    title: "안쪽 고리 : 관계단조(Relative Minor)",
                    swatch: palette.minor,
                    paragraphs: [
                        "각 장조와 동일한 조표를 사용하는 관계단조를 나타냅니다. 표시된 음이름은 해당 단조의 으뜸음입니다.",
                    ]
                )
            }

            overviewSection(title: "5도권의 이동 방향") {
                overviewItem(
                    title: "시계 방향 : 완전5도 상행",
                    paragraphs: [
                        "시계 방향으로 한 칸 이동하면 으뜸음이 완전5도 높아집니다.",
                        "C Major를 기준으로 이동할 때마다 샵(♯)이 하나씩 추가됩니다.",
                    ]
                )
                overviewItem(
                    title: "반시계 방향 : 완전4도 상행",
                    paragraphs: [
                        "반시계 방향으로 한 칸 이동하면 으뜸음이 완전4도 높아집니다.",
                        "C Major를 기준으로 이동할 때마다 플랫(♭)이 하나씩 추가됩니다.",
                    ]
                )
            }
        }
    }

    private var directionPage: some View {
        pageCard {
            VStack(alignment: .leading, spacing: LumenoteSpacing.md) {
                Text("5도권은 시계 방향으로 이동하면 완전5도, 반시계 방향으로 이동하면 완전4도씩 으뜸음이 바뀝니다.")
                Text("C Major를 기준으로 각 방향으로 이동하며 조표가 어떻게 변하는지 살펴보세요.")
            }
            .font(LumenoteFont.callout(.medium))
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)

            RotationStepCard()

            overviewSection(title: "조표 붙는 순서") {
                VStack(alignment: .leading, spacing: LumenoteSpacing.md) {
                    Text("시계 방향으로 한 칸씩 이동하면 샵(♯)이 F, C, G, D, A, E, B 순서로 하나씩 추가됩니다.")
                    Text("반시계 방향으로 한 칸씩 이동하면 플랫(♭)이 B, E, A, D, G, C, F 순서로 하나씩 추가됩니다.")
                }
                .font(LumenoteFont.callout(.medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var relativePage: some View {
        pageCard {
            Text("5도권에서 같은 칸에 배치된 장조와 단조는 서로 관계조입니다.")
                .font(LumenoteFont.callout(.medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            overviewSection(title: "관계조의 특징") {
                Text("같은 칸에 위치한 장조와 관계단조는 조표가 같으며, 으뜸음은 단3도(3반음) 차이가 납니다.")
                    .font(LumenoteFont.callout(.medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            CircleReferenceSlice(
                rotation: 0,
                noteTint: palette.major,
                relativeTint: palette.minor
            )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("C 장조와 관계단조 A 단조가 같은 칸에 있습니다.")

            overviewSection(title: "관계조 예시") {
                VStack(alignment: .leading, spacing: LumenoteSpacing.lg) {
                    relationRow(major: "C 장조", minor: "A 단조", signature: "조표 없음")
                    relationRow(major: "G 장조", minor: "E 단조", signature: "♯ 1개 (F♯)")
                    relationRow(major: "F 장조", minor: "D 단조", signature: "♭ 1개 (B♭)")
                }
            }
        }
    }

    private var sharedPage: some View {
        pageCard {
            VStack(alignment: .leading, spacing: LumenoteSpacing.md) {
                Text("이웃한 장조끼리 또는 단조끼리는 단 하나의 음만 다릅니다.")
                Text("공통으로 사용하는 음이 많아 전조하거나 코드를 연결할 때 활용할 수 있습니다.")
            }
            .font(LumenoteFont.callout(.medium))
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)

            CircleReferenceSlice(rotation: 0)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("기준음 C와 이웃한 F, G가 보입니다.")

            VStack(spacing: LumenoteSpacing.md) {
                sharedKeyCard(
                    title: "F 장조",
                    spellings: ["F", "G", "A", "Bb", "C", "D", "E"],
                    changed: "Bb",
                    footnote: "C와 6개 음을 공유",
                    titleColor: .primary,
                    borderColor: .secondary
                )
                sharedKeyCard(
                    title: "C 장조",
                    spellings: ["C", "D", "E", "F", "G", "A", "B"],
                    changed: nil,
                    footnote: "기준 조성",
                    titleColor: palette.minor,
                    borderColor: palette.minor
                )
                sharedKeyCard(
                    title: "G 장조",
                    spellings: ["G", "A", "B", "C", "D", "E", "F#"],
                    changed: "F#",
                    footnote: "C와 6개 음을 공유",
                    titleColor: .primary,
                    borderColor: .secondary
                )
            }
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(sheetBackground)
    }

    private var pageControls: some View {
        HStack {
            pageButton(
                systemName: "chevron.left",
                label: "이전 페이지",
                enabled: page != .overview
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
                enabled: page != .shared
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

    private func relationRow(major: String, minor: String, signature: String) -> some View {
        VStack(alignment: .leading, spacing: LumenoteSpacing.xxs) {
            HStack(spacing: 0) {
                Text(major)
                    .font(LumenoteFont.subheadline(.bold))
                    .foregroundStyle(palette.major)
                Text(", ")
                    .font(LumenoteFont.subheadline(.bold))
                    .foregroundStyle(.primary)
                Text(minor)
                    .font(LumenoteFont.subheadline(.bold))
                    .foregroundStyle(palette.minor)
            }
            Text(signature)
                .font(LumenoteFont.caption(.medium))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func sharedKeyCard(
        title: String,
        spellings: [String],
        changed: String?,
        footnote: String,
        titleColor: Color,
        borderColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: LumenoteSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(LumenoteFont.subheadline(.bold))
                    .foregroundStyle(titleColor)
                Spacer(minLength: LumenoteSpacing.sm)
                Text(footnote)
                    .font(LumenoteFont.caption2(.medium))
                    .foregroundStyle(.secondary)
            }
            spellingRow(spellings, changed: changed)
        }
        .padding(LumenoteSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous)
                .strokeBorder(borderColor, lineWidth: LumenoteStroke.compact)
        )
        .accessibilityElement(children: .combine)
    }

    private func spellingRow(_ spellings: [String], changed: String?) -> some View {
        HStack(spacing: LumenoteSpacing.xs) {
            ForEach(Array(spellings.enumerated()), id: \.offset) { _, spelling in
                let isChanged = spelling == changed
                Text(CircleOfFifthsModel.Tonic.formatNoteName(spelling))
                    .font(LumenoteFont.caption(.bold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, isChanged ? LumenoteSpacing.xs : 0)
                    .padding(.vertical, isChanged ? LumenoteSpacing.xxs : 0)
                    .background(
                        RoundedRectangle(cornerRadius: LumenoteRadius.chip, style: .continuous)
                            .fill(isChanged ? palette.highlight : Color.clear)
                    )
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func overviewSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: LumenoteSpacing.lg) {
            Text(title)
                .font(LumenoteFont.headline(.bold))
                .foregroundStyle(.primary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private func overviewItem(title: String, swatch: Color? = nil, paragraphs: [String]) -> some View {
        VStack(alignment: .leading, spacing: LumenoteSpacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: LumenoteSpacing.sm) {
                if let swatch {
                    Circle()
                        .fill(swatch)
                        .frame(width: 8, height: 8)
                        .alignmentGuide(.firstTextBaseline) { dimensions in
                            dimensions.height * 0.8
                        }
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(LumenoteFont.subheadline(.bold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(paragraphs, id: \.self) { paragraph in
                Text(paragraph)
                    .font(LumenoteFont.callout(.medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, swatch == nil ? 0 : 8 + LumenoteSpacing.sm)
            }
        }
        .accessibilityElement(children: .combine)
    }

}

// MARK: - Pages

private enum GuidePage: Int, CaseIterable, Hashable {
    case overview
    case direction
    case relative
    case shared

    var title: String {
        switch self {
        case .overview: "5도권이란?"
        case .direction: "이동 방향과 조표 변화"
        case .relative: "장조와 관계단조"
        case .shared: "이웃한 조성"
        }
    }
}

// MARK: - One-step rotation

/// Cropped circle with C raised at the top. The ring turns so the chosen neighbor becomes that reference, and the staff below gains one accidental.
private struct RotationStepCard: View {
    @Environment(\.appPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var direction: RotationStepDirection = .clockwise
    @State private var rotation: Double = 0
    @State private var step = 0
    @State private var phase: MovePhase = .ready
    @State private var moveID = 0

    private var isAnimating: Bool { phase == .moving || phase == .returning }
    private var showsReturn: Bool { phase == .arrived || phase == .returning }

    /// How many 30° steps the ring has traveled, including the step still arriving.
    private var travel: Double { min(Double(RotationStepDirection.stepCount), abs(rotation) / 30) }

    private var revealedCount: Int {
        guard travel > 0 else { return 0 }
        return min(RotationStepDirection.stepCount, Int(travel.rounded(.up)))
    }

    private var newestOpacity: Double {
        guard revealedCount > 0 else { return 0 }
        let fractional = travel - floor(travel)
        return fractional == 0 ? 1 : fractional
    }

    private var displayedStep: Int {
        min(RotationStepDirection.stepCount, Int((abs(rotation) / 30).rounded()))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LumenoteSpacing.lg) {
            directionTabs
            slice
            staff
            moveButton
        }
        .padding(LumenoteSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous)
                .strokeBorder(palette.divider, lineWidth: LumenoteStroke.compact)
        )
    }

    private var directionTabs: some View {
        HStack(spacing: LumenoteSpacing.sm) {
            ForEach(RotationStepDirection.allCases) { item in
                let isSelected = item == direction
                Button {
                    guard direction != item, !isAnimating else { return }
                    var reset = Transaction()
                    reset.disablesAnimations = true
                    withTransaction(reset) {
                        rotation = 0
                        step = 0
                    }
                    moveID += 1
                    phase = .ready
                    direction = item
                } label: {
                    Text(item.title)
                        .font(LumenoteFont.caption(.bold))
                        .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, LumenoteSpacing.lg)
                        .background(
                            Capsule(style: .continuous)
                                .fill(isSelected ? palette.highlight : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .disabled(isAnimating)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(LumenoteSpacing.xs)
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(palette.divider, lineWidth: LumenoteStroke.compact)
        )
    }

    private var slice: some View {
        CircleReferenceSlice(rotation: rotation)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(circleAccessibilityLabel)
    }

    private var staff: some View {
        VStack(spacing: LumenoteSpacing.md) {
            KeySignatureStaffView(
                accidentals: revealedCount == 0 ? [] : direction.accidentals,
                staffSpace: 16,
                lineColor: Color.primary.opacity(0.85),
                newestOrder: revealedCount > 0 ? revealedCount - 1 : nil,
                newestOpacity: newestOpacity,
                newestColor: palette.minor
            )
            .frame(maxWidth: .infinity)

            Text(keyTitle)
                .font(LumenoteFont.callout(.bold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, LumenoteSpacing.section)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(staffAccessibilityLabel)
    }

    private var keyTitle: String {
        "\(direction.tonicName(at: revealedCount)) Major"
    }

    private var moveButton: some View {
        Button(action: showsReturn ? returnHome : moveForward) {
            Text(showsReturn ? "원위치" : "이동하기")
                .font(LumenoteFont.body(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, LumenoteSpacing.lg)
                .background(Capsule(style: .continuous).fill(palette.fretboardQuizRoot))
        }
        .buttonStyle(.plain)
        .disabled(isAnimating)
        .opacity(isAnimating ? 0.45 : 1)
        .accessibilityHint(showsReturn ? "기준음을 C로 되돌립니다" : "선택한 방향으로 한 칸 이동합니다")
    }

    private var circleAccessibilityLabel: String {
        "기준음 \(direction.tonicName(at: displayedStep))."
    }

    private var staffAccessibilityLabel: String {
        guard revealedCount > 0 else { return "\(keyTitle). 조표 없음" }
        let newest = direction.accidentalName(at: revealedCount - 1)
        return "\(keyTitle). \(direction.signatureKind) \(revealedCount)개. 최근 조표 \(newest)."
    }

    private func moveForward() {
        guard step < RotationStepDirection.stepCount else { return }
        let id = moveID + 1
        moveID = id
        let next = step + 1
        phase = .moving
        let target = direction.rotation(forStep: next)
        guard !reduceMotion else {
            rotation = target
            step = next
            phase = next == RotationStepDirection.stepCount ? .arrived : .ready
            return
        }
        withAnimation(.easeInOut(duration: 1.05)) {
            rotation = target
        } completion: {
            guard moveID == id else { return }
            step = next
            phase = next == RotationStepDirection.stepCount ? .arrived : .ready
        }
    }

    private func returnHome() {
        let id = moveID + 1
        moveID = id
        phase = .returning
        guard !reduceMotion else {
            rotation = 0
            step = 0
            phase = .ready
            return
        }
        withAnimation(.easeInOut(duration: 1.15)) {
            rotation = 0
        } completion: {
            guard moveID == id else { return }
            step = 0
            phase = .ready
        }
    }
}

/// Cropped circle with the reference wedge raised at the top.
private struct CircleReferenceSlice: View {
    var rotation: Double
    var signatureTint: Color? = nil
    var noteTint: Color? = nil
    var relativeTint: Color? = nil

    @Environment(\.appPalette) private var palette

    var body: some View {
        Color.clear
            .aspectRatio(1.72, contentMode: .fit)
            .overlay {
                GeometryReader { geo in
                    sliceContent(in: geo.size)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: LumenoteRadius.softRow, style: .continuous))
    }

    private func sliceContent(in size: CGSize) -> some View {
        let outerRadius = size.width * 0.60
        let ringSize = outerRadius / SliceMetric.signatureOuter
        let center = CGPoint(
            x: size.width / 2,
            y: 18 + outerRadius * SliceMetric.raisedScale
        )
        let localCenter = CGPoint(x: ringSize / 2, y: ringSize / 2)

        return ZStack {
            ring(ringSize: ringSize, localCenter: localCenter)
                .rotationEffect(.degrees(rotation))
            raisedWedge(ringSize: ringSize)
            wedgeLabels(center: localCenter, side: ringSize)
                .rotationEffect(.degrees(rotation))
        }
        .frame(width: ringSize, height: ringSize)
        .position(center)
        .allowsHitTesting(false)
    }

    private func ring(ringSize: CGFloat, localCenter: CGPoint) -> some View {
        Canvas { context, _ in
            drawBands(context: &context, center: localCenter, side: ringSize)
        }
        .frame(width: ringSize, height: ringSize)
    }

    private func raisedWedge(ringSize: CGFloat) -> some View {
        RaisedTonicWedgeView(
            noteColor: .white,
            signatureTint: signatureTint,
            noteTint: noteTint,
            relativeTint: relativeTint,
            ringStroke: palette.ringStroke,
            signatureOuterRatio: SliceMetric.signatureOuter,
            outerRadiusRatio: SliceMetric.noteOuter,
            degreeOuterRatio: SliceMetric.relativeOuter,
            degreeInnerRatio: SliceMetric.relativeInner,
            raisedScale: SliceMetric.raisedScale,
            angularPadDegrees: SliceMetric.raisedPad,
            shadowOpacity: palette.raisedWedgeShadowOpacity
        )
        .frame(width: ringSize, height: ringSize)
        .allowsHitTesting(false)
    }

    private func wedgeLabels(center: CGPoint, side: CGFloat) -> some View {
        let data = RotationSliceData.standard
        return ZStack {
            ForEach(1...12, id: \.self) { position in
                let lift = referenceLift(for: position)
                let signatureLines = data.signatures[position] ?? []
                let majorLines = data.majors[position] ?? []
                let minorLines = data.minors[position] ?? []
                ringText(
                    signatureLines,
                    size: side * blended(
                        signatureLines.count > 1 ? 0.022 : 0.030,
                        signatureLines.count > 1 ? 0.026 : 0.034,
                        lift
                    ),
                    weight: .bold,
                    opacity: 0.85,
                    at: point(
                        center,
                        radius: liftedRadius(side * (SliceMetric.signatureOuter + SliceMetric.noteOuter) / 2, lift: lift),
                        position: position
                    ),
                    lifted: lift > 0.5
                )
                ringText(
                    majorLines,
                    size: side * blended(
                        majorLines.count > 1 ? 0.034 : 0.048,
                        majorLines.count > 1 ? 0.040 : 0.055,
                        lift
                    ),
                    weight: .heavy,
                    opacity: 1,
                    at: point(
                        center,
                        radius: liftedRadius(side * (SliceMetric.noteOuter + SliceMetric.relativeOuter) / 2, lift: lift),
                        position: position
                    ),
                    lifted: lift > 0.5
                )
                ringText(
                    minorLines,
                    size: side * blended(
                        minorLines.count > 1 ? 0.021 : 0.028,
                        minorLines.count > 1 ? 0.024 : 0.032,
                        lift
                    ),
                    weight: .bold,
                    opacity: 1,
                    at: point(
                        center,
                        radius: liftedRadius(side * (SliceMetric.relativeOuter + SliceMetric.relativeInner) / 2, lift: lift),
                        position: position
                    ),
                    lifted: lift > 0.5
                )
            }
        }
        .allowsHitTesting(false)
    }

    /// 1 when this wedge sits in the raised reference slot, 0 once it is a full step away.
    private func referenceLift(for position: Int) -> CGFloat {
        let base = -90.0 + Double(position % 12) * 30.0
        var delta = base + rotation + 90
        while delta > 180 { delta -= 360 }
        while delta < -180 { delta += 360 }
        return 1 - min(abs(delta) / 30, 1)
    }

    private func liftedRadius(_ radius: CGFloat, lift: CGFloat) -> CGFloat {
        radius * (1 + (SliceMetric.raisedScale - 1) * lift)
    }

    private func blended(_ resting: CGFloat, _ raised: CGFloat, _ lift: CGFloat) -> CGFloat {
        resting + (raised - resting) * lift
    }

    private func ringText(
        _ lines: [String],
        size: CGFloat,
        weight: Font.Weight,
        opacity: Double,
        at center: CGPoint,
        lifted: Bool
    ) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .multilineTextAlignment(.center)
        .font(LumenoteFont.rounded(size: size, weight: weight))
        .foregroundStyle(Color(white: 0.18).opacity(opacity))
        .rotationEffect(.degrees(-rotation))
        .position(center)
        .zIndex(lifted ? 1 : 0)
    }

    private func drawBands(context: inout GraphicsContext, center: CGPoint, side: CGFloat) {
        for position in 1...12 {
            fillWedge(
                context: &context,
                center: center,
                side: side,
                position: position,
                inner: SliceMetric.noteOuter,
                outer: SliceMetric.signatureOuter,
                tint: signatureTint
            )
            fillWedge(
                context: &context,
                center: center,
                side: side,
                position: position,
                inner: SliceMetric.relativeOuter,
                outer: SliceMetric.noteOuter,
                tint: noteTint
            )
            fillWedge(
                context: &context,
                center: center,
                side: side,
                position: position,
                inner: SliceMetric.relativeInner,
                outer: SliceMetric.relativeOuter,
                tint: relativeTint
            )
        }

        var spokes = Path()
        for index in 0..<12 {
            let angle = -105.0 + Double(index) * 30.0
            spokes.move(to: point(center, radius: side * SliceMetric.relativeInner, angle: angle))
            spokes.addLine(to: point(center, radius: side * SliceMetric.signatureOuter, angle: angle))
        }
        context.stroke(spokes, with: .color(palette.ringStroke.opacity(0.45)), lineWidth: max(0.8, side * 0.003))

        var rings = Path()
        for ratio in [SliceMetric.signatureOuter, SliceMetric.noteOuter, SliceMetric.relativeOuter, SliceMetric.relativeInner] {
            let radius = side * ratio
            rings.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        }
        context.stroke(rings, with: .color(palette.ringStroke.opacity(0.8)), lineWidth: max(1, side * 0.0035))
    }

    private func fillWedge(
        context: inout GraphicsContext,
        center: CGPoint,
        side: CGFloat,
        position: Int,
        inner: CGFloat,
        outer: CGFloat,
        tint: Color?
    ) {
        let mid = -90.0 + Double(position % 12) * 30.0
        drawSector(
            context: &context,
            center: center,
            inner: side * inner,
            outer: side * outer,
            midAngle: mid,
            halfWidth: 15,
            color: .white
        )
        if let tint {
            drawSector(
                context: &context,
                center: center,
                inner: side * inner,
                outer: side * outer,
                midAngle: mid,
                halfWidth: 15,
                color: tint.opacity(SliceMetric.wash)
            )
        }
    }

    private func drawSector(
        context: inout GraphicsContext,
        center: CGPoint,
        inner: CGFloat,
        outer: CGFloat,
        midAngle: Double,
        halfWidth: Double,
        color: Color
    ) {
        var path = Path()
        path.addArc(
            center: center,
            radius: outer,
            startAngle: .degrees(midAngle - halfWidth),
            endAngle: .degrees(midAngle + halfWidth),
            clockwise: false
        )
        path.addArc(
            center: center,
            radius: inner,
            startAngle: .degrees(midAngle + halfWidth),
            endAngle: .degrees(midAngle - halfWidth),
            clockwise: true
        )
        path.closeSubpath()
        context.fill(path, with: .color(color))
    }

    private func point(_ center: CGPoint, radius: CGFloat, position: Int) -> CGPoint {
        point(center, radius: radius, angle: -90.0 + Double(position % 12) * 30.0)
    }

    private func point(_ center: CGPoint, radius: CGFloat, angle: Double) -> CGPoint {
        let radians = angle * .pi / 180
        return CGPoint(x: center.x + cos(radians) * radius, y: center.y + sin(radians) * radius)
    }
}

private enum MovePhase {
    case ready
    case moving
    case arrived
    case returning
}

private enum RotationStepDirection: String, CaseIterable, Identifiable {
    case clockwise
    case counterclockwise

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clockwise: "시계 방향"
        case .counterclockwise: "반시계 방향"
        }
    }

    static let stepCount = 7

    /// Degrees that bring the next key into the fixed top slot. Negative is the sharp side.
    var degreesPerStep: Double {
        switch self {
        case .clockwise: -30
        case .counterclockwise: 30
        }
    }

    func rotation(forStep step: Int) -> Double {
        Double(step) * degreesPerStep
    }

    func tonicName(at step: Int) -> String {
        let names: [String]
        switch self {
        case .clockwise:
            names = ["C", "G", "D", "A", "E", "B", "F♯", "C♯"]
        case .counterclockwise:
            names = ["C", "F", "B♭", "E♭", "A♭", "D♭", "G♭", "C♭"]
        }
        return names[min(max(step, 0), names.count - 1)]
    }

    func accidentalName(at order: Int) -> String {
        let names: [String]
        switch self {
        case .clockwise:
            names = ["F♯", "C♯", "G♯", "D♯", "A♯", "E♯", "B♯"]
        case .counterclockwise:
            names = ["B♭", "E♭", "A♭", "D♭", "G♭", "C♭", "F♭"]
        }
        guard names.indices.contains(order) else { return "" }
        return names[order]
    }

    var signatureKind: String {
        switch self {
        case .clockwise: "샵"
        case .counterclockwise: "플랫"
        }
    }

    var accidentals: [CircleOfFifthsModel.KeySignatureAccidental] {
        switch self {
        case .clockwise: RotationSliceData.standard.sharps
        case .counterclockwise: RotationSliceData.standard.flats
        }
    }
}

private enum SliceMetric {
    static let signatureOuter: CGFloat = 0.47
    static let noteOuter: CGFloat = 0.40
    static let relativeOuter: CGFloat = 0.255
    static let relativeInner: CGFloat = 0.16
    static let raisedScale: CGFloat = 1.05
    static let raisedPad: Double = 2.5
    static let wash = 0.34
}

private struct RotationSliceData {
    let signatures: [Int: [String]]
    let majors: [Int: [String]]
    let minors: [Int: [String]]
    let sharps: [CircleOfFifthsModel.KeySignatureAccidental]
    let flats: [CircleOfFifthsModel.KeySignatureAccidental]

    static let standard: RotationSliceData = {
        let model = CircleOfFifthsModel()
        var signatures: [Int: [String]] = [:]
        var majors: [Int: [String]] = [:]
        var minors: [Int: [String]] = [:]
        for position in 1...12 {
            signatures[position] = model.displayedSignatureCountLabels[position] ?? []
            majors[position] = (model.displayedOuterSpellings[position] ?? []).map {
                CircleOfFifthsModel.Tonic.formatNoteName($0)
            }
            minors[position] = (model.displayedRelativeMinorSpellings[position] ?? []).map {
                CircleOfFifthsModel.Tonic.formatNoteName($0) + "m"
            }
        }
        let sharpModel = CircleOfFifthsModel()
        sharpModel.selectedTonic = .cSharp
        let flatModel = CircleOfFifthsModel()
        flatModel.selectedTonic = .cFlat
        return RotationSliceData(
            signatures: signatures,
            majors: majors,
            minors: minors,
            sharps: sharpModel.keySignatureAccidentals,
            flats: flatModel.keySignatureAccidentals
        )
    }()
}

#Preview {
    CircleOfFifthsGuideView()
}
