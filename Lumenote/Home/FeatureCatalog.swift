//

import Foundation

/// Top-level subject area in the home menu.
enum FeatureDomain: String, CaseIterable, Hashable, Identifiable {
    case harmony
    case guitar

    var id: String { rawValue }

    var title: String {
        switch self {
        case .harmony: "화성학"
        case .guitar: "기타"
        }
    }

    var subtitle: String {
        switch self {
        case .harmony: "음정 · 음계 · 조표 · 화음"
        case .guitar: "지판과 주법"
        }
    }

    var systemImage: String {
        switch self {
        case .harmony: "music.note"
        case .guitar: "guitars"
        }
    }
}

/// Learn vs quiz grouping under a domain.
enum FeatureMode: String, CaseIterable, Hashable, Identifiable {
    case learn
    case quiz

    var id: String { rawValue }

    var title: String {
        switch self {
        case .learn: "학습"
        case .quiz: "퀴즈"
        }
    }

    var subtitle: String {
        switch self {
        case .learn: "개념과 구성을 살펴보세요"
        case .quiz: "문제를 풀어 보세요"
        }
    }

    var systemImage: String {
        switch self {
        case .learn: "book"
        case .quiz: "questionmark.circle"
        }
    }
}

/// A domain paired with learn or quiz, used as a navigation route.
struct FeatureCategory: Hashable, Identifiable {
    let domain: FeatureDomain
    let mode: FeatureMode

    var id: String { "\(domain.rawValue)-\(mode.rawValue)" }
    var title: String { mode.title }
}

/// Leaf screen reached from a feature list.
enum FeatureDestination: Hashable {
    case interval
    case scale
    case circleOfFifths
    case chord
    case intervalQuiz
    case scaleQuiz
    case keySignatureQuiz
    case chordQuiz
    case fretboardNoteNames
    case fretboardDegrees
    case fretboardExplorer
}

enum FeatureIcon: Hashable {
    case system(String)
    case glyph(String)
}

struct FeatureItem: Identifiable, Hashable {
    let destination: FeatureDestination
    let title: String
    let subtitle: String
    let icon: FeatureIcon

    var id: FeatureDestination { destination }
}

/// Entries shown for each domain and mode. Add new features here.
enum FeatureCatalog {
    static func items(in domain: FeatureDomain, mode: FeatureMode) -> [FeatureItem] {
        switch (domain, mode) {
        case (.harmony, .learn):
            [
                FeatureItem(
                    destination: .interval,
                    title: "음정",
                    subtitle: "두 음 사이의 거리",
                    icon: .system("ruler")
                ),
                FeatureItem(
                    destination: .scale,
                    title: "음계",
                    subtitle: "일정한 음정 규칙에 따라 배열된 음들의 체계",
                    icon: .system("music.quarternote.3")
                ),
                FeatureItem(
                    destination: .circleOfFifths,
                    title: "5도권",
                    subtitle: "키 · 조표 · 관계조",
                    icon: .system("circle.circle")
                ),
                FeatureItem(
                    destination: .chord,
                    title: "화음",
                    subtitle: "Triad, 7th 코드의 구성과 표기",
                    icon: .system("music.note.list")
                ),
            ]
        case (.harmony, .quiz):
            [
                FeatureItem(
                    destination: .intervalQuiz,
                    title: "음정 퀴즈",
                    subtitle: "두 음의 음정을 맞춰 보세요",
                    icon: .system("ruler")
                ),
                FeatureItem(
                    destination: .scaleQuiz,
                    title: "음계 퀴즈",
                    subtitle: "구성음 · 패턴 · 도수를 맞춰 보세요",
                    icon: .system("music.quarternote.3")
                ),
                FeatureItem(
                    destination: .keySignatureQuiz,
                    title: "키 · 조표 퀴즈",
                    subtitle: "키와 조표를 맞춰 보세요",
                    icon: .glyph("♯")
                ),
                FeatureItem(
                    destination: .chordQuiz,
                    title: "화음 퀴즈",
                    subtitle: "구성음 · 공식 · 표기를 맞춰 보세요",
                    icon: .system("music.note.list")
                ),
            ]
        case (.guitar, .learn):
            [
                FeatureItem(
                    destination: .fretboardExplorer,
                    title: "지판 보기",
                    subtitle: "음이름과 도수로 지판 위치를 살펴보세요",
                    icon: .system("guitars")
                ),
            ]
        case (.guitar, .quiz):
            [
                FeatureItem(
                    destination: .fretboardNoteNames,
                    title: "지판 퀴즈 (음이름)",
                    subtitle: "지판에서 음의 위치를 찾아 보세요",
                    icon: .system("guitars")
                ),
                FeatureItem(
                    destination: .fretboardDegrees,
                    title: "지판 퀴즈 (도수)",
                    subtitle: "1도를 기준으로 도수의 위치를 찾아 보세요",
                    icon: .system("guitars")
                ),
            ]
        }
    }
}
