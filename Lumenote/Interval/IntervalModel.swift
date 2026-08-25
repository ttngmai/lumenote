//

import Foundation

/// Interactive interval explorer: root and target note spellings within one octave.
///
/// Interval names are derived from root and target **spellings** (letter + accidental),
/// so enharmonic pairs such as minor 2nd vs augmented unison follow the chosen spellings.
@Observable
final class IntervalModel {
    /// Chromatic spelling of the root note (e.g. `"C"`, `"C#"`, `"Db"`).
    var rootSpelling: String = "C" {
        didSet {
            if !Self.isKnownSpelling(rootSpelling) {
                rootSpelling = "C"
            }
        }
    }

    /// Chromatic spelling of the target note (e.g. `"E"`, `"Fb"`, `"E#"`).
    var targetSpelling: String = "E" {
        didSet {
            if !Self.isKnownSpelling(targetSpelling) {
                targetSpelling = "E"
            }
        }
    }

    // MARK: - Derived

    var rootPitchClass: Int {
        Self.pitchClass(for: rootSpelling)
    }

    var targetPitchClass: Int {
        Self.pitchClass(for: targetSpelling)
    }

    /// Semitone distance ascending from root to target, 0…11 (within one octave).
    var ascendingSemitoneDistance: Int {
        (targetPitchClass - rootPitchClass + 12) % 12
    }

    /// Semitone distance descending from root to target, 0…11 (within one octave).
    var descendingSemitoneDistance: Int {
        (rootPitchClass - targetPitchClass + 12) % 12
    }

    var rootDisplayName: String {
        Self.formatNoteName(rootSpelling)
    }

    var targetDisplayName: String {
        Self.formatNoteName(targetSpelling)
    }

    /// Korean name for the ascending interval (root → target upward).
    var ascendingIntervalName: String {
        Self.koreanIntervalName(
            root: rootSpelling,
            target: targetSpelling,
            semitones: ascendingSemitoneDistance
        )
    }

    /// English name for the ascending interval (root → target upward).
    var ascendingIntervalNameEnglish: String {
        Self.englishIntervalName(
            root: rootSpelling,
            target: targetSpelling,
            semitones: ascendingSemitoneDistance
        )
    }

    /// Korean name for the descending interval (named lower → upper on the staff).
    var descendingIntervalName: String {
        Self.koreanIntervalName(
            root: targetSpelling,
            target: rootSpelling,
            semitones: descendingSemitoneDistance
        )
    }

    /// English name for the descending interval (named lower → upper on the staff).
    var descendingIntervalNameEnglish: String {
        Self.englishIntervalName(
            root: targetSpelling,
            target: rootSpelling,
            semitones: descendingSemitoneDistance
        )
    }

    /// Selectable note spellings for root and target pickers (fixed display order).
    var noteOptions: [(spelling: String, displayName: String)] {
        Self.orderedSpellings.map { ($0, Self.formatNoteName($0)) }
    }

    /// Root then target on a treble staff, ascending by letter.
    var ascendingStaffNotes: [IntervalStaffNote] {
        Self.staffNotes(
            rootSpelling: rootSpelling,
            targetSpelling: targetSpelling,
            direction: .ascending
        )
    }

    /// Root then target on a treble staff, descending by letter.
    var descendingStaffNotes: [IntervalStaffNote] {
        Self.staffNotes(
            rootSpelling: rootSpelling,
            targetSpelling: targetSpelling,
            direction: .descending
        )
    }

    // MARK: - Tables

    /// Display order for pickers: naturals with both sharp and flat enharmonics where they exist.
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

    /// Major/perfect reference semitones for diatonic numbers 1…8.
    private static let referenceSemitones: [Int] = [0, 0, 2, 4, 5, 7, 9, 11, 12]

    private static let perfectIntervalNumbers: Set<Int> = [1, 4, 5, 8]

    private static let letterIndices: [Character: Int] = [
        "C": 0, "D": 1, "E": 2, "F": 3, "G": 4, "A": 5, "B": 6
    ]

