//

import Foundation

/// Difficulty chosen before a chord quiz session.
enum ChordQuizDifficulty: String, CaseIterable, Hashable, Identifiable {
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

/// Mixed chord quiz: complete tones, identify chord, complete formula, identify degree.
@MainActor
@Observable
final class ChordQuizModel {
    enum QuestionKind: Equatable {
        /// Fill one missing chord tone.
        case completeChord
        /// Given a root-position staff, pick the chord symbol.
        case identifyChord
        /// Fill one missing degree in the chord formula.
        case completeFormula
        /// Ask for the note at a given chord degree.
        case identifyTone
    }

    enum PromptToken: Equatable {
        case note(String)
        case blank
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
        let promptTokens: [PromptToken]
        let staffNotes: [IntervalStaffNote]
        let staffNoteNames: [String]
        let choices: [String]
        let correctAnswer: String
        let explanationContext: ExplanationContext
    }

    struct ExplanationContext: Equatable {
        let rootSpelling: String
        let kind: ChordKind
        let toneSpellings: [String]
        let blankIndex: Int?
        let degreeNumber: Int?
    }

    let difficulty: ChordQuizDifficulty
    /// Number of questions in this session: 10, 20, 30, 40, or 50.
    let questionLimit: Int
    private let explorer = ChordModel()
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

    /// Chord or kind name emphasized in the prompt.
    var promptHighlights: [String] {
        let ctx = question.explanationContext
        switch question.kind {
        case .completeChord:
            return [chordLabel(root: ctx.rootSpelling, kind: ctx.kind)]
        case .completeFormula:
            return [kindLabel(ctx.kind)]
        case .identifyTone:
            let name = chordLabel(root: ctx.rootSpelling, kind: ctx.kind)
            guard let degree = ctx.degreeNumber else { return [name] }
            return [name, "\(degree)도"]
        case .identifyChord:
            return []
        }
    }

    /// Easy compares the major/minor pair, so two choices are enough.
    /// Normal and Hard stay at four, except when the in-scope kind pool is smaller.
    private var noteChoiceCount: Int {
        difficulty == .easy ? 2 : 4
    }

    init(difficulty: ChordQuizDifficulty, questionLimit: Int) {
        self.difficulty = difficulty
        self.questionLimit = Self.normalizedQuestionCount(questionLimit)
        catalog = Self.buildCatalog(for: difficulty)
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
        let tones = ctx.toneSpellings.map(ScaleModel.formatNoteName)
        let chordName = chordLabel(root: ctx.rootSpelling, kind: ctx.kind)
        let formula = ctx.kind.formulaText
        let symbol = chordSymbol(root: ctx.rootSpelling, kind: ctx.kind)

        if answer == question.correctAnswer {
            return Feedback(
                headline: "정답",
                detail: correctDetail(
                    for: question.kind,
                    chordName: chordName,
                    tones: tones,
                    formula: formula,
                    context: ctx
                )
            )
        }

        switch question.kind {
        case .completeChord:
            return completeChordWrongFeedback(answer: answer, tones: tones, context: ctx)
        case .identifyChord:
            return Feedback(
                headline: "\(answer) ✕ → \(question.correctAnswer) ✓",
                detail: identifyChordDetail(
                    tones: tones,
                    symbol: symbol,
                    kind: ctx.kind,
                    formula: formula
                )
            )
        case .completeFormula:
            return Feedback(
                headline: "\(answer) ✕ → \(question.correctAnswer) ✓",
                detail: completeFormulaDetail(kind: ctx.kind, formula: formula)
            )
        case .identifyTone:
            return identifyToneWrongFeedback(
                answer: answer,
                chordName: chordName,
                tones: tones,
                context: ctx
            )
        }
    }

    // MARK: - Generation

    private func makeQuestion() -> Question {
        for _ in 0..<80 {
            let candidate: Question?
            switch weightedKind() {
            case .completeChord:
                candidate = makeCompleteChordQuestion()
            case .identifyChord:
                candidate = makeIdentifyChordQuestion()
            case .completeFormula:
                candidate = makeCompleteFormulaQuestion()
            case .identifyTone:
                candidate = makeIdentifyToneQuestion()
            }
            if let question = candidate {
                previousQuestionID = questionID(for: question)
                return question
            }
        }
        return fallbackQuestion
    }

