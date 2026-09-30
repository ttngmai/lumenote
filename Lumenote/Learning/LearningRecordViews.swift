//

import SwiftUI

enum LearningRoute: Hashable {
    case hub
    case domain(FeatureDomain)
    case topic(LearningTopic)
    case review(LearningTopic, Set<String>)
}

struct LearningHubView: View {
    @Environment(\.learningLog) private var learningLog

    var body: some View {
        let snapshot = learningLog?.snapshot() ?? .empty
        List {
            Section {
                ForEach(FeatureDomain.allCases) { domain in
                    let topics = snapshot.topics(in: domain)
                    let due = topics.reduce(0) { $0 + $1.due.count }
                    NavigationLink(value: LearningRoute.domain(domain)) {
                        LearningMenuRow(
                            title: domain.title,
                            subtitle: dueSubtitle(due),
                            systemImage: domain.systemImage
                        )
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(LearningScreenBackground())
        .lumenoteCompactHeader(title: "오답 관리", showsBackButton: true)
    }

    private func dueSubtitle(_ due: Int) -> String {
        due > 0 ? L10n.s("복습 대상 \(due)개") : "복습할 항목이 없습니다".l10n
    }
}

struct LearningDomainView: View {
    let domain: FeatureDomain
    @Environment(\.learningLog) private var learningLog

    var body: some View {
        let snapshot = learningLog?.snapshot() ?? .empty
        List {
            Section {
                ForEach(snapshot.topics(in: domain)) { progress in
                    NavigationLink(value: LearningRoute.topic(progress.topic)) {
                        LearningMenuRow(
                            title: progress.topic.title,
                            subtitle: topicSubtitle(progress),
                            systemImage: "chart.bar"
                        )
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(LearningScreenBackground())
        .lumenoteCompactHeader(title: domain.title, showsBackButton: true)
    }

    private func topicSubtitle(_ progress: TopicProgress) -> String {
        guard progress.hasAttempts else { return "아직 기록이 없습니다".l10n }
        return L10n.s("복습 대상 \(progress.due.count)개")
    }
}

struct LearningTopicView: View {
    let topic: LearningTopic
    @Environment(\.learningLog) private var learningLog
    @State private var showsStandingGuide = false

    var body: some View {
        let progress = learningLog?.snapshot().progress(for: topic)
            ?? TopicProgress(topic: topic, unseen: 0, learning: 0, shaky: 0, solid: 0, due: [])
        List {
            Section {
                StandingChart(progress: progress)
            } header: {
                HStack {
                    Spacer(minLength: 0)
                    Button {
                        showsStandingGuide = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .font(LumenoteFont.rounded(size: 18, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("학습 상태 기준".l10n)
                }
                .textCase(nil)
            } footer: {
                if !progress.due.isEmpty {
                    ReviewStartLink(
                        topic: topic,
                        skillKeys: Set(progress.due.map(\.skillKey))
                    )
                }
            }

            Section {
                if progress.due.isEmpty {
                    Text("복습할 항목이 없습니다".l10n)
                        .font(LumenoteFont.caption(.medium))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(progress.due) { skill in
                        DueSkillRow(skill: skill)
                    }
                }
            } header: {
                Text("복습 대상".l10n)
                    .font(LumenoteFont.body(.bold))
                    .foregroundStyle(.primary)
                    .textCase(nil)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(LearningScreenBackground())
        .lumenoteCompactHeader(title: topic.title, showsBackButton: true)
        .overlay {
            if showsStandingGuide {
                StandingGuidePopup {
                    showsStandingGuide = false
                }
            }
        }
    }
}

private struct ReviewStartLink: View {
    let topic: LearningTopic
    let skillKeys: Set<String>
    @Environment(\.appPalette) private var palette

    var body: some View {
        NavigationLink(value: LearningRoute.review(topic, skillKeys)) {
            Text("복습 시작".l10n)
                .font(LumenoteFont.body(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, LumenoteSpacing.xxl)
                .background(
                    RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous)
                        .fill(palette.minor)
                )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .padding(.top, LumenoteSpacing.md)
        .textCase(nil)
    }
}

private struct DueSkillRow: View {
    let skill: SkillProgress
    @Environment(\.appPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: LumenoteSpacing.xxs) {
            HStack(alignment: .center, spacing: LumenoteSpacing.sm) {
                Text(skill.title)
                    .font(LumenoteFont.body(.bold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                StandingLabel(standing: skill.standing)
            }

            HStack(alignment: .center, spacing: LumenoteSpacing.xs) {
                answerMark("xmark.circle.fill", color: palette.quizIncorrect, label: "오답")
                Text(skill.lastMissChosen.l10n)
                Text("→")
                    .accessibilityHidden(true)
                answerMark("checkmark.circle.fill", color: palette.quizCorrect, label: "정답")
                Text(skill.lastMissExpected.l10n)
            }
            .font(LumenoteFont.caption(.medium))
            .foregroundStyle(.secondary)

            Text(skill.lastMissAt.formatted(date: .abbreviated, time: .shortened))
                .font(LumenoteFont.caption(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, LumenoteSpacing.xs)
        .accessibilityElement(children: .combine)
    }

    private func answerMark(_ systemImage: String, color: Color, label: String) -> some View {
        Image(systemName: systemImage)
            .font(LumenoteFont.rounded(size: 14, weight: .semibold))
            .foregroundStyle(color)
            .accessibilityLabel(label.l10n)
    }
}

private struct StandingChart: View {
    let progress: TopicProgress
    @Environment(\.appPalette) private var palette

    private var bars: [StandingBar] {
        [
            StandingBar(standing: .unseen, count: progress.unseen, color: palette.ringStroke),
            StandingBar(standing: .learning, count: progress.learning, color: palette.minor),
            StandingBar(standing: .shaky, count: progress.shaky, color: palette.quizIncorrect),
            StandingBar(standing: .solid, count: progress.solid, color: palette.quizCorrect),
        ]
    }

    private var tallest: Int {
        max(bars.map(\.count).max() ?? 0, 1)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: LumenoteSpacing.sm) {
            ForEach(bars) { bar in
                VStack(spacing: LumenoteSpacing.sm) {
                    Text("\(bar.count)")
                        .font(LumenoteFont.caption(.bold))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                    barColumn(bar)
                    Text(bar.standing.title)
                        .font(LumenoteFont.caption2(.medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity, minHeight: 16, alignment: .top)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(bar.standing.title) \(bar.count)")
            }
        }
        .padding(.top, LumenoteSpacing.md)
        .padding(.bottom, LumenoteSpacing.xxs)
        .accessibilityElement(children: .contain)
    }

    private func barColumn(_ bar: StandingBar) -> some View {
        let plotHeight: CGFloat = 96
        let height = barHeight(count: bar.count, plotHeight: plotHeight)
        return VStack(spacing: 0) {
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(bar.count == 0 ? palette.divider : bar.color)
                .frame(height: height)
        }
        .frame(maxWidth: .infinity)
        .frame(height: plotHeight)
    }

    private func barHeight(count: Int, plotHeight: CGFloat) -> CGFloat {
        if count == 0 { return 4 }
        let scaled = plotHeight * CGFloat(count) / CGFloat(tallest)
        return max(8, scaled)
    }
}

private struct StandingBar: Identifiable {
    let standing: SkillStanding
    let count: Int
    let color: Color

    var id: SkillStanding { standing }
}

private struct StandingLabel: View {
    let standing: SkillStanding
    @Environment(\.appPalette) private var palette

    var body: some View {
        Text(standing.title)
            .font(LumenoteFont.caption2(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, LumenoteSpacing.md)
            .padding(.vertical, LumenoteSpacing.xxs)
            .background(Capsule().fill(color.opacity(0.16)))
    }

    private var color: Color {
        switch standing {
        case .unseen: palette.ringStroke
        case .learning: palette.minor
        case .shaky: palette.quizIncorrect
        case .solid: palette.quizCorrect
        }
    }
}

private struct StandingGuidePopup: View {
    var dismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture(perform: dismiss)

            VStack(alignment: .leading, spacing: LumenoteSpacing.lg) {
                Text("학습 상태".l10n)
                    .font(LumenoteFont.body(.bold))
                    .foregroundStyle(.primary)
                Text("각 항목의 최근 10회 풀이 기록을 기준으로 학습 상태를 판단합니다.".l10n)
                    .font(LumenoteFont.caption(.medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                guideRow(
                    .unseen,
                    detail: "한 번도 풀지 않은 항목입니다."
                )
                guideRow(
                    .learning,
                    detail: "풀이 기록이 있지만 아직 연속 3회 정답을 달성하지 못했고, 불안정 상태에도 해당하지 않는 항목입니다."
                )
                guideRow(
                    .shaky,
                    detail: "최근 10회 풀이 중 정답 기록이 있지만, 마지막 풀이에서 틀린 항목입니다."
                )
                guideRow(
                    .solid,
                    detail: "최근 3회 연속으로 정답을 맞힌 항목입니다."
                )
            }
            .padding(LumenoteSpacing.popupInset)
            .lumenotePopup()
            .padding(.horizontal, LumenoteSpacing.xl)
        }
        .accessibilityAddTraits(.isModal)
    }

    private func guideRow(_ standing: SkillStanding, detail: String) -> some View {
        VStack(alignment: .leading, spacing: LumenoteSpacing.xs) {
            StandingLabel(standing: standing)
            Text(detail.l10n)
                .font(LumenoteFont.caption(.medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

struct LearningTopicShortcut: View {
    let topic: LearningTopic

    var body: some View {
        NavigationLink(value: LearningRoute.topic(topic)) {
            Text("이 주제의 오답".l10n)
                .font(LumenoteFont.body(.bold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, LumenoteSpacing.xxl)
                .lumenoteCard()
        }
        .buttonStyle(.plain)
    }
}

private struct LearningMenuRow: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: LumenoteSpacing.xxl) {
            Image(systemName: systemImage)
                .font(LumenoteFont.rounded(size: 22, weight: .semibold))
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
}

private struct LearningScreenBackground: View {
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
