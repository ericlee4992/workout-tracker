import SwiftData
import SwiftUI

// C02–C04 (Floodlight ticket 12): the cardio focus of the live workout, in plain Floodlight.
//
// Rows of the live list (the Lifting | Cardio switch and the add block stay the live screen's):
//  • recording  → disc · name · status pill; the ring (the one bold element); the GPS status when
//                 something is wrong (decision 2); the figures table; the heart-rate plate.
//  • paused     → "Paused 0:42" (the pill inverts), the lit segments go hollow, a blinking pause
//                 glyph over the still clock; the tray's filled command is Resume.
//  • GPS lost   → the "Location unavailable." plate; a distance ring stalls at a slashed pin.
//                 Never a map while recording (routes appear after Finish / in History).
//  • nothing live → the first planned target with its Start (D57), then ended-segment cards; or
//                 the empty state.
// The tray (Pause / Resume · End Cardio) is pinned at the thumb by the live screen.

struct CardioWorkoutSection: View {
    var workout: Workout
    var recorder: CardioRecorder
    var monitor: HeartRateMonitor?
    /// Opens Max Heart Rate (the plate's "Set up zones").
    var editMaxHeartRate: () -> Void = {}
    /// Starts a planned target (the live screen's own path, D57).
    var startPlanned: (PlannedCardio) -> Void = { _ in }
    var canStartPlanned = true
    @Query(sort: \CardioSegment.startedAt, order: .reverse) private var allSegments: [CardioSegment]
    @Environment(\.look) private var look

    var body: some View {
        let live = workout.unfinishedCardio
        let ended = Array(workout.orderedCardio.filter { $0.endedAt != nil }.reversed())
        let plans = live == nil ? workout.plannedCardio.filter { workout.canStart($0) } : []
        Group {
            if let live {
                CardioLiveBlock(segment: live, workout: workout, recorder: recorder, monitor: monitor,
                                editMaxHeartRate: editMaxHeartRate)
                    .id(live.id)
            }
            if let first = plans.first {
                VStack(alignment: .leading, spacing: look.space.header) {
                    SectionHeader("Planned cardio")
                    CardioPlanHero(plan: first, workout: workout,
                                   last: CardioReadout.lastDone(in: allSegments)[first.activity],
                                   canStart: canStartPlanned) { startPlanned(first) }
                    ForEach(plans.dropFirst()) { plan in
                        CardioPlanCard(plan: plan, canStart: canStartPlanned) { startPlanned(plan) }
                    }
                }
            }
            if live == nil && plans.isEmpty && ended.isEmpty {
                EmptyStateView(symbol: "figure.run", title: "Add cardio to this workout")
            }
            ForEach(ended) { segment in
                CardioEndedCard(segment: segment, workout: workout)
            }
        }
        .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20))
        .listRowSeparator(.hidden).listRowBackground(Color.clear)
    }
}

// MARK: - Live segment

