//

import Foundation
import SwiftUI

/// Interactive Circle of Fifths model, based on Rand Scullard's design:
/// https://randscullard.com/CircleOfFifths/
@Observable
final class CircleOfFifthsModel {
    var selectedTonic: Tonic = .c
    var selectedMode: MusicalMode = .ionian

    /// Clock positions 1…12 → note names for the current tonic/mode.
    var noteNames: [Int: String] {
        let signature = Self.keySignatures[keySignatureIndex] ?? Self.keySignatures[0]!
        var result: [Int: String] = [:]
        for position in 1...12 {
            result[position] = signature[position - 1]
        }
        return result
    }

    /// Outer-ring spellings. Dual-common enharmonics are both listed (C♯ above D♭).
    var displayedOuterSpellings: [Int: [String]] {
        var result: [Int: [String]] = [:]
        for position in 1...12 {
            let pair = Tonic.commonSpellings(atLydianStart: position)
            if pair.count >= 2 {
                result[position] = pair.map(\.rawValue)
            } else {
                let raw = Tonic.commonSpelling(of: noteNames[position] ?? "")
                result[position] = raw.isEmpty ? [] : [raw]
            }
        }
        return result
    }

    /// Inner-ring relative-minor spellings, matching `displayedOuterSpellings`.
    var displayedRelativeMinorSpellings: [Int: [String]] {
        var result: [Int: [String]] = [:]
        for position in 1...12 {
            let relatives = (displayedOuterSpellings[position] ?? []).compactMap(Self.relativeMinorSpelling(of:))
            if !relatives.isEmpty {
                result[position] = relatives
            }
        }
        return result
    }

    /// Seven consecutive active (diatonic) clock positions, in clockwise order.
    var activePositions: [Int] {
        let start = selectedTonic.lydianStartPosition + selectedMode.offset
        return (0..<7).map { Self.normalizedClock(start + $0) }
    }

    var activePositionSet: Set<Int> {
        Set(activePositions)
    }

    /// Clock position → Roman-numeral degree label (only for active notes).
    var degreeLabels: [Int: String] {
        var degrees = Self.lydianDegrees
        for _ in 0..<abs(selectedMode.offset) {
            if let last = degrees.popLast() {
                degrees.insert(last, at: 0)
            }
        }

        var result: [Int: String] = [:]
        for (ordinal, position) in activePositions.enumerated() {
            result[position] = Self.makeDegreeSymbol(degree: degrees[ordinal], ordinal: ordinal)
        }
        return result
    }

    /// Degree labels keyed by screen-clock wedge. Stable when only the tonic changes.
    var screenDegreeLabels: [Int: String] {
        Dictionary(uniqueKeysWithValues: degreeLabels.map { position, label in
            (screenClock(forModelPosition: position), label)
        })
    }

    /// Clock position of the tonic (aligned to the fixed 12 o'clock pointer after rotation).
    var tonicArrowPosition: Int {
        selectedTonic.lydianStartPosition
    }

    /// Where the Major/Minor/Dim quality segment begins on the active arc.
    var chordRingStartPosition: Int {
        Self.normalizedClock(selectedTonic.lydianStartPosition + selectedMode.offset)
    }

    /// Chord quality for an active model clock position, if any.
    func chordQuality(at position: Int) -> ChordQuality? {
        guard let ordinal = activePositions.firstIndex(of: position) else { return nil }
        return ChordQuality.quality(forOrdinal: ordinal)
    }

    /// Chord quality for a fixed screen clock wedge when the tonic is pinned at 12 o'clock.
    /// Screen position 12 is the tonic; qualities depend only on the selected mode.
    func screenChordQuality(atScreenClock position: Int) -> ChordQuality? {
        let stepsFromTonic = position % 12 // 12 → 0, 1 → 1, …
        for ordinal in 0..<7 {
            let steps = Self.normalizedClock(12 + selectedMode.offset + ordinal) % 12
            if steps == stepsFromTonic {
                return ChordQuality.quality(forOrdinal: ordinal)
            }
        }
        return nil
    }

    /// Rotation (degrees) that brings the selected tonic to 12 o'clock.
    var tonicAlignmentRotationDegrees: Double {
        -Double(tonicArrowPosition % 12) * 30.0
    }

