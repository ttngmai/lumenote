//

import Foundation

/// Multiple-choice quiz: identify the ascending interval between two notes.
@Observable
final class IntervalQuizModel {
    struct Question: Equatable {
        let rootDisplayName: String
        let targetDisplayName: String
        let staffNotes: [IntervalStaffNote]
        let choices: [String]
        let correctAnswer: String
    }

    private let explorer = IntervalModel()
    private var previousPair: (root: String, target: String)?

    /// Common chromatic spellings; rarer double-identity notes are omitted so prompts stay familiar.
    private let spellings: [String] = [
        "C", "C#", "Db", "D", "D#", "Eb", "E", "F",
        "F#", "Gb", "G", "G#", "Ab", "A", "A#", "Bb", "B",
    ]

    /// All ascending interval names reachable from the quiz spelling pool.
    private let intervalNames: [String]

    private(set) var question: Question
    private(set) var selectedAnswer: String?
    private(set) var correctCount = 0
    private(set) var answeredCount = 0

    var hasAnswered: Bool { selectedAnswer != nil }

    var isSelectionCorrect: Bool {
        selectedAnswer == question.correctAnswer
    }

    init() {
        intervalNames = Self.collectIntervalNames(for: spellings)
        question = Question(
            rootDisplayName: "C",
            targetDisplayName: "E",
            staffNotes: [],
            choices: [],
            correctAnswer: "장3도"
        )
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

    private func makeQuestion() -> Question {
        for _ in 0..<80 {
            guard let root = spellings.randomElement(),
                  let target = spellings.randomElement()
            else { continue }

            if previousPair?.root == root, previousPair?.target == target {
                continue
            }

            explorer.rootSpelling = root
            explorer.targetSpelling = target
            let correct = explorer.ascendingIntervalName
            guard intervalNames.contains(correct) else { continue }

            let distractors = intervalNames
                .filter { $0 != correct }
                .shuffled()
                .prefix(3)
            guard distractors.count == 3 else { continue }

            previousPair = (root, target)
            return Question(
                rootDisplayName: explorer.rootDisplayName,
                targetDisplayName: explorer.targetDisplayName,
                staffNotes: explorer.ascendingStaffNotes,
                choices: (Array(distractors) + [correct]).shuffled(),
                correctAnswer: correct
            )
        }

        return fallbackQuestion
    }

    private var fallbackQuestion: Question {
        explorer.rootSpelling = "C"
        explorer.targetSpelling = "E"
        previousPair = ("C", "E")
        return Question(
            rootDisplayName: explorer.rootDisplayName,
            targetDisplayName: explorer.targetDisplayName,
            staffNotes: explorer.ascendingStaffNotes,
            choices: ["장3도", "단3도", "완전4도", "완전5도"].shuffled(),
            correctAnswer: "장3도"
        )
    }

    private static func collectIntervalNames(for spellings: [String]) -> [String] {
        let explorer = IntervalModel()
        var names = Set<String>()
        for root in spellings {
            for target in spellings {
                explorer.rootSpelling = root
                explorer.targetSpelling = target
                names.insert(explorer.ascendingIntervalName)
            }
        }
        return names.sorted()
    }
}
