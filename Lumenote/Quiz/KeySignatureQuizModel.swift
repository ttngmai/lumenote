//

import Foundation

/// Difficulty chosen before a key-signature quiz session.
enum KeySignatureQuizDifficulty: String, CaseIterable, Hashable, Identifiable {
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

    /// Largest accidental count included in prompts and distractors.
    var maxAccidentals: Int {
        switch self {
        case .easy: 2
        case .normal: 5
        case .hard: 7
        }
    }
}

/// Multiple-choice quiz: match keys to key signatures (and the reverse).
@Observable
final class KeySignatureQuizModel {
    enum QuestionKind: Equatable {
        /// Given a key name, pick the correct staff among four.
        case pickStaff
        /// Given a staff (possibly blank for C / Am), pick the correct key among four.
        case pickKey
    }

    struct QuizKey: Hashable, Equatable {
        let tonic: CircleOfFifthsModel.Tonic
        let mode: CircleOfFifthsModel.MusicalMode

        var id: String { "\(tonic.rawValue)|\(mode.rawValue)" }

        var displayName: String {
            "\(tonic.displayName) \(mode.shortName)"
        }

        /// Signature index used by `CircleOfFifthsModel` (0 = no accidentals).
        var signatureIndex: Int {
            tonic.lydianSignature + mode.offset
        }
    }

    struct StaffChoice: Identifiable, Equatable {
        let id: String
        let accidentals: [CircleOfFifthsModel.KeySignatureAccidental]
        let signatureIndex: Int
    }

    struct Question: Equatable {
        let kind: QuestionKind
        let promptKey: QuizKey
        let promptAccidentals: [CircleOfFifthsModel.KeySignatureAccidental]
        /// Staff options for `.pickStaff` (exactly four).
        let staffChoices: [StaffChoice]
        /// Key-name options for `.pickKey` (exactly four).
        let keyChoices: [QuizKey]
        let correctChoiceID: String
    }

    private struct CountBucket {
        let range: ClosedRange<Int>
        let weight: Int
    }

    let difficulty: KeySignatureQuizDifficulty
    /// Number of questions in this session: 10, 20, 30, 40, or 50.
    let questionLimit: Int

    private let signatureLookup = CircleOfFifthsModel()
    private let catalog: [QuizKey]
    private var previousQuestionID: String?

    private(set) var question: Question
    private(set) var selectedChoiceID: String?
    private(set) var correctCount = 0
    private(set) var answeredCount = 0
    /// One entry per answered question, in order. `true` is a correct answer.
    private(set) var outcomes: [Bool] = []
    private(set) var isFinished = false

    var hasAnswered: Bool { selectedChoiceID != nil }

    var incorrectCount: Int { answeredCount - correctCount }

    var isSelectionCorrect: Bool {
        selectedChoiceID == question.correctChoiceID
    }

    var isOnFinalAnswer: Bool {
        hasAnswered && answeredCount >= questionLimit
    }

    init(difficulty: KeySignatureQuizDifficulty, questionLimit: Int) {
        self.difficulty = difficulty
        self.questionLimit = Self.normalizedQuestionCount(questionLimit)
        catalog = Self.buildCatalog(maxAccidentals: difficulty.maxAccidentals)
        question = Self.placeholderQuestion
        question = makeQuestion()
    }

    func select(choiceID: String) {
        guard selectedChoiceID == nil, !isFinished else { return }
        selectedChoiceID = choiceID
        answeredCount += 1
        let correct = choiceID == question.correctChoiceID
        if correct {
            correctCount += 1
        }
        outcomes.append(correct)
    }

