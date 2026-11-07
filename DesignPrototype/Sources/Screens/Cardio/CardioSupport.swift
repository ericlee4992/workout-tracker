import SwiftUI

// Cardio area helpers the Store / Look layers lack. Everything is area-prefixed so the
// integrator can promote it. Nothing here keeps state of its own: it derives from the Store.

// MARK: - Store readouts

/// One cardio segment, live or finished, in the shape the distance editor and cards need.
struct CardioSegmentSnapshot: Equatable {
    var id: UUID
    var activity: CardioActivity
    var activeSeconds: Int
    /// Distance the sensors / GPS measured (nil = none).
    var measuredMeters: Double?
    var manualDistance: Double?
    var unit: DistanceUnit
    var isLive: Bool

    /// Manual wins, else measured.
    var distanceMeters: Double? {
        if let manualDistance { return manualDistance * unit.metersPerUnit }
        return measuredMeters
    }
}

extension Store {
    /// A live segment (the running session) or a finished one (history), by id.
    func cardioSegmentSnapshot(_ id: UUID) -> CardioSegmentSnapshot? {
        if let c = session?.cardio.first(where: { $0.id == id }) {
            return CardioSegmentSnapshot(id: c.id, activity: c.activity, activeSeconds: c.activeSeconds(at: c.endedAt ?? now),
                                         measuredMeters: c.measuredMeters > 0 ? c.measuredMeters : nil,
                                         manualDistance: c.manualDistance, unit: c.unit, isLive: true)
        }
        for w in workouts {
            if let s = w.cardio.first(where: { $0.id == id }) {
                return CardioSegmentSnapshot(id: s.id, activity: s.activity, activeSeconds: s.activeSeconds,
                                             measuredMeters: s.measuredMeters, manualDistance: s.manualDistance,
                                             unit: s.unit, isLive: false)
            }
        }
        return nil
    }

    /// The planned target a live segment was started from (nil = unplanned).
    func cardioPlan(for segment: LiveCardio) -> PlannedCardio? {
        guard let id = segment.plannedID else { return nil }
        return session?.plannedCardio.first { $0.id == id }
    }

    /// Planned targets in the running session that have not started yet.
    var cardioPendingPlans: [PlannedCardio] {
        (session?.plannedCardio ?? []).filter { plannedStatus($0.id) == .notStarted }
    }

    /// The most recent finished segment of an activity (picker tiles, "Last time").
    func cardioLastDone(_ activity: CardioActivity) -> (date: Date, segment: CardioSegment)? {
        for w in history {
            if let s = w.cardio.last(where: { $0.activity == activity }) { return (s.startedAt, s) }
        }
        return nil
    }

    /// The last `limit` 15-second heart-rate buckets of the session, newest at the right.
    /// Gaps (0) are skipped; indices keep their position so a gap stays a hole.
    func cardioRecentHeartRate(limit: Int = 24) -> [CardioHRPoint] {
        guard let log = session?.heartRate else { return [] }
        let n = min(log.mean.count, log.low.count, log.high.count)
        let start = max(0, n - limit)
        return (start..<n).compactMap { i in
            guard log.mean[i] > 0 else { return nil }
            return CardioHRPoint(index: limit - (n - i), mean: log.mean[i],
                                 low: log.low[i] > 0 ? log.low[i] : log.mean[i], high: max(log.high[i], log.mean[i]))
        }
    }

    /// Lower bound of each zone (index 0 … 5), or empty without a max heart rate.
    var cardioZoneBounds: [Int] {
        guard let max = maxHeartRate else { return [] }
        return HeartRateZone.allCases.map { Int((Double(max) * $0.lowerFraction).rounded()) }
    }

    /// PROTOTYPE capture helper: a fresh Push Day whose template carries `plans` (the template is
    /// put back at once; the session keeps its own copy of the targets), in cardio focus.
    func cardioStartPushDay(plans: [PlannedCardio]) {
        let templateID = SampleData.templateID("Push Day")
        guard let i = templates.firstIndex(where: { $0.id == templateID }) else { return }
        let original = templates[i]
        templates[i].cardio = plans
        cancelWorkout()
        startLifting(templateID: templateID)
        templates[i] = original
        setFocus(.cardio)
    }
}

// MARK: - Capture variants (view-level; Store-level ones are applied by the shell)

