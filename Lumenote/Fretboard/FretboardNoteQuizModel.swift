//

import Foundation

/// Difficulty chosen before a fretboard note-name quiz session.
enum FretboardNoteQuizDifficulty: String, CaseIterable, Hashable, Identifiable {
    case normal
    case hard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .normal: "Normal"
        case .hard: "Hard"
        }
    }

    /// Naturals through the 12th fret, or every pitch class through the 22nd.
    fileprivate var pitchClasses: [Int] {
        switch self {
        case .normal:
            return [0, 2, 4, 5, 7, 9, 11]
        case .hard:
            return Fretboard.pitchClasses
        }
    }

    fileprivate var lastFret: Int {
        switch self {
        case .normal:
            return Fretboard.lastFret
        case .hard:
            return Fretboard.explorerLastFret
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

    private(set) var question: Question
    private(set) var selectedPosition: Fretboard.Position?
    private(set) var correctCount = 0
    private(set) var answeredCount = 0
    /// One entry per answered question, in order. `true` is a correct answer.
    private(set) var outcomes: [Bool] = []
    private(set) var isFinished = false

    var hasAnswered: Bool { selectedPosition != nil }

    var incorrectCount: Int { answeredCount - correctCount }

    var isSelectionCorrect: Bool {
        guard let selectedPosition else { return false }
        return Fretboard.pitchClass(at: selectedPosition) == question.targetPitchClass
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

    init(difficulty: FretboardNoteQuizDifficulty, questionLimit: Int) {
        self.difficulty = difficulty
        self.questionLimit = Self.normalizedQuestionCount(questionLimit)
        question = Question(
            targetPitchClass: 0,
            accidental: .sharp,
            fretWindow: 0...(Fretboard.quizWindowLength - 1)
        )
        question = makeQuestion(avoiding: nil)
    }

    func select(_ position: Fretboard.Position) {
        guard selectedPosition == nil, !isFinished else { return }
        guard question.fretWindow.contains(position.fret) else { return }
        selectedPosition = position
        answeredCount += 1
        let correct = Fretboard.pitchClass(at: position) == question.targetPitchClass
        if correct {
            correctCount += 1
        }
        outcomes.append(correct)
    }

    func nextQuestion() {
        guard hasAnswered, !isFinished, answeredCount < questionLimit else { return }
        let previous = question.targetPitchClass
        selectedPosition = nil
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
        let pool = difficulty.pitchClasses
        let candidates = pool.filter { $0 != previous }
        let pitchClass = (candidates.isEmpty ? pool : candidates).randomElement() ?? pool[0]
        let windows = Fretboard.quizFretWindows(
            containing: pitchClass,
            lastFret: difficulty.lastFret
        )
        let window = windows.randomElement() ?? 0...(Fretboard.quizWindowLength - 1)
        return Question(
            targetPitchClass: pitchClass,
            accidental: accidental(for: pitchClass),
            fretWindow: window
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
