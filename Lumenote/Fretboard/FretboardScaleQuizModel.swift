//

import Foundation

/// How many degrees a scale-position question reveals before the player answers.
enum FretboardScaleQuizDifficulty: String, CaseIterable, Hashable, Identifiable {
    case easy
    case normal
    case hard

    static let storageKey = "fretboardScaleQuizDifficulty"
    static let questionCountStorageKey = "fretboardScaleQuizQuestionCount"
    static let scalesStorageKey = "fretboardScaleQuizScales"
    static let systemsStorageKey = "fretboardScaleQuizSystems"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .easy: "Easy"
        case .normal: "Normal"
        case .hard: "Hard"
        }
    }

    var detail: String {
        switch self {
        case .easy: "1도와 일부 도수를 보여 줍니다.".l10n
        case .normal: "1도만 보여 줍니다.".l10n
        case .hard: "빈 지판에서 포지션을 완성합니다.".l10n
        }
    }
}

/// Labels for one scale-position question. Grading uses these cells, not pitch class.
struct FretboardScaleQuizMarks: Equatable {
    var hints: Set<Fretboard.Position>
    var answers: Set<Fretboard.Position>
    var labels: [Fretboard.Position: String]
    var accessibilityLabels: [Fretboard.Position: String]
    var hintSwatches: [Fretboard.Position: Int]
}

/// Skill key for one movable form: scale, system, and CAGED letter or 3NPS number.
enum FretboardScaleQuizSkill {
    struct Parts: Equatable {
        var kind: ScaleKind
        var system: FretboardScaleFormSystem
        var token: String
    }

    static let catalog: [String] = ScaleKind.allCases.flatMap { kind in
        FretboardScaleForms.systems(for: kind).flatMap { system in
            FretboardScaleForms.positions(tonicPitchClass: 0, kind: kind, system: system).map { position in
                key(kind: kind, system: system, position: position)
            }
        }
    }

    static func key(
        kind: ScaleKind,
        system: FretboardScaleFormSystem,
        position: FretboardScaleFormPosition
    ) -> String {
        "\(kind.rawValue)|\(system.rawValue)|\(token(for: position))"
    }

    static func token(for position: FretboardScaleFormPosition) -> String {
        position.shapeLetter ?? String(position.index + 1)
    }

    static func parse(_ key: String) -> Parts? {
        let parts = key.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3,
              let kind = ScaleKind(rawValue: parts[0]),
              let system = FretboardScaleFormSystem(rawValue: parts[1]),
              !parts[2].isEmpty
        else { return nil }
        return Parts(kind: kind, system: system, token: parts[2])
    }

    static func title(for key: String) -> String {
        guard let parts = parse(key) else { return key }
        let positionTitle: String
        if parts.system == .caged {
            positionTitle = L10n.s("\(parts.token) 포지션")
        } else if let number = Int(parts.token) {
            positionTitle = L10n.s("\(number)포지션")
        } else {
            positionTitle = parts.token
        }
        return "\(parts.kind.englishTitle) · \(parts.system.title) · \(positionTitle)"
    }

    static func hasQuestions(
        scales: Set<ScaleKind>,
        systems: Set<FretboardScaleFormSystem>
    ) -> Bool {
        !keys(scales: scales, systems: systems).isEmpty
    }

    static func systemIsAvailable(
        _ system: FretboardScaleFormSystem,
        scales: Set<ScaleKind>
    ) -> Bool {
        scales.contains { FretboardScaleForms.systems(for: $0).contains(system) }
    }

    static func keys(
        scales: Set<ScaleKind>,
        systems: Set<FretboardScaleFormSystem>
    ) -> [String] {
        catalog.filter { key in
            guard let parts = parse(key) else { return false }
            return scales.contains(parts.kind) && systems.contains(parts.system)
        }
    }

    static func scales(from raw: String) -> Set<ScaleKind> {
        Set(raw.split(separator: ",").compactMap { ScaleKind(rawValue: String($0)) })
    }

    static func systems(from raw: String) -> Set<FretboardScaleFormSystem> {
        Set(raw.split(separator: ",").compactMap { FretboardScaleFormSystem(rawValue: String($0)) })
    }

    static func rawScales(_ scales: Set<ScaleKind>) -> String {
        scales.map(\.rawValue).sorted().joined(separator: ",")
    }

    static func rawSystems(_ systems: Set<FretboardScaleFormSystem>) -> String {
        systems.map(\.rawValue).sorted().joined(separator: ",")
    }
}

/// Quiz: fill every cell of one CAGED or 3NPS form, then check.
@Observable
final class FretboardScaleQuizModel {
    struct Question: Equatable {
        let tonicSpelling: String
        let tonicPitchClass: Int
        let kind: ScaleKind
        let system: FretboardScaleFormSystem
        let position: FretboardScaleFormPosition
        let skillKey: String
        let accidental: AccidentalPreference
        let marks: FretboardScaleQuizMarks

