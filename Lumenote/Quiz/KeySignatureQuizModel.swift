//

import Foundation

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

    private let signatureLookup = CircleOfFifthsModel()
    private let catalog: [QuizKey]
    private var previousQuestionID: String?

    private(set) var question: Question
    private(set) var selectedChoiceID: String?
    private(set) var correctCount = 0
    private(set) var answeredCount = 0

    var hasAnswered: Bool { selectedChoiceID != nil }

    var isSelectionCorrect: Bool {
        selectedChoiceID == question.correctChoiceID
    }

    init() {
        catalog = Self.buildCatalog()
        question = Self.placeholderQuestion
        question = makeQuestion()
    }

    func select(choiceID: String) {
        guard selectedChoiceID == nil else { return }
        selectedChoiceID = choiceID
        answeredCount += 1
        if choiceID == question.correctChoiceID {
            correctCount += 1
        }
    }

    func nextQuestion() {
        selectedChoiceID = nil
        question = makeQuestion()
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
        return fallbackQuestion
    }

    private func makePickStaffQuestion() -> Question? {
        guard let target = catalog.randomElement() else { return nil }
        let questionID = target.id + "-pickStaff"
        if questionID == previousQuestionID { return nil }

        let targetAccidentals = accidentals(for: target)
        let distractors = catalog
            .filter { $0.signatureIndex != target.signatureIndex }
            .shuffled()

        var staffChoices: [StaffChoice] = [
            StaffChoice(
                id: target.id,
                accidentals: targetAccidentals,
                signatureIndex: target.signatureIndex
            )
        ]
        var usedIndices: Set<Int> = [target.signatureIndex]

        for candidate in distractors {
            guard usedIndices.insert(candidate.signatureIndex).inserted else { continue }
            staffChoices.append(
                StaffChoice(
                    id: candidate.id,
                    accidentals: accidentals(for: candidate),
                    signatureIndex: candidate.signatureIndex
                )
            )
            if staffChoices.count == 4 { break }
        }
        guard staffChoices.count == 4 else { return nil }

        staffChoices.shuffle()
        return Question(
            kind: .pickStaff,
            promptKey: target,
            promptAccidentals: targetAccidentals,
            staffChoices: staffChoices,
            keyChoices: [],
            correctChoiceID: target.id
        )
    }

    private func makePickKeyQuestion() -> Question? {
        guard let target = catalog.randomElement() else { return nil }
        let questionID = target.id + "-pickKey"
        if questionID == previousQuestionID { return nil }

        let sameSignature = Set(
            catalog
                .filter { $0.signatureIndex == target.signatureIndex }
                .map(\.id)
        )

        let distractors = catalog
            .filter { !sameSignature.contains($0.id) }
            .shuffled()
            .prefix(3)
        guard distractors.count == 3 else { return nil }

        let choices = (Array(distractors) + [target]).shuffled()
        return Question(
            kind: .pickKey,
            promptKey: target,
            promptAccidentals: accidentals(for: target),
            staffChoices: [],
            keyChoices: choices,
            correctChoiceID: target.id
        )
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

    /// Common major / natural-minor keys with at most seven sharps or flats.
    private static func buildCatalog() -> [QuizKey] {
        let tonics = CircleOfFifthsModel.Tonic.allCases.filter { !$0.isObscure }
        let modes: [CircleOfFifthsModel.MusicalMode] = [.ionian, .aeolian]
        return tonics.flatMap { tonic in
            modes.compactMap { mode in
                let key = QuizKey(tonic: tonic, mode: mode)
                guard abs(key.signatureIndex) <= 7 else { return nil }
                return key
            }
        }
    }
}