    /// Fallback when spelling-based naming cannot resolve (should not occur for chromatic tables).
    private static let fallbackIntervalNames: [String] = [
        "완전1도",
        "단2도",
        "장2도",
        "단3도",
        "장3도",
        "완전4도",
        "증4도",
        "완전5도",
        "단6도",
        "장6도",
        "단7도",
        "장7도",
        "완전8도",
    ]

    private static let fallbackIntervalNamesEnglish: [String] = [
        "Perfect Unison",
        "Minor 2nd",
        "Major 2nd",
        "Minor 3rd",
        "Major 3rd",
        "Perfect 4th",
        "Augmented 4th",
        "Perfect 5th",
        "Minor 6th",
        "Major 6th",
        "Minor 7th",
        "Major 7th",
        "Perfect Octave",
    ]

    // MARK: - Spelling-aware interval naming

    private static func koreanIntervalName(root: String, target: String, semitones: Int) -> String {
        guard let number = diatonicNumber(root: root, target: target),
              let offset = qualityOffset(intervalNumber: number, semitones: semitones),
              let name = koreanName(intervalNumber: number, offset: offset)
        else {
            return fallbackIntervalNames[clampDistance(semitones)]
        }
        return name
    }

    private static func englishIntervalName(root: String, target: String, semitones: Int) -> String {
        guard let number = diatonicNumber(root: root, target: target),
              let offset = qualityOffset(intervalNumber: number, semitones: semitones),
              let name = englishName(intervalNumber: number, offset: offset)
        else {
            return fallbackIntervalNamesEnglish[clampDistance(semitones)]
        }
        return name
    }

    private static func diatonicNumber(root: String, target: String) -> Int? {
        guard let rootLetter = letterIndex(of: root),
              let targetLetter = letterIndex(of: target)
        else { return nil }
        let steps = (targetLetter - rootLetter + 7) % 7
        return steps + 1
    }

    private static func qualityOffset(intervalNumber: Int, semitones: Int) -> Int? {
        guard intervalNumber >= 1, intervalNumber <= 8 else { return nil }
        return semitones - referenceSemitones[intervalNumber]
    }

    private static func koreanName(intervalNumber: Int, offset: Int) -> String? {
        if perfectIntervalNumbers.contains(intervalNumber) {
            switch offset {
            case -1 where intervalNumber != 1:
                return "감\(intervalNumber)도"
            case 0:
                switch intervalNumber {
                case 1: return "완전1도"
                case 8: return "완전8도"
                default: return "완전\(intervalNumber)도"
                }
            case 1:
                if intervalNumber == 8 { return "증7도" }
                return "증\(intervalNumber)도"
            default:
                return nil
            }
        }

        switch offset {
        case -2: return "감\(intervalNumber)도"
        case -1: return "단\(intervalNumber)도"
        case 0: return "장\(intervalNumber)도"
        case 1: return "증\(intervalNumber)도"
        default: return nil
        }
    }

    private static func englishName(intervalNumber: Int, offset: Int) -> String? {
        let ordinal = englishOrdinal(intervalNumber: intervalNumber)

        if perfectIntervalNumbers.contains(intervalNumber) {
            switch offset {
            case -1 where intervalNumber != 1:
                return "Diminished \(ordinal)"
            case 0:
                switch intervalNumber {
                case 1: return "Perfect Unison"
                case 8: return "Perfect Octave"
                default: return "Perfect \(ordinal)"
                }
            case 1:
                if intervalNumber == 8 { return "Augmented 7th" }
                return "Augmented \(ordinal)"
            default:
                return nil
            }
        }

        switch offset {
        case -2: return "Diminished \(ordinal)"
        case -1: return "Minor \(ordinal)"
        case 0: return "Major \(ordinal)"
        case 1: return "Augmented \(ordinal)"
        default: return nil
        }
    }

