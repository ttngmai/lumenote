//

import Foundation

/// Difficulty chosen before an interval quiz session.
enum IntervalQuizDifficulty: String, CaseIterable, Hashable, Identifiable {
    case easy
    case normal
    case hard

    static let storageKey = "intervalQuizDifficulty"
    static let questionCountStorageKey = "intervalQuizQuestionCount"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .easy: "Easy"
        case .normal: "Normal"
        case .hard: "Hard"
        }
    }
}

/// Multiple-choice quiz over ascending and descending intervals.
/// One task names the interval. The other names the note reached by that interval.
@Observable
final class IntervalQuizModel {
    enum Task: Equatable {
        /// Two notes are shown. Choose the interval name.
        case identifyInterval
        /// A start note, interval, and direction are given. Choose the note reached.
        case spellTarget
    }

    struct Question: Equatable {
        let task: Task
        let rootDisplayName: String
        let targetDisplayName: String
        /// Korean interval name, such as `장3도`.
        let intervalName: String
        /// Korean direction word, `상행` or `하행`.
        let directionName: String
        let staffNotes: [IntervalStaffNote]
        let choices: [String]
        let correctAnswer: String
        let skillKey: String
    }

    /// Melodic direction on the staff. The named interval is always lower note → upper note.
    private enum IntervalDirection: Hashable {
        case ascending
        case descending
    }

    private struct Prompt {
        let root: String
        let target: String
        let direction: IntervalDirection
        let name: String
        let degree: Int
        let qualityOffset: Int
        let weight: IntervalWeight

        var skillKey: String {
            LearningSkillKey.interval(degree: degree, qualityOffset: qualityOffset)
        }
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
    /// Review sessions use the number of due skills, from 1 through 10.
    let questionLimit: Int
    private let recorder: (any LearningRecording)?
    private let focusSkillKeys: Set<String>
    private let explorer = IntervalModel()
    private let catalog: [Prompt]
    private var previousPair: (root: String, target: String, direction: IntervalDirection)?

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

    init(
        difficulty: IntervalQuizDifficulty,
        questionLimit: Int,
        recorder: (any LearningRecording)? = nil,
        focusSkillKeys: Set<String> = []
    ) {
        self.difficulty = difficulty
        self.recorder = recorder
        self.focusSkillKeys = focusSkillKeys
        self.questionLimit = focusSkillKeys.isEmpty
            ? Self.normalizedQuestionCount(questionLimit)
            : min(10, max(1, questionLimit))
        catalog = Self.makeCatalog(for: difficulty)
        question = Question(
            task: .identifyInterval,
            rootDisplayName: "C",
            targetDisplayName: "E",
            intervalName: "장3도",
            directionName: "상행",
            staffNotes: [],
            choices: [],
            correctAnswer: "장3도",
            skillKey: LearningSkillKey.interval(degree: 3, qualityOffset: 0)
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
        recorder?.record(
            LearningAttemptInput(
                topic: .interval,
                skillKey: question.skillKey,
                correct: correct,
                expected: question.correctAnswer,
                chosen: answer,
                difficulty: difficulty.rawValue
            )
        )
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
            guard let prompt = pickPrompt() else { continue }
            explorer.rootSpelling = prompt.root
            explorer.targetSpelling = prompt.target
            guard intervalName(for: prompt.direction) == prompt.name else { continue }

            let question = Bool.random()
                ? (spellQuestion(for: prompt) ?? identifyQuestion(for: prompt))
                : identifyQuestion(for: prompt)
            guard let question else { continue }
            previousPair = (prompt.root, prompt.target, prompt.direction)
            return question
        }

        return fallbackQuestion
    }

    private func identifyQuestion(for prompt: Prompt) -> Question? {
        guard let choices = makeChoices(correct: prompt) else { return nil }
        return Question(
            task: .identifyInterval,
            rootDisplayName: explorer.rootDisplayName,
            targetDisplayName: explorer.targetDisplayName,
            intervalName: prompt.name,
            directionName: directionName(for: prompt.direction),
            staffNotes: staffNotes(for: prompt.direction),
            choices: choices,
            correctAnswer: prompt.name,
            skillKey: prompt.skillKey
        )
    }

    private func spellQuestion(for prompt: Prompt) -> Question? {
        guard let choices = spellChoices(correctSpelling: prompt.target) else { return nil }
        return Question(
            task: .spellTarget,
            rootDisplayName: explorer.rootDisplayName,
            targetDisplayName: explorer.targetDisplayName,
            intervalName: prompt.name,
            directionName: directionName(for: prompt.direction),
            staffNotes: [],
            choices: choices,
            correctAnswer: explorer.targetDisplayName,
            skillKey: prompt.skillKey
        )
    }

