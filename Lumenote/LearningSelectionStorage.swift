//

import Foundation

/// Versioned JSON in UserDefaults for explorer selections.
///
/// A missing or unreadable document is replaced with the screen default.
/// A newer version than this app understands is left untouched.
enum LearningSelectionStorage {
    static func resolve<T: Codable & Equatable>(
        key: String,
        version: Int,
        fallback: T,
        sanitize: @MainActor (T) -> T,
        defaults: UserDefaults = .standard
    ) -> T {
        switch load(T.self, key: key, version: version, defaults: defaults) {
        case .absent, .unrecognizedVersion:
            return fallback
        case .corrupt:
            save(fallback, key: key, version: version, defaults: defaults)
            return fallback
        case .ready(let payload):
            let value = sanitize(payload)
            if value != payload {
                save(value, key: key, version: version, defaults: defaults)
            }
            return value
        }
    }

    static func save<T: Codable & Equatable>(
        _ payload: T,
        key: String,
        version: Int,
        defaults: UserDefaults = .standard
    ) {
        switch load(T.self, key: key, version: version, defaults: defaults) {
        case .unrecognizedVersion:
            return
        case .ready(let existing) where existing == payload:
            return
        default:
            break
        }

        let envelope = Envelope(version: version, payload: payload)
        guard let data = try? JSONEncoder().encode(envelope) else { return }
        defaults.set(data, forKey: key)
    }

    private static func load<T: Decodable>(
        _ type: T.Type,
        key: String,
        version: Int,
        defaults: UserDefaults
    ) -> LoadOutcome<T> {
        guard let data = defaults.data(forKey: key) else { return .absent }
        guard let header = try? JSONDecoder().decode(VersionHeader.self, from: data) else {
            return .corrupt
        }
        if header.version > version { return .unrecognizedVersion }
        guard header.version == version,
              let envelope = try? JSONDecoder().decode(DecodedEnvelope<T>.self, from: data)
        else { return .corrupt }
        return .ready(envelope.payload)
    }

    private struct VersionHeader: Decodable {
        var version: Int
    }

    private struct Envelope<Payload: Encodable>: Encodable {
        var version: Int
        var payload: Payload
    }

    private struct DecodedEnvelope<Payload: Decodable>: Decodable {
        var version: Int
        var payload: Payload
    }

    private enum LoadOutcome<T> {
        case absent
        case ready(T)
        case unrecognizedVersion
        case corrupt
    }
}

enum IntervalSelectionStore {
    private static let key = "intervalSelection"
    private static let version = 1

    private struct Payload: Codable, Equatable {
        var rootSpelling: String
        var targetSpelling: String
    }

    private static let fallback = Payload(rootSpelling: "C", targetSpelling: "E")

    static func load() -> (rootSpelling: String, targetSpelling: String) {
        let payload = LearningSelectionStorage.resolve(
            key: key,
            version: version,
            fallback: fallback,
            sanitize: sanitize
        )
        return (payload.rootSpelling, payload.targetSpelling)
    }

    static func save(rootSpelling: String, targetSpelling: String) {
        let payload = sanitize(Payload(rootSpelling: rootSpelling, targetSpelling: targetSpelling))
        LearningSelectionStorage.save(payload, key: key, version: version)
    }

    private static func sanitize(_ payload: Payload) -> Payload {
        Payload(
            rootSpelling: IntervalModel.isKnownSpelling(payload.rootSpelling) ? payload.rootSpelling : fallback.rootSpelling,
            targetSpelling: IntervalModel.isKnownSpelling(payload.targetSpelling) ? payload.targetSpelling : fallback.targetSpelling
        )
    }
}

enum ScaleSelectionStore {
    private static let key = "scaleSelection"
    private static let version = 1

    private struct Payload: Codable, Equatable {
        struct Card: Codable, Equatable {
            var tonicSpelling: String
            var kind: String
        }

        var cards: [Card]
    }

    private static let fallback = Payload(
        cards: [Payload.Card(tonicSpelling: "C", kind: ScaleKind.major.rawValue)]
    )

    static func loadCards() -> [ScaleCard] {
        resolve().cards.map { card in
            ScaleCard(tonicSpelling: card.tonicSpelling, kind: ScaleKind(rawValue: card.kind) ?? .major)
        }
    }

    static func save(_ cards: [ScaleCard]) {
        let payload = sanitize(Payload(cards: cards.map {
            Payload.Card(tonicSpelling: $0.tonicSpelling, kind: $0.kind.rawValue)
        }))
        LearningSelectionStorage.save(payload, key: key, version: version)
    }

    private static func resolve() -> Payload {
        LearningSelectionStorage.resolve(
            key: key,
            version: version,
            fallback: fallback,
            sanitize: sanitize
        )
    }

    private static func sanitize(_ payload: Payload) -> Payload {
        let cards = payload.cards.compactMap { card -> Payload.Card? in
            guard ScaleModel.isKnownSpelling(card.tonicSpelling),
                  ScaleKind(rawValue: card.kind) != nil
            else { return nil }
            return card
        }
        let limited = Array(cards.prefix(ScaleCard.maximumCount))
        return limited.isEmpty ? fallback : Payload(cards: limited)
    }

    private static let applyTonicToAllKey = "scaleApplyTonicToAllCards"

    /// When true, the tonic picker writes the chosen tonic onto every scale card.
    static func loadApplyTonicToAll(defaults: UserDefaults = .standard) -> Bool {
        guard defaults.object(forKey: applyTonicToAllKey) != nil else { return true }
        return defaults.bool(forKey: applyTonicToAllKey)
    }

