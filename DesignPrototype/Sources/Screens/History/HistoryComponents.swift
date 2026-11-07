import SwiftUI

// History's own pieces, each with the look's signature where the SPECs define one:
// the month heat strip (A lit bulbs · B family bars · C punches), the new-best count mark,
// the route drawing, the hero ring / stamp, and small badges.

// MARK: - Month heat strip

/// Every day of a month in one row, week-spaced: A lights cells like scoreboard bulbs (by
/// intensity), B stacks each day's families as a bar, C punches trained days.
struct HistoryMonthStrip: View {
    var days: [CalendarDay]
    var signals: [Date: HistoryDaySignal]
    var animated = true
    @State private var shown = false
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .caption2) private var cellHeightA: CGFloat = 30
    @ScaledMetric(relativeTo: .caption2) private var barAreaB: CGFloat = 40
    @ScaledMetric(relativeTo: .caption2) private var labelHeight: CGFloat = 13

    private var height: CGFloat {
        switch look.id {
        case .floodlight: min(cellHeightA, 40)
        case .anatomy: min(barAreaB, 52)
        case .paper, .carbon: 18
        }
    }

    var body: some View {
        let on = shown || !animated || reduceMotion
        // One column per day: the cell, and under week starts its day number (an overlay, so a
        // label never widens its column and every number sits under its own day).
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                VStack(spacing: 6) {
                    cell(day, index: index, on: on)
                        .frame(maxWidth: .infinity)
                        .frame(height: height, alignment: .bottom)
                    Color.clear
                        .frame(height: labelHeight)
                        .overlay(alignment: .top) {
                            if index == 0 || isWeekStart(day) {
                                Text("\(day.dayNumber)")
                                    .font(.system(.caption2, weight: .semibold).monospacedDigit())
                                    .foregroundStyle(look.textTertiary)
                                    .fixedSize()
                            }
                        }
                }
                .padding(.leading, isWeekStart(day) && index > 0 ? 3 : 0)
            }
        }
        .onAppear {
            guard !shown else { return }
            if reduceMotion || !animated { shown = true; return }
            withAnimation(.easeOut(duration: 0.5).delay(0.15)) { shown = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    private var spoken: String {
        let trained = days.filter { $0.intensity > 0 }
        guard let first = days.first else { return "" }
        let month = Format.monthName(first.date)
        if trained.isEmpty { return "\(month), no workouts yet" }
        return "\(month), trained on " + trained.map { "\($0.dayNumber)" }.joined(separator: ", ")
    }

    private func isWeekStart(_ day: CalendarDay) -> Bool {
        Calendar.app.component(.weekday, from: day.date) == Calendar.app.firstWeekday
    }

    @ViewBuilder
    private func cell(_ day: CalendarDay, index: Int, on: Bool) -> some View {
        switch look.id {
        case .floodlight: bulb(day, index: index, on: on)
        case .anatomy: bar(day, index: index, on: on)
        case .paper, .carbon: punch(day, index: index, on: on)
        }
    }

    // A: a bulb per day, lit brighter with more work.
    private func bulb(_ day: CalendarDay, index: Int, on: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 3, style: .continuous)
        let levels: [Double] = [0, 0.42, 0.62, 0.82, 1]
        return shape
            .fill(day.intensity > 0 ? look.done.opacity(on ? levels[min(4, day.intensity)] : 0.08)
                  : (day.isFuture || day.isToday ? Color.clear : look.surfaceRaised))
            .overlay {
                if day.isToday && day.intensity == 0 {
                    shape.strokeBorder(look.textPrimary.opacity(0.62), style: StrokeStyle(lineWidth: 1.2, dash: [2.5, 2]))
                } else if day.isFuture {
                    shape.strokeBorder(look.hairline, lineWidth: 1)
                }
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.22).delay(Double(index) * 0.018), value: on)
    }

    // B: the day's families stacked, height by sets; cardio adds a heart-rate cap.
    @ViewBuilder
    private func bar(_ day: CalendarDay, index: Int, on: Bool) -> some View {
        if day.intensity > 0, let signal = signals[Calendar.app.startOfDay(for: day.date)] {
            let total = max(1, signal.families.reduce(0) { $0 + $1.sets })
            let barHeight = max(10, min(height, CGFloat(day.sets) / 28 * height))
            let cardioHeight: CGFloat = signal.hasCardio ? (signal.hasLifting ? 6 : 14) : 0
            let liftHeight = signal.hasLifting ? barHeight : 0
            VStack(spacing: 1.5) {
                if signal.hasCardio {
                    Rectangle().fill(look.heartRate).frame(height: cardioHeight)
                }
                if liftHeight > 0 {
                    VStack(spacing: 1.5) {
                        ForEach(signal.families.reversed()) { count in
                            Rectangle().fill(look.family(count.family))
                                .frame(height: max(2, (liftHeight - CGFloat(signal.families.count - 1) * 1.5)
                                                   * CGFloat(count.sets) / CGFloat(total)))
                        }
                    }
                }
            }
            .frame(width: 6)
            .clipShape(Capsule())
            .scaleEffect(x: 1, y: on ? 1 : 0.02, anchor: .bottom)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.5).delay(Double(index) * 0.02), value: on)
        } else if day.isToday {
            Circle().strokeBorder(look.textSecondary, style: StrokeStyle(lineWidth: 1, dash: [2, 1.5])).frame(width: 9, height: 9)
        } else {
            Circle().fill(day.isFuture ? look.dayDotFuture : look.dayDotPast).frame(width: 4, height: 4)
        }
    }

    // C: punched (ink), missed (a thin ring), today (cobalt dashed), ahead (dotted).
    @ViewBuilder
    private func punch(_ day: CalendarDay, index: Int, on: Bool) -> some View {
        // Up to 11 pt, shrinking with the column so a 31-day month always fits the card.
        Group {
            if day.intensity > 0 {
                Circle().fill(look.done)
                    .scaleEffect(on ? 1 : 1.6)
                    .opacity(on ? 1 : 0)
                    .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.6).delay(Double(index) * 0.02), value: on)
            } else if day.isToday {
                Circle().strokeBorder(look.actionText, style: StrokeStyle(lineWidth: 1.6, dash: [2, 1.6]))
            } else if day.isFuture {
                Circle().strokeBorder(look.textSecondary.opacity(0.7), style: StrokeStyle(lineWidth: 1.1, dash: [1, 1.8]))
            } else {
                Circle().strokeBorder(look.textSecondary, lineWidth: 1.1)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 11, maxHeight: 11)
        .frame(maxHeight: .infinity)
    }
}

