//

import Foundation

/// Standard 6-string guitar fretboard: pitch classes, positions, and note names.
enum Fretboard {
    struct Position: Hashable {
        /// 0 is string 1 (high E) at the top of the diagram.
        var stringIndex: Int
        var fret: Int
    }

    /// How explorer markers and note chips are labeled.
    enum LabelMode: String, CaseIterable, Identifiable {
        case noteName
        case degree

        var id: String { rawValue }

        var title: String {
            switch self {
            case .noteName: return "음이름"
            case .degree: return "도수"
            }
        }

        var next: LabelMode {
            switch self {
            case .noteName: return .degree
            case .degree: return .noteName
            }
        }

        var toggleAccessibilityLabel: String {
            switch self {
            case .noteName: return "도수 표시로 전환"
            case .degree: return "음이름 표시로 전환"
            }
        }
    }

    static let stringCount = 6
    static let lastFret = 12
    static let explorerLastFret = 22
    static let quizWindowLength = 5
    /// Chromatic intervals asked by the fretboard degree quiz. Tonic (0 semitones / 1도) is never the target.
    static let quizTargetSemitones = 1...11
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

    /// Consecutive 5-fret windows on the 22-fret board.
    static func quizFretWindows(
        lastFret: Int = explorerLastFret
    ) -> [ClosedRange<Int>] {
        let length = quizWindowLength
        guard lastFret >= length - 1 else { return [] }
        return (0...(lastFret - length + 1)).map { start in
            start...(start + length - 1)
        }
    }

    /// Consecutive 5-fret windows on the 22-fret board that contain `pitchClass`.
    static func quizFretWindows(
        containing pitchClass: Int,
        lastFret: Int = explorerLastFret
    ) -> [ClosedRange<Int>] {
        quizFretWindows(lastFret: lastFret).filter { window in
            !positions(of: pitchClass, frets: window).isEmpty
        }
    }

    static func displayName(
        pitchClass: Int,
        accidental: AccidentalPreference
    ) -> String {
        let names = accidental == .flat ? flatNames : sharpNames
        return names[normalizedPitchClass(pitchClass)]
    }

    /// Pitch classes in the explorer chip order: C…B, or 1…7 from the chosen root.
    static func explorerPitchClasses(
        labelMode: LabelMode,
        rootPitchClass: Int
    ) -> [Int] {
        switch labelMode {
        case .noteName:
            return pitchClasses
        case .degree:
            let root = normalizedPitchClass(rootPitchClass)
            return (0..<12).map { (root + $0) % 12 }
        }
    }

    /// Color-table index so degree 1 uses C's color, 2 uses D's color, and so on.
    static func swatchPitchClass(
        for pitchClass: Int,
        labelMode: LabelMode,
        rootPitchClass: Int
    ) -> Int {
        switch labelMode {
        case .noteName:
            return normalizedPitchClass(pitchClass)
        case .degree:
            return semitones(from: rootPitchClass, to: pitchClass)
        }
    }

    /// Chromatic interval from `rootPitchClass` up to `pitchClass`, 0…11.
    static func semitones(from rootPitchClass: Int, to pitchClass: Int) -> Int {
        (normalizedPitchClass(pitchClass) - normalizedPitchClass(rootPitchClass) + 12) % 12
    }

    /// Chromatic degree for a pitch class relative to the chosen root (1).
    /// Half-steps follow the sharp/flat preference (`♯1`/`♭2`, `♯4`/`♭5`, …).
    static func degreeLabel(
        pitchClass: Int,
        rootPitchClass: Int,
        accidental: AccidentalPreference
    ) -> String {
        let labels = accidental == .flat ? flatDegreeLabels : sharpDegreeLabels
        return labels[semitones(from: rootPitchClass, to: pitchClass)]
    }

    static func displayLabel(
        pitchClass: Int,
        accidental: AccidentalPreference,
        labelMode: LabelMode,
        rootPitchClass: Int
    ) -> String {
        switch labelMode {
        case .noteName:
            return displayName(pitchClass: pitchClass, accidental: accidental)
        case .degree:
            return degreeLabel(
                pitchClass: pitchClass,
                rootPitchClass: rootPitchClass,
                accidental: accidental
            )
        }
    }

    static func accessibilityName(
        pitchClass: Int,
        accidental: AccidentalPreference,
        labelMode: LabelMode,
        rootPitchClass: Int
    ) -> String {
        switch labelMode {
        case .noteName:
            return displayName(pitchClass: pitchClass, accidental: accidental)
        case .degree:
            return degreeAccessibilityName(
                pitchClass: pitchClass,
                rootPitchClass: rootPitchClass,
                accidental: accidental
            )
        }
    }

    private static func degreeAccessibilityName(
        pitchClass: Int,
        rootPitchClass: Int,
        accidental: AccidentalPreference
    ) -> String {
        let names = accidental == .flat ? flatDegreeAccessibilityNames : sharpDegreeAccessibilityNames
        return names[semitones(from: rootPitchClass, to: pitchClass)]
    }

    static func normalizedPitchClass(_ pitchClass: Int) -> Int {
        ((pitchClass % 12) + 12) % 12
    }

    private static let sharpNames = [
        "C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B",
    ]

    private static let flatNames = [
        "C", "D♭", "D", "E♭", "E", "F", "G♭", "G", "A♭", "A", "B♭", "B",
    ]

    private static let sharpDegreeLabels = [
        "1", "♯1", "2", "♯2", "3", "4", "♯4", "5", "♯5", "6", "♯6", "7",
    ]

    private static let flatDegreeLabels = [
        "1", "♭2", "2", "♭3", "3", "4", "♭5", "5", "♭6", "6", "♭7", "7",
    ]

    private static let sharpDegreeAccessibilityNames = [
        "1도", "샵 1도", "2도", "샵 2도", "3도", "4도", "샵 4도",
        "5도", "샵 5도", "6도", "샵 6도", "7도",
    ]

    private static let flatDegreeAccessibilityNames = [
        "1도", "플랫 2도", "2도", "플랫 3도", "3도", "4도", "플랫 5도",
        "5도", "플랫 6도", "6도", "플랫 7도", "7도",
    ]
}
