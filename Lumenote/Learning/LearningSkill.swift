//

import Foundation

/// A quiz subject whose attempts are stored and reviewed together.
enum LearningTopic: String, CaseIterable, Hashable, Identifiable {
    case interval
    case scale
    case keySignature
    case chord
    case diatonicChord
    case fretboardNote
    case fretboardDegree

    var id: String { rawValue }

    var domain: FeatureDomain {
        switch self {
        case .interval, .scale, .keySignature, .chord, .diatonicChord:
            .harmony
        case .fretboardNote, .fretboardDegree:
            .guitar
        }
    }

    var title: String {
        switch self {
        case .interval:
            L10n.string("음정")
        case .scale:
            L10n.string("스케일")
        case .keySignature:
            L10n.string("키 · 조표")
        case .chord:
            L10n.string("코드")
        case .diatonicChord:
            L10n.string("다이아토닉 코드")
        case .fretboardNote:
            L10n.string("지판 음이름")
        case .fretboardDegree:
            L10n.string("지판 도수")
        }
    }

    static func topics(in domain: FeatureDomain) -> [LearningTopic] {
        allCases.filter { $0.domain == domain }
    }
}

/// Stable skill-key tokens shared by quiz recording and the skill catalog.
enum LearningSkillToken {
    enum Scale {
        static let completeScale = "completeScale"
        static let identifyScale = "identifyScale"
        static let completePattern = "completePattern"
        static let completeFormula = "completeFormula"
        static let identifyDegree = "identifyDegree"
        static let excludedNote = "excludedNote"

        /// Interval patterns stay on the four heptatonic scales. Every kind gets the degree formula.
        static func tokens(for kind: ScaleKind) -> [String] {
            var tokens = [completeScale, identifyScale]
            if kind.category == .basic {
                tokens.append(completePattern)
            }
            tokens.append(contentsOf: [completeFormula, identifyDegree, excludedNote])
            return tokens
        }
    }

    enum Chord {
        static let completeChord = "completeChord"
        static let identifyChord = "identifyChord"
        static let completeFormula = "completeFormula"
        static let identifyTone = "identifyTone"
        static let all = [completeChord, identifyChord, completeFormula, identifyTone]
    }

    enum Diatonic {
        static let completeRomanPattern = "completeRomanPattern"
        static let identifyQuality = "identifyQuality"
        static let identifyNonDiatonic = "identifyNonDiatonic"
    }

    enum KeySignature {
        static let pickStaff = "pickStaff"
        static let pickKey = "pickKey"
        static let all = [pickStaff, pickKey]
    }
}

/// Parses and builds skill keys. The key is not localized.
enum LearningSkillKey {
    struct ScaleParts {
        var kind: ScaleKind
        var token: String
    }

    struct ChordParts {
        var kind: ChordKind
        var token: String
    }

    struct DiatonicParts {
        var kind: ScaleKind
        var degree: DiatonicDegree?
        var voicing: DiatonicVoicing
        var token: String
    }

    struct KeySignatureParts {
        var token: String
        var signatureIndex: Int
    }

    static func interval(degree: Int, qualityOffset: Int) -> String {
        "\(degree)|\(qualityOffset)"
    }

    static func parseInterval(_ key: String) -> (degree: Int, qualityOffset: Int)? {
        let parts = key.split(separator: "|").map(String.init)
        guard parts.count == 2, let degree = Int(parts[0]), let offset = Int(parts[1]) else {
            return nil
        }
        return (degree, offset)
    }

    static func scale(kind: ScaleKind, token: String) -> String {
        "\(kind.rawValue)|\(token)"
    }

    static func parseScale(_ key: String) -> ScaleParts? {
        let parts = key.split(separator: "|").map(String.init)
        guard parts.count == 2, let kind = ScaleKind(rawValue: parts[0]) else { return nil }
        return ScaleParts(kind: kind, token: parts[1])
    }

    static func chord(kind: ChordKind, token: String) -> String {
        "\(kind.rawValue)|\(token)"
    }

