//

import Foundation

/// How a scale is grouped into movable fretboard forms.
enum FretboardScaleFormSystem: String, CaseIterable, Identifiable {
    case caged
    case threeNotesPerString

    var id: String { rawValue }

    var title: String {
        switch self {
        case .caged: "CAGED"
        case .threeNotesPerString: "3NPS"
        }
    }
}

/// One movable scale form: a CAGED shape or a 3-notes-per-string position.
struct FretboardScaleFormPosition: Identifiable, Equatable {
    let index: Int
    /// CAGED shape letter. Empty for a 3NPS position, which is numbered by `index`.
    let shapeLetter: String?
    let notes: [Fretboard.Position]

    var id: Int { index }

    var fretRange: ClosedRange<Int> {
        let frets = notes.map(\.fret)
        return (frets.min() ?? 0)...(frets.max() ?? 0)
    }

    var title: String {
        if let shapeLetter {
            return L10n.s("\(shapeLetter) 포지션")
        }
        return L10n.s("\(index + 1)포지션")
    }
}

/// CAGED and 3-notes-per-string forms for the scales in the fretboard explorer.
enum FretboardScaleForms {
    static func systems(for kind: ScaleKind) -> [FretboardScaleFormSystem] {
        switch kind {
        case .major, .naturalMinor:
            [.caged, .threeNotesPerString]
        case .harmonicMinor, .melodicMinor:
            [.threeNotesPerString]
        case .majorPentatonic, .minorPentatonic, .majorBlues, .minorBlues:
            [.caged]
        }
    }

    static func positions(
        tonicPitchClass: Int,
        kind: ScaleKind,
        system: FretboardScaleFormSystem
    ) -> [FretboardScaleFormPosition] {
        let tonic = Fretboard.normalizedPitchClass(tonicPitchClass)
        switch system {
        case .caged:
            return cagedPositions(tonic: tonic, kind: kind)
        case .threeNotesPerString:
            guard kind.category == .basic else { return [] }
            let semitones = semitoneOffsets(for: kind)
            guard semitones.count == 7 else { return [] }
            return threeNotesPerString(tonic: tonic, semitones: semitones).enumerated().map { index, notes in
                FretboardScaleFormPosition(index: index, shapeLetter: nil, notes: notes)
            }
        }
    }

    // MARK: - CAGED

    /// Major-scale CAGED grids, high E string first. Each character is one fret.
    /// `-` is empty. Degrees `4` and `7` are removed to make the pentatonic boxes.
    /// `baseChroma` is the pitch class the grid was written at, before moving it to the tonic.
    private struct CAGEDTemplate {
        let baseChroma: Int
        let rows: [String]
    }

    private static let cagedTemplates: [CAGEDTemplate] = [
        CAGEDTemplate(baseChroma: 8, rows: ["-6-71", "-34-5", "71-2-", "-5-6-", "-2-34", "-6-71"]),
        CAGEDTemplate(baseChroma: 5, rows: ["71-2", "-5-6", "2-34", "6-71", "34-5", "71-2"]),
        CAGEDTemplate(baseChroma: 3, rows: ["-2-34", "-6-71", "34-5", "71-2-", "-5-6-", "-2-34"]),
        CAGEDTemplate(baseChroma: 0, rows: ["34-5", "71-2", "5-6-", "2-34", "6-71", "34-5"]),
        CAGEDTemplate(baseChroma: 10, rows: ["-5-6-", "-2-34", "6-71-", "34-5-", "71-2-", "-5-6-"]),
    ]

    /// Aeolian is a mode of the major scale, so natural-minor boxes reuse the major grids
    /// shifted to the relative major. Harmonic and melodic minor use 3NPS only.
    private static let aeolianOffset = 9
    private static let pentatonicDegreesToOmit: Set<Character> = ["4", "7"]
    private static let shapeOrder = ["C", "A", "G", "E", "D"]

    private static func cagedPositions(tonic: Int, kind: ScaleKind) -> [FretboardScaleFormPosition] {
        let boxes: [[Fretboard.Position]]
        switch kind {
        case .major:
            boxes = cagedBoxes(tonic: tonic, modeOffset: 0, omitting: [])
        case .naturalMinor:
            boxes = cagedBoxes(tonic: tonic, modeOffset: aeolianOffset, omitting: [])
        case .harmonicMinor, .melodicMinor:
            return []
        case .majorPentatonic:
            boxes = cagedBoxes(tonic: tonic, modeOffset: 0, omitting: pentatonicDegreesToOmit)
        case .minorPentatonic:
            boxes = cagedBoxes(tonic: tonic, modeOffset: aeolianOffset, omitting: pentatonicDegreesToOmit)
        case .majorBlues:
            let blue = Fretboard.normalizedPitchClass(tonic + 3)
            boxes = cagedBoxes(tonic: tonic, modeOffset: 0, omitting: pentatonicDegreesToOmit)
                .map { adding(pitchClass: blue, to: $0) }
        case .minorBlues:
            let blue = Fretboard.normalizedPitchClass(tonic + 6)
            boxes = cagedBoxes(tonic: tonic, modeOffset: aeolianOffset, omitting: pentatonicDegreesToOmit)
                .map { adding(pitchClass: blue, to: $0) }
        }

        let named = boxes.map { notes in
            (shape: shapeLetter(notes: notes, tonic: tonic), notes: notes)
        }
        let ordered = named.sorted { lhs, rhs in
            let left = lhs.notes.map(\.fret).min() ?? 0
            let right = rhs.notes.map(\.fret).min() ?? 0
            if left != right { return left < right }
            return shapeRank(lhs.shape) < shapeRank(rhs.shape)
        }
        return ordered.enumerated().map { index, box in
            FretboardScaleFormPosition(index: index, shapeLetter: box.shape, notes: box.notes)
        }
    }

