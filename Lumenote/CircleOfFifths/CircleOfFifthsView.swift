//

import SwiftUI

struct CircleOfFifthsView: View {
    @Environment(\.appPalette) private var palette
    @AppStorage(AppearanceMode.storageKey) private var appearance: AppearanceMode = .system

    @State private var model = CircleOfFifthsModel()
    @State private var isTonicExpanded = false
    @State private var isAccidentalOrderExpanded = false

    var body: some View {
        GeometryReader { geo in
            let isWide = geo.size.width > geo.size.height * 0.9

            Group {
                if isWide {
                    HStack(alignment: .center, spacing: LumenoteSpacing.xl) {
                        circleSection(placesLegendBeside: true)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        ScrollView {
                            selectors
                        }
                        .scrollIndicators(.hidden)
                        .frame(width: min(330, geo.size.width * 0.34))
                    }
                } else {
                    ScrollView {
                        VStack(spacing: LumenoteSpacing.lg) {
                            circleSection(placesLegendBeside: false)
                            selectors
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .padding(.horizontal, isWide ? LumenoteSpacing.lg : LumenoteSpacing.xl)
            .padding(.top, isWide ? LumenoteSpacing.lg : LumenoteSpacing.xl)
            .padding(.bottom, isWide ? 0 : LumenoteSpacing.xxxl)
            .frame(width: geo.size.width, height: geo.size.height, alignment: isWide ? .center : .top)
        }
        .background(background)
        .lumenoteCompactHeader(title: "5도권", showsBackButton: true) {
            AppearanceToggleButton(appearance: $appearance)
        }
    }

    private var background: some View {
        LinearGradient(
            colors: palette.backgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private func circleSection(placesLegendBeside: Bool) -> some View {
        CircleOfFifthsRingView(model: model, placesLegendBeside: placesLegendBeside)
            // Portrait keeps a readable cap; landscape uses the full leftover column.
            .frame(maxWidth: placesLegendBeside ? .infinity : 520)
    }

    private var selectors: some View {
        VStack(spacing: LumenoteSpacing.lg) {
            tonicPickerControl
            accidentalOrderCard
        }
        .frame(maxWidth: .infinity)
    }

    /// Tonic selector.
    private var tonicPickerControl: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeOut(duration: 0.18)) {
                    isTonicExpanded.toggle()
                }
            } label: {
                HStack(spacing: LumenoteSpacing.xs) {
                    Text(model.selectedTonicDisplayName)
                        .font(LumenoteFont.body(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text("Key")
                        .font(LumenoteFont.caption(.bold))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(LumenoteFont.rounded(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isTonicExpanded ? 180 : 0))
                }
                .padding(.horizontal, LumenoteSpacing.xxl)
                .padding(.vertical, LumenoteSpacing.xl)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(model.selectedTonicDisplayName) Key")
            .accessibilityHint(isTonicExpanded ? "접기" : "펼치기")
            .accessibilityAddTraits(isTonicExpanded ? .isSelected : [])

            if isTonicExpanded {
                tonicOptionGrid
                    .padding(.horizontal, LumenoteSpacing.xxl)
                    .padding(.bottom, LumenoteSpacing.xxl)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .lumenoteCard(isActive: isTonicExpanded)
    }

    private var accidentalOrderCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeOut(duration: 0.18)) {
                    isAccidentalOrderExpanded.toggle()
                }
            } label: {
                HStack(spacing: LumenoteSpacing.xs) {
                    Text("조표 붙는 순서")
                        .font(LumenoteFont.caption(.bold))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(LumenoteFont.rounded(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isAccidentalOrderExpanded ? 180 : 0))
                }
                .padding(.horizontal, LumenoteSpacing.xxl)
                .padding(.vertical, LumenoteSpacing.xl)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("조표 붙는 순서")
            .accessibilityHint(isAccidentalOrderExpanded ? "접기" : "펼치기")
            .accessibilityAddTraits(isAccidentalOrderExpanded ? .isSelected : [])

            if isAccidentalOrderExpanded {
                VStack(alignment: .leading, spacing: LumenoteSpacing.xl) {
                    accidentalOrderRow(
                        title: "♯",
                        sequence: "F → C → G → D → A → E → B"
                    )
                    accidentalOrderRow(
                        title: "♭",
                        sequence: "B → E → A → D → G → C → F",
                        footnote: "♯이 붙는 순서의 역순입니다."
                    )
                }
                .padding(.horizontal, LumenoteSpacing.xxl)
                .padding(.bottom, LumenoteSpacing.xxl)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .lumenoteCard()
    }

    private func accidentalOrderRow(title: String, sequence: String, footnote: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: LumenoteSpacing.xs) {
            Text(title)
                .font(LumenoteFont.caption(.bold))
                .foregroundStyle(.secondary)
            Text(sequence)
                .font(LumenoteFont.body(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            if let footnote {
                Text(footnote)
                    .font(LumenoteFont.caption(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tonicOptionGrid: some View {
        let options = CircleOfFifthsModel.Tonic.chromaticPickerOptions
        let columnCount = 3

        return Grid(horizontalSpacing: LumenoteSpacing.md, verticalSpacing: LumenoteSpacing.md) {
            ForEach(Array(stride(from: 0, to: options.count, by: columnCount)), id: \.self) { start in
                let end = min(start + columnCount, options.count)
                GridRow {
                    ForEach(options[start..<end]) { option in
                        tonicOptionButton(option)
                    }
                    ForEach(0..<(columnCount - (end - start)), id: \.self) { _ in
                        Color.clear
                    }
                }
            }
        }
    }

    private func tonicOptionButton(_ option: CircleOfFifthsModel.TonicPickerOption) -> some View {
        let selected = option.contains(model.selectedTonic)
        return Button {
            model.selectedTonic = option.representative
            withAnimation(.easeOut(duration: 0.18)) {
                isTonicExpanded = false
            }
        } label: {
            Text(option.displayName)
                .font(LumenoteFont.body(selected ? .bold : .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .padding(.vertical, LumenoteSpacing.xl)
                .padding(.horizontal, LumenoteSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: LumenoteRadius.chip, style: .continuous)
                        .fill(selected ? palette.highlight : palette.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: LumenoteRadius.chip, style: .continuous)
                        .strokeBorder(
                            selected ? palette.cardBorderActive : palette.divider,
                            lineWidth: selected ? LumenoteStroke.compact : LumenoteStroke.hairline
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.displayName)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

#Preview {
    CircleOfFifthsView()
        .lumenotePalette()
}
