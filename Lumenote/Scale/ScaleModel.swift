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

    /// Ascending degrees from the tonic through the octave, spelled for the chosen tonic and kind.
    var degreeSpellings: [String] {
        Self.spellings(tonic: tonicSpelling, kind: kind)
    }

    /// Selectable tonic spellings shared by the scale explorer and diatonic-chord lesson.
    static var selectableNotes: [(spelling: String, displayName: String)] {
        orderedSpellings.map { ($0, formatNoteName($0)) }
    }

    /// Ascending degrees from the tonic through the octave for an arbitrary tonic and kind.
    static func spellings(tonic: String, kind: ScaleKind) -> [String] {
        spellScale(tonic: tonic, tones: kind.formula)
    }

    var degreeDisplayNames: [String] {
        degreeSpellings.map(Self.formatNoteName)
    }

    /// Formula under each staff note, tonic through octave. The octave reads "8(1)".
    var degreeLabels: [String] {
        kind.degreeLabels
    }

    /// Step labels between consecutive degrees.
    var stepIntervals: [ScaleStepInterval] {
        kind.stepIntervals
    }

    /// Tonic through octave on a treble staff starting in the C4 octave.
    var staffNotes: [IntervalStaffNote] {
        Self.staffNotes(tonic: tonicSpelling, kind: kind)
    }

    /// Tonic through octave on a treble staff starting in the C4 octave.
    /// Staff position follows the scale-degree letter, so skipped degrees leave a gap
    /// and chromatic pairs (♭3–3, ♭5–5) share a line.
    static func staffNotes(tonic: String, kind: ScaleKind) -> [IntervalStaffNote] {
        let tones = kind.formula
        let spellings = spellScale(tonic: tonic, tones: tones)
        guard let tonicLetter = letterIndex(of: tonic), spellings.count == tones.count else { return [] }

        // Fixed letter → staff mapping in the C4 octave: C = −2, D = −1, E = 0, …, B = 4.
        let startStep = tonicLetter - 2
        return spellings.enumerated().map { index, spelling in
            IntervalStaffNote(
                id: index,
                spelling: spelling,
                staffStep: startStep + tones[index].letterOffset,
                accidentalSymbol: accidentalSymbol(
                    for: spelling,
                    cancelingNatural: showsCancelingNatural(at: index, spellings: spellings)
                )
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

    /// Spells each formula tone on its scale-degree letter, matching the target pitch class.
    private static func spellScale(tonic: String, tones: [ScaleFormulaTone]) -> [String] {
        guard let tonicLetter = letterIndex(of: tonic) else { return [] }
        let tonicPC = pitchClass(for: tonic)

        return tones.map { tone in
            let letterIdx = (tonicLetter + tone.letterOffset) % 7
            let expectedPC = (tonicPC + tone.semitonesFromTonic) % 12
            let naturalPC = naturalPitchClasses[letterIdx]
            var offset = expectedPC - naturalPC
            if offset > 6 { offset -= 12 }
            if offset < -6 { offset += 12 }
            return spelling(letter: letters[letterIdx], accidentalOffset: offset)
        }
    }

    /// A natural sign cancels an accidental on the previous note when both share a letter (♭3 then 3).
    private static func showsCancelingNatural(at index: Int, spellings: [String]) -> Bool {
        guard index > 0 else { return false }
        let current = spellings[index]
        let previous = spellings[index - 1]
        guard current.first == previous.first else { return false }
        return accidentalSymbol(for: current) == nil && accidentalSymbol(for: previous) != nil
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

    private static func accidentalSymbol(for spelling: String, cancelingNatural: Bool = false) -> String? {
        if spelling.hasSuffix("##") { return "𝄪" }
        if spelling.hasSuffix("#") { return "♯" }
        if spelling.hasSuffix("bb") { return "𝄫" }
        if spelling.hasSuffix("b") { return "♭" }
        if cancelingNatural { return "♮" }
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

enum ScaleCategory: String, CaseIterable, Identifiable {
    case basic
    case pentatonic
    case blues

    var id: String { rawValue }

    var title: String {
        switch self {
        case .basic: "Heptatonic"
        case .pentatonic: "Pentatonic"
        case .blues: "Blues"
        }
    }

    var kinds: [ScaleKind] {
        ScaleKind.allCases.filter { $0.category == self }
    }
}

enum ScaleKind: String, CaseIterable, Identifiable {
    case major
    case naturalMinor
    case harmonicMinor
    case melodicMinor
    case majorPentatonic
    case minorPentatonic
    case majorBlues
    case minorBlues

    var id: String { rawValue }

    var category: ScaleCategory {
        switch self {
        case .major, .naturalMinor, .harmonicMinor, .melodicMinor:
            return .basic
        case .majorPentatonic, .minorPentatonic:
            return .pentatonic
        case .majorBlues, .minorBlues:
            return .blues
        }
    }

    /// The four heptatonic scales used by diatonic chords, quizzes, and learning.
    static var basicCases: [ScaleKind] {
        ScaleCategory.basic.kinds
    }

    var englishTitle: String {
        switch self {
        case .major: return "Major"
        case .naturalMinor: return "Natural Minor"
        case .harmonicMinor: return "Harmonic Minor"
        case .melodicMinor: return "Melodic Minor"
        case .majorPentatonic: return "Major Pentatonic"
        case .minorPentatonic: return "Minor Pentatonic"
        case .majorBlues: return "Major Blues"
        case .minorBlues: return "Minor Blues"
        }
    }

    /// Scale-degree formula from the tonic through the octave.
    /// Accidentals are relative to the major scale, written like chord tones ("♭3").
    /// The octave is labeled "8(1)".
    var degreeLabels: [String] {
        formula.map(\.label)
    }

    /// Semitone distances between consecutive degrees (tonic → octave).
    /// Melodic minor uses the ascending form (raised 6th and 7th).
    var semitoneSteps: [Int] {
        let pitches = formula.map(\.semitonesFromTonic)
        return zip(pitches, pitches.dropFirst()).map { $1 - $0 }
    }

    /// Step labels that distinguish a minor 3rd skip from the harmonic-minor augmented 2nd.
    var stepIntervals: [ScaleStepInterval] {
        zip(formula, formula.dropFirst()).map { ScaleStepInterval.between($0, $1) }
    }

    /// Degree numbers and alterations relative to the major scale, including the octave.
    fileprivate var formula: [ScaleFormulaTone] {
        switch self {
        case .major:
            return Self.tones([(1, 0), (2, 0), (3, 0), (4, 0), (5, 0), (6, 0), (7, 0)])
        case .naturalMinor:
            return Self.tones([(1, 0), (2, 0), (3, -1), (4, 0), (5, 0), (6, -1), (7, -1)])
        case .harmonicMinor:
            return Self.tones([(1, 0), (2, 0), (3, -1), (4, 0), (5, 0), (6, -1), (7, 0)])
        case .melodicMinor:
            return Self.tones([(1, 0), (2, 0), (3, -1), (4, 0), (5, 0), (6, 0), (7, 0)])
        case .majorPentatonic:
            return Self.tones([(1, 0), (2, 0), (3, 0), (5, 0), (6, 0)])
        case .minorPentatonic:
            return Self.tones([(1, 0), (3, -1), (4, 0), (5, 0), (7, -1)])
        case .majorBlues:
            return Self.tones([(1, 0), (2, 0), (3, -1), (3, 0), (5, 0), (6, 0)])
        case .minorBlues:
            return Self.tones([(1, 0), (3, -1), (4, 0), (5, -1), (5, 0), (7, -1)])
        }
    }

    private static func tones(_ specs: [(Int, Int)]) -> [ScaleFormulaTone] {
        specs.map { ScaleFormulaTone(degree: $0.0, alteration: $0.1) }
            + [ScaleFormulaTone(degree: 8, alteration: 0)]
    }
}

/// One scale degree: its number (1...7, or 8 for the octave) and alteration from major.
fileprivate struct ScaleFormulaTone: Equatable {
    let degree: Int
    let alteration: Int

    var label: String {
        if degree == 8 { return "8(1)" }
        let prefix: String
        switch alteration {
        case -2: prefix = "𝄫"
        case -1: prefix = "♭"
        case 1: prefix = "♯"
        case 2: prefix = "𝄪"
        default: prefix = ""
        }
        return prefix + String(degree)
    }

    /// Semitones above the tonic. The octave is 12.
    var semitonesFromTonic: Int {
        let majorSemitones = [0, 2, 4, 5, 7, 9, 11]
        let index = (degree == 8 ? 1 : degree) - 1
        let base = majorSemitones[index] + alteration
        return degree == 8 ? base + 12 : base
    }

    /// Letter steps above the tonic. The octave is one letter past B's cycle (+7).
    var letterOffset: Int {
        degree == 8 ? 7 : degree - 1
    }
}

/// Interval between two adjacent scale degrees, labeled like the textbook diagram.
enum ScaleStepInterval: Equatable {
    case half
    case whole
    case augmentedSecond
    case minorThird

    init(semitones: Int) {
        switch semitones {
        case 1: self = .half
        case 3: self = .augmentedSecond
        default: self = .whole
        }
    }

    /// Names the step from letter span as well as size, so a pentatonic skip is a minor 3rd
    /// and the harmonic-minor ♭6–7 step stays an augmented 2nd.
    fileprivate static func between(_ left: ScaleFormulaTone, _ right: ScaleFormulaTone) -> ScaleStepInterval {
        let semitones = right.semitonesFromTonic - left.semitonesFromTonic
        let letterSpan = right.letterOffset - left.letterOffset
        switch (letterSpan, semitones) {
        case (0, 1), (1, 1):
            return .half
        case (1, 2):
            return .whole
        case (1, 3):
            return .augmentedSecond
        case (2, 3):
            return .minorThird
        default:
            return ScaleStepInterval(semitones: semitones)
        }
    }

    var koreanLabel: String {
        switch self {
        case .half: return "반음".l10n
        case .whole: return "온음".l10n
        case .augmentedSecond:
            return LanguageSettings.shared.language == .english ? "A2" : "증2도"
        case .minorThird:
            return LanguageSettings.shared.language == .english ? "m3" : "단3도"
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
        kind.stepIntervals
    }

    var staffNotes: [IntervalStaffNote] {
        ScaleModel.staffNotes(tonic: tonicSpelling, kind: kind)
    }

    /// Same tonic, next scale kind in the same category. Used when the user adds another card.
    func addingNextKind() -> ScaleCard {
        let kinds = kind.category.kinds
        let index = kinds.firstIndex(of: kind) ?? 0
        let next = kinds[(index + 1) % kinds.count]
        return ScaleCard(tonicSpelling: tonicSpelling, kind: next)
    }

    mutating func setTonic(_ spelling: String) {
        guard ScaleModel.isKnownSpelling(spelling) else { return }
        tonicSpelling = spelling
    }
}
