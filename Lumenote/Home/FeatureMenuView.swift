//

import SwiftUI

/// Root menu: pick a domain, then learn or quiz, then a feature.
struct FeatureMenuView: View {
    @AppStorage(AppearanceMode.storageKey) private var appearance: AppearanceMode = .system

    var body: some View {
        List {
            ForEach(FeatureDomain.allCases) { domain in
                NavigationLink(value: domain) {
                    FeatureMenuRow(
                        title: domain.title,
                        subtitle: domain.subtitle,
                        systemImage: domain.systemImage
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(FeatureMenuBackground())
        .lumenoteCompactHeader(title: "Lumenote") {
            AppearanceToggleButton(appearance: $appearance)
        }
        .navigationDestination(for: FeatureDomain.self) { domain in
            FeatureModeMenuView(domain: domain)
        }
        .navigationDestination(for: FeatureCategory.self) { category in
            FeatureListView(domain: category.domain, mode: category.mode)
        }
        .navigationDestination(for: FeatureDestination.self) { destination in
            featureScreen(for: destination)
        }
    }

    @ViewBuilder
    private func featureScreen(for destination: FeatureDestination) -> some View {
        switch destination {
        case .interval:
            IntervalView()
        case .scale:
            ScaleView()
        case .circleOfFifths:
            CircleOfFifthsView()
        case .chord:
            ChordView()
        case .diatonicChord:
            DiatonicChordView()
        case .intervalQuiz:
            IntervalQuizView()
        case .scaleQuiz:
            ScaleQuizView()
        case .keySignatureQuiz:
            KeySignatureQuizView()
        case .chordQuiz:
            ChordQuizView()
        case .fretboardNoteNames:
            FretboardNoteQuizView()
        case .fretboardDegrees:
            FretboardDegreeQuizView()
        case .fretboardExplorer:
            FretboardExplorerView()
        }
    }
}

// MARK: - Mode menu

private struct FeatureModeMenuView: View {
    let domain: FeatureDomain

    var body: some View {
        List {
            ForEach(FeatureMode.allCases) { mode in
                NavigationLink(value: FeatureCategory(domain: domain, mode: mode)) {
                    FeatureMenuRow(
                        title: mode.title,
                        subtitle: mode.subtitle,
                        systemImage: mode.systemImage
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(FeatureMenuBackground())
        .lumenoteCompactHeader(title: domain.title, showsBackButton: true)
    }
}

// MARK: - Feature list

private struct FeatureListView: View {
    let domain: FeatureDomain
    let mode: FeatureMode

    private var items: [FeatureItem] {
        FeatureCatalog.items(in: domain, mode: mode)
    }

    var body: some View {
        Group {
            if items.isEmpty {
                ContentUnavailableView(
                    "아직 해당되는 메뉴가 없습니다",
                    systemImage: domain.systemImage
                )
            } else {
                List {
                    ForEach(items) { item in
                        NavigationLink(value: item.destination) {
                            FeatureMenuRow(item)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .background(FeatureMenuBackground())
        .lumenoteCompactHeader(title: mode.title, showsBackButton: true)
    }
}

// MARK: - Shared chrome

private struct FeatureMenuRow: View {
    let title: String
    let subtitle: String
    let icon: FeatureIcon

    init(_ item: FeatureItem) {
        self.title = item.title
        self.subtitle = item.subtitle
        self.icon = item.icon
    }

    init(title: String, subtitle: String, icon: FeatureIcon) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
    }

    init(title: String, subtitle: String, systemImage: String) {
        self.init(title: title, subtitle: subtitle, icon: .system(systemImage))
    }

    var body: some View {
        HStack(spacing: LumenoteSpacing.xxl) {
            iconView
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

    @ViewBuilder
    private var iconView: some View {
        switch icon {
        case .system(let name):
            Image(systemName: name)
                .font(LumenoteFont.rounded(size: 22, weight: .semibold))
        case .glyph(let glyph):
            Text(glyph)
                .font(LumenoteFont.rounded(size: 26, weight: .semibold))
        }
    }
}

private struct FeatureMenuBackground: View {
    @Environment(\.appPalette) private var palette

    var body: some View {
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
