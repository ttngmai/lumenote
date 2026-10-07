//

import Foundation

/// Difficulty chosen before a scale quiz session.
enum ScaleQuizDifficulty: String, CaseIterable, Hashable, Identifiable {
    case easy
    case normal
    case hard

    static let storageKey = "scaleQuizDifficulty"
    static let questionCountStorageKey = "scaleQuizQuestionCount"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .easy: "Easy"
        case .normal: "Normal"
        case .hard: "Hard"
        }
    }
}

/// Mixed scale quiz: complete notes, identify scale, interval pattern, degree formula, identify degree.
@MainActor
@Observable
final class ScaleQuizModel {
    enum QuestionKind: Equatable {
        /// Fill one missing scale degree.
        case completeScale
        /// Given ascending degrees, pick the scale name.
        case identifyScale
        /// Fill one missing whole/half (or aug2) step in the pattern.
        /// Heptatonic scales only.
        case completePattern
        /// Fill one degree, or two on Hard, in the scale-degree formula.
        case completeFormula
        /// Ask which note is a given scale degree.
        case identifyDegree
        /// Ask which note is not a member of the scale.
        case excludedNote

        var skillToken: String {
            switch self {
            case .completeScale: LearningSkillToken.Scale.completeScale
            case .identifyScale: LearningSkillToken.Scale.identifyScale
            case .completePattern: LearningSkillToken.Scale.completePattern
            case .completeFormula: LearningSkillToken.Scale.completeFormula
            case .identifyDegree: LearningSkillToken.Scale.identifyDegree
            case .excludedNote: LearningSkillToken.Scale.excludedNote
            }
        }
    }

    enum PromptToken: Equatable {
        case note(String)
        case blank
        case step(String)
        case stepBlank
        case degree(String)
        case degreeBlank
    }

    struct Feedback: Equatable {
        let headline: String
        let detail: String
    }

    struct Question: Equatable {
        let kind: QuestionKind
        let promptTitle: String
        /// e.g. "D Major"
        let scaleLabel: String
        let promptTokens: [PromptToken]
        /// Optional staff for identify-scale prompts.
        let staffNotes: [IntervalStaffNote]
        let staffIntervals: [ScaleStepInterval]
        let staffNoteNames: [String]
        let choices: [String]
        let correctAnswer: String
        /// Used to build wrong-answer explanations.
        let explanationContext: ExplanationContext
    }

    struct ExplanationContext: Equatable {
        let tonicSpelling: String
        let kind: ScaleKind
        let degreeSpellings: [String]
        let blankIndex: Int?
        let degreeNumber: Int?
        /// Printed degree such as "♭5". Nil when the question is not about one degree.
        let degreeLabel: String?
        let askedNoteDisplay: String?

        init(
            tonicSpelling: String,
            kind: ScaleKind,
            degreeSpellings: [String],
            blankIndex: Int?,
            degreeNumber: Int?,
            degreeLabel: String? = nil,
            askedNoteDisplay: String?
        ) {
            self.tonicSpelling = tonicSpelling
            self.kind = kind
            self.degreeSpellings = degreeSpellings
            self.blankIndex = blankIndex
            self.degreeNumber = degreeNumber
            self.degreeLabel = degreeLabel
            self.askedNoteDisplay = askedNoteDisplay
        }
    }

    let difficulty: ScaleQuizDifficulty
    /// Number of questions in this session: 10, 20, 30, 40, or 50.
    /// Review sessions use the number of due skills, from 1 through 10.
    let questionLimit: Int
    private let recorder: (any LearningRecording)?
    private let focusSkillKeys: Set<String>
    /// Set only while a review question is being built for one scale kind.
    private var reviewKind: ScaleKind?
    private let explorer = ScaleModel()
    private let catalog: [CatalogEntry]
    private var previousQuestionID: String?

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

    init(
        difficulty: ScaleQuizDifficulty,
        questionLimit: Int,
        recorder: (any LearningRecording)? = nil,
        focusSkillKeys: Set<String> = []
    ) {
        self.difficulty = difficulty
        self.recorder = recorder
        self.focusSkillKeys = focusSkillKeys
        self.questionLimit = focusSkillKeys.isEmpty
            ? Self.normalizedQuestionCount(questionLimit)
            : min(10, max(1, questionLimit))
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
        recorder?.record(
            LearningAttemptInput(
                topic: .scale,
                skillKey: learningSkillKey(for: question),
                correct: correct,
                expected: question.correctAnswer,
                chosen: answer,
                difficulty: difficulty.rawValue
            )
        )
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
        let degrees = ctx.degreeSpellings.map(ScaleModel.formatNoteName)
        let scaleName = scaleDisplayName(tonic: ctx.tonicSpelling, kind: ctx.kind)

        if answer == question.correctAnswer {
            return Feedback(
                headline: "정답".l10n,
                detail: correctDetail(for: question.kind, scaleName: scaleName, degrees: degrees, context: ctx)
            )
        }

        switch question.kind {
        case .completeScale:
            return Feedback(
                headline: "\(answer) ✕ → \(question.correctAnswer) ✓",
                detail: degreeNoteDetail(scaleName: scaleName, degrees: degrees, context: ctx)
            )
        case .identifyScale:
            return Feedback(
                headline: "\(answer) ✕ → \(question.correctAnswer) ✓",
                detail: ""
            )
        case .completePattern, .completeFormula:
            return Feedback(
                headline: "\(answer) ✕ → \(question.correctAnswer) ✓",
                detail: question.kind == .completeFormula ? formulaDetail(kind: ctx.kind) : ""
            )
        case .identifyDegree:
            return degreeWrongFeedback(answer: answer, scaleName: scaleName, degrees: degrees, context: ctx)
        case .excludedNote:
            return Feedback(
                headline: "\(answer) ✕ → \(question.correctAnswer) ✓",
                detail: excludedNoteDetail(scaleName: scaleName)
            )
        }
    }