struct CardioLiveBlock: View {
    var segment: CardioSegment
    var workout: Workout
    var recorder: CardioRecorder
    var monitor: HeartRateMonitor?
    var editMaxHeartRate: () -> Void
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.cardioStill) private var still
    @State private var editingDistance = false
    @ScaledMetric(relativeTo: .largeTitle) private var ringSide: CGFloat = 236
    @ScaledMetric(relativeTo: .title3) private var discSize: CGFloat = 44

    private var ax: Bool { typeSize.isAccessibilitySize }
    private var ringDiameter: CGFloat { ax ? 190 : min(ringSide, 300) }

    private var targetMinutes: Int? {
        workout.plannedCardio.first { $0.segmentID == segment.id }?.minutes
    }
    /// Manual entry: indoor only, while nothing measured the distance or it was typed
    /// (the September 19 rule — measured distance needs no editor).
    private var distanceEditable: Bool {
        !segment.activity.isOutdoor && (segment.automaticDistanceMeters == nil || segment.manualDistanceValue != nil)
    }
    private var location: CardioLocationStatus {
        .of(message: recorder.locationMessage, outdoor: segment.activity.isOutdoor, running: segment.isRunning)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { tick in
            let active = Int(segment.activeDuration(at: tick.date))
            let model = CardioRingModel.make(activeSeconds: active, targetMinutes: targetMinutes,
                                             distanceMeters: segment.distanceMeters, unit: segment.unit)
            let paused = !segment.isRunning
            VStack(alignment: .leading, spacing: ax ? 14 : 20) {
                header(paused: paused, pausedFor: CardioReadout.pausedSeconds(segment, at: tick.date) ?? 0)
                hero(active: active, model: model, paused: paused)
                    .frame(maxWidth: .infinity)
                if location == .lost {
                    locationLostPlate.transition(.opacity)
                }
                VStack(spacing: look.space.group) {
                    // Stat numbers, not big numbers: the ring's centre stays the largest figure at every
                    // size (at AccessibilityL the ring is 190 pt and its centre about 40 pt).
                    CardioStatGrid(stats: stats(active: active, model: model, paused: paused),
                                   numberFont: look.font.statNumber, dense: ax)
                    CardioHeartPlate(segment: segment, recorder: recorder, monitor: monitor,
                                     editMaxHeartRate: editMaxHeartRate)
                }
            }
            .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85), value: paused)
            .sensoryFeedback(.success, trigger: model.targetDone) { _, new in new }
            .sensoryFeedback(.impact(weight: .light), trigger: model.splitIndex)
        }
        .foregroundStyle(look.textPrimary)
        .sheet(isPresented: $editingDistance) { CardioDistanceSheet(segment: segment) }
    }

    // MARK: Header

    private func header(paused: Bool, pausedFor: Int) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                titleBlock
                Spacer(minLength: 8)
                CardioStatusPill(paused: paused, pausedSeconds: pausedFor).fixedSize()
            }
            VStack(alignment: .leading, spacing: 10) {
                titleBlock
                CardioStatusPill(paused: paused, pausedSeconds: pausedFor)
            }
        }
    }

    private var titleBlock: some View {
        HStack(spacing: 12) {
            CardioActivityDisc(symbol: segment.activity.symbol, size: discSize)
            VStack(alignment: .leading, spacing: 3) {
                Text(segment.activity.name)
                    .font(look.font.cardTitle)
                    .foregroundStyle(look.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if case .waiting(let message) = location {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        CardioSignalBars()
                        Text(message)
                            .font(.system(.footnote, weight: .semibold))
                            .foregroundStyle(look.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("cardioLocationStatus")
                }
            }
        }
    }

    // MARK: Ring

    @ViewBuilder
    private func hero(active: Int, model: CardioRingModel, paused: Bool) -> some View {
        // An editable distance ring opens the Distance sheet (its centre is the distance): the ring
        // stays the distance figure (`cardioDistanceMetric`), and a pencil disc on it is the edit
        // button (`cardioEditDistance`), so both handles exist in every state.
        if model.countsDistance && distanceEditable {
            ring(active: active, model: model, paused: paused, editable: true)
                .onTapGesture { editingDistance = true }
                .accessibilityAddTraits(.isButton)
                .accessibilityAction(named: "Edit distance") { editingDistance = true }
                .accessibilityIdentifier("cardioDistanceMetric")
                .overlay(alignment: .bottomTrailing) {
                    Button { editingDistance = true } label: {
                        Image(systemName: "pencil")
                            .font(.system(.body, weight: .bold))
                            .foregroundStyle(look.textPrimary)
                            .frame(width: 44, height: 44)
                            .background(look.surfaceRaised, in: Circle())
                    }
                    .buttonStyle(.lookPressable)
                    .accessibilityLabel("Edit distance")
                    .accessibilityIdentifier("cardioEditDistance")
                }
        } else {
            ring(active: active, model: model, paused: paused, editable: false)
                .accessibilityIdentifier(model.countsDistance ? "cardioDistanceMetric" : "cardioTimer")
        }
    }

    private func ring(active: Int, model: CardioRingModel, paused: Bool, editable: Bool) -> some View {
        let side = ringDiameter
        let width = (side * 0.066).rounded()
        let stalled = location == .lost && model.countsDistance
        let phase: CardioRingPhase = paused ? .paused : (stalled ? .stalled : .recording)
        let centre = centreText(model)
        let caption = captionText(model, unit: segment.unit)
        return CardioRing(progress: model.targetDone ? 1 : model.progress, ticks: model.ticks, phase: phase,
                          size: side, lineWidth: width, notch: look.ground) {
            VStack(spacing: 4) {
                if paused {
                    Image(systemName: "pause.fill")
                        .font(.system(size: max(14, side * 0.08), weight: .heavy))
                        .foregroundStyle(look.textPrimary)
                        .modifier(CardioBlink())
                }
                Text(centre)
                    .font(look.cardioHeroFont(size: side * 0.212))
                    .foregroundStyle(paused || stalled ? look.textSecondary : look.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText(countsDown: false))
                    .animation(reduceMotion || still ? nil : .snappy(duration: 0.25), value: centre)
                if let caption {
                    HStack(spacing: 4) {
                        if model.targetDone { Image(systemName: "checkmark.circle.fill").foregroundStyle(look.textPrimary) }
                        Text(caption)
                    }
                    .font(look.cardioCaptionFont)
                    .foregroundStyle(look.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                }
            }
            .frame(width: side - 2 * width - 34)
        }
        .celebrate(model.targetDone ? 1 : 0)
        .celebrate(model.splitIndex)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ringLabel(active: active, model: model, paused: paused, centre: centre, caption: caption))
    }

    private func centreText(_ model: CardioRingModel) -> String {
        switch model.centre {
        case .time(let seconds): Format.elapsed(seconds: seconds)
        case .distance(let units): String(format: "%.2f", units)
        }
    }

    private func captionText(_ model: CardioRingModel, unit: CardioDistanceUnit) -> String? {
        if let target = model.targetSeconds { return "of \(Format.elapsed(seconds: target))" }
        if let next = model.nextUnit { return CardioFormat.splitTarget(next, unit) }
        return nil
    }

    private func ringLabel(active: Int, model: CardioRingModel, paused: Bool, centre: String, caption: String?) -> String {
        var parts = [segment.activity.name, Format.spokenElapsed(seconds: active)]
        if model.countsDistance { parts.append("\(centre) \(segment.unit.rawValue)") }
        if let caption { parts.append(caption) }
        if model.targetDone { parts.append("target reached") }
        parts.append(paused ? "Paused" : "Recording")
        return parts.joined(separator: ", ")
    }

    // MARK: GPS lost

    /// "Location unavailable." (the September 19 copy): time keeps recording, distance stops.
    private var locationLostPlate: some View {
        HStack(spacing: 14) {
            Image(systemName: "location.slash.fill")
                .font(.system(.body, weight: .bold))
                .foregroundStyle(look.ground)
                .frame(width: 42, height: 42)
                .background(look.textPrimary, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(CardioLocationStatus.unavailable)
                    .font(.system(.headline, weight: .bold))
                    .foregroundStyle(look.textPrimary)
                Text("Recording time continues.")
                    .font(look.font.footnote)
                    .foregroundStyle(look.textSecondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lookSurface(.panel)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("cardioLocationStatus")
    }

    // MARK: Figures

    private func stats(active: Int, model: CardioRingModel, paused: Bool) -> [CardioStat] {
        let unit = segment.unit
        let seconds = segment.activeDuration(at: recorder.measurementTime)
        let meters = segment.distanceMeters
        let lost = location == .lost
        var list: [CardioStat] = []
        if model.countsDistance {
            // The ring's centre carries the distance; the active time moves here.
            list.append(CardioStat(label: "Time", symbol: "timer", value: Format.elapsed(seconds: active), unit: nil,
                                   dimmed: paused, identifier: "cardioTimer"))
        } else {
            let editable = distanceEditable
            list.append(CardioStat(
                label: segment.manualDistanceValue != nil ? "Entered distance" : "Distance",
                symbol: CardioFormat.distanceSymbol,
                value: CardioFormat.distance(meters, unit), unit: unit.rawValue,
                dimmed: paused || lost,
                accessory: lost ? "location.slash" : nil,
                action: editable ? { editingDistance = true } : nil,
                identifier: "cardioDistanceMetric",
                editIdentifier: editable ? "cardioEditDistance" : nil))
        }
        // A typed distance has no live speed of its own: current pace/speed is the sensors'.
        let fresh = segment.manualDistanceValue == nil ? recorder.freshSpeed : nil
        if segment.activity.usesSpeed {
            list.append(CardioStat(label: "Current speed", symbol: "gauge.with.needle",
                                   value: CardioFormat.speed(metersPerSecond: fresh, unit: unit),
                                   unit: CardioFormat.speedUnit(unit), identifier: "cardioCurrentPace"))
            list.append(CardioStat(label: "Average speed", symbol: "stopwatch",
                                   value: CardioFormat.speed(meters: meters, seconds: seconds, unit: unit),
                                   unit: CardioFormat.speedUnit(unit), dimmed: paused))
        } else {
            list.append(CardioStat(label: "Current pace", symbol: "gauge.with.needle",
                                   value: CardioMath.paceText(CardioMath.pace(speed: fresh, unit: unit)),
                                   unit: CardioFormat.paceUnit(unit), identifier: "cardioCurrentPace"))
            list.append(CardioStat(label: "Average pace", symbol: "stopwatch",
                                   value: CardioFormat.pace(meters: meters, seconds: seconds, unit: unit),
                                   unit: CardioFormat.paceUnit(unit), dimmed: paused))
        }
        if let calories = segment.activeEnergyKilocalories {
            list.append(CardioStat(label: "Active calories", symbol: "flame.fill",
                                   value: "\(Int(calories.rounded()))", unit: "cal", dimmed: paused))
        }
        return list
    }
}

// MARK: - Status pill

/// Recording: the live dot on a quiet pill. Paused: the pill inverts and counts the pause.
private struct CardioStatusPill: View {
    var paused: Bool
    var pausedSeconds: Int
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .subheadline) private var height: CGFloat = 34

    var body: some View {
        HStack(spacing: 7) {
            if paused {
                Image(systemName: "pause.fill").font(.system(.caption, weight: .heavy))
                Text("Paused")
                Text(Format.elapsed(seconds: pausedSeconds)).monospacedDigit()
            } else {
                CardioPulseDot(color: look.done, size: 9).padding(.trailing, 2)
                Text("Recording")
            }
        }
        .font(.system(.subheadline, weight: .bold))
        .foregroundStyle(paused ? look.ground : look.textPrimary)
        .padding(.horizontal, 13)
        .frame(minHeight: height)
        .background(paused ? look.textPrimary : look.surface, in: Capsule())
        .overlay { if !paused { Capsule().strokeBorder(look.hairline, lineWidth: 1) } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(paused ? "Paused, for \(Format.spokenElapsed(seconds: pausedSeconds))" : "Recording")
        .accessibilityIdentifier("cardioStatus")
    }
}

// MARK: - Heart-rate plate

/// Heart rate while cardio records: the beating bpm, the zone meter and the last six minutes as
/// one zone-coloured line (once two minutes exist). Missing is not zero: no reading → "Waiting for
/// heart-rate data" while recording, else nothing. Tapping it opens Max Heart Rate (zones).
private struct CardioHeartPlate: View {
    var segment: CardioSegment
    var recorder: CardioRecorder
    var monitor: HeartRateMonitor?
    var editMaxHeartRate: () -> Void
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if let sample = recorder.currentHeartRate {
            plate(sample)
        } else if segment.isRunning {
            HeartRatePlate(title: nil) {
                HStack(spacing: 12) {
                    Image(systemName: "heart").font(.system(.title3, weight: .bold)).foregroundStyle(look.textTertiary)
                    Text("Waiting for heart-rate data")
                        .font(look.font.subhead).foregroundStyle(look.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .frame(minHeight: 44)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("cardioHeartRate")
        }
    }

    private func plate(_ sample: HeartRateSample) -> some View {
        let max = monitor?.maxHeartRate?.bpm
        let zone = max.flatMap { HeartRateZones.zone(for: sample.bpm, max: $0) }
        let points = CardioHeartTrace.points(monitor?.samples ?? [], since: segment.startedAt, now: recorder.measurementTime)
        let bounds = max.map { m in HeartRateZone.allCases.map { HeartRateZones.lowerBound(of: $0, max: m) } } ?? []
        return Button(action: editMaxHeartRate) {
            HeartRatePlate(title: nil) {
                HStack(alignment: .center, spacing: typeSize.isAccessibilitySize ? 10 : 14) {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            BeatingHeart(bpm: sample.bpm, isFresh: true, font: .system(.title3, weight: .bold))
                            Text("\(sample.bpm)")
                                .font(look.font.statNumber)
                                .foregroundStyle(look.heartRate)
                                .contentTransition(.numericText(value: Double(sample.bpm)))
                                .lineLimit(1)
                            Text("bpm").font(look.cardioUnitFont).foregroundStyle(look.textSecondary)
                        }
                        HStack(spacing: 7) {
                            if max == nil {
                                Image(systemName: "slider.horizontal.3").font(.system(.footnote, weight: .bold))
                                    .foregroundStyle(look.textPrimary)
                            } else {
                                ZoneMeter(zone: zone)
                            }
                            Text(zone?.label ?? (max == nil ? "Set up zones" : "Heart rate"))
                                .font(.system(.footnote, weight: .semibold))
                                .foregroundStyle(max == nil ? look.textPrimary : look.textSecondary)
                        }
                    }
                    .layoutPriority(1)
                    Spacer(minLength: 4)
                    // Under two minutes there is no shape yet: the number stands alone.
                    if points.count >= 8 {
                        CardioHeartTraceView(points: points, zoneBounds: bounds)
                            .frame(minWidth: 60, maxWidth: 140)
                            .frame(height: 48)
                    }
                }
            }
        }
        .buttonStyle(.lookPressable)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Heart rate \(sample.bpm) beats per minute" + (zone.map { ", \($0.label)" } ?? ""))
        .accessibilityHint(max == nil ? "Sets up heart-rate zones" : "Edits the maximum heart rate")
        .accessibilityIdentifier("cardioHeartRate")
    }
}

/// The last six minutes as one smoothed line (30-second points), coloured by the zone each stretch
/// sits in (hard stops at the zone bounds), ending in the "now" dot.
private struct CardioHeartTraceView: View {
    var points: [CardioHeartPoint]
    var count = 24
    var zoneBounds: [Int]
    @Environment(\.look) private var look

    private var smoothed: [(x: Double, bpm: Double)] {
        var groups: [Int: [Double]] = [:]
        for p in points { groups[p.index / 2, default: []].append(p.bpm) }
        return groups.keys.sorted().map { key in
            let values = groups[key] ?? []
            return (Double(key) * 2 + 0.5, values.reduce(0, +) / Double(Swift.max(1, values.count)))
        }
    }

    var body: some View {
        Canvas { context, size in
            let pts = smoothed
            guard pts.count >= 2, let lo0 = pts.map(\.bpm).min(), let hi0 = pts.map(\.bpm).max() else { return }
            let mid = (lo0 + hi0) / 2, half = Swift.max(14, (hi0 - lo0) / 2 + 3)
            let lo = mid - half, span = 2 * half
            let inset: CGFloat = 5
            func x(_ v: Double) -> CGFloat { inset + (size.width - 2 * inset) * CGFloat(v / Double(Swift.max(1, count - 1))) }
            func y(_ bpm: Double) -> CGFloat { inset + (size.height - 2 * inset) * CGFloat(1 - (bpm - lo) / span) }
            var path = Path()
            var previous: (x: Double, bpm: Double)?
            for (i, pt) in pts.enumerated() {
                let here = CGPoint(x: x(pt.x), y: y(pt.bpm))
                if let prev = previous, pt.x - prev.x <= 4 {
                    let p0 = i >= 2 ? pts[i - 2] : prev
                    let p3 = i + 1 < pts.count ? pts[i + 1] : pt
                    let c1 = CGPoint(x: x(prev.x) + (x(pt.x) - x(p0.x)) / 6, y: y(prev.bpm) + (y(pt.bpm) - y(p0.bpm)) / 6)
                    let c2 = CGPoint(x: x(pt.x) - (x(p3.x) - x(prev.x)) / 6, y: y(pt.bpm) - (y(p3.bpm) - y(prev.bpm)) / 6)
                    path.addCurve(to: here, control1: c1, control2: c2)
                } else {
                    path.move(to: here)
                }
                previous = pt
            }
            context.stroke(path, with: shading(size: size, y: y), style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
            if let last = pts.last {
                let c = CGPoint(x: x(last.x), y: y(last.bpm))
                context.fill(Path(ellipseIn: CGRect(x: c.x - 4.5, y: c.y - 4.5, width: 9, height: 9)), with: .color(look.heartRate))
            }
        }
        .accessibilityHidden(true)
    }

    private func shading(size: CGSize, y: (Double) -> CGFloat) -> GraphicsContext.Shading {
        guard zoneBounds.count == 6, size.height > 0 else { return .color(look.heartRate) }
        var stops: [Gradient.Stop] = []
        var bottom = 0
        for (i, bound) in zoneBounds.enumerated() where y(Double(bound)) >= size.height { bottom = i }
        stops.append(.init(color: look.zoneRamp[bottom], location: 0))
        var current = bottom
        for i in (bottom + 1)..<6 {
            let yy = y(Double(zoneBounds[i]))
            guard yy > 0, yy < size.height else { continue }
            let location = 1 - yy / size.height
            stops.append(.init(color: look.zoneRamp[current], location: location))
            stops.append(.init(color: look.zoneRamp[i], location: location))
            current = i
        }
        stops.append(.init(color: look.zoneRamp[current], location: 1))
        return .linearGradient(Gradient(stops: stops), startPoint: CGPoint(x: 0, y: size.height), endPoint: .zero)
    }
}

// MARK: - Ended segment

/// A finished segment in the running workout: the disc, name and the active time as the card's
/// figure ("20:05 of 20:00"), a small done ring (lit with a check once a target was met), then the
/// figures as a hairline table. Distance is the one editable figure; it opens Distance (C05).
struct CardioEndedCard: View {
    var segment: CardioSegment
    var workout: Workout
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var editingDistance = false
    @ScaledMetric(relativeTo: .title3) private var discSize: CGFloat = 40

    var body: some View {
        let target = workout.plannedCardio.first { $0.segmentID == segment.id }?.minutes
        let active = Int(segment.activeDuration(at: segment.endedAt ?? .now))
        let progress = target.map { min(1, Double(active) / Double(max(60, $0 * 60))) } ?? 1
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                CardioActivityDisc(symbol: segment.activity.symbol, size: discSize)
                VStack(alignment: .leading, spacing: 4) {
                    Text(segment.activity.name)
                        .font(look.font.cardTitle)
                        .foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    timeLine(active: active, target: target)
                }
                Spacer(minLength: 8)
                CardioRing(progress: progress, ticks: min(12, target ?? 12), phase: .still,
                           size: 54, lineWidth: 6, notch: look.surface) {
                    if progress >= 1 {
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundStyle(look.onDone)
                            .frame(width: 30, height: 30)
                            .background(look.done, in: Circle())
                    }
                }
                .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("cardioSummary.\(segment.activityRawValue)")
            LookDivider()
            CardioStatGrid(stats: CardioCardStats.figures(segment, look: look, editDistance: { editingDistance = true }),
                           style: .inset, numberFont: look.font.statNumber)
        }
        .lookSurface(.panel)
        .accessibilityElement(children: .contain)
        .sheet(isPresented: $editingDistance) { CardioDistanceSheet(segment: segment) }
    }

    /// "20:05" big, then "of 20:00" small; they stack at accessibility sizes.
    private func timeLine(active: Int, target: Int?) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 6))
        return layout {
            Text(Format.elapsed(seconds: active)).font(look.font.bigNumber).foregroundStyle(look.textPrimary).monospacedDigit()
            if let target {
                Text("of \(Format.elapsed(seconds: target * 60))").font(look.cardioUnitFont).foregroundStyle(look.textSecondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Format.spokenElapsed(seconds: active) + (target.map { ", target \($0) minutes" } ?? ""))
    }
}

/// The ended card's figures: Distance (editable; "Entered distance" once typed), average pace or
/// speed, average heart rate, active calories.
enum CardioCardStats {
    static func figures(_ segment: CardioSegment, look: Look, editDistance: @escaping () -> Void) -> [CardioStat] {
        let unit = segment.unit
        let seconds = segment.activeDuration(at: segment.endedAt ?? .now)
        let fromGPS = segment.activity.isOutdoor && segment.manualDistanceValue == nil
        var list = [CardioStat(
            label: segment.manualDistanceValue != nil ? "Entered distance" : "Distance",
            symbol: fromGPS ? "location.fill" : CardioFormat.distanceSymbol,
            value: CardioFormat.distance(segment.distanceMeters, unit), unit: unit.rawValue,
            accessory: "pencil", action: editDistance, identifier: "cardioSummaryEditDistance")]
        if segment.activity.usesSpeed {
            list.append(CardioStat(label: "Average speed", symbol: "stopwatch",
                                   value: CardioFormat.speed(meters: segment.distanceMeters, seconds: seconds, unit: unit),
                                   unit: CardioFormat.speedUnit(unit)))
        } else {
            list.append(CardioStat(label: "Average pace", symbol: "stopwatch",
                                   value: CardioFormat.pace(meters: segment.distanceMeters, seconds: seconds, unit: unit),
                                   unit: CardioFormat.paceUnit(unit)))
        }
        if let bpm = segment.averageHeartRate {
            list.append(CardioStat(label: "Avg. heart rate", symbol: "heart.fill", value: "\(bpm)", unit: "bpm",
                                   tint: look.heartRate, symbolTint: look.heartRate))
        }
        if let calories = segment.activeEnergyKilocalories {
            list.append(CardioStat(label: "Active calories", symbol: "flame.fill",
                                   value: "\(Int(calories.rounded()))", unit: "cal"))
        }
        return list
    }
}

// MARK: - Planned target (not started)

/// The first planned target waiting for its explicit Start (D57): the empty target ring around the
/// target time, its Start capsule, then two quiet facts — the last time this activity was done and
/// the lifting so far.
private struct CardioPlanHero: View {
    var plan: PlannedCardio
    var workout: Workout
    var last: CardioSegment?
    var canStart: Bool
    var start: () -> Void
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .largeTitle) private var ringSide: CGFloat = 200

    var body: some View {
        let side = min(ringSide, 260)
        let width = (side * 0.066).rounded()
        VStack(spacing: 20) {
            CardioRing(progress: 0, ticks: plan.minutes < 5 ? 12 : min(60, plan.minutes), phase: .still,
                       size: side, lineWidth: width, notch: look.ground) {
                VStack(spacing: 4) {
                    // The target, not a running clock: secondary until Start.
                    Text(Format.elapsed(seconds: plan.minutes * 60))
                        .font(look.cardioHeroFont(size: side * 0.22))
                        .foregroundStyle(look.textSecondary)
                        .lineLimit(1).minimumScaleFactor(0.5)
                    HStack(spacing: 6) {
                        Image(systemName: plan.activity.symbol)
                        Text(plan.distance.map { "\($0.formatted()) \(plan.unit.rawValue)" } ?? plan.activity.name)
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .font(look.cardioCaptionFont)
                    .foregroundStyle(look.textSecondary)
                }
                .frame(width: side - 2 * width - 30)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(plan.activity.name), target \(plan.summary)")

            StartCapsule(title: "Start \(plan.activity.name)", symbol: plan.activity.symbol, action: start)
                .frame(maxWidth: .infinity)
                .disabled(!canStart)
                .opacity(canStart ? 1 : 0.45)
                .accessibilityIdentifier("startPlannedCardio")
            facts
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var facts: some View {
        let sets = WorkoutSession.orderedEntries(of: workout).flatMap { WorkoutSession.orderedSets(of: $0) }
        let done = sets.filter { $0.completedAt != nil }.count
        if last != nil || !sets.isEmpty {
            LookList {
                if let last {
                    CardioFactRow(symbol: "clock.arrow.circlepath", label: "Last \(plan.activity.name)",
                                  values: [last.distanceMeters.map { "\(CardioFormat.distance($0, last.unit)) \(last.unit.rawValue)" },
                                           Format.elapsed(seconds: Int(last.activeDuration(at: last.endedAt ?? last.lastCheckpointAt))),
                                           LookFormat.shortDate(last.startedAt)].compactMap { $0 })
                }
                if !sets.isEmpty {
                    CardioFactRow(symbol: "figure.strengthtraining.traditional", label: "Lifting",
                                  values: ["\(done)/\(sets.count) sets"], sets: (done, sets.count))
                }
            }
        }
    }
}

/// A quiet fact row: glyph · small label · values; at accessibility sizes the values go under.
private struct CardioFactRow: View {
    var symbol: String
    var label: String
    var values: [String]
    var sets: (done: Int, total: Int)? = nil
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var glyphColumn: CGFloat = 26

    var body: some View {
        let ax = typeSize.isAccessibilitySize
        let layout = ax ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        HStack(alignment: .center, spacing: 12) {
            LookIcon(symbol, style: .body).foregroundStyle(look.textSecondary).frame(width: glyphColumn)
            layout {
                Text(label).font(look.font.subhead).foregroundStyle(look.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !ax { Spacer(minLength: 8) }
                HStack(spacing: 8) {
                    if let sets { SetsRing(done: sets.done, total: sets.total, size: 18).accessibilityHidden(true) }
                    Text(values.joined(separator: " · "))
                        .font(.system(.subheadline, weight: .bold).monospacedDigit())
                        .foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// A later planned target: a compact card with its Start.
private struct CardioPlanCard: View {
    var plan: PlannedCardio
    var canStart: Bool
    var start: () -> Void
    @Environment(\.look) private var look

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                CardioRing(progress: 0, ticks: plan.minutes < 5 ? 12 : min(60, plan.minutes), phase: .still,
                           size: 64, lineWidth: 7, notch: look.surface) {
                    Text("\(plan.minutes)").font(look.font.smallNumber).foregroundStyle(look.textPrimary).minimumScaleFactor(0.7)
                }
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(plan.activity.name).font(look.font.cardTitle).foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(plan.summary).font(look.font.subhead).foregroundStyle(look.textSecondary)
                }
                Spacer(minLength: 0)
            }
            Button(action: start) { Label("Start \(plan.activity.name)", systemImage: plan.activity.symbol) }
                .buttonStyle(.lookSecondary)
                .disabled(!canStart)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lookSurface(.panel)
    }
}

// MARK: - Tray

/// Pinned at the thumb, in the rest bar's slot. Pause (or Resume) is the state's one filled
/// command; End Cardio is quiet and narrower (it ends the segment at once). At accessibility sizes
/// the two stay side by side while they fit (icons drop first), else they stack.
struct CardioControls: View {
    var segment: CardioSegment
    var recorder: CardioRecorder
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var toggles = 0
    @State private var ends = 0
    @ScaledMetric(relativeTo: .headline) private var endWidth: CGFloat = 158

    var body: some View {
        let ax = typeSize.isAccessibilitySize
        ViewThatFits(in: .horizontal) {
            row(icons: true, equal: ax)
            row(icons: false, equal: true)
            VStack(spacing: 10) { pause(icons: true); end(icons: true) }
        }
        .padding(12)
        .background { CardioTrayBackground() }
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
        .background {
            VStack(spacing: 0) {
                LinearGradient(colors: [look.ground.opacity(0), look.ground], startPoint: .top, endPoint: .bottom)
                    .frame(height: 26)
                look.ground
            }
            .padding(.top, -26)
            .ignoresSafeArea(edges: .bottom)
            .allowsHitTesting(false)
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: toggles)
        .sensoryFeedback(.impact(weight: .heavy), trigger: ends)
    }

    private func row(icons: Bool, equal: Bool) -> some View {
        HStack(spacing: 10) {
            pause(icons: icons)
            end(icons: icons).frame(maxWidth: equal ? .infinity : endWidth)
        }
    }

    private func pause(icons: Bool) -> some View {
        let running = segment.isRunning
        return Button {
            toggles += 1
            withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8)) {
                if running { recorder.pause() } else { recorder.resume() }
            }
        } label: {
            label(running ? "Pause" : "Resume", symbol: running ? "pause.fill" : "play.fill", icons: icons)
        }
        .buttonStyle(CardioTrayButtonStyle(prominent: true))
        .accessibilityIdentifier("cardioPauseResume")
    }

    private func end(icons: Bool) -> some View {
        Button {
            ends += 1
            withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.85)) { recorder.endCardio() }
        } label: {
            label("End Cardio", symbol: "stop.fill", icons: icons)
        }
        .buttonStyle(CardioTrayButtonStyle(prominent: false))
        .accessibilityIdentifier("endCardio")
    }

    @ViewBuilder private func label(_ title: String, symbol: String, icons: Bool) -> some View {
        if icons {
            Label(title, systemImage: symbol).contentTransition(.symbolEffect(.replace)).fixedSize()
        } else {
            Text(title).fixedSize()
        }
    }
}