/// `-variant` names the cardio screens apply themselves on appear. Each one is applied once per
/// launch, so a panel that re-appears (or a session the variant replaced) never re-applies it.
/// PROTOTYPE: states the sample reset does not reach. Variants that need recorded time
/// ("cycle", "met") run the scenario clock for a few seconds and then stop it again, so every
/// figure on screen is one the Store really recorded.
enum CardioVariants {
    static var applied: Set<String> = []

    static func tokens(_ variant: String?) -> Set<String> {
        Set((variant ?? "").split(separator: "+").map(String.init))
    }

    /// True the first time this variant is seen in this launch.
    static func claim(_ variant: String?) -> Bool {
        guard let variant, !variant.isEmpty else { return false }
        return applied.insert(variant).inserted
    }

    /// Runs the scenario clock for `seconds`, then stops it (captures stay frozen afterwards).
    static func record(_ store: Store, seconds: Double) {
        let wasFrozen = store.freezeClock
        store.freezeClock = false
        guard wasFrozen else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { store.freezeClock = true }
    }

    /// The live panel's variants (C02–C04).
    static func applyPanel(_ variant: String?, store: Store) {
        guard claim(variant) else { return }
        let t = tokens(variant)
        let live = store.session?.unfinishedCardio
        if t.contains("planned"), store.session?.hasCardio == true {
            // Push Day with its 20-min Indoor Run target not started yet.
            store.reset(to: .l01)
            store.setFocus(.cardio)
        }
        if t.contains("noCardio") {
            // A workout with no cardio and no targets: the empty cardio tab.
            store.cardioStartPushDay(plans: [])
        }
        if t.contains("cycle") {
            // Indoor Cycle after the run: the speed layout (mi/h), the run as an ended card.
            store.startCardio(activity: .indoorCycle)
            record(store, seconds: 40)
        }
        if t.contains("met") {
            // A 1-minute target run past its time while still recording.
            let plan = PlannedCardio(id: UUID(), activity: .indoorRun, minutes: 1, distance: nil, unit: .mi)
            store.cardioStartPushDay(plans: [plan])
            store.startPlannedCardio(plan.id)
            record(store, seconds: 68)
        }
        if t.contains("noMax") {
            // No measured maximum and no date of birth: no zones ("Set up zones").
            store.settings.measuredMaxHeartRate = nil
            store.settings.birthDate = nil
        }
        if t.contains("manual"), let live {
            store.setManualDistance(1.5, unit: .mi, segmentID: live.id)
        }
        if t.contains("acquiring") {
            // Just resumed outdoors: a new route portion waits for a fix ("Waiting for GPS…").
            store.pauseCardio()
            store.resumeCardio()
        }
        if t.contains("ended") {
            store.endCardio()
        }
        if t.contains("lifting") {
            // The Lifting focus while the run records (the Live area's return row).
            store.setFocus(.lifting)
        }
    }
}

/// When the running segment was paused (the Store keeps active time only). PROTOTYPE: the
/// panel's Pause / Resume keep it; the C03 sample, paused at reset, reads as paused 0:42.
enum CardioPauseLedger {
    static var pausedAt: [UUID: Date] = [:]

    static func pausedSeconds(_ segment: LiveCardio, store: Store) -> Int {
        guard segment.isPaused else { return 0 }
        if pausedAt[segment.id] == nil {
            let sample = store.currentScreen == .c03 && store.freezeClock
            pausedAt[segment.id] = store.now.addingTimeInterval(sample ? -42 : 0)
        }
        return max(0, Int(store.now.timeIntervalSince(pausedAt[segment.id] ?? store.now)))
    }
}

extension EnvironmentValues {
    /// True while the scenario clock is frozen (captures): pulses, blinks and flickers rest in
    /// their still state so a screenshot shows the resting board, never a mid-blink frame.
    @Entry var cardioStill: Bool = false
}

// MARK: - Formatting (plain numbers, D52)

