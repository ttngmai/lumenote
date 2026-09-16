//

import SwiftUI

struct FretboardExplorerView: View {
    @Environment(\.appPalette) private var palette
    @AppStorage(AppearanceMode.storageKey) private var appearance: AppearanceMode = .system
    @AppStorage(AccidentalPreference.fretboardStorageKey) private var accidental: AccidentalPreference = .sharp

    @State private var model = FretboardExplorerModel()

    private let noteColumns = Array(repeating: GridItem(.flexible(), spacing: LumenoteSpacing.md), count: 4)

    var body: some View {
        ScrollView {
            VStack(spacing: LumenoteSpacing.section) {
                fretboardCard
                noteToggleCard
            }
            .padding(.horizontal, LumenoteSpacing.popupInset)
            .padding(.vertical, LumenoteSpacing.xxxl)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(background)
        .lumenoteCompactHeader(title: "지판 보기", showsBackButton: true) {
            HStack(spacing: LumenoteSpacing.sm) {
                accidentalToggle
                AppearanceToggleButton(appearance: $appearance)
            }
        }
    }

    private var fretboardCard: some View {
        GeometryReader { geo in
            let needsScroll = geo.size.width < FretboardDiagramView.minimumWidth
            let diagram = FretboardDiagramView(
                accidental: accidental,
                visiblePitchClasses: model.visiblePitchClasses
            )

            Group {
                if needsScroll {
                    ScrollView(.horizontal, showsIndicators: false) {
                        diagram
                            .frame(width: FretboardDiagramView.minimumWidth)
                    }
                } else {
                    diagram
                        .frame(width: geo.size.width)
                }
            }
        }
        .frame(height: FretboardDiagramView.preferredHeight)
        .padding(.horizontal, LumenoteSpacing.xs)
        .padding(.vertical, LumenoteSpacing.xl)
        .frame(maxWidth: .infinity)
        .background(palette.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous)
                .strokeBorder(palette.divider, lineWidth: LumenoteStroke.compact)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("기타 지판")
    }

    private var noteToggleCard: some View {
        LazyVGrid(columns: noteColumns, spacing: LumenoteSpacing.md) {
            ForEach(Fretboard.pitchClasses, id: \.self) { pitchClass in
                noteToggleButton(pitchClass)
            }
        }
        .padding(LumenoteSpacing.xxl)
        .frame(maxWidth: .infinity)
        .background(palette.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous)
                .strokeBorder(palette.divider, lineWidth: LumenoteStroke.compact)
        )
    }

    private func noteToggleButton(_ pitchClass: Int) -> some View {
        let name = Fretboard.displayName(pitchClass: pitchClass, accidental: accidental)
        let color = palette.fretboardNote(pitchClass)
        let isOn = model.isVisible(pitchClass)

        return Button {
            model.toggle(pitchClass)
        } label: {
            Text(name)
                .font(LumenoteFont.body(.bold))
                .foregroundStyle(isOn ? Color.white : color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, LumenoteSpacing.xxl)
                .background(
                    RoundedRectangle(cornerRadius: LumenoteRadius.softRow, style: .continuous)
                        .fill(isOn ? color : color.opacity(0.14))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: LumenoteRadius.softRow, style: .continuous)
                        .strokeBorder(color, lineWidth: isOn ? LumenoteStroke.compact : LumenoteStroke.hairline)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityValue(isOn ? "표시됨" : "숨김")
        .accessibilityHint("지판 표시를 전환하려면 두 번 탭하세요")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private var accidentalToggle: some View {
        Button {
            accidental = accidental == .sharp ? .flat : .sharp
        } label: {
            Text(accidental.symbol)
                .font(LumenoteFont.rounded(size: 18, weight: .bold))
                .foregroundStyle(.primary)
                .frame(width: 34, height: 34)
                .background(Circle().fill(palette.cardBackground))
                .overlay(Circle().strokeBorder(palette.cardBorder, lineWidth: LumenoteStroke.compact))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accidental == .sharp ? "플랫 표기로 전환" : "샵 표기로 전환")
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
        FretboardExplorerView()
    }
    .lumenotePalette()
}