// MARK: - New-best count mark

/// "New bests in this workout": A an outlined plate with a burst and the count; B a pearl
/// pill with a star; C the yellow highlighter sticker with its words (C's one term).
struct HistoryPRMark: View {
    var count: Int
    @Environment(\.look) private var look

    var body: some View {
        Group {
            switch look.id {
            case .floodlight:
                HStack(spacing: 3) {
                    Image(systemName: "burst.fill").font(.system(.caption2, weight: .bold))
                    Text("\(count)").font(.system(.caption, weight: .heavy).monospacedDigit())
                }
                .foregroundStyle(look.positive)
                .padding(.horizontal, 6)
                .frame(minHeight: 20)
                .overlay {
                    RoundedRectangle(cornerRadius: look.radius.badge, style: .continuous)
                        .strokeBorder(look.positive, lineWidth: 1.5)
                }
            case .anatomy:
                HStack(spacing: 3) {
                    Image(systemName: "star.fill").font(.system(.caption2, weight: .heavy)).imageScale(.small)
                    Text("\(count)").font(look.font.badge.monospacedDigit())
                }
                .foregroundStyle(look.textPrimary)
                .padding(.horizontal, 7)
                .frame(minHeight: 22)
                .background(look.positive.opacity(0.14), in: Capsule())
                .overlay { Capsule().strokeBorder(look.positive.opacity(0.22), lineWidth: 1) }
            case .paper, .carbon:
                Text(count == 1 ? "New best" : "\(count) new bests")
                    .font(look.font.badge)
                    .foregroundStyle(look.onPositive)
                    .padding(.horizontal, 6).padding(.top, 1).padding(.bottom, 2)
                    .background(look.positive, in: RoundedRectangle(cornerRadius: look.radius.badge, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: look.radius.badge, style: .continuous)
                            .strokeBorder(look.onPositive, lineWidth: 1.5)
                    }
                    .rotationEffect(.degrees(-3))
            }
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(count == 1 ? "1 new best" : "\(count) new bests")
    }
}

// MARK: - Small badges

/// A quiet text badge: the unit ("kg", "kg + lb") or a load type ("Assisted").
struct HistoryTextBadge: View {
    var text: String
    @Environment(\.look) private var look

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(.caption, design: look.id == .anatomy ? .rounded : .default, weight: .bold))
            .foregroundStyle(look.textSecondary)
            .padding(.horizontal, 7)
            .frame(minHeight: 20)
            .overlay {
                Capsule().strokeBorder(look.id.isPaperClub ? look.textSecondary : look.hairline.opacity(2.2),
                                       lineWidth: look.id.isPaperClub ? 1.2 : 1)
            }
            .fixedSize()
    }
}

