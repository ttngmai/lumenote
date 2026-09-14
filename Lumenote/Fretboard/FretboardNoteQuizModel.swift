//

import Foundation

/// Quiz: a pitch class is named, and any matching fret is a correct answer.
@Observable
final class FretboardNoteQuizModel {
    struct Question: Equatable {
        let targetPitchClass: Int
    }

    private(set) var question: Question
    private(set) var selectedPosition: Fretboard.Position?
    private(set) var correctCount = 0
    private(set) var answeredCount = 0

    var hasAnswered: Bool { selectedPosition != nil }

    var isSelectionCorrect: Bool {
        guard let selectedPosition else { return false }
        return Fretboard.pitchClass(at: selectedPosition) == question.targetPitchClass
    }

    var matchingPositions: [Fretboard.Position] {
        Fretboard.positions(of: question.targetPitchClass)
    }

    init() {
        question = Question(targetPitchClass: 0)
        question = makeQuestion(avoiding: nil)
    }

    func displayName(accidental: AccidentalPreference) -> String {
        Fretboard.displayName(
            pitchClass: question.targetPitchClass,
            accidental: accidental
        )
    }

    func select(_ position: Fretboard.Position) {
        guard selectedPosition == nil else { return }
        selectedPosition = position
        answeredCount += 1
        if isSelectionCorrect {
            correctCount += 1
        }
    }

    func nextQuestion() {
        let previous = question.targetPitchClass
        selectedPosition = nil
        question = makeQuestion(avoiding: previous)
    }

    private func makeQuestion(avoiding previous: Int?) -> Question {
        var pitchClass = Int.random(in: 0..<12)
        if let previous, pitchClass == previous {
            pitchClass = (pitchClass + 1 + Int.random(in: 0..<11)) % 12
        }
        return Question(targetPitchClass: pitchClass)
    }
}
