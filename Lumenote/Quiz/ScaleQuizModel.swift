//

import Foundation

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
        /// Ask for a scale degree's note, or a note's degree number.
        case identifyDegree
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

    private let explorer = ScaleModel()
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
            return completeScaleWrongFeedback(answer: answer, degrees: degrees, context: ctx)
        case .identifyScale:
            return Feedback(
                headline: "\(answer) ✕ → \(question.correctAnswer) ✓",
                detail: "구성음 \(degrees.joined(separator: " → "))는 \(question.correctAnswer)입니다."
            )
        case .completePattern:
            return Feedback(
                headline: "\(answer) ✕ → \(question.correctAnswer) ✓",
                detail: "\(ctx.kind.englishTitle) Scale의 음정 패턴은 \(patternSummary(for: ctx.kind))입니다."
            )
        case .identifyDegree:
            return degreeWrongFeedback(answer: answer, scaleName: scaleName, degrees: degrees, context: ctx)
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
                candidate = makeIdentifyDegreeQuestion()
            }
            if let question = candidate {
                previousQuestionID = questionID(for: question)
                return question
            }
        }
        return fallbackQuestion
    }

    private func makeCompleteScaleQuestion() -> Question? {
        guard let entry = catalog.randomElement() else { return nil }
        let blankIndex = Int.random(in: 1...6)
        let questionID = "complete-\(entry.id)-\(blankIndex)"
        if questionID == previousQuestionID { return nil }

        let displays = entry.degreeSpellings.map(ScaleModel.formatNoteName)
        let correct = displays[blankIndex]
        let distractors = noteDistractors(
            correctSpelling: entry.degreeSpellings[blankIndex],
            scaleSpellings: entry.degreeSpellings
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
            promptTitle: "\(entry.displayName)를 완성하세요",
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
        guard let entry = catalog.randomElement() else { return nil }
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
            promptTitle: "다음 음계는 무엇일까요?",
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
        guard let kind = ScaleKind.allCases.randomElement() else { return nil }
        let blankIndex = Int.random(in: 0...6)
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
            promptTitle: "\(kind.englishTitle) Scale의 음정 패턴을 완성하세요",
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
        guard let entry = catalog.randomElement() else { return nil }
        let degreeIndex = Int.random(in: 1...6) // 2도…7도
        let degreeNumber = degreeIndex + 1
        let askForNote = Bool.random()
        let questionID = "degree-\(entry.id)-\(degreeNumber)-\(askForNote ? "note" : "num")"
        if questionID == previousQuestionID { return nil }

        let displays = entry.degreeSpellings.map(ScaleModel.formatNoteName)
        let noteDisplay = displays[degreeIndex]

        if askForNote {
            let correct = noteDisplay
            let distractors = noteDistractors(
                correctSpelling: entry.degreeSpellings[degreeIndex],
                scaleSpellings: entry.degreeSpellings
            )
            guard distractors.count == 3 else { return nil }

            return Question(
                kind: .identifyDegree,
                promptTitle: "\(entry.displayName)의 \(degreeNumber)도는?",
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

        let correct = "\(degreeNumber)도"
        let otherDegrees = (2...7)
            .filter { $0 != degreeNumber }
            .shuffled()
            .prefix(3)
            .map { "\($0)도" }
        guard otherDegrees.count == 3 else { return nil }

        return Question(
            kind: .identifyDegree,
                promptTitle: "\(entry.displayName)에서 \(noteDisplay)의 도수는?",
            scaleLabel: entry.displayName,
            promptTokens: [],
            staffNotes: [],
            staffIntervals: [],
            staffNoteNames: [],
            choices: (Array(otherDegrees) + [correct]).shuffled(),
            correctAnswer: correct,
            explanationContext: ExplanationContext(
                tonicSpelling: entry.tonic,
                kind: entry.kind,
                degreeSpellings: entry.degreeSpellings,
                blankIndex: nil,
                degreeNumber: degreeNumber,
                askedNoteDisplay: noteDisplay
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
            return "\(scaleName): \(degrees.joined(separator: " → "))"
        case .identifyScale:
            return "구성음 \(degrees.joined(separator: " → "))"
        case .completePattern:
            return "\(context.kind.englishTitle): \(patternSummary(for: context.kind))"
        case .identifyDegree:
            if let asked = context.askedNoteDisplay, let degree = context.degreeNumber {
                return "\(scaleName)에서 \(asked)는 \(degree)도입니다."
            }
            if let degree = context.degreeNumber {
                let note = degrees[degree - 1]
                return "\(scaleName)의 \(degree)도는 \(note)입니다."
            }
            return scaleName
        }
    }

    private func completeScaleWrongFeedback(
        answer: String,
        degrees: [String],
        context: ExplanationContext
    ) -> Feedback {
        guard let blankIndex = context.blankIndex else {
            return Feedback(
                headline: "\(answer) ✕ → \(question.correctAnswer) ✓",
                detail: ""
            )
        }
        let correct = degrees[blankIndex]
        let headline = "\(answer) ✕ → \(correct) ✓"

        if blankIndex > 0 {
            let previous = degrees[blankIndex - 1]
            let step = ScaleStepInterval(semitones: context.kind.semitoneSteps[blankIndex - 1])
            return Feedback(
                headline: headline,
                detail: "\(previous) → \(correct)는 \(step.koreanLabel)이어야 합니다."
            )
        }

        return Feedback(
            headline: headline,
            detail: "\(scaleDisplayName(tonic: context.tonicSpelling, kind: context.kind))의 \(blankIndex + 1)도는 \(correct)입니다."
        )
    }

    private func degreeWrongFeedback(
        answer: String,
        scaleName: String,
        degrees: [String],
        context: ExplanationContext
    ) -> Feedback {
        if let asked = context.askedNoteDisplay, let degree = context.degreeNumber {
            return Feedback(
                headline: "\(answer) ✕ → \(degree)도 ✓",
                detail: "\(scaleName)에서 \(asked)는 \(degree)도입니다."
            )
        }
        if let degree = context.degreeNumber {
            let note = degrees[degree - 1]
            return Feedback(
                headline: "\(answer) ✕ → \(note) ✓",
                detail: "\(scaleName)의 \(degree)도는 \(note)입니다."
            )
        }
        return Feedback(headline: "\(answer) ✕ → \(question.correctAnswer) ✓", detail: "")
    }

    private func patternSummary(for kind: ScaleKind) -> String {
        kind.semitoneSteps
            .map { ScaleStepInterval(semitones: $0).koreanLabel }
            .joined(separator: " - ")
    }

    // MARK: - Distractors & catalog

    private func noteDistractors(correctSpelling: String, scaleSpellings: [String]) -> [String] {
        let correctDisplay = ScaleModel.formatNoteName(correctSpelling)
        var pool: [String] = []

        if let letter = correctSpelling.first {
            for suffix in ["", "#", "b"] {
                let candidate = String(letter) + suffix
                guard ScaleModel.isKnownSpelling(candidate) else { continue }
                let display = ScaleModel.formatNoteName(candidate)
                if display != correctDisplay {
                    pool.append(display)
                }
            }
        }

        for spelling in scaleSpellings {
            let display = ScaleModel.formatNoteName(spelling)
            if display != correctDisplay {
                pool.append(display)
            }
        }

        // Nearby chromatic spellings from the explorer options.
        for option in explorer.noteOptions {
            let display = option.displayName
            if display != correctDisplay {
                pool.append(display)
            }
        }

        var unique: [String] = []
        var seen = Set<String>()
        for name in pool.shuffled() {
            if seen.insert(name).inserted {
                unique.append(name)
            }
            if unique.count == 3 { break }
        }
        return unique
    }

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
            let mode = ctx.askedNoteDisplay == nil ? "note" : "num"
            return "degree-\(ctx.tonicSpelling)|\(ctx.kind.rawValue)-\(ctx.degreeNumber ?? 0)-\(mode)"
        }
    }

    private var fallbackQuestion: Question {
        let spellings = ["C", "D", "E", "F", "G", "A", "B", "C"]
        let displays = spellings.map(ScaleModel.formatNoteName)
        return Question(
            kind: .completeScale,
            promptTitle: "C Major를 완성하세요",
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