    /// Easy drills tones and formulas. Hard shifts toward reading and calculating.
    private func weightedKind() -> QuestionKind {
        let weights: [(QuestionKind, Int)]
        switch difficulty {
        case .easy:
            weights = [
                (.completeChord, 50),
                (.identifyChord, 15),
                (.completeFormula, 25),
                (.identifyTone, 10),
            ]
        case .normal:
            weights = [
                (.completeChord, 40),
                (.identifyChord, 25),
                (.completeFormula, 20),
                (.identifyTone, 15),
            ]
        case .hard:
            weights = [
                (.completeChord, 30),
                (.identifyChord, 30),
                (.completeFormula, 15),
                (.identifyTone, 25),
            ]
        }

        let total = weights.reduce(0) { $0 + $1.1 }
        var roll = Int.random(in: 0..<total)
        for (kind, weight) in weights {
            if roll < weight { return kind }
            roll -= weight
        }
        return .completeChord
    }

    private func makeCompleteChordQuestion() -> Question? {
        guard let entry = pickEntry() else { return nil }
        let blankIndex = Int.random(in: 1..<entry.toneSpellings.count)
        let questionID = "complete-\(entry.id)-\(blankIndex)"
        if questionID == previousQuestionID { return nil }

        let displays = entry.toneSpellings.map(ScaleModel.formatNoteName)
        let correct = displays[blankIndex]
        let distractors = noteDistractors(
            correctSpelling: entry.toneSpellings[blankIndex],
            chordSpellings: entry.toneSpellings,
            root: entry.root,
            kind: entry.kind,
            toneIndex: blankIndex
        )
        guard distractors.count == noteChoiceCount - 1 else { return nil }

        var tokens: [PromptToken] = []
        for (index, name) in displays.enumerated() {
            tokens.append(index == blankIndex ? .blank : .note(name))
        }

        let staff = capturedStaff(root: entry.root, kind: entry.kind)

        return Question(
            kind: .completeChord,
            promptTitle: "\(entry.displayName) 코드를 완성하세요.",
            promptTokens: tokens,
            staffNotes: staff.notes,
            staffNoteNames: staff.names,
            choices: (distractors + [correct]).shuffled(),
            correctAnswer: correct,
            explanationContext: ExplanationContext(
                rootSpelling: entry.root,
                kind: entry.kind,
                toneSpellings: entry.toneSpellings,
                blankIndex: blankIndex,
                degreeNumber: degreeNumber(at: blankIndex)
            )
        )
    }

    private func makeIdentifyChordQuestion() -> Question? {
        guard let entry = pickEntry() else { return nil }
        let questionID = "identify-\(entry.id)"
        if questionID == previousQuestionID { return nil }

        let distractorKinds = kindDistractors(for: entry.kind)
        let needed = identifyChoiceCount(for: entry.kind) - 1
        guard distractorKinds.count == needed else { return nil }

        let correct = chordSymbol(root: entry.root, kind: entry.kind)
        let distractors = distractorKinds.map { chordSymbol(root: entry.root, kind: $0) }
        let unique = Set(distractors + [correct])
        guard unique.count == needed + 1 else { return nil }

        configureExplorer(entry)

        return Question(
            kind: .identifyChord,
            promptTitle: "다음 코드는 무엇일까요?",
            promptTokens: [],
            staffNotes: explorer.staffNotes,
            staffNoteNames: explorer.toneDisplayNames,
            choices: (distractors + [correct]).shuffled(),
            correctAnswer: correct,
            explanationContext: ExplanationContext(
                rootSpelling: entry.root,
                kind: entry.kind,
                toneSpellings: entry.toneSpellings,
                blankIndex: nil,
                degreeNumber: nil
            )
        )
    }