    // MARK: - Generation

    private func makeQuestion() -> Question {
        if !focusSkillKeys.isEmpty, let focused = makeFocusedQuestion() {
            return focused
        }
        for _ in 0..<80 {
            let candidate: Question?
            switch weightedQuestionKind() {
            case .completeScale:
                candidate = makeCompleteScaleQuestion()
            case .identifyScale:
                candidate = makeIdentifyScaleQuestion()
            case .completePattern:
                candidate = makeCompletePatternQuestion()
            case .completeFormula:
                candidate = makeCompleteFormulaQuestion()
            case .identifyDegree:
                candidate = makeIdentifyDegreeQuestion()
            case .excludedNote:
                candidate = makeExcludedNoteQuestion()
            }
            if let question = candidate {
                previousQuestionID = questionID(for: question)
                return question
            }
        }
        return fallbackQuestion
    }

    private func makeFocusedQuestion() -> Question? {
        for _ in 0..<40 {
            guard let raw = focusSkillKeys.randomElement(),
                  let parsed = LearningSkillKey.parseScale(raw)
            else { continue }
            reviewKind = parsed.kind
            let candidate: Question?
            switch parsed.token {
            case LearningSkillToken.Scale.completeScale:
                candidate = makeCompleteScaleQuestion()
            case LearningSkillToken.Scale.identifyScale:
                candidate = makeIdentifyScaleQuestion()
            case LearningSkillToken.Scale.completePattern:
                candidate = makeCompletePatternQuestion()
            case LearningSkillToken.Scale.completeFormula:
                candidate = makeCompleteFormulaQuestion()
            case LearningSkillToken.Scale.identifyDegree:
                candidate = makeIdentifyDegreeQuestion()
            case LearningSkillToken.Scale.excludedNote:
                candidate = makeExcludedNoteQuestion()
            default:
                candidate = nil
            }
            reviewKind = nil
            if let candidate {
                previousQuestionID = questionID(for: candidate)
                return candidate
            }
        }
        reviewKind = nil
        return nil
    }

    private func learningSkillKey(for question: Question) -> String {
        LearningSkillKey.scale(kind: question.explanationContext.kind, token: question.kind.skillToken)
    }

    private func makeCompleteScaleQuestion() -> Question? {
        guard let entry = pickEntry() else { return nil }
        guard let blankIndex = singleBlankIndex(for: entry.kind) else { return nil }
        let questionID = "complete-\(entry.id)-\(blankIndex)"
        if focusSkillKeys.isEmpty, questionID == previousQuestionID { return nil }

        let displays = entry.degreeSpellings.map(ScaleModel.formatNoteName)
        let correct = displays[blankIndex]
        let degreeLabel = entry.kind.degreeLabels[blankIndex]
        let distractors = noteDistractors(
            correctSpelling: entry.degreeSpellings[blankIndex],
            scaleSpellings: entry.degreeSpellings,
            tonic: entry.tonic,
            kind: entry.kind,
            degreeLabel: degreeLabel
        )
        guard distractors.count == 3 else { return nil }

        var tokens: [PromptToken] = []
        for (index, name) in displays.enumerated() {
            if index == blankIndex {
                tokens.append(.blank)
            } else {
                tokens.append(.note(name))
            }
        }

        return Question(
            kind: .completeScale,
            promptTitle: L10n.s("\(entry.displayName) 스케일을 완성하세요."),
            scaleLabel: entry.displayName,
            promptTokens: tokens,
            staffNotes: [],
            staffIntervals: [],
            staffNoteNames: [],
            choices: (distractors + [correct]).shuffled(),
            correctAnswer: correct,
            explanationContext: ExplanationContext(
                tonicSpelling: entry.tonic,
                kind: entry.kind,
                degreeSpellings: entry.degreeSpellings,
                blankIndex: blankIndex,
                degreeNumber: degreeNumber(of: degreeLabel),
                degreeLabel: degreeLabel,
                askedNoteDisplay: nil
            )
        )
    }

    private func makeIdentifyScaleQuestion() -> Question? {
        guard let entry = pickEntry() else { return nil }
        let questionID = "identify-\(entry.id)"
        if focusSkillKeys.isEmpty, questionID == previousQuestionID { return nil }

        var distractors = preferredScaleNames(for: entry)
        if distractors.count < 3 {
            let others = catalog
                .filter { $0.displayName != entry.displayName && !distractors.contains($0.displayName) }
                .shuffled()
                .prefix(3 - distractors.count)
                .map(\.displayName)
            distractors.append(contentsOf: others)
        }
        guard distractors.count >= 3 else { return nil }
        distractors = Array(distractors.prefix(3))

        let displays = entry.degreeSpellings.map(ScaleModel.formatNoteName)
        configureExplorer(entry)
        let staffNotes = explorer.staffNotes
        let staffIntervals = explorer.stepIntervals

        return Question(
            kind: .identifyScale,
            promptTitle: "다음 스케일은 무엇일까요?".l10n,
            scaleLabel: entry.displayName,
            promptTokens: displays.map { .note($0) },
            staffNotes: staffNotes,
            staffIntervals: staffIntervals,
            staffNoteNames: displays,
            choices: (distractors + [entry.displayName]).shuffled(),
            correctAnswer: entry.displayName,
            explanationContext: ExplanationContext(
                tonicSpelling: entry.tonic,
                kind: entry.kind,
                degreeSpellings: entry.degreeSpellings,
                blankIndex: nil,
                degreeNumber: nil,
                askedNoteDisplay: nil
            )
        )
    }

