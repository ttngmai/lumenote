//

import Foundation

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

    init() {
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
        guard selectedPosition == nil else { return }
        guard question.fretWindow.contains(position.fret) else { return }
        guard position != question.rootPosition else { return }
        selectedPosition = position
    }

    func nextQuestion() {
        let previous = question.intervalSemitones
        selectedPosition = nil
        question = makeQuestion(avoiding: previous)
    }

    private func makeQuestion(avoiding previousInterval: Int?) -> Question {
        if let question = randomQuestion(avoiding: previousInterval) {
            return question
        }
        return randomQuestion(avoiding: nil) ?? question
    }

    private func randomQuestion(avoiding previousInterval: Int?) -> Question? {
        let windows = Fretboard.quizFretWindows()
        for _ in 0..<80 {
            guard let window = windows.randomElement() else { return nil }
            let rootPosition = Fretboard.Position(
                stringIndex: Int.random(in: 0..<Fretboard.stringCount),
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
        Fretboard.quizTargetSemitones.filter { intervalSemitones in
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
