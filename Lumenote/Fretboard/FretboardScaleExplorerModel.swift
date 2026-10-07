//

import Foundation

/// One scale on the fretboard: tonic spelling, scale kind, and the tones drawn on the neck.
@Observable
final class FretboardScaleExplorerModel {
    var labelMode: Fretboard.LabelMode = .noteName
    private(set) var tonicSpelling: String = "C"
    var kind: ScaleKind = .major

    /// A scale tone other than the octave, which shares the tonic's fretboard positions.
    struct Tone: Identifiable, Equatable {
        let pitchClass: Int
        let noteName: String
        let degreeLabel: String
        /// Korean accessibility key such as "플랫 3도".
        let degreeAccessibilityKey: String

        var id: Int { pitchClass }

        func label(for mode: Fretboard.LabelMode) -> String {
            switch mode {
            case .noteName: noteName
            case .degree: degreeLabel
            }
        }

        func accessibilityLabel(for mode: Fretboard.LabelMode) -> String {
            switch mode {
            case .noteName: noteName
            case .degree: degreeAccessibilityKey.l10n
            }
        }

        func swatchPitchClass(for mode: Fretboard.LabelMode, tonicPitchClass: Int) -> Int {
            switch mode {
            case .noteName:
                pitchClass
            case .degree:
                Fretboard.semitones(from: tonicPitchClass, to: pitchClass)
            }
        }
    }

    var tonicPitchClass: Int {
        ScaleModel.pitchClass(for: tonicSpelling)
    }

    var tonicDisplayName: String {
        ScaleModel.formatNoteName(tonicSpelling)
    }

    /// Ascending scale tones. The octave is omitted because it is the same pitch class as the tonic.
    var tones: [Tone] {
        let spellings = ScaleModel.spellings(tonic: tonicSpelling, kind: kind)
        let degrees = kind.degreeLabels
        let count = min(spellings.count, degrees.count)
        guard count > 1 else { return [] }

        return (0..<(count - 1)).map { index in
            let spelling = spellings[index]
            let degree = degrees[index]
            return Tone(
                pitchClass: ScaleModel.pitchClass(for: spelling),
                noteName: ScaleModel.formatNoteName(spelling),
                degreeLabel: degree,
                degreeAccessibilityKey: Self.spokenDegreeKey(degree)
            )
        }
    }

    var visiblePitchClasses: Set<Int> {
        Set(tones.map(\.pitchClass))
    }

    func markerLabels() -> [Int: String] {
        Dictionary(tones.map { ($0.pitchClass, $0.label(for: labelMode)) }, uniquingKeysWith: { _, last in last })
    }

    func markerSwatches() -> [Int: Int] {
        let tonic = tonicPitchClass
        return Dictionary(
            tones.map { ($0.pitchClass, $0.swatchPitchClass(for: labelMode, tonicPitchClass: tonic)) },
            uniquingKeysWith: { _, last in last }
        )
    }

    func markerAccessibilityLabels() -> [Int: String] {
        Dictionary(
            tones.map { ($0.pitchClass, $0.accessibilityLabel(for: labelMode)) },
            uniquingKeysWith: { _, last in last }
        )
    }

    func selectTonic(_ spelling: String) {
        guard ScaleModel.isKnownSpelling(spelling) else { return }
        tonicSpelling = spelling
    }

    /// "♭3" → "플랫 3도". Scale formulas in this app only use single sharps and flats.
    private static func spokenDegreeKey(_ label: String) -> String {
        let prefix: String
        let number: String
        if label.hasPrefix("𝄫") {
            prefix = "더블플랫 "
            number = String(label.dropFirst())
        } else if label.hasPrefix("♭") {
            prefix = "플랫 "
            number = String(label.dropFirst())
        } else if label.hasPrefix("𝄪") {
            prefix = "더블샵 "
            number = String(label.dropFirst())
        } else if label.hasPrefix("♯") {
            prefix = "샵 "
            number = String(label.dropFirst())
        } else {
            prefix = ""
            number = label
        }
        return "\(prefix)\(number)도"
    }
}
