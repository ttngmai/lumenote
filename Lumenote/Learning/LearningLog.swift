//

import Foundation
import SwiftData
import SwiftUI

@Model
final class LearningAttemptRecord {
    var topicRaw: String
    var skillKey: String
    var correct: Bool
    var expected: String
    var chosen: String
    var difficulty: String
    var createdAt: Date

    init(
        topicRaw: String,
        skillKey: String,
        correct: Bool,
        expected: String,
        chosen: String,
        difficulty: String,
        createdAt: Date
    ) {
        self.topicRaw = topicRaw
        self.skillKey = skillKey
        self.correct = correct
        self.expected = expected
        self.chosen = chosen
        self.difficulty = difficulty
        self.createdAt = createdAt
    }
}

@MainActor
@Observable
final class LearningLog: LearningRecording {
    private let context: ModelContext
    /// Bumped after each save so screens recompute standing from the store.
    private(set) var revision = 0

    init(context: ModelContext) {
        self.context = context
    }

    func record(_ attempt: LearningAttemptInput) {
        let record = LearningAttemptRecord(
            topicRaw: attempt.topic.rawValue,
            skillKey: attempt.skillKey,
            correct: attempt.correct,
            expected: attempt.expected,
            chosen: attempt.chosen,
            difficulty: attempt.difficulty,
            createdAt: Date()
        )
        context.insert(record)
        try? context.save()
        revision += 1
    }

    func snapshot() -> LearningSnapshot {
        _ = revision
        let descriptor = FetchDescriptor<LearningAttemptRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        let records = (try? context.fetch(descriptor)) ?? []
        let attempts = records.map { record in
            (
                topicRaw: record.topicRaw,
                attempt: LearningProgressMath.Attempt(
                    skillKey: record.skillKey,
                    correct: record.correct,
                    expected: record.expected,
                    chosen: record.chosen,
                    createdAt: record.createdAt
                )
            )
        }
        return LearningProgressMath.snapshot(records: attempts)
    }
}

extension EnvironmentValues {
    @Entry var learningLog: LearningLog? = nil
}

enum LearningStore {
    static func makeContainer() -> ModelContainer {
        if let container = try? ModelContainer(for: LearningAttemptRecord.self) {
            return container
        }
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(
            for: LearningAttemptRecord.self,
            configurations: configuration
        )
    }
}
