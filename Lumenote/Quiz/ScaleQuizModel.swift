//

import Foundation

/// Difficulty chosen before a scale quiz session.
enum ScaleQuizDifficulty: String, CaseIterable, Hashable, Identifiable {
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
}

/// Mixed scale quiz: complete notes, identify scale, complete step pattern, identify degree.
@MainActor
@Observable
final class ScaleQuizModel {
    enum QuestionKind: Equatable {
        /// Fill one missing scale degree.
        case completeScale
        /// Given ascending degrees, pick the scale name.
        case identifyScale
        /// Fill one missing whole/half (or aug2) step in the pattern.
        case completePattern
        /// Ask which note is a given scale degree.
        case identifyDegree
        /// Ask which note is not a member of the scale.
        case excludedNote
    }

    enum PromptToken: Equatable {
        case note(String)
        case blank
        case step(String)
        case stepBlank
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
        let askedNoteDisplay: String?
    }

    let difficulty: ScaleQuizDifficulty
    /// Number of questions in this session: 10, 20, 30, 40, or 50.
    let questionLimit: Int
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

    init(difficulty: ScaleQuizDifficulty, questionLimit: Int) {
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
        let degrees = ctx.degreeSpellings.map(ScaleModel.formatNoteName)
        let scaleName = scaleDisplayName(tonic: ctx.tonicSpelling, kind: ctx.kind)

        if answer == question.correctAnswer {
            return Feedback(
                headline: "정답",
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
        case .completePattern:
            return Feedback(
                headline: "\(answer) ✕ → \(question.correctAnswer) ✓",
                detail: ""
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
        for _ in 0..<80 {
            let candidate: Question?
            // Weight complete-scale highest — it mirrors the learning screen most closely.
            switch Int.random(in: 0..<10) {
            case 0..<4:
                candidate = makeCompleteScaleQuestion()
            case 4..<6:
                candidate = makeIdentifyScaleQuestion()
            case 6..<8:
                candidate = makeCompletePatternQuestion()
            default:
                candidate = shouldAskDegreeNote()
                    ? makeIdentifyDegreeQuestion()
                    : makeExcludedNoteQuestion()
            }
            if let question = candidate {
                previousQuestionID = questionID(for: question)
                return question
            }
        }
        return fallbackQuestion
    }

    private func makeCompleteScaleQuestion() -> Question? {
        guard let entry = pickEntry() else { return nil }
        let blankIndex = noteBlankIndex(for: entry.kind)
        let questionID = "complete-\(entry.id)-\(blankIndex)"
        if questionID == previousQuestionID { return nil }

        let displays = entry.degreeSpellings.map(ScaleModel.formatNoteName)
        let correct = displays[blankIndex]
        let distractors = noteDistractors(
            correctSpelling: entry.degreeSpellings[blankIndex],
            scaleSpellings: entry.degreeSpellings,
            tonic: entry.tonic,
            kind: entry.kind,
            degreeIndex: blankIndex
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
            promptTitle: "\(entry.displayName) 스케일을 완성하세요.",
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
                degreeNumber: blankIndex + 1,
                askedNoteDisplay: nil
            )
        )
    }

    private func makeIdentifyScaleQuestion() -> Question? {
        guard let entry = pickEntry() else { return nil }
        let questionID = "identify-\(entry.id)"
        if questionID == previousQuestionID { return nil }

        let sameTonic = catalog.filter { $0.tonic == entry.tonic && $0.kind != entry.kind }
        var distractors = sameTonic.map(\.displayName)

        if distractors.count < 3 {
            let others = catalog
                .filter { $0.displayName != entry.displayName && !distractors.contains($0.displayName) }
                .shuffled()
                .prefix(3 - distractors.count)
                .map(\.displayName)
            distractors.append(contentsOf: others)
        }

        distractors = Array(Set(distractors)).filter { $0 != entry.displayName }.shuffled()
        guard distractors.count >= 3 else { return nil }
        distractors = Array(distractors.prefix(3))

        let displays = entry.degreeSpellings.map(ScaleModel.formatNoteName)
        configureExplorer(entry)
        let staffNotes = explorer.staffNotes
        let staffIntervals = explorer.stepIntervals

        return Question(
            kind: .identifyScale,
            promptTitle: "다음 스케일은 무엇일까요?",
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
        if questionID == previousQuestionID { return nil }

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
            Set(ScaleKind.allCases.flatMap { kind in
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
            promptTitle: "\(kind.englishTitle) 스케일의 음정 패턴을 완성하세요.",
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

    private func makeIdentifyDegreeQuestion() -> Question? {
        guard let entry = pickEntry() else { return nil }
        let degreeIndex = noteBlankIndex(for: entry.kind) // 2도…7도
        let degreeNumber = degreeIndex + 1
        let questionID = "degree-\(entry.id)-\(degreeNumber)"
        if questionID == previousQuestionID { return nil }

        let displays = entry.degreeSpellings.map(ScaleModel.formatNoteName)
        let correct = displays[degreeIndex]
        let distractors = noteDistractors(
            correctSpelling: entry.degreeSpellings[degreeIndex],
            scaleSpellings: entry.degreeSpellings,
            tonic: entry.tonic,
            kind: entry.kind,
            degreeIndex: degreeIndex
        )
        guard distractors.count == 3 else { return nil }

        return Question(
            kind: .identifyDegree,
            promptTitle: "\(entry.displayName) 스케일의 \(degreeNumber)도 음은?",
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
                degreeNumber: degreeNumber,
                askedNoteDisplay: nil
            )
        )
    }

    private func makeExcludedNoteQuestion() -> Question? {
        guard let entry = pickEntry() else { return nil }
        guard let correctSpelling = excludedSpelling(for: entry) else { return nil }
        let questionID = "exclude-\(entry.id)-\(correctSpelling)"
        if questionID == previousQuestionID { return nil }

        let correct = ScaleModel.formatNoteName(correctSpelling)
        var distractors: [String] = []
        var seen: Set<String> = [correct]
        for spelling in entry.degreeSpellings.prefix(7).shuffled() {
            let display = ScaleModel.formatNoteName(spelling)
            if seen.insert(display).inserted {
                distractors.append(display)
            }
            if distractors.count == 3 { break }
        }
        guard distractors.count == 3 else { return nil }

        return Question(
            kind: .excludedNote,
            promptTitle: "\(entry.displayName) 스케일에 포함되지 않는 음은?",
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
        guard let degree = context.degreeNumber, degrees.indices.contains(degree - 1) else {
            return scaleName
        }
        let note = degrees[degree - 1]
        return "\(scaleName) 스케일의 \(degree)도 음은 \(note)입니다."
    }

    private func excludedNoteDetail(scaleName: String) -> String {
        let note = question.correctAnswer
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

    /// Easy keeps Major and Natural Minor common, but still draws the other kinds
    /// so identify-scale can offer four names.
    private func pickEntry() -> CatalogEntry? {
        let pool = catalog.filter { allowedTonics.contains($0.tonic) }
        guard !pool.isEmpty else { return nil }
        switch difficulty {
        case .easy:
            return weightedEntry(
                from: pool,
                weights: [.major: 4, .naturalMinor: 4, .harmonicMinor: 1, .melodicMinor: 1]
            )
        case .normal, .hard:
            return pool.randomElement()
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
        switch difficulty {
        case .easy:
            [.major, .naturalMinor].randomElement()
        case .normal, .hard:
            ScaleKind.allCases.randomElement()
        }
    }

    /// Degree index in 1...6 (2도–7도). Normal prefers the notes that distinguish the kind.
    private func noteBlankIndex(for kind: ScaleKind) -> Int {
        let full = Array(1...6)
        guard difficulty == .normal else { return full.randomElement() ?? 1 }
        let characteristic = characteristicDegreeIndices(for: kind).filter { full.contains($0) }
        guard !characteristic.isEmpty, Int.random(in: 0..<10) < 7 else {
            return full.randomElement() ?? 1
        }
        return characteristic.randomElement() ?? full[0]
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

    /// 3·6·7 of natural minor, the raised 7th of harmonic minor, and 6·7 of melodic minor.
    private func characteristicDegreeIndices(for kind: ScaleKind) -> [Int] {
        switch kind {
        case .major:
            []
        case .naturalMinor:
            [2, 5, 6]
        case .harmonicMinor:
            [6]
        case .melodicMinor:
            [5, 6]
        }
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
        }
    }

    /// Easy keeps degree-note questions more often. The remaining share asks which note is outside the scale.
    private func shouldAskDegreeNote() -> Bool {
        switch difficulty {
        case .easy:
            Int.random(in: 0..<10) < 7
        case .normal, .hard:
            Bool.random()
        }
    }

    /// A note spelling that is not one of the scale's degree names.
    /// Easy uses a different pitch. Normal prefers a sibling scale's tone. Hard prefers an enharmonic spelling.
    private func excludedSpelling(for entry: CatalogEntry) -> String? {
        let scaleSpellings = Array(entry.degreeSpellings.prefix(7))
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
            let siblings = siblingOutsiders(tonic: entry.tonic, kind: entry.kind, scaleDisplays: scaleDisplays)
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
                    ? siblingOutsiders(tonic: entry.tonic, kind: entry.kind, scaleDisplays: scaleDisplays)
                    : altered
            }
        }

        return uniqueSpellings(pool).randomElement()
    }

    private func siblingOutsiders(tonic: String, kind: ScaleKind, scaleDisplays: Set<String>) -> [String] {
        var result: [String] = []
        for other in ScaleKind.allCases where other != kind {
            let spelled = spellings(tonic: tonic, kind: other)
            guard spelled.count == 8 else { continue }
            guard spelled.allSatisfy({ !$0.contains("##") && !$0.hasSuffix("bb") }) else { continue }
            for spelling in spelled.prefix(7) {
                let display = ScaleModel.formatNoteName(spelling)
                if !scaleDisplays.contains(display) {
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
        degreeIndex: Int
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
                siblingDegreeDisplays(tonic: tonic, kind: kind, degreeIndex: degreeIndex, correctDisplay: correctDisplay),
                neighborDisplays(pitchClass: correctPitch, correctDisplay: correctDisplay),
                sameLetterDisplays(correctSpelling: correctSpelling, correctDisplay: correctDisplay),
                optionDisplays(excluding: correctDisplay),
            ]
        case .hard:
            tiers = [
                enharmonicDisplays(pitchClass: correctPitch, correctDisplay: correctDisplay),
                siblingDegreeDisplays(tonic: tonic, kind: kind, degreeIndex: degreeIndex, correctDisplay: correctDisplay),
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
        degreeIndex: Int,
        correctDisplay: String
    ) -> [String] {
        ScaleKind.allCases.compactMap { other in
            guard other != kind else { return nil }
            let spellings = spellings(tonic: tonic, kind: other)
            guard spellings.count == 8, spellings.indices.contains(degreeIndex) else { return nil }
            guard spellings.allSatisfy({ !$0.contains("##") && !$0.hasSuffix("bb") }) else { return nil }
            let display = ScaleModel.formatNoteName(spellings[degreeIndex])
            return display == correctDisplay ? nil : display
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
                guard spellings.count == 8 else { continue }
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

    private func questionID(for question: Question) -> String {
        let ctx = question.explanationContext
        switch question.kind {
        case .completeScale:
            return "complete-\(ctx.tonicSpelling)|\(ctx.kind.rawValue)-\(ctx.blankIndex ?? -1)"
        case .identifyScale:
            return "identify-\(ctx.tonicSpelling)|\(ctx.kind.rawValue)"
        case .completePattern:
            return "pattern-\(ctx.kind.rawValue)-\(ctx.blankIndex ?? -1)"
        case .identifyDegree:
            return "degree-\(ctx.tonicSpelling)|\(ctx.kind.rawValue)-\(ctx.degreeNumber ?? 0)"
        case .excludedNote:
            return "exclude-\(ctx.tonicSpelling)|\(ctx.kind.rawValue)-\(question.correctAnswer)"
        }
    }

    private var fallbackQuestion: Question {
        let spellings = ["C", "D", "E", "F", "G", "A", "B", "C"]
        let displays = spellings.map(ScaleModel.formatNoteName)
        return Question(
            kind: .completeScale,
            promptTitle: "C Major 스케일을 완성하세요.",
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