enum CardioFormat {
    /// Live distance keeps two decimals so the figure never jumps width: "1.47", "0.90".
    static func distance(_ meters: Double?, _ unit: DistanceUnit) -> String {
        guard let meters, meters > 0 else { return "—" }
        return String(format: "%.2f", meters / unit.metersPerUnit)
    }
    /// Distance for summaries: "2.31".
    static func distanceValue(_ value: Double) -> String { String(format: "%.2f", value) }
    /// "8:43" or "—".
    static func pace(_ secondsPerUnit: Double?) -> String { Format.pace(secondsPerUnit) }
    /// "18.4" units per hour, or "—".
    static func speed(_ perHour: Double?) -> String {
        guard let perHour, perHour.isFinite, perHour > 0 else { return "—" }
        return String(format: "%.1f", perHour)
    }
    /// "/mi", "/km".
    static func paceUnit(_ unit: DistanceUnit) -> String { "/\(unit.label)" }
    /// "mi/h", "km/h".
    static func speedUnit(_ unit: DistanceUnit) -> String { "\(unit.label)/h" }
    /// What a distance ring counts toward: "of 1 mi", "of 3 km" (PROPOSED string).
    static func splitTarget(_ next: Int, _ unit: DistanceUnit) -> String {
        "of \(next) \(unit.label)"
    }
    /// A planned target: "20 min", "20 min · 3 mi" (the real app's summary format).
    static func plan(_ plan: PlannedCardio) -> String {
        if let d = plan.distance { return "\(plan.minutes) min · \(Format.number(d)) \(plan.unit.label)" }
        return "\(plan.minutes) min"
    }
    /// Keeps a typed distance to digits and one decimal separator, at most 6 characters
    /// ("12.345"), so the big field never overflows.
    static func sanitize(_ text: String) -> String {
        var out = ""
        var sawSeparator = false
        for ch in text {
            if ch.isASCII, ch.isNumber {
                out.append(ch)
            } else if (ch == "." || ch == ","), !sawSeparator {
                sawSeparator = true
                out.append(ch)
            }
            if out.count == 6 { break }
        }
        return out
    }

    /// Parses a typed distance ("2.31", "2,31", " 3 ").
    static func parse(_ text: String) -> Double? {
        let cleaned = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty else { return nil }
        return Double(cleaned)
    }
}

// MARK: - Type

extension Look {
    /// The cardio ring's number: each look's number face (A Expanded Heavy, B Rounded Heavy,
    /// C Expanded Heavy) at a Dynamic-Type-scaled size (pass a `@ScaledMetric`).
    func cardioHeroFont(size: CGFloat) -> Font {
        switch id {
        case .floodlight, .paper, .carbon:
            Font.system(size: size, weight: .heavy).width(.expanded).monospacedDigit()
        case .anatomy:
            Font.system(size: size, weight: .heavy, design: .rounded).monospacedDigit()
        }
    }

    /// The recording dot: A floodlight white (Ultra stays on the live ring segment and Pause,
    /// never a third role), B pearl, C the cobalt pen.
    var cardioLive: Color {
        switch id {
        case .floodlight: done
        case .anatomy: textPrimary
        case .paper, .carbon: actionText
        }
    }

    /// Small label over metric values.
    var cardioLabelFont: Font {
        switch id {
        case .floodlight: .system(.footnote, weight: .regular)
        case .anatomy, .paper, .carbon: .system(.footnote, weight: .semibold)
        }
    }

    var cardioUnitFont: Font {
        .system(.subheadline, design: id == .anatomy ? .rounded : .default, weight: id == .anatomy ? .bold : .semibold)
    }

    /// Short labels inside the ring and on pills (B rounded).
    var cardioCaptionFont: Font {
        .system(.subheadline, design: id == .anatomy ? .rounded : .default, weight: .semibold)
    }
}

// MARK: - Pulse, blink

/// The recording pulse: a solid dot that sends out a small ripple once every 1.4 s.
/// Reduce Motion, a frozen clock (captures) or `active == false`: a still dot.
struct CardioPulseDot: View {
    var color: Color
    var size: CGFloat = 9
    var active = true
    /// How far the ripple grows (× the dot's size).
    var ripple: CGFloat = 0.9
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.cardioStill) private var still

    var body: some View {
        let animate = active && !reduceMotion && !still
        TimelineView(.animation(minimumInterval: nil, paused: !animate)) { context in
            let phase = animate ? (context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.4) / 1.4) : 0
            ZStack {
                if animate {
                    Circle()
                        .stroke(color, lineWidth: max(1.2, size * 0.16))
                        .scaleEffect(1 + ripple * phase)
                        .opacity(0.7 * (1 - phase))
                }
                Circle().fill(color)
            }
            .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// A stopped watch: the pause glyph over the frozen time blinks (never the time itself, which
/// stays at full contrast). Reduce Motion / frozen clock: steady.
struct CardioBlink: ViewModifier {
    var active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.cardioStill) private var still

    func body(content: Content) -> some View {
        if !active || reduceMotion || still {
            content
        } else {
            TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let wave = 0.5 + 0.5 * cos(t * 2 * .pi / 1.6)
                content.opacity(0.3 + 0.7 * wave)
            }
        }
    }
}