    /// Select the tonic whose Lydian start matches `position`.
    /// Never picks a rarely used spelling when a common enharmonic exists.
    /// Among common spellings, prefers the same sharp/flat family as the current tonic.
    func selectTonic(forLydianStart position: Int) {
        let normalized = Self.normalizedClock(position)
        let matches = Tonic.allCases.filter { $0.lydianStartPosition == normalized }
        let common = matches.filter { !$0.isObscure }
        let candidates = common.isEmpty ? matches : common

        if candidates.contains(selectedTonic) { return }

        if let preference = selectedTonic.accidentalPreference,
           let matchingFamily = candidates.first(where: { $0.accidentalPreference == preference }) {
            selectedTonic = matchingFamily
            return
        }

        if selectedTonic.accidentalPreference == nil,
           let natural = candidates.first(where: { $0.accidentalPreference == nil }) {
            selectedTonic = natural
            return
        }

        if let preferred = candidates.first {
            selectedTonic = preferred
        }
    }

    /// Clock position implied by a circle rotation in degrees.
    static func lydianStartPosition(forRotationDegrees degrees: Double) -> Int {
        var steps = Int(((-degrees / 30.0).rounded())) % 12
        if steps < 0 { steps += 12 }
        return steps == 0 ? 12 : steps
    }

    var keySignatureIndex: Int {
        selectedTonic.lydianSignature + selectedMode.offset
    }

    /// Common enharmonic pair for the selected cell, e.g. C♯ · D♭.
    var selectedTonicDisplayName: String {
        let spellings = Tonic.commonSpellings(atLydianStart: selectedTonic.lydianStartPosition)
        if spellings.count >= 2 {
            return spellings.map(\.displayName).joined(separator: " · ")
        }
        return selectedTonic.displayName
    }

    /// Tonics whose key signatures belong in the hub (one, or a dual-common pair).
    var displayedKeyTonics: [Tonic] {
        let spellings = Tonic.commonSpellings(atLydianStart: selectedTonic.lydianStartPosition)
        return spellings.count >= 2 ? spellings : [selectedTonic]
    }

    var sharpsOrFlatsDescription: String {
        displayedKeyTonics.map { tonic in
            let label = Self.signatureCountDescription(tonic.lydianSignature + selectedMode.offset)
            return displayedKeyTonics.count > 1 ? "\(tonic.displayName) \(label)" : label
        }
        .joined(separator: ", ")
    }

    var selectedKeyTitle: String {
        "\(selectedTonicDisplayName) \(selectedMode.shortName)"
    }

    /// Key-signature accidentals in writing order, placed on a treble staff.
    /// Beyond seven, an accidental doubles the one already occupying its slot.
    var keySignatureAccidentals: [KeySignatureAccidental] {
        keySignatureAccidentals(for: selectedTonic)
    }

    /// One staff per displayed tonic (C♯ above D♭ when both are common).
    var hubKeySignatures: [HubKeySignature] {
        displayedKeyTonics.map { tonic in
            HubKeySignature(id: tonic.rawValue, accidentals: keySignatureAccidentals(for: tonic))
        }
    }

    func keySignatureAccidentals(for tonic: Tonic) -> [KeySignatureAccidental] {
        let index = tonic.lydianSignature + selectedMode.offset
        guard index != 0 else { return [] }

        let isSharp = index > 0
        let steps = isSharp ? Self.sharpStaffSteps : Self.flatStaffSteps
        var symbols = [String?](repeating: nil, count: 7)
        for ordinal in 0..<min(abs(index), 14) {
            let isDouble = ordinal >= 7
            symbols[ordinal % 7] = isSharp
                ? (isDouble ? "𝄪" : "♯")
                : (isDouble ? "𝄫" : "♭")
        }

        return (0..<7).compactMap { slot in
            guard let symbol = symbols[slot] else { return nil }
            return KeySignatureAccidental(order: slot, symbol: symbol, staffStep: steps[slot])
        }
    }

    private static func signatureCountDescription(_ index: Int) -> String {
        if index == 0 {
            return "조표 없음"
        } else if index > 0 {
            return "♯ \(index)개"
        } else {
            return "♭ \(abs(index))개"
        }
    }