    static func parseChord(_ key: String) -> ChordParts? {
        let parts = key.split(separator: "|").map(String.init)
        guard parts.count == 2, let kind = ChordKind(rawValue: parts[0]) else { return nil }
        return ChordParts(kind: kind, token: parts[1])
    }

    static func diatonic(
        kind: ScaleKind,
        degree: DiatonicDegree?,
        voicing: DiatonicVoicing,
        token: String
    ) -> String {
        if let degree {
            return "\(kind.rawValue)|\(degree.rawValue)|\(voicing.rawValue)|\(token)"
        }
        return "\(kind.rawValue)|\(voicing.rawValue)|\(token)"
    }

    static func parseDiatonic(_ key: String) -> DiatonicParts? {
        let parts = key.split(separator: "|").map(String.init)
        if parts.count == 4,
           let kind = ScaleKind(rawValue: parts[0]),
           let degreeRaw = Int(parts[1]),
           let degree = DiatonicDegree(rawValue: degreeRaw),
           let voicing = DiatonicVoicing(rawValue: parts[2]) {
            return DiatonicParts(kind: kind, degree: degree, voicing: voicing, token: parts[3])
        }
        if parts.count == 3,
           let kind = ScaleKind(rawValue: parts[0]),
           let voicing = DiatonicVoicing(rawValue: parts[1]) {
            return DiatonicParts(kind: kind, degree: nil, voicing: voicing, token: parts[2])
        }
        return nil
    }

    static func keySignature(token: String, signatureIndex: Int) -> String {
        "\(token)|\(signatureIndex)"
    }

    static func parseKeySignature(_ key: String) -> KeySignatureParts? {
        let parts = key.split(separator: "|").map(String.init)
        guard parts.count == 2, let index = Int(parts[1]) else { return nil }
        return KeySignatureParts(token: parts[0], signatureIndex: index)
    }

    static func fretboardNote(pitchClass: Int) -> String {
        String(pitchClass)
    }

    static func fretboardDegree(semitones: Int) -> String {
        String(semitones)
    }
}

enum LearningSkillTitle {
    static func title(topic: LearningTopic, key: String) -> String {
        switch topic {
        case .interval:
            guard let parsed = LearningSkillKey.parseInterval(key) else { return key }
            return IntervalModel.localizedQuizName(degree: parsed.degree, qualityOffset: parsed.qualityOffset)
        case .scale:
            guard let parsed = LearningSkillKey.parseScale(key) else { return key }
            return "\(parsed.kind.englishTitle) · \(scaleTokenTitle(parsed.token).l10n)"
        case .chord:
            guard let parsed = LearningSkillKey.parseChord(key) else { return key }
            return "\(parsed.kind.englishTitle) · \(chordTokenTitle(parsed.token).l10n)"
        case .diatonicChord:
            guard let parsed = LearningSkillKey.parseDiatonic(key) else { return key }
            return diatonicTitle(parsed)
        case .keySignature:
            guard let parsed = LearningSkillKey.parseKeySignature(key) else { return key }
            return "\(keySignatureTokenTitle(parsed.token).l10n) · \(signatureTitle(parsed.signatureIndex))"
        case .fretboardNote:
            guard let pitchClass = Int(key) else { return key }
            return Fretboard.displayName(pitchClass: pitchClass, accidental: .sharp)
        case .fretboardDegree:
            guard let semitones = Int(key) else { return key }
            return Fretboard.degreeLabel(
                pitchClass: semitones,
                rootPitchClass: 0,
                accidental: .sharp
            )
        }
    }

    private static func scaleTokenTitle(_ token: String) -> String {
        switch token {
        case LearningSkillToken.Scale.completeScale: "구성음"
        case LearningSkillToken.Scale.identifyScale: "스케일 이름"
        case LearningSkillToken.Scale.completePattern: "음정 패턴"
        case LearningSkillToken.Scale.completeFormula: "도수 공식"
        case LearningSkillToken.Scale.identifyDegree: "도수"
        case LearningSkillToken.Scale.excludedNote: "비구성음"
        default: token
        }
    }

