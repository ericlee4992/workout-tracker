import SwiftUI

// C02–C05: the cardio focus of the live workout (Lifting | Cardio → Cardio).
//
// Embedding contract (for the Live area): CardioLivePanel fills the space it is given. It owns
// its ScrollView and pins its Pause / End Cardio tray with `safeAreaInset(edge: .bottom)` over
// solid ground (nothing scrolls visibly under it), so place it as the flexible remainder under
// the live header — not inside another ScrollView. It paints the screen ground.
//
// States:
//  • recording    → activity line + Recording pill, the ring (the one bold element), figures,
//                   heart-rate plate; tray: Pause (filled) · End Cardio.
//                   The ring's centre is always what the ring counts: time against a planned
//                   target, distance toward the next mile / km (then Time moves into the
//                   figures), or time on a 60-second sweep.
//  • paused       → inverted "Paused 0:42" pill, the recorded ring switches off (A hollow bulbs,
//                   B/C dotted), the pause glyph breathes over the still clock; tray: Resume.
//  • outdoor      → GPS line under the name; GPS lost = a "Location unavailable." plate, the ring
//                   stalls at a slashed pin. Never a map (routes appear after Finish / in History).
//  • nothing live → planned target with Start (+ last time, lifting so far), ended-segment cards
//                   (distance editable), Add Cardio; or the empty state.
// View-level variants: see CardioVariants.applyPanel; "p2"/"p3" scroll to the end.

struct CardioLivePanel: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @State private var scrolledForVariant = false
    /// The panel's size and the pinned tray's height, so the live block can fit the first
    /// viewport (the Live screen gives the panel less room than the full screen).
    @State private var panelSize: CGSize = .zero
    @State private var trayHeight: CGFloat = 0

    private static let bottomID = "cardio.bottom"

    var body: some View {
        let session = store.session
        let live = session?.unfinishedCardio
        let ended = Array((session?.cardio ?? []).filter(\.isEnded).reversed())
        let plans = live == nil ? store.cardioPendingPlans : []
        let isEmpty = live == nil && plans.isEmpty && ended.isEmpty

        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: look.space.section) {
                    if let live {
                        CardioLiveBlock(segment: live, visibleHeight: max(0, panelSize.height - trayHeight),
                                        width: panelSize.width)
                            .id(live.id)
                            .transition(.opacity)
                    }
                    if let first = plans.first {
                        VStack(alignment: .leading, spacing: look.space.header) {
                            SectionHeader("Planned cardio")
                            CardioPlanHero(plan: first)
                            ForEach(plans.dropFirst()) { CardioPlanCard(plan: $0) }
                        }
                    }
                    if isEmpty {
                        EmptyStateView(symbol: "figure.run", title: "Add cardio to this workout",
                                       actionTitle: "Add Cardio") { router.present(.cardioPicker) }
                            .padding(.top, 40)
                    }
                    if !ended.isEmpty {
                        VStack(spacing: look.space.group) {
                            ForEach(ended) { segment in
                                CardioSummaryCard(segment: segment)
                                    .transition(.asymmetric(insertion: .scale(scale: 0.96).combined(with: .opacity),
                                                            removal: .opacity))
                            }
                        }
                    }
                    if !isEmpty {
                        Button { router.present(.cardioPicker) } label: {
                            Label("Add Cardio", systemImage: "plus")
                        }
                        .buttonStyle(.lookSecondary)
                    }
                    Color.clear.frame(height: 1).id(Self.bottomID)
                }
                .padding(.horizontal, look.space.margin)
                .padding(.top, 14)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .onAppear {
                CardioVariants.applyPanel(router.variant, store: store)
                scrollForVariant(proxy)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let live {
                CardioControlTray(segment: live)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { trayHeight = $0 }
                    .background { CardioDockGround() }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if Proposal.shared.finishAtBottom {
                // PROPOSAL: once the activity has ended, the same slot finishes the workout.
                ProposedCardioFinish()
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { panelSize = $0 }
        .lookScreenBackground()
        // Captures (frozen clock): pulses, blinks and flickers rest at their full state.
        .environment(\.cardioStill, store.freezeClock)
    }

    /// `-variant p2` / `p3`: show the end of the panel (it is at most ~1.5 viewports).
    private func scrollForVariant(_ proxy: ScrollViewProxy) {
        guard !scrolledForVariant else { return }
        let t = CardioVariants.tokens(router.variant)
        guard t.contains("p2") || t.contains("p3") else { return }
        scrolledForVariant = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            proxy.scrollTo(Self.bottomID, anchor: .bottom)
        }
    }
}

