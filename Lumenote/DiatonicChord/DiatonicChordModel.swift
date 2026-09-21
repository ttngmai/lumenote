//

import Foundation

/// Lesson state: tonic + scale kind + triad/7th voicing → spelled diatonic chords.
@Observable
final class DiatonicChordModel {
    var tonicSpelling: String = "C" {
        didSet {
            if !ScaleModel.isKnownSpelling(tonicSpelling) {
                tonicSpelling = "C"
            }
        }
    }

    var kind: ScaleKind = .major
    var voicing: DiatonicVoicing = .triad

    // MARK: - Derived

    var tonicDisplayName: String {
        ScaleModel.formatNoteName(tonicSpelling)
    }

    var noteOptions: [(spelling: String, displayName: String)] {
        ScaleModel.selectableNotes
    }

    /// Seven scale degrees, excluding the octave.
    var scaleNoteSpellings: [String] {
        Array(ScaleModel.spellings(tonic: tonicSpelling, kind: kind).dropLast())
    }

    var scaleNoteDisplayNames: [String] {
        scaleNoteSpellings.map(ScaleModel.formatNoteName)
    }

    var chords: [DiatonicChordEntry] {
        Self.chords(tonic: tonicSpelling, kind: kind, voicing: voicing)
    }

    /// Major-key diatonic triads for the selected tonic, used by the function lesson.
    var majorFunctionChords: [DiatonicChordEntry] {
        Self.chords(tonic: tonicSpelling, kind: .major, voicing: .triad)
    }

    var qualityPatternText: String {
        chords.map(\.quality.patternLabel).joined(separator: " – ")
    }

    var romanPatternText: String {
        chords.map(\.degree.functionRoman).joined(separator: " – ")
    }

    func majorChord(for degree: DiatonicDegree) -> DiatonicChordEntry? {
        majorFunctionChords.first { $0.degree == degree }
    }

    // MARK: - Building

    static func chords(
        tonic: String,
        kind: ScaleKind,
        voicing: DiatonicVoicing
    ) -> [DiatonicChordEntry] {
        let scaleNotes = Array(ScaleModel.spellings(tonic: tonic, kind: kind).dropLast())
        guard scaleNotes.count == DiatonicDegree.allCases.count else { return [] }

        return DiatonicDegree.allCases.map { degree in
            let tones = voicing.letterOffsets.map { offset in
                scaleNotes[(degree.rawValue + offset) % scaleNotes.count]
            }
            let quality = DiatonicChordQuality.detected(from: tones) ?? voicing.fallbackQuality
            return DiatonicChordEntry(
                degree: degree,
                roman: roman(kind: kind, voicing: voicing, degree: degree),
                quality: quality,
                rootSpelling: scaleNotes[degree.rawValue],
                toneSpellings: tones
            )
        }
    }

    static func roman(
        kind: ScaleKind,
        voicing: DiatonicVoicing,
        degree: DiatonicDegree
    ) -> String {
        let table = voicing == .triad ? triadRomans : seventhRomans
        return table[kind]?[degree.rawValue] ?? degree.functionRoman
    }

    // MARK: - Textbook roman numerals

    private static let triadRomans: [ScaleKind: [String]] = [
        .major: ["I", "IIm", "IIIm", "IV", "V", "VIm", "VII°"],
        .naturalMinor: ["Im", "II°", "♭III", "IVm", "Vm", "♭VI", "♭VII"],
        .harmonicMinor: ["Im", "II°", "♭III+", "IVm", "V", "♭VI", "VII°"],
        .melodicMinor: ["Im", "IIm", "♭III+", "IV", "V", "VI°", "VII°"],
    ]

    private static let seventhRomans: [ScaleKind: [String]] = [
        .major: ["IM7", "IIm7", "IIIm7", "IVM7", "V7", "VIm7", "VIIm7♭5"],
        .naturalMinor: ["Im7", "IIm7♭5", "♭IIIM7", "IVm7", "Vm7", "♭VIM7", "♭VII7"],
        .harmonicMinor: ["ImM7", "IIm7♭5", "♭III+M7", "IVm7", "V7", "♭VIM7", "VII°7"],
        .melodicMinor: ["ImM7", "IIm7", "♭III+M7", "IV7", "V7", "VIm7♭5", "VIIm7♭5"],
    ]