    private func makeCompleteFormulaQuestion() -> Question? {
        let kinds = Self.kinds(for: difficulty)
        guard let kind = kinds.randomElement() else { return nil }
        let blankIndex = Int.random(in: 1..<kind.tones.count)
        let questionID = "formula-\(kind.rawValue)-\(blankIndex)"
        if questionID == previousQuestionID { return nil }

        let labels = kind.tones.map(\.degreeLabel)
        let correct = labels[blankIndex]
        let shown = labels.enumerated().compactMap { index, label in
            index == blankIndex ? nil : label
        }
        let distractors = formulaDistractors(correct: correct, shown: shown)
        guard distractors.count == noteChoiceCount - 1 else { return nil }

        var tokens: [PromptToken] = []
        for (index, label) in labels.enumerated() {
            tokens.append(index == blankIndex ? .degreeBlank : .degree(label))
        }

        return Question(
            kind: .completeFormula,
            promptTitle: "\(kindLabel(kind)) 코드의 도수 공식을 완성하세요.",
            promptTokens: tokens,
            staffNotes: [],
            staffNoteNames: [],
            choices: (distractors + [correct]).shuffled(),
            correctAnswer: correct,
            explanationContext: ExplanationContext(
                rootSpelling: "C",
                kind: kind,
                toneSpellings: spellings(root: "C", kind: kind),
                blankIndex: blankIndex,
                degreeNumber: degreeNumber(at: blankIndex)
            )
        )
    }

    private func makeIdentifyToneQuestion() -> Question? {
        guard let entry = pickEntry() else { return nil }
        let toneIndex = pickToneIndex(for: entry.kind)
        let degree = degreeNumber(at: toneIndex)
        let questionID = "tone-\(entry.id)-\(degree)"
        if questionID == previousQuestionID { return nil }

        let noteDisplay = ScaleModel.formatNoteName(entry.toneSpellings[toneIndex])
        let distractors = noteDistractors(
            correctSpelling: entry.toneSpellings[toneIndex],
            chordSpellings: entry.toneSpellings,
            root: entry.root,
            kind: entry.kind,
            toneIndex: toneIndex
        )
        guard distractors.count == noteChoiceCount - 1 else { return nil }

        let staff = capturedStaff(root: entry.root, kind: entry.kind)

        return Question(
            kind: .identifyTone,
            promptTitle: "\(entry.displayName) 코드의 \(degree)도 음은?",
            promptTokens: [],
            staffNotes: staff.notes,
            staffNoteNames: staff.names,
            choices: (distractors + [noteDisplay]).shuffled(),
            correctAnswer: noteDisplay,
            explanationContext: ExplanationContext(
                rootSpelling: entry.root,
                kind: entry.kind,
                toneSpellings: entry.toneSpellings,
                blankIndex: toneIndex,
                degreeNumber: degree
            )
        )
    }

    // MARK: - Feedback helpers

    private func correctDetail(
        for kind: QuestionKind,
        chordName: String,
        tones: [String],
        formula: String,
        context: ExplanationContext
    ) -> String {
        switch kind {
        case .completeChord:
            if let degree = context.degreeNumber {
                let note = tones[degreeIndex(for: degree)]
                return completeChordDetail(chordName: chordName, degree: degree, note: note)
            }
            return chordName
        case .identifyChord:
            return identifyChordDetail(
                tones: tones,
                symbol: chordSymbol(root: context.rootSpelling, kind: context.kind),
                kind: context.kind,
                formula: formula
            )
        case .completeFormula:
            return completeFormulaDetail(kind: context.kind, formula: formula)
        case .identifyTone:
            if let degree = context.degreeNumber {
                let note = tones[degreeIndex(for: degree)]
                return identifyToneDetail(chordName: chordName, degree: degree, note: note)
            }
            return chordName
        }
    }

    private func completeChordWrongFeedback(
        answer: String,
        tones: [String],
        context: ExplanationContext
    ) -> Feedback {
        guard let blankIndex = context.blankIndex else {
            return Feedback(
                headline: "\(answer) ✕ → \(question.correctAnswer) ✓",
                detail: ""
            )
        }
        let correct = tones[blankIndex]
        let degree = degreeNumber(at: blankIndex)
        let chordName = chordLabel(root: context.rootSpelling, kind: context.kind)
        return Feedback(
            headline: "\(answer) ✕ → \(correct) ✓",
            detail: completeChordDetail(chordName: chordName, degree: degree, note: correct)
        )
    }

    private func identifyToneWrongFeedback(
        answer: String,
        chordName: String,
        tones: [String],
        context: ExplanationContext
    ) -> Feedback {
        if let degree = context.degreeNumber {
            let note = tones[degreeIndex(for: degree)]
            return Feedback(
                headline: "\(answer) ✕ → \(note) ✓",
                detail: identifyToneDetail(chordName: chordName, degree: degree, note: note)
            )
        }
        return Feedback(headline: "\(answer) ✕ → \(question.correctAnswer) ✓", detail: "")
    }