    /// Draw an interval family by the difficulty's weights, then a spelling pair that produces it.
    private func pickPrompt() -> Prompt? {
        let pool = focusPool
        let avoidingRepeat = pool.filter { prompt in
            previousPair?.root != prompt.root
                || previousPair?.target != prompt.target
                || previousPair?.direction != prompt.direction
        }
        let source = avoidingRepeat.isEmpty ? pool : avoidingRepeat
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

    private var focusPool: [Prompt] {
        guard !focusSkillKeys.isEmpty else { return catalog }
        let matched = catalog.filter { focusSkillKeys.contains($0.skillKey) }
        return matched.isEmpty ? catalog : matched
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

    /// Four note names. Distractors stay inside this difficulty's spelling list.
    /// Easy prefers distant letters, Normal a same-letter accidental and a step neighbor,
    /// Hard the enharmonic spelling first.
    private func spellChoices(correctSpelling: String) -> [String]? {
        let correctDisplay = IntervalModel.formatNoteName(correctSpelling)
        let correctPitch = IntervalModel.pitchClass(for: correctSpelling)
        let correctLetter = correctSpelling.first
        let allowed = Self.spellings(for: difficulty, explorer: explorer)

        struct Candidate {
            let spelling: String
            let display: String
            let pitch: Int
        }

        let pool = allowed.compactMap { spelling -> Candidate? in
            let display = IntervalModel.formatNoteName(spelling)
            guard display != correctDisplay else { return nil }
            return Candidate(
                spelling: spelling,
                display: display,
                pitch: IntervalModel.pitchClass(for: spelling)
            )
        }

        func distance(_ pitch: Int) -> Int {
            let delta = abs(pitch - correctPitch)
            return min(delta, 12 - delta)
        }

        func matching(_ include: (Candidate) -> Bool) -> [String] {
            pool.filter(include).map(\.display)
        }

        let tiers: [[String]]
        switch difficulty {
        case .easy:
            tiers = [
                matching {
                    $0.spelling.first != correctLetter && $0.pitch != correctPitch && distance($0.pitch) >= 3
                },
                matching {
                    $0.spelling.first != correctLetter && $0.pitch != correctPitch && distance($0.pitch) >= 2
                },
                matching { _ in true },
            ]
        case .normal:
            tiers = [
                matching { $0.spelling.first == correctLetter && $0.pitch != correctPitch },
                matching { $0.spelling.first != correctLetter && distance($0.pitch) == 1 },
                matching { $0.pitch != correctPitch && distance($0.pitch) <= 2 },
                matching { $0.pitch != correctPitch },
                matching { _ in true },
            ]
        case .hard:
            tiers = [
                matching { $0.pitch == correctPitch },
                matching { $0.spelling.first == correctLetter && $0.pitch != correctPitch },
                matching { distance($0.pitch) == 1 },
                matching { _ in true },
            ]
        }

        let distractors = takeDisplays(tiers, excluding: correctDisplay, count: 3)
        guard distractors.count == 3, Set(distractors).count == 3 else { return nil }
        return (distractors + [correctDisplay]).shuffled()
    }

    private func takeDisplays(_ tiers: [[String]], excluding correct: String, count: Int) -> [String] {
        var unique: [String] = []
        var seen: Set<String> = [correct]
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

    private func directionName(for direction: IntervalDirection) -> String {
        switch direction {
        case .ascending: "상행"
        case .descending: "하행"
        }
    }

    private var fallbackQuestion: Question {
        explorer.rootSpelling = "C"
        explorer.targetSpelling = "E"
        previousPair = ("C", "E", .ascending)
        let prompt = Prompt(
            root: "C",
            target: "E",
            direction: .ascending,
            name: "장3도",
            degree: 3,
            qualityOffset: 0,
            weight: .major
        )
        let choices = makeChoices(correct: prompt) ?? ["장3도", "단3도", "완전4도", "완전5도"]
        return Question(
            task: .identifyInterval,
            rootDisplayName: explorer.rootDisplayName,
            targetDisplayName: explorer.targetDisplayName,
            intervalName: prompt.name,
            directionName: "상행",
            staffNotes: explorer.ascendingStaffNotes,
            choices: choices.shuffled(),
            correctAnswer: "장3도",
            skillKey: prompt.skillKey
        )
    }

    private static func makeCatalog(for difficulty: IntervalQuizDifficulty) -> [Prompt] {
        let explorer = IntervalModel()
        let spellings = spellings(for: difficulty, explorer: explorer)
        let allowed = allowedWeights(for: difficulty)
        var ascending: [Prompt] = []
        var descending: [Prompt] = []

        for root in spellings {
            for target in spellings {
                explorer.rootSpelling = root
                explorer.targetSpelling = target
                if let prompt = prompt(
                    root: root,
                    target: target,
                    direction: .ascending,
                    resolution: explorer.ascendingResolution(),
                    allowed: allowed
                ) {
                    ascending.append(prompt)
                }
                if let prompt = prompt(
                    root: root,
                    target: target,
                    direction: .descending,
                    resolution: explorer.descendingResolution(),
                    allowed: allowed
                ) {
                    descending.append(prompt)
                }
            }
        }

        // Ascending entries stay first so skill-key order matches the previous catalog.
        return ascending + descending
    }

    /// Keeps a direction only when its own lower-to-upper name is allowed at this difficulty.
    private static func prompt(
        root: String,
        target: String,
        direction: IntervalDirection,
        resolution: IntervalResolution?,
        allowed: Set<IntervalWeight>
    ) -> Prompt? {
        guard let resolution,
              let weight = weight(degree: resolution.degree, offset: resolution.qualityOffset),
              allowed.contains(weight)
        else { return nil }

        return Prompt(
            root: root,
            target: target,
            direction: direction,
            name: resolution.koreanName,
            degree: resolution.degree,
            qualityOffset: resolution.qualityOffset,
            weight: weight
        )
    }

    private func intervalName(for direction: IntervalDirection) -> String {
        switch direction {
        case .ascending:
            explorer.ascendingIntervalName
        case .descending:
            explorer.descendingIntervalName
        }
    }

    private func staffNotes(for direction: IntervalDirection) -> [IntervalStaffNote] {
        switch direction {
        case .ascending:
            explorer.ascendingStaffNotes
        case .descending:
            explorer.descendingStaffNotes
        }
    }

    static func learningSkillKeys() -> [String] {
        var seen = Set<String>()
        var keys: [String] = []
        for prompt in makeCatalog(for: .hard) {
            if seen.insert(prompt.skillKey).inserted {
                keys.append(prompt.skillKey)
            }
        }
        return keys
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