    /// Scale tones (degree + note) in ascending order from the tonic.
    var scaleTones: [ScaleTone] {
        let names = noteNames
        let degrees = degreeLabels
        let rows: [(pc: Int, position: Int, roman: String, note: String)] = activePositions.compactMap { position in
            guard let name = names[position],
                  let roman = degrees[position],
                  let pc = Self.pitchClass(of: name) else {
                return nil
            }
            return (pc, position, roman, Tonic.formatNoteName(name))
        }

        guard let tonicPC = Self.pitchClass(of: selectedTonic.rawValue) else {
            return rows.enumerated().map { index, row in
                ScaleTone(
                    scaleDegree: index + 1,
                    degree: row.roman,
                    note: row.note,
                    clockPosition: row.position
                )
            }
        }

        return rows
            .sorted { lhs, rhs in
                let l = (lhs.pc - tonicPC + 12) % 12
                let r = (rhs.pc - tonicPC + 12) % 12
                return l < r
            }
            .enumerated()
            .map { index, row in
                ScaleTone(
                    scaleDegree: index + 1,
                    degree: row.roman,
                    note: row.note,
                    clockPosition: row.position
                )
            }
    }

    /// Scale notes in ascending order from the tonic.
    var diatonicScaleNotes: [String] {
        scaleTones.map(\.note)
    }

    /// Scale notes (tonic through the octave) placed on a treble staff from C4’s octave.
    var scaleStaffNotes: [ScaleStaffNote] {
        let tones = scaleTones
        guard let first = tones.first,
              let tonicLetter = Self.letterIndex(of: first.note) else { return [] }

        let startStep = tonicLetter - 2
        let degreeSymbols = Dictionary(
            uniqueKeysWithValues: selectedMode.characterProfile.formula.map { ($0.scaleDegree, $0.symbol) }
        )
        var notes: [ScaleStaffNote] = []
        for (index, tone) in tones.enumerated() {
            guard let letter = Self.letterIndex(of: tone.note) else { continue }
            let offset = (letter - tonicLetter + 7) % 7
            notes.append(
                ScaleStaffNote(
                    id: index,
                    name: tone.note,
                    staffStep: startStep + offset,
                    degreeLabel: degreeSymbols[tone.scaleDegree] ?? "\(tone.scaleDegree)",
                    showsCaption: true
                )
            )
        }
        notes.append(
            ScaleStaffNote(
                id: tones.count,
                name: first.note,
                staffStep: startStep + 7,
                degreeLabel: "",
                showsCaption: false
            )
        )
        return notes
    }

    /// Mode character block: one-line comparison, formula, and characteristic note.
    var modeCharacter: ModeCharacter {
        let profile = selectedMode.characterProfile
        let tones = scaleTones

        func tone(atScaleDegree degree: Int) -> ScaleTone? {
            tones.first { $0.scaleDegree == degree }
        }

        let characteristicNote: ModeCharacter.Highlight?
        if let degree = profile.characteristicNoteDegree,
           let tone = tone(atScaleDegree: degree) {
            characteristicNote = ModeCharacter.Highlight(
                text: "\(tone.note) (\(profile.characteristicIntervalLabel))",
                scaleDegree: degree,
                clockPosition: tone.clockPosition
            )
        } else {
            characteristicNote = nil
        }

        return ModeCharacter(
            summary: profile.summary,
            formula: profile.formula,
            characteristicNote: characteristicNote
        )
    }

    /// Flip to the enharmonic alternate spelling when one exists
    /// (e.g. C♯ ↔ D♭, B♯ ↔ C, C♭ ↔ B).
    func toggleTonicAccidental() {
        guard let alternate = selectedTonic.enharmonicAlternate else { return }
        selectedTonic = alternate
    }

    /// Model-clock positions temporarily emphasized (e.g. characteristic note tap).
    var emphasizedClockPositions: Set<Int> = []
    /// Scale degrees 1…7 temporarily emphasized in the Scale table / formula.
    var emphasizedScaleDegrees: Set<Int> = []

    func emphasize(scaleDegree: Int, clockPosition: Int) {
        emphasizedScaleDegrees = [scaleDegree]
        emphasizedClockPositions = [clockPosition]
    }

    func emphasize(scaleDegrees: Set<Int>) {
        emphasizedScaleDegrees = scaleDegrees
        emphasizedClockPositions = Set(
            scaleTones
                .filter { scaleDegrees.contains($0.scaleDegree) }
                .map(\.clockPosition)
        )
    }