    func nextQuestion() {
        guard hasAnswered, !isFinished, answeredCount < questionLimit else { return }
        selectedChoiceID = nil
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

    // MARK: - Generation

    private func makeQuestion() -> Question {
        for _ in 0..<80 {
            let candidate = Bool.random() ? makePickStaffQuestion() : makePickKeyQuestion()
            if let question = candidate ?? makePickStaffQuestion() ?? makePickKeyQuestion() {
                previousQuestionID = question.promptKey.id + "-\(question.kind)"
                return question
            }
        }
        let fallback = fallbackQuestion
        previousQuestionID = fallback.promptKey.id + "-\(fallback.kind)"
        return fallback
    }

    private func makePickStaffQuestion() -> Question? {
        guard let target = pickTarget() else { return nil }
        let questionID = target.id + "-pickStaff"
        if questionID == previousQuestionID { return nil }

        let indices = distractorIndices(for: target)
        guard indices.count == 3 else { return nil }

        var staffChoices: [StaffChoice] = [
            StaffChoice(
                id: target.id,
                accidentals: accidentals(for: target),
                signatureIndex: target.signatureIndex
            )
        ]
        for index in indices {
            guard let key = key(forSignature: index, preferring: target.mode, excluding: target.id) else {
                return nil
            }
            staffChoices.append(
                StaffChoice(
                    id: key.id,
                    accidentals: accidentals(for: key),
                    signatureIndex: key.signatureIndex
                )
            )
        }
        guard staffChoices.count == 4 else { return nil }

        staffChoices.shuffle()
        return Question(
            kind: .pickStaff,
            promptKey: target,
            promptAccidentals: accidentals(for: target),
            staffChoices: staffChoices,
            keyChoices: [],
            correctChoiceID: target.id
        )
    }

    private func makePickKeyQuestion() -> Question? {
        guard let target = pickTarget() else { return nil }
        let questionID = target.id + "-pickKey"
        if questionID == previousQuestionID { return nil }

        let indices = distractorIndices(for: target)
        guard indices.count == 3 else { return nil }

        var choices = [target]
        for index in indices {
            guard let key = key(forSignature: index, preferring: target.mode, excluding: target.id) else {
                return nil
            }
            choices.append(key)
        }
        guard choices.count == 4, Set(choices.map(\.id)).count == 4 else { return nil }

        return Question(
            kind: .pickKey,
            promptKey: target,
            promptAccidentals: accidentals(for: target),
            staffChoices: [],
            keyChoices: choices.shuffled(),
            correctChoiceID: target.id
        )
    }

    /// Draw an accidental-count bucket by the difficulty's weights, then a key in that bucket.
    private func pickTarget() -> QuizKey? {
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

            let range = buckets[index].range
            if let key = catalog.filter({ range.contains(abs($0.signatureIndex)) }).randomElement() {
                return key
            }
            buckets.remove(at: index)
        }

        return catalog.randomElement()
    }

    /// Three signature indices, distinct from the target, inside this difficulty's range.
    private func distractorIndices(for target: QuizKey) -> [Int] {
        let targetIndex = target.signatureIndex
        let pool = availableIndices.filter { $0 != targetIndex }.sorted()
        guard pool.count >= 3 else { return [] }

        switch difficulty {
        case .easy:
            return Array(pool.sorted { lhs, rhs in
                let leftDistance = abs(lhs - targetIndex)
                let rightDistance = abs(rhs - targetIndex)
                if leftDistance != rightDistance { return leftDistance > rightDistance }
                let leftOpposite = isOpposite(lhs, target: targetIndex)
                let rightOpposite = isOpposite(rhs, target: targetIndex)
                if leftOpposite != rightOpposite { return leftOpposite }
                return false
            }.prefix(3))

        case .normal:
            var picked: [Int] = []
            let sameSign = pool
                .filter { isSameSign($0, target: targetIndex) }
                .sorted { abs($0 - targetIndex) < abs($1 - targetIndex) }
            picked.append(contentsOf: sameSign.filter { abs($0 - targetIndex) <= 2 }.prefix(2))

            if targetIndex != 0 {
                let opposite = pool.filter { isOpposite($0, target: targetIndex) && !picked.contains($0) }
                if let best = opposite.min(by: { lhs, rhs in
                    let leftCount = abs(abs(lhs) - abs(targetIndex))
                    let rightCount = abs(abs(rhs) - abs(targetIndex))
                    if leftCount != rightCount { return leftCount < rightCount }
                    return abs(lhs - targetIndex) < abs(rhs - targetIndex)
                }) {
                    picked.append(best)
                }
            }

            return filled(picked, from: pool, target: targetIndex)

        case .hard:
            var picked: [Int] = []
            if let partner = enharmonicPartner(of: target),
               partner.signatureIndex != targetIndex,
               pool.contains(partner.signatureIndex) {
                picked.append(partner.signatureIndex)
            }
            return filled(picked, from: pool, target: targetIndex)
        }
    }

