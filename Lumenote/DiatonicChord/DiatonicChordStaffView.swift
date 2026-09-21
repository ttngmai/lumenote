//

import SwiftUI

/// Treble staff with the seven diatonic chords in root position and roman / symbol labels.
struct DiatonicChordStaffView: View {
    let columns: [DiatonicStaffColumn]
    let highlightedDegree: DiatonicDegree?
    let staffSpace: CGFloat
    var targetWidth: CGFloat? = nil
    let lineColor: Color
    let noteColor: Color
    let highlightColor: Color
    let dimmedNoteColor: Color
    let highlightFill: Color

    private var staffHeight: CGFloat { staffSpace * 4 }
    private var clefWidth: CGFloat { staffSpace * 2.6 }
    private var leadingPad: CGFloat { staffSpace * 0.7 }
    private var trailingPad: CGFloat { staffSpace * 1.2 }
    private var verticalPad: CGFloat { staffSpace * 3.0 }
    private var accidentalPad: CGFloat { staffSpace * 1.15 }
    private var labelBlockHeight: CGFloat { staffSpace * 3.4 }

    private var minColumnSpacing: CGFloat { staffSpace * 3.35 }
    private var maxColumnSpacing: CGFloat { staffSpace * 4.6 }

    private var columnSpacing: CGFloat {
        guard let targetWidth, columns.count > 1 else { return minColumnSpacing }
        let gaps = CGFloat(columns.count - 1)
        let fixed = clefWidth + leadingPad + accidentalPad + trailingPad
        let ideal = (targetWidth - fixed) / gaps
        return min(maxColumnSpacing, max(minColumnSpacing, ideal))
    }

    private var contentWidth: CGFloat {
        chordX(for: max(columns.count - 1, 0)) + trailingPad
    }

    private var staffCanvasHeight: CGFloat {
        staffHeight + verticalPad * 2
    }

    var body: some View {
        VStack(spacing: staffSpace * 0.15) {
            ZStack(alignment: .topLeading) {
                highlightBand
                staffLines
                clef

                ForEach(columns) { column in
                    ForEach(column.notes) { note in
                        ledgerLines(for: note, in: column.chord.degree)
                        notehead(for: note, degree: column.chord.degree)
                    }
                }
            }
            .frame(width: contentWidth, height: staffCanvasHeight)

            labelRow
                .frame(width: contentWidth, height: labelBlockHeight)
        }
        .frame(width: contentWidth)
        .frame(minWidth: targetWidth ?? contentWidth, alignment: .center)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        columns
            .map { "\($0.chord.roman) \($0.chord.compactName)" }
            .joined(separator: ", ")
    }

    // MARK: - Staff