/// "Edited": the D47 mark on a row.
struct HistoryEditedMark: View {
    @Environment(\.look) private var look
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "pencil.circle").font(.system(.caption, weight: .semibold))
            Text("Edited").font(.system(.caption, weight: .medium))
        }
        .foregroundStyle(look.textSecondary)
        .fixedSize()
    }
}

/// Superset letter ("A", "B") beside an exercise name.
struct HistorySupersetLetter: View {
    var letter: String
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .footnote) private var side: CGFloat = 24

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: look.id == .anatomy ? side / 2 : 6, style: .continuous)
        Text(letter)
            .font(.system(.footnote, design: look.id == .anatomy ? .rounded : .default, weight: .heavy))
            .foregroundStyle(look.textPrimary)
            .frame(width: side, height: side)
            .background(look.id == .anatomy ? look.controlFill : .clear, in: shape)
            .overlay {
                if look.id != .anatomy {
                    shape.strokeBorder(look.id.isPaperClub ? look.outline : look.textPrimary.opacity(0.42), lineWidth: 1.5)
                }
            }
            .accessibilityLabel("Superset \(letter)")
    }
}

/// The face of CardIconButton, for use as a Menu label (the ellipsis options menu).
struct HistoryIconFace: View {
    var symbol: String
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .body) private var discB: CGFloat = 38
    @ScaledMetric(relativeTo: .body) private var discC: CGFloat = 36
    @ScaledMetric(relativeTo: .body) private var bareA: CGFloat = 32

    var body: some View {
        let visual: CGFloat = switch look.id {
        case .floodlight: bareA
        case .anatomy: discB
        case .paper, .carbon: discC
        }
        let outset = max(0, (44 - visual) / 2)
        Group {
            switch look.id {
            case .floodlight:
                Image(systemName: symbol).font(.system(.body, weight: .semibold)).foregroundStyle(look.textSecondary)
            case .anatomy:
                Image(systemName: symbol).font(.system(.subheadline, weight: .semibold)).foregroundStyle(look.textPrimary)
                    .frame(width: visual, height: visual).background(look.controlFill, in: Circle())
            case .paper, .carbon:
                Image(systemName: symbol).font(.system(.footnote, weight: .bold)).foregroundStyle(look.textPrimary)
                    .frame(width: visual, height: visual).overlay { Circle().strokeBorder(look.outline, lineWidth: 1.5) }
            }
        }
        .frame(width: visual, height: visual)
        .padding(outset)
        .contentShape(Rectangle())
        .padding(-outset)
    }
}

