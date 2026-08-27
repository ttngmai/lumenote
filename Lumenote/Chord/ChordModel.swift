//

import Foundation

/// Interactive chord construction guide: root + chord kind → spelled tones, degrees, and symbols.
@Observable
final class ChordModel {
    var rootSpelling: String = "C" {
        didSet {
            if !ScaleModel.isKnownSpelling(rootSpelling) {
                rootSpelling = "C"
            }
        }
    }

    var kind: ChordKind = .majorTriad

    // MARK: - Derived

    var rootDisplayName: String {
        ScaleModel.formatNoteName(rootSpelling)
    }

    var noteOptions: [(spelling: String, displayName: String)] {
        Self.orderedSpellings.map { ($0, ScaleModel.formatNoteName($0)) }
    }

    var toneSpellings: [String] {
        Self.spellChord(root: rootSpelling, tones: kind.tones)
    }

    var toneDisplayNames: [String] {
        toneSpellings.map { ScaleModel.formatNoteName($0) }
    }

    var degreeLabels: [String] {
        kind.tones.map(\.degreeLabel)
    }

    var notations: [String] {
        kind.notations(rootDisplayName: rootDisplayName)
    }

    /// Root-position chord on a treble staff starting in the C4 octave.
    var staffNotes: [IntervalStaffNote] {
        let spellings = toneSpellings
        guard let rootLetter = Self.letterIndex(of: rootSpelling) else { return [] }

        // Fixed letter → staff mapping in the C4 octave: C = −2, D = −1, E = 0, …, B = 4.
        let startStep = rootLetter - 2
        var notes = kind.tones.enumerated().map { index, tone in
            IntervalStaffNote(
                id: index,
                spelling: spellings[index],
                staffStep: startStep + tone.letterOffset,
                accidentalSymbol: Self.accidentalSymbol(for: spellings[index])
            )
        }

        let minStep = notes.map(\.staffStep).min() ?? 0
        let maxStep = notes.map(\.staffStep).max() ?? 0
        var shift = 0
        while minStep + shift < -4 { shift += 7 }
        while maxStep + shift > 12 { shift -= 7 }
        if shift != 0 {
            notes = notes.map { note in
                IntervalStaffNote(
                    id: note.id,
                    spelling: note.spelling,
                    staffStep: note.staffStep + shift,
                    accidentalSymbol: note.accidentalSymbol
                )
            }
        }
        return notes
    }

    // MARK: - Tables

    private static let orderedSpellings: [String] = [
        "C", "C#", "Db", "D", "D#", "Eb", "E", "Fb", "E#", "F",
        "F#", "Gb", "G", "G#", "Ab", "A", "A#", "Bb", "B", "Cb", "B#",
    ]

    private static let letters: [Character] = ["C", "D", "E", "F", "G", "A", "B"]
    private static let naturalPitchClasses: [Int] = [0, 2, 4, 5, 7, 9, 11]

    private static let letterIndices: [Character: Int] = [
        "C": 0, "D": 1, "E": 2, "F": 3, "G": 4, "A": 5, "B": 6,
    ]

    // MARK: - Spelling

    private static func spellChord(root: String, tones: [ChordTone]) -> [String] {
        guard let rootLetter = letterIndex(of: root) else { return [] }
        let rootPC = ScaleModel.pitchClass(for: root)

        return tones.map { tone in
            let letterIdx = (rootLetter + tone.letterOffset) % 7
            let expectedPC = (rootPC + tone.semitoneOffset) % 12
            let naturalPC = naturalPitchClasses[letterIdx]
            var offset = expectedPC - naturalPC
            if offset > 6 { offset -= 12 }
            if offset < -6 { offset += 12 }
            return spelling(letter: letters[letterIdx], accidentalOffset: offset)
        }
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
}

// MARK: - Chord kind

enum ChordCategory: String {
    case triad
    case seventh

    var koreanTitle: String {
        switch self {
        case .triad: return "3화음"
        case .seventh: return "7화음"
        }
    }
}

enum ChordKind: String, CaseIterable, Identifiable {
    case majorTriad
    case minorTriad
    case augmentedTriad
    case diminishedTriad
    case major7
    case dominant7
    case minorMajor7
    case minor7
    case halfDiminished7
    case diminished7

    var id: String { rawValue }

    var category: ChordCategory {
        switch self {
        case .majorTriad, .minorTriad, .augmentedTriad, .diminishedTriad:
            return .triad
        case .major7, .dominant7, .minorMajor7, .minor7, .halfDiminished7, .diminished7:
            return .seventh
        }
    }

