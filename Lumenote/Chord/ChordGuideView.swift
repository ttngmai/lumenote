//

import SwiftUI

/// Textbook-style summary of triad and seventh-chord names, formulas, and C-based symbols.
struct ChordGuideView: View {
    @Environment(\.appPalette) private var palette
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: LumenoteSpacing.section) {
                    summaryCard
                    chordSection(title: "Triad", kinds: ChordKind.triads)
                    chordSection(title: "7th", kinds: ChordKind.sevenths)
                }
                .padding(.horizontal, LumenoteSpacing.popupInset)
                .padding(.vertical, LumenoteSpacing.xxxl)
                .frame(maxWidth: .infinity)
            }
            .background(sheetBackground)
            .navigationTitle("화음 정리")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                        .font(LumenoteFont.callout(.semibold))
                }
            }
        }
        .lumenotePalette()
    }

    private var summaryCard: some View {
        Text("근음을 C로 둔 Triad와 7th 코드의 이름, 구성음, 표기입니다. 근음이 바뀌면 같은 간격으로 구성음과 기호가 옮겨집니다.")
            .font(LumenoteFont.callout(.medium))
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(LumenoteSpacing.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous)
                    .strokeBorder(palette.divider, lineWidth: LumenoteStroke.compact)
            )
    }

    private func chordSection(title: String, kinds: [ChordKind]) -> some View {
        VStack(alignment: .leading, spacing: LumenoteSpacing.md) {
            Text(title)
                .font(LumenoteFont.caption(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, LumenoteSpacing.xs)

            VStack(spacing: 0) {
                tableHeader

                ForEach(Array(kinds.enumerated()), id: \.element.id) { index, kind in
                    if index > 0 {
                        Rectangle()
                            .fill(palette.divider)
                            .frame(height: LumenoteStroke.hairline)
                    }
                    chordRow(kind)
                }
            }
            .background(palette.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous)
                    .strokeBorder(palette.divider, lineWidth: LumenoteStroke.compact)
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }

    private var tableHeader: some View {
        HStack(alignment: .center, spacing: LumenoteSpacing.md) {
            Text("화음")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("구성음")
                .frame(width: 88, alignment: .leading)
        }
        .font(LumenoteFont.caption2(.bold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, LumenoteSpacing.xxl)
        .padding(.vertical, LumenoteSpacing.lg)
        .background(palette.highlightSoft)
        .accessibilityHidden(true)
    }

    private func chordRow(_ kind: ChordKind) -> some View {
        VStack(alignment: .leading, spacing: LumenoteSpacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: LumenoteSpacing.md) {
                Text(kind.englishTitle)
                    .font(LumenoteFont.body(.bold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(kind.formulaText)
                    .font(LumenoteFont.callout(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 88, alignment: .leading)
            }

            HStack(alignment: .firstTextBaseline, spacing: LumenoteSpacing.sm) {
                Text("표기")
                    .font(LumenoteFont.caption2(.semibold))
                    .foregroundStyle(.secondary)
                Text(kind.notations(rootDisplayName: "C").joined(separator: "  ·  "))
                    .font(LumenoteFont.caption(.medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, LumenoteSpacing.xxl)
        .padding(.vertical, LumenoteSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(kind.englishTitle), 구성음 \(kind.formulaText), 표기 \(kind.notations(rootDisplayName: "C").joined(separator: ", "))"
        )
    }

    private var sheetBackground: some View {
        LinearGradient(
            colors: palette.backgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

#Preview {
    ChordGuideView()
}
