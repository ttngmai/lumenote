//

import SwiftUI

/// Treble staff with an octave of scale degrees and textbook-style step labels underneath.
struct ScaleStaffView: View {
    let notes: [IntervalStaffNote]
    let intervals: [ScaleStepInterval]
    let noteNames: [String]
    let staffSpace: CGFloat
    /// Card inner width used to stretch note spacing (up to a cap) and center the staff.
    var targetWidth: CGFloat? = nil
    let lineColor: Color
    let noteColor: Color
    let accentColor: Color

    private var staffHeight: CGFloat { staffSpace * 4 }
    private var clefWidth: CGFloat { staffSpace * 2.6 }
    private var leadingPad: CGFloat { staffSpace * 0.55 }
    private var trailingPad: CGFloat { staffSpace * 1.1 }
    private var verticalPad: CGFloat { staffSpace * 2.35 }
    private var annotationHeight: CGFloat { staffSpace * 3.4 }
    private var nameRowHeight: CGFloat { staffSpace * 1.7 }

    private var minNoteSpacing: CGFloat { staffSpace * 2.55 }
    private var maxNoteSpacing: CGFloat { staffSpace * 4.4 }

    private var noteSpacing: CGFloat {
        guard let targetWidth, notes.count > 1 else { return minNoteSpacing }
        let gaps = CGFloat(notes.count - 1)
        let fixed = clefWidth + leadingPad + trailingPad + staffSpace * 1.1
        let ideal = (targetWidth - fixed) / gaps
        return min(maxNoteSpacing, max(minNoteSpacing, ideal))
    }

    private var contentWidth: CGFloat {
        clefWidth
            + leadingPad
            + noteSpacing * CGFloat(max(notes.count - 1, 0))
            + trailingPad
            + staffSpace * 1.1
    }

    private var staffCanvasHeight: CGFloat {
        staffHeight + verticalPad * 2
    }

    var body: some View {
        VStack(spacing: staffSpace * 0.2) {
            ZStack(alignment: .topLeading) {
                staffLines
                clef

                ForEach(notes) { note in
                    ledgerLines(for: note)
                    notehead(for: note)
                }
            }
            .frame(width: contentWidth, height: staffCanvasHeight)

            noteNameRow
                .frame(width: contentWidth, height: nameRowHeight)

            intervalAnnotations
                .frame(width: contentWidth, height: annotationHeight)
        }
        .frame(width: contentWidth)
        .frame(minWidth: targetWidth ?? contentWidth, alignment: .center)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        let names = noteNames.joined(separator: ", ")
        let steps = intervals.map(\.koreanLabel).joined(separator: ", ")
        return "\(names). 구성: \(steps)"
    }

    // MARK: - Staff

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

    private func notehead(for note: IntervalStaffNote) -> some View {
        let x = noteX(for: note.id)
        let y = y(forStaffStep: note.staffStep)

        return ZStack {
            if let accidental = note.accidentalSymbol {
                Text(accidental)
                    .font(.system(size: staffSpace * 1.85, weight: .semibold))
                    .foregroundStyle(noteColor)
                    .position(x: x - staffSpace * 1.05, y: y)
            }

            Ellipse()
                .fill(noteColor)
                .frame(width: staffSpace * 1.25, height: staffSpace * 0.88)
                .rotationEffect(.degrees(-20))
                .position(x: x, y: y)
        }
        .frame(width: contentWidth, height: staffCanvasHeight)
    }

