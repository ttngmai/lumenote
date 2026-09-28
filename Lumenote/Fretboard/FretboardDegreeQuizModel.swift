//

import Foundation

/// Difficulty chosen before a fretboard degree quiz session.
enum FretboardDegreeQuizDifficulty: String, CaseIterable, Hashable, Identifiable {
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

    /// Chromatic intervals from the marked root. Easy asks 3, 4, 5, and 7 only.
    fileprivate var intervalSemitones: [Int] {
        switch self {
        case .easy:
            return [4, 5, 7, 11]
        case .normal, .hard:
            return Array(Fretboard.quizTargetSemitones)
        }
    }

    /// String indexes allowed for the marked root. Index 0 is string 1 (high E).
    fileprivate var rootStringIndices: [Int] {
        switch self {
        case .easy:
            return [5, 4, 3]
        case .normal, .hard:
            return Array(0..<Fretboard.stringCount)
        }
    }

    fileprivate var lastFret: Int {
        switch self {
        case .easy, .normal:
            return Fretboard.lastFret
        case .hard:
            return Fretboard.explorerLastFret
        }
    }
}

/// Quiz: a tonic is marked on the board, and any matching target-degree fret is correct.
@Observable
final class FretboardDegreeQuizModel {
    struct Question: Equatable {
        let rootPosition: Fretboard.Position
        let rootPitchClass: Int
        let intervalSemitones: Int
        let targetPitchClass: Int
        let accidental: AccidentalPreference
        let fretWindow: ClosedRange<Int>
    }

    let difficulty: FretboardDegreeQuizDifficulty
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
        Fretboard.degreeLabel(
            pitchClass: question.targetPitchClass,
            rootPitchClass: question.rootPitchClass,
            accidental: question.accidental
        )
    }

    var accessibilityName: String {
        Fretboard.accessibilityName(
            pitchClass: question.targetPitchClass,
            accidental: question.accidental,
            labelMode: .degree,
            rootPitchClass: question.rootPitchClass
        )
    }

    init(difficulty: FretboardDegreeQuizDifficulty, questionLimit: Int) {
        self.difficulty = difficulty
        self.questionLimit = Self.normalizedQuestionCount(questionLimit)
        question = Question(
            rootPosition: Fretboard.Position(stringIndex: 0, fret: 0),
            rootPitchClass: 0,
            intervalSemitones: 2,
            targetPitchClass: 2,
            accidental: .sharp,
            fretWindow: 0...(Fretboard.quizWindowLength - 1)
        )
        question = makeQuestion(avoiding: nil)
    }

    func select(_ position: Fretboard.Position) {
        guard selectedPosition == nil, !isFinished else { return }
        guard question.fretWindow.contains(position.fret) else { return }
        guard position != question.rootPosition else { return }
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
        let previous = question.intervalSemitones
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

    private func makeQuestion(avoiding previousInterval: Int?) -> Question {
        if let question = randomQuestion(avoiding: previousInterval) {
            return question
        }
        return randomQuestion(avoiding: nil) ?? question
    }

    private func randomQuestion(avoiding previousInterval: Int?) -> Question? {
        let windows = Fretboard.quizFretWindows(lastFret: difficulty.lastFret)
        let rootStrings = difficulty.rootStringIndices
        for _ in 0..<80 {
            guard let window = windows.randomElement(),
                  let stringIndex = rootStrings.randomElement()
            else { return nil }
            let rootPosition = Fretboard.Position(
                stringIndex: stringIndex,
                fret: Int.random(in: window)
            )
            let rootPitchClass = Fretboard.pitchClass(at: rootPosition)
            let intervals = availableIntervals(
                rootPitchClass: rootPitchClass,
                window: window,
                avoiding: previousInterval
            )
            guard let intervalSemitones = intervals.randomElement() else { continue }
            let targetPitchClass = Fretboard.normalizedPitchClass(rootPitchClass + intervalSemitones)
            return Question(
                rootPosition: rootPosition,
                rootPitchClass: rootPitchClass,
                intervalSemitones: intervalSemitones,
                targetPitchClass: targetPitchClass,
                accidental: accidental(forSemitones: intervalSemitones),
                fretWindow: window
            )
        }
        return nil
    }

    private func availableIntervals(
        rootPitchClass: Int,
        window: ClosedRange<Int>,
        avoiding previousInterval: Int?
    ) -> [Int] {
        difficulty.intervalSemitones.filter { intervalSemitones in
            if intervalSemitones == previousInterval { return false }
            let targetPitchClass = Fretboard.normalizedPitchClass(rootPitchClass + intervalSemitones)
            return !Fretboard.positions(of: targetPitchClass, frets: window).isEmpty
        }
    }

    /// Chromatic degrees pick sharp or flat at random; naturals keep sharp spellings for markers.
    private func accidental(forSemitones intervalSemitones: Int) -> AccidentalPreference {
        let sharp = Fretboard.degreeLabel(
            pitchClass: intervalSemitones,
            rootPitchClass: 0,
            accidental: .sharp
        )
        let flat = Fretboard.degreeLabel(
            pitchClass: intervalSemitones,
            rootPitchClass: 0,
            accidental: .flat
        )
        if sharp == flat {
            return .sharp
        }
        return Bool.random() ? .sharp : .flat
    }
}