    func clearEmphasis() {
        emphasizedScaleDegrees = []
        emphasizedClockPositions = []
    }

    /// Screen-clock wedge for a model-clock position when tonic is pinned at 12.
    func screenClock(forModelPosition position: Int) -> Int {
        Self.normalizedClock(position - tonicArrowPosition)
    }

    /// Model-clock position currently shown in a fixed screen wedge.
    func modelClock(forScreenClock position: Int) -> Int {
        Self.normalizedClock(position + tonicArrowPosition)
    }

    // MARK: - Types

    /// One hub staff, identified by the tonic it represents.
    struct HubKeySignature: Identifiable, Equatable {
        let id: String
        let accidentals: [KeySignatureAccidental]
    }

    /// Picker cell: a single tonic, or a dual-common enharmonic pair.
    struct TonicPickerOption: Identifiable, Equatable {
        let members: [Tonic]

        var id: String { members.map(\.rawValue).joined(separator: "|") }

        var displayName: String {
            members.map(\.displayName).joined(separator: " · ")
        }

        var representative: Tonic { members[0] }

        func contains(_ tonic: Tonic) -> Bool {
            members.contains(tonic)
        }
    }

    /// One accidental of a key signature on a treble staff.
    struct KeySignatureAccidental: Identifiable, Equatable {
        /// Position in the conventional writing order (F, C, G, D, A, E, B).
        let order: Int
        let symbol: String
        /// Half-space steps above the bottom staff line (E4 = 0, F4 = 1, …).
        let staffStep: Int

        var id: Int { order }
    }

    struct ScaleTone: Identifiable, Equatable {
        let scaleDegree: Int
        let degree: String
        let note: String
        let clockPosition: Int

        var id: String { "\(scaleDegree)-\(degree)-\(note)" }
    }

    /// One scale pitch on a treble staff, plus the repeating tonic at the octave.
    struct ScaleStaffNote: Identifiable, Equatable {
        let id: Int
        let name: String
        /// Half-space steps above the bottom staff line (E4 = 0, F4 = 1, C4 = −2).
        let staffStep: Int
        /// Mode formula label (e.g. "1", "♭3", "♯4"). Empty when `showsCaption` is false.
        let degreeLabel: String
        /// The octave tonic is drawn without a name or degree caption.
        let showsCaption: Bool

        var accidentalGlyph: String? {
            let rest = String(name.dropFirst())
            return rest.isEmpty ? nil : rest
        }
    }

    struct ModeCharacter: Equatable {
        let summary: String
        let formula: [FormulaTone]
        let characteristicNote: Highlight?

        struct FormulaTone: Identifiable, Equatable {
            let scaleDegree: Int
            let symbol: String
            let isEmphasized: Bool

            var id: Int { scaleDegree }
        }

        struct Highlight: Equatable {
            let text: String
            let scaleDegree: Int
            let clockPosition: Int
        }
    }

    struct ModeCharacterProfile {
        let summary: String
        let formula: [ModeCharacter.FormulaTone]
        /// Nil for Ionian / Aeolian (no distinctive note beyond the parent scale).
        let characteristicNoteDegree: Int?
        let characteristicIntervalLabel: String
    }

    enum Tonic: String, CaseIterable, Identifiable {
        case bSharp = "B#"
        case eSharp = "E#"
        case aSharp = "A#"
        case dSharp = "D#"
        case gSharp = "G#"
        case cSharp = "C#"
        case fSharp = "F#"
        case b = "B"
        case e = "E"
        case a = "A"
        case d = "D"
        case g = "G"
        case c = "C"
        case f = "F"
        case bFlat = "Bb"
        case eFlat = "Eb"
        case aFlat = "Ab"
        case dFlat = "Db"
        case gFlat = "Gb"
        case cFlat = "Cb"
        case fFlat = "Fb"

        var id: String { rawValue }

        var displayName: String {
            Self.formatNoteName(rawValue)
        }

        /// Sharp / flat family implied by this spelling, if any.
        var accidentalPreference: AccidentalPreference? {
            let accidentals = String(rawValue.dropFirst())
            if accidentals.contains("#") { return .sharp }
            if accidentals.contains("b") { return .flat }
            return nil
        }