// MARK: - Live segment

private struct CardioLiveBlock: View {
    var segment: LiveCardio
    /// The panel height above the tray (0 = unknown). Under ~640 pt (the Live screen's header
    /// and switch sit above) the block goes compact so the heart-rate plate clears the tray.
    var visibleHeight: CGFloat = 0
    var width: CGFloat = 0
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var ringSide: CGFloat = 236
    @ScaledMetric(relativeTo: .title3) private var discSize: CGFloat = 44

    /// What the ring counts, and what its centre says.
    private struct RingModel {
        var progress: Double
        var ticks: Int
        var centre: String
        var caption: String?
        /// The centre is a distance (the ring counts toward the next mile / km).
        var countsDistance = false
        var targetDone = false
        /// Changes when a split completes (A lights, a light haptic).
        var splitIndex = 0
    }

    private var ax: Bool { typeSize.isAccessibilitySize }

    private var compact: Bool {
        visibleHeight > 0 && visibleHeight < 640 && !ax
    }

    /// The ring's side: scaled and capped; at AX sizes about 45 % of the width so the figures
    /// and the heart-rate plate reach the first viewport; in compact, what is left after the
    /// other parts (about 336 pt, plus the GPS line or plate), never under 176.
    private var ringDiameter: CGFloat {
        let full = min(ringSide, 330)
        if ax { return max(150, min(full, (width > 0 ? width : 430) * 0.45)) }
        guard compact else { return full }
        var rest: CGFloat = 336
        if segment.activity.isOutdoor { rest += segment.gps == .unavailable ? 84 : 8 }
        return min(full, max(176, visibleHeight - rest))
    }

    var body: some View {
        let active = segment.activeSeconds(at: store.now)
        let model = ringModel(active: active)
        let paused = segment.isPaused

        VStack(alignment: .leading, spacing: compact || ax ? 14 : 20) {
            header(paused: paused)
            hero(active: active, model: model, paused: paused)
                .frame(maxWidth: .infinity)
            if segment.activity.isOutdoor && segment.gps == .unavailable {
                gpsLostPlate
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
            VStack(spacing: compact ? 10 : look.space.group) {
                CardioStatGrid(stats: stats(active: active, model: model, paused: paused),
                               numberFont: compact ? look.font.statNumber : nil, dense: compact || ax)
                CardioHeartPlate(isRunning: segment.isRunning)
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85), value: paused)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: segment.gps)
        .sensoryFeedback(.success, trigger: model.targetDone) { _, new in new }
        .sensoryFeedback(.impact(weight: .light), trigger: model.splitIndex)
    }

    private func ringModel(active: Int) -> RingModel {
        if let plan = store.cardioPlan(for: segment) {
            let target = max(60, plan.minutes * 60)
            return RingModel(progress: Double(active) / Double(target), ticks: plan.minutes < 5 ? 12 : min(60, plan.minutes),
                             centre: Format.elapsed(active),
                             caption: "of \(Format.elapsed(target))", targetDone: active >= target)
        }
        if let meters = segment.distanceMeters, meters > 0 {
            let units = meters / segment.unit.metersPerUnit
            let whole = units.rounded(.down)
            return RingModel(progress: units - whole, ticks: 10,
                             centre: CardioFormat.distance(meters, segment.unit),
                             caption: CardioFormat.splitTarget(Int(whole) + 1, segment.unit),
                             countsDistance: true, splitIndex: Int(whole))
        }
        return RingModel(progress: Double(active % 60) / 60, ticks: 12, centre: Format.elapsed(active), caption: nil)
    }

    // MARK: Header: activity · GPS · Recording / Paused

