//

import Foundation

/// Mixed diatonic-chord quiz: roman pattern, quality, and non-diatonic identification.
@MainActor
@Observable
final class DiatonicChordQuizModel {
    enum QuestionKind: Equatable {
        /// Fill one missing roman numeral in the scale's diatonic pattern.
        case completeRomanPattern
        /// Given a scale-degree ordinal, pick the chord quality.
        case identifyQuality
        /// Pick the chord that does not belong to the key's diatonic set.
        case identifyNonDiatonic
    }

    enum PromptToken: Equatable {
        case roman(String)
        case blank
    }

    struct Feedback: Equatable {
        let headline: String
        let detail: String
    }

    struct Question: Equatable {
        let kind: QuestionKind
        let promptTitle: String
        /// Substrings of `promptTitle` drawn in accent weight.
        let promptHighlights: [String]
        let promptTokens: [PromptToken]
        let choices: [String]
        let correctAnswer: String
        let explanationContext: ExplanationContext
    }

    struct ExplanationContext: Equatable {
        let tonicSpelling: String
        let kind: ScaleKind
        let voicing: DiatonicVoicing
        let degree: DiatonicDegree
        let roman: String
        let compactName: String
        let rootDisplayName: String
        let qualityTitle: String
        let diatonicNames: [String]
    }

    private let catalog: [CatalogEntry]
    private var previousQuestionID: String?

    private(set) var question: Question
    private(set) var selectedAnswer: String?
    private(set) var correctCount = 0
    private(set) var answeredCount = 0

    var hasAnswered: Bool { selectedAnswer != nil }

    var isSelectionCorrect: Bool {
        selectedAnswer == question.correctAnswer
    }

    init() {
        catalog = Self.buildCatalog()
        question = Self.placeholderQuestion
        question = makeQuestion()
    }

    func select(_ answer: String) {
        guard selectedAnswer == nil else { return }
        selectedAnswer = answer
        answeredCount += 1
        if answer == question.correctAnswer {
            correctCount += 1
        }
    }

    func nextQuestion() {
        selectedAnswer = nil
        question = makeQuestion()
    }

    func feedback(for answer: String) -> Feedback {
        let ctx = question.explanationContext

        if answer == question.correctAnswer {
            return Feedback(headline: "정답", detail: explanation(for: ctx))
        }

        return Feedback(
            headline: "\(answer) ✕ → \(question.correctAnswer) ✓",
            detail: explanation(for: ctx)
        )
    }

    // MARK: - Generation

    private func makeQuestion() -> Question {
        for _ in 0..<80 {
            let candidate: Question?
            switch Int.random(in: 0..<3) {
            case 0:
                candidate = makeCompleteRomanPatternQuestion()
            case 1:
                candidate = makeIdentifyQualityQuestion()
            default:
                candidate = makeIdentifyNonDiatonicQuestion()
            }
            if let question = candidate {
                previousQuestionID = questionID(for: question)
                return question
            }
        }
        return fallbackQuestion
    }

    private func makeCompleteRomanPatternQuestion() -> Question? {
        guard let kind = ScaleKind.allCases.randomElement(),
              let voicing = DiatonicVoicing.allCases.randomElement(),
              let blank = DiatonicDegree.allCases.randomElement()
        else { return nil }

        let questionID = "roman-pattern-\(kind.rawValue)|\(voicing.rawValue)-\(blank.rawValue)"
        if questionID == previousQuestionID { return nil }

        let romans = DiatonicDegree.allCases.map {
            DiatonicChordModel.roman(kind: kind, voicing: voicing, degree: $0)
        }
        let correct = romans[blank.rawValue]
        let distractors = romanQualityVariants(kind: kind, voicing: voicing, degree: blank)
        guard let choices = uniqueChoices(correct: correct, distractors: distractors) else {
            return nil
        }

        let tokens: [PromptToken] = DiatonicDegree.allCases.map { degree in
            degree == blank ? .blank : .roman(romans[degree.rawValue])
        }
        let scalePhrase = "\(kind.englishTitle) 스케일"
        let phrase = constructedChordPhrase(voicing)

        return Question(
            kind: .completeRomanPattern,
            promptTitle: "\(scalePhrase)의 다이아토닉 \(phrase) 규칙을 완성하세요.",
            promptHighlights: [kind.englishTitle, voicing.title],
            promptTokens: tokens,
            choices: choices,
            correctAnswer: correct,
            explanationContext: ExplanationContext(
                tonicSpelling: "C",
                kind: kind,
                voicing: voicing,
                degree: blank,
                roman: correct,
                compactName: "",
                rootDisplayName: "",
                qualityTitle: "",
                diatonicNames: romans
            )
        )
    }