        /// Other spelling at the same circle position, if any (e.g. C ↔ B♯, F♯ ↔ G♭).
        var enharmonicAlternate: Tonic? {
            Self.allCases.first {
                $0.lydianStartPosition == lydianStartPosition && $0 != self
            }
        }

        /// Dual-common pairs stay in one picker button, so the swap control is unused.
        var canToggleEnharmonicSpelling: Bool {
            let pair = Tonic.commonSpellings(atLydianStart: lydianStartPosition)
            guard pair.count < 2 else { return false }
            guard let alternate = enharmonicAlternate else { return false }
            return !alternate.isObscure
        }

        /// Rare tonics omitted from the picker and enharmonic swap; rewritten on the circle.
        var isObscure: Bool {
            switch self {
            case .bSharp, .eSharp, .aSharp, .dSharp, .gSharp, .fFlat:
                return true
            default:
                return false
            }
        }

        /// Rewrites a rare spelling to the everyday enharmonic (F♭ → E, B♯ → C).
        static func commonSpelling(of name: String) -> String {
            guard let tonic = Tonic(rawValue: name), tonic.isObscure else { return name }
            guard let alternate = tonic.enharmonicAlternate, !alternate.isObscure else { return name }
            return alternate.rawValue
        }

        /// Common spellings that share a clock cell, sharp/natural then flat (C♯, D♭).
        static func commonSpellings(atLydianStart position: Int) -> [Tonic] {
            allCases
                .filter { $0.lydianStartPosition == position && !$0.isObscure }
                .sorted { displayRank($0) < displayRank($1) }
        }

        private static func displayRank(_ tonic: Tonic) -> Int {
            switch tonic.accidentalPreference {
            case .sharp: return 0
            case nil: return 1
            case .flat: return 2
            }
        }

        /// Clock position where Lydian of this tonic begins.
        var lydianStartPosition: Int {
            switch self {
            case .bSharp: return 12
            case .eSharp: return 11
            case .aSharp: return 10
            case .dSharp: return 9
            case .gSharp: return 8
            case .cSharp: return 7
            case .fSharp: return 6
            case .b: return 5
            case .e: return 4
            case .a: return 3
            case .d: return 2
            case .g: return 1
            case .c: return 12
            case .f: return 11
            case .bFlat: return 10
            case .eFlat: return 9
            case .aFlat: return 8
            case .dFlat: return 7
            case .gFlat: return 6
            case .cFlat: return 5
            case .fFlat: return 4
            }
        }

        /// Key-signature index for this tonic in Lydian.
        var lydianSignature: Int {
            switch self {
            case .bSharp: return 13
            case .eSharp: return 12
            case .aSharp: return 11
            case .dSharp: return 10
            case .gSharp: return 9
            case .cSharp: return 8
            case .fSharp: return 7
            case .b: return 6
            case .e: return 5
            case .a: return 4
            case .d: return 3
            case .g: return 2
            case .c: return 1
            case .f: return 0
            case .bFlat: return -1
            case .eFlat: return -2
            case .aFlat: return -3
            case .dFlat: return -4
            case .gFlat: return -5
            case .cFlat: return -6
            case .fFlat: return -7
            }
        }

        static func formatNoteName(_ name: String) -> String {
            if name.hasSuffix("##") {
                return String(name.dropLast(2)) + "𝄪"
            }
            if name.hasSuffix("bb") {
                return String(name.dropLast(2)) + "𝄫"
            }
            if name.hasSuffix("#") {
                return String(name.dropLast()) + "♯"
            }
            if name.hasSuffix("b") {
                return String(name.dropLast()) + "♭"
            }
            return name
        }

        /// Chromatic picker order from C: C, C♯, D♭, D, … (B♯ follows B; C♭ wraps after B).
        static var chromaticPickerOrder: [Tonic] {
            allCases
                .filter { !$0.isObscure }
                .sorted { $0.chromaticPickerRank < $1.chromaticPickerRank }
        }

