//

import Foundation

/// Toggle which pitch classes are drawn on the fretboard explorer.
@Observable
final class FretboardExplorerModel {
    private(set) var visiblePitchClasses: Set<Int>

    init(visiblePitchClasses: Set<Int> = Set(Fretboard.pitchClasses)) {
        self.visiblePitchClasses = visiblePitchClasses
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
}