    private func identifyChordDetail(
        tones: [String],
        symbol: String,
        kind: ChordKind,
        formula: String
    ) -> String {
        let names = tones.joined(separator: " · ")
        let formulaLine = completeFormulaDetail(kind: kind, formula: formula)
        return "구성음 \(names)는 \(symbol) 코드 입니다.\n\(formulaLine)"
    }

    private func completeChordDetail(chordName: String, degree: Int, note: String) -> String {
        "\(chordName) 코드에서 \(degree)도 음은 \(note)입니다."
    }

    private func identifyToneDetail(chordName: String, degree: Int, note: String) -> String {
        "\(chordName) 코드의 \(degree)도 음은 \(note)입니다."
    }

    private func completeFormulaDetail(kind: ChordKind, formula: String) -> String {
        "\(kindLabel(kind)) 코드의 도수 공식 : \(formula)"
    }

    // MARK: - Distractors & catalog

    /// Easy uses the other triad quality when it changes the tone, otherwise one distant natural.
    /// Hard prefers an enharmonic spelling of the answer.
    private func noteDistractors(
        correctSpelling: String,
        chordSpellings: [String],
        root: String,
        kind: ChordKind,
        toneIndex: Int
    ) -> [String] {
        let correctDisplay = ScaleModel.formatNoteName(correctSpelling)
        let correctPitch = ScaleModel.pitchClass(for: correctSpelling)
        let forbidden = Set(chordSpellings.map(ScaleModel.formatNoteName))
        let allowRare = difficulty == .hard
        let tiers: [[String]]
        switch difficulty {
        case .easy:
            tiers = [
                siblingToneDisplays(
                    root: root,
                    kind: kind,
                    toneIndex: toneIndex,
                    correctDisplay: correctDisplay
                ),
                clearNoteDisplays(
                    correctSpelling: correctSpelling,
                    correctPitch: correctPitch,
                    forbidden: forbidden
                ),
            ]
        case .normal:
            tiers = [
                sameLetterDisplays(
                    correctSpelling: correctSpelling,
                    correctDisplay: correctDisplay,
                    allowRare: allowRare
                ),
                neighborDisplays(
                    pitchClass: correctPitch,
                    correctDisplay: correctDisplay,
                    allowRare: allowRare
                ),
                optionDisplays(excluding: correctDisplay, allowRare: allowRare),
            ]
        case .hard:
            tiers = [
                enharmonicDisplays(pitchClass: correctPitch, correctDisplay: correctDisplay),
                sameLetterDisplays(
                    correctSpelling: correctSpelling,
                    correctDisplay: correctDisplay,
                    allowRare: allowRare
                ),
                neighborDisplays(
                    pitchClass: correctPitch,
                    correctDisplay: correctDisplay,
                    allowRare: allowRare
                ),
                optionDisplays(excluding: correctDisplay, allowRare: allowRare),
            ]
        }
        return takeDisplays(tiers, excluding: forbidden, count: noteChoiceCount - 1)
    }

    /// Major and minor thirds differ by one accidental. Fifths are often the same pitch.
    private func siblingToneDisplays(
        root: String,
        kind: ChordKind,
        toneIndex: Int,
        correctDisplay: String
    ) -> [String] {
        let other: ChordKind?
        switch kind {
        case .majorTriad: other = .minorTriad
        case .minorTriad: other = .majorTriad
        default: other = nil
        }
        guard let other else { return [] }
        let spelled = spellings(root: root, kind: other)
        guard spelled.indices.contains(toneIndex) else { return [] }
        let spelling = spelled[toneIndex]
        guard !Self.rareSpellings.contains(spelling) else { return [] }
        let display = ScaleModel.formatNoteName(spelling)
        return display == correctDisplay ? [] : [display]
    }

    private func clearNoteDisplays(
        correctSpelling: String,
        correctPitch: Int,
        forbidden: Set<String>
    ) -> [String] {
        let correctLetter = correctSpelling.first
        return ["C", "D", "E", "F", "G", "A", "B"].compactMap { spelling in
            let display = ScaleModel.formatNoteName(spelling)
            if forbidden.contains(display) || spelling.first == correctLetter { return nil }
            let pitch = ScaleModel.pitchClass(for: spelling)
            if pitch == correctPitch { return nil }
            let distance = min(abs(pitch - correctPitch), 12 - abs(pitch - correctPitch))
            guard distance >= 2 else { return nil }
            return display
        }
    }

