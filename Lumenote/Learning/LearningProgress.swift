//

import Foundation

/// One answered question, before it is stored.
struct LearningAttemptInput {
    var topic: LearningTopic
    var skillKey: String
    var correct: Bool
    var expected: String
    var chosen: String
    var difficulty: String
}

protocol LearningRecording: AnyObject {
    func record(_ attempt: LearningAttemptInput)
}

enum SkillStanding: CaseIterable, Hashable, Identifiable {
    case unseen
    case learning
    case shaky
    case solid

    var id: Self { self }

    var title: String {
        switch self {
        case .unseen: "아직 안 봄".l10n
        case .learning: "학습 중".l10n
        case .shaky: "불안정".l10n
        case .solid: "안정".l10n
        }
    }
}

struct SkillProgress: Identifiable, Hashable {
    var topic: LearningTopic
    var skillKey: String
    var title: String
    var standing: SkillStanding
    var isDue: Bool
    var lastMissExpected: String
    var lastMissChosen: String
    var lastMissAt: Date

    var id: String { "\(topic.rawValue)|\(skillKey)" }
}

struct TopicProgress: Identifiable, Hashable {
    var topic: LearningTopic
    var unseen: Int
    var learning: Int
    var shaky: Int
    var solid: Int
    var due: [SkillProgress]

    var id: LearningTopic { topic }

    var hasAttempts: Bool {
        learning + shaky + solid > 0
    }
}

struct LearningSnapshot {
    var topics: [TopicProgress]
    var dueCount: Int
    var attemptCount: Int

    static let empty = LearningSnapshot(topics: [], dueCount: 0, attemptCount: 0)

    func topics(in domain: FeatureDomain) -> [TopicProgress] {
        topics.filter { $0.topic.domain == domain }
    }

    func progress(for topic: LearningTopic) -> TopicProgress {
        topics.first { $0.topic == topic }
            ?? TopicProgress(topic: topic, unseen: 0, learning: 0, shaky: 0, solid: 0, due: [])
    }
}

enum LearningProgressMath {
    /// Standing uses this many most recent attempts so early misses do not stay forever.
    static let recentWindow = 10
    /// Consecutive correct answers that leave the review queue.
    static let graduateStreak = 3

    struct Attempt {
        var skillKey: String
        var correct: Bool
        var expected: String
        var chosen: String
        var createdAt: Date
    }

    static func snapshot(
        records: [(topicRaw: String, attempt: Attempt)]
    ) -> LearningSnapshot {
        var attemptsByTopic: [LearningTopic: [String: [Attempt]]] = [:]
        for topic in LearningTopic.allCases {
            attemptsByTopic[topic] = [:]
        }
        for record in records {
            guard let topic = LearningTopic(rawValue: record.topicRaw) else { continue }
            attemptsByTopic[topic, default: [:]][record.attempt.skillKey, default: []].append(record.attempt)
        }

        let topics = LearningTopic.allCases.map { topic in
            topicProgress(topic, attempts: attemptsByTopic[topic] ?? [:])
        }
        return LearningSnapshot(
            topics: topics,
            dueCount: topics.reduce(0) { $0 + $1.due.count },
            attemptCount: records.count
        )
    }

    static func evaluate(correctFlags: [Bool]) -> (standing: SkillStanding, isDue: Bool) {
        let recent = Array(correctFlags.suffix(recentWindow))
        if recent.isEmpty {
            return (.unseen, false)
        }

        var streak = 0
        for flag in recent.reversed() {
            if flag {
                streak += 1
            } else {
                break
            }
        }

        let standing: SkillStanding
        if streak >= graduateStreak {
            standing = .solid
        } else if recent.last == false, recent.dropLast().contains(true) {
            standing = .shaky
        } else {
            standing = .learning
        }

        let isDue = recent.contains(false) && streak < graduateStreak
        return (standing, isDue)
    }

    private static func topicProgress(
        _ topic: LearningTopic,
        attempts: [String: [Attempt]]
    ) -> TopicProgress {
        var unseen = 0
        var learning = 0
        var shaky = 0
        var solid = 0
        var due: [SkillProgress] = []
        var seen = Set<String>()

        for key in LearningSkillCatalog.keys(for: topic) {
            seen.insert(key)
            let skillAttempts = attempts[key] ?? []
            let evaluated = evaluate(correctFlags: skillAttempts.map(\.correct))
            count(evaluated.standing, unseen: &unseen, learning: &learning, shaky: &shaky, solid: &solid)
            if evaluated.isDue, let progress = dueProgress(topic: topic, key: key, attempts: skillAttempts) {
                due.append(progress)
            }
        }

        for (key, skillAttempts) in attempts where !seen.contains(key) {
            let evaluated = evaluate(correctFlags: skillAttempts.map(\.correct))
            count(evaluated.standing, unseen: &unseen, learning: &learning, shaky: &shaky, solid: &solid)
            if evaluated.isDue, let progress = dueProgress(topic: topic, key: key, attempts: skillAttempts) {
                due.append(progress)
            }
        }

        due.sort { $0.lastMissAt > $1.lastMissAt }
        return TopicProgress(
            topic: topic,
            unseen: unseen,
            learning: learning,
            shaky: shaky,
            solid: solid,
            due: due
        )
    }

    private static func count(
        _ standing: SkillStanding,
        unseen: inout Int,
        learning: inout Int,
        shaky: inout Int,
        solid: inout Int
    ) {
        switch standing {
        case .unseen: unseen += 1
        case .learning: learning += 1
        case .shaky: shaky += 1
        case .solid: solid += 1
        }
    }

    private static func dueProgress(
        topic: LearningTopic,
        key: String,
        attempts: [Attempt]
    ) -> SkillProgress? {
        guard let miss = attempts.last(where: { !$0.correct }) else { return nil }
        let standing = evaluate(correctFlags: attempts.map(\.correct)).standing
        return SkillProgress(
            topic: topic,
            skillKey: key,
            title: LearningSkillTitle.title(topic: topic, key: key),
            standing: standing,
            isDue: true,
            lastMissExpected: miss.expected,
            lastMissChosen: miss.chosen,
            lastMissAt: miss.createdAt
        )
    }
}