    static let roles: [DiatonicDegreeRole] = [
        DiatonicDegreeRole(
            degree: .i,
            function: .tonic,
            functionLabel: "Tonic",
            title: "조성의 중심이 되는 가장 안정적인 코드입니다.",
            body: "곡의 시작이나 끝에서 자주 사용되며, 다른 코드에서 발생한 긴장이 I 코드로 돌아오면서 해결되는 느낌을 줍니다.",
            takeaway: "안정 · 중심 · 해결"
        ),
        DiatonicDegreeRole(
            degree: .ii,
            function: .subdominant,
            functionLabel: "Subdominant 계열",
            title: "음악을 토닉에서 벗어나 다른 곳으로 진행시키는 역할을 합니다.",
            body: "특히 V 코드로 자연스럽게 이어지기 때문에 ii → V → I 진행은 팝, 재즈 등에서 매우 중요하게 사용됩니다.",
            takeaway: "전개 · 이동 · V로 연결"
        ),
        DiatonicDegreeRole(
            degree: .iii,
            function: .tonic,
            functionLabel: "Tonic 계열",
            title: "I 코드와 일부 음을 공유하여 비교적 안정적인 성격을 갖습니다.",
            body: "I만큼 강한 중심감을 갖지는 않으며, 앞뒤 코드에 따라 연결이나 진행을 위한 코드로도 사용됩니다.",
            takeaway: "비교적 안정 · 연결 · I과 유사한 성격"
        ),
        DiatonicDegreeRole(
            degree: .iv,
            function: .subdominant,
            functionLabel: "Subdominant",
            title: "대표적인 서브도미넌트 코드로, 안정된 토닉에서 벗어나 음악을 전개시키는 역할을 합니다.",
            body: "V로 진행하여 긴장을 증가시키거나 다시 I으로 돌아갈 수도 있습니다.",
            takeaway: "전개 · 변화 · 이동"
        ),
        DiatonicDegreeRole(
            degree: .v,
            function: .dominant,
            functionLabel: "Dominant",
            title: "강한 긴장감을 만들고 I 코드로 해결되려는 성질을 가진 코드입니다.",
            body: "특히 V 코드의 3음은 조의 Leading Tone(이끈음)이기 때문에 으뜸음으로 반음 위 진행하려는 강한 성질을 갖습니다.",
            takeaway: "긴장 · 불안정 · I으로 해결"
        ),
        DiatonicDegreeRole(
            degree: .vi,
            function: .tonic,
            functionLabel: "Tonic 계열",
            title: "I 코드와 공통음을 가지고 있어 토닉을 어느 정도 대신할 수 있는 코드입니다.",
            body: "특히 V 다음에 예상했던 I 대신 vi가 등장하면 거짓종지(Deceptive Cadence)와 같은 효과를 만들 수 있습니다. 관계단조(Relative Minor)의 으뜸화음이기도 합니다.",
            takeaway: "안정 · 토닉 대리 · 분위기 변화"
        ),
        DiatonicDegreeRole(
            degree: .vii,
            function: .dominant,
            functionLabel: "Dominant 계열",
            title: "매우 불안정하며 I으로 해결되려는 성질이 강한 감3화음입니다.",
            body: "근음 자체가 Leading Tone이므로 으뜸음으로 반음 위 진행하려는 성질을 가지고 있습니다.",
            takeaway: "강한 긴장 · 불안정 · I으로 해결"
        ),
    ]
}

// MARK: - Voicing

enum DiatonicVoicing: String, CaseIterable, Identifiable {
    case triad
    case seventh

    var id: String { rawValue }

    var title: String {
        switch self {
        case .triad: "3화음"
        case .seventh: "7화음"
        }
    }

    var letterOffsets: [Int] {
        switch self {
        case .triad: [0, 2, 4]
        case .seventh: [0, 2, 4, 6]
        }
    }

    var fallbackQuality: DiatonicChordQuality {
        switch self {
        case .triad: .major
        case .seventh: .major7
        }
    }
}

// MARK: - Degree & function

enum DiatonicDegree: Int, CaseIterable, Identifiable {
    case i, ii, iii, iv, v, vi, vii

    var id: Int { rawValue }

    /// Major-key function roman numeral (I, ii, iii, IV, V, vi, vii°).
    var functionRoman: String {
        switch self {
        case .i: "I"
        case .ii: "ii"
        case .iii: "iii"
        case .iv: "IV"
        case .v: "V"
        case .vi: "vi"
        case .vii: "vii°"
        }
    }

    var function: HarmonicFunction {
        switch self {
        case .i, .iii, .vi: .tonic
        case .ii, .iv: .subdominant
        case .v, .vii: .dominant
        }
    }
}

enum HarmonicFunction: String, CaseIterable, Identifiable {
    case tonic
    case subdominant
    case dominant

    var id: String { rawValue }

    var englishTitle: String {
        switch self {
        case .tonic: "Tonic"
        case .subdominant: "Subdominant"
        case .dominant: "Dominant"
        }
    }

    var motionLabel: String {
        switch self {
        case .tonic: "안정 · 해결"
        case .subdominant: "전개 · 이동"
        case .dominant: "긴장 · 해결 요구"
        }
    }