    private func enharmonicDisplays(pitchClass: Int, correctDisplay: String) -> [String] {
        explorer.noteOptions.compactMap { option in
            let pitch = ScaleModel.pitchClass(for: option.spelling)
            guard pitch == pitchClass, option.displayName != correctDisplay else { return nil }
            return option.displayName
        }
    }

    private func neighborDisplays(pitchClass: Int, correctDisplay: String, allowRare: Bool) -> [String] {
        let neighbors: Set<Int> = [(pitchClass + 1) % 12, (pitchClass + 11) % 12]
        return explorer.noteOptions.compactMap { option in
            if !allowRare, Self.rareSpellings.contains(option.spelling) { return nil }
            let pitch = ScaleModel.pitchClass(for: option.spelling)
            guard neighbors.contains(pitch), option.displayName != correctDisplay else { return nil }
            return option.displayName
        }
    }

    private func sameLetterDisplays(
        correctSpelling: String,
        correctDisplay: String,
        allowRare: Bool
    ) -> [String] {
        guard let letter = correctSpelling.first else { return [] }
        return ["", "#", "b"].compactMap { suffix in
            let candidate = String(letter) + suffix
            guard ScaleModel.isKnownSpelling(candidate) else { return nil }
            if !allowRare, Self.rareSpellings.contains(candidate) { return nil }
            let display = ScaleModel.formatNoteName(candidate)
            return display == correctDisplay ? nil : display
        }
    }

    private func optionDisplays(excluding correctDisplay: String, allowRare: Bool) -> [String] {
        explorer.noteOptions.compactMap { option in
            if !allowRare, Self.rareSpellings.contains(option.spelling) { return nil }
            return option.displayName == correctDisplay ? nil : option.displayName
        }
    }

