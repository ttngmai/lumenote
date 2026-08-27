//

import SwiftUI

/// Treble staff with a stacked root-position chord and degree labels to the right.
struct ChordStaffView: View {
    let notes: [IntervalStaffNote]
    let noteNames: [String]
    let degreeLabels: [String]
    let staffSpace: CGFloat
    var targetWidth: CGFloat? = nil
    let lineColor: Color
    let noteColor: Color
    let accentColor: Color

    private var staffHeight: CGFloat { staffSpace * 4 }
    private var clefWidth: CGFloat { staffSpace * 2.6 }
    private var leadingPad: CGFloat { staffSpace * 0.55 }
    private var trailingPad: CGFloat { staffSpace * 0.8 }
    private var verticalPad: CGFloat { staffSpace * 2.5 }
    private var accidentalPad: CGFloat { staffSpace * 1.7 }
    private var noteheadX: CGFloat { clefWidth + leadingPad + accidentalPad }
    private var labelGap: CGFloat { staffSpace * 1.8 }
    private var labelColumnWidth: CGFloat { staffSpace * 5.8 }

    private var contentWidth: CGFloat {
        noteheadX + staffSpace * 0.7 + labelGap + labelColumnWidth + trailingPad
    }

    private var canvasHeight: CGFloat {
        staffHeight + verticalPad * 2
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            staffLines
            clef

            ForEach(notes) { note in
                ledgerLines(for: note)
                notehead(for: note)
                toneLabel(for: note)
            }
        }
        .frame(width: contentWidth, height: canvasHeight)
        .frame(minWidth: targetWidth ?? contentWidth, alignment: .center)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        let names = zip(noteNames, degreeLabels)
            .map { "\($0) \($1)" }
            .joined(separator: ", ")
        return names
    }

    // MARK: - Staff

    private var staffLines: some View {
        Canvas { context, _ in
            let lineEnd = noteheadX + staffSpace * 1.4
            for line in 0..<5 {
                let y = verticalPad + CGFloat(line) * staffSpace
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: lineEnd, y: y))
                context.stroke(
                    path,
                    with: .color(lineColor),
                    lineWidth: max(0.6, staffSpace * 0.09)
                )
            }
        }
        .frame(width: contentWidth, height: canvasHeight)
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
        let y = y(forStaffStep: note.staffStep)

        return ZStack {
            if let accidental = note.accidentalSymbol {
                Text(accidental)
                    .font(.system(size: staffSpace * 1.85, weight: .semibold))
                    .foregroundStyle(noteColor)
                    .position(x: noteheadX - staffSpace * 1.15, y: y)
            }

            Ellipse()
                .fill(noteColor)
                .frame(width: staffSpace * 1.25, height: staffSpace * 0.88)
                .rotationEffect(.degrees(-20))
                .position(x: noteheadX, y: y)
        }
        .frame(width: contentWidth, height: canvasHeight)
    }

    private func ledgerLines(for note: IntervalStaffNote) -> some View {
        let step = note.staffStep
        let halfWidth = staffSpace * 0.95
        let steps = ledgerSteps(for: step)

        return Canvas { context, _ in
            for ledgerStep in steps {
                let y = y(forStaffStep: ledgerStep)
                var path = Path()
                path.move(to: CGPoint(x: noteheadX - halfWidth, y: y))
                path.addLine(to: CGPoint(x: noteheadX + halfWidth, y: y))
                context.stroke(
                    path,
                    with: .color(lineColor),
                    lineWidth: max(0.6, staffSpace * 0.09)
                )
            }
        }
        .frame(width: contentWidth, height: canvasHeight)
        .allowsHitTesting(false)
    }

    private func toneLabel(for note: IntervalStaffNote) -> some View {
        let index = note.id
        let name = noteNames.indices.contains(index) ? noteNames[index] : ""
        let degree = degreeLabels.indices.contains(index) ? degreeLabels[index] : ""
        let y = y(forStaffStep: note.staffStep)
        let x = noteheadX + staffSpace * 0.7 + labelGap + labelColumnWidth / 2

        return HStack(spacing: staffSpace * 0.45) {
            Text(name)
                .font(.system(size: staffSpace * 1.15, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(minWidth: staffSpace * 2.2, alignment: .leading)
            Text(degree)
                .font(.system(size: staffSpace * 1.05, weight: .bold, design: .rounded))
                .foregroundStyle(accentColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(width: labelColumnWidth, alignment: .leading)
        .position(x: x, y: y)
        .accessibilityHidden(true)
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

    private func y(forStaffStep step: Int) -> CGFloat {
        verticalPad + staffHeight - CGFloat(step) * staffSpace / 2
    }
}

#Preview {
    ChordStaffView(
        notes: [
            IntervalStaffNote(id: 0, spelling: "C", staffStep: -2, accidentalSymbol: nil),
            IntervalStaffNote(id: 1, spelling: "E", staffStep: 0, accidentalSymbol: nil),
            IntervalStaffNote(id: 2, spelling: "G", staffStep: 2, accidentalSymbol: nil),
        ],
        noteNames: ["C", "E", "G"],
        degreeLabels: ["1", "3", "5"],
        staffSpace: 12,
        lineColor: .primary,
        noteColor: .primary,
        accentColor: .blue
    )
    .padding()
    .lumenotePalette()
}