    var koreanTitle: String {
        switch self {
        case .majorTriad: return "장3화음"
        case .minorTriad: return "단3화음"
        case .augmentedTriad: return "증3화음"
        case .diminishedTriad: return "감3화음"
        case .major7: return "장7화음"
        case .dominant7: return "속7화음"
        case .minorMajor7: return "단장7화음"
        case .minor7: return "단7화음"
        case .halfDiminished7: return "반감7화음"
        case .diminished7: return "감7화음"
        }
    }

    /// English names follow the textbook summary table.
    var englishTitle: String {
        switch self {
        case .majorTriad: return "Major Triad"
        case .minorTriad: return "minor Triad"
        case .augmentedTriad: return "Augmented Triad"
        case .diminishedTriad: return "Diminish Triad"
        case .major7: return "Major 7"
        case .dominant7: return "7"
        case .minorMajor7: return "minor Major 7"
        case .minor7: return "minor 7"
        case .halfDiminished7: return "minor 7 ♭5"
        case .diminished7: return "Diminish 7"
        }
    }

    var tones: [ChordTone] {
        switch self {
        case .majorTriad:
            return [.root, .majorThird, .perfectFifth]
        case .minorTriad:
            return [.root, .minorThird, .perfectFifth]
        case .augmentedTriad:
            return [.root, .majorThird, .augmentedFifth]
        case .diminishedTriad:
            return [.root, .minorThird, .diminishedFifth]
        case .major7:
            return [.root, .majorThird, .perfectFifth, .majorSeventh]
        case .dominant7:
            return [.root, .majorThird, .perfectFifth, .minorSeventh]
        case .minorMajor7:
            return [.root, .minorThird, .perfectFifth, .majorSeventh]
        case .minor7:
            return [.root, .minorThird, .perfectFifth, .minorSeventh]
        case .halfDiminished7:
            return [.root, .minorThird, .diminishedFifth, .minorSeventh]
        case .diminished7:
            return [.root, .minorThird, .diminishedFifth, .diminishedSeventh]
        }
    }

    var formulaText: String {
        tones.map(\.degreeLabel).joined(separator: ", ")
    }

    static var triads: [ChordKind] {
        allCases.filter { $0.category == .triad }
    }

    static var sevenths: [ChordKind] {
        allCases.filter { $0.category == .seventh }
    }

    /// Chord symbols with the given root, matching the C-based textbook examples.
    func notations(rootDisplayName root: String) -> [String] {
        switch self {
        case .majorTriad:
            return [root, "\(root)M", "\(root) Maj", "\(root) Major"]
        case .minorTriad:
            return ["\(root)m", "\(root)min", "\(root)minor", "\(root)-"]
        case .augmentedTriad:
            return ["\(root)aug", "\(root)+", "\(root)♯5"]
        case .diminishedTriad:
            return ["\(root)dim", "\(root)°", "\(root)m♭5"]
        case .major7:
            return ["\(root)Maj7", "\(root)Δ7", "\(root)M7"]
        case .dominant7:
            return ["\(root)7"]
        case .minorMajor7:
            return ["\(root)mM7", "\(root)mΔ7", "\(root)-M7", "\(root)-Δ7", "\(root)mMaj7"]
        case .minor7:
            return ["\(root)m7", "\(root)-7", "\(root)min7"]
        case .halfDiminished7:
            return ["\(root)m7♭5", "\(root)-7♭5", "\(root)min7♭5"]
        case .diminished7:
            return ["\(root)dim7", "\(root)°7"]
        }
    }
}

/// One chord member: diatonic letter distance from the root plus the sounding interval.
struct ChordTone: Equatable {
    let letterOffset: Int
    let semitoneOffset: Int
    let degreeLabel: String

    var isAltered: Bool {
        degreeLabel.contains("♭") || degreeLabel.contains("♯")
    }

    static let root = ChordTone(letterOffset: 0, semitoneOffset: 0, degreeLabel: "1")
    static let minorThird = ChordTone(letterOffset: 2, semitoneOffset: 3, degreeLabel: "♭3")
    static let majorThird = ChordTone(letterOffset: 2, semitoneOffset: 4, degreeLabel: "3")
    static let diminishedFifth = ChordTone(letterOffset: 4, semitoneOffset: 6, degreeLabel: "♭5")
    static let perfectFifth = ChordTone(letterOffset: 4, semitoneOffset: 7, degreeLabel: "5")
    static let augmentedFifth = ChordTone(letterOffset: 4, semitoneOffset: 8, degreeLabel: "♯5")
    static let diminishedSeventh = ChordTone(letterOffset: 6, semitoneOffset: 9, degreeLabel: "♭♭7")
    static let minorSeventh = ChordTone(letterOffset: 6, semitoneOffset: 10, degreeLabel: "♭7")
    static let majorSeventh = ChordTone(letterOffset: 6, semitoneOffset: 11, degreeLabel: "7")
}