// MARK: - The ring

/// Cardio's one bold element. The number in its centre is always what the ring counts:
/// time against a planned target, distance toward the next mile, or a 60-second sweep.
/// A (scoreboard): one segment per minute / tenth — done segments light white, the current one
///   fills in Ultra and flickers while recording (no head dot: the segment is the live mark).
/// B (anatomy): one continuous arc tinted by the current heart-rate zone, notched like the others.
/// C (paper club): a pen dial — cobalt arc over a notched track.
/// Paused: the live colour drops out and the recorded arc dots / dashes; the head stops.
/// Stalled (GPS lost on a distance ring): the recorded part stays, only the head stops at a
///   slashed pin and the rest of the track breaks up (A greys just the partial segment).
/// Target met: the ring is fully inked / lit and a check sits at 12 o'clock.
enum CardioRingPhase: Equatable { case recording, paused, stalled, still }

struct CardioRing<Center: View>: View {
    typealias Phase = CardioRingPhase

    var progress: Double
    /// Segments (A) / notches (B, C); 0 = a plain arc (small rings).
    var ticks: Int
    var phase: Phase
    /// B's zone tint (nil = pearl).
    var tint: Color?
    var size: CGFloat
    var lineWidth: CGFloat
    /// The notch colour: the ground the ring sits on.
    var notch: Color?
    @ViewBuilder var center: Center

    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.cardioStill) private var still

    private var p: Double { max(0, min(1, progress)) }
    private var met: Bool { progress >= 1 && (phase == .recording || phase == .still) }
    private var radius: CGFloat { (size - lineWidth) / 2 }
    private var notchColor: Color { notch ?? look.ground }
    private var showsBadge: Bool { met && size >= 120 && phase == .recording }

    var body: some View {
        ZStack {
            switch look.id {
            case .floodlight:
                if ticks > 0 { segmented } else { plain }
            case .anatomy, .paper, .carbon:
                if ticks > 0 && size >= 120 { dial } else { plain }
            }
            if phase == .recording && !met && look.id != .floodlight && size >= 120 { head }
            if phase == .stalled { stalledHead }
            if showsBadge { metBadge }
            center
        }
        .frame(width: size, height: size)
    }

    // MARK: Colours

    /// The recorded arc.
    private var arcColor: Color {
        if met { return look.done }
        switch (look.id, phase) {
        case (_, .paused): return look.textTertiary
        case (.floodlight, .stalled): return look.done
        case (.floodlight, _): return look.done
        case (.anatomy, .recording): return tint ?? look.textPrimary
        case (.anatomy, _): return look.textPrimary
        case (_, .recording): return look.actionText
        case (_, .stalled): return look.textPrimary
        case (_, .still): return look.textPrimary
        }
    }

    // MARK: A — segments

    private var segmented: some View {
        let n = max(2, ticks)
        let step = 1.0 / Double(n)
        let exact = p * Double(n)
        let lit = min(n, Int(exact.rounded(.down)))
        let partial = exact - Double(lit)
        let gap = n > 30 ? 0.26 : 0.16
        let solid = StrokeStyle(lineWidth: lineWidth, lineCap: .butt)
        // Paused: the recorded bulbs switch off — hollow outlines of the same segments.
        let hollow = max(1.5, lineWidth * 0.12)
        func start(_ i: Int) -> Double { Double(i) * step + step * gap / 2 }
        func end(_ i: Int) -> Double { Double(i + 1) * step - step * gap / 2 }
        return ZStack {
            ForEach(0..<n, id: \.self) { i in
                let arc = RingArc(start: start(i), end: end(i))
                if i < lit {
                    if phase == .paused {
                        arc.stroke(style: solid).stroke(look.textSecondary, lineWidth: hollow)
                    } else {
                        arc.stroke(look.done, style: solid)
                    }
                } else if phase == .stalled {
                    // GPS lost: past the pin the track thins to a hairline — nothing recorded there.
                    arc.stroke(look.ringTrack, style: StrokeStyle(lineWidth: max(2, lineWidth * 0.28), lineCap: .butt))
                } else {
                    arc.stroke(look.ringTrack, style: solid)
                }
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: lit)
            if lit < n, partial > 0.001, phase != .stalled {
                let arc = RingArc(start: start(lit), end: start(lit) + (end(lit) - start(lit)) * partial)
                if phase == .paused {
                    arc.stroke(style: solid).stroke(look.textSecondary, lineWidth: hollow)
                } else {
                    flicker {
                        arc.stroke(phase == .recording ? look.live : look.done, style: solid)
                    }
                }
            }
        }
        .padding(lineWidth / 2)
    }

    /// A's current segment flickers like a scoreboard bulb while recording.
    @ViewBuilder
    private func flicker<V: View>(@ViewBuilder _ content: () -> V) -> some View {
        let view = content()
        if phase == .recording && !reduceMotion && !still {
            TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                view.opacity(0.55 + 0.45 * (0.5 + 0.5 * cos(t * 2 * .pi / 1.4)))
            }
        } else {
            view
        }
    }

    // MARK: Plain arc (small rings, the ended card)

    private var plain: some View {
        ZStack {
            Circle().stroke(look.ringTrack, lineWidth: lineWidth)
            if p > 0 {
                RingArc(start: 0, end: p)
                    .stroke(p >= 1 ? look.done : arcColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: p >= 1 ? .butt : .round))
            }
        }
        .padding(lineWidth / 2)
    }

    // MARK: B, C — notched dial

    private var dial: some View {
        let paused = phase == .paused
        let isPaper = look.id.isPaperClub
        let arcStyle: StrokeStyle = paused
            ? (isPaper
               ? StrokeStyle(lineWidth: max(3, lineWidth * 0.42), lineCap: .round, dash: [0.1, max(7, lineWidth * 0.8)])
               : StrokeStyle(lineWidth: lineWidth, lineCap: .round, dash: [0.1, lineWidth * 1.55]))
            : StrokeStyle(lineWidth: lineWidth, lineCap: isPaper || met ? .butt : .round)
        return ZStack {
            if phase == .stalled {
                // The unrecorded rest of the track breaks up beyond the pin.
                RingArc(start: p, end: 1)
                    .stroke(look.ringTrack, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt,
                                                               dash: [lineWidth * 0.55, lineWidth * 0.75]))
            } else {
                Circle().stroke(look.ringTrack, lineWidth: lineWidth)
            }
            if p > 0 {
                RingArc(start: 0, end: p)
                    .stroke(arcColor, style: arcStyle)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.8), value: arcColor)
            }
            ForEach(0..<ticks, id: \.self) { i in
                Rectangle()
                    .fill(notchColor)
                    .frame(width: 2.5, height: lineWidth + 2)
                    .offset(y: -radius + lineWidth / 2)
                    .rotationEffect(.degrees(360 * Double(i) / Double(ticks)))
            }
        }
        .padding(lineWidth / 2)
    }

    // MARK: Head (recording pulse), stalled pin, met badge

    private var headColor: Color {
        switch look.id {
        case .floodlight: look.live
        case .anatomy: tint ?? look.textPrimary
        case .paper, .carbon: look.actionText
        }
    }

    private func point(at fraction: Double) -> CGSize {
        let angle = fraction * 2 * Double.pi - Double.pi / 2
        return CGSize(width: radius * CGFloat(cos(angle)), height: radius * CGFloat(sin(angle)))
    }

    /// Where the recorded arc ends (A: inside the current segment).
    private var headFraction: Double {
        guard look.id == .floodlight, ticks > 0 else { return p }
        let n = Double(max(2, ticks))
        let step = 1 / n
        let exact = p * n
        let lit = exact.rounded(.down)
        let partial = exact - lit
        let gap = n > 30 ? 0.26 : 0.16
        return lit * step + step * gap / 2 + (step - step * gap) * partial
    }

    private var head: some View {
        let dot = lineWidth * 1.0
        return ZStack {
            Circle().fill(notchColor).frame(width: dot + 4, height: dot + 4)
            CardioPulseDot(color: headColor, size: dot, ripple: 0.55)
        }
        .offset(point(at: headFraction))
        .animation(reduceMotion ? nil : .linear(duration: 1), value: headFraction)
    }

    /// GPS lost: where the head stopped, a slashed location pin in a disc on the ring.
    private var stalledHead: some View {
        let side = max(28, lineWidth * 2.3)
        return Image(systemName: "location.slash.fill")
            .font(.system(size: side * 0.46, weight: .bold))
            .foregroundStyle(look.textPrimary)
            .frame(width: side, height: side)
            .background(notchColor, in: Circle())
            .overlay { Circle().strokeBorder(look.textSecondary, lineWidth: 2) }
            .offset(point(at: headFraction))
            .transition(.scale.combined(with: .opacity))
            .accessibilityHidden(true)
    }

    /// Target met: a check stamped at 12 o'clock on the full ring.
    private var metBadge: some View {
        let side = max(30, lineWidth * 2.5)
        return Image(systemName: "checkmark")
            .font(.system(size: side * 0.44, weight: .heavy))
            .foregroundStyle(look.onDone)
            .frame(width: side, height: side)
            .background(look.done, in: Circle())
            .overlay { Circle().strokeBorder(notchColor, lineWidth: 3) }
            .offset(point(at: 0))
            .transition(.scale(scale: 1.6).combined(with: .opacity))
            .accessibilityHidden(true)
    }
}