    private var highlightBand: some View {
        Group {
            if let highlightedDegree,
               let index = columns.firstIndex(where: { $0.chord.degree == highlightedDegree })
            {
                let x = chordX(for: index)
                RoundedRectangle(cornerRadius: staffSpace * 0.45, style: .continuous)
                    .fill(highlightFill)
                    .frame(width: columnSpacing * 0.92, height: staffCanvasHeight - staffSpace * 0.4)
                    .position(x: x, y: staffCanvasHeight / 2)
            }
        }
        .frame(width: contentWidth, height: staffCanvasHeight)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var staffLines: some View {
        Canvas { context, _ in
            for line in 0..<5 {
                let y = verticalPad + CGFloat(line) * staffSpace
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: contentWidth, y: y))
                context.stroke(
                    path,
                    with: .color(lineColor),
                    lineWidth: max(0.6, staffSpace * 0.09)
                )
            }
        }
        .frame(width: contentWidth, height: staffCanvasHeight)
    }

    private var clef: some View {
        Text("𝄞")
            .font(.system(size: staffSpace * 6.6))
            .minimumScaleFactor(0.3)
            .lineLimit(1)
            .foregroundStyle(lineColor)
            .frame(width: clefWidth, height: staffSpace * 7)
            .position(x: clefWidth / 2, y: verticalPad + staffHeight / 2)
    }

    private func notehead(for note: IntervalStaffNote, degree: DiatonicDegree) -> some View {
        let x = chordX(for: degree.rawValue)
        let y = y(forStaffStep: note.staffStep)
        let color = noteColor(for: degree)

        return ZStack {
            if let accidental = note.accidentalSymbol {
                Text(accidental)
                    .font(.system(size: staffSpace * 1.85, weight: .semibold))
                    .foregroundStyle(color)
                    .position(x: x - accidentalPad, y: y)
            }

            Ellipse()
                .fill(color)
                .frame(width: staffSpace * 1.25, height: staffSpace * 0.88)
                .rotationEffect(.degrees(-20))
                .position(x: x, y: y)
        }
        .frame(width: contentWidth, height: staffCanvasHeight)
    }

    private func ledgerLines(for note: IntervalStaffNote, in degree: DiatonicDegree) -> some View {
        let x = chordX(for: degree.rawValue)
        let halfWidth = staffSpace * 0.95
        let steps = ledgerSteps(for: note.staffStep)
        let color = noteColor(for: degree)

        return Canvas { context, _ in
            for ledgerStep in steps {
                let y = y(forStaffStep: ledgerStep)
                var path = Path()
                path.move(to: CGPoint(x: x - halfWidth, y: y))
                path.addLine(to: CGPoint(x: x + halfWidth, y: y))
                context.stroke(
                    path,
                    with: .color(color.opacity(0.85)),
                    lineWidth: max(0.6, staffSpace * 0.09)
                )
            }
        }
        .frame(width: contentWidth, height: staffCanvasHeight)
        .allowsHitTesting(false)
    }

    private var labelRow: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(columns.enumerated()), id: \.element.id) { index, column in
                let highlighted = highlightedDegree == column.chord.degree
                let color: Color = {
                    if highlightedDegree == nil { return .primary }
                    return highlighted ? highlightColor : .secondary
                }()

                VStack(spacing: staffSpace * 0.12) {
                    Text(column.chord.roman)
                        .font(.system(size: staffSpace * 1.12, weight: .bold, design: .rounded))
                    Text(column.chord.compactName)
                        .font(.system(size: staffSpace * 1.02, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .frame(width: columnSpacing * 0.95)
                .position(x: chordX(for: index), y: labelBlockHeight / 2)
            }
        }
        .frame(width: contentWidth, height: labelBlockHeight)
        .accessibilityHidden(true)
    }

    // MARK: - Geometry

    private func chordX(for index: Int) -> CGFloat {
        clefWidth + leadingPad + accidentalPad + columnSpacing * CGFloat(index)
    }

    private func y(forStaffStep step: Int) -> CGFloat {
        verticalPad + staffHeight - CGFloat(step) * staffSpace / 2
    }

    private func noteColor(for degree: DiatonicDegree) -> Color {
        guard let highlightedDegree else { return noteColor }
        return degree == highlightedDegree ? highlightColor : dimmedNoteColor
    }

    private func ledgerSteps(for step: Int) -> [Int] {
        if step < 0 {
            let lowestLedger = step % 2 == 0 ? step : step + 1
            guard lowestLedger <= -2 else { return [] }
            return Array(stride(from: lowestLedger, through: -2, by: 2))
        }
        if step > 8 {
            let highestLedger = step % 2 == 0 ? step : step - 1
            guard highestLedger >= 10 else { return [] }
            return Array(stride(from: 10, through: highestLedger, by: 2))
        }
        return []
    }
}

#Preview {
    DiatonicChordStaffView(
        columns: DiatonicChordModel().staffColumns,
        highlightedDegree: .i,
        staffSpace: 11,
        lineColor: .primary,
        noteColor: .primary,
        highlightColor: .blue,
        dimmedNoteColor: .primary.opacity(0.28),
        highlightFill: Color.yellow.opacity(0.35)
    )
    .padding()
    .lumenotePalette()
}