/// A dashed "make one" row (Add Exercise…): the look's create treatment.
struct HistoryMakeRow: View {
    var title: String
    var symbol: String = "plus"
    var action: () -> Void
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .headline) private var height: CGFloat = 52

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if look.id == .floodlight {
                    Image(systemName: symbol).font(.system(.body, weight: .semibold))
                } else {
                    IconDisc(symbol: symbol, size: 30, context: .make)
                }
                Text(title).font(look.id == .anatomy ? look.font.button : .system(.body, weight: .semibold))
            }
            .foregroundStyle(look.textPrimary)
            .frame(maxWidth: .infinity, minHeight: height)
            .dashedOutline(look.id.isPaperClub ? look.outline : look.dash, radius: look.radius.panel,
                           lineWidth: look.id.isPaperClub ? 2 : 1.5, dash: [6, 4])
            .contentShape(Rectangle())
        }
        .buttonStyle(.lookPressable)
    }
}

// MARK: - Route drawing (routes appear only after Finish / in History)

/// Projects route points into a rect (equirectangular with cos-latitude), keeping aspect.
struct HistoryRouteProjection {
    var points: [RoutePoint]
    var rect: CGRect

    func project() -> [CGPoint] {
        guard let first = points.first else { return [] }
        let k = cos(first.latitude * .pi / 180)
        let xs = points.map { $0.longitude * k }, ys = points.map { $0.latitude }
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else { return [] }
        let w = max(maxX - minX, 1e-9), h = max(maxY - minY, 1e-9)
        let scale = min(rect.width / w, rect.height / h)
        let ox = rect.minX + (rect.width - w * scale) / 2, oy = rect.minY + (rect.height - h * scale) / 2
        return zip(xs, ys).map { x, y in CGPoint(x: ox + (x - minX) * scale, y: oy + (maxY - y) * scale) }
    }
}

/// The finished route: one stroke per GPS portion (never joined across pauses), a start ring,
/// a finish dot and optional split markers. A: a floodlight line on the stand; B: heart-rate red
/// on the card; C: an ink line on a dotted notebook ground.
struct HistoryRouteMap: View {
    var route: [RoutePoint]
    /// Distances (in metres) where split markers go, with their labels.
    var markers: [(meters: Double, label: String)] = []
    var lineWidth: CGFloat = 4
    var inset: CGFloat = 24
    var showsGround = true
    @State private var drawn: CGFloat = 0
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let rect = CGRect(origin: .zero, size: geo.size).insetBy(dx: inset, dy: inset)
            let points = HistoryRouteProjection(points: route, rect: rect).project()
            ZStack {
                if showsGround { ground(size: geo.size) }
                routePath(points).trim(from: 0, to: drawn)
                    .stroke(look.historyRouteColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                if let start = points.first {
                    Circle().fill(look.historyCardFill(onSheet: false))
                        .overlay { Circle().strokeBorder(look.historyRouteColor, lineWidth: max(2, lineWidth * 0.6)) }
                        .frame(width: lineWidth * 3.2, height: lineWidth * 3.2)
                        .position(start)
                }
                if let end = points.last, drawn >= 1 {
                    Circle().fill(look.historyRouteColor)
                        .overlay { Circle().strokeBorder(look.historyCardFill(onSheet: false), lineWidth: 2) }
                        .frame(width: lineWidth * 3.4, height: lineWidth * 3.4)
                        .position(end)
                        .transition(.scale)
                }
                ForEach(Array(markerPoints(points).enumerated()), id: \.offset) { _, marker in
                    Text(marker.label)
                        .font(.system(.caption2, weight: .heavy).monospacedDigit())
                        .foregroundStyle(markerText)
                        .frame(width: 20, height: 20)
                        .background(markerFill, in: Circle())
                        .overlay { Circle().strokeBorder(look.historyCardFill(onSheet: false), lineWidth: 1.5) }
                        .position(marker.point)
                        .opacity(drawn >= 1 ? 1 : 0)
                }
            }
        }
        .onAppear {
            guard drawn == 0 else { return }
            if reduceMotion || markers.isEmpty { drawn = 1; return }
            withAnimation(.easeInOut(duration: 0.7).delay(0.1)) { drawn = 1 }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Recorded cardio route")
    }

    private var markerFill: Color {
        switch look.id {
        case .floodlight: look.done
        case .anatomy: look.textPrimary
        case .paper, .carbon: look.textPrimary
        }
    }
    private var markerText: Color {
        switch look.id {
        case .floodlight: look.onDone
        case .anatomy: look.onAction
        case .paper, .carbon: look.surface
        }
    }