// MARK: - Heart-rate trace

/// One 15-second heart-rate bucket for the live trace.
struct CardioHRPoint: Hashable {
    var index: Int
    var mean: Int
    var low: Int
    var high: Int
}

/// The last six minutes of heart rate as one smoothed line (30-s points), coloured by the zone
/// each stretch sits in (a vertical gradient with hard stops at the zone bounds), ending in the
/// "now" dot. No range band, no ticks: clean like Apple Fitness.
struct CardioHRTrace: View {
    var points: [CardioHRPoint]
    /// Positions the 15-s buckets span (index 0 ..< count).
    var count: Int = 24
    var zoneBounds: [Int]
    @Environment(\.look) private var look

    /// Pairs of 15-s buckets averaged into 30-s points (a gap stays a gap).
    private var smoothed: [(x: Double, bpm: Double)] {
        var groups: [Int: [Int]] = [:]
        for p in points { groups[p.index / 2, default: []].append(p.mean) }
        return groups.keys.sorted().map { key in
            let values = groups[key] ?? []
            return (x: Double(key) * 2 + 0.5, bpm: Double(values.reduce(0, +)) / Double(max(1, values.count)))
        }
    }

    var body: some View {
        Canvas { context, size in
            let pts = smoothed
            guard pts.count >= 2, let lo0 = pts.map(\.bpm).min(), let hi0 = pts.map(\.bpm).max() else { return }
            // At least a 28 bpm window, so a steady effort reads as steady.
            let mid = (lo0 + hi0) / 2
            let half = max(14, (hi0 - lo0) / 2 + 3)
            let lo = mid - half, span = 2 * half
            let inset: CGFloat = 5
            func x(_ v: Double) -> CGFloat { inset + (size.width - 2 * inset) * CGFloat(v / Double(max(1, count - 1))) }
            func y(_ bpm: Double) -> CGFloat { inset + (size.height - 2 * inset) * CGFloat(1 - (bpm - lo) / span) }

            // Catmull-Rom through the points; a gap of more than a minute breaks the line.
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

    /// Zone colours by height: hard stops where each zone begins.
    private func shading(size: CGSize, y: (Double) -> CGFloat) -> GraphicsContext.Shading {
        guard zoneBounds.count == 6, size.height > 0 else { return .color(look.heartRate) }
        var stops: [Gradient.Stop] = []
        // From the bottom (location 0) up: each zone from its lower bound to the next.
        var zoneAtBottom = 0
        for (i, bound) in zoneBounds.enumerated() where y(Double(bound)) >= size.height { zoneAtBottom = i }
        stops.append(.init(color: look.zoneRamp[zoneAtBottom], location: 0))
        var current = zoneAtBottom
        for i in (zoneAtBottom + 1)..<6 {
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

/// The zone meter as five stepped, horizontal pips lit up to the current zone (A: the shared
/// dashes; B: rounded pips in the zone ramp; C: blocks on the ink slab). The ascending bar glyph
/// is kept for GPS signal only.
struct CardioZoneMeter: View {
    var zone: HeartRateZone?
    @Environment(\.look) private var look

    var body: some View {
        let level = zone?.rawValue ?? 0
        switch look.id {
        case .floodlight:
            ZoneMeter(zone: zone)
        case .anatomy:
            HStack(spacing: 2.5) {
                ForEach(1...5, id: \.self) { step in
                    Capsule()
                        .fill(step <= level ? look.zoneRamp[step] : Color.white.opacity(0.14))
                        .frame(width: 9, height: 5)
                }
            }
            .accessibilityHidden(true)
        case .paper, .carbon:
            HStack(spacing: 2) {
                ForEach(1...5, id: \.self) { step in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(step <= level ? look.heartRate : look.onSlab.opacity(0.22))
                        .frame(width: 5, height: 10)
                }
            }
            .accessibilityHidden(true)
        }
    }
}

// MARK: - GPS signal glyph

/// Three signal bars. Live: all lit. Waiting: they light in turn (Reduce Motion / frozen: one lit).
struct CardioSignalBars: View {
    var state: GPSState
    var color: Color
    var track: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.cardioStill) private var still
    @ScaledMetric(relativeTo: .caption) private var unit: CGFloat = 3.5

    var body: some View {
        let searching = state == .waiting && !reduceMotion && !still
        TimelineView(.animation(minimumInterval: 0.25, paused: !searching)) { context in
            let tick = searching ? Int(context.date.timeIntervalSinceReferenceDate / 0.35) % 4 : 1
            HStack(alignment: .bottom, spacing: unit * 0.55) {
                ForEach(0..<3, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(isLit(i, tick: tick) ? color : track)
                        .frame(width: unit, height: unit * (1.4 + CGFloat(i) * 0.9))
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func isLit(_ i: Int, tick: Int) -> Bool {
        switch state {
        case .live, .notNeeded: true
        case .waiting: i < tick
        case .unavailable: false
        }
    }
}

// MARK: - Control tray (Pause / Resume · End Cardio)

/// The tray's buttons: full-width capsules, 54 pt (capped at 60 at AX sizes). `prominent` is the
/// state's one filled command (A Ultra, B pearl, C cobalt with its hard offset). A/B scale while
/// pressed; C sinks (primary) or darkens (outlined). Reduce Motion: opacity dip.
struct CardioTrayButtonStyle: ButtonStyle {
    var prominent: Bool
    @ScaledMetric(relativeTo: .headline) private var height: CGFloat = 54
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let label = configuration.label
            .font(look.font.button)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: min(height, 60))
        Group {
            switch (look.id, prominent) {
            case (.floodlight, true), (.anatomy, true):
                label.foregroundStyle(look.onAction).background(look.action, in: Capsule())
            case (.floodlight, false):
                label.foregroundStyle(look.textPrimary)
                    .background(look.pillFill, in: Capsule())
                    .overlay { Capsule().strokeBorder(look.pillEdge, lineWidth: 1) }
            case (.anatomy, false):
                label.foregroundStyle(look.textPrimary)
                    .glassEffect(.regular.tint(look.slab), in: Capsule())
                    .overlay { Capsule().strokeBorder(look.pillEdge, lineWidth: 1) }
            case (_, true):
                // C's primary: cobalt, the ink outline and the 4 × 4 hard offset it sinks into.
                let sink = look.motion.pressSink
                let down = pressed && !reduceMotion
                label.foregroundStyle(look.onAction)
                    .background(look.action, in: Capsule())
                    .overlay { Capsule().strokeBorder(look.outline, lineWidth: look.stroke.primary) }
                    .offset(x: down ? sink : 0, y: down ? sink : 0)
                    .background { Capsule().fill(look.shadowInk).offset(x: sink, y: sink) }
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.09), value: pressed)
            case (_, false):
                // C's pressable: the ink / bone outline; the fill darkens while pressed.
                label.foregroundStyle(look.textPrimary)
                    .background(pressed ? look.pressedFill : look.surface, in: Capsule())
                    .overlay { Capsule().strokeBorder(look.outline, lineWidth: look.stroke.pressable) }
            }
        }
        .contentShape(Capsule())
        .pressFeedback(pressed, look.id.isPaperClub ? .none : .scale)
    }
}

/// The pinned tray: A the rest bar's glass bar, B Liquid Glass over graphite, C a paper sheet
/// with a soft rule (C keeps its ink slab for the heart-rate plate only).
struct CardioTrayBackground: View {
    @Environment(\.look) private var look

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: look.radius.bar, style: .continuous)
        switch look.id {
        case .floodlight:
            shape.fill(look.slab)
                .background(.ultraThinMaterial, in: shape)
                .overlay { shape.strokeBorder(look.slabEdge, lineWidth: 1) }
                .shadow(color: look.floatShadow(0.5), radius: 14, x: 0, y: 6)
        case .anatomy:
            Color.clear
                .glassEffect(.regular.tint(look.slab), in: shape)
                .overlay { shape.strokeBorder(look.slabEdge, lineWidth: 1) }
        case .paper, .carbon:
            // Information level (sheet + soft rule): the ink slab stays for the heart-rate plate.
            shape.fill(look.surface)
                .overlay { shape.strokeBorder(look.hairline, lineWidth: 1.5) }
        }
    }
}

/// The ground under the tray: a fade band (scrolled content reads as scrolled, not collided)
/// and then solid ground down to the screen edge, so nothing shows under or around the slab.
struct CardioDockGround: View {
    var fade: CGFloat = 26
    @Environment(\.look) private var look

    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [look.ground.opacity(0), look.ground], startPoint: .top, endPoint: .bottom)
                .frame(height: fade)
            look.ground
        }
        .padding(.top, -fade)
        .ignoresSafeArea(edges: .bottom)
        .allowsHitTesting(false)
    }
}