    private func makeCompletePatternQuestion() -> Question? {
        guard let kind = pickPatternKind() else { return nil }
        let blankIndex = patternBlankIndex(for: kind)
        let questionID = "pattern-\(kind.rawValue)-\(blankIndex)"
        if focusSkillKeys.isEmpty, questionID == previousQuestionID { return nil }

        let steps = kind.semitoneSteps.map(ScaleStepInterval.init(semitones:))
        let correct = steps[blankIndex].koreanLabel

        var tokens: [PromptToken] = []
        for (index, step) in steps.enumerated() {
            if index == blankIndex {
                tokens.append(.stepBlank)
            } else {
                tokens.append(.step(step.koreanLabel))
            }
        }

        let choicePool = Array(
            Set(ScaleKind.basicCases.flatMap { kind in
                kind.semitoneSteps.map { ScaleStepInterval(semitones: $0).koreanLabel }
            })
        )
        let distractors = choicePool.filter { $0 != correct }.shuffled().prefix(2)
        guard distractors.count == 2 else { return nil }

        // Prefer a common major tonic for context label; pattern itself is kind-only.
        let tonic = "C"
        let spellings = spellings(tonic: tonic, kind: kind)

        return Question(
            kind: .completePattern,
            promptTitle: L10n.s("\(kind.englishTitle) 스케일의 음정 패턴을 완성하세요."),
            scaleLabel: "\(tonic) \(kind.englishTitle)",
            promptTokens: tokens,
            staffNotes: [],
            staffIntervals: [],
            staffNoteNames: [],
            choices: (Array(distractors) + [correct]).shuffled(),
            correctAnswer: correct,
            explanationContext: ExplanationContext(
                tonicSpelling: tonic,
                kind: kind,
                degreeSpellings: spellings,
                blankIndex: blankIndex,
                degreeNumber: nil,
                askedNoteDisplay: nil
            )
        )
    }

    private func makeCompleteFormulaQuestion() -> Question? {
        guard let kind = pickFormulaKind() else { return nil }
        guard let blankIndices = formulaBlankIndices(for: kind), !blankIndices.isEmpty else { return nil }
        let labels = Array(kind.degreeLabels.dropLast())
        guard blankIndices.allSatisfy({ labels.indices.contains($0) }) else { return nil }
        let questionID = "formula-\(kind.rawValue)-\(blankIndices.map(String.init).joined(separator: ","))"
        if focusSkillKeys.isEmpty, questionID == previousQuestionID { return nil }

        guard let built = formulaChoices(labels: labels, blankIndices: blankIndices) else { return nil }
        var tokens: [PromptToken] = []
        for (index, label) in labels.enumerated() {
            tokens.append(blankIndices.contains(index) ? .degreeBlank : .degree(label))
        }

        let tonic = "C"
        let spellings = spellings(tonic: tonic, kind: kind)
        return Question(
            kind: .completeFormula,
            promptTitle: L10n.s("\(kind.englishTitle) 스케일의 도수 공식을 완성하세요."),
            scaleLabel: "\(tonic) \(kind.englishTitle)",
            promptTokens: tokens,
            staffNotes: [],
            staffIntervals: [],
            staffNoteNames: [],
            choices: (built.distractors + [built.correct]).shuffled(),
            correctAnswer: built.correct,
            explanationContext: ExplanationContext(
                tonicSpelling: tonic,
                kind: kind,
                degreeSpellings: spellings,
                blankIndex: blankIndices[0],
                degreeNumber: nil,
                degreeLabel: built.correct,
                askedNoteDisplay: nil
            )
        )
    }

    private func makeIdentifyDegreeQuestion() -> Question? {
        guard let entry = pickEntry() else { return nil }
        guard let degreeIndex = singleBlankIndex(for: entry.kind) else { return nil }
        let degreeLabel = entry.kind.degreeLabels[degreeIndex]
        let questionID = "degree-\(entry.id)-\(degreeIndex)"
        if focusSkillKeys.isEmpty, questionID == previousQuestionID { return nil }

        let displays = entry.degreeSpellings.map(ScaleModel.formatNoteName)
        let correct = displays[degreeIndex]
        let distractors = noteDistractors(
            correctSpelling: entry.degreeSpellings[degreeIndex],
            scaleSpellings: entry.degreeSpellings,
            tonic: entry.tonic,
            kind: entry.kind,
            degreeLabel: degreeLabel
        )
        guard distractors.count == 3 else { return nil }

        return Question(
            kind: .identifyDegree,
            promptTitle: L10n.s("\(entry.displayName) 스케일의 \(degreeLabel)도 음은?"),
            scaleLabel: entry.displayName,
            promptTokens: [],
            staffNotes: [],
            staffIntervals: [],
            staffNoteNames: [],
            choices: (distractors + [correct]).shuffled(),
            correctAnswer: correct,
            explanationContext: ExplanationContext(
                tonicSpelling: entry.tonic,
                kind: entry.kind,
                degreeSpellings: entry.degreeSpellings,
                blankIndex: degreeIndex,
                degreeNumber: degreeNumber(of: degreeLabel),
                degreeLabel: degreeLabel,
                askedNoteDisplay: nil
            )
        )
    }

    private func makeExcludedNoteQuestion() -> Question? {
        guard let entry = pickEntry() else { return nil }
        guard let correctSpelling = excludedSpelling(for: entry) else { return nil }
        let questionID = "exclude-\(entry.id)-\(correctSpelling)"
        if focusSkillKeys.isEmpty, questionID == previousQuestionID { return nil }

        let correct = ScaleModel.formatNoteName(correctSpelling)
        var distractors: [String] = []
        var seen: Set<String> = [correct]
        for spelling in entry.degreeSpellings.dropLast().shuffled() {
            let display = ScaleModel.formatNoteName(spelling)
            if seen.insert(display).inserted {
                distractors.append(display)
            }
            if distractors.count == 3 { break }
        }
        guard distractors.count == 3 else { return nil }

        return Question(
            kind: .excludedNote,
            promptTitle: L10n.s("\(entry.displayName) 스케일에 포함되지 않는 음은?"),
            scaleLabel: entry.displayName,
            promptTokens: [],
            staffNotes: [],
            staffIntervals: [],
            staffNoteNames: [],
            choices: (distractors + [correct]).shuffled(),
            correctAnswer: correct,
            explanationContext: ExplanationContext(
                tonicSpelling: entry.tonic,
                kind: entry.kind,
                degreeSpellings: entry.degreeSpellings,
                blankIndex: nil,
                degreeNumber: nil,
                askedNoteDisplay: nil
            )
        )
    }

