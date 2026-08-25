//

import SwiftUI

/// Treble staff with two noteheads (root → target) for ascending or descending intervals.
struct IntervalStaffView: View {
    let notes: [IntervalStaffNote]
    let staffSpace: CGFloat
    let lineColor: Color
    let noteColor: Color

    private var staffHeight: CGFloat { staffSpace * 4 }
    private var clefWidth: CGFloat { staffSpace * 2.8 }
    private var noteSpacing: CGFloat { staffSpace * 3.2 }
    private var leadingPad: CGFloat { staffSpace * 0.4 }
    private var trailingPad: CGFloat { staffSpace * 1.4 }
    private var verticalPad: CGFloat { staffSpace * 2.2 }

    private var contentWidth: CGFloat {
        clefWidth
            + leadingPad
            + noteSpacing * CGFloat(max(notes.count - 1, 0))
            + trailingPad
            + staffSpace * 1.2
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
            }
        }
        .frame(width: contentWidth, height: canvasHeight)
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
        .frame(width: contentWidth, height: canvasHeight)
    }

    private var clef: some View {
        Text("𝄞")
            .font(.system(size: staffSpace * 7))
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
                    .font(.system(size: staffSpace * 2.0, weight: .semibold))
                    .foregroundStyle(noteColor)
                    .position(x: x - staffSpace * 1.15, y: y)
            }

            Ellipse()
                .fill(noteColor)
                .frame(width: staffSpace * 1.35, height: staffSpace * 0.95)
                .rotationEffect(.degrees(-20))
                .position(x: x, y: y)
        }
        .frame(width: contentWidth, height: canvasHeight)
    }

    /// Short ledger lines for notes below E4 (step 0) or above F5 (step 8).
    private func ledgerLines(for note: IntervalStaffNote) -> some View {
        let step = note.staffStep
        let x = noteX(for: note.id)
        let halfWidth = staffSpace * 1.05
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
        .frame(width: contentWidth, height: canvasHeight)
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

    private func noteX(for index: Int) -> CGFloat {
        clefWidth + leadingPad + staffSpace * 0.6 + noteSpacing * CGFloat(index)
    }

    /// Bottom staff line is step 0; each step is half a staff space.
    private func y(forStaffStep step: Int) -> CGFloat {
        verticalPad + staffHeight - CGFloat(step) * staffSpace / 2
    }
}

#Preview {
    VStack(spacing: 24) {
        IntervalStaffView(
            notes: [
                IntervalStaffNote(id: 0, spelling: "C", staffStep: -2, accidentalSymbol: nil),
                IntervalStaffNote(id: 1, spelling: "E", staffStep: 0, accidentalSymbol: nil),
            ],
            staffSpace: 12,
            lineColor: .primary,
            noteColor: .primary
        )
        IntervalStaffView(
            notes: [
                IntervalStaffNote(id: 0, spelling: "C", staffStep: 5, accidentalSymbol: nil),
                IntervalStaffNote(id: 1, spelling: "E", staffStep: -2, accidentalSymbol: nil),
            ],
            staffSpace: 12,
            lineColor: .primary,
            noteColor: .primary
        )
    }
    .padding()
    .lumenotePalette()
}