        /// Picker rows with dual-common enharmonics grouped (C♯ · D♭).
        static var chromaticPickerOptions: [TonicPickerOption] {
            var seenPositions = Set<Int>()
            var options: [TonicPickerOption] = []
            for tonic in chromaticPickerOrder {
                let position = tonic.lydianStartPosition
                guard seenPositions.insert(position).inserted else { continue }
                let spellings = commonSpellings(atLydianStart: position)
                options.append(TonicPickerOption(members: spellings.isEmpty ? [tonic] : spellings))
            }
            return options
        }

        /// Letter C=0 … B=6, accidental ♭=−1 / natural=0 / ♯=+1. C♭ uses index 7 so the grid starts at C.
        private var chromaticPickerRank: Int {
            let letters: [Character] = ["C", "D", "E", "F", "G", "A", "B"]
            guard let first = rawValue.first, var letterIndex = letters.firstIndex(of: first) else {
                return Int.max
            }
            let accidentalOffset: Int
            switch accidentalPreference {
            case nil: accidentalOffset = 0
            case .sharp: accidentalOffset = 1
            case .flat: accidentalOffset = -1
            }
            if letterIndex == 0 && accidentalOffset < 0 {
                letterIndex = 7
            }
            return letterIndex * 10 + accidentalOffset
        }
    }

