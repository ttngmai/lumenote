//

import SwiftUI

/// Root menu: pick a domain, then expand learn or quiz to open a feature.
struct FeatureMenuView: View {
    @AppStorage(AppearanceMode.storageKey) private var appearance: AppearanceMode = .system

    var body: some View {
        List {
            Section {
                NavigationLink(value: LearningRoute.hub) {
                    FeatureMenuRow(
                        title: "오답 관리".l10n,
                        subtitle: "틀린 문제를 다시 풀고, 학습 상태를 확인하세요".l10n,
                        systemImage: "chart.bar"
                    )
                }
            }

            Section {
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

            Section {
                NavigationLink(value: AppSettingsDestination.language) {
                    FeatureMenuRow(
                        title: "언어 설정".l10n,
                        subtitle: LanguageSettings.shared.language.nativeName,
                        systemImage: "globe"
                    )
                }
                NavigationLink(value: AppSettingsDestination.appearance) {
                    FeatureMenuRow(
                        title: "화면 모드".l10n,
                        subtitle: appearance.title,
                        systemImage: "circle.lefthalf.filled"
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(FeatureMenuBackground())
        .lumenoteCompactHeader(title: "Lumenote")
        .navigationDestination(for: AppSettingsDestination.self) { destination in
            switch destination {
            case .language:
                LanguageSettingsView()
            case .appearance:
                AppearanceSettingsView()
            }
        }
        .navigationDestination(for: FeatureDomain.self) { domain in
            FeatureModeMenuView(domain: domain)
        }
        .navigationDestination(for: FeatureDestination.self) { destination in
            featureScreen(for: destination)
        }
        .navigationDestination(for: LearningRoute.self) { route in
            switch route {
            case .hub:
                LearningHubView()
            case .domain(let domain):
                LearningDomainView(domain: domain)
            case .topic(let topic):
                LearningTopicView(topic: topic)
            case .review(let topic, let skillKeys):
                LearningReviewSessionView(topic: topic, skillKeys: skillKeys)
            }
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
            IntervalQuizDifficultyView()
        case .scaleQuiz:
            ScaleQuizDifficultyView()
        case .keySignatureQuiz:
            KeySignatureQuizDifficultyView()
        case .chordQuiz:
            ChordQuizDifficultyView()
        case .diatonicChordQuiz:
            DiatonicChordQuizDifficultyView()
        case .fretboardNoteNames:
            FretboardNoteQuizDifficultyView()
        case .fretboardDegrees:
            FretboardDegreeQuizDifficultyView()
        case .fretboardExplorer:
            FretboardExplorerView()
        }
    }
}

// MARK: - Mode menu

private struct FeatureModeMenuView: View {
    let domain: FeatureDomain
    @State private var expandedModes: Set<FeatureMode> = []

    var body: some View {
        List {
            ForEach(FeatureMode.allCases) { mode in
                FeatureModeSection(
                    domain: domain,
                    mode: mode,
                    isExpanded: expansionBinding(for: mode)
                )
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(LumenoteSpacing.xl)
        .scrollContentBackground(.hidden)
        .background(FeatureMenuBackground())
        .lumenoteCompactHeader(title: domain.title, showsBackButton: true)
    }

    private func expansionBinding(for mode: FeatureMode) -> Binding<Bool> {
        Binding(
            get: { expandedModes.contains(mode) },
            set: { isExpanded in
                if isExpanded {
                    expandedModes.insert(mode)
                } else {
                    expandedModes.remove(mode)
                }
            }
        )
    }
}

private struct FeatureModeSection: View {
    let domain: FeatureDomain
    let mode: FeatureMode
    @Binding var isExpanded: Bool

    private var items: [FeatureItem] {
        FeatureCatalog.items(in: domain, mode: mode)
    }

    var body: some View {
        Section {
            Button {
                withAnimation(.easeOut(duration: 0.18)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: LumenoteSpacing.md) {
                    FeatureMenuRow(
                        title: mode.title,
                        subtitle: mode.subtitle,
                        systemImage: mode.systemImage
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.down")
                        .font(LumenoteFont.rounded(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(mode.title), \(mode.subtitle)")
            .accessibilityHint((isExpanded ? "접기" : "펼치기").l10n)
            .accessibilityAddTraits(.isButton)
            .accessibilityAddTraits(isExpanded ? .isSelected : [])

            if isExpanded {
                if items.isEmpty {
                    Text("아직 해당되는 메뉴가 없습니다")
                        .font(LumenoteFont.caption(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, LumenoteSpacing.xs)
                } else {
                    ForEach(items) { item in
                        NavigationLink(value: item.destination) {
                            FeatureMenuRow(item)
                        }
                    }
                }
            }
        }
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
        .frame(maxWidth: .infinity, alignment: .leading)
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
