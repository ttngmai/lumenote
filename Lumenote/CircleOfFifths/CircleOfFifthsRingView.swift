//

import SwiftUI

struct CircleOfFifthsRingView: View {
    @Bindable var model: CircleOfFifthsModel
    /// When true, layout is a landscape column: only the top is reserved for interval labels.
    var placesLegendBeside: Bool = false

    @Environment(\.appPalette) private var palette

    @State private var ringRotationDegrees: Double = 0
    @State private var dragRotationDegrees: Double = 0
    @State private var dragStartAngle: Double?
    @State private var rotationAtDragStart: Double = 0
    @State private var skipWedgeTap = false

    private var ringStroke: Color { palette.ringStroke }
    private var wedgeFill: Color { .white }
    private var wedgeLabelColor: Color { Color(white: 0.18) }

    /// Outermost: sharp/flat counts.
    /// Keep `signatureOuterRatio * raisedScale ≤ 0.48` so the raised tonic stays inside the square.
    private let signatureOuterRatio: CGFloat = 0.47
    /// Boundary between signature ring and note names.
    private let outerRadiusRatio: CGFloat = 0.40
    /// Boundary between the note ring (outer) and the degree ring (inner).
    private let degreeOuterRatio: CGFloat = 0.255
    /// Innermost: degree labels. Inner edge also bounds the centre hub.
    private let degreeInnerRatio: CGFloat = 0.16
    /// How much the 12 o'clock tonic wedge is scaled up (radial + slight angular overlap).
    private let raisedScale: CGFloat = 1.05
    private let raisedAngularPadDegrees: Double = 2.5
    /// Extra vertical room (as a fraction of ring size) for raised tonic + interval labels.
    /// Interval labels sit on the upper arc, so only the top needs a margin.
    /// Landscape keeps the ring flush to the bottom of its column.
    private var topLabelMarginRatio: CGFloat {
        placesLegendBeside ? 0.10 : 0.14
    }

    private var bottomLabelMarginRatio: CGFloat {
        0
    }

    /// Continuous ring rotation. Avoids C (0°) ↔ F (−330°) long-way animation.
    private var displayedRotationDegrees: Double {
        ringRotationDegrees + dragRotationDegrees
    }

    /// Layout is slightly taller than wide so labels above/below the ring aren't clipped.
    private var layoutAspectRatio: CGFloat {
        1 / (1 + topLabelMarginRatio + bottomLabelMarginRatio)
    }

    var body: some View {
        if placesLegendBeside {
            landscapeRing
        } else {
            ringCanvas
        }
    }

