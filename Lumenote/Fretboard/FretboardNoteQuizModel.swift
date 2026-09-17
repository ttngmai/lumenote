//

import Foundation

/// Quiz: a pitch class is named, and any matching fret in the visible window is correct.
@Observable
final class FretboardNoteQuizModel {
    struct Question: Equatable {
        let targetPitchClass: Int
        let accidental: AccidentalPreference
        let fretWindow: ClosedRange<Int>
    }

    private(set) var question: Question
    private(set) var selectedPosition: Fretboard.Position?

    var hasAnswered: Bool { selectedPosition != nil }

    var isSelectionCorrect: Bool {
        guard let selectedPosition else { return false }
        return Fretboard.pitchClass(at: selectedPosition) == question.targetPitchClass
    }

    var matchingPositions: [Fretboard.Position] {
        Fretboard.positions(of: question.targetPitchClass, frets: question.fretWindow)
    }

    init() {
        question = Question(
            targetPitchClass: 0,
            accidental: .sharp,
            fretWindow: 0...(Fretboard.quizWindowLength - 1)
        )
        question = makeQuestion(avoiding: nil)
    }

    var displayName: String {
        Fretboard.displayName(
            pitchClass: question.targetPitchClass,
            accidental: question.accidental
        )
    }

    func select(_ position: Fretboard.Position) {
        guard selectedPosition == nil else { return }
        guard question.fretWindow.contains(position.fret) else { return }
        selectedPosition = position
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
        let windows = Fretboard.quizFretWindows(containing: pitchClass)
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