    var memberRomans: String {
        switch self {
        case .tonic: "I, iii, vi"
        case .subdominant: "ii, IV"
        case .dominant: "V, vii°"
        }
    }
}

enum HarmonicMotionStep: String, CaseIterable, Identifiable {
    case rest
    case depart
    case tension
    case resolve

    var id: String { rawValue }

    var function: HarmonicFunction {
        switch self {
        case .rest, .resolve: .tonic
        case .depart: .subdominant
        case .tension: .dominant
        }
    }

    var title: String {
        switch self {
        case .rest: "안정"
        case .depart: "전개"
        case .tension: "긴장"
        case .resolve: "해결"
        }
    }

    var romans: String {
        switch self {
        case .rest: "I · iii · vi"
        case .depart: "ii · IV"
        case .tension: "V · vii°"
        case .resolve: "I"
        }
    }
}

// MARK: - Quality & entries

enum DiatonicChordQuality: Equatable {
    case major
    case minor
    case augmented
    case diminished
    case major7
    case minor7
    case dominant7
    case minorMajor7
    case halfDiminished7
    case diminished7
    case augmentedMajor7

    var patternLabel: String {
        switch self {
        case .major: "Major"
        case .minor: "minor"
        case .augmented: "Augmented"
        case .diminished: "diminished"
        case .major7: "Major 7"
        case .minor7: "minor 7"
        case .dominant7: "7"
        case .minorMajor7: "minor Major 7"
        case .halfDiminished7: "minor 7 ♭5"
        case .diminished7: "diminished 7"
        case .augmentedMajor7: "Augmented Major 7"
        }
    }

    var englishNoun: String {
        switch self {
        case .major: "Major"
        case .minor: "minor"
        case .augmented: "Augmented"
        case .diminished: "diminished"
        case .major7: "Major 7"
        case .minor7: "minor 7"
        case .dominant7: "7"
        case .minorMajor7: "minor Major 7"
        case .halfDiminished7: "minor 7 ♭5"
        case .diminished7: "diminished 7"
        case .augmentedMajor7: "Augmented Major 7"
        }
    }

    func compactName(rootDisplayName root: String) -> String {
        switch self {
        case .major: root
        case .minor: "\(root)m"
        case .augmented: "\(root)+"
        case .diminished: "\(root)dim"
        case .major7: "\(root)M7"
        case .minor7: "\(root)m7"
        case .dominant7: "\(root)7"
        case .minorMajor7: "\(root)mM7"
        case .halfDiminished7: "\(root)m7♭5"
        case .diminished7: "\(root)°7"
        case .augmentedMajor7: "\(root)+M7"
        }
    }

    static func detected(from toneSpellings: [String]) -> DiatonicChordQuality? {
        guard let root = toneSpellings.first, toneSpellings.count >= 3 else { return nil }
        let rootPC = ScaleModel.pitchClass(for: root)
        func interval(_ spelling: String) -> Int {
            (ScaleModel.pitchClass(for: spelling) - rootPC + 12) % 12
        }

        let third = interval(toneSpellings[1])
        let fifth = interval(toneSpellings[2])
        if toneSpellings.count == 3 {
            switch (third, fifth) {
            case (4, 7): return .major
            case (3, 7): return .minor
            case (4, 8): return .augmented
            case (3, 6): return .diminished
            default: return nil
            }
        }

        guard toneSpellings.count >= 4 else { return nil }
        let seventh = interval(toneSpellings[3])
        switch (third, fifth, seventh) {
        case (4, 7, 11): return .major7
        case (3, 7, 10): return .minor7
        case (4, 7, 10): return .dominant7
        case (3, 7, 11): return .minorMajor7
        case (3, 6, 10): return .halfDiminished7
        case (3, 6, 9): return .diminished7
        case (4, 8, 11): return .augmentedMajor7
        default: return nil
        }
    }
}

struct DiatonicChordEntry: Identifiable, Equatable {
    let degree: DiatonicDegree
    let roman: String
    let quality: DiatonicChordQuality
    let rootSpelling: String
    let toneSpellings: [String]

    var id: Int { degree.rawValue }

    var rootDisplayName: String {
        ScaleModel.formatNoteName(rootSpelling)
    }

    var compactName: String {
        quality.compactName(rootDisplayName: rootDisplayName)
    }

    var toneDisplayNames: [String] {
        toneSpellings.map(ScaleModel.formatNoteName)
    }

    var stackedTonesText: String {
        toneDisplayNames.joined(separator: " – ")
    }

    var examplePhrase: String {
        "\(rootDisplayName) \(quality.englishNoun)"
    }
}

struct DiatonicDegreeRole: Identifiable {
    let degree: DiatonicDegree
    let function: HarmonicFunction
    let functionLabel: String
    let title: String
    let body: String
    let takeaway: String

    var id: Int { degree.rawValue }
}
