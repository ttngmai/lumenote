//

import SwiftUI

/// Equal-width 6-string fretboard for `firstFret...lastFret`.
struct FretboardDiagramView: View {
    var accidental: AccidentalPreference
    var firstFret: Int = 0
    var lastFret: Int = Fretboard.lastFret
    var selectedPosition: Fretboard.Position? = nil
    var targetPitchClass: Int? = nil
    var hasAnswered: Bool = false
    /// Shown before and after answering, e.g. the degree-quiz tonic.
    var hintPosition: Fretboard.Position? = nil
    var showsStringLabels: Bool = true
    /// When set, matching pitch classes are shown in distinct colors and cells are not tappable.
    var visiblePitchClasses: Set<Int>? = nil
    var labelMode: Fretboard.LabelMode = .noteName
    var rootPitchClass: Int = 0
    var onSelect: (Fretboard.Position) -> Void = { _ in }

    @Environment(\.appPalette) private var palette
    @Environment(\.colorScheme) private var colorScheme

    static let stringLabelWidth: CGFloat = 22
    static let fretNumberHeight: CGFloat = 22
    static let minFretWidth: CGFloat = 44
    static let rowHeight: CGFloat = 36
    /// Quiz markers stay on the light-mode green/red so white note names stay readable.
    private static let lightQuizPalette = AppPalette(colorScheme: .light)

    static var minimumWidth: CGFloat {
        boardWidth(lastFret: Fretboard.lastFret)
    }

    static func boardWidth(lastFret: Int, showsStringLabels: Bool = true) -> CGFloat {
        boardWidth(frets: 0...lastFret, showsStringLabels: showsStringLabels)
    }

    static func boardWidth(frets: ClosedRange<Int>, showsStringLabels: Bool = true) -> CGFloat {
        let labelsWidth = showsStringLabels ? stringLabelWidth : 0
        return labelsWidth + minFretWidth * CGFloat(frets.count)
    }

    static var preferredHeight: CGFloat {
        rowHeight * CGFloat(Fretboard.stringCount) + fretNumberHeight
    }

    private var frets: ClosedRange<Int> { firstFret...lastFret }
    private let singleInlayFrets: Set<Int> = [3, 5, 7, 9, 15, 17, 19, 21]
    private let doubleInlayFrets: Set<Int> = [12]
    private let markerSize: CGFloat = 30

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if showsStringLabels {
                stringLabels
            }
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
        .frame(minWidth: Self.boardWidth(frets: frets, showsStringLabels: showsStringLabels))
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
            ForEach(frets, id: \.self) { fret in
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
            ForEach(frets, id: \.self) { fret in
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
                    } else {
                        HStack {
                            if fret == firstFret {
                                Rectangle()
                                    .fill(fretColor)
                                    .frame(width: LumenoteStroke.compact)
                            }
                            Spacer(minLength: 0)
                            if fret < lastFret {
                                Rectangle()
                                    .fill(fretColor)
                                    .frame(width: LumenoteStroke.compact)
                            }
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
        if doubleInlayFrets.contains(fret) {
            VStack(spacing: 14) {
                inlayDot
                inlayDot
            }
        } else if singleInlayFrets.contains(fret) {
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
                    ForEach(frets, id: \.self) { fret in
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
        .accessibilityLabel(accessibilityLabel(for: position, markerName: markerAccessibilityName(for: position)))
        .accessibilityHint(accessibilityHint(for: position))
        .accessibilityAddTraits(position == selectedPosition ? .isSelected : [])
    }

    private var isExploring: Bool { visiblePitchClasses != nil }

    private var isInteractive: Bool { !isExploring && !hasAnswered }

    private func markerStyle(
        for position: Fretboard.Position
    ) -> (fill: Color, stroke: Color, name: String)? {
        let pitchClass = Fretboard.pitchClass(at: position)
        let name = Fretboard.displayLabel(
            pitchClass: pitchClass,
            accidental: accidental,
            labelMode: labelMode,
            rootPitchClass: rootPitchClass
        )

        if let visiblePitchClasses {
            guard visiblePitchClasses.contains(pitchClass) else { return nil }
            let color = palette.fretboardNote(
                Fretboard.swatchPitchClass(
                    for: pitchClass,
                    labelMode: labelMode,
                    rootPitchClass: rootPitchClass
                )
            )
            return (color, color, name)
        }

        if position == hintPosition {
            let color = palette.fretboardQuizRoot
            return (color, color, name)
        }

        guard hasAnswered else { return nil }

        let isMatch = pitchClass == targetPitchClass
        let isSelected = position == selectedPosition

        if isMatch {
            let color = Self.lightQuizPalette.quizCorrect
            return (color, color, name)
        }
        if isSelected {
            let color = Self.lightQuizPalette.quizIncorrect
            return (color, color, name)
        }
        return nil
    }

    private func markerAccessibilityName(for position: Fretboard.Position) -> String? {
        guard markerStyle(for: position) != nil else { return nil }
        let pitchClass = Fretboard.pitchClass(at: position)
        return Fretboard.accessibilityName(
            pitchClass: pitchClass,
            accidental: accidental,
            labelMode: labelMode,
            rootPitchClass: rootPitchClass
        )
    }

    private func accessibilityHint(for position: Fretboard.Position) -> String {
        guard isInteractive else { return "" }
        if position == hintPosition {
            return "기준음입니다"
        }
        return "답을 선택하려면 두 번 탭하세요"
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
        firstFret: 12,
        lastFret: 16,
        selectedPosition: Fretboard.Position(stringIndex: 0, fret: 13),
        targetPitchClass: 5,
        hasAnswered: true,
        showsStringLabels: false,
        onSelect: { _ in }
    )
    .padding()
    .lumenotePalette()
}

#Preview("Degree Quiz") {
    FretboardDiagramView(
        accidental: .sharp,
        firstFret: 5,
        lastFret: 9,
        targetPitchClass: 11,
        hintPosition: Fretboard.Position(stringIndex: 2, fret: 7),
        showsStringLabels: false,
        labelMode: .degree,
        rootPitchClass: 2,
        onSelect: { _ in }
    )
    .padding()
    .lumenotePalette()
}

#Preview("Explorer") {
    FretboardDiagramView(
        accidental: .sharp,
        lastFret: Fretboard.explorerLastFret,
        visiblePitchClasses: Set(Fretboard.pitchClasses)
    )
    .padding()
    .lumenotePalette()
}

#Preview("Explorer Degrees") {
    FretboardDiagramView(
        accidental: .sharp,
        lastFret: Fretboard.explorerLastFret,
        visiblePitchClasses: Set(Fretboard.pitchClasses),
        labelMode: .degree,
        rootPitchClass: 7
    )
    .padding()
    .lumenotePalette()
}
