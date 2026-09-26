//

import Foundation

/// Difficulty chosen before a diatonic-chord quiz session.
enum DiatonicChordQuizDifficulty: String, CaseIterable, Hashable, Identifiable {
    case easy
    case normal
    case hard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .easy: "Easy"
        case .normal: "Normal"
        case .hard: "Hard"
        }
    }

    var allowedKinds: [ScaleKind] {
        switch self {
        case .easy: [.major, .naturalMinor]
        case .normal, .hard: ScaleKind.allCases
        }
    }

    var allowedVoicings: [DiatonicVoicing] {
        switch self {
        case .easy: [.triad]
        case .normal, .hard: DiatonicVoicing.allCases
        }
    }

    /// Key-signature limit for non-diatonic questions. Nil uses the full catalog.
    var maxSignatureCount: Int? {
        switch self {
        case .easy: 1
        case .normal: 3
        case .hard: nil
        }
    }

    /// Roman-pattern, quality, and non-diatonic weights.
    var questionWeights: (roman: Int, quality: Int, nonDiatonic: Int) {
        switch self {
        case .easy: (45, 40, 15)
        case .normal: (35, 35, 30)
        case .hard: (25, 25, 50)
        }
    }
}

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

    let difficulty: DiatonicChordQuizDifficulty
    /// Number of questions in this session: 10, 20, 30, 40, or 50.
    let questionLimit: Int
    private let catalog: [CatalogEntry]
    private var previousQuestionID: String?
    /// Scale, voicing, and degree shared by the last roman-pattern or quality question.
    private var previousRuleKey: String?

    private(set) var question: Question
    private(set) var selectedAnswer: String?
    private(set) var correctCount = 0
    private(set) var answeredCount = 0
    /// One entry per answered question, in order. `true` is a correct answer.
    private(set) var outcomes: [Bool] = []
    private(set) var isFinished = false

    var hasAnswered: Bool { selectedAnswer != nil }

    var incorrectCount: Int { answeredCount - correctCount }

    var isSelectionCorrect: Bool {
        selectedAnswer == question.correctAnswer
    }

    var isOnFinalAnswer: Bool {
        hasAnswered && answeredCount >= questionLimit
    }

    init(difficulty: DiatonicChordQuizDifficulty, questionLimit: Int) {
        self.difficulty = difficulty
        self.questionLimit = Self.normalizedQuestionCount(questionLimit)
        catalog = Self.buildCatalog()
        question = Self.placeholderQuestion
        question = makeQuestion()
    }

    func select(_ answer: String) {
        guard selectedAnswer == nil, !isFinished else { return }
        selectedAnswer = answer
        answeredCount += 1
        let correct = answer == question.correctAnswer
        if correct {
            correctCount += 1
        }
        outcomes.append(correct)
    }

    func nextQuestion() {
        guard hasAnswered, !isFinished, answeredCount < questionLimit else { return }
        selectedAnswer = nil
        question = makeQuestion()
    }

    func finish() {
        guard isOnFinalAnswer else { return }
        isFinished = true
    }

    static func normalizedQuestionCount(_ count: Int) -> Int {
        let stepped = (count / 10) * 10
        return min(50, max(10, stepped))
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
            switch weightedKind() {
            case .completeRomanPattern:
                candidate = makeCompleteRomanPatternQuestion()
            case .identifyQuality:
                candidate = makeIdentifyQualityQuestion()
            case .identifyNonDiatonic:
                candidate = makeIdentifyNonDiatonicQuestion()
            }
            if let question = candidate {
                remember(question)
                return question
            }
        }
        let fallback = fallbackQuestion
        remember(fallback)
        return fallback
    }

    private func weightedKind() -> QuestionKind {
        let weights = difficulty.questionWeights
        let buckets: [(QuestionKind, Int)] = [
            (.completeRomanPattern, weights.roman),
            (.identifyQuality, weights.quality),
            (.identifyNonDiatonic, weights.nonDiatonic),
        ]
        let total = buckets.reduce(0) { $0 + $1.1 }
        var roll = Int.random(in: 0..<total)
        for (kind, weight) in buckets {
            if roll < weight { return kind }
            roll -= weight
        }
        return .completeRomanPattern
    }

    private func makeCompleteRomanPatternQuestion() -> Question? {
        guard let kind = difficulty.allowedKinds.randomElement(),
              let voicing = difficulty.allowedVoicings.randomElement(),
              let blank = DiatonicDegree.allCases.randomElement()
        else { return nil }

        let ruleKey = ruleKey(kind: kind, voicing: voicing, degree: blank)
        if ruleKey == previousRuleKey { return nil }
        let questionID = "roman-pattern-\(ruleKey)"
        if questionID == previousQuestionID { return nil }

        let romans = DiatonicDegree.allCases.map {
            DiatonicChordModel.roman(kind: kind, voicing: voicing, degree: $0)
        }
        let correct = romans[blank.rawValue]
        guard let quality = referenceQuality(kind: kind, voicing: voicing, degree: blank) else {
            return nil
        }
        let distractors = distractorQualities(for: quality).map {
            roman(kind: kind, degree: blank, quality: $0)
        }
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
        let ruleKey = ruleKey(kind: entry.kind, voicing: entry.voicing, degree: chord.degree)
        if ruleKey == previousRuleKey { return nil }
        let questionID = "quality-\(ruleKey)"
        if questionID == previousQuestionID { return nil }

        let correct = chord.quality.englishTitle
        guard let choices = uniqueChoices(
            correct: correct,
            distractors: distractorQualities(for: chord.quality).map(\.englishTitle)
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
        guard let entry = type3Catalog.randomElement() else { return nil }
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
        return "\(context.kind.englishTitle) 스케일의 다이아토닉 \(phrase) 규칙 : \(list)"
    }

    private func qualityExplanation(context: ExplanationContext) -> String {
        let ordinal = degreeOrdinal(context.degree)
        let phrase = constructedChordPhrase(context.voicing)
        let romans = DiatonicDegree.allCases.map {
            DiatonicChordModel.roman(kind: context.kind, voicing: context.voicing, degree: $0)
        }
        .joined(separator: " · ")
        return """
        \(context.kind.englishTitle) 스케일에서 \(ordinal) 음을 근음으로 하는 \(phrase)는 \(context.qualityTitle)(\(context.roman))입니다.
        \(context.kind.englishTitle) 스케일의 다이아토닉 \(phrase) 규칙 : \(romans)
        """
    }

    private func nonDiatonicExplanation(context: ExplanationContext) -> String {
        let phrase = constructedChordPhrase(context.voicing)
        let scale = "\(scaleLabel(tonic: context.tonicSpelling, kind: context.kind)) 스케일"
        let names = context.diatonicNames.joined(separator: " · ")
        let romans = DiatonicDegree.allCases.map {
            DiatonicChordModel.roman(
                kind: context.kind,
                voicing: context.voicing,
                degree: $0
            )
        }
        .joined(separator: " · ")
        return """
        \(scale)의 다이아토닉 \(phrase) : \(names) (\(romans))
        \(context.compactName)는 \(scale)의 다이아토닉 코드가 아닙니다.
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
        guard let entry = ruleCatalog.randomElement(),
              let chord = entry.chords.randomElement()
        else { return nil }
        return (entry, chord)
    }

    private var ruleCatalog: [CatalogEntry] {
        catalog.filter {
            difficulty.allowedKinds.contains($0.kind) && difficulty.allowedVoicings.contains($0.voicing)
        }
    }

    private var type3Catalog: [CatalogEntry] {
        ruleCatalog.filter { entry in
            guard let maxCount = difficulty.maxSignatureCount else { return true }
            guard let count = signatureCount(tonic: entry.tonic, kind: entry.kind) else { return false }
            return count <= maxCount
        }
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

    /// Triads keep every other quality. Sevenths keep the three nearest or farthest.
    private func distractorQualities(for quality: DiatonicChordQuality) -> [DiatonicChordQuality] {
        let others = qualityFamily(for: quality).filter { $0 != quality }
        guard quality.isSeventh else { return others }
        let preferNear = difficulty == .hard
        return Array(rankedByDistance(others, from: quality, preferNear: preferNear).prefix(3))
    }

    private func rankedByDistance(
        _ qualities: [DiatonicChordQuality],
        from quality: DiatonicChordQuality,
        preferNear: Bool
    ) -> [DiatonicChordQuality] {
        let grouped = Dictionary(grouping: qualities) { quality.toneDifferenceCount(from: $0) }
        let distances = grouped.keys.sorted()
        let ordered = preferNear ? distances : distances.reversed()
        return ordered.flatMap { (grouped[$0] ?? []).shuffled() }
    }

    private func referenceQuality(
        kind: ScaleKind,
        voicing: DiatonicVoicing,
        degree: DiatonicDegree
    ) -> DiatonicChordQuality? {
        let chords = DiatonicChordModel.chords(tonic: "C", kind: kind, voicing: voicing)
        guard chords.count == DiatonicDegree.allCases.count else { return nil }
        return chords[degree.rawValue].quality
    }

    private func ruleKey(
        kind: ScaleKind,
        voicing: DiatonicVoicing,
        degree: DiatonicDegree
    ) -> String {
        "\(kind.rawValue)|\(voicing.rawValue)-\(degree.rawValue)"
    }

    private func remember(_ question: Question) {
        previousQuestionID = questionID(for: question)
        let context = question.explanationContext
        switch question.kind {
        case .completeRomanPattern, .identifyQuality:
            previousRuleKey = ruleKey(kind: context.kind, voicing: context.voicing, degree: context.degree)
        case .identifyNonDiatonic:
            previousRuleKey = nil
        }
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

    /// Same root, different quality. Easy and Normal prefer a distant quality; Hard prefers the nearest.
    private func nonDiatonicChordName(for entry: CatalogEntry) -> String? {
        let diatonic = Set(entry.chords.map(\.compactName))
        var candidates: [(name: String, distance: Int)] = []
        var seen = Set<String>()

        for chord in entry.chords {
            for quality in qualityFamily(for: chord.quality) where quality != chord.quality {
                let name = quality.compactName(rootDisplayName: chord.rootDisplayName)
                guard !diatonic.contains(name), seen.insert(name).inserted else { continue }
                candidates.append((name, chord.quality.toneDifferenceCount(from: quality)))
            }
        }
        guard !candidates.isEmpty else { return nil }

        let preferNear = difficulty == .hard
        let target = preferNear
            ? candidates.map(\.distance).min()
            : candidates.map(\.distance).max()
        guard let target else { return nil }
        return candidates.filter { $0.distance == target }.randomElement()?.name
    }

    /// Accidentals in the key signature. Minor kinds share the natural-minor signature.
    private func signatureCount(tonic: String, kind: ScaleKind) -> Int? {
        switch kind {
        case .major:
            return Self.majorSignatureCount[tonic]
        case .naturalMinor, .harmonicMinor, .melodicMinor:
            let scale = ScaleModel.spellings(tonic: tonic, kind: .naturalMinor)
            guard scale.count >= 3 else { return nil }
            return Self.majorSignatureCount[scale[2]]
        }
    }

    private static let majorSignatureCount: [String: Int] = [
        "C": 0,
        "G": 1, "F": 1,
        "D": 2, "Bb": 2,
        "A": 3, "Eb": 3,
        "E": 4, "Ab": 4,
        "B": 5, "Db": 5,
        "F#": 6, "Gb": 6,
        "C#": 7,
    ]

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
    /// Root-position intervals above the root: third, fifth, and seventh when present.
    var toneIntervals: [Int] {
        switch self {
        case .major: [4, 7]
        case .minor: [3, 7]
        case .augmented: [4, 8]
        case .diminished: [3, 6]
        case .major7: [4, 7, 11]
        case .minor7: [3, 7, 10]
        case .dominant7: [4, 7, 10]
        case .minorMajor7: [3, 7, 11]
        case .halfDiminished7: [3, 6, 10]
        case .diminished7: [3, 6, 9]
        case .augmentedMajor7: [4, 8, 11]
        }
    }

    func toneDifferenceCount(from other: DiatonicChordQuality) -> Int {
        zip(toneIntervals, other.toneIntervals).filter { $0 != $1 }.count
    }

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