    private func routePath(_ points: [CGPoint]) -> Path {
        var path = Path()
        for (i, point) in points.enumerated() {
            if i == 0 || route[i].portion != route[i - 1].portion { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }

    /// Markers placed by distance along the route (scaled to the route's own length).
    private func markerPoints(_ points: [CGPoint]) -> [(point: CGPoint, label: String)] {
        guard route.count > 1, !markers.isEmpty else { return [] }
        var cumulative: [Double] = [0]
        for i in 1..<route.count {
            let step = route[i].portion == route[i - 1].portion ? Derived.meters(route[i - 1], route[i]) : 0
            cumulative.append(cumulative[i - 1] + step)
        }
        guard let total = cumulative.last, total > 0, let last = markers.last?.meters, last > 0 else { return [] }
        let scale = total / max(last, markers.map(\.meters).max() ?? last)
        return markers.compactMap { marker in
            let target = marker.meters * scale
            guard let i = cumulative.firstIndex(where: { $0 >= target }), i > 0 else { return nil }
            let a = cumulative[i - 1], b = cumulative[i]
            let t = b > a ? (target - a) / (b - a) : 0
            let p = CGPoint(x: points[i - 1].x + (points[i].x - points[i - 1].x) * t,
                            y: points[i - 1].y + (points[i].y - points[i - 1].y) * t)
            return (p, marker.label)
        }
    }

    @ViewBuilder
    private func ground(size: CGSize) -> some View {
        Canvas { context, size in
            let step: CGFloat = look.id.isPaperClub ? 16 : 22
            switch look.id {
            case .paper, .carbon:
                var y = step / 2
                while y < size.height {
                    var x = step / 2
                    while x < size.width {
                        context.fill(Path(ellipseIn: CGRect(x: x - 0.9, y: y - 0.9, width: 1.8, height: 1.8)),
                                     with: .color(look.textSecondary.opacity(0.35)))
                        x += step
                    }
                    y += step
                }
            case .floodlight, .anatomy:
                var grid = Path()
                var x = step
                while x < size.width { grid.move(to: CGPoint(x: x, y: 0)); grid.addLine(to: CGPoint(x: x, y: size.height)); x += step }
                var y = step
                while y < size.height { grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: size.width, y: y)); y += step }
                context.stroke(grid, with: .color(look.wash(look.id == .floodlight ? 0.045 : 0.035)), lineWidth: 1)
            }
        }
    }
}

// MARK: - Hero ring / stamp (the workout's working-set count)

/// The detail hero. Working sets only (warmups stay out, as in the Finish ring), so a finished
/// ring is always fully lit: A one segment per set in its family colour, B family arcs, C the
/// rubber stamp. The centre carries the number in every look.
struct HistoryHeroRing: View {
    /// Working sets in workout order, with their family (nil = no family, e.g. Core).
    var sets: [MuscleFamily?]
    var size: CGFloat = 104
    @State private var drawn = false
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var total: Int { sets.count }