    static func saveApplyTonicToAll(_ isOn: Bool, defaults: UserDefaults = .standard) {
        defaults.set(isOn, forKey: applyTonicToAllKey)
    }
}

enum CircleOfFifthsSelectionStore {
    private static let key = "circleOfFifthsSelection"
    private static let version = 1

    private struct Payload: Codable, Equatable {
        var tonic: String
        var mode: String
    }

    private static let fallback = Payload(
        tonic: CircleOfFifthsModel.Tonic.c.rawValue,
        mode: CircleOfFifthsModel.MusicalMode.ionian.rawValue
    )

    static func load() -> (tonic: CircleOfFifthsModel.Tonic, mode: CircleOfFifthsModel.MusicalMode) {
        let payload = LearningSelectionStorage.resolve(
            key: key,
            version: version,
            fallback: fallback,
            sanitize: sanitize
        )
        return (
            CircleOfFifthsModel.Tonic(rawValue: payload.tonic) ?? .c,
            CircleOfFifthsModel.MusicalMode(rawValue: payload.mode) ?? .ionian
        )
    }

    static func save(tonic: CircleOfFifthsModel.Tonic, mode: CircleOfFifthsModel.MusicalMode) {
        let payload = sanitize(Payload(tonic: tonic.rawValue, mode: mode.rawValue))
        LearningSelectionStorage.save(payload, key: key, version: version)
    }

    private static func sanitize(_ payload: Payload) -> Payload {
        Payload(
            tonic: CircleOfFifthsModel.Tonic(rawValue: payload.tonic)?.rawValue ?? fallback.tonic,
            mode: CircleOfFifthsModel.MusicalMode(rawValue: payload.mode)?.rawValue ?? fallback.mode
        )
    }
}

enum ChordSelectionStore {
    private static let key = "chordSelection"
    private static let version = 1

    private struct Payload: Codable, Equatable {
        struct Card: Codable, Equatable {
            var rootSpelling: String
            var kind: String
        }

        var cards: [Card]
    }

    private static let fallback = Payload(
        cards: [Payload.Card(rootSpelling: "C", kind: ChordKind.majorTriad.rawValue)]
    )

    static func loadCards() -> [ChordCard] {
        resolve().cards.map { card in
            ChordCard(rootSpelling: card.rootSpelling, kind: ChordKind(rawValue: card.kind) ?? .majorTriad)
        }
    }

    static func save(_ cards: [ChordCard]) {
        let payload = sanitize(Payload(cards: cards.map {
            Payload.Card(rootSpelling: $0.rootSpelling, kind: $0.kind.rawValue)
        }))
        LearningSelectionStorage.save(payload, key: key, version: version)
    }

    private static func resolve() -> Payload {
        LearningSelectionStorage.resolve(
            key: key,
            version: version,
            fallback: fallback,
            sanitize: sanitize
        )
    }

    private static func sanitize(_ payload: Payload) -> Payload {
        let cards = payload.cards.compactMap { card -> Payload.Card? in
            guard ScaleModel.isKnownSpelling(card.rootSpelling),
                  ChordKind(rawValue: card.kind) != nil
            else { return nil }
            return card
        }
        let limited = Array(cards.prefix(ChordCard.maximumCount))
        return limited.isEmpty ? fallback : Payload(cards: limited)
    }
}

enum DiatonicChordSelectionStore {
    private static let key = "diatonicChordSelection"
    private static let version = 1

    private struct Payload: Codable, Equatable {
        struct Card: Codable, Equatable {
            var tonicSpelling: String
            var kind: String
            var voicing: String
        }

        var cards: [Card]
    }

    private static let fallback = Payload(
        cards: [
            Payload.Card(
                tonicSpelling: "C",
                kind: ScaleKind.major.rawValue,
                voicing: DiatonicVoicing.triad.rawValue
            )
        ]
    )

    static func loadCards() -> [DiatonicChordCard] {
        resolve().cards.map { card in
            DiatonicChordCard(
                tonicSpelling: card.tonicSpelling,
                kind: ScaleKind(rawValue: card.kind) ?? .major,
                voicing: DiatonicVoicing(rawValue: card.voicing) ?? .triad
            )
        }
    }

    static func save(_ cards: [DiatonicChordCard]) {
        let payload = sanitize(Payload(cards: cards.map {
            Payload.Card(
                tonicSpelling: $0.tonicSpelling,
                kind: $0.kind.rawValue,
                voicing: $0.voicing.rawValue
            )
        }))
        LearningSelectionStorage.save(payload, key: key, version: version)
    }

    private static func resolve() -> Payload {
        LearningSelectionStorage.resolve(
            key: key,
            version: version,
            fallback: fallback,
            sanitize: sanitize
        )
    }

    private static func sanitize(_ payload: Payload) -> Payload {
        let cards = payload.cards.compactMap { card -> Payload.Card? in
            guard ScaleModel.isKnownSpelling(card.tonicSpelling),
                  ScaleKind(rawValue: card.kind) != nil
            else { return nil }
            return Payload.Card(
                tonicSpelling: card.tonicSpelling,
                kind: card.kind,
                voicing: DiatonicVoicing(rawValue: card.voicing)?.rawValue ?? DiatonicVoicing.triad.rawValue
            )
        }
        let limited = Array(cards.prefix(DiatonicChordCard.maximumCount))
        return limited.isEmpty ? fallback : Payload(cards: limited)
    }
}
