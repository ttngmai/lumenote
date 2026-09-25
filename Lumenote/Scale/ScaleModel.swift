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
        Self.selectableNotes
    }

    /// Eight ascending degrees (tonic through octave), spelled for the chosen tonic and kind.
    var degreeSpellings: [String] {
        Self.spellings(tonic: tonicSpelling, kind: kind)
    }

    /// Selectable tonic spellings shared by the scale explorer and diatonic-chord lesson.
    static var selectableNotes: [(spelling: String, displayName: String)] {
        orderedSpellings.map { ($0, formatNoteName($0)) }
    }

    /// Eight ascending degrees (tonic through octave) for an arbitrary tonic and kind.
    static func spellings(tonic: String, kind: ScaleKind) -> [String] {
        spellScale(tonic: tonic, steps: kind.semitoneSteps)
    }

    var degreeDisplayNames: [String] {
        degreeSpellings.map(Self.formatNoteName)
    }

    /// Formula under each staff note, tonic through octave. The octave reads "8(1)".
    var degreeLabels: [String] {
        kind.degreeLabels
    }

    /// Step labels between consecutive degrees (7 intervals for an octave scale).
    var stepIntervals: [ScaleStepInterval] {
        kind.semitoneSteps.map(ScaleStepInterval.init(semitones:))
    }

    /// Tonic through octave on a treble staff starting in the C4 octave.
    var staffNotes: [IntervalStaffNote] {
        Self.staffNotes(tonic: tonicSpelling, kind: kind)
    }

    /// Tonic through octave on a treble staff starting in the C4 octave.
    static func staffNotes(tonic: String, kind: ScaleKind) -> [IntervalStaffNote] {
        let spellings = spellings(tonic: tonic, kind: kind)
        guard let tonicLetter = letterIndex(of: tonic) else { return [] }

        // Fixed letter → staff mapping in the C4 octave: C = −2, D = −1, E = 0, …, B = 4.
        let startStep = tonicLetter - 2
        return spellings.enumerated().map { index, spelling in
            IntervalStaffNote(
                id: index,
                spelling: spelling,
                staffStep: startStep + index,
                accidentalSymbol: accidentalSymbol(for: spelling)
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

    /// Scale-degree formula for the eight staff notes (tonic through octave).
    /// Accidentals are relative to the major scale, written like chord tones ("♭3").
    /// The octave is labeled "8(1)".
    var degreeLabels: [String] {
        let degrees: [String]
        switch self {
        case .major:
            degrees = ["1", "2", "3", "4", "5", "6", "7"]
        case .naturalMinor:
            degrees = ["1", "2", "♭3", "4", "5", "♭6", "♭7"]
        case .harmonicMinor:
            degrees = ["1", "2", "♭3", "4", "5", "♭6", "7"]
        case .melodicMinor:
            degrees = ["1", "2", "♭3", "4", "5", "6", "7"]
        }
        return degrees + ["8(1)"]
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

/// One scale card on the scale explorer. The screen shows up to `maximumCount` cards.
struct ScaleCard: Identifiable, Equatable {
    static let maximumCount = 4

    let id: UUID
    var tonicSpelling: String
    var kind: ScaleKind

    init(id: UUID = UUID(), tonicSpelling: String = "C", kind: ScaleKind = .major) {
        self.id = id
        self.tonicSpelling = ScaleModel.isKnownSpelling(tonicSpelling) ? tonicSpelling : "C"
        self.kind = kind
    }

    var tonicDisplayName: String {
        ScaleModel.formatNoteName(tonicSpelling)
    }

    var degreeDisplayNames: [String] {
        ScaleModel.spellings(tonic: tonicSpelling, kind: kind).map(ScaleModel.formatNoteName)
    }

    var degreeLabels: [String] {
        kind.degreeLabels
    }

    var stepIntervals: [ScaleStepInterval] {
        kind.semitoneSteps.map(ScaleStepInterval.init(semitones:))
    }

    var staffNotes: [IntervalStaffNote] {
        ScaleModel.staffNotes(tonic: tonicSpelling, kind: kind)
    }

    /// Same tonic, next scale kind. Used when the user adds another card.
    func addingNextKind() -> ScaleCard {
        let kinds = ScaleKind.allCases
        let index = kinds.firstIndex(of: kind) ?? 0
        let next = kinds[(index + 1) % kinds.count]
        return ScaleCard(tonicSpelling: tonicSpelling, kind: next)
    }

    mutating func setTonic(_ spelling: String) {
        guard ScaleModel.isKnownSpelling(spelling) else { return }
        tonicSpelling = spelling
    }
}