    private func header(paused: Bool) -> some View {
        let pausedFor = CardioPauseLedger.pausedSeconds(segment, store: store)
        return ViewThatFits(in: .horizontal) {
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
                if segment.activity.isOutdoor && segment.gps != .unavailable {
                    gpsLine
                }
            }
        }
    }

    /// "GPS" with live bars, or "Waiting for GPS…" with searching bars.
    /// PROTOTYPE: tapping it simulates losing GPS (Store.setGPSUnavailable).
    private var gpsLine: some View {
        Button { store.setGPSUnavailable(true) } label: {
            HStack(spacing: 6) {
                CardioSignalBars(state: segment.gps, color: look.textPrimary, track: look.ringTrack)
                Text(segment.gps.message ?? "GPS")
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(look.textSecondary)
            }
            .frame(minHeight: 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(segment.gps == .waiting ? "Waiting for GPS" : "GPS")
    }

    // MARK: Hero ring

    @ViewBuilder
    private func hero(active: Int, model: RingModel, paused: Bool) -> some View {
        // An indoor distance ring edits its distance (its centre is the distance).
        if model.countsDistance && !segment.activity.isOutdoor {
            let id = segment.id
            Button { router.present(.cardioDistance(segmentID: id)) } label: {
                ring(active: active, model: model, paused: paused)
            }
            .buttonStyle(.lookPressable)
            .accessibilityHint("Edits the distance")
        } else {
            ring(active: active, model: model, paused: paused)
        }
    }

    private func ring(active: Int, model: RingModel, paused: Bool) -> some View {
        let side = ringDiameter
        let width = (side * 0.066).rounded()
        let tint = look.id == .anatomy ? store.currentZone.map(look.zone) : nil
        // GPS lost on a distance ring: the ring stalls at a pin while the clock runs on.
        let stalled = segment.gps == .unavailable && model.countsDistance
        let phase: CardioRingPhase = paused ? .paused : (stalled ? .stalled : .recording)
        let editable = model.countsDistance && !segment.activity.isOutdoor
        return CardioRing(progress: model.progress, ticks: model.ticks, phase: phase,
                          tint: tint, size: side, lineWidth: width, notch: look.ground) {
            VStack(spacing: 4) {
                if paused {
                    Image(systemName: "pause.fill")
                        .font(.system(size: max(14, side * 0.08), weight: .heavy))
                        .foregroundStyle(look.textPrimary)
                        .modifier(CardioBlink(active: true))
                        .transition(.scale.combined(with: .opacity))
                }
                Text(model.centre)
                    .font(look.cardioHeroFont(size: side * 0.212))
                    .foregroundStyle(paused || stalled ? look.textSecondary : look.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText(countsDown: false))
                    .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: model.centre)
                if let caption = model.caption {
                    HStack(spacing: 4) {
                        if model.targetDone {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(look.id.isPaperClub ? look.actionText : look.textPrimary)
                        }
                        Text(caption)
                        if editable {
                            Image(systemName: "pencil")
                                .foregroundStyle(look.id.isPaperClub ? look.actionText : look.textPrimary)
                        }
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
        .accessibilityLabel(heroLabel(active: active, model: model, paused: paused))
    }

    private func heroLabel(active: Int, model: RingModel, paused: Bool) -> String {
        var parts = [segment.activity.name, Format.spokenElapsed(active)]
        if model.countsDistance { parts.append("\(model.centre) \(segment.unit.label)") }
        if let caption = model.caption { parts.append(caption) }
        parts.append(paused ? "Paused" : "Recording")
        return parts.joined(separator: ", ")
    }

    // MARK: GPS lost

    /// "Location unavailable." (real copy): time keeps recording, distance stops.
    /// PROTOTYPE: tapping it brings GPS back (waits for a fix, then a new route portion).
    private var gpsLostPlate: some View {
        Button { store.setGPSUnavailable(false) } label: {
            HStack(spacing: 14) {
                Image(systemName: "location.slash.fill")
                    .font(.system(.body, weight: .bold))
                    .foregroundStyle(look.ground)
                    .frame(width: 42, height: 42)
                    .background(look.textPrimary, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Location unavailable.")
                        .font(.system(.headline, design: look.id == .anatomy ? .rounded : .default, weight: .bold))
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
        }
        .buttonStyle(.lookPressable)
        .accessibilityElement(children: .combine)
    }

    // MARK: Figures

    private func stats(active: Int, model: RingModel, paused: Bool) -> [CardioStat] {
        let unit = segment.unit
        let usesSpeed = segment.activity.usesSpeed
        let gpsLost = segment.gps == .unavailable
        let editable = !segment.activity.isOutdoor
        let segmentID = segment.id
        let now = store.now

        var list: [CardioStat] = []
        if model.countsDistance {
            // The ring's centre carries the distance; the active time moves here.
            list.append(CardioStat(label: "Time", symbol: "timer", value: Format.elapsed(active), unit: nil,
                                   dimmed: paused))
        } else {
            list.append(CardioStat(
                label: segment.manualDistance != nil ? "Entered distance" : "Distance",
                symbol: CardioStat.distanceSymbol,
                value: CardioFormat.distance(segment.distanceMeters, unit), unit: unit.label,
                dimmed: paused || gpsLost,
                accessory: gpsLost ? "location.slash" : (editable ? "pencil" : nil),
                action: editable ? { router.present(.cardioDistance(segmentID: segmentID)) } : nil))
        }
        if usesSpeed {
            list.append(CardioStat(label: "Current speed", symbol: "gauge.with.needle",
                                   value: CardioFormat.speed(segment.currentSpeedPerHour), unit: CardioFormat.speedUnit(unit)))
            list.append(CardioStat(label: "Average speed", symbol: "stopwatch",
                                   value: CardioFormat.speed(segment.speedPerHour(at: now)), unit: CardioFormat.speedUnit(unit),
                                   dimmed: paused))
        } else {
            list.append(CardioStat(label: "Current pace", symbol: "gauge.with.needle",
                                   value: CardioFormat.pace(segment.currentPaceSecondsPerUnit), unit: CardioFormat.paceUnit(unit)))
            list.append(CardioStat(label: "Average pace", symbol: "stopwatch",
                                   value: CardioFormat.pace(segment.paceSecondsPerUnit(at: now)), unit: CardioFormat.paceUnit(unit),
                                   dimmed: paused))
        }
        if segment.activeCalories >= 0.5 || segment.heartRateCount > 0 {
            list.append(CardioStat(label: "Active calories", symbol: "flame.fill",
                                   value: "\(Int(segment.activeCalories.rounded()))", unit: "cal", dimmed: paused))
        }
        return list
    }
}

// MARK: - Status pill

/// Recording: a pulsing dot on a quiet pill. Paused: the pill inverts (solid text colour,
/// ground-coloured words) and counts how long the pause has lasted ("Paused 0:42").
private struct CardioStatusPill: View {
    var paused: Bool
    var pausedSeconds: Int = 0
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .subheadline) private var height: CGFloat = 34

    var body: some View {
        HStack(spacing: 7) {
            if paused {
                Image(systemName: "pause.fill").font(.system(.caption, weight: .heavy))
                Text("Paused")
                Text(Format.elapsed(pausedSeconds))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            } else {
                CardioPulseDot(color: look.cardioLive, size: 9, ripple: 0.9)
                    .padding(.trailing, 2)
                Text("Recording")
            }
        }
        .font(.system(.subheadline, design: look.id == .anatomy ? .rounded : .default, weight: .bold))
        .foregroundStyle(paused ? look.ground : look.textPrimary)
        .padding(.horizontal, 13)
        .frame(minHeight: height)
        .background(paused ? look.textPrimary : look.surface, in: Capsule())
        .overlay {
            if !paused {
                Capsule().strokeBorder(look.hairline, lineWidth: look.stroke.hairline)
            }
        }
        .contentTransition(.opacity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(paused ? "Paused for \(Format.spokenElapsed(pausedSeconds))" : "Recording")
    }
}

// MARK: - Figures grid

struct CardioStat: Identifiable {
    static let distanceSymbol = "point.bottomleft.forward.to.point.topright.scurvepath"

    var id: String { label }
    var label: String
    var symbol: String
    var value: String
    var unit: String?
    var tint: Color? = nil
    var symbolTint: Color? = nil
    var dimmed = false
    /// A glyph after the label: "pencil" (editable), "location.slash" (GPS lost).
    var accessory: String? = nil
    var action: (() -> Void)? = nil
}

/// Paired figures, grouped per look: A one scoreboard panel split by hairlines, B separate
/// solid tiles, C one ticket per pair. `.table` puts the pairs inside an existing card.
/// AX sizes keep the pairs (labels wrap to two lines, numerals may shrink to 0.7×) so the
/// figures and the heart-rate plate still reach the first viewport above the tray.
struct CardioStatGrid: View {
    enum Style { case grouped, table }
    var stats: [CardioStat]
    var style: Style = .grouped
    var numberFont: Font?
    /// Tighter cells (the compact live block, AX sizes).
    var dense = false
    @Environment(\.look) private var look

    private var rows: [[CardioStat]] {
        stride(from: 0, to: stats.count, by: 2).map { Array(stats[$0..<min($0 + 2, stats.count)]) }
    }

    var body: some View {
        let font = numberFont ?? look.font.bigNumber
        switch (style, look.id) {
        case (.table, _), (.grouped, .floodlight):
            let table = VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    if index > 0 { LookDivider() }
                    pair(row, font: font)
                }
            }
            if style == .table { table } else { table.lookSurface(.stat) }
        case (.grouped, .anatomy):
            VStack(spacing: 10) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 10) {
                        ForEach(row) { stat in
                            CardioStatCell(stat: stat, numberFont: font, dense: dense)
                                .frame(maxHeight: .infinity, alignment: .topLeading)
                                .lookSurface(.stat)
                        }
                        if row.count == 1 { Color.clear.frame(maxWidth: .infinity) }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        case (.grouped, _):
            VStack(spacing: 12) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    pair(row, font: font).lookSurface(.stat)
                }
            }
        }
    }

    private func pair(_ row: [CardioStat], font: Font) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(row.enumerated()), id: \.element.id) { index, stat in
                if index > 0 { LookDivider(vertical: true) }
                CardioStatCell(stat: stat, numberFont: font, dense: dense)
                    .frame(maxHeight: .infinity, alignment: .topLeading)
            }
            if row.count == 1 {
                LookDivider(vertical: true)
                Color.clear.frame(maxWidth: .infinity)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Small label (with its glyph) over a big number and a small unit.
struct CardioStatCell: View {
    var stat: CardioStat
    var numberFont: Font
    var dense = false
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let action = stat.action {
            Button(action: action) { content }
                .buttonStyle(.lookPressable)
                .accessibilityHint("Edits the distance")
        } else {
            content
        }
    }

    private var content: some View {
        let ax = typeSize.isAccessibilitySize
        return VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Image(systemName: stat.symbol)
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(stat.symbolTint ?? (look.id.isPaperClub ? look.textPrimary : look.textSecondary))
                Text(stat.label)
                    .font(look.cardioLabelFont)
                    .foregroundStyle(look.textSecondary)
                    .lineLimit(ax ? 2 : 1)
                    .minimumScaleFactor(ax ? 1 : 0.8)
                    .fixedSize(horizontal: false, vertical: ax)
                if let accessory = stat.accessory {
                    Image(systemName: accessory)
                        .font(.system(.caption, weight: .bold))
                        .foregroundStyle(stat.action != nil ? (look.id.isPaperClub ? look.actionText : look.textPrimary) : look.textSecondary)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(stat.value)
                    .font(numberFont)
                    .foregroundStyle(stat.value == "—" ? look.textTertiary
                                     : (stat.dimmed ? look.textSecondary : (stat.tint ?? look.textPrimary)))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .contentTransition(.numericText())
                    .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: stat.value)
                if let unit = stat.unit, stat.value != "—" {
                    Text(unit).font(look.cardioUnitFont).foregroundStyle(look.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .padding(.horizontal, ax ? 12 : 16)
        .padding(.top, dense ? 10 : 13)
        .padding(.bottom, dense ? 9 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([stat.label, stat.value == "—" ? "no reading" : stat.value, stat.value == "—" ? nil : stat.unit]
            .compactMap { $0 }.joined(separator: " "))
    }
}

// MARK: - Heart rate plate

/// Heart rate while cardio records: the beating bpm, the zone meter and the last six minutes
/// as one smoothed zone-coloured line. A/B a panel, C the ink slab (an instrument).
/// Missing ≠ zero: no reading → the plate waits ("Waiting for heart-rate data") while
/// recording, else nothing.
private struct CardioHeartPlate: View {
    var isRunning: Bool
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        switch store.hrFeed {
        case .live:
            if let bpm = store.currentBPM { plate(bpm: bpm, zone: store.currentZone, stale: false) }
        case .stale(let lastBpm, _):
            plate(bpm: lastBpm, zone: nil, stale: true)
        case .waiting:
            if isRunning { waiting }
        }
    }

    private var onSlab: Bool { look.id.isPaperClub }

    private func plate(bpm: Int, zone: HeartRateZone?, stale: Bool) -> some View {
        let secondary = onSlab ? look.onSlabSecondary : look.textSecondary
        let valueColor: Color = stale ? (onSlab ? look.onSlabSecondary : look.textTertiary) : (onSlab ? look.onSlab : look.heartRate)
        let slots = store.cardioRecentHeartRate()
        let stacked = typeSize.isAccessibilitySize
        let noZones = store.maxHeartRate == nil
        let readout = VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                BeatingHeart(bpm: bpm, isFresh: !stale, font: .system(.title3, weight: .bold))
                Text("\(bpm)")
                    .font(look.font.bigNumber)
                    .foregroundStyle(valueColor)
                    .contentTransition(.numericText(value: Double(bpm)))
                    .lineLimit(1)
                Text("bpm").font(look.cardioUnitFont).foregroundStyle(secondary)
            }
            HStack(spacing: 7) {
                if noZones {
                    Image(systemName: "slider.horizontal.3").font(.system(.footnote, weight: .bold))
                        .foregroundStyle(onSlab ? look.onSlab : look.textPrimary)
                } else {
                    CardioZoneMeter(zone: stale ? nil : zone)
                }
                Text(zone?.label ?? (noZones ? "Set up zones" : "Heart rate"))
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(onSlab ? look.onSlab : (noZones ? look.textPrimary : look.textSecondary))
            }
        }
        return Button { router.present(.maxHeartRate) } label: {
            HeartRatePlate(title: nil) {
                // The trace stays beside the readout at AX sizes too (narrower), so the plate
                // keeps one row above the tray.
                HStack(alignment: .center, spacing: stacked ? 10 : 14) {
                    readout.layoutPriority(1)
                    Spacer(minLength: 4)
                    // Under two minutes there is no shape yet: the number stands alone.
                    if slots.count >= 8 {
                        CardioHRTrace(points: slots, zoneBounds: store.cardioZoneBounds)
                            .frame(minWidth: 60, maxWidth: 140)
                            .frame(height: 48)
                    }
                }
            }
        }
        .buttonStyle(.lookPressable)
        .animation(.easeInOut(duration: 0.6), value: zone)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Heart rate \(bpm) beats per minute\(zone.map { ", \($0.label)" } ?? "")\(stale ? ", not current" : "")")
        .accessibilityHint(noZones ? "Sets up heart-rate zones" : "")
    }

    /// No reading yet: the same plate, its heart outlined and still, and a flat dashed baseline
    /// where the trace will draw.
    private var waiting: some View {
        HeartRatePlate(title: nil) {
            HStack(spacing: 12) {
                Image(systemName: "heart")
                    .font(.system(.title3, weight: .bold))
                    .foregroundStyle(onSlab ? look.onSlabSecondary : look.textTertiary)
                Text("Waiting for heart-rate data")
                    .font(look.font.subhead)
                    .foregroundStyle(onSlab ? look.onSlab : look.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .frame(minHeight: 44)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Ended segment

/// A finished segment in the running workout. The header carries its badge, name and the
/// active time as the card's big number ("20:05 of 20:00"), with the done ring (fully lit with a
/// check in a lit disc once the target was met). Below, the figures pair up in a hairline table;
/// Distance is the one editable figure (pencil; an outdoor one also shows it came from GPS) and
/// opens the Distance sheet (C05).
private struct CardioSummaryCard: View {
    var segment: LiveCardio
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var landed = 0
    @ScaledMetric(relativeTo: .title3) private var discSize: CGFloat = 40

    var body: some View {
        let plan = store.cardioPlan(for: segment)
        let progress = segment.plannedID.flatMap { store.plannedProgress($0) } ?? 1
        let met = progress >= 1
        let active = segment.activeSeconds(at: segment.endedAt ?? store.now)
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                CardioActivityDisc(symbol: segment.activity.symbol, size: discSize)
                VStack(alignment: .leading, spacing: 4) {
                    Text(segment.activity.name)
                        .font(look.font.cardTitle)
                        .foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    timeLine(active: active, plan: plan)
                }
                Spacer(minLength: 8)
                CardioRing(progress: progress, ticks: min(12, plan?.minutes ?? 12), phase: .still, tint: nil,
                           size: 54, lineWidth: 6, notch: look.surface) {
                    if met {
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundStyle(look.onDone)
                            .frame(width: 30, height: 30)
                            .background(look.done, in: Circle())
                    }
                }
                .celebrate(landed)
                .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .accessibilityElement(children: .combine)
            LookDivider()
            CardioStatGrid(stats: stats, style: .table, numberFont: look.font.statNumber)
        }
        .lookSurface(.panel)
        .sensoryFeedback(.success, trigger: landed)
        .onAppear {
            // The moment End Cardio lands it: bump the ring once.
            if let ended = segment.endedAt, store.now.timeIntervalSince(ended) < 3 { landed += 1 }
        }
    }

    /// "20:05" big, then "of 20:00" (the target) small; they stack at AX sizes.
    private func timeLine(active: Int, plan: PlannedCardio?) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 6))
        return layout {
            Text(Format.elapsed(active))
                .font(look.font.bigNumber)
                .foregroundStyle(look.textPrimary)
                .monospacedDigit()
            if let plan {
                Text("of \(Format.elapsed(plan.minutes * 60))")
                    .font(look.cardioUnitFont)
                    .foregroundStyle(look.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Format.spokenElapsed(active) + (plan.map { ", target \($0.minutes) minutes" } ?? ""))
    }

    private var stats: [CardioStat] {
        let unit = segment.unit
        let end = segment.endedAt ?? store.now
        let segmentID = segment.id
        let fromGPS = segment.activity.isOutdoor && segment.manualDistance == nil
        var list = [CardioStat(
            label: segment.manualDistance != nil ? "Entered distance" : "Distance",
            symbol: fromGPS ? "location.fill" : CardioStat.distanceSymbol,
            value: segment.distanceMeters.map { CardioFormat.distanceValue($0 / unit.metersPerUnit) } ?? "—",
            unit: unit.label, accessory: "pencil",
            action: { router.present(.cardioDistance(segmentID: segmentID)) })]
        if segment.activity.usesSpeed {
            list.append(CardioStat(label: "Average speed", symbol: "stopwatch",
                                   value: CardioFormat.speed(segment.speedPerHour(at: end)),
                                   unit: CardioFormat.speedUnit(unit)))
        } else {
            list.append(CardioStat(label: "Average pace", symbol: "stopwatch",
                                   value: CardioFormat.pace(segment.paceSecondsPerUnit(at: end)),
                                   unit: CardioFormat.paceUnit(unit)))
        }
        if let hr = segment.averageHeartRate {
            list.append(CardioStat(label: "Avg. heart rate", symbol: "heart.fill", value: "\(hr)", unit: "bpm",
                                   tint: look.id.isPaperClub ? nil : look.heartRate, symbolTint: look.heartRate))
        }
        if segment.activeCalories >= 0.5 {
            list.append(CardioStat(label: "Active calories", symbol: "flame.fill",
                                   value: "\(Int(segment.activeCalories.rounded()))", unit: "cal"))
        }
        return list
    }
}

// MARK: - Planned target (not started)

/// Today's planned cardio, waiting for its explicit Start: the empty target ring (one notch or
/// segment per minute) around the target time, its Start capsule, then two quiet facts — the
/// last time this activity was done and the lifting so far. Pressing Start turns this ring into
/// the recording ring in the same place.
private struct CardioPlanHero: View {
    var plan: PlannedCardio
    @Environment(Store.self) private var store
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var ringSide: CGFloat = 200
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 44

    var body: some View {
        let side = min(ringSide, 280)
        let width = (side * 0.066).rounded()
        VStack(spacing: 20) {
            CardioRing(progress: 0, ticks: plan.minutes < 5 ? 12 : min(60, plan.minutes), phase: .still, tint: nil,
                       size: side, lineWidth: width, notch: look.ground) {
                VStack(spacing: 4) {
                    // The target, not a running clock: secondary until Start.
                    Text(Format.elapsed(plan.minutes * 60))
                        .font(look.cardioHeroFont(size: min(heroSize, side * 0.22)))
                        .foregroundStyle(look.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    HStack(spacing: 6) {
                        Image(systemName: plan.activity.symbol)
                        Text(plan.distance.map { "\(Format.number($0)) \(plan.unit.label)" } ?? plan.activity.name)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .font(look.cardioCaptionFont)
                    .foregroundStyle(look.textSecondary)
                }
                .frame(width: side - 2 * width - 30)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(plan.activity.name), target \(CardioFormat.plan(plan))")

            StartCapsule(title: "Start \(plan.activity.name)", symbol: plan.activity.symbol) {
                withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.85)) {
                    store.startPlannedCardio(plan.id)
                }
            }
            .frame(maxWidth: .infinity)

            facts
        }
        .frame(maxWidth: .infinity)
    }

    /// "Last Indoor Run · 3.10 mi · 28:40 · Sep 21" and "Lifting 22/22 sets" — numbers, no prose.
    @ViewBuilder private var facts: some View {
        let last = store.cardioLastDone(plan.activity)
        let session = store.session
        let lifting = (session?.totalSetCount ?? 0) > 0 ? session : nil
        if last != nil || lifting != nil {
            LookList {
                if let last {
                    CardioFactRow(symbol: "clock.arrow.circlepath", label: "Last \(plan.activity.name)",
                                  values: [last.segment.distanceMeters.map { CardioFormat.distanceValue($0 / last.segment.unit.metersPerUnit) + " " + last.segment.unit.label },
                                           Format.elapsed(last.segment.activeSeconds),
                                           Format.shortDate(last.date)].compactMap { $0 })
                }
                if let lifting {
                    CardioFactRow(symbol: "figure.strengthtraining.traditional", label: "Lifting",
                                  values: ["\(lifting.completedSetCount)/\(lifting.totalSetCount) sets"],
                                  sets: (lifting.completedSetCount, lifting.totalSetCount))
                }
            }
        }
    }
}

/// A quiet fact row: glyph · small label · values (numbers in the number face); at AX sizes
/// the values move under the label.
private struct CardioFactRow: View {
    var symbol: String
    var label: String
    var values: [String]
    var sets: (done: Int, total: Int)? = nil
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var glyphColumn: CGFloat = 26

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        HStack(alignment: .center, spacing: 12) {
            LookIcon(symbol, style: .body)
                .foregroundStyle(look.id.isPaperClub ? look.textPrimary : look.textSecondary)
                .frame(width: glyphColumn)
            layout {
                Text(label)
                    .font(look.font.subhead)
                    .foregroundStyle(look.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
                HStack(spacing: 8) {
                    if let sets {
                        SetsRing(done: sets.done, total: sets.total, size: 18)
                            .accessibilityHidden(true)
                    }
                    Text(values.joined(separator: " · "))
                        .font(.system(.subheadline, design: look.id == .anatomy ? .rounded : .default, weight: .bold).monospacedDigit())
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

/// A second (or later) planned target: compact card with its Start.
private struct CardioPlanCard: View {
    var plan: PlannedCardio
    @Environment(Store.self) private var store
    @Environment(\.look) private var look

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                CardioRing(progress: 0, ticks: plan.minutes < 5 ? 12 : min(60, plan.minutes), phase: .still, tint: nil,
                           size: 64, lineWidth: 7, notch: look.surface) {
                    Text("\(plan.minutes)")
                        .font(look.font.smallNumber)
                        .foregroundStyle(look.textPrimary)
                        .minimumScaleFactor(0.7)
                }
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(plan.activity.name)
                        .font(look.font.cardTitle)
                        .foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(CardioFormat.plan(plan))
                        .font(look.font.subhead)
                        .foregroundStyle(look.textSecondary)
                }
                Spacer(minLength: 0)
            }
            Button { store.startPlannedCardio(plan.id) } label: {
                Label("Start \(plan.activity.name)", systemImage: plan.activity.symbol)
            }
            .buttonStyle(.lookSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lookSurface(.panel)
    }
}

// MARK: - Control tray

/// Pinned at the thumb, in the rest bar's slot. Pause (or Resume) is the state's one filled
/// command; End Cardio is quiet and narrower (it ends the segment at once, as today). At AX
/// sizes the two stay side by side (icons drop first) so the tray keeps one row.
private struct CardioControlTray: View {
    var segment: LiveCardio
    @Environment(Store.self) private var store
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var toggles = 0
    @State private var ends = 0
    @ScaledMetric(relativeTo: .headline) private var endWidth: CGFloat = 158

    var body: some View {
        let ax = typeSize.isAccessibilitySize
        ViewThatFits(in: .horizontal) {
            row(icons: true, equal: true)
            row(icons: false, equal: true)
            VStack(spacing: 10) {
                pause(icons: true)
                end(icons: true)
            }
        }
        .padding(look.id.isPaperClub ? 14 : 12)
        .background { CardioTrayBackground() }
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
        .sensoryFeedback(.impact(weight: .medium), trigger: toggles)
        .sensoryFeedback(.impact(weight: .heavy), trigger: ends)
    }

    private func row(icons: Bool, equal: Bool) -> some View {
        HStack(spacing: 12) {
            pause(icons: icons)
            end(icons: icons)
                .frame(maxWidth: equal ? .infinity : endWidth)
        }
    }

    private func pause(icons: Bool) -> some View {
        let paused = segment.isPaused
        let id = segment.id
        return Button {
            toggles += 1
            withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8)) {
                if paused {
                    store.resumeCardio()
                    CardioPauseLedger.pausedAt[id] = nil
                } else {
                    CardioPauseLedger.pausedAt[id] = store.now
                    store.pauseCardio()
                }
            }
        } label: {
            label(paused ? "Resume" : "Pause", symbol: paused ? "play.fill" : "pause.fill", icons: icons)
        }
        .buttonStyle(CardioTrayButtonStyle(prominent: true))
    }

    private func end(icons: Bool) -> some View {
        Button {
            ends += 1
            withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.85)) {
                store.endCardio()
            }
        } label: {
            // PROPOSAL: name what ends — this activity, not the workout ("End Indoor Run").
            // PROPOSAL: just "End" (the activity is named on the panel above).
            label("End", symbol: "stop.fill", icons: icons)
        }
        .buttonStyle(CardioTrayButtonStyle(prominent: false))
    }

    @ViewBuilder
    private func label(_ title: String, symbol: String, icons: Bool) -> some View {
        if icons {
            Label(title, systemImage: symbol)
                .contentTransition(.symbolEffect(.replace))
                .fixedSize()
        } else {
            Text(title).fixedSize()
        }
    }
}

// MARK: - PROPOSAL: finish from the cardio panel

/// After "End <activity>", the tray's slot becomes Finish Workout (the lifting screen's bar).
private struct ProposedCardioFinish: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router

    var body: some View {
        ProposedFinishBar {
            _ = store.finish()
            router.finishWorkout()
        }
    }
}