    private func makeIdentifyQualityQuestion() -> Question? {
        guard let (entry, chord) = pickChord() else { return nil }
        let questionID = "quality-\(entry.kind.rawValue)|\(entry.voicing.rawValue)-\(chord.degree.rawValue)"
        if questionID == previousQuestionID { return nil }

        let correct = chord.quality.englishTitle
        let family = qualityFamily(for: chord.quality)
        guard let choices = uniqueChoices(
            correct: correct,
            distractors: family.map(\.englishTitle)
        ) else { return nil }

        let ordinal = degreeOrdinal(chord.degree)
        let phrase = constructedChordPhrase(entry.voicing)
        return Question(
            kind: .identifyQuality,
            promptTitle: "\(entry.kind.englishTitle) 스케일에서 \(ordinal) 음을 근음으로 하는 \(phrase)의 품질은?",
            promptHighlights: [entry.kind.englishTitle, ordinal, entry.voicing.title],
            promptTokens: [],
            choices: choices,
            correctAnswer: correct,
            explanationContext: explanationContext(entry: entry, chord: chord)
        )
    }

    private func makeIdentifyNonDiatonicQuestion() -> Question? {
        guard let entry = catalog.randomElement() else { return nil }
        let diatonic = entry.chords.map(\.compactName)
        guard diatonic.count == DiatonicDegree.allCases.count else { return nil }
        guard let outsider = nonDiatonicChordName(for: entry) else { return nil }

        let questionID = "non-diatonic-\(entry.id)-\(outsider)"
        if questionID == previousQuestionID { return nil }

        guard let choices = uniqueChoices(correct: outsider, distractors: diatonic) else {
            return nil
        }

        let scalePhrase = "\(entry.scaleDisplayName) 스케일"
        let phrase = constructedChordPhrase(entry.voicing)
        return Question(
            kind: .identifyNonDiatonic,
            promptTitle: "다음 중, \(scalePhrase)의 다이아토닉 \(phrase)가 아닌 것은?",
            promptHighlights: [entry.scaleDisplayName, entry.voicing.title],
            promptTokens: [],
            choices: choices,
            correctAnswer: outsider,
            explanationContext: ExplanationContext(
                tonicSpelling: entry.tonic,
                kind: entry.kind,
                voicing: entry.voicing,
                degree: .i,
                roman: "",
                compactName: outsider,
                rootDisplayName: "",
                qualityTitle: "",
                diatonicNames: diatonic
            )
        )
    }

    // MARK: - Feedback helpers

    private func explanation(for context: ExplanationContext) -> String {
        switch question.kind {
        case .completeRomanPattern:
            return romanPatternExplanation(context: context)
        case .identifyQuality:
            return qualityExplanation(context: context)
        case .identifyNonDiatonic:
            return nonDiatonicExplanation(context: context)
        }
    }

    private func romanPatternExplanation(context: ExplanationContext) -> String {
        let phrase = constructedChordPhrase(context.voicing)
        let list = context.diatonicNames.joined(separator: " · ")
        return "\(context.kind.englishTitle) 스케일의 다이아토닉 \(phrase) 규칙은 \(list)입니다."
    }

    private func qualityExplanation(context: ExplanationContext) -> String {
        let ordinal = degreeOrdinal(context.degree)
        let phrase = constructedChordPhrase(context.voicing)
        return "\(context.kind.englishTitle) 스케일에서 \(ordinal) 음을 근음으로 하는 \(phrase)는 \(context.qualityTitle)(\(context.roman))입니다."
    }

    private func nonDiatonicExplanation(context: ExplanationContext) -> String {
        let phrase = constructedChordPhrase(context.voicing)
        let scale = "\(scaleLabel(tonic: context.tonicSpelling, kind: context.kind)) 스케일"
        let pairs = zip(context.diatonicNames, DiatonicDegree.allCases).map { name, degree in
            let roman = DiatonicChordModel.roman(
                kind: context.kind,
                voicing: context.voicing,
                degree: degree
            )
            return "\(name)(\(roman))"
        }
        .joined(separator: " · ")
        return """
        \(scale)의 다이아토닉 \(phrase) : \(pairs)
        \(context.compactName)는 다이아토닉 코드가 아닙니다.
        """
    }

    // MARK: - Distractors & catalog

