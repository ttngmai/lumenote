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
                    summary
                    chordSection(title: "Triad", kinds: ChordKind.triads)
                    chordSection(title: "7th", kinds: ChordKind.sevenths)
                }
                .padding(LumenoteSpacing.xxl)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(palette.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous)
                        .strokeBorder(palette.divider, lineWidth: LumenoteStroke.compact)
                )
                .padding(.horizontal, LumenoteSpacing.popupInset)
                .padding(.vertical, LumenoteSpacing.xxxl)
            }
            .background(sheetBackground)
            .navigationTitle("코드 정리")
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

    private var summary: some View {
        VStack(alignment: .leading, spacing: LumenoteSpacing.md) {
            Text("C를 근음으로 하는 Triad와 7th 코드의 이름, 구성음, 표기입니다.")
                .fixedSize(horizontal: false, vertical: true)
            Text("근음이 바뀌어도 코드의 구성음 사이의 음정 관계는 동일하게 유지됩니다.")
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(LumenoteFont.callout(.medium))
        .foregroundStyle(.primary)
    }

    private func chordSection(title: String, kinds: [ChordKind]) -> some View {
        VStack(alignment: .leading, spacing: LumenoteSpacing.md) {
            Text(title.l10n)
                .font(LumenoteFont.caption(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)

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
            .clipShape(RoundedRectangle(cornerRadius: LumenoteRadius.softRow, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: LumenoteRadius.softRow, style: .continuous)
                    .strokeBorder(palette.divider, lineWidth: LumenoteStroke.compact)
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }

    private var tableHeader: some View {
        HStack(alignment: .center, spacing: LumenoteSpacing.md) {
            Text("코드")
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
