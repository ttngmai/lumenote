//

import Foundation

/// Difficulty chosen before a fretboard degree quiz session.
enum FretboardDegreeQuizDifficulty: String, CaseIterable, Hashable, Identifiable {
    case easy
    case normal
    case hard

    static let storageKey = "fretboardDegreeQuizDifficulty"
    static let questionCountStorageKey = "fretboardDegreeQuizQuestionCount"
    static let fretRangeModeStorageKey = "fretboardDegreeQuizFretRangeMode"
    static let fretWindowStartStorageKey = "fretboardDegreeQuizFretWindowStart"
    static let answerModeStorageKey = "fretboardDegreeQuizAnswerMode"

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

    init(
        difficulty: FretboardDegreeQuizDifficulty,
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
        guard !hasAnswered, !isFinished else { return }
        guard question.fretWindow.contains(position.fret) else { return }
        guard position != question.rootPosition else { return }
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
        let previous = question.intervalSemitones
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

    private func makeQuestion(avoiding previousInterval: Int?) -> Question {
        if let question = randomQuestion(avoiding: previousInterval) {
            return question
        }
        return randomQuestion(avoiding: nil) ?? question
    }

    private func randomQuestion(avoiding previousInterval: Int?) -> Question? {
        let windows = windowsForQuestion()
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
            let allowed = Set(focusSkillKeys.compactMap(Int.init))
            let focused = focusSkillKeys.isEmpty ? intervals : intervals.filter { allowed.contains($0) }
            guard let intervalSemitones = focused.randomElement() else { continue }
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

    private func windowsForQuestion() -> [ClosedRange<Int>] {
        switch fretRangeMode {
        case .fixed:
            return [fretWindow]
        case .eachQuestion:
            return Fretboard.quizFretWindows(lastFret: Fretboard.explorerLastFret)
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
                Fretboard.degreeLabel(
                    pitchClass: Fretboard.pitchClass(at: position),
                    rootPitchClass: question.rootPitchClass,
                    accidental: question.accidental
                )
            }
            .sorted()
            .joined(separator: ", ")
        recorder?.record(
            LearningAttemptInput(
                topic: .fretboardDegree,
                skillKey: LearningSkillKey.fretboardDegree(semitones: question.intervalSemitones),
                correct: isCorrect,
                expected: displayName,
                chosen: chosen,
                difficulty: difficulty.rawValue
            )
        )
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