    /// Ring centered in the leftover landscape column.
    private var landscapeRing: some View {
        GeometryReader { geo in
            let size = ringDiameter(in: geo.size)

            ringSquare(size: size)
                .frame(
                    width: size,
                    height: size + size * topLabelMarginRatio,
                    alignment: .bottom
                )
                .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    @ViewBuilder
    private var ringCanvas: some View {
        ringGeometry
            .aspectRatio(layoutAspectRatio, contentMode: .fit)
    }

    private var ringGeometry: some View {
        GeometryReader { geo in
            let size = ringDiameter(in: geo.size)
            let ringOriginX = (geo.size.width - size) / 2
            // Keep the reserved label margin above the square (not split top/bottom).
            let ringOriginY = size * topLabelMarginRatio

            ringSquare(size: size)
                .frame(width: size, height: size)
                .position(x: ringOriginX + size / 2, y: ringOriginY + size / 2)
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .accessibilityHint("칸을 탭하면 그 음이 1도가 됩니다. 원을 드래그하면 시계 방향은 5도 상행 (4도 하행), 반시계 방향은 4도 상행 (5도 하행)입니다.")
    }

    /// Fixed-size ring (drawing + gesture). Used by both portrait and landscape layouts.
    private func ringSquare(size: CGFloat) -> some View {
        let localCenter = CGPoint(x: size / 2, y: size / 2)

        return ZStack {
            // Base rings (equal wedges).
            Canvas { context, _ in
                drawBaseRings(context: context, center: localCenter, size: size)
            }

            // Raised 12 o'clock wedge drawn above neighbors with a drop shadow.
            RaisedTonicWedgeView(
                noteColor: wedgeFill,
                ringStroke: ringStroke,
                signatureOuterRatio: signatureOuterRatio,
                outerRadiusRatio: outerRadiusRatio,
                degreeOuterRatio: degreeOuterRatio,
                degreeInnerRatio: degreeInnerRatio,
                raisedScale: raisedScale,
                angularPadDegrees: raisedAngularPadDegrees,
                isEmphasized: model.emphasizedClockPositions.contains { position in
                    model.screenClock(forModelPosition: position) == 12
                },
                emphasisFill: palette.emphasisFill,
                emphasisStroke: palette.emphasisStroke,
                shadowOpacity: palette.raisedWedgeShadowOpacity
            )

            // Rotating labels.
            signatureCountLabels(center: localCenter, size: size)
                .rotationEffect(.degrees(displayedRotationDegrees))
                .allowsHitTesting(false)

            noteLabels(center: localCenter, size: size)
                .rotationEffect(.degrees(displayedRotationDegrees))
                .allowsHitTesting(false)

            relativeMinorLabels(center: localCenter, size: size)
                .rotationEffect(.degrees(displayedRotationDegrees))
                .allowsHitTesting(false)

            centerHub(size: size)
                .allowsHitTesting(false)
            rotationAffordances(center: localCenter, size: size)
        }
        .frame(width: size, height: size)
        .animation(.easeInOut(duration: 0.2), value: model.emphasizedClockPositions)
        .contentShape(Circle().scale(1.12))
        .gesture(rotationDragGesture(center: localCenter))
        .simultaneousGesture(wedgeTapGesture(center: localCenter, size: size))
        .onAppear {
            ringRotationDegrees = canonicalRotationDegrees(for: model.tonicArrowPosition)
        }
        .onChange(of: model.selectedTonic) { _, _ in
            // Picker / external tonic changes: take the shortest arc (fixes C ↔ F spin).
            guard dragStartAngle == nil else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                ringRotationDegrees += shortestRotationDelta(
                    from: ringRotationDegrees,
                    to: canonicalRotationDegrees(for: model.tonicArrowPosition)
                )
            }
        }
        .animation(
            dragStartAngle == nil
                ? .spring(response: 0.45, dampingFraction: 0.82)
                : nil,
            value: model.selectedMode
        )
        .accessibilityHint("칸을 탭하면 그 음이 1도가 됩니다. 원을 드래그하면 시계 방향은 5도 상행 (4도 하행), 반시계 방향은 4도 상행 (5도 하행)입니다.")
    }

    /// Diameter limited by width and by height after label margins.
    private func ringDiameter(in size: CGSize) -> CGFloat {
        let heightBudget = size.height / (1 + topLabelMarginRatio + bottomLabelMarginRatio)
        return max(min(size.width, heightBudget), 1)
    }

    // MARK: - Base rings

    private func drawBaseRings(context: GraphicsContext, center: CGPoint, size: CGFloat) {
        let radii = ringRadii(size: size, scale: 1)

        // Outer → inner: signature, note, degree. Skip position 12; raised overlay redraws it.
        for position in 1...12 where position != 12 {
            fillSector(
                context: context,
                center: center,
                inner: radii.signatureInner,
                outer: radii.signatureOuter,
                clockPosition: position,
                color: wedgeFill,
                angularPad: 0
            )

            fillSector(
                context: context,
                center: center,
                inner: radii.noteInner,
                outer: radii.noteOuter,
                clockPosition: position,
                color: wedgeFill,
                angularPad: 0
            )

            fillSector(
                context: context,
                center: center,
                inner: radii.degreeInner,
                outer: radii.degreeOuter,
                clockPosition: position,
                color: wedgeFill,
                angularPad: 0
            )
        }

        // Separators (all 12; raised wedge covers the top pair)
        for position in 1...12 {
            let angle = angleForLeadingEdge(of: position)
            var line = Path()
            line.move(to: point(center: center, radius: radii.degreeInner, angle: angle))
            line.addLine(to: point(center: center, radius: radii.signatureOuter, angle: angle))
            context.stroke(line, with: .color(ringStroke.opacity(0.3)), lineWidth: 0.8)
        }

        // Ring outlines
        for radius in [radii.signatureOuter, radii.noteOuter, radii.degreeOuter, radii.degreeInner] {
            var circle = Path()
            circle.addEllipse(
                in: CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
            )
            context.stroke(
                circle,
                with: .color(ringStroke),
                lineWidth: radius == radii.signatureOuter ? 1.8 : 1.1
            )
        }

        // Temporary emphasis (characteristic note / formula tap).
        let emphasizedScreens = Set(
            model.emphasizedClockPositions.map { model.screenClock(forModelPosition: $0) }
        )
        let emphasisFill = palette.emphasisFill
        let emphasisStroke = palette.emphasisStroke
        let emphasisLineWidth: CGFloat = 2.4
        // The stroke is centered on the path, so inset the outline by half the line
        // width (radially and angularly) to keep the border fully inside the cell.
        let radialInset = emphasisLineWidth / 2
        let angularInsetDegrees = Double(radialInset / radii.signatureOuter) * 180 / .pi
        for screenPosition in emphasizedScreens where screenPosition != 12 {
            fillSector(
                context: context,
                center: center,
                inner: radii.degreeInner,
                outer: radii.signatureOuter,
                clockPosition: screenPosition,
                color: emphasisFill,
                angularPad: 0
            )
            strokeSector(
                context: context,
                center: center,
                inner: radii.degreeInner + radialInset,
                outer: radii.signatureOuter - radialInset,
                clockPosition: screenPosition,
                color: emphasisStroke,
                lineWidth: emphasisLineWidth,
                angularPad: -angularInsetDegrees
            )
        }
    }

    // MARK: - Labels

    private func signatureCountLabels(center: CGPoint, size: CGFloat) -> some View {
        let baseRadius = size * ((signatureOuterRatio + outerRadiusRatio) / 2)
        return ForEach(1...12, id: \.self) { position in
            let lines = model.displayedSignatureCountLabels[position] ?? []
            let isTonic = visualScreenClock(forModelPosition: position) == 12
            let isEmphasized = model.emphasizedClockPositions.contains(position)
            let isStacked = lines.count > 1
            let radius = isTonic ? baseRadius * raisedScale : baseRadius
            stackedRingLabel(lines: lines)
                .font(LumenoteFont.rounded(
                    size: size * stackedFontRatio(
                        isStacked: isStacked,
                        isTonic: isTonic,
                        stacked: (0.026, 0.022),
                        single: (0.034, 0.030)
                    ),
                    weight: .bold
                ))
                .foregroundStyle(wedgeLabelColor.opacity(0.85))
                .padding(isEmphasized ? 2 : 0)
                .background(
                    Circle()
                        .fill(isEmphasized ? palette.emphasisStroke.opacity(0.9) : .clear)
                )
                .rotationEffect(.degrees(-displayedRotationDegrees))
                .position(point(center: center, radius: radius, angle: angleForCenter(of: position)))
                .zIndex(isTonic || isEmphasized ? 1 : 0)
        }
    }

    private func noteLabels(center: CGPoint, size: CGFloat) -> some View {
        // Midpoint of the note ring (thickest / outermost name band).
        let baseRadius = size * ((outerRadiusRatio + degreeOuterRatio) / 2)
        return ForEach(1...12, id: \.self) { position in
            let lines = (model.displayedOuterSpellings[position] ?? []).map {
                CircleOfFifthsModel.Tonic.formatNoteName($0)
            }
            let isTonic = visualScreenClock(forModelPosition: position) == 12
            let isEmphasized = model.emphasizedClockPositions.contains(position)
            let isStacked = lines.count > 1
            let radius = isTonic ? baseRadius * raisedScale : baseRadius
            stackedRingLabel(lines: lines)
                .font(LumenoteFont.rounded(
                    size: size * stackedFontRatio(
                        isStacked: isStacked,
                        isTonic: isTonic,
                        stacked: (0.040, 0.034),
                        single: (0.055, 0.048)
                    ),
                    weight: .heavy
                ))
                .foregroundStyle(wedgeLabelColor)
                .padding(isEmphasized ? 3 : 0)
                .background(
                    Circle()
                        .fill(isEmphasized ? palette.emphasisStroke.opacity(0.9) : .clear)
                )
                .rotationEffect(.degrees(-displayedRotationDegrees))
                .position(point(center: center, radius: radius, angle: angleForCenter(of: position)))
                .zIndex(isTonic || isEmphasized ? 1 : 0)
        }
    }

    private func relativeMinorLabels(center: CGPoint, size: CGFloat) -> some View {
        let baseRadius = size * ((degreeOuterRatio + degreeInnerRatio) / 2)
        return ForEach(1...12, id: \.self) { position in
            let lines = (model.displayedRelativeMinorSpellings[position] ?? []).map {
                CircleOfFifthsModel.Tonic.formatNoteName($0) + "m"
            }
            let isTonic = visualScreenClock(forModelPosition: position) == 12
            let isStacked = lines.count > 1
            let radius = isTonic ? baseRadius * raisedScale : baseRadius
            stackedRingLabel(lines: lines)
                .font(LumenoteFont.rounded(
                    size: size * stackedFontRatio(
                        isStacked: isStacked,
                        isTonic: isTonic,
                        stacked: (0.024, 0.021),
                        single: (0.032, 0.028)
                    ),
                    weight: .bold
                ))
                .foregroundStyle(wedgeLabelColor)
                .rotationEffect(.degrees(-displayedRotationDegrees))
                .position(point(center: center, radius: radius, angle: angleForCenter(of: position)))
                .zIndex(isTonic ? 1 : 0)
        }
    }

    private func stackedRingLabel(lines: [String]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .multilineTextAlignment(.center)
    }

    private func stackedFontRatio(
        isStacked: Bool,
        isTonic: Bool,
        stacked: (CGFloat, CGFloat),
        single: (CGFloat, CGFloat)
    ) -> CGFloat {
        let pair = isStacked ? stacked : single
        return isTonic ? pair.0 : pair.1
    }

    private func centerHub(size: CGFloat) -> some View {
        let signatures = model.hubKeySignatures
        let isDual = signatures.count > 1
        let hubDiameter = size * degreeInnerRatio * 2
        return Group {
            if model.selectedMode.showsKeySignatureStaff {
                VStack(spacing: isDual ? size * 0.028 : 0) {
                    ForEach(signatures) { signature in
                        KeySignatureStaffView(
                            accidentals: signature.accidentals,
                            staffSpace: size * 0.022,
                            lineColor: .primary
                        )
                    }
                }
                .frame(width: hubDiameter, height: hubDiameter)
                .clipShape(Circle())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(model.sharpsOrFlatsDescription)
            }
        }
    }

    // MARK: - Rotation affordances

    private func rotationAffordances(center: CGPoint, size: CGFloat) -> some View {
        let radius = size * 0.51
        let gStart = -72.0
        let gEnd = -48.0
        let fStart = -108.0
        let fEnd = -132.0
        let labelFont = LumenoteFont.rounded(size: size * 0.026, weight: .bold)
        let labelWidth = size * 0.30
        let labelRadius = radius + size * 0.072

        return ZStack {
            directionalArc(
                center: center,
                radius: radius,
                startDegrees: gStart,
                endDegrees: gEnd,
                clockwise: false,
                lineWidth: size * 0.0055
            )
            arrowHead(
                center: center,
                radius: radius,
                tangentDegrees: gEnd,
                pointingClockwise: true,
                size: size * 0.024
            )
            Text("5도 상행\n(4도 하행)")
                .font(labelFont)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(width: labelWidth)
                .position(point(center: center, radius: labelRadius, angle: .degrees(-60)))

            directionalArc(
                center: center,
                radius: radius,
                startDegrees: fStart,
                endDegrees: fEnd,
                clockwise: true,
                lineWidth: size * 0.0055
            )
            arrowHead(
                center: center,
                radius: radius,
                tangentDegrees: fEnd,
                pointingClockwise: false,
                size: size * 0.024
            )
            Text("4도 상행\n(5도 하행)")
                .font(labelFont)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(width: labelWidth)
                .position(point(center: center, radius: labelRadius, angle: .degrees(-120)))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func directionalArc(
        center: CGPoint,
        radius: CGFloat,
        startDegrees: Double,
        endDegrees: Double,
        clockwise: Bool,
        lineWidth: CGFloat
    ) -> some View {
        Path { path in
            path.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(startDegrees),
                endAngle: .degrees(endDegrees),
                clockwise: clockwise
            )
        }
        .stroke(Color.secondary.opacity(0.55), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
    }

    private func arrowHead(
        center: CGPoint,
        radius: CGFloat,
        tangentDegrees: Double,
        pointingClockwise: Bool,
        size: CGFloat
    ) -> some View {
        let tip = point(center: center, radius: radius, angle: .degrees(tangentDegrees))
        let rotation = tangentDegrees + (pointingClockwise ? 90 : -90)
        return Image(systemName: "arrowtriangle.right.fill")
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(Color.secondary.opacity(0.75))
            .rotationEffect(.degrees(rotation))
            .position(tip)
    }

    // MARK: - Drag rotation

    private func rotationDragGesture(center: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                skipWedgeTap = true
                let angle = atan2(
                    value.location.y - center.y,
                    value.location.x - center.x
                )
                if dragStartAngle == nil {
                    dragStartAngle = angle
                    rotationAtDragStart = displayedRotationDegrees
                }
                guard let start = dragStartAngle else { return }

                var delta = (angle - start) * 180 / .pi
                while delta > 180 { delta -= 360 }
                while delta < -180 { delta += 360 }

                let newDisplayed = rotationAtDragStart + delta
                let position = CircleOfFifthsModel.lydianStartPosition(forRotationDegrees: newDisplayed)
                model.selectTonic(forLydianStart: position)

                // Keep ringRotation on a continuous snapped angle so C↔F never jumps by 330°.
                let snappedRing = ringRotationDegrees + shortestRotationDelta(
                    from: ringRotationDegrees,
                    to: canonicalRotationDegrees(for: position)
                )
                ringRotationDegrees = snappedRing
                dragRotationDegrees = newDisplayed - snappedRing
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.84)) {
                    dragRotationDegrees = 0
                }
                dragStartAngle = nil
                DispatchQueue.main.async {
                    skipWedgeTap = false
                }
            }
    }

    private func wedgeTapGesture(center: CGPoint, size: CGFloat) -> some Gesture {
        SpatialTapGesture()
            .onEnded { event in
                guard !skipWedgeTap else { return }
                selectTonic(at: event.location, center: center, size: size)
            }
    }

    private func selectTonic(at location: CGPoint, center: CGPoint, size: CGFloat) {
        let dx = location.x - center.x
        let dy = location.y - center.y
        let distance = hypot(dx, dy)
        let inner = size * degreeInnerRatio * 0.92
        let outer = size * signatureOuterRatio * raisedScale * 1.08
        guard distance >= inner, distance <= outer else { return }

        var clockDegrees = atan2(dy, dx) * 180 / .pi + 90
        while clockDegrees < 0 { clockDegrees += 360 }
        while clockDegrees >= 360 { clockDegrees -= 360 }

        var screenClock = Int((clockDegrees / 30.0).rounded())
        if screenClock == 0 { screenClock = 12 }
        let modelPosition = model.modelClock(forScreenClock: screenClock)
        model.selectTonic(forLydianStart: modelPosition)
    }

    /// Screen wedge occupied by a model-clock note under the current displayed rotation.
    private func visualScreenClock(forModelPosition position: Int) -> Int {
        let visualTonic = CircleOfFifthsModel.lydianStartPosition(
            forRotationDegrees: displayedRotationDegrees
        )
        return CircleOfFifthsModel.normalizedClock(position - visualTonic)
    }

    /// Canonical alignment for a clock position in (−360, 0] (C/B♯ → 0, G → −30, …, F → −330).
    private func canonicalRotationDegrees(for lydianStartPosition: Int) -> Double {
        -Double(lydianStartPosition % 12) * 30.0
    }

    /// Shortest signed delta on the circle from `from` toward an angle equivalent to `to`.
    private func shortestRotationDelta(from: Double, to: Double) -> Double {
        let fromN = normalizedDegrees(from)
        let toN = normalizedDegrees(to)
        var delta = toN - fromN
        if delta > 180 { delta -= 360 }
        if delta <= -180 { delta += 360 }
        return delta
    }

    private func normalizedDegrees(_ degrees: Double) -> Double {
        var value = degrees.truncatingRemainder(dividingBy: 360)
        if value < 0 { value += 360 }
        return value
    }

    // MARK: - Drawing helpers

    private struct RingRadii {
        /// Outermost: sharp/flat counts.
        var signatureOuter: CGFloat
        var signatureInner: CGFloat
        /// Note names.
        var noteOuter: CGFloat
        var noteInner: CGFloat
        /// Innermost: degree labels.
        var degreeOuter: CGFloat
        var degreeInner: CGFloat
    }

    private func ringRadii(size: CGFloat, scale: CGFloat) -> RingRadii {
        RingRadii(
            signatureOuter: size * signatureOuterRatio * scale,
            signatureInner: size * outerRadiusRatio * scale,
            noteOuter: size * outerRadiusRatio * scale,
            noteInner: size * degreeOuterRatio * scale,
            degreeOuter: size * degreeOuterRatio * scale,
            degreeInner: size * degreeInnerRatio * scale
        )
    }

    private func fillSector(
        context: GraphicsContext,
        center: CGPoint,
        inner: CGFloat,
        outer: CGFloat,
        clockPosition: Int,
        color: Color,
        angularPad: Double
    ) {
        let startAngle = angleForLeadingEdge(of: clockPosition) - .degrees(angularPad)
        let endAngle = angleForLeadingEdge(of: CircleOfFifthsModel.normalizedClock(clockPosition + 1))
            + .degrees(angularPad)
        var path = Path()
        path.addArc(center: center, radius: outer, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.addArc(center: center, radius: inner, startAngle: endAngle, endAngle: startAngle, clockwise: true)
        path.closeSubpath()
        context.fill(path, with: .color(color))
    }

    private func strokeSector(
        context: GraphicsContext,
        center: CGPoint,
        inner: CGFloat,
        outer: CGFloat,
        clockPosition: Int,
        color: Color,
        lineWidth: CGFloat,
        angularPad: Double
    ) {
        let startAngle = angleForLeadingEdge(of: clockPosition) - .degrees(angularPad)
        let endAngle = angleForLeadingEdge(of: CircleOfFifthsModel.normalizedClock(clockPosition + 1))
            + .degrees(angularPad)
        var path = Path()
        path.addArc(center: center, radius: outer, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.addArc(center: center, radius: inner, startAngle: endAngle, endAngle: startAngle, clockwise: true)
        path.closeSubpath()
        context.stroke(path, with: .color(color), lineWidth: lineWidth)
    }

    // MARK: - Geometry helpers

    private func angleForLeadingEdge(of clockPosition: Int) -> Angle {
        let clockDegrees = Double(clockPosition) * 30.0 - 15.0
        return .degrees(clockDegrees - 90)
    }

    private func angleForCenter(of clockPosition: Int) -> Angle {
        let clockDegrees = Double(clockPosition) * 30.0
        return .degrees(clockDegrees - 90)
    }

    private func point(center: CGPoint, radius: CGFloat, angle: Angle) -> CGPoint {
        CGPoint(
            x: center.x + radius * CGFloat(cos(angle.radians)),
            y: center.y + radius * CGFloat(sin(angle.radians))
        )
    }
}

// MARK: - Raised tonic wedge

private struct RaisedTonicWedgeView: View {
    let noteColor: Color
    let ringStroke: Color
    let signatureOuterRatio: CGFloat
    let outerRadiusRatio: CGFloat
    let degreeOuterRatio: CGFloat
    let degreeInnerRatio: CGFloat
    let raisedScale: CGFloat
    let angularPadDegrees: Double
    var isEmphasized: Bool = false
    var emphasisFill: Color = .clear
    var emphasisStroke: Color = .clear
    /// Contact shadow needs more weight on a dark background to still read as raised.
    var shadowOpacity: Double = 0.2

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                // Soft contact shadow.
                AnnularSector(
                    clockPosition: 12,
                    innerRatio: degreeInnerRatio * raisedScale,
                    outerRatio: signatureOuterRatio * raisedScale,
                    angularPadDegrees: angularPadDegrees
                )
                .fill(Color.black.opacity(shadowOpacity))
                .offset(y: size * 0.01)
                .blur(radius: size * 0.014)

                // Outer → inner: signature, note, degree (degree shares note color).
                band(
                    innerRatio: outerRadiusRatio * raisedScale,
                    outerRatio: signatureOuterRatio * raisedScale,
                    fill: noteColor,
                    strokeWidth: 1.6
                )
                band(
                    innerRatio: degreeOuterRatio * raisedScale,
                    outerRatio: outerRadiusRatio * raisedScale,
                    fill: noteColor,
                    strokeWidth: 1.6
                )
                band(
                    innerRatio: degreeInnerRatio * raisedScale,
                    outerRatio: degreeOuterRatio * raisedScale,
                    fill: noteColor,
                    strokeWidth: 1.1
                )

                if isEmphasized {
                    // Inset the stroke by half the line width so the border stays
                    // inside the raised wedge outline (stroke is path-centered).
                    let emphasisLineWidth: CGFloat = 2.4
                    let insetRatio = emphasisLineWidth / 2 / size
                    let angularInsetDegrees = Double(
                        (emphasisLineWidth / 2) / (size * signatureOuterRatio * raisedScale)
                    ) * 180 / .pi

                    AnnularSector(
                        clockPosition: 12,
                        innerRatio: degreeInnerRatio * raisedScale,
                        outerRatio: signatureOuterRatio * raisedScale,
                        angularPadDegrees: angularPadDegrees
                    )
                    .fill(emphasisFill)
                    .overlay(
                        AnnularSector(
                            clockPosition: 12,
                            innerRatio: degreeInnerRatio * raisedScale + insetRatio,
                            outerRatio: signatureOuterRatio * raisedScale - insetRatio,
                            angularPadDegrees: angularPadDegrees - angularInsetDegrees
                        )
                        .stroke(emphasisStroke, lineWidth: emphasisLineWidth)
                    )
                }
            }
            .shadow(color: .black.opacity(0.1), radius: size * 0.02, x: 0, y: size * 0.012)
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .allowsHitTesting(false)
    }

    private func band(
        innerRatio: CGFloat,
        outerRatio: CGFloat,
        fill: Color,
        strokeWidth: CGFloat
    ) -> some View {
        let shape = AnnularSector(
            clockPosition: 12,
            innerRatio: innerRatio,
            outerRatio: outerRatio,
            angularPadDegrees: angularPadDegrees
        )
        return shape
            .fill(fill)
            .overlay(shape.stroke(ringStroke, lineWidth: strokeWidth))
    }
}

private struct AnnularSector: Shape {
    var clockPosition: Int
    var innerRatio: CGFloat
    var outerRatio: CGFloat
    var angularPadDegrees: Double

    func path(in rect: CGRect) -> Path {
        let size = min(rect.width, rect.height)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let inner = size * innerRatio
        let outer = size * outerRatio

        let leading = Double(clockPosition) * 30.0 - 15.0 - 90.0 - angularPadDegrees
        let trailing = Double(CircleOfFifthsModel.normalizedClock(clockPosition + 1)) * 30.0 - 15.0 - 90.0
            + angularPadDegrees

        var path = Path()
        path.addArc(
            center: center,
            radius: outer,
            startAngle: .degrees(leading),
            endAngle: .degrees(trailing),
            clockwise: false
        )
        path.addArc(
            center: center,
            radius: inner,
            startAngle: .degrees(trailing),
            endAngle: .degrees(leading),
            clockwise: true
        )
        path.closeSubpath()
        return path
    }
}

#Preview {
    CircleOfFifthsRingView(model: CircleOfFifthsModel())
        .lumenotePalette()
        .padding()
}