    private func uniqueChoices(correct: String, distractors: [String]) -> [String]? {
        var unique: [String] = []
        var seen: Set<String> = [correct]
        for name in distractors.shuffled() where seen.insert(name).inserted {
            unique.append(name)
            if unique.count == 3 { break }
        }
        guard unique.count == 3 else { return nil }
        return (unique + [correct]).shuffled()
    }

    private func pickChord() -> (CatalogEntry, DiatonicChordEntry)? {
        guard let entry = catalog.randomElement(),
              let chord = entry.chords.randomElement()
        else { return nil }
        return (entry, chord)
    }

    private func qualityFamily(for quality: DiatonicChordQuality) -> [DiatonicChordQuality] {
        if quality.isSeventh {
            return [
                .major7, .minor7, .dominant7, .minorMajor7,
                .halfDiminished7, .diminished7, .augmentedMajor7,
            ]
        }
        return [.major, .minor, .augmented, .diminished]
    }

    /// Same-degree roman numerals with other chord qualities, keeping the scale's accidental.
    private func romanQualityVariants(
        kind: ScaleKind,
        voicing: DiatonicVoicing,
        degree: DiatonicDegree
    ) -> [String] {
        let qualities: [DiatonicChordQuality] = voicing == .seventh
            ? [.major7, .minor7, .dominant7, .minorMajor7, .halfDiminished7, .diminished7, .augmentedMajor7]
            : [.major, .minor, .augmented, .diminished]
        return qualities.map { roman(kind: kind, degree: degree, quality: $0) }
    }

    private func roman(
        kind: ScaleKind,
        degree: DiatonicDegree,
        quality: DiatonicChordQuality
    ) -> String {
        let accidental = romanAccidental(kind: kind, degree: degree)
        let numeral: String
        switch quality {
        case .major, .augmented, .major7, .dominant7, .augmentedMajor7:
            numeral = degree.upperRoman
        case .minor, .diminished, .minor7, .minorMajor7, .halfDiminished7, .diminished7:
            numeral = degree.lowerRoman
        }
        return accidental + numeral + quality.romanQualitySuffix
    }

    private func romanAccidental(kind: ScaleKind, degree: DiatonicDegree) -> String {
        switch (kind, degree) {
        case (.naturalMinor, .iii), (.harmonicMinor, .iii), (.melodicMinor, .iii):
            return "♭"
        case (.naturalMinor, .vi), (.harmonicMinor, .vi):
            return "♭"
        case (.naturalMinor, .vii):
            return "♭"
        default:
            return ""
        }
    }

    /// A same-voicing chord whose compact name is not among the key's seven diatonic chords.
    private func nonDiatonicChordName(for entry: CatalogEntry) -> String? {
        let diatonic = Set(entry.chords.map(\.compactName))
        var altered: [String] = []
        var seen = Set<String>()

        for chord in entry.chords {
            for quality in qualityFamily(for: chord.quality) where quality != chord.quality {
                let name = quality.compactName(rootDisplayName: chord.rootDisplayName)
                if !diatonic.contains(name), seen.insert(name).inserted {
                    altered.append(name)
                }
            }
        }
        if let pick = altered.randomElement() {
            return pick
        }

        for other in catalog.shuffled() where other.voicing == entry.voicing {
            for chord in other.chords {
                if !diatonic.contains(chord.compactName) {
                    return chord.compactName
                }
            }
        }
        return nil
    }

    private func explanationContext(
        entry: CatalogEntry,
        chord: DiatonicChordEntry
    ) -> ExplanationContext {
        ExplanationContext(
            tonicSpelling: entry.tonic,
            kind: entry.kind,
            voicing: entry.voicing,
            degree: chord.degree,
            roman: chord.roman,
            compactName: chord.compactName,
            rootDisplayName: chord.rootDisplayName,
            qualityTitle: chord.quality.englishTitle,
            diatonicNames: entry.chords.map(\.compactName)
        )
    }

    private func scaleLabel(tonic: String, kind: ScaleKind) -> String {
        Self.scaleLabel(tonic: tonic, kind: kind)
    }

    private static func scaleLabel(tonic: String, kind: ScaleKind) -> String {
        "\(ScaleModel.formatNoteName(tonic)) \(kind.englishTitle)"
    }

    private func constructedChordPhrase(_ voicing: DiatonicVoicing) -> String {
        "\(voicing.title) 코드"
    }

    private func degreeOrdinal(_ degree: DiatonicDegree) -> String {
        "\(degree.rawValue + 1)도"
    }