        var promptTitle: String {
            "\(ScaleModel.formatNoteName(tonicSpelling)) \(kind.englishTitle)"
        }

        var expectedRecord: String {
            "\(promptTitle) · \(position.title)"
        }
    }

    let difficulty: FretboardScaleQuizDifficulty
    let questionLimit: Int
    let scales: Set<ScaleKind>
    let systems: Set<FretboardScaleFormSystem>
    private let recorder: (any LearningRecording)?
    private let focusSkillKeys: Set<String>

    private(set) var question: Question
    private(set) var selectedPositions: Set<Fretboard.Position> = []
    private(set) var hasAnswered = false
    private(set) var correctCount = 0
    private(set) var answeredCount = 0
    private(set) var outcomes: [Bool] = []
    private(set) var isFinished = false

    var incorrectCount: Int { answeredCount - correctCount }

    var placedCount: Int { question.marks.hints.count + selectedPositions.count }

    var answerCount: Int { question.marks.answers.count }

    var isOnFinalAnswer: Bool {
        hasAnswered && answeredCount >= questionLimit
    }

    var instruction: String {
        switch difficulty {
        case .easy:
            "표시된 도수를 참고하여 포지션을 완성하세요.".l10n
        case .normal, .hard:
            "스케일 포지션을 완성하세요.".l10n
        }
    }

    init(
        difficulty: FretboardScaleQuizDifficulty,
        questionLimit: Int,
        scales: Set<ScaleKind> = Set(ScaleKind.allCases),
        systems: Set<FretboardScaleFormSystem> = Set(FretboardScaleFormSystem.allCases),
        recorder: (any LearningRecording)? = nil,
        focusSkillKeys: Set<String> = []
    ) {
        self.difficulty = difficulty
        self.questionLimit = focusSkillKeys.isEmpty
            ? Self.normalizedQuestionCount(questionLimit)
            : min(10, max(1, questionLimit))
        self.scales = scales
        self.systems = systems
        self.recorder = recorder
        self.focusSkillKeys = focusSkillKeys
        question = Self.placeholder
        question = makeQuestion(avoiding: nil) ?? question
    }

    func toggle(_ position: Fretboard.Position) {
        guard !hasAnswered, !isFinished else { return }
        guard question.position.fretRange.contains(position.fret) else { return }
        guard !question.marks.hints.contains(position) else { return }
        if selectedPositions.contains(position) {
            selectedPositions.remove(position)
        } else {
            selectedPositions.insert(position)
        }
    }

    func confirm() {
        guard !hasAnswered, !isFinished else { return }
        guard !question.marks.answers.isEmpty else { return }
        let remaining = question.marks.answers.subtracting(question.marks.hints)
        complete(isCorrect: selectedPositions == remaining)
    }

    func nextQuestion() {
        guard hasAnswered, !isFinished, answeredCount < questionLimit else { return }
        let previous = question.skillKey
        selectedPositions = []
        hasAnswered = false
        question = makeQuestion(avoiding: previous) ?? question
    }

    func finish() {
        guard isOnFinalAnswer else { return }
        isFinished = true
    }

    static func normalizedQuestionCount(_ count: Int) -> Int {
        let stepped = (count / 10) * 10
        return min(50, max(10, stepped))
    }

    private func makeQuestion(avoiding previousKey: String?) -> Question? {
        let keys = candidateKeys()
        let preferred = keys.filter { $0 != previousKey }
        let pool = preferred.isEmpty ? keys : preferred
        let tonics = ScaleModel.selectableNotes.map(\.spelling).shuffled()
        for key in pool.shuffled() {
            for spelling in tonics {
                if let question = makeQuestion(skillKey: key, tonicSpelling: spelling) {
                    return question
                }
            }
        }
        return nil
    }

    private func candidateKeys() -> [String] {
        if !focusSkillKeys.isEmpty {
            return Array(focusSkillKeys)
        }
        return FretboardScaleQuizSkill.keys(scales: scales, systems: systems)
    }