    var body: some View {
        Group {
            switch look.id {
            case .floodlight: floodlight
            case .anatomy: anatomy
            case .paper, .carbon: stamp
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            guard !drawn else { return }
            if reduceMotion { drawn = true } else { withAnimation { drawn = true } }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Format.count(total, "working set"))
    }

    private var label: String { total == 1 ? "working set" : "working sets" }

    private func centre(inner: CGFloat) -> some View {
        VStack(spacing: 0) {
            Text("\(total)").font(look.font.bigNumber).foregroundStyle(look.textPrimary)
                .minimumScaleFactor(0.6).lineLimit(1)
            Text(label)
                .font(.system(.caption2, design: look.id == .anatomy ? .rounded : .default, weight: .semibold))
                .foregroundStyle(look.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: inner)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    /// A family-less working set (Core) is lit in ink, never left grey.
    private func color(_ family: MuscleFamily?) -> Color {
        family.map { look.family($0) } ?? look.textPrimary
    }

    private var floodlight: some View {
        let width = size * 0.085
        return ZStack {
            if total > 0 && total <= 40 {
                ForEach(0..<total, id: \.self) { index in
                    let step = 1.0 / Double(total)
                    RingArc(start: Double(index) * step + step * 0.13, end: Double(index + 1) * step - step * 0.13)
                        .stroke(drawn ? color(sets[index]) : look.ringTrack, style: StrokeStyle(lineWidth: width))
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.16).delay(Double(index) * 0.024), value: drawn)
                }
            } else {
                runs(width: width, cap: .butt, gap: 0.004)
            }
            centre(inner: size * 0.66)
        }
        .padding(width / 2)
    }

    private var anatomy: some View {
        let width = size * 0.09
        return ZStack {
            // The track shows only while the arcs draw in.
            Circle().stroke(look.ringTrack, lineWidth: width).opacity(drawn ? 0 : 1)
            runs(width: width, cap: .round, gap: 0.035)
            centre(inner: size * 0.64)
        }
        .padding(width / 2 + 2)
    }

    /// Consecutive runs of the same family.
    private func runs(width: CGFloat, cap: CGLineCap, gap: Double) -> some View {
        var groups: [(color: Color, count: Int, key: String)] = []
        for family in sets {
            let key = family?.rawValue ?? "none"
            if let last = groups.last, last.key == key {
                groups[groups.count - 1].count += 1
            } else {
                groups.append((color(family), 1, key))
            }
        }
        let working = max(1, groups.reduce(0) { $0 + $1.count })
        let fractions = groups.map { Double($0.count) / Double(working) }
        let starts = fractions.indices.map { i in fractions[..<i].reduce(0, +) }
        return ZStack {
            ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
                let start = starts[index] + gap / 2
                let end = max(start + 0.001, starts[index] + fractions[index] - gap / 2)
                RingArc(start: start, end: drawn ? end : start)
                    .stroke(group.color, style: StrokeStyle(lineWidth: width, lineCap: cap))
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.6).delay(Double(index) * 0.12), value: drawn)
            }
        }
    }

    /// C: the rubber stamp (−8°) as the status mark: a thick ink ring, a dashed ring inside,
    /// and the workout's number in the middle (the date already sits beside it).
    private var stamp: some View {
        let ring = size * 0.045
        return ZStack {
            Circle().fill(look.surface).padding(ring / 2)
            Circle().stroke(look.textPrimary, lineWidth: ring).padding(ring / 2)
            Circle()
                .stroke(look.textPrimary, style: StrokeStyle(lineWidth: size * 0.016, dash: [3, 3.2]))
                .padding(size * 0.096)
            VStack(spacing: 0) {
                Text("\(total)")
                    .font(look.font.heroNumber)
                    .minimumScaleFactor(0.6).lineLimit(1)
                // Whole words only: "WORKING / SETS", or just "SETS" when large text leaves
                // no room (never a hyphenated "WORK-ING").
                ViewThatFits {
                    VStack(spacing: 0) {
                        ForEach(label.uppercased().split(separator: " ").map(String.init), id: \.self) { Text($0) }
                    }
                    .fixedSize()
                    Text(label.uppercased().split(separator: " ").last.map(String.init) ?? "").fixedSize()
                }
                .font(.system(.caption2, weight: .heavy)).tracking(0.8)
            }
            .frame(maxWidth: size * 0.6)
            .foregroundStyle(look.textPrimary)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
        .scaleEffect(drawn || reduceMotion ? 1 : 1.4)
        .opacity(drawn || reduceMotion ? 1 : 0)
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.6), value: drawn)
        .rotationEffect(.degrees(-8))
    }
}

// MARK: - Empty mark (H07)

/// The look's own "nothing yet" mark: A an unlit segmented ring, B an empty ring track,
/// C an open (dashed) stamp. The History symbol sits in the middle.
struct HistoryEmptyMark: View {
    var size: CGFloat = 132
    @Environment(\.look) private var look