    private static func englishOrdinal(intervalNumber: Int) -> String {
        switch intervalNumber {
        case 1: return "Unison"
        case 2: return "2nd"
        case 3: return "3rd"
        case 4: return "4th"
        case 5: return "5th"
        case 6: return "6th"
        case 7: return "7th"
        case 8: return "Octave"
        default: return "\(intervalNumber)th"
        }
    }

    private static func letterIndex(of spelling: String) -> Int? {
        guard let first = spelling.first else { return nil }
        return letterIndices[first]
    }

    // MARK: - Staff placement

    private enum StaffDirection {
        case ascending
        case descending
    }

    private static func staffNotes(
        rootSpelling: String,
        targetSpelling: String,
        direction: StaffDirection
    ) -> [IntervalStaffNote] {
        guard let rootLetter = letterIndex(of: rootSpelling),
              let targetLetter = letterIndex(of: targetSpelling)
        else { return [] }

        // Fixed letter → staff mapping in the C4 octave: C = −2, D = −1, E = 0, …, B = 4.
        // Only ±7 (octave) shifts are allowed afterward so the written letter never changes.
        var rootStep = rootLetter - 2
        var targetStep: Int
        switch direction {
        case .ascending:
            let up = (targetLetter - rootLetter + 7) % 7
            targetStep = rootStep + up
        case .descending:
            let down = (rootLetter - targetLetter + 7) % 7
            if down == 0, pitchClass(for: rootSpelling) != pitchClass(for: targetSpelling) {
                // Same letter, different pitch (e.g. E♭ → E as a 7th): drop one octave.
                targetStep = rootStep - 7
            } else {
                targetStep = rootStep - down
            }
        }

        while min(rootStep, targetStep) < -4 {
            rootStep += 7
            targetStep += 7
        }
        while max(rootStep, targetStep) > 12 {
            rootStep -= 7
            targetStep -= 7
        }

        let sharesStaffDegree = rootStep == targetStep
        return [
            IntervalStaffNote(
                id: 0,
                spelling: rootSpelling,
                staffStep: rootStep,
                accidentalSymbol: accidentalSymbol(for: rootSpelling)
            ),
            IntervalStaffNote(
                id: 1,
                spelling: targetSpelling,
                staffStep: targetStep,
                accidentalSymbol: staffAccidentalSymbol(
                    for: targetSpelling,
                    previousSpelling: rootSpelling,
                    sharesStaffDegree: sharesStaffDegree
                )
            ),
        ]
    }

    private static func accidentalSymbol(for spelling: String) -> String? {
        if spelling.hasSuffix("##") { return "𝄪" }
        if spelling.hasSuffix("#") { return "♯" }
        if spelling.hasSuffix("bb") { return "𝄫" }
        if spelling.hasSuffix("b") { return "♭" }
        return nil
    }

    /// Courtesy accidental for the second note when it shares a staff degree with the first.
    /// Example: E♭ then E on the same line needs ♮ on E.
    private static func staffAccidentalSymbol(
        for spelling: String,
        previousSpelling: String,
        sharesStaffDegree: Bool
    ) -> String? {
        let own = accidentalSymbol(for: spelling)
        guard sharesStaffDegree else { return own }
        if accidentalSymbol(for: previousSpelling) != nil, own == nil {
            return "♮"
        }
        return own
    }

    // MARK: - Helpers

    static func pitchClass(for spelling: String) -> Int {
        pitchClassBySpelling[spelling] ?? 0
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

    static func clampDistance(_ value: Int) -> Int {
        min(12, max(0, value))
    }
}

/// One notehead placement on a treble staff for the interval explorer.
struct IntervalStaffNote: Identifiable, Equatable {
    let id: Int
    let spelling: String
    /// Half-space steps above the bottom staff line (E4 = 0, F4 = 1, C4 = −2).
    let staffStep: Int
    /// ♯ / ♭ / … drawn to the left of the notehead, if any.
    let accidentalSymbol: String?
}
