//

import Foundation

/// Difficulty chosen before an interval quiz session.
enum IntervalQuizDifficulty: String, CaseIterable, Hashable, Identifiable {
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

    private struct Prompt {
        let root: String
        let target: String
        let name: String
        let degree: Int
        let weight: IntervalWeight
    }

    /// Coarse interval family used for both filtering and draw weights.
    private enum IntervalWeight: Hashable {
        case perfect
        case major
        case minor
        case augmented
        case diminished
        case doubly
    }

    let difficulty: IntervalQuizDifficulty
    /// Number of questions in this session: 10, 20, 30, 40, or 50.
    let questionLimit: Int
    private let explorer = IntervalModel()
    private let catalog: [Prompt]
    private var previousPair: (root: String, target: String)?

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

    init(difficulty: IntervalQuizDifficulty, questionLimit: Int) {
        self.difficulty = difficulty
        self.questionLimit = Self.normalizedQuestionCount(questionLimit)
        catalog = Self.makeCatalog(for: difficulty)
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

    private func makeQuestion() -> Question {
        for _ in 0..<40 {
            guard let prompt = pickPrompt(),
                  let choices = makeChoices(correct: prompt)
            else { continue }

            explorer.rootSpelling = prompt.root
            explorer.targetSpelling = prompt.target
            guard explorer.ascendingIntervalName == prompt.name else { continue }
            previousPair = (prompt.root, prompt.target)
            return Question(
                rootDisplayName: explorer.rootDisplayName,
                targetDisplayName: explorer.targetDisplayName,
                staffNotes: explorer.ascendingStaffNotes,
                choices: choices,
                correctAnswer: prompt.name
            )
        }

        return fallbackQuestion
    }

    /// Draw an interval family by the difficulty's weights, then a spelling pair that produces it.
    private func pickPrompt() -> Prompt? {
        let avoidingRepeat = catalog.filter { prompt in
            previousPair?.root != prompt.root || previousPair?.target != prompt.target
        }
        let source = avoidingRepeat.isEmpty ? catalog : avoidingRepeat
        var buckets = Self.distribution(for: difficulty)

        while !buckets.isEmpty {
            let total = buckets.reduce(0) { $0 + $1.weight }
            guard total > 0 else { break }

            var roll = Int.random(in: 0..<total)
            var index = 0
            for (offset, bucket) in buckets.enumerated() {
                if roll < bucket.weight {
                    index = offset
                    break
                }
                roll -= bucket.weight
            }

            let chosen = buckets[index].family
            if let prompt = source.filter({ $0.weight == chosen }).randomElement() {
                return prompt
            }
            buckets.remove(at: index)
        }

        return source.randomElement()
    }

    private func makeChoices(correct: Prompt) -> [String]? {
        var degreeByName: [String: Int] = [:]
        for prompt in catalog where prompt.name != correct.name {
            degreeByName[prompt.name] = prompt.degree
        }

        let sameDegree = degreeByName.filter { $0.value == correct.degree }.map(\.key).shuffled()
        let otherDegree = degreeByName.filter { $0.value != correct.degree }.map(\.key).shuffled()

        var picked: [String] = []
        switch difficulty {
        case .easy:
            // One same-degree alternative when it exists, then easier-to-separate degrees.
            if let same = sameDegree.first {
                picked.append(same)
            }
            picked.append(contentsOf: otherDegree.prefix(3 - picked.count))
        case .normal:
            picked.append(contentsOf: sameDegree.prefix(2))
            picked.append(contentsOf: otherDegree.prefix(3 - picked.count))
        case .hard:
            picked.append(contentsOf: sameDegree.prefix(3))
            picked.append(contentsOf: otherDegree.prefix(3 - picked.count))
        }

        if picked.count < 3 {
            let remainder = (sameDegree + otherDegree).filter { !picked.contains($0) }
            picked.append(contentsOf: remainder.prefix(3 - picked.count))
        }

        guard picked.count == 3, Set(picked).count == 3 else { return nil }
        return (picked + [correct.name]).shuffled()
    }

    private var fallbackQuestion: Question {
        explorer.rootSpelling = "C"
        explorer.targetSpelling = "E"
        previousPair = ("C", "E")
        let choices = makeChoices(
            correct: Prompt(root: "C", target: "E", name: "장3도", degree: 3, weight: .major)
        ) ?? ["장3도", "단3도", "완전4도", "완전5도"]
        return Question(
            rootDisplayName: explorer.rootDisplayName,
            targetDisplayName: explorer.targetDisplayName,
            staffNotes: explorer.ascendingStaffNotes,
            choices: choices.shuffled(),
            correctAnswer: "장3도"
        )
    }

    private static func makeCatalog(for difficulty: IntervalQuizDifficulty) -> [Prompt] {
        let explorer = IntervalModel()
        let spellings = spellings(for: difficulty, explorer: explorer)
        let allowed = allowedWeights(for: difficulty)
        var prompts: [Prompt] = []

        for root in spellings {
            for target in spellings {
                explorer.rootSpelling = root
                explorer.targetSpelling = target
                guard let resolution = explorer.ascendingResolution(),
                      let weight = weight(degree: resolution.degree, offset: resolution.qualityOffset),
                      allowed.contains(weight)
                else { continue }

                prompts.append(
                    Prompt(
                        root: root,
                        target: target,
                        name: resolution.koreanName,
                        degree: resolution.degree,
                        weight: weight
                    )
                )
            }
        }

        return prompts
    }

    private static func spellings(for difficulty: IntervalQuizDifficulty, explorer: IntervalModel) -> [String] {
        let all = explorer.noteOptions.map(\.spelling)
        switch difficulty {
        case .easy:
            return all.filter { !$0.contains("#") && !$0.contains("b") }
        case .normal:
            let rare: Set<String> = ["Fb", "E#", "Cb", "B#"]
            return all.filter { !rare.contains($0) }
        case .hard:
            return all
        }
    }

    private static func allowedWeights(for difficulty: IntervalQuizDifficulty) -> Set<IntervalWeight> {
        switch difficulty {
        case .easy:
            [.perfect, .major, .minor]
        case .normal:
            [.perfect, .major, .minor, .augmented, .diminished]
        case .hard:
            [.perfect, .major, .minor, .augmented, .diminished, .doubly]
        }
    }

    /// Initial draw rates. Empty families are skipped and the remaining weights are used as-is.
    private static func distribution(for difficulty: IntervalQuizDifficulty) -> [(family: IntervalWeight, weight: Int)] {
        switch difficulty {
        case .easy:
            [(.perfect, 35), (.major, 35), (.minor, 30)]
        case .normal:
            [(.perfect, 20), (.major, 25), (.minor, 25), (.augmented, 15), (.diminished, 15)]
        case .hard:
            [(.perfect, 10), (.major, 15), (.minor, 15), (.augmented, 20), (.diminished, 20), (.doubly, 20)]
        }
    }

    /// Maps a resolved quality offset onto a quiz family. Triply altered intervals are omitted.
    private static func weight(degree: Int, offset: Int) -> IntervalWeight? {
        let perfectDegrees: Set<Int> = [1, 4, 5, 8]
        if perfectDegrees.contains(degree) {
            switch offset {
            case 0:
                return .perfect
            case 1:
                return .augmented
            case -1 where degree != 1:
                return .diminished
            case 2 where degree != 8:
                return .doubly
            case -2 where degree != 1:
                return .doubly
            default:
                return nil
            }
        }

        switch offset {
        case 0:
            return .major
        case -1:
            return .minor
        case 1:
            return .augmented
        case -2:
            return .diminished
        case 2, -3:
            return .doubly
        default:
            return nil
        }
    }
}