    enum MusicalMode: String, CaseIterable, Identifiable {
        case ionian
        case dorian
        case phrygian
        case lydian
        case mixolydian
        case aeolian
        case locrian

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .lydian: return "Lydian"
            case .ionian: return "Major / Ionian"
            case .mixolydian: return "Mixolydian"
            case .dorian: return "Dorian"
            case .aeolian: return "N. Minor / Aeolian"
            case .phrygian: return "Phrygian"
            case .locrian: return "Locrian"
            }
        }

        var shortName: String {
            switch self {
            case .lydian: return "Lydian"
            case .ionian: return "Major"
            case .mixolydian: return "Mixolydian"
            case .dorian: return "Dorian"
            case .aeolian: return "Minor"
            case .phrygian: return "Phrygian"
            case .locrian: return "Locrian"
            }
        }

        /// Key signatures are shown in the hub only for the two parent scales.
        var showsKeySignatureStaff: Bool {
            self == .ionian || self == .aeolian
        }

        /// Steps counterclockwise from Lydian.
        var offset: Int {
            switch self {
            case .lydian: return 0
            case .ionian: return -1
            case .mixolydian: return -2
            case .dorian: return -3
            case .aeolian: return -4
            case .phrygian: return -5
            case .locrian: return -6
            }
        }

        var characterProfile: ModeCharacterProfile {
            switch self {
            case .lydian:
                return ModeCharacterProfile(
                    summary: "메이저 + 증4도",
                    formula: Self.formula([
                        (1, "1", false), (2, "2", false), (3, "3", false),
                        (4, "♯4", true), (5, "5", false), (6, "6", false), (7, "7", false)
                    ]),
                    characteristicNoteDegree: 4,
                    characteristicIntervalLabel: "Augmented 4th"
                )
            case .ionian:
                return ModeCharacterProfile(
                    summary: "일반적인 메이저",
                    formula: Self.formula([
                        (1, "1", false), (2, "2", false), (3, "3", false),
                        (4, "4", false), (5, "5", false), (6, "6", false), (7, "7", false)
                    ]),
                    characteristicNoteDegree: nil,
                    characteristicIntervalLabel: ""
                )
            case .mixolydian:
                return ModeCharacterProfile(
                    summary: "메이저 + 단7도",
                    formula: Self.formula([
                        (1, "1", false), (2, "2", false), (3, "3", false),
                        (4, "4", false), (5, "5", false), (6, "6", false), (7, "♭7", true)
                    ]),
                    characteristicNoteDegree: 7,
                    characteristicIntervalLabel: "Minor 7th"
                )
            case .dorian:
                return ModeCharacterProfile(
                    summary: "마이너 + 장6도",
                    formula: Self.formula([
                        (1, "1", false), (2, "2", false), (3, "♭3", true),
                        (4, "4", false), (5, "5", false), (6, "6", true), (7, "♭7", true)
                    ]),
                    characteristicNoteDegree: 6,
                    characteristicIntervalLabel: "Major 6th"
                )
            case .aeolian:
                return ModeCharacterProfile(
                    summary: "일반적인 내추럴 마이너",
                    formula: Self.formula([
                        (1, "1", false), (2, "2", false), (3, "♭3", false),
                        (4, "4", false), (5, "5", false), (6, "♭6", false), (7, "♭7", false)
                    ]),
                    characteristicNoteDegree: nil,
                    characteristicIntervalLabel: ""
                )
            case .phrygian:
                return ModeCharacterProfile(
                    summary: "마이너 + 단2도",
                    formula: Self.formula([
                        (1, "1", false), (2, "♭2", true), (3, "♭3", true),
                        (4, "4", false), (5, "5", false), (6, "♭6", true), (7, "♭7", true)
                    ]),
                    characteristicNoteDegree: 2,
                    characteristicIntervalLabel: "Minor 2nd"
                )
            case .locrian:
                return ModeCharacterProfile(
                    summary: "마이너 + 감5도",
                    formula: Self.formula([
                        (1, "1", false), (2, "♭2", true), (3, "♭3", true),
                        (4, "4", false), (5, "♭5", true), (6, "♭6", true), (7, "♭7", true)
                    ]),
                    characteristicNoteDegree: 5,
                    characteristicIntervalLabel: "Diminished 5th"
                )
            }
        }

        private static func formula(
            _ degrees: [(Int, String, Bool)]
        ) -> [ModeCharacter.FormulaTone] {
            degrees.map { ModeCharacter.FormulaTone(scaleDegree: $0.0, symbol: $0.1, isEmphasized: $0.2) }
        }
    }

    enum ChordQuality {
        case major
        case minor
        case diminished

        static func quality(forOrdinal ordinal: Int) -> ChordQuality {
            switch ordinal {
            case 0, 1, 2: return .major
            case 3, 4, 5: return .minor
            default: return .diminished
            }
        }
    }

    // MARK: - Tables from CircleOfFifths.js

    /// Scale degrees for Lydian around the circle (clockwise from start).
    private static let lydianDegrees = [1, 5, 2, 6, 3, 7, 4]

    /// Treble-staff placement of sharps in writing order: F5, C5, G5, D5, A4, E5, B4.
    private static let sharpStaffSteps = [8, 5, 9, 6, 3, 7, 4]

    /// Treble-staff placement of flats in writing order: B4, E5, A4, D5, G4, C5, F4.
    private static let flatStaffSteps = [4, 7, 3, 6, 2, 5, 1]

    /// Key-signature index → note names at clock positions 1…12.
    private static let keySignatures: [Int: [String]] = [
        -13: ["Abb", "Ebb", "Bbb", "Fb", "Cb", "Gb", "Db", "Ab", "Eb", "Cbb", "Gbb", "Dbb"],
        -12: ["Abb", "Ebb", "Bbb", "Fb", "Cb", "Gb", "Db", "Ab", "Eb", "Bb", "Gbb", "Dbb"],
        -11: ["Abb", "Ebb", "Bbb", "Fb", "Cb", "Gb", "Db", "Ab", "Eb", "Bb", "F", "Dbb"],
        -10: ["Abb", "Ebb", "Bbb", "Fb", "Cb", "Gb", "Db", "Ab", "Eb", "Bb", "F", "C"],
        -9: ["G", "Ebb", "Bbb", "Fb", "Cb", "Gb", "Db", "Ab", "Eb", "Bb", "F", "C"],
        -8: ["G", "D", "Bbb", "Fb", "Cb", "Gb", "Db", "Ab", "Eb", "Bb", "F", "C"],
        -7: ["G", "D", "A", "Fb", "Cb", "Gb", "Db", "Ab", "Eb", "Bb", "F", "C"],
        -6: ["G", "D", "A", "E", "Cb", "Gb", "Db", "Ab", "Eb", "Bb", "F", "C"],
        -5: ["G", "D", "A", "E", "B", "Gb", "Db", "Ab", "Eb", "Bb", "F", "C"],
        -4: ["G", "D", "A", "E", "B", "F#", "Db", "Ab", "Eb", "Bb", "F", "C"],
        -3: ["G", "D", "A", "E", "B", "F#", "Db", "Ab", "Eb", "Bb", "F", "C"],
        -2: ["G", "D", "A", "E", "B", "F#", "Db", "Ab", "Eb", "Bb", "F", "C"],
        -1: ["G", "D", "A", "E", "B", "F#", "Db", "Ab", "Eb", "Bb", "F", "C"],
        0: ["G", "D", "A", "E", "B", "F#", "Db", "Ab", "Eb", "Bb", "F", "C"],
        1: ["G", "D", "A", "E", "B", "F#", "Db", "Ab", "Eb", "Bb", "F", "C"],
        2: ["G", "D", "A", "E", "B", "F#", "C#", "Ab", "Eb", "Bb", "F", "C"],
        3: ["G", "D", "A", "E", "B", "F#", "C#", "G#", "Eb", "Bb", "F", "C"],
        4: ["G", "D", "A", "E", "B", "F#", "C#", "G#", "D#", "Bb", "F", "C"],
        5: ["G", "D", "A", "E", "B", "F#", "C#", "G#", "D#", "A#", "F", "C"],
        6: ["G", "D", "A", "E", "B", "F#", "C#", "G#", "D#", "A#", "E#", "C"],
        7: ["G", "D", "A", "E", "B", "F#", "C#", "G#", "D#", "A#", "E#", "B#"],
        8: ["F##", "D", "A", "E", "B", "F#", "C#", "G#", "D#", "A#", "E#", "B#"],
        9: ["F##", "C##", "A", "E", "B", "F#", "C#", "G#", "D#", "A#", "E#", "B#"],
        10: ["F##", "C##", "G##", "E", "B", "F#", "C#", "G#", "D#", "A#", "E#", "B#"],
        11: ["F##", "C##", "G##", "D##", "B", "F#", "C#", "G#", "D#", "A#", "E#", "B#"],
        12: ["F##", "C##", "G##", "D##", "A##", "F#", "C#", "G#", "D#", "A#", "E#", "B#"],
        13: ["F##", "C##", "G##", "D##", "A##", "E##", "C#", "G#", "D#", "A#", "E#", "B#"]
    ]

    static func normalizedClock(_ position: Int) -> Int {
        var clock = position
        while clock < 1 { clock += 12 }
        while clock > 12 { clock -= 12 }
        return clock
    }

    private static func makeDegreeSymbol(degree: Int, ordinal: Int) -> String {
        let romans = ["i", "ii", "iii", "iv", "v", "vi", "vii"]
        guard degree >= 1, degree <= 7 else { return "" }
        let roman = romans[degree - 1]
        switch ChordQuality.quality(forOrdinal: ordinal) {
        case .major:
            return roman.uppercased()
        case .diminished:
            return roman + "°"
        case .minor:
            return roman
        }
    }

    private static func pitchClass(of name: String) -> Int? {
        let letterMap: [Character: Int] = [
            "C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11
        ]
        guard let first = name.first, let base = letterMap[first] else { return nil }
        var pc = base
        let accidentals = String(name.dropFirst())
        if accidentals.hasSuffix("##") {
            pc += 2
        } else if accidentals.hasSuffix("bb") {
            pc -= 2
        } else if accidentals.hasSuffix("#") {
            pc += 1
        } else if accidentals.hasSuffix("b") {
            pc -= 1
        }
        return (pc % 12 + 12) % 12
    }

    private static func letterIndex(of name: String) -> Int? {
        let letters: [Character] = ["C", "D", "E", "F", "G", "A", "B"]
        guard let first = name.first else { return nil }
        return letters.firstIndex(of: first)
    }

    /// Minor-third below `major`, keeping the expected letter (C → A, F♯ → D♯, D♭ → B♭).
    private static func relativeMinorSpelling(of major: String) -> String? {
        let letters: [Character] = ["C", "D", "E", "F", "G", "A", "B"]
        guard let letter = letterIndex(of: major),
              let pc = pitchClass(of: major) else {
            return nil
        }
        let relativeLetter = String(letters[(letter + 5) % 7])
        guard let naturalPC = pitchClass(of: relativeLetter) else { return nil }
        let targetPC = (pc - 3 + 12) % 12
        var diff = targetPC - naturalPC
        if diff > 6 { diff -= 12 }
        if diff < -6 { diff += 12 }
        let accidental: String
        switch diff {
        case 0: accidental = ""
        case 1: accidental = "#"
        case 2: accidental = "##"
        case -1: accidental = "b"
        case -2: accidental = "bb"
        default: return nil
        }
        return relativeLetter + accidental
    }
}
