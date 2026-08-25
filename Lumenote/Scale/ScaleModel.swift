//

import Foundation

/// Interactive scale construction guide: tonic + scale kind → spelled degrees and step labels.
@Observable
final class ScaleModel {
    var tonicSpelling: String = "C" {
        didSet {
            if !Self.isKnownSpelling(tonicSpelling) {
                tonicSpelling = "C"
            }
        }
    }

    var kind: ScaleKind = .major

    // MARK: - Derived

    var tonicDisplayName: String {
        Self.formatNoteName(tonicSpelling)
    }

    /// Selectable tonic spellings (same chromatic order as the interval explorer).
    var noteOptions: [(spelling: String, displayName: String)] {
        Self.orderedSpellings.map { ($0, Self.formatNoteName($0)) }
    }

    /// Eight ascending degrees (tonic through octave), spelled for the chosen tonic and kind.
    var degreeSpellings: [String] {
        Self.spellScale(tonic: tonicSpelling, steps: kind.semitoneSteps)
    }

    var degreeDisplayNames: [String] {
        degreeSpellings.map(Self.formatNoteName)
    }

    /// Step labels between consecutive degrees (7 intervals for an octave scale).
    var stepIntervals: [ScaleStepInterval] {
        kind.semitoneSteps.map(ScaleStepInterval.init(semitones:))
    }

    /// Tonic through octave on a treble staff starting in the C4 octave.
    var staffNotes: [IntervalStaffNote] {
        let spellings = degreeSpellings
        guard let tonicLetter = Self.letterIndex(of: tonicSpelling) else { return [] }

        // Fixed letter → staff mapping in the C4 octave: C = −2, D = −1, E = 0, …, B = 4.
        let startStep = tonicLetter - 2
        return spellings.enumerated().map { index, spelling in
            IntervalStaffNote(
                id: index,
                spelling: spelling,
                staffStep: startStep + index,
                accidentalSymbol: Self.accidentalSymbol(for: spelling)
            )
        }
    }

    // MARK: - Tables

    private static let orderedSpellings: [String] = [
        "C", "C#", "Db", "D", "D#", "Eb", "E", "Fb", "E#", "F",
        "F#", "Gb", "G", "G#", "Ab", "A", "A#", "Bb", "B", "Cb", "B#",
    ]

    private static let pitchClassBySpelling: [String: Int] = [
        "C": 0, "B#": 0,
        "C#": 1, "Db": 1,
        "D": 2,
        "D#": 3, "Eb": 3,
        "E": 4, "Fb": 4,
        "E#": 5, "F": 5,
        "F#": 6, "Gb": 6,
        "G": 7,
        "G#": 8, "Ab": 8,
        "A": 9,
        "A#": 10, "Bb": 10,
        "B": 11, "Cb": 11,
    ]

    private static let letters: [Character] = ["C", "D", "E", "F", "G", "A", "B"]
    private static let naturalPitchClasses: [Int] = [0, 2, 4, 5, 7, 9, 11]

    private static let letterIndices: [Character: Int] = [
        "C": 0, "D": 1, "E": 2, "F": 3, "G": 4, "A": 5, "B": 6,
    ]

    // MARK: - Spelling

    /// Builds eight note spellings by walking consecutive letters and matching each target pitch class.
    private static func spellScale(tonic: String, steps: [Int]) -> [String] {
        guard let tonicLetter = letterIndex(of: tonic) else { return [] }
        let tonicPC = pitchClass(for: tonic)

        var spellings: [String] = []
        var cumulative = 0
        for degree in 0...7 {
            if degree > 0 {
                cumulative += steps[degree - 1]
            }
            let letterIdx = (tonicLetter + degree) % 7
            let expectedPC = (tonicPC + cumulative) % 12
            let naturalPC = naturalPitchClasses[letterIdx]
            var offset = expectedPC - naturalPC
            if offset > 6 { offset -= 12 }
            if offset < -6 { offset += 12 }
            spellings.append(spelling(letter: letters[letterIdx], accidentalOffset: offset))
        }
        return spellings
    }