    // MARK: - Feedback helpers

    private func correctDetail(
        for kind: QuestionKind,
        scaleName: String,
        degrees: [String],
        context: ExplanationContext
    ) -> String {
        switch kind {
        case .completeScale:
            return degreeNoteDetail(scaleName: scaleName, degrees: degrees, context: context)
        case .identifyScale:
            return ""
        case .completePattern:
            return ""
        case .completeFormula:
            return formulaDetail(kind: context.kind)
        case .excludedNote:
            return excludedNoteDetail(scaleName: scaleName)
        case .identifyDegree:
            return degreeNoteDetail(scaleName: scaleName, degrees: degrees, context: context)
        }
    }

    private func degreeNoteDetail(
        scaleName: String,
        degrees: [String],
        context: ExplanationContext
    ) -> String {
        guard let index = context.blankIndex, degrees.indices.contains(index) else {
            return scaleName
        }
        let note = degrees[index]
        let label = context.degreeLabel ?? context.degreeNumber.map(String.init) ?? ""
        guard !label.isEmpty else { return scaleName }
        return L10n.s("\(scaleName) 스케일의 \(label)도 음은 \(note)입니다.")
    }

    private func formulaDetail(kind: ScaleKind) -> String {
        let formula = kind.degreeLabels.dropLast().joined(separator: " ")
        return L10n.s("\(kind.englishTitle) 스케일의 도수 공식 : \(formula)")
    }

    private func excludedNoteDetail(scaleName: String) -> String {
        let note = question.correctAnswer
        if LanguageSettings.shared.language == .english {
            return L10n.s("\(note) is not in the \(scaleName) scale.")
        }
        return "\(note)\(topicParticle(for: note)) \(scaleName) 스케일에 포함되지 않습니다."
    }

    /// 은 after a final consonant (♯, ♭, F), 는 otherwise.
    private func topicParticle(for name: String) -> String {
        guard let last = name.last else { return "은" }
        if last == "♯" || last == "♭" || last == "F" {
            return "은"
        }
        return "는"
    }

    private func degreeWrongFeedback(
        answer: String,
        scaleName: String,
        degrees: [String],
        context: ExplanationContext
    ) -> Feedback {
        if context.degreeNumber != nil {
            return Feedback(
                headline: "\(answer) ✕ → \(question.correctAnswer) ✓",
                detail: degreeNoteDetail(scaleName: scaleName, degrees: degrees, context: context)
            )
        }
        return Feedback(headline: "\(answer) ✕ → \(question.correctAnswer) ✓", detail: "")
    }

    // MARK: - Distractors & catalog

    /// Easy favors major, natural minor, and the two pentatonic scales.
    /// Normal and Hard draw the eight kinds evenly, then a tonic that can spell that kind.
    private func pickEntry() -> CatalogEntry? {
        let pool = catalog.filter { allowedTonics.contains($0.tonic) }
        guard !pool.isEmpty else { return nil }
        if let reviewKind {
            return pool.filter { $0.kind == reviewKind }.randomElement()
        }
        switch difficulty {
        case .easy:
            return weightedEntry(from: pool, weights: Self.easyKindWeights)
        case .normal, .hard:
            let kinds = Array(Set(pool.map(\.kind)))
            guard let kind = kinds.randomElement() else { return nil }
            return pool.filter { $0.kind == kind }.randomElement()
        }
    }

    private func weightedEntry(from pool: [CatalogEntry], weights: [ScaleKind: Int]) -> CatalogEntry? {
        let buckets = ScaleKind.allCases.compactMap { kind -> (weight: Int, entries: [CatalogEntry])? in
            let matches = pool.filter { $0.kind == kind }
            let weight = weights[kind] ?? 0
            guard !matches.isEmpty, weight > 0 else { return nil }
            return (weight, matches)
        }
        let total = buckets.reduce(0) { $0 + $1.weight }
        guard total > 0 else { return pool.randomElement() }

        var roll = Int.random(in: 0..<total)
        for bucket in buckets {
            if roll < bucket.weight {
                return bucket.entries.randomElement()
            }
            roll -= bucket.weight
        }
        return pool.randomElement()
    }

    /// 20 / 20 / 15 / 15 / 7.5 / 7.5 / 7.5 / 7.5 percent across the eight kinds.
    private static let easyKindWeights: [ScaleKind: Int] = [
        .major: 8,
        .naturalMinor: 8,
        .majorPentatonic: 6,
        .minorPentatonic: 6,
        .harmonicMinor: 3,
        .melodicMinor: 3,
        .majorBlues: 3,
        .minorBlues: 3,
    ]

    private var allowedTonics: Set<String> {
        switch difficulty {
        case .easy:
            ["C", "G", "F", "D", "Bb"]
        case .normal:
            ["C", "G", "F", "D", "Bb", "A", "E", "Eb", "Ab"]
        case .hard:
            Set(Self.quizTonics)
        }
    }

    private func pickPatternKind() -> ScaleKind? {
        if let reviewKind {
            return ScaleKind.basicCases.contains(reviewKind) ? reviewKind : nil
        }
        switch difficulty {
        case .easy:
            return [.major, .naturalMinor].randomElement()
        case .normal, .hard:
            return ScaleKind.basicCases.randomElement()
        }
    }