// MARK: - Activity disc

/// The activity figure in a disc: A a raised cell disc, B the quiet control disc, C an outlined
/// ring on the ground. Used by the picker tiles, the live header and the segment cards, so an
/// activity always wears the same badge.
struct CardioActivityDisc: View {
    var symbol: String
    var size: CGFloat

    @Environment(\.look) private var look

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(look.textPrimary)
            .frame(width: size, height: size)
            .background(fill, in: Circle())
            .overlay {
                if look.id.isPaperClub {
                    Circle().strokeBorder(look.outline, lineWidth: 1.5)
                }
            }
            .accessibilityHidden(true)
    }

    private var fill: Color {
        switch look.id {
        case .floodlight: look.surfaceRaised
        case .anatomy: look.controlFill
        case .paper, .carbon: look.ground
        }
    }
}

// MARK: - Selection edge (picker tiles)

extension View {
    /// A selected tile: the look's selection colour as a heavier edge (A/B 2 pt over a white
    /// lozenge tint, C a 3 pt cobalt pen line).
    func cardioSelected(_ selected: Bool, radius: CGFloat, look: Look) -> some View {
        overlay {
            if selected {
                let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
                ZStack {
                    if !look.id.isPaperClub { shape.fill(look.segmentFill.opacity(0.5)) }
                    shape.strokeBorder(look.selection, lineWidth: look.id.isPaperClub ? 3 : 2)
                }
                .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - Sheet header

/// Cancel on glass · title · Save. Save keeps its filled capsule in every look and drops to
/// 40 % while there is nothing to save (the shared SheetHeader draws C's disabled Save as bare
/// text, which made the header lopsided).
struct CardioSheetHeader: View {
    var title: String
    var commitEnabled: Bool
    var cancel: () -> Void
    var commit: () -> Void
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 44

    var body: some View {
        ZStack {
            Text(title)
                .font(look.font.navTitle)
                .foregroundStyle(look.textPrimary)
                .lineLimit(1)
                .padding(.horizontal, 100)
                .accessibilityAddTraits(.isHeader)
            HStack {
                GlassCapsuleButton("Cancel", action: cancel)
                Spacer()
                Button(action: commit) {
                    Text("Save")
                        .font(look.font.button)
                        .foregroundStyle(look.onAction)
                        .padding(.horizontal, 18)
                        .frame(minHeight: height)
                        .background(look.action, in: Capsule())
                        .overlay {
                            if look.id.isPaperClub { Capsule().strokeBorder(look.outline, lineWidth: 2) }
                        }
                        .opacity(commitEnabled ? 1 : 0.4)
                }
                .buttonStyle(.lookPressable)
                .disabled(!commitEnabled)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .accessibilityShowsLargeContentViewer { Text("Save") }
                .animation(.easeOut(duration: 0.15), value: commitEnabled)
            }
        }
        .padding(.horizontal, look.space.margin)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
}

// MARK: - Dynamic Type in sheets

/// The shell applies its AccessibilityL capture override to the live cover but not to sheets;
/// Cardio's sheets apply it themselves so `-axl YES` captures them at AX1 too.
struct CardioTypeOverride: ViewModifier {
    var size: DynamicTypeSize?
    func body(content: Content) -> some View {
        if let size { content.dynamicTypeSize(size) } else { content }
    }
}