    private static func spelling(letter: Character, accidentalOffset: Int) -> String {
        let base = String(letter)
        switch accidentalOffset {
        case 2: return base + "##"
        case 1: return base + "#"
        case 0: return base
        case -1: return base + "b"
        case -2: return base + "bb"
        default:
            // Extreme theoretical cases: keep nearest double accidental.
            if accidentalOffset > 2 { return base + "##" }
            if accidentalOffset < -2 { return base + "bb" }
            return base
        }
    }

    private static func letterIndex(of spelling: String) -> Int? {
        guard let first = spelling.first else { return nil }
        return letterIndices[first]
    }

    private static func accidentalSymbol(for spelling: String) -> String? {
        if spelling.hasSuffix("##") { return "𝄪" }
        if spelling.hasSuffix("#") { return "♯" }
        if spelling.hasSuffix("bb") { return "𝄫" }
        if spelling.hasSuffix("b") { return "♭" }
        return nil
    }

    // MARK: - Helpers

    static func pitchClass(for spelling: String) -> Int {
        if let known = pitchClassBySpelling[spelling] {
            return known
        }
        // Double accidentals (e.g. Fx, Bbb) used by some harmonic-minor tonics.
        guard let letter = spelling.first,
              let letterIdx = letterIndices[letter]
        else { return 0 }
        let natural = naturalPitchClasses[letterIdx]
        let suffix = String(spelling.dropFirst())
        let offset: Int
        switch suffix {
        case "##": offset = 2
        case "#": offset = 1
        case "bb": offset = -2
        case "b": offset = -1
        default: offset = 0
        }
        return (natural + offset + 12) % 12
    }

    static func isKnownSpelling(_ spelling: String) -> Bool {
        pitchClassBySpelling[spelling] != nil
    }

    static func formatNoteName(_ name: String) -> String {
        if name.hasSuffix("##") {
            return String(name.dropLast(2)) + "𝄪"
        }
        if name.hasSuffix("#") {
            return String(name.dropLast()) + "♯"
        }
        if name.hasSuffix("bb") {
            return String(name.dropLast(2)) + "𝄫"
        }
        if name.hasSuffix("b") {
            return String(name.dropLast()) + "♭"
        }
        return name
    }
}

// MARK: - Scale kind

enum ScaleKind: String, CaseIterable, Identifiable {
    case major
    case naturalMinor
    case harmonicMinor
    case melodicMinor

    var id: String { rawValue }

    var englishTitle: String {
        switch self {
        case .major: return "Major"
        case .naturalMinor: return "Natural Minor"
        case .harmonicMinor: return "Harmonic Minor"
        case .melodicMinor: return "Melodic Minor"
        }
    }

    /// Semitone distances between consecutive degrees (tonic → octave).
    /// Melodic minor uses the ascending form (raised 6th and 7th).
    var semitoneSteps: [Int] {
        switch self {
        case .major:
            return [2, 2, 1, 2, 2, 2, 1]
        case .naturalMinor:
            return [2, 1, 2, 2, 1, 2, 2]
        case .harmonicMinor:
            return [2, 1, 2, 2, 1, 3, 1]
        case .melodicMinor:
            return [2, 1, 2, 2, 2, 2, 1]
        }
    }
}

/// Interval between two adjacent scale degrees, labeled like the textbook diagram.
enum ScaleStepInterval: Equatable {
    case half
    case whole
    case augmentedSecond

    init(semitones: Int) {
        switch semitones {
        case 1: self = .half
        case 3: self = .augmentedSecond
        default: self = .whole
        }
    }

    var koreanLabel: String {
        switch self {
        case .half: return "반음"
        case .whole: return "온음"
        case .augmentedSecond: return "증2도"
        }
    }

    var accessibilityLabel: String {
        koreanLabel
    }
}