    private struct CatalogEntry: Equatable {
        let tonic: String
        let kind: ScaleKind
        let voicing: DiatonicVoicing
        let chords: [DiatonicChordEntry]

        var id: String { "\(tonic)|\(kind.rawValue)|\(voicing.rawValue)" }

        var scaleDisplayName: String {
            DiatonicChordQuizModel.scaleLabel(tonic: tonic, kind: kind)
        }
    }

    private static let quizTonics: [String] = [
        "C", "G", "D", "A", "E", "B", "F#",
        "Db", "Ab", "Eb", "Bb", "F",
        "C#", "Gb",
    ]

    private static func buildCatalog() -> [CatalogEntry] {
        var entries: [CatalogEntry] = []
        for tonic in quizTonics {
            for kind in ScaleKind.allCases {
                for voicing in DiatonicVoicing.allCases {
                    let chords = DiatonicChordModel.chords(tonic: tonic, kind: kind, voicing: voicing)
                    guard chords.count == DiatonicDegree.allCases.count else { continue }
                    let tones = chords.flatMap(\.toneSpellings)
                    guard tones.allSatisfy({ !$0.contains("##") && !$0.hasSuffix("bb") }) else {
                        continue
                    }
                    entries.append(
                        CatalogEntry(tonic: tonic, kind: kind, voicing: voicing, chords: chords)
                    )
                }
            }
        }
        return entries
    }

    private func questionID(for question: Question) -> String {
        let ctx = question.explanationContext
        switch question.kind {
        case .completeRomanPattern:
            return "roman-pattern-\(ctx.kind.rawValue)|\(ctx.voicing.rawValue)-\(ctx.degree.rawValue)"
        case .identifyQuality:
            return "quality-\(ctx.kind.rawValue)|\(ctx.voicing.rawValue)-\(ctx.degree.rawValue)"
        case .identifyNonDiatonic:
            return "non-diatonic-\(ctx.tonicSpelling)|\(ctx.kind.rawValue)|\(ctx.voicing.rawValue)-\(ctx.compactName)"
        }
    }

    private var fallbackQuestion: Question {
        let romans = ["I", "ii", "iii", "IV", "V", "vi", "vii°"]
        return Question(
            kind: .completeRomanPattern,
            promptTitle: "Major 스케일의 다이아토닉 Triad 코드 규칙을 완성하세요.",
            promptHighlights: ["Major", "Triad"],
            promptTokens: [
                .roman("I"), .roman("ii"), .blank, .roman("IV"),
                .roman("V"), .roman("vi"), .roman("vii°"),
            ],
            choices: ["iii", "III", "iii°", "III+"].shuffled(),
            correctAnswer: "iii",
            explanationContext: ExplanationContext(
                tonicSpelling: "C",
                kind: .major,
                voicing: .triad,
                degree: .iii,
                roman: "iii",
                compactName: "",
                rootDisplayName: "",
                qualityTitle: "",
                diatonicNames: romans
            )
        )
    }

    private static var placeholderQuestion: Question {
        Question(
            kind: .completeRomanPattern,
            promptTitle: "",
            promptHighlights: [],
            promptTokens: [],
            choices: [],
            correctAnswer: "",
            explanationContext: ExplanationContext(
                tonicSpelling: "C",
                kind: .major,
                voicing: .triad,
                degree: .i,
                roman: "I",
                compactName: "",
                rootDisplayName: "",
                qualityTitle: "",
                diatonicNames: []
            )
        )
    }
}

private extension DiatonicDegree {
    var upperRoman: String {
        switch self {
        case .i: "I"
        case .ii: "II"
        case .iii: "III"
        case .iv: "IV"
        case .v: "V"
        case .vi: "VI"
        case .vii: "VII"
        }
    }

    var lowerRoman: String {
        switch self {
        case .i: "i"
        case .ii: "ii"
        case .iii: "iii"
        case .iv: "iv"
        case .v: "v"
        case .vi: "vi"
        case .vii: "vii"
        }
    }
}

private extension DiatonicChordQuality {
    var romanQualitySuffix: String {
        switch self {
        case .major, .minor: ""
        case .diminished: "°"
        case .augmented: "+"
        case .major7: "M7"
        case .minor7: "7"
        case .dominant7: "7"
        case .minorMajor7: "M7"
        case .halfDiminished7: "7♭5"
        case .diminished7: "°7"
        case .augmentedMajor7: "+M7"
        }
    }
}
