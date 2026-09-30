//

import Foundation

/// Difficulty chosen before a fretboard note-name quiz session.
enum FretboardNoteQuizDifficulty: String, CaseIterable, Hashable, Identifiable {
    case normal
    case hard

    static let storageKey = "fretboardNoteQuizDifficulty"
    static let questionCountStorageKey = "fretboardNoteQuizQuestionCount"
    static let fretRangeModeStorageKey = "fretboardNoteQuizFretRangeMode"
    static let fretWindowStartStorageKey = "fretboardNoteQuizFretWindowStart"
    static let answerModeStorageKey = "fretboardNoteQuizAnswerMode"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .normal: "Normal"
        case .hard: "Hard"
        }
    }

    /// Naturals, or every pitch class. The visible fret window is chosen separately.
    fileprivate var pitchClasses: [Int] {
        switch self {
        case .normal:
            return [0, 2, 4, 5, 7, 9, 11]
        case .hard:
            return Fretboard.pitchClasses
        }
    }
}

/// Quiz: a pitch class is named, and any matching fret in the visible window is correct.
@Observable
final class FretboardNoteQuizModel {
    struct Question: Equatable {
        let targetPitchClass: Int
        let accidental: AccidentalPreference
        let fretWindow: ClosedRange<Int>
    }

    let difficulty: FretboardNoteQuizDifficulty
    /// Number of questions in this session: 10, 20, 30, 40, or 50.
    let questionLimit: Int
    let fretRangeMode: FretboardQuizFretRangeMode
    /// Window used for the whole session when `fretRangeMode` is `.fixed`.
    let fretWindow: ClosedRange<Int>
    let answerMode: FretboardQuizAnswerMode
    private let recorder: (any LearningRecording)?
    private let focusSkillKeys: Set<String>

    private(set) var question: Question
    private(set) var selectedPositions: Set<Fretboard.Position> = []
    private(set) var hasAnswered = false
    private(set) var correctCount = 0
    private(set) var answeredCount = 0
    /// One entry per answered question, in order. `true` is a correct answer.
    private(set) var outcomes: [Bool] = []
    private(set) var isFinished = false

    var incorrectCount: Int { answeredCount - correctCount }

    var isSelectionCorrect: Bool {
        guard hasAnswered else { return false }
        switch answerMode {
        case .findOne:
            return selectedPositions.allSatisfy {
                Fretboard.pitchClass(at: $0) == question.targetPitchClass
            }
        case .findAll:
            return Set(matchingPositions) == selectedPositions
        }
    }

    var isOnFinalAnswer: Bool {
        hasAnswered && answeredCount >= questionLimit
    }

    var matchingPositions: [Fretboard.Position] {
        Fretboard.positions(of: question.targetPitchClass, frets: question.fretWindow)
    }

    var displayName: String {
        Fretboard.displayName(
            pitchClass: question.targetPitchClass,
            accidental: question.accidental
        )
    }

    init(
        difficulty: FretboardNoteQuizDifficulty,
        questionLimit: Int,
        fretRangeMode: FretboardQuizFretRangeMode = .eachQuestion,
        fretWindow: ClosedRange<Int> = 0...(Fretboard.quizWindowLength - 1),
        answerMode: FretboardQuizAnswerMode = .findOne,
        recorder: (any LearningRecording)? = nil,
        focusSkillKeys: Set<String> = []
    ) {
        self.difficulty = difficulty
        self.questionLimit = focusSkillKeys.isEmpty
            ? Self.normalizedQuestionCount(questionLimit)
            : min(10, max(1, questionLimit))
        self.fretRangeMode = fretRangeMode
        self.fretWindow = Fretboard.clampedQuizFretWindow(fretWindow)
        self.answerMode = answerMode
        self.recorder = recorder
        self.focusSkillKeys = focusSkillKeys
        question = Question(
            targetPitchClass: 0,
            accidental: .sharp,
            fretWindow: 0...(Fretboard.quizWindowLength - 1)
        )
        question = makeQuestion(avoiding: nil)
    }

    func select(_ position: Fretboard.Position) {
        guard !hasAnswered, !isFinished else { return }
        guard question.fretWindow.contains(position.fret) else { return }
        switch FretboardQuizGrading.select(
            position: position,
            answerMode: answerMode,
            targetPitchClass: question.targetPitchClass,
            matches: matchingPositions,
            selected: &selectedPositions
        ) {
        case .inProgress:
            break
        case .finished(let isCorrect):
            completeSelection(isCorrect: isCorrect)
        }
    }

    func nextQuestion() {
        guard hasAnswered, !isFinished, answeredCount < questionLimit else { return }
        let previous = question.targetPitchClass
        selectedPositions = []
        hasAnswered = false
        question = makeQuestion(avoiding: previous)
    }

    func finish() {
        guard isOnFinalAnswer else { return }
        isFinished = true
    }

    static func normalizedQuestionCount(_ count: Int) -> Int {
        let stepped = (count / 10) * 10
        return min(50, max(10, stepped))
    }

    private func makeQuestion(avoiding previous: Int?) -> Question {
        var pool = difficulty.pitchClasses
        if !focusSkillKeys.isEmpty {
            let allowed = Set(focusSkillKeys.compactMap(Int.init))
            let focused = pool.filter { allowed.contains($0) }
            if !focused.isEmpty {
                pool = focused
            }
        }
        let candidates = pool.filter { $0 != previous }
        let pitchClass = (candidates.isEmpty ? pool : candidates).randomElement() ?? pool[0]
        let window = window(containing: pitchClass)
        return Question(
            targetPitchClass: pitchClass,
            accidental: accidental(for: pitchClass),
            fretWindow: window
        )
    }

    private func window(containing pitchClass: Int) -> ClosedRange<Int> {
        switch fretRangeMode {
        case .fixed:
            return fretWindow
        case .eachQuestion:
            let windows = Fretboard.quizFretWindows(
                containing: pitchClass,
                lastFret: Fretboard.explorerLastFret
            )
            return windows.randomElement() ?? fretWindow
        }
    }

    private func completeSelection(isCorrect: Bool) {
        hasAnswered = true
        answeredCount += 1
        if isCorrect {
            correctCount += 1
        }
        outcomes.append(isCorrect)
        let chosen = selectedPositions
            .map { position in
                Fretboard.displayName(
                    pitchClass: Fretboard.pitchClass(at: position),
                    accidental: question.accidental
                )
            }
            .sorted()
            .joined(separator: ", ")
        recorder?.record(
            LearningAttemptInput(
                topic: .fretboardNote,
                skillKey: LearningSkillKey.fretboardNote(pitchClass: question.targetPitchClass),
                correct: isCorrect,
                expected: displayName,
                chosen: chosen,
                difficulty: difficulty.rawValue
            )
        )
    }

    /// Black keys pick sharp or flat at random; naturals keep sharp spellings for markers.
    private func accidental(for pitchClass: Int) -> AccidentalPreference {
        let sharp = Fretboard.displayName(pitchClass: pitchClass, accidental: .sharp)
        let flat = Fretboard.displayName(pitchClass: pitchClass, accidental: .flat)
        if sharp == flat {
            return .sharp
        }
        return Bool.random() ? .sharp : .flat
    }
}