    private func ledgerLines(for note: IntervalStaffNote) -> some View {
        let step = note.staffStep
        let x = noteX(for: note.id)
        let halfWidth = staffSpace * 0.95
        let steps = ledgerSteps(for: step)

        return Canvas { context, _ in
            for ledgerStep in steps {
                let y = y(forStaffStep: ledgerStep)
                var path = Path()
                path.move(to: CGPoint(x: x - halfWidth, y: y))
                path.addLine(to: CGPoint(x: x + halfWidth, y: y))
                context.stroke(
                    path,
                    with: .color(lineColor),
                    lineWidth: max(0.6, staffSpace * 0.09)
                )
            }
        }
        .frame(width: contentWidth, height: staffCanvasHeight)
        .allowsHitTesting(false)
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

    // MARK: - Interval annotations

    private var intervalAnnotations: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(intervals.enumerated()), id: \.offset) { index, interval in
                let left = noteX(for: index)
                let right = noteX(for: index + 1)
                let midX = (left + right) / 2
                let width = right - left

                VStack(spacing: staffSpace * 0.12) {
                    ScaleStepMark(kind: interval, color: accentColor)
                        .frame(width: max(width * 0.72, staffSpace * 1.1), height: staffSpace * 0.85)

                    Text(interval.koreanLabel)
                        .font(.system(size: staffSpace * 0.95, weight: .semibold, design: .rounded))
                        .foregroundStyle(accentColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .position(x: midX, y: annotationHeight / 2)
            }
        }
        .frame(width: contentWidth, height: annotationHeight)
        .accessibilityHidden(true)
    }

    private var noteNameRow: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(noteNames.enumerated()), id: \.offset) { index, name in
                Text(name)
                    .font(.system(size: staffSpace * 1.05, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .position(x: noteX(for: index), y: nameRowHeight / 2)
            }
        }
        .frame(width: contentWidth, height: nameRowHeight)
        .accessibilityHidden(true)
    }

    // MARK: - Geometry

    private func noteX(for index: Int) -> CGFloat {
        clefWidth + leadingPad + staffSpace * 0.55 + noteSpacing * CGFloat(index)
    }

    private func y(forStaffStep step: Int) -> CGFloat {
        verticalPad + staffHeight - CGFloat(step) * staffSpace / 2
    }
}

/// Bracket / caret mark matching the textbook whole-step and half-step glyphs.
private struct ScaleStepMark: View {
    let kind: ScaleStepInterval
    let color: Color

    var body: some View {
        Canvas { context, size in
            var path = Path()
            let stroke = max(1.1, min(size.width, size.height) * 0.12)
            let insetX = size.width * 0.06
            let top = size.height * 0.12
            let bottom = size.height * 0.88

            switch kind {
            case .whole, .augmentedSecond:
                // Square bracket opening upward toward the notes: └──┘
                path.move(to: CGPoint(x: insetX, y: top))
                path.addLine(to: CGPoint(x: insetX, y: bottom))
                path.addLine(to: CGPoint(x: size.width - insetX, y: bottom))
                path.addLine(to: CGPoint(x: size.width - insetX, y: top))
            case .half:
                // Upside-down V (caret) for half steps: ∨
                path.move(to: CGPoint(x: insetX, y: top))
                path.addLine(to: CGPoint(x: size.width / 2, y: bottom))
                path.addLine(to: CGPoint(x: size.width - insetX, y: top))
            }

            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: stroke, lineCap: .square, lineJoin: .miter)
            )
        }
    }
}

#Preview {
    ScaleStaffView(
        notes: [
            IntervalStaffNote(id: 0, spelling: "C", staffStep: -2, accidentalSymbol: nil),
            IntervalStaffNote(id: 1, spelling: "D", staffStep: -1, accidentalSymbol: nil),
            IntervalStaffNote(id: 2, spelling: "E", staffStep: 0, accidentalSymbol: nil),
            IntervalStaffNote(id: 3, spelling: "F", staffStep: 1, accidentalSymbol: nil),
            IntervalStaffNote(id: 4, spelling: "G", staffStep: 2, accidentalSymbol: nil),
            IntervalStaffNote(id: 5, spelling: "A", staffStep: 3, accidentalSymbol: nil),
            IntervalStaffNote(id: 6, spelling: "B", staffStep: 4, accidentalSymbol: nil),
            IntervalStaffNote(id: 7, spelling: "C", staffStep: 5, accidentalSymbol: nil),
        ],
        intervals: ScaleKind.major.semitoneSteps.map(ScaleStepInterval.init(semitones:)),
        noteNames: ["C", "D", "E", "F", "G", "A", "B", "C"],
        staffSpace: 11,
        lineColor: .primary,
        noteColor: .primary,
        accentColor: .blue
    )
    .padding()
    .lumenotePalette()
}
