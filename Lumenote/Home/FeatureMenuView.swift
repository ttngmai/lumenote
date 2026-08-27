//

import SwiftUI

/// Root feature list grouped into tools and quizzes.
struct FeatureMenuView: View {
    @Environment(\.appPalette) private var palette
    @AppStorage(AppearanceMode.storageKey) private var appearance: AppearanceMode = .system

    private enum Destination: Hashable {
        case circleOfFifths
        case interval
        case scale
        case chord
        case intervalQuiz
        case keySignatureQuiz
        case scaleQuiz
    }

    var body: some View {
        List {
            Section("도구") {
                NavigationLink(value: Destination.interval) {
                    featureRow(
                        title: "음정",
                        subtitle: "두 음 사이의 거리",
                        systemImage: "ruler"
                    )
                }

                NavigationLink(value: Destination.scale) {
                    featureRow(
                        title: "음계",
                        subtitle: "일정한 음정 규칙에 따라 배열된 음들의 체계",
                        systemImage: "music.quarternote.3"
                    )
                }

                NavigationLink(value: Destination.chord) {
                    featureRow(
                        title: "화음",
                        subtitle: "3화음 · 7화음의 구성과 표기",
                        systemImage: "music.note.list"
                    )
                }

                NavigationLink(value: Destination.circleOfFifths) {
                    featureRow(
                        title: "5도권",
                        subtitle: "키 · 조표 · 관계조",
                        systemImage: "circle.circle"
                    )
                }
            }

            Section("퀴즈") {
                NavigationLink(value: Destination.intervalQuiz) {
                    featureRow(
                        title: "음정 퀴즈",
                        subtitle: "두 음의 음정을 맞춰 보세요",
                        systemImage: "ruler"
                    )
                }

                NavigationLink(value: Destination.scaleQuiz) {
                    featureRow(
                        title: "음계 퀴즈",
                        subtitle: "구성음 · 패턴 · 도수를 맞춰 보세요",
                        systemImage: "music.quarternote.3"
                    )
                }

                NavigationLink(value: Destination.keySignatureQuiz) {
                    featureRow(
                        title: "키 · 조표 퀴즈",
                        subtitle: "키와 조표를 맞춰 보세요",
                        glyph: "♯"
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(background)
        .lumenoteCompactHeader(title: "Lumenote") {
            AppearanceToggleButton(appearance: $appearance)
        }
        .navigationDestination(for: Destination.self) { destination in
            switch destination {
            case .circleOfFifths:
                CircleOfFifthsView()
            case .interval:
                IntervalView()
            case .scale:
                ScaleView()
            case .chord:
                ChordView()
            case .intervalQuiz:
                IntervalQuizView()
            case .keySignatureQuiz:
                KeySignatureQuizView()
            case .scaleQuiz:
                ScaleQuizView()
            }
        }
    }

    private func featureRow(title: String, subtitle: String, systemImage: String) -> some View {
        featureRow(title: title, subtitle: subtitle) {
            Image(systemName: systemImage)
                .font(LumenoteFont.rounded(size: 22, weight: .semibold))
        }
    }

    /// Uses a music-glyph label (e.g. ♯) when no matching SF Symbol exists.
    private func featureRow(title: String, subtitle: String, glyph: String) -> some View {
        featureRow(title: title, subtitle: subtitle) {
            Text(glyph)
                .font(LumenoteFont.rounded(size: 26, weight: .semibold))
        }
    }

    private func featureRow<Icon: View>(
        title: String,
        subtitle: String,
        @ViewBuilder icon: () -> Icon
    ) -> some View {
        HStack(spacing: LumenoteSpacing.xxl) {
            icon()
                .foregroundStyle(.primary)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: LumenoteSpacing.xxs) {
                Text(title)
                    .font(LumenoteFont.body(.bold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(LumenoteFont.caption(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, LumenoteSpacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(subtitle)")
    }

    private var background: some View {
        LinearGradient(
            colors: palette.backgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

#Preview {
    NavigationStack {
        FeatureMenuView()
    }
    .lumenotePalette()
}