    private func takeDisplays(_ tiers: [[String]], excluding: Set<String>, count: Int) -> [String] {
        var unique: [String] = []
        var seen = excluding
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

    private func formulaDistractors(correct: String, shown: [String]) -> [String] {
        let needed = noteChoiceCount - 1
        if difficulty == .easy {
            if correct == "3" || correct == "♭3" {
                return [correct == "3" ? "♭3" : "3"]
            }
            let pool = ["6", "7"].filter { $0 != correct && !shown.contains($0) }
            if let pick = pool.randomElement() ?? ["6", "7"].first(where: { $0 != correct }) {
                return [pick]
            }
            return []
        }

        let groups = [
            ["3", "♭3"],
            ["5", "♭5", "♯5"],
            ["7", "♭7", "𝄫7"],
        ]
        var preferred: [String] = []
        if let group = groups.first(where: { $0.contains(correct) }) {
            preferred = group.filter { $0 != correct }.shuffled()
        }
        let extras = ["1", "3", "♭3", "5", "♭5", "♯5", "6", "7", "♭7", "𝄫7"]
        let rest = extras.shuffled().filter { $0 != correct && !preferred.contains($0) }
        let ordered = preferred + rest
        let hidden = ordered.filter { !shown.contains($0) }
        let source = hidden.count >= needed ? hidden : ordered
        return Array(source.prefix(needed))
    }

    /// Same root, same category. Easy is only the other of major and minor.
    /// Normal sevenths have three kinds in scope, so that comparison uses three choices.
    private func kindDistractors(for kind: ChordKind) -> [ChordKind] {
        let allowed = Self.kinds(for: difficulty)
        let needed = identifyChoiceCount(for: kind) - 1
        let preferred = Self.preferredDistractors(for: kind).filter { allowed.contains($0) }
        let sameCategory = allowed.filter { $0.category == kind.category && $0 != kind }
        var result: [ChordKind] = []
        var seen = Set<ChordKind>()
        for candidate in preferred + sameCategory.shuffled() {
            if candidate != kind, seen.insert(candidate).inserted {
                result.append(candidate)
            }
            if result.count == needed { break }
        }
        return result
    }

    private func identifyChoiceCount(for kind: ChordKind) -> Int {
        let pool = Self.kinds(for: difficulty).filter { $0.category == kind.category }
        let cap = difficulty == .easy ? 2 : 4
        return min(cap, pool.count)
    }

    private static func preferredDistractors(for kind: ChordKind) -> [ChordKind] {
        switch kind {
        case .majorTriad:
            [.minorTriad, .augmentedTriad, .diminishedTriad]
        case .minorTriad:
            [.majorTriad, .diminishedTriad, .augmentedTriad]
        case .augmentedTriad:
            [.majorTriad, .minorTriad, .diminishedTriad]
        case .diminishedTriad:
            [.minorTriad, .majorTriad, .augmentedTriad]
        case .major7:
            [.dominant7, .minorMajor7, .minor7]
        case .dominant7:
            [.major7, .minor7, .minorMajor7]
        case .minorMajor7:
            [.minor7, .major7, .dominant7]
        case .minor7:
            [.minorMajor7, .halfDiminished7, .dominant7]
        case .halfDiminished7:
            [.diminished7, .minor7, .minorMajor7]
        case .diminished7:
            [.halfDiminished7, .minor7, .dominant7]
        }
    }

    private func pickToneIndex(for kind: ChordKind) -> Int {
        if kind.tones.count == 4 {
            switch difficulty {
            case .easy, .normal:
                let roll = Int.random(in: 0..<10)
                if roll < 5 { return 3 }
                if roll < 8 { return 1 }
                return 2
            case .hard:
                return [1, 2, 3].randomElement() ?? 1
            }
        }
        return Bool.random() ? 1 : 2
    }

    private func degreeNumber(at toneIndex: Int) -> Int {
        switch toneIndex {
        case 1: return 3
        case 2: return 5
        case 3: return 7
        default: return 1
        }
    }

    private func degreeIndex(for degreeNumber: Int) -> Int {
        switch degreeNumber {
        case 3: return 1
        case 5: return 2
        case 7: return 3
        default: return 0
        }
    }

    private struct CatalogEntry: Equatable {
        let root: String
        let kind: ChordKind
        let toneSpellings: [String]

        var id: String { "\(root)|\(kind.rawValue)" }

        var displayName: String {
            ChordQuizModel.chordLabel(root: root, kind: kind)
        }
    }

    /// Spellings such as B♯ stay available on Hard, where enharmonic choices are intentional.
    private static let rareSpellings: Set<String> = ["Fb", "E#", "Cb", "B#"]

    private static let quizRoots: [String] = [
        "C", "G", "D", "A", "E", "B", "F#",
        "Db", "Ab", "Eb", "Bb", "F",
        "C#", "Gb",
    ]

    private static func roots(for difficulty: ChordQuizDifficulty) -> [String] {
        switch difficulty {
        case .easy:
            ["C", "G", "F"]
        case .normal:
            ["C", "D", "E", "F", "G", "A", "B"]
        case .hard:
            quizRoots
        }
    }

    private static func kinds(for difficulty: ChordQuizDifficulty) -> [ChordKind] {
        switch difficulty {
        case .easy:
            [.majorTriad, .minorTriad]
        case .normal:
            [
                .majorTriad, .minorTriad, .augmentedTriad, .diminishedTriad,
                .major7, .dominant7, .minor7,
            ]
        case .hard:
            ChordKind.allCases
        }
    }

    private static func buildCatalog(for difficulty: ChordQuizDifficulty) -> [CatalogEntry] {
        let probe = ChordModel()
        var entries: [CatalogEntry] = []
        for root in roots(for: difficulty) {
            for kind in kinds(for: difficulty) {
                probe.rootSpelling = root
                probe.kind = kind
                let spellings = probe.toneSpellings
                guard spellings.count == kind.tones.count else { continue }
                guard spellings.allSatisfy({ !$0.contains("##") && !$0.hasSuffix("bb") }) else {
                    continue
                }
                entries.append(
                    CatalogEntry(root: root, kind: kind, toneSpellings: spellings)
                )
            }
        }
        return entries
    }

    /// Roots are drawn evenly. C♯ and D♭ stay separate spellings on Hard.
    private func pickEntry() -> CatalogEntry? {
        let roots = Set(catalog.map(\.root))
        guard let root = roots.randomElement() else { return nil }
        return catalog.filter { $0.root == root }.randomElement()
    }

    private func configureExplorer(_ entry: CatalogEntry) {
        explorer.rootSpelling = entry.root
        explorer.kind = entry.kind
    }

    private func capturedStaff(root: String, kind: ChordKind) -> (notes: [IntervalStaffNote], names: [String]) {
        explorer.rootSpelling = root
        explorer.kind = kind
        return (explorer.staffNotes, explorer.toneDisplayNames)
    }

    private func spellings(root: String, kind: ChordKind) -> [String] {
        explorer.rootSpelling = root
        explorer.kind = kind
        return explorer.toneSpellings
    }

    private func chordLabel(root: String, kind: ChordKind) -> String {
        Self.chordLabel(root: root, kind: kind)
    }

    private static func chordLabel(root: String, kind: ChordKind) -> String {
        let rootName = ScaleModel.formatNoteName(root)
        if kind == .dominant7 {
            return "\(rootName)7"
        }
        return "\(rootName) \(kind.englishTitle)"
    }

    private func kindLabel(_ kind: ChordKind) -> String {
        kind == .dominant7 ? "Dominant 7" : kind.englishTitle
    }

    private func chordSymbol(root: String, kind: ChordKind) -> String {
        let rootName = ScaleModel.formatNoteName(root)
        return kind.notations(rootDisplayName: rootName).first ?? chordLabel(root: root, kind: kind)
    }

    private func questionID(for question: Question) -> String {
        let ctx = question.explanationContext
        switch question.kind {
        case .completeChord:
            return "complete-\(ctx.rootSpelling)|\(ctx.kind.rawValue)-\(ctx.blankIndex ?? -1)"
        case .identifyChord:
            return "identify-\(ctx.rootSpelling)|\(ctx.kind.rawValue)"
        case .completeFormula:
            return "formula-\(ctx.kind.rawValue)-\(ctx.blankIndex ?? -1)"
        case .identifyTone:
            return "tone-\(ctx.rootSpelling)|\(ctx.kind.rawValue)-\(ctx.degreeNumber ?? 0)"
        }
    }

    private var fallbackQuestion: Question {
        switch difficulty {
        case .easy:
            let staff = capturedStaff(root: "C", kind: .majorTriad)
            return Question(
                kind: .completeChord,
                promptTitle: "C Major Triad 코드를 완성하세요.",
                promptTokens: [.note("C"), .blank, .note("G")],
                staffNotes: staff.notes,
                staffNoteNames: staff.names,
                choices: ["E", "E♭"].shuffled(),
                correctAnswer: "E",
                explanationContext: ExplanationContext(
                    rootSpelling: "C",
                    kind: .majorTriad,
                    toneSpellings: ["C", "E", "G"],
                    blankIndex: 1,
                    degreeNumber: 3
                )
            )
        case .normal:
            let staff = capturedStaff(root: "C", kind: .dominant7)
            return Question(
                kind: .completeChord,
                promptTitle: "C7 코드를 완성하세요.",
                promptTokens: [.note("C"), .note("E"), .note("G"), .blank],
                staffNotes: staff.notes,
                staffNoteNames: staff.names,
                choices: ["B♭", "B", "A", "D"].shuffled(),
                correctAnswer: "B♭",
                explanationContext: ExplanationContext(
                    rootSpelling: "C",
                    kind: .dominant7,
                    toneSpellings: ["C", "E", "G", "Bb"],
                    blankIndex: 3,
                    degreeNumber: 7
                )
            )
        case .hard:
            let spellings = ["C", "E", "G", "B"]
            let displays = spellings.map(ScaleModel.formatNoteName)
            let staff = capturedStaff(root: "C", kind: .major7)
            return Question(
                kind: .completeChord,
                promptTitle: "C Major 7 코드를 완성하세요.",
                promptTokens: [.note("C"), .note("E"), .note("G"), .blank],
                staffNotes: staff.notes,
                staffNoteNames: staff.names,
                choices: ["B", "B♭", "A", "D"].shuffled(),
                correctAnswer: displays[3],
                explanationContext: ExplanationContext(
                    rootSpelling: "C",
                    kind: .major7,
                    toneSpellings: spellings,
                    blankIndex: 3,
                    degreeNumber: 7
                )
            )
        }
    }

    private static var placeholderQuestion: Question {
        Question(
            kind: .completeChord,
            promptTitle: "",
            promptTokens: [],
            staffNotes: [],
            staffNoteNames: [],
            choices: [],
            correctAnswer: "",
            explanationContext: ExplanationContext(
                rootSpelling: "C",
                kind: .majorTriad,
                toneSpellings: [],
                blankIndex: nil,
                degreeNumber: nil
            )
        )
    }
}
