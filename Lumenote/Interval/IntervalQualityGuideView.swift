//

import SwiftUI

/// Explains Perfect / Major / Minor quality rules and how # / ♭ shift them.
struct IntervalQualityGuideView: View {
    @Environment(\.appPalette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private let connectorGap: CGFloat = 36

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: LumenoteSpacing.section) {
                    summaryCard
                    diagram
                }
                .padding(.horizontal, LumenoteSpacing.popupInset)
                .padding(.vertical, LumenoteSpacing.xxxl)
                .frame(maxWidth: .infinity)
            }
            .background(sheetBackground)
            .navigationTitle("음정 이름 규칙")
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

    // MARK: - Summary

    private var summaryCard: some View {
        Text("같은 도수에서 반음이 멀어지면 # 방향, 가까워지면 ♭ 방향으로 이름이 바뀝니다.\n1·4·5·8도는 Perfect를 쓰고, 2·3·6·7도는 Major / Minor를 씁니다.")
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
                degrees: "1, 2, 3, 4, 5, 6, 7",
                fill: colors.doublyAugmented,
                foreground: colors.onGreen
            )

            qualityBox(
                .augmented,
                title: "Augmented(증)",
                degrees: "1, 2, 3, 4, 5, 6, 7",
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
                degrees: "1, 2, 3, 4, 5, 6, 7",
                fill: colors.diminished,
                foreground: colors.onRed
            )

            qualityBox(
                .doublyDiminished,
                title: "Doubly Diminished(겹감)",
                degrees: "1, 2, 3, 4, 5, 6, 7",
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
        degrees: String,
        fill: Color,
        foreground: Color
    ) -> some View {
        VStack(spacing: LumenoteSpacing.xxs) {
            Text(title)
                .font(LumenoteFont.caption(.bold))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
                .lineLimit(2)
            Text(degrees)
                .font(LumenoteFont.caption2(.semibold))
                .opacity(0.85)
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
        .accessibilityLabel("\(title), \(degrees)")
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
            ? Color(red: 0.28, green: 0.45, blue: 0.78)
            : Color(red: 0.55, green: 0.70, blue: 0.92)
    }

    var major: Color {
        isDark
            ? Color(red: 0.28, green: 0.45, blue: 0.78)
            : Color(red: 0.55, green: 0.70, blue: 0.92)
    }

    var minorQuality: Color {
        isDark
            ? Color(red: 0.72, green: 0.32, blue: 0.55)
            : Color(red: 0.93, green: 0.55, blue: 0.72)
    }

    var augmented: Color {
        isDark
            ? Color(red: 0.22, green: 0.55, blue: 0.38)
            : Color(red: 0.55, green: 0.82, blue: 0.62)
    }

    var doublyAugmented: Color {
        isDark
            ? Color(red: 0.16, green: 0.42, blue: 0.30)
            : Color(red: 0.35, green: 0.68, blue: 0.48)
    }

    var diminished: Color {
        isDark
            ? Color(red: 0.72, green: 0.38, blue: 0.38)
            : Color(red: 0.95, green: 0.62, blue: 0.58)
    }

    var doublyDiminished: Color {
        isDark
            ? Color(red: 0.78, green: 0.28, blue: 0.28)
            : Color(red: 0.92, green: 0.42, blue: 0.40)
    }

    var onBlue: Color { isDark ? .white : Color(red: 0.12, green: 0.22, blue: 0.42) }
    var onPink: Color { isDark ? .white : Color(red: 0.42, green: 0.12, blue: 0.28) }
    var onGreen: Color { isDark ? .white : Color(red: 0.10, green: 0.28, blue: 0.18) }
    var onRed: Color { isDark ? .white : Color(red: 0.42, green: 0.12, blue: 0.12) }
}

#Preview {
    IntervalQualityGuideView()
}