    private func pickFormulaKind() -> ScaleKind? {
        if let reviewKind { return reviewKind }
        switch difficulty {
        case .easy:
            return weightedKind(Self.easyKindWeights)
        case .normal, .hard:
            return ScaleKind.allCases.randomElement()
        }
    }

    private func weightedKind(_ weights: [ScaleKind: Int]) -> ScaleKind? {
        let buckets = ScaleKind.allCases.compactMap { kind -> (ScaleKind, Int)? in
            let weight = weights[kind] ?? 0
            return weight > 0 ? (kind, weight) : nil
        }
        let total = buckets.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return ScaleKind.allCases.randomElement() }
        var roll = Int.random(in: 0..<total)
        for (kind, weight) in buckets {
            if roll < weight { return kind }
            roll -= weight
        }
        return buckets.last?.0
    }

    private func weightedQuestionKind() -> QuestionKind {
        let weights: [(QuestionKind, Int)] = [
            (.completeScale, 30),
            (.identifyScale, 20),
            (.completePattern, 15),
            (.completeFormula, 15),
            (.identifyDegree, 10),
            (.excludedNote, 10),
        ]
        let total = weights.reduce(0) { $0 + $1.1 }
        var roll = Int.random(in: 0..<total)
        for (kind, weight) in weights {
            if roll < weight { return kind }
            roll -= weight
        }
        return .completeScale
    }

    /// Skips the tonic and the octave. Normal prefers the degrees that identify the kind.
    private func singleBlankIndex(for kind: ScaleKind) -> Int? {
        let full = innerDegreeIndices(for: kind)
        guard !full.isEmpty else { return nil }
        guard difficulty == .normal else { return full.randomElement() }
        let characteristic = characteristicIndices(for: kind, allowed: full)
        guard !characteristic.isEmpty, Int.random(in: 0..<10) < 7 else {
            return full.randomElement()
        }
        return characteristic.randomElement()
    }

    /// Hard asks for two formula degrees. One of them is a characteristic degree when the kind has one.
    private func formulaBlankIndices(for kind: ScaleKind) -> [Int]? {
        if difficulty != .hard {
            return singleBlankIndex(for: kind).map { [$0] }
        }
        let full = innerDegreeIndices(for: kind)
        guard full.count >= 2 else { return nil }
        let characteristic = characteristicIndices(for: kind, allowed: full)
        guard let first = characteristic.randomElement() ?? full.randomElement() else { return nil }
        guard let second = full.filter({ $0 != first }).randomElement() else { return nil }
        return [first, second].sorted()
    }

    private func innerDegreeIndices(for kind: ScaleKind) -> [Int] {
        let count = kind.degreeLabels.count
        guard count >= 3 else { return [] }
        return Array(1..<(count - 1))
    }

    private func characteristicIndices(for kind: ScaleKind, allowed: [Int]) -> [Int] {
        let wanted = Set(characteristicDegreeLabels(for: kind))
        let labels = kind.degreeLabels
        return allowed.filter { labels.indices.contains($0) && wanted.contains(labels[$0]) }
    }

    /// Degrees that identify the scale. Major has none, so its blank stays random.
    private func characteristicDegreeLabels(for kind: ScaleKind) -> [String] {
        switch kind {
        case .major:
            []
        case .naturalMinor:
            ["♭3", "♭6", "♭7"]
        case .harmonicMinor:
            ["7"]
        case .melodicMinor:
            ["6", "7"]
        case .majorPentatonic:
            ["3", "6"]
        case .minorPentatonic:
            ["♭3", "♭7"]
        case .majorBlues:
            ["♭3"]
        case .minorBlues:
            ["♭5"]
        }
    }

    /// Step index in 0...6. Normal prefers the intervals that distinguish the kind.
    private func patternBlankIndex(for kind: ScaleKind) -> Int {
        let full = Array(0...6)
        guard difficulty == .normal else { return full.randomElement() ?? 0 }
        let characteristic = characteristicStepIndices(for: kind)
        guard !characteristic.isEmpty, Int.random(in: 0..<10) < 7 else {
            return full.randomElement() ?? 0
        }
        return characteristic.randomElement() ?? full[0]
    }

    /// Steps where each kind differs from its nearest relative.
    private func characteristicStepIndices(for kind: ScaleKind) -> [Int] {
        switch kind {
        case .major, .naturalMinor:
            [1, 4, 5, 6]
        case .harmonicMinor:
            [5, 6]
        case .melodicMinor:
            [4, 5, 6]
        case .majorPentatonic, .minorPentatonic, .majorBlues, .minorBlues:
            []
        }
    }

    /// A note spelling that is not one of the scale's degree names.
    /// Easy uses a different pitch. Normal prefers a sibling scale's tone. Hard prefers an enharmonic spelling.
    private func excludedSpelling(for entry: CatalogEntry) -> String? {
        let scaleSpellings = Array(entry.degreeSpellings.dropLast())
        let scaleDisplays = Set(scaleSpellings.map(ScaleModel.formatNoteName))
        let scalePitches = Set(scaleSpellings.map { ScaleModel.pitchClass(for: $0) })
        let options = explorer.noteOptions.map(\.spelling)

        func outside(_ spelling: String) -> Bool {
            guard ScaleModel.isKnownSpelling(spelling) else { return false }
            return !scaleDisplays.contains(ScaleModel.formatNoteName(spelling))
        }

        let pool: [String]
        switch difficulty {
        case .easy:
            pool = options.filter { spelling in
                guard outside(spelling), !Self.rareSpellings.contains(spelling) else { return false }
                return !scalePitches.contains(ScaleModel.pitchClass(for: spelling))
            }
        case .normal:
            let nearest = siblingOutsiders(
                tonic: entry.tonic,
                kinds: Self.nearestKinds(for: entry.kind),
                scaleDisplays: scaleDisplays
            )
            let siblings = nearest.isEmpty
                ? siblingOutsiders(
                    tonic: entry.tonic,
                    kinds: ScaleKind.allCases.filter { $0 != entry.kind },
                    scaleDisplays: scaleDisplays
                )
                : nearest
            if !siblings.isEmpty {
                pool = siblings
            } else {
                pool = options.filter { spelling in
                    guard outside(spelling) else { return false }
                    let pitch = ScaleModel.pitchClass(for: spelling)
                    guard !scalePitches.contains(pitch) else { return false }
                    return scalePitches.contains { scalePitch in
                        let distance = min(abs(scalePitch - pitch), 12 - abs(scalePitch - pitch))
                        return distance == 1
                    }
                }
            }
        case .hard:
            let enharmonics = options.filter { spelling in
                guard outside(spelling) else { return false }
                return scalePitches.contains(ScaleModel.pitchClass(for: spelling))
            }
            if !enharmonics.isEmpty {
                pool = enharmonics
            } else {
                let altered = sameLetterOutsiders(scaleSpellings: scaleSpellings, outside: outside)
                pool = altered.isEmpty
                    ? siblingOutsiders(
                        tonic: entry.tonic,
                        kinds: ScaleKind.allCases.filter { $0 != entry.kind },
                        scaleDisplays: scaleDisplays
                    )
                    : altered
            }
        }

        return uniqueSpellings(pool).randomElement()
    }

    private func siblingOutsiders(tonic: String, kinds: [ScaleKind], scaleDisplays: Set<String>) -> [String] {
        var result: [String] = []
        var seen = Set<String>()
        for other in kinds {
            let spelled = spellings(tonic: tonic, kind: other)
            guard spelled.count >= 3 else { continue }
            guard spelled.allSatisfy({ !$0.contains("##") && !$0.hasSuffix("bb") }) else { continue }
            for spelling in spelled.dropLast() {
                let display = ScaleModel.formatNoteName(spelling)
                if scaleDisplays.contains(display) { continue }
                if seen.insert(display).inserted {
                    result.append(spelling)
                }
            }
        }
        return result
    }

    private func sameLetterOutsiders(scaleSpellings: [String], outside: (String) -> Bool) -> [String] {
        var result: [String] = []
        for spelling in scaleSpellings {
            guard let letter = spelling.first else { continue }
            for suffix in ["", "#", "b"] {
                let candidate = String(letter) + suffix
                if outside(candidate) {
                    result.append(candidate)
                }
            }
        }
        return result
    }

    private func uniqueSpellings(_ spellings: [String]) -> [String] {
        var result: [String] = []
        var seen = Set<String>()
        for spelling in spellings.shuffled() {
            let display = ScaleModel.formatNoteName(spelling)
            if seen.insert(display).inserted {
                result.append(spelling)
            }
        }
        return result
    }

    private func noteDistractors(
        correctSpelling: String,
        scaleSpellings: [String],
        tonic: String,
        kind: ScaleKind,
        degreeLabel: String
    ) -> [String] {
        let correctDisplay = ScaleModel.formatNoteName(correctSpelling)
        let correctPitch = ScaleModel.pitchClass(for: correctSpelling)
        let tiers: [[String]]
        switch difficulty {
        case .easy:
            tiers = [
                farNoteDisplays(correctSpelling: correctSpelling, scaleSpellings: scaleSpellings, minimumDistance: 3),
                farNoteDisplays(correctSpelling: correctSpelling, scaleSpellings: scaleSpellings, minimumDistance: 2),
                optionDisplays(excluding: correctDisplay),
            ]
        case .normal:
            tiers = [
                siblingDegreeDisplays(tonic: tonic, kind: kind, degreeLabel: degreeLabel, correctDisplay: correctDisplay),
                neighborDisplays(pitchClass: correctPitch, correctDisplay: correctDisplay),
                sameLetterDisplays(correctSpelling: correctSpelling, correctDisplay: correctDisplay),
                optionDisplays(excluding: correctDisplay),
            ]
        case .hard:
            tiers = [
                enharmonicDisplays(pitchClass: correctPitch, correctDisplay: correctDisplay),
                siblingDegreeDisplays(tonic: tonic, kind: kind, degreeLabel: degreeLabel, correctDisplay: correctDisplay),
                neighborDisplays(pitchClass: correctPitch, correctDisplay: correctDisplay),
                sameLetterDisplays(correctSpelling: correctSpelling, correctDisplay: correctDisplay),
                optionDisplays(excluding: correctDisplay),
            ]
        }
        return takeDistractors(tiers, correctDisplay: correctDisplay)
    }

    /// Notes at least `minimumDistance` semitones away, outside the scale, and not an enharmonic
    /// or same-letter accidental of the answer. Easy also skips rare spellings such as E♯.
    private func farNoteDisplays(
        correctSpelling: String,
        scaleSpellings: [String],
        minimumDistance: Int
    ) -> [String] {
        let correctDisplay = ScaleModel.formatNoteName(correctSpelling)
        let correctPitch = ScaleModel.pitchClass(for: correctSpelling)
        let scaleDisplays = Set(scaleSpellings.map(ScaleModel.formatNoteName))
        let correctLetter = correctSpelling.first

        return explorer.noteOptions.compactMap { option in
            if Self.rareSpellings.contains(option.spelling) { return nil }
            if option.displayName == correctDisplay || scaleDisplays.contains(option.displayName) {
                return nil
            }
            if option.spelling.first == correctLetter { return nil }
            let pitch = ScaleModel.pitchClass(for: option.spelling)
            if pitch == correctPitch { return nil }
            let distance = min(abs(pitch - correctPitch), 12 - abs(pitch - correctPitch))
            guard distance >= minimumDistance else { return nil }
            return option.displayName
        }
    }

    private func siblingDegreeDisplays(
        tonic: String,
        kind: ScaleKind,
        degreeLabel: String,
        correctDisplay: String
    ) -> [String] {
        let number = degreeNumber(of: degreeLabel)
        return Self.nearestKinds(for: kind).flatMap { other -> [String] in
            let spelled = spellings(tonic: tonic, kind: other)
            guard spelled.allSatisfy({ !$0.contains("##") && !$0.hasSuffix("bb") }) else { return [] }
            return other.degreeLabels.enumerated().compactMap { index, label in
                guard degreeNumber(of: label) == number, label != degreeLabel else { return nil }
                guard spelled.indices.contains(index) else { return nil }
                let display = ScaleModel.formatNoteName(spelled[index])
                return display == correctDisplay ? nil : display
            }
        }
    }

    private func neighborDisplays(pitchClass: Int, correctDisplay: String) -> [String] {
        let neighbors: Set<Int> = [(pitchClass + 1) % 12, (pitchClass + 11) % 12]
        return explorer.noteOptions.compactMap { option in
            let pitch = ScaleModel.pitchClass(for: option.spelling)
            guard neighbors.contains(pitch), option.displayName != correctDisplay else { return nil }
            return option.displayName
        }
    }

    private func enharmonicDisplays(pitchClass: Int, correctDisplay: String) -> [String] {
        explorer.noteOptions.compactMap { option in
            let pitch = ScaleModel.pitchClass(for: option.spelling)
            guard pitch == pitchClass, option.displayName != correctDisplay else { return nil }
            return option.displayName
        }
    }

    private func sameLetterDisplays(correctSpelling: String, correctDisplay: String) -> [String] {
        guard let letter = correctSpelling.first else { return [] }
        return ["", "#", "b"].compactMap { suffix in
            let candidate = String(letter) + suffix
            guard ScaleModel.isKnownSpelling(candidate) else { return nil }
            let display = ScaleModel.formatNoteName(candidate)
            return display == correctDisplay ? nil : display
        }
    }

    private func optionDisplays(excluding correctDisplay: String) -> [String] {
        explorer.noteOptions.compactMap { option in
            option.displayName == correctDisplay ? nil : option.displayName
        }
    }

    private func takeDistractors(_ tiers: [[String]], correctDisplay: String, count: Int = 3) -> [String] {
        var unique: [String] = []
        var seen: Set<String> = [correctDisplay]
        for tier in tiers {
            for name in tier.shuffled() {
                if seen.insert(name).inserted {
                    unique.append(name)
                }
                if unique.count == count { return unique }
            }
        }
        return unique
    }

    private static let rareSpellings: Set<String> = ["Fb", "E#", "Cb", "B#"]

    private struct CatalogEntry: Equatable {
        let tonic: String
        let kind: ScaleKind
        let degreeSpellings: [String]

        var id: String { "\(tonic)|\(kind.rawValue)" }

        var displayName: String {
            "\(ScaleModel.formatNoteName(tonic)) \(kind.englishTitle)"
        }
    }

    private static let quizTonics: [String] = [
        "C", "G", "D", "A", "E", "B", "F#",
        "Db", "Ab", "Eb", "Bb", "F",
        "C#", "Gb",
    ]

    private static func buildCatalog() -> [CatalogEntry] {
        let probe = ScaleModel()
        var entries: [CatalogEntry] = []
        for tonic in quizTonics {
            for kind in ScaleKind.allCases {
                probe.tonicSpelling = tonic
                probe.kind = kind
                let spellings = probe.degreeSpellings
                guard spellings.count == kind.degreeLabels.count, spellings.count >= 3 else { continue }
                guard spellings.allSatisfy({ !$0.contains("##") && !$0.hasSuffix("bb") }) else {
                    continue
                }
                entries.append(
                    CatalogEntry(tonic: tonic, kind: kind, degreeSpellings: spellings)
                )
            }
        }
        return entries
    }

    private func configureExplorer(_ entry: CatalogEntry) {
        explorer.tonicSpelling = entry.tonic
        explorer.kind = entry.kind
    }

    private func spellings(tonic: String, kind: ScaleKind) -> [String] {
        explorer.tonicSpelling = tonic
        explorer.kind = kind
        return explorer.degreeSpellings
    }

    private func scaleDisplayName(tonic: String, kind: ScaleKind) -> String {
        "\(ScaleModel.formatNoteName(tonic)) \(kind.englishTitle)"
    }

    /// Scales a learner is most likely to confuse with `kind`, nearest first.
    private static func nearestKinds(for kind: ScaleKind) -> [ScaleKind] {
        switch kind {
        case .major:
            [.naturalMinor, .majorPentatonic, .majorBlues]
        case .naturalMinor:
            [.harmonicMinor, .melodicMinor, .minorPentatonic, .minorBlues]
        case .harmonicMinor:
            [.melodicMinor, .naturalMinor]
        case .melodicMinor:
            [.harmonicMinor, .naturalMinor]
        case .majorPentatonic:
            [.majorBlues, .major, .minorPentatonic]
        case .minorPentatonic:
            [.minorBlues, .naturalMinor, .majorPentatonic]
        case .majorBlues:
            [.majorPentatonic, .major, .minorBlues]
        case .minorBlues:
            [.minorPentatonic, .naturalMinor, .majorBlues]
        }
    }

    private func preferredScaleNames(for entry: CatalogEntry) -> [String] {
        let sameTonic = catalog.filter { $0.tonic == entry.tonic && $0.kind != entry.kind }
        var names: [String] = []
        for kind in Self.nearestKinds(for: entry.kind) {
            guard let match = sameTonic.first(where: { $0.kind == kind }) else { continue }
            names.append(match.displayName)
            if names.count == 3 { break }
        }
        if names.count < 3 {
            let rest = sameTonic.map(\.displayName).filter { !names.contains($0) }.shuffled()
            names.append(contentsOf: rest.prefix(3 - names.count))
        }
        return names
    }

    private func formulaChoices(labels: [String], blankIndices: [Int]) -> (correct: String, distractors: [String])? {
        let corrects = blankIndices.map { labels[$0] }
        let correct = formatFormulaChoice(corrects)
        if blankIndices.count == 1 {
            let shown = labels.enumerated().compactMap { index, label in
                blankIndices.contains(index) ? nil : label
            }
            let distractors = singleFormulaDistractors(correct: corrects[0], shown: shown)
            guard distractors.count == 3 else { return nil }
            return (correct, distractors)
        }
        let distractors = pairFormulaDistractors(corrects: corrects)
        guard distractors.count == 3 else { return nil }
        return (correct, distractors)
    }

    /// Easy keeps one near miss and then unrelated degrees. Normal fills with adjacent alterations first.
    /// Degrees already printed in the formula are not offered again.
    private func singleFormulaDistractors(correct: String, shown: [String]) -> [String] {
        let shownSet = Set(shown)
        func usable(_ label: String) -> Bool {
            label != correct && !shownSet.contains(label)
        }
        let siblings = alterationSiblings(of: correct).filter(usable)
        let unrelated = Self.formulaChoicePool.filter { candidate in
            usable(candidate)
                && !siblings.contains(candidate)
                && degreeNumber(of: candidate) != degreeNumber(of: correct)
        }
        let preferred: [String]
        switch difficulty {
        case .easy:
            preferred = Array(siblings.shuffled().prefix(1)) + unrelated.shuffled()
        case .normal, .hard:
            preferred = siblings.shuffled() + unrelated.shuffled()
        }
        return takeDistractors([preferred, Self.formulaChoicePool.filter(usable)], correctDisplay: correct)
    }

    /// Each side of a wrong pair is the correct degree or a nearby alteration, never the correct pair itself.
    private func pairFormulaDistractors(corrects: [String]) -> [String] {
        guard corrects.count == 2 else { return [] }
        let options = corrects.map { correct -> [String] in
            let siblings = alterationSiblings(of: correct).filter { $0 != correct }.shuffled()
            let extras = Self.formulaChoicePool.filter { $0 != correct && !siblings.contains($0) }.shuffled()
            return [correct] + siblings + Array(extras.prefix(2))
        }
        var pairs: [String] = []
        var seen: Set<String> = [formatFormulaChoice(corrects)]
        for left in options[0].shuffled() {
            for right in options[1].shuffled() {
                let text = formatFormulaChoice([left, right])
                if seen.insert(text).inserted {
                    pairs.append(text)
                }
                if pairs.count == 3 { return pairs }
            }
        }
        return pairs
    }

    private func formatFormulaChoice(_ parts: [String]) -> String {
        parts.joined(separator: " / ")
    }

    private func alterationSiblings(of label: String) -> [String] {
        Self.degreeAlterationGroups.first { $0.contains(label) } ?? []
    }

    private func degreeNumber(of label: String) -> Int? {
        Int(label.filter(\.isNumber))
    }

    private static let degreeAlterationGroups: [[String]] = [
        ["♭2", "2", "♯2"],
        ["♭3", "3", "♯3"],
        ["4", "♯4"],
        ["♭5", "5", "♯5"],
        ["♭6", "6"],
        ["♭7", "7", "♯7"],
    ]

    private static let formulaChoicePool = ["2", "♭3", "3", "4", "♯4", "♭5", "5", "♭6", "6", "♭7", "7", "♯7"]

    private func questionID(for question: Question) -> String {
        let ctx = question.explanationContext
        switch question.kind {
        case .completeScale:
            return "complete-\(ctx.tonicSpelling)|\(ctx.kind.rawValue)-\(ctx.blankIndex ?? -1)"
        case .identifyScale:
            return "identify-\(ctx.tonicSpelling)|\(ctx.kind.rawValue)"
        case .completePattern:
            return "pattern-\(ctx.kind.rawValue)-\(ctx.blankIndex ?? -1)"
        case .completeFormula:
            return "formula-\(ctx.kind.rawValue)-\(question.correctAnswer)"
        case .identifyDegree:
            return "degree-\(ctx.tonicSpelling)|\(ctx.kind.rawValue)-\(ctx.blankIndex ?? -1)"
        case .excludedNote:
            return "exclude-\(ctx.tonicSpelling)|\(ctx.kind.rawValue)-\(question.correctAnswer)"
        }
    }

    private var fallbackQuestion: Question {
        let spellings = ["C", "D", "E", "F", "G", "A", "B", "C"]
        let displays = spellings.map(ScaleModel.formatNoteName)
        return Question(
            kind: .completeScale,
            promptTitle: "C Major 스케일을 완성하세요.".l10n,
            scaleLabel: "C Major",
            promptTokens: [
                .note("C"), .note("D"), .blank, .note("F"),
                .note("G"), .note("A"), .note("B"), .note("C"),
            ],
            staffNotes: [],
            staffIntervals: [],
            staffNoteNames: [],
            choices: ["E", "E♭", "F♯", "D♯"].shuffled(),
            correctAnswer: displays[2],
            explanationContext: ExplanationContext(
                tonicSpelling: "C",
                kind: .major,
                degreeSpellings: spellings,
                blankIndex: 2,
                degreeNumber: 3,
                askedNoteDisplay: nil
            )
        )
    }

    private static var placeholderQuestion: Question {
        Question(
            kind: .completeScale,
            promptTitle: "",
            scaleLabel: "",
            promptTokens: [],
            staffNotes: [],
            staffIntervals: [],
            staffNoteNames: [],
            choices: [],
            correctAnswer: "",
            explanationContext: ExplanationContext(
                tonicSpelling: "C",
                kind: .major,
                degreeSpellings: [],
                blankIndex: nil,
                degreeNumber: nil,
                askedNoteDisplay: nil
            )
        )
    }
}