    private static func cagedBoxes(
        tonic: Int,
        modeOffset: Int,
        omitting: Set<Character>
    ) -> [[Fretboard.Position]] {
        cagedTemplates.map { template in
            var delta = tonic - template.baseChroma - modeOffset
            while delta < -1 {
                delta += 12
            }
            var notes: [Fretboard.Position] = []
            for (stringIndex, row) in template.rows.enumerated() {
                for (column, character) in row.enumerated() where character != "-" && !omitting.contains(character) {
                    notes.append(Fretboard.Position(stringIndex: stringIndex, fret: column + delta))
                }
            }
            return placedOnNeck(notes)
        }
    }

    /// Names the box from the strings that carry the tonic.
    /// String 0 is the high E. G is tested before E because both use the outer strings.
    private static func shapeLetter(notes: [Fretboard.Position], tonic: Int) -> String {
        let roots = Set(notes.filter { Fretboard.pitchClass(at: $0) == tonic }.map(\.stringIndex))
        if roots.isSuperset(of: [0, 2, 5]) { return "G" }
        if roots.isSuperset(of: [0, 3, 5]) || roots.isSuperset(of: [0, 5]) { return "E" }
        if roots.isSuperset(of: [1, 3]) { return "D" }
        if roots.isSuperset(of: [1, 4]) { return "C" }
        if roots.isSuperset(of: [2, 4]) { return "A" }
        return "C"
    }

    private static func shapeRank(_ letter: String) -> Int {
        shapeOrder.firstIndex(of: letter) ?? shapeOrder.count
    }

    /// Inserts the blues note wherever it falls inside the pentatonic box.
    private static func adding(pitchClass: Int, to notes: [Fretboard.Position]) -> [Fretboard.Position] {
        guard
            let minFret = notes.map(\.fret).min(),
            let maxFret = notes.map(\.fret).max()
        else { return notes }

        var result = notes
        let existing = Set(notes)
        for stringIndex in 0..<Fretboard.stringCount {
            for fret in minFret...maxFret {
                let position = Fretboard.Position(stringIndex: stringIndex, fret: fret)
                guard !existing.contains(position) else { continue }
                guard Fretboard.pitchClass(at: position) == pitchClass else { continue }
                result.append(position)
            }
        }
        return result
    }

    // MARK: - 3 notes per string

    /// Standard-tuning MIDI numbers, high E string first.
    private static let openMIDI = [64, 59, 55, 50, 45, 40]

    /// Seven positions. Position 1 starts on the tonic and each string continues with the next three scale notes.
    private static func threeNotesPerString(tonic: Int, semitones: [Int]) -> [[Fretboard.Position]] {
        (0..<semitones.count).map { start in
            let lowE = Fretboard.stringCount - 1
            let firstPitchClass = Fretboard.normalizedPitchClass(tonic + semitones[start])
            let openPitchClass = Fretboard.standardOpenPitchClasses[lowE]
            let firstFret = (firstPitchClass - openPitchClass + 12) % 12
            let firstMIDI = openMIDI[lowE] + firstFret
            var notes: [Fretboard.Position] = []
            for stringFromLow in 0..<Fretboard.stringCount {
                let stringIndex = lowE - stringFromLow
                for step in 0..<3 {
                    let noteIndex = stringFromLow * 3 + step
                    let degree = (start + noteIndex) % semitones.count
                    let octave = (start + noteIndex) / semitones.count
                    let absolute = semitones[degree] + 12 * octave
                    let fret = firstMIDI + (absolute - semitones[start]) - openMIDI[stringIndex]
                    notes.append(Fretboard.Position(stringIndex: stringIndex, fret: fret))
                }
            }
            return placedOnNeck(notes)
        }
    }

    // MARK: - Shared

    private static func semitoneOffsets(for kind: ScaleKind) -> [Int] {
        let spellings = ScaleModel.spellings(tonic: "C", kind: kind)
        let pitchClasses = spellings.dropLast().map(ScaleModel.pitchClass(for:))
        guard let tonic = pitchClasses.first else { return [] }
        return pitchClasses.map { Fretboard.normalizedPitchClass($0 - tonic) }
    }

    private static func placedOnNeck(_ notes: [Fretboard.Position]) -> [Fretboard.Position] {
        var notes = notes
        if notes.contains(where: { $0.fret < 0 }) {
            notes = notes.map { Fretboard.Position(stringIndex: $0.stringIndex, fret: $0.fret + 12) }
        }
        while notes.allSatisfy({ $0.fret - 12 >= 0 }), notes.contains(where: { $0.fret > Fretboard.explorerLastFret }) {
            notes = notes.map { Fretboard.Position(stringIndex: $0.stringIndex, fret: $0.fret - 12) }
        }
        return notes
    }
}