    private static func chordTokenTitle(_ token: String) -> String {
        switch token {
        case LearningSkillToken.Chord.completeChord: "구성음"
        case LearningSkillToken.Chord.identifyChord: "코드 이름"
        case LearningSkillToken.Chord.completeFormula: "코드 공식"
        case LearningSkillToken.Chord.identifyTone: "도수"
        default: token
        }
    }

    private static func diatonicTitle(_ parsed: LearningSkillKey.DiatonicParts) -> String {
        let token = diatonicTokenTitle(parsed.token).l10n
        if let degree = parsed.degree {
            let ordinal = degree.rawValue + 1
            return "\(parsed.kind.englishTitle) · \(ordinal)도 · \(parsed.voicing.title) · \(token)"
        }
        return "\(parsed.kind.englishTitle) · \(parsed.voicing.title) · \(token)"
    }

    private static func diatonicTokenTitle(_ token: String) -> String {
        switch token {
        case LearningSkillToken.Diatonic.completeRomanPattern: "다이아토닉 규칙"
        case LearningSkillToken.Diatonic.identifyQuality: "코드 품질"
        case LearningSkillToken.Diatonic.identifyNonDiatonic: "비다이아토닉"
        default: token
        }
    }

    private static func keySignatureTokenTitle(_ token: String) -> String {
        switch token {
        case LearningSkillToken.KeySignature.pickStaff: "조표 고르기"
        case LearningSkillToken.KeySignature.pickKey: "키 고르기"
        default: token
        }
    }

    private static func signatureTitle(_ index: Int) -> String {
        if index == 0 { return "조표 없음".l10n }
        if index > 0 { return "\(index)♯" }
        return "\(abs(index))♭"
    }
}

/// Every skill a topic can record. Unseen counts come from keys with no attempts.
enum LearningSkillCatalog {
    static func keys(for topic: LearningTopic) -> [String] {
        switch topic {
        case .interval:
            intervalKeys
        case .scale:
            ScaleKind.allCases.flatMap { kind in
                LearningSkillToken.Scale.tokens(for: kind).map { LearningSkillKey.scale(kind: kind, token: $0) }
            }
        case .chord:
            ChordKind.allCases.flatMap { kind in
                LearningSkillToken.Chord.all.map { LearningSkillKey.chord(kind: kind, token: $0) }
            }
        case .diatonicChord:
            diatonicKeys()
        case .keySignature:
            keySignatureKeys
        case .fretboardNote:
            Fretboard.pitchClasses.map { LearningSkillKey.fretboardNote(pitchClass: $0) }
        case .fretboardDegree:
            Fretboard.quizTargetSemitones.map { LearningSkillKey.fretboardDegree(semitones: $0) }
        }
    }

    private static let intervalKeys = IntervalQuizModel.learningSkillKeys()
    private static let keySignatureKeys = KeySignatureQuizModel.learningSkillKeys()

    private static func diatonicKeys() -> [String] {
        var keys: [String] = []
        for kind in ScaleKind.basicCases {
            for voicing in DiatonicVoicing.allCases {
                for degree in DiatonicDegree.allCases {
                    keys.append(
                        LearningSkillKey.diatonic(
                            kind: kind,
                            degree: degree,
                            voicing: voicing,
                            token: LearningSkillToken.Diatonic.completeRomanPattern
                        )
                    )
                    keys.append(
                        LearningSkillKey.diatonic(
                            kind: kind,
                            degree: degree,
                            voicing: voicing,
                            token: LearningSkillToken.Diatonic.identifyQuality
                        )
                    )
                }
                keys.append(
                    LearningSkillKey.diatonic(
                        kind: kind,
                        degree: nil,
                        voicing: voicing,
                        token: LearningSkillToken.Diatonic.identifyNonDiatonic
                    )
                )
            }
        }
        return keys
    }
}
