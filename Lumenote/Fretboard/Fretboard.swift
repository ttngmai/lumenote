//

import Foundation

/// Standard 6-string guitar fretboard: pitch classes, positions, and note names.
enum Fretboard {
    struct Position: Hashable {
        /// 0 is string 1 (high E) at the top of the diagram.
        var stringIndex: Int
        var fret: Int
    }

    static let stringCount = 6
    static let lastFret = 12
    static let explorerLastFret = 22
    static let frets = 0...lastFret
    static let pitchClasses = Array(0..<12)

    /// Open-string pitch classes from string 1 (high E) to string 6 (low E).
    static let standardOpenPitchClasses = [4, 11, 7, 2, 9, 4]

    static func pitchClass(at position: Position) -> Int {
        let open = standardOpenPitchClasses[position.stringIndex]
        return (open + position.fret) % 12
    }

    static func positions(
        of pitchClass: Int,
        frets: ClosedRange<Int> = Self.frets
    ) -> [Position] {
        (0..<stringCount).flatMap { stringIndex in
            frets.compactMap { fret in
                let position = Position(stringIndex: stringIndex, fret: fret)
                return Self.pitchClass(at: position) == pitchClass ? position : nil
            }
        }
    }

    static func displayName(
        pitchClass: Int,
        accidental: AccidentalPreference
    ) -> String {
        let names = accidental == .flat ? flatNames : sharpNames
        let index = ((pitchClass % 12) + 12) % 12
        return names[index]
    }

    private static let sharpNames = [
        "C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B",
    ]

    private static let flatNames = [
        "C", "D♭", "D", "E♭", "E", "F", "G♭", "G", "A♭", "A", "B♭", "B",
    ]
}