    /// Same mode and enharmonic tonic, when that key is in the current catalog.
    private func enharmonicPartner(of key: QuizKey) -> QuizKey? {
        guard let alternate = key.tonic.enharmonicAlternate else { return nil }
        return catalog.first { $0.tonic == alternate && $0.mode == key.mode }
    }

    private func filled(_ picked: [Int], from pool: [Int], target: Int) -> [Int] {
        var result = picked
        if result.count < 3 {
            let rest = pool
                .filter { !result.contains($0) }
                .sorted { abs($0 - target) < abs($1 - target) }
            result.append(contentsOf: rest.prefix(3 - result.count))
        }
        return Array(result.prefix(3))
    }

    private func key(
        forSignature index: Int,
        preferring mode: CircleOfFifthsModel.MusicalMode,
        excluding excludedID: String
    ) -> QuizKey? {
        let matches = catalog.filter { $0.signatureIndex == index && $0.id != excludedID }
        if let sameMode = matches.first(where: { $0.mode == mode }) {
            return sameMode
        }
        return matches.first
    }

    private var availableIndices: [Int] {
        Array(Set(catalog.map(\.signatureIndex)))
    }

    private func isSameSign(_ index: Int, target: Int) -> Bool {
        index != 0 && target != 0 && (index > 0) == (target > 0)
    }

    private func isOpposite(_ index: Int, target: Int) -> Bool {
        index != 0 && target != 0 && (index > 0) != (target > 0)
    }

    private func accidentals(for key: QuizKey) -> [CircleOfFifthsModel.KeySignatureAccidental] {
        signatureLookup.selectedMode = key.mode
        return signatureLookup.keySignatureAccidentals(for: key.tonic)
    }

    private var fallbackQuestion: Question {
        let target = QuizKey(tonic: .c, mode: .ionian)
        let g = QuizKey(tonic: .g, mode: .ionian)
        let f = QuizKey(tonic: .f, mode: .ionian)
        let d = QuizKey(tonic: .d, mode: .ionian)
        return Question(
            kind: .pickStaff,
            promptKey: target,
            promptAccidentals: accidentals(for: target),
            staffChoices: [target, g, f, d].map {
                StaffChoice(
                    id: $0.id,
                    accidentals: accidentals(for: $0),
                    signatureIndex: $0.signatureIndex
                )
            }.shuffled(),
            keyChoices: [],
            correctChoiceID: target.id
        )
    }

    private static var placeholderQuestion: Question {
        Question(
            kind: .pickStaff,
            promptKey: QuizKey(tonic: .c, mode: .ionian),
            promptAccidentals: [],
            staffChoices: [],
            keyChoices: [],
            correctChoiceID: "C|ionian"
        )
    }

    /// Common major / natural-minor keys whose signature count is within `maxAccidentals`.
    private static func buildCatalog(maxAccidentals: Int) -> [QuizKey] {
        let tonics = CircleOfFifthsModel.Tonic.allCases.filter { !$0.isObscure }
        let modes: [CircleOfFifthsModel.MusicalMode] = [.ionian, .aeolian]
        return tonics.flatMap { tonic in
            modes.compactMap { mode in
                let key = QuizKey(tonic: tonic, mode: mode)
                guard abs(key.signatureIndex) <= maxAccidentals else { return nil }
                return key
            }
        }
    }

    /// Initial draw rates by absolute accidental count. Empty buckets are skipped.
    private static func distribution(for difficulty: KeySignatureQuizDifficulty) -> [CountBucket] {
        switch difficulty {
        case .easy:
            [CountBucket(range: 0...1, weight: 60), CountBucket(range: 2...2, weight: 40)]
        case .normal:
            [
                CountBucket(range: 0...2, weight: 25),
                CountBucket(range: 3...4, weight: 50),
                CountBucket(range: 5...5, weight: 25),
            ]
        case .hard:
            [
                CountBucket(range: 0...2, weight: 15),
                CountBucket(range: 3...5, weight: 35),
                CountBucket(range: 6...7, weight: 50),
            ]
        }
    }
}
