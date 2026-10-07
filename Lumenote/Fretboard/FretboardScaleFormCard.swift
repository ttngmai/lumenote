//

import SwiftUI

/// Paged CAGED or 3NPS forms for the scale currently shown on the fretboard.
struct FretboardScaleFormCard: View {
    let model: FretboardScaleExplorerModel

    @Environment(\.appPalette) private var palette
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var system: FretboardScaleFormSystem = .caged
    @State private var page: Int? = 0
    /// CAGED shape kept when the tonic changes, so the same form stays in view.
    @State private var selectedShape = "C"

    private var isCompactHeight: Bool {
        verticalSizeClass == .compact
    }

    private var systems: [FretboardScaleFormSystem] {
        FretboardScaleForms.systems(for: model.kind)
    }

    private var positions: [FretboardScaleFormPosition] {
        FretboardScaleForms.positions(
            tonicPitchClass: model.tonicPitchClass,
            kind: model.kind,
            system: system
        )
    }

    private var pageIndex: Int {
        let index = page ?? 0
        guard positions.indices.contains(index) else { return 0 }
        return index
    }

    private var currentPosition: FretboardScaleFormPosition? {
        guard positions.indices.contains(pageIndex) else { return nil }
        return positions[pageIndex]
    }

    var body: some View {
        VStack(spacing: isCompactHeight ? LumenoteSpacing.sm : LumenoteSpacing.lg) {
            systemControl
            pageControls
            diagramPager
        }
        .padding(.horizontal, LumenoteSpacing.md)
        .padding(.vertical, isCompactHeight ? LumenoteSpacing.sm : LumenoteSpacing.xl)
        .frame(maxWidth: .infinity)
        .background(palette.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: LumenoteRadius.card, style: .continuous)
                .strokeBorder(palette.divider, lineWidth: LumenoteStroke.compact)
        )
        .accessibilityElement(children: .contain)
        .onAppear(perform: captureShape)
        .onChange(of: page) { _, _ in
            captureShape()
        }
        .onChange(of: model.kind) { _, kind in
            let available = FretboardScaleForms.systems(for: kind)
            if !available.contains(system) {
                system = available[0]
            } else if system == .caged {
                alignPageToSelectedShape()
            }
        }
        .onChange(of: model.tonicPitchClass) { _, _ in
            guard system == .caged else { return }
            alignPageToSelectedShape()
        }
        .onChange(of: system) { _, _ in
            showFirstPosition()
        }
    }

    @ViewBuilder
    private var systemControl: some View {
        if systems.count > 1 {
            HStack(spacing: LumenoteSpacing.xxs) {
                ForEach(systems) { item in
                    systemButton(item)
                }
            }
            .padding(LumenoteSpacing.xxs)
            .background(Capsule(style: .continuous).fill(Color.primary.opacity(0.06)))
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if let only = systems.first {
            Text(only.title)
                .font(LumenoteFont.caption(.bold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private func systemButton(_ item: FretboardScaleFormSystem) -> some View {
        let selected = item == system
        return Button {
            guard system != item else { return }
            system = item
        } label: {
            Text(item.title)
                .font(LumenoteFont.caption(.bold))
                .foregroundStyle(.primary)
                .padding(.horizontal, LumenoteSpacing.md)
                .frame(height: 28)
                .background(
                    Capsule(style: .continuous)
                        .fill(selected ? palette.highlight : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHint("이 방식으로 보려면 두 번 탭하세요".l10n)
    }

    private var pageControls: some View {
        HStack(spacing: LumenoteSpacing.md) {
            pageButton(
                systemName: "chevron.left",
                label: "이전 포지션",
                enabled: pageIndex > 0
            ) {
                move(by: -1)
            }

            VStack(spacing: LumenoteSpacing.xs) {
                Text(currentPosition?.title ?? "")
                    .font(LumenoteFont.caption(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                HStack(spacing: LumenoteSpacing.sm) {
                    ForEach(positions.indices, id: \.self) { index in
                        Circle()
                            .fill(index == pageIndex ? Color.primary : Color.secondary.opacity(0.35))
                            .frame(width: 7, height: 7)
                    }
                }
                .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(currentPosition?.title ?? "")
            .accessibilityValue("\(pageIndex + 1) / \(positions.count)")

            pageButton(
                systemName: "chevron.right",
                label: "다음 포지션",
                enabled: pageIndex < positions.count - 1
            ) {
                move(by: 1)
            }
        }
    }

    private func pageButton(
        systemName: String,
        label: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(LumenoteFont.rounded(size: 15, weight: .bold))
                .foregroundStyle(.primary)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.primary.opacity(0.06)))
                .overlay(Circle().strokeBorder(palette.divider, lineWidth: LumenoteStroke.compact))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .accessibilityLabel(label.l10n)
    }

    private var diagramPager: some View {
        GeometryReader { geo in
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(positions) { position in
                        positionDiagram(position)
                            .frame(width: geo.size.width)
                            .id(position.index)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $page, anchor: .leading)
            .scrollIndicators(.hidden)
        }
        .frame(height: FretboardDiagramView.preferredHeight)
    }

    private func positionDiagram(_ position: FretboardScaleFormPosition) -> some View {
        GeometryReader { geo in
            let naturalWidth = FretboardDiagramView.boardWidth(frets: position.fretRange)
            let scale = min(1, geo.size.width / max(naturalWidth, 1))
            FretboardDiagramView(
                accidental: .sharp,
                firstFret: position.fretRange.lowerBound,
                lastFret: position.fretRange.upperBound,
                visiblePositions: Set(position.notes),
                labelMode: model.labelMode,
                rootPitchClass: model.tonicPitchClass,
                pitchClassLabels: model.markerLabels(),
                pitchClassSwatches: model.markerSwatches(),
                pitchClassAccessibilityLabels: model.markerAccessibilityLabels()
            )
            .frame(width: naturalWidth, height: FretboardDiagramView.preferredHeight)
            .scaleEffect(scale)
            .frame(width: naturalWidth * scale, height: FretboardDiagramView.preferredHeight * scale)
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .accessibilityElement(children: .contain)
    }

    private func move(by delta: Int) {
        let next = pageIndex + delta
        guard positions.indices.contains(next) else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            page = next
        }
    }

    private func captureShape() {
        guard system == .caged, let shape = currentPosition?.shapeLetter else { return }
        selectedShape = shape
    }

    private func alignPageToSelectedShape() {
        guard let index = positions.firstIndex(where: { $0.shapeLetter == selectedShape }) else { return }
        guard page != index else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            page = index
        }
    }

    private func showFirstPosition() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            page = 0
        }
        captureShape()
    }
}
