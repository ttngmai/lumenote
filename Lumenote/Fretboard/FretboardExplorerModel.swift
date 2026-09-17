//

import Foundation

/// Explorer state: visible pitch classes, marker labels, and the degree-mode root.
@Observable
final class FretboardExplorerModel {
    var labelMode: Fretboard.LabelMode = .noteName
    private(set) var rootPitchClass: Int = 0
    private(set) var visiblePitchClasses: Set<Int>

    init(
        labelMode: Fretboard.LabelMode = .noteName,
        rootPitchClass: Int = 0,
        visiblePitchClasses: Set<Int> = Set(Fretboard.pitchClasses)
    ) {
        self.labelMode = labelMode
        self.rootPitchClass = Fretboard.normalizedPitchClass(rootPitchClass)
        self.visiblePitchClasses = visiblePitchClasses
    }

    func selectRoot(_ pitchClass: Int) {
        let newRoot = Fretboard.normalizedPitchClass(pitchClass)
        guard newRoot != rootPitchClass else { return }

        if labelMode == .degree {
            let degrees = visiblePitchClasses.map { pitchClass in
                Fretboard.semitones(from: rootPitchClass, to: pitchClass)
            }
            visiblePitchClasses = Set(degrees.map { degree in
                (newRoot + degree) % 12
            })
        }

        rootPitchClass = newRoot
    }

    var areAllVisible: Bool {
        Fretboard.pitchClasses.allSatisfy { visiblePitchClasses.contains($0) }
    }

    func isVisible(_ pitchClass: Int) -> Bool {
        visiblePitchClasses.contains(pitchClass)
    }

    func toggle(_ pitchClass: Int) {
        if visiblePitchClasses.contains(pitchClass) {
            visiblePitchClasses.remove(pitchClass)
        } else {
            visiblePitchClasses.insert(pitchClass)
        }
    }

    func toggleAll() {
        if areAllVisible {
            visiblePitchClasses.removeAll()
        } else {
            visiblePitchClasses = Set(Fretboard.pitchClasses)
        }
    }
}
