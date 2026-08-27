//

import Foundation

/// Mixed chord quiz: complete tones, identify chord, complete formula, identify degree, match notation.
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
        /// Ask for a chord tone's note, or a note's degree label.
        case identifyTone
        /// Match a chord kind to its primary symbol (and the reverse).
        case identifyNotation
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
        /// Large centered symbol for notation → kind prompts.
        let promptEmphasis: String?
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
        let askedNoteDisplay: String?
    }

    private let explorer = ChordModel()
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
                    symbol: symbol,
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
                detail: "구성음 \(tones.joined(separator: " · "))는 \(symbol)입니다."
            )
        case .completeFormula:
            return Feedback(
                headline: "\(answer) ✕ → \(question.correctAnswer) ✓",
                detail: "\(kindLabel(ctx.kind))의 구성음은 \(formula)입니다."
            )
        case .identifyTone:
            return identifyToneWrongFeedback(
                answer: answer,
                chordName: chordName,
                tones: tones,
                context: ctx
            )
        case .identifyNotation:
            return Feedback(
                headline: "\(answer) ✕ → \(question.correctAnswer) ✓",
                detail: "\(symbol)은 \(kindLabel(ctx.kind)) 표기입니다."
            )
        }
    }

    // MARK: - Generation

    private func makeQuestion() -> Question {
        for _ in 0..<80 {
            let candidate: Question?
            // Weight complete-chord highest — it mirrors the learning screen most closely.
            switch Int.random(in: 0..<10) {
            case 0..<4:
                candidate = makeCompleteChordQuestion()
            case 4..<6:
                candidate = makeIdentifyChordQuestion()
            case 6..<8:
                candidate = makeCompleteFormulaQuestion()
            case 8:
                candidate = makeIdentifyToneQuestion()
            default:
                candidate = makeIdentifyNotationQuestion()
            }
            if let question = candidate {
                previousQuestionID = questionID(for: question)
                return question
            }
        }
        return fallbackQuestion
    }

    private func makeCompleteChordQuestion() -> Question? {
        guard let entry = catalog.randomElement() else { return nil }
        let blankIndex = Int.random(in: 1..<entry.toneSpellings.count)
        let questionID = "complete-\(entry.id)-\(blankIndex)"
        if questionID == previousQuestionID { return nil }

        let displays = entry.toneSpellings.map(ScaleModel.formatNoteName)
        let correct = displays[blankIndex]
        let distractors = noteDistractors(
            correctSpelling: entry.toneSpellings[blankIndex],
            chordSpellings: entry.toneSpellings
        )
        guard distractors.count == 3 else { return nil }

        var tokens: [PromptToken] = []
        for (index, name) in displays.enumerated() {
            tokens.append(index == blankIndex ? .blank : .note(name))
        }

        return Question(
            kind: .completeChord,
            promptTitle: "\(entry.displayName)를 완성하세요",
            promptEmphasis: nil,
            promptTokens: tokens,
            staffNotes: [],
            staffNoteNames: [],
            choices: (distractors + [correct]).shuffled(),
            correctAnswer: correct,
            explanationContext: ExplanationContext(
                rootSpelling: entry.root,
                kind: entry.kind,
                toneSpellings: entry.toneSpellings,
                blankIndex: blankIndex,
                degreeNumber: degreeNumber(at: blankIndex),
                askedNoteDisplay: nil
            )
        )
    }

    private func makeIdentifyChordQuestion() -> Question? {
        guard let entry = catalog.randomElement() else { return nil }
        let questionID = "identify-\(entry.id)"
        if questionID == previousQuestionID { return nil }

        let distractorKinds = kindDistractors(for: entry.kind)
        guard distractorKinds.count == 3 else { return nil }

        let correct = chordSymbol(root: entry.root, kind: entry.kind)
        let distractors = distractorKinds.map { chordSymbol(root: entry.root, kind: $0) }
        let unique = Set(distractors + [correct])
        guard unique.count == 4 else { return nil }

        configureExplorer(entry)

        return Question(
            kind: .identifyChord,
            promptTitle: "다음 화음은 무엇일까요?",
            promptEmphasis: nil,
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
                degreeNumber: nil,
                askedNoteDisplay: nil
            )
        )
    }

    private func makeCompleteFormulaQuestion() -> Question? {
        guard let kind = ChordKind.allCases.randomElement() else { return nil }
        let blankIndex = Int.random(in: 1..<kind.tones.count)
        let questionID = "formula-\(kind.rawValue)-\(blankIndex)"
        if questionID == previousQuestionID { return nil }

        let labels = kind.tones.map(\.degreeLabel)
        let correct = labels[blankIndex]
        let distractors = formulaDistractors(correct: correct)
        guard distractors.count == 3 else { return nil }

        var tokens: [PromptToken] = []
        for (index, label) in labels.enumerated() {
            tokens.append(index == blankIndex ? .degreeBlank : .degree(label))
        }

        return Question(
            kind: .completeFormula,
            promptTitle: "\(kindLabel(kind))의 구성음을 완성하세요",
            promptEmphasis: nil,
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
                degreeNumber: degreeNumber(at: blankIndex),
                askedNoteDisplay: nil
            )
        )
    }

    private func makeIdentifyToneQuestion() -> Question? {
        guard let entry = catalog.randomElement() else { return nil }
        let toneIndex = pickToneIndex(for: entry.kind)
        let degree = degreeNumber(at: toneIndex)
        let askForNote = Bool.random()
        let questionID = "tone-\(entry.id)-\(degree)-\(askForNote ? "note" : "label")"
        if questionID == previousQuestionID { return nil }

        let displays = entry.toneSpellings.map(ScaleModel.formatNoteName)
        let noteDisplay = displays[toneIndex]
        let degreeLabel = entry.kind.tones[toneIndex].degreeLabel

        if askForNote {
            let distractors = noteDistractors(
                correctSpelling: entry.toneSpellings[toneIndex],
                chordSpellings: entry.toneSpellings
            )
            guard distractors.count == 3 else { return nil }

            return Question(
                kind: .identifyTone,
                promptTitle: "\(entry.displayName)의 \(degree)도는?",
                promptEmphasis: nil,
                promptTokens: [],
                staffNotes: [],
                staffNoteNames: [],
                choices: (distractors + [noteDisplay]).shuffled(),
                correctAnswer: noteDisplay,
                explanationContext: ExplanationContext(
                    rootSpelling: entry.root,
                    kind: entry.kind,
                    toneSpellings: entry.toneSpellings,
                    blankIndex: toneIndex,
                    degreeNumber: degree,
                    askedNoteDisplay: nil
                )
            )
        }

        let distractors = formulaDistractors(correct: degreeLabel)
        guard distractors.count == 3 else { return nil }

        return Question(
            kind: .identifyTone,
            promptTitle: "\(entry.displayName)에서 \(noteDisplay)는?",
            promptEmphasis: nil,
            promptTokens: [],
            staffNotes: [],
            staffNoteNames: [],
            choices: (distractors + [degreeLabel]).shuffled(),
            correctAnswer: degreeLabel,
            explanationContext: ExplanationContext(
                rootSpelling: entry.root,
                kind: entry.kind,
                toneSpellings: entry.toneSpellings,
                blankIndex: toneIndex,
                degreeNumber: degree,
                askedNoteDisplay: noteDisplay
            )
        )
    }

    private func makeIdentifyNotationQuestion() -> Question? {
        guard let entry = catalog.randomElement() else { return nil }
        let askForKind = Bool.random()
        let questionID = "notation-\(entry.id)-\(askForKind ? "kind" : "symbol")"
        if questionID == previousQuestionID { return nil }

        let distractorKinds = kindDistractors(for: entry.kind)
        guard distractorKinds.count == 3 else { return nil }

        if askForKind {
            let correct = kindLabel(entry.kind)
            let distractors = distractorKinds.map(kindLabel)
            let unique = Set(distractors + [correct])
            guard unique.count == 4 else { return nil }

            let rootName = ScaleModel.formatNoteName(entry.root)
            return Question(
                kind: .identifyNotation,
                promptTitle: "근음이 \(rootName)일 때, 다음 표기의 화음은?",
                promptEmphasis: chordSymbol(root: entry.root, kind: entry.kind),
                promptTokens: [],
                staffNotes: [],
                staffNoteNames: [],
                choices: (distractors + [correct]).shuffled(),
                correctAnswer: correct,
                explanationContext: ExplanationContext(
                    rootSpelling: entry.root,
                    kind: entry.kind,
                    toneSpellings: entry.toneSpellings,
                    blankIndex: nil,
                    degreeNumber: nil,
                    askedNoteDisplay: nil
                )
            )
        }

        let correct = chordSymbol(root: entry.root, kind: entry.kind)
        let distractors = distractorKinds.map { chordSymbol(root: entry.root, kind: $0) }
        let unique = Set(distractors + [correct])
        guard unique.count == 4 else { return nil }

        return Question(
            kind: .identifyNotation,
            promptTitle: "\(entry.displayName)의 표기는?",
            promptEmphasis: nil,
            promptTokens: [],
            staffNotes: [],
            staffNoteNames: [],
            choices: (distractors + [correct]).shuffled(),
            correctAnswer: correct,
            explanationContext: ExplanationContext(
                rootSpelling: entry.root,
                kind: entry.kind,
                toneSpellings: entry.toneSpellings,
                blankIndex: nil,
                degreeNumber: nil,
                askedNoteDisplay: nil
            )
        )
    }

    // MARK: - Feedback helpers

    private func correctDetail(
        for kind: QuestionKind,
        chordName: String,
        symbol: String,
        tones: [String],
        formula: String,
        context: ExplanationContext
    ) -> String {
        switch kind {
        case .completeChord:
            return "\(chordName): \(tones.joined(separator: " · "))"
        case .identifyChord:
            return "구성음 \(tones.joined(separator: " · "))"
        case .completeFormula:
            return "\(kindLabel(context.kind)): \(formula)"
        case .identifyTone:
            if let asked = context.askedNoteDisplay, let degree = context.degreeNumber {
                let label = context.kind.tones[degreeIndex(for: degree)].degreeLabel
                return "\(chordName)에서 \(asked)는 \(label)입니다."
            }
            if let degree = context.degreeNumber {
                let note = tones[degreeIndex(for: degree)]
                return "\(chordName)의 \(degree)도는 \(note)입니다."
            }
            return chordName
        case .identifyNotation:
            return "\(symbol)은 \(kindLabel(context.kind)) 표기입니다."
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
        let label = context.kind.tones[blankIndex].degreeLabel
        return Feedback(
            headline: "\(answer) ✕ → \(correct) ✓",
            detail: "\(chordLabel(root: context.rootSpelling, kind: context.kind))의 \(degree)도(\(label))는 \(correct)입니다."
        )
    }

    private func identifyToneWrongFeedback(
        answer: String,
        chordName: String,
        tones: [String],
        context: ExplanationContext
    ) -> Feedback {
        if let asked = context.askedNoteDisplay, let degree = context.degreeNumber {
            let label = context.kind.tones[degreeIndex(for: degree)].degreeLabel
            return Feedback(
                headline: "\(answer) ✕ → \(label) ✓",
                detail: "\(chordName)에서 \(asked)는 \(label)입니다."
            )
        }
        if let degree = context.degreeNumber {
            let note = tones[degreeIndex(for: degree)]
            return Feedback(
                headline: "\(answer) ✕ → \(note) ✓",
                detail: "\(chordName)의 \(degree)도는 \(note)입니다."
            )
        }
        return Feedback(headline: "\(answer) ✕ → \(question.correctAnswer) ✓", detail: "")
    }

    // MARK: - Distractors & catalog

    private func noteDistractors(correctSpelling: String, chordSpellings: [String]) -> [String] {
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

        for spelling in chordSpellings {
            let display = ScaleModel.formatNoteName(spelling)
            if display != correctDisplay {
                pool.append(display)
            }
        }

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

    private func formulaDistractors(correct: String) -> [String] {
        let groups = [
            ["3", "♭3"],
            ["5", "♭5", "♯5"],
            ["7", "♭7", "♭♭7"],
        ]
        var pool: [String] = []
        if let group = groups.first(where: { $0.contains(correct) }) {
            pool.append(contentsOf: group.filter { $0 != correct })
        }

        let extras = ["1", "3", "♭3", "5", "♭5", "♯5", "6", "7", "♭7", "♭♭7"]
        for label in extras.shuffled() where label != correct && !pool.contains(label) {
            pool.append(label)
        }

        return Array(pool.prefix(3))
    }

    private func kindDistractors(for kind: ChordKind) -> [ChordKind] {
        let preferred: [ChordKind]
        switch kind {
        case .majorTriad:
            preferred = [.minorTriad, .augmentedTriad, .diminishedTriad]
        case .minorTriad:
            preferred = [.majorTriad, .diminishedTriad, .augmentedTriad]
        case .augmentedTriad:
            preferred = [.majorTriad, .minorTriad, .diminishedTriad]
        case .diminishedTriad:
            preferred = [.minorTriad, .majorTriad, .augmentedTriad]
        case .major7:
            preferred = [.dominant7, .minorMajor7, .minor7]
        case .dominant7:
            preferred = [.major7, .minor7, .minorMajor7]
        case .minorMajor7:
            preferred = [.minor7, .major7, .dominant7]
        case .minor7:
            preferred = [.minorMajor7, .halfDiminished7, .dominant7]
        case .halfDiminished7:
            preferred = [.diminished7, .minor7, .minorMajor7]
        case .diminished7:
            preferred = [.halfDiminished7, .minor7, .dominant7]
        }

        let sameCategory = ChordKind.allCases.filter { $0.category == kind.category && $0 != kind }
        var result: [ChordKind] = []
        var seen = Set<ChordKind>()
        for candidate in preferred + sameCategory.shuffled() {
            if candidate != kind, seen.insert(candidate).inserted {
                result.append(candidate)
            }
            if result.count == 3 { break }
        }
        return result
    }

    private func pickToneIndex(for kind: ChordKind) -> Int {
        if kind.tones.count == 4 {
            let roll = Int.random(in: 0..<10)
            if roll < 5 { return 3 }
            if roll < 8 { return 1 }
            return 2
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

    private static let quizRoots: [String] = [
        "C", "G", "D", "A", "E", "B", "F#",
        "Db", "Ab", "Eb", "Bb", "F",
        "C#", "Gb",
    ]

    private static func buildCatalog() -> [CatalogEntry] {
        let probe = ChordModel()
        var entries: [CatalogEntry] = []
        for root in quizRoots {
            for kind in ChordKind.allCases {
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

    private func configureExplorer(_ entry: CatalogEntry) {
        explorer.rootSpelling = entry.root
        explorer.kind = entry.kind
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
            let mode = ctx.askedNoteDisplay == nil ? "note" : "label"
            return "tone-\(ctx.rootSpelling)|\(ctx.kind.rawValue)-\(ctx.degreeNumber ?? 0)-\(mode)"
        case .identifyNotation:
            let mode = question.promptEmphasis == nil ? "symbol" : "kind"
            return "notation-\(ctx.rootSpelling)|\(ctx.kind.rawValue)-\(mode)"
        }
    }

    private var fallbackQuestion: Question {
        let spellings = ["C", "E", "G", "B"]
        let displays = spellings.map(ScaleModel.formatNoteName)
        return Question(
            kind: .completeChord,
            promptTitle: "C Major 7를 완성하세요",
            promptEmphasis: nil,
            promptTokens: [.note("C"), .note("E"), .note("G"), .blank],
            staffNotes: [],
            staffNoteNames: [],
            choices: ["B", "B♭", "A", "D"].shuffled(),
            correctAnswer: displays[3],
            explanationContext: ExplanationContext(
                rootSpelling: "C",
                kind: .major7,
                toneSpellings: spellings,
                blankIndex: 3,
                degreeNumber: 7,
                askedNoteDisplay: nil
            )
        )
    }

    private static var placeholderQuestion: Question {
        Question(
            kind: .completeChord,
            promptTitle: "",
            promptEmphasis: nil,
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
                degreeNumber: nil,
                askedNoteDisplay: nil
            )
        )
    }
}