    var body: some View {
        ZStack {
            switch look.id {
            case .floodlight:
                let width = size * 0.075
                ForEach(0..<24, id: \.self) { index in
                    let step = 1.0 / 24
                    RingArc(start: Double(index) * step + step * 0.14, end: Double(index + 1) * step - step * 0.14)
                        .stroke(look.ringTrack, style: StrokeStyle(lineWidth: width))
                }
                .padding(width / 2)
            case .anatomy:
                Circle().stroke(look.ringTrack, lineWidth: size * 0.085).padding(size * 0.045)
            case .paper, .carbon:
                ZStack {
                    Circle().strokeBorder(look.dash, style: StrokeStyle(lineWidth: size * 0.04, dash: [7, 5]))
                    Circle().strokeBorder(look.dash, style: StrokeStyle(lineWidth: size * 0.016, dash: [3, 3.2]))
                        .padding(size * 0.1)
                }
                .rotationEffect(.degrees(-8))
            }
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: size * 0.3, weight: .semibold))
                .foregroundStyle(look.textTertiary)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Barbell glyph

/// A barbell (bar, collars and plates), so "Barbell" no longer borrows the Workout tab's
/// strength-training figure. Scales with the text beside it.
struct HistoryBarbellGlyph: View {
    @ScaledMetric(relativeTo: .footnote) private var width: CGFloat = 20

    var body: some View {
        HistoryBarbellShape()
            .frame(width: width, height: width * 0.6)
            .accessibilityHidden(true)
    }
}

struct HistoryBarbellShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height, mid = rect.midY
        let barH = max(1.4, h * 0.14)
        path.addRoundedRect(in: CGRect(x: rect.minX, y: mid - barH / 2, width: w, height: barH),
                            cornerSize: CGSize(width: barH / 2, height: barH / 2))
        func plate(_ x: CGFloat, _ pw: CGFloat, _ ph: CGFloat) {
            path.addRoundedRect(in: CGRect(x: rect.minX + x, y: mid - ph / 2, width: pw, height: ph),
                                cornerSize: CGSize(width: pw * 0.35, height: pw * 0.35))
        }
        // Outer small plate, inner big plate, then the collar — mirrored.
        for (x, pw, ph) in [(w * 0.07, w * 0.09, h * 0.62), (w * 0.17, w * 0.12, h), (w * 0.3, w * 0.05, h * 0.36)] {
            plate(x, pw, ph)
            plate(w - x - pw, pw, ph)
        }
        return path
    }
}

// MARK: - Flow layout (marks wrap instead of widening the row)

/// Places children left to right and wraps to a new line when the width runs out. Sizing and
/// placement share one line-breaking pass (at the proposed width, with a rounding tolerance),
/// so a row never places more lines than it measured.
struct HistoryFlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 6

    private struct Line { var items: [(index: Int, size: CGSize, x: CGFloat)] = []; var height: CGFloat = 0; var width: CGFloat = 0 }

    private func lines(_ subviews: Subviews, width: CGFloat) -> [Line] {
        var result: [Line] = [Line()]
        for (index, view) in subviews.enumerated() {
            let size = view.sizeThatFits(.unspecified)
            var line = result[result.count - 1]
            let x = line.items.isEmpty ? 0 : line.width + spacing
            if !line.items.isEmpty && x + size.width > width + 0.5 {
                result.append(Line())
                line = Line()
                line.items.append((index, size, 0))
                line.width = size.width
                line.height = size.height
            } else {
                line.items.append((index, size, x))
                line.width = x + size.width
                line.height = max(line.height, size.height)
            }
            result[result.count - 1] = line
        }
        return result.filter { !$0.items.isEmpty }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let all = lines(subviews, width: width)
        let height = all.reduce(0) { $0 + $1.height } + CGFloat(max(0, all.count - 1)) * lineSpacing
        let widest = all.map(\.width).max() ?? 0
        return CGSize(width: width.isFinite ? width : widest, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for line in lines(subviews, width: proposal.width ?? bounds.width) {
            for item in line.items {
                subviews[item.index].place(at: CGPoint(x: bounds.minX + item.x, y: y + (line.height - item.size.height) / 2),
                                           proposal: ProposedViewSize(item.size))
            }
            y += line.height + lineSpacing
        }
    }
}
