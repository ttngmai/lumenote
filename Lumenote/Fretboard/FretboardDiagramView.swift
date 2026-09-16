//

import SwiftUI

/// Equal-width 6-string fretboard (open string through 12th fret).
struct FretboardDiagramView: View {
    var accidental: AccidentalPreference
    var selectedPosition: Fretboard.Position? = nil
    var targetPitchClass: Int? = nil
    var hasAnswered: Bool = false
    /// When set, matching pitch classes are shown in distinct colors and cells are not tappable.
    var visiblePitchClasses: Set<Int>? = nil
    var onSelect: (Fretboard.Position) -> Void = { _ in }

    @Environment(\.appPalette) private var palette
    @Environment(\.colorScheme) private var colorScheme

    static let stringLabelWidth: CGFloat = 22
    static let fretNumberHeight: CGFloat = 22
    static let minFretWidth: CGFloat = 44
    static let rowHeight: CGFloat = 36

    static var minimumWidth: CGFloat {
        stringLabelWidth + minFretWidth * CGFloat(Fretboard.frets.count)
    }

    static var preferredHeight: CGFloat {
        rowHeight * CGFloat(Fretboard.stringCount) + fretNumberHeight
    }

    private let inlayFrets: Set<Int> = [3, 5, 7, 9]
    private let markerSize: CGFloat = 30

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            stringLabels
            VStack(spacing: 0) {
                ZStack {
                    boardFill
                    fretColumns
                    strings
                    cellGrid
                }
                .frame(height: Self.rowHeight * CGFloat(Fretboard.stringCount))
                .clipShape(RoundedRectangle(cornerRadius: LumenoteRadius.scaleCell, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: LumenoteRadius.scaleCell, style: .continuous)
                        .strokeBorder(palette.cardBorder, lineWidth: LumenoteStroke.compact)
                )

                fretNumbers
            }
        }
        .frame(minWidth: Self.minimumWidth)
        .accessibilityElement(children: .contain)
    }

    private var stringLabels: some View {
        VStack(spacing: 0) {
            ForEach(0..<Fretboard.stringCount, id: \.self) { stringIndex in
                Text("\(stringIndex + 1)")
                    .font(LumenoteFont.caption2(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: Self.stringLabelWidth, height: Self.rowHeight)
                    .accessibilityHidden(true)
            }
        }
    }

    private var fretNumbers: some View {
        HStack(spacing: 0) {
            ForEach(Fretboard.frets, id: \.self) { fret in
                Text("\(fret)")
                    .font(LumenoteFont.caption2(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: Self.fretNumberHeight)
                    .accessibilityHidden(true)
            }
        }
    }

    private var boardFill: some View {
        RoundedRectangle(cornerRadius: LumenoteRadius.scaleCell, style: .continuous)
            .fill(Color.primary.opacity(0.06))
    }

    private var isDark: Bool { colorScheme == .dark }

    private var nutColor: Color {
        isDark ? Color.white.opacity(0.9) : palette.cardBorder
    }

    private var fretColor: Color {
        isDark ? Color.white.opacity(0.72) : palette.ringStroke.opacity(0.45)
    }

    private var stringColor: Color {
        isDark ? Color.white.opacity(0.8) : Color.primary.opacity(0.38)
    }

    private var fretColumns: some View {
        HStack(spacing: 0) {
            ForEach(Fretboard.frets, id: \.self) { fret in
                ZStack {
                    if fret == 0 {
                        palette.cardBackground.opacity(0.55)
                    }

                    inlay(for: fret)

                    if fret == 0 {
                        HStack {
                            Spacer(minLength: 0)
                            Rectangle()
                                .fill(nutColor)
                                .frame(width: 5)
                        }
                    } else if fret < Fretboard.lastFret {
                        HStack {
                            Spacer(minLength: 0)
                            Rectangle()
                                .fill(fretColor)
                                .frame(width: LumenoteStroke.compact)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func inlay(for fret: Int) -> some View {
        if fret == 12 {
            VStack(spacing: 14) {
                inlayDot
                inlayDot
            }
        } else if inlayFrets.contains(fret) {
            inlayDot
        }
    }

    private var inlayDot: some View {
        Circle()
            .fill(Color.primary.opacity(0.16))
            .frame(width: 7, height: 7)
    }

    private var strings: some View {
        Canvas { context, size in
            let rowHeight = size.height / CGFloat(Fretboard.stringCount)
            for stringIndex in 0..<Fretboard.stringCount {
                let y = rowHeight * (CGFloat(stringIndex) + 0.5)
                let thickness = 0.8 + CGFloat(stringIndex) / CGFloat(Fretboard.stringCount - 1) * 1.5
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(
                    path,
                    with: .color(stringColor),
                    style: StrokeStyle(lineWidth: thickness, lineCap: .round)
                )
            }
        }
        .allowsHitTesting(false)
    }

    private var cellGrid: some View {
        VStack(spacing: 0) {
            ForEach(0..<Fretboard.stringCount, id: \.self) { stringIndex in
                HStack(spacing: 0) {
                    ForEach(Fretboard.frets, id: \.self) { fret in
                        cell(Fretboard.Position(stringIndex: stringIndex, fret: fret))
                    }
                }
            }
        }
    }

    private func cell(_ position: Fretboard.Position) -> some View {
        let marker = markerStyle(for: position)

        return Button {
            onSelect(position)
        } label: {
            ZStack {
                if let marker {
                    Circle()
                        .fill(marker.fill)
                        .overlay(
                            Circle()
                                .strokeBorder(marker.stroke, lineWidth: LumenoteStroke.compact)
                        )
                        .frame(width: markerSize, height: markerSize)
                    Text(marker.name)
                        .font(LumenoteFont.rounded(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .frame(width: markerSize - 4)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .allowsHitTesting(isInteractive)
        .accessibilityLabel(accessibilityLabel(for: position, markerName: marker?.name))
        .accessibilityHint(isInteractive ? "답을 선택하려면 두 번 탭하세요" : "")
        .accessibilityAddTraits(position == selectedPosition ? .isSelected : [])
    }

    private var isExploring: Bool { visiblePitchClasses != nil }

    private var isInteractive: Bool { !isExploring && !hasAnswered }

    private func markerStyle(
        for position: Fretboard.Position
    ) -> (fill: Color, stroke: Color, name: String)? {
        let pitchClass = Fretboard.pitchClass(at: position)
        let name = Fretboard.displayName(pitchClass: pitchClass, accidental: accidental)

        if let visiblePitchClasses {
            guard visiblePitchClasses.contains(pitchClass) else { return nil }
            let color = palette.fretboardNote(pitchClass)
            return (color, color, name)
        }

        guard hasAnswered else { return nil }

        let isMatch = pitchClass == targetPitchClass
        let isSelected = position == selectedPosition

        if isMatch {
            let color = correctMarkerColor
            return (color, color, name)
        }
        if isSelected {
            let color = palette.quizIncorrect.opacity(1)
            return (color, color, name)
        }
        return nil
    }

    /// Solid green that keeps white note names readable in both appearances.
    private var correctMarkerColor: Color {
        colorScheme == .dark
            ? Color(red: 0.20, green: 0.64, blue: 0.40)
            : palette.quizCorrect
    }

    private func accessibilityLabel(for position: Fretboard.Position, markerName: String?) -> String {
        let location = position.fret == 0
            ? "\(position.stringIndex + 1)번줄 개방현"
            : "\(position.stringIndex + 1)번줄 \(position.fret)프렛"
        if let markerName {
            return "\(location), \(markerName)"
        }
        return location
    }
}

#Preview("Quiz") {
    FretboardDiagramView(
        accidental: .sharp,
        selectedPosition: Fretboard.Position(stringIndex: 0, fret: 1),
        targetPitchClass: 5,
        hasAnswered: true,
        onSelect: { _ in }
    )
    .padding()
    .lumenotePalette()
}

#Preview("Explorer") {
    FretboardDiagramView(
        accidental: .sharp,
        visiblePitchClasses: Set(Fretboard.pitchClasses)
    )
    .padding()
    .lumenotePalette()
}