    private func makeQuestion(skillKey: String, tonicSpelling: String) -> Question? {
        guard let parts = FretboardScaleQuizSkill.parse(skillKey) else { return nil }
        guard ScaleModel.isKnownSpelling(tonicSpelling) else { return nil }
        let tonicPitchClass = ScaleModel.pitchClass(for: tonicSpelling)
        let positions = FretboardScaleForms.positions(
            tonicPitchClass: tonicPitchClass,
            kind: parts.kind,
            system: parts.system
        )
        guard let position = positions.first(where: {
            FretboardScaleQuizSkill.token(for: $0) == parts.token
        }) else { return nil }

        let answers = Set(position.notes)
        let hints = hintPositions(in: answers, tonicPitchClass: tonicPitchClass)
        let accidental: AccidentalPreference = tonicSpelling.contains("b") ? .flat : .sharp
        let degrees = degreeLabels(tonicSpelling: tonicSpelling, kind: parts.kind)
        var labels: [Fretboard.Position: String] = [:]
        var accessibilityLabels: [Fretboard.Position: String] = [:]
        var hintSwatches: [Fretboard.Position: Int] = [:]
        for stringIndex in 0..<Fretboard.stringCount {
            for fret in position.fretRange {
                let cell = Fretboard.Position(stringIndex: stringIndex, fret: fret)
                let pitchClass = Fretboard.pitchClass(at: cell)
                let label = degrees[pitchClass] ?? Fretboard.degreeLabel(
                    pitchClass: pitchClass,
                    rootPitchClass: tonicPitchClass,
                    accidental: accidental
                )
                labels[cell] = label
                accessibilityLabels[cell] = Self.spokenDegreeKey(label).l10n
                if hints.contains(cell) {
                    hintSwatches[cell] = Fretboard.semitones(from: tonicPitchClass, to: pitchClass)
                }
            }
        }

        return Question(
            tonicSpelling: tonicSpelling,
            tonicPitchClass: tonicPitchClass,
            kind: parts.kind,
            system: parts.system,
            position: position,
            skillKey: skillKey,
            accidental: accidental,
            marks: FretboardScaleQuizMarks(
                hints: hints,
                answers: answers,
                labels: labels,
                accessibilityLabels: accessibilityLabels,
                hintSwatches: hintSwatches
            )
        )
    }

    /// Easy shows every root plus enough other scale tones to reach about 45% of the form.
    private func hintPositions(
        in answers: Set<Fretboard.Position>,
        tonicPitchClass: Int
    ) -> Set<Fretboard.Position> {
        let roots = answers.filter { Fretboard.pitchClass(at: $0) == tonicPitchClass }
        switch difficulty {
        case .hard:
            return []
        case .normal:
            return roots
        case .easy:
            var goal = Int((Double(answers.count) * 0.45).rounded())
            goal = max(goal, roots.count)
            if goal >= answers.count, answers.count > roots.count {
                goal = answers.count - 1
            }
            var hints = roots
            let extras = answers.subtracting(roots).shuffled()
            let needed = max(0, goal - hints.count)
            hints.formUnion(extras.prefix(needed))
            return hints
        }
    }

    private func degreeLabels(tonicSpelling: String, kind: ScaleKind) -> [Int: String] {
        let spellings = ScaleModel.spellings(tonic: tonicSpelling, kind: kind)
        let degrees = kind.degreeLabels
        let count = min(spellings.count, degrees.count)
        guard count > 1 else { return [:] }
        var labels: [Int: String] = [:]
        for index in 0..<(count - 1) {
            let pitchClass = ScaleModel.pitchClass(for: spellings[index])
            labels[pitchClass] = degrees[index]
        }
        return labels
    }

    private func complete(isCorrect: Bool) {
        hasAnswered = true
        answeredCount += 1
        if isCorrect {
            correctCount += 1
        }
        outcomes.append(isCorrect)
        recorder?.record(
            LearningAttemptInput(
                topic: .fretboardScale,
                skillKey: question.skillKey,
                correct: isCorrect,
                expected: question.expectedRecord,
                chosen: "\(placedCount)/\(answerCount)",
                difficulty: difficulty.rawValue
            )
        )
    }

    private static let placeholder = Question(
        tonicSpelling: "C",
        tonicPitchClass: 0,
        kind: .major,
        system: .caged,
        position: FretboardScaleFormPosition(index: 0, shapeLetter: "C", notes: []),
        skillKey: "major|caged|C",
        accidental: .sharp,
        marks: FretboardScaleQuizMarks(
            hints: [],
            answers: [],
            labels: [:],
            accessibilityLabels: [:],
            hintSwatches: [:]
        )
    )

    /// "♭3" → "플랫 3도". Scale formulas in this app only use single sharps and flats.
    private static func spokenDegreeKey(_ label: String) -> String {
        let prefix: String
        let number: String
        if label.hasPrefix("𝄫") {
            prefix = "더블플랫 "
            number = String(label.dropFirst())
        } else if label.hasPrefix("♭") {
            prefix = "플랫 "
            number = String(label.dropFirst())
        } else if label.hasPrefix("𝄪") {
            prefix = "더블샵 "
            number = String(label.dropFirst())
        } else if label.hasPrefix("♯") {
            prefix = "샵 "
            number = String(label.dropFirst())
        } else {
            prefix = ""
            number = label
        }
        return "\(prefix)\(number)도"
    }
}
