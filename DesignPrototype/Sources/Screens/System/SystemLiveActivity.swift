import SwiftUI

// PROTOTYPE — Z01: the lock-screen Live Activity and the Dynamic Island, in each look.
//
// Idea: the Live Activity is the live workout's two kept skeletons lifted onto the Lock Screen —
// the header line (what you are on · clock · N/M sets) and the rest bar (draining ring with its
// hourglass, "Rest" over the time, +15s, Skip). Each look dresses it in its own instrument:
// A a night panel with Ultra "now", B graphite Liquid Glass with pearl, C a paper (or carbon)
// ticket holding the ink slab.
//
// Three states: resting (the rest bar), ready (rest is over: the next set to load, with last
// time's value beside it) and cardio (target ring · time · Pause).
//
// Platform honesty: a real Live Activity cannot run free animations. The countdown and the
// draining ring are system timers (`Text(timerInterval:)`, `ProgressView(timerInterval:)`), so
// they are drawn; the beating heart and the final-10-s beat are not. +15s / Skip / Pause are
// App Intent buttons (PROPOSED). Tapping anywhere else opens the app. The expanded island keeps
// its content clear of the camera, as the system's leading / trailing / bottom regions do.

/// Everything the Live Activity and the island draw.
struct SystemActivityModel {
    var snapshot: LiveActivitySnapshot
    /// "Next · Set 3 · 110 lb × 8" (lifting while resting).
    var nextLine: String?
    /// The next set (ready state: rest is over).
    var nextMarker: SystemNextMarker?
    var nextValue: SetValue?
    var nextLoadType: LoadType = .weighted
    /// Last time's value for that set ("105 lb × 8"), shown beside it when ready.
    var nextPrevious: String?
    /// The next set belongs to another exercise: once rest is over, the activity moves on to it.
    var nextExerciseName: String?
    /// "A" / "B" when the next set is in a superset.
    var nextSupersetLetter: String?
    /// The running rest follows a set that was a new best.
    var restFollowsNewBest = false
    /// The instant that set beat the best (4 s): the footer shows it and by how much.
    var bestMoment: SystemBestMoment?
    /// Z03: how the last rest ended, drawn in the footer.
    var restResult: SystemRestResult?
    var cardioTarget: SystemCardioTarget?

    var isCardio: Bool { snapshot.isCardio }
    var isResting: Bool { !snapshot.isCardio && snapshot.restRemaining != nil && (snapshot.restTotal ?? 0) > 0 }
    var restRemaining: Int { snapshot.restRemaining ?? 0 }
    var restProgress: Double {
        guard let total = snapshot.restTotal, total > 0 else { return 0 }
        return Double(restRemaining) / Double(total)
    }
    /// The header's name. Lifting: the exercise you are on (once rest is over, the one you move
    /// to). Cardio: the workout, whose clock sits beside it.
    var headerTitle: String {
        if snapshot.isCardio { return snapshot.title }
        if !isResting, let next = nextExerciseName { return next }
        return snapshot.exerciseName ?? snapshot.title
    }
    /// The instrument's name: the cardio activity, or the exercise.
    var title: String {
        if snapshot.isCardio { return snapshot.activity?.name ?? snapshot.title }
        return headerTitle
    }
    /// Z03 Recovered: the next set's marker lights in the look's "now" colour.
    var markerLit: Bool {
        if case .recovered = restResult { return true }
        return false
    }
    /// The state key the card animates between.
    var phase: Int { isCardio ? 2 : (isResting ? 1 : 0) }
}

struct SystemActivityActions {
    var add15: () -> Void = {}
    var skip: () -> Void = {}
    var pauseResume: () -> Void = {}
    var open: () -> Void = {}
}

// MARK: - Shared readouts

/// Colours for text inside the instrument: C's ink slab uses its slab colours.
struct SystemInk {
    var primary: Color
    var secondary: Color

    static func instrument(_ look: Look) -> SystemInk {
        look.id.isPaperClub ? SystemInk(primary: look.onSlab, secondary: look.onSlabSecondary)
            : SystemInk(primary: look.textPrimary, secondary: look.textSecondary)
    }
    static func card(_ look: Look) -> SystemInk { SystemInk(primary: look.textPrimary, secondary: look.textSecondary) }
    /// The island is black in every look: C reads it as its ink slab.
    static func island(_ look: Look) -> SystemInk { instrument(look) }
}

/// "♥ 128 bpm" with the zone meter. Omitted entirely when there is no reading.
private struct SystemHeartReadout: View {
    var bpm: Int?
    var zone: HeartRateZone?
    var ink: SystemInk
    var showsUnit = true
    var showsZone = true
    @Environment(\.look) private var look

    var body: some View {
        if let bpm {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.system(.caption, weight: .bold))
                    .foregroundStyle(look.heartRate)
                Text("\(bpm)")
                    .font(look.systemNumberFont(.subheadline))
                    .foregroundStyle(ink.primary)
                    .contentTransition(.numericText())
                if showsUnit {
                    Text("bpm").font(.system(.caption, weight: .semibold)).foregroundStyle(ink.secondary)
                }
                if showsZone, let zone, zone != .warm {
                    ZoneMeter(zone: zone).alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
                }
            }
            .lineLimit(1)
            .fixedSize()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(bpm) beats per minute" + (zone.map { ", \($0.label)" } ?? ""))
        }
    }
}

/// The sets ring with "7/18".
private struct SystemSetsReadout: View {
    var done: Int
    var total: Int
    var ink: SystemInk
    var ringSize: CGFloat = 18
    var showsWord = false
    @Environment(\.look) private var look

    var body: some View {
        HStack(spacing: 5) {
            SystemSetsRing(done: done, total: total, size: ringSize)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(done)/\(total)")
                    .font(look.systemNumberFont(.footnote))
                    .foregroundStyle(ink.primary)
                    .contentTransition(.numericText())
                if showsWord {
                    Text("sets").font(.system(.caption, weight: .semibold)).foregroundStyle(ink.secondary)
                }
            }
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(done) of \(total) sets")
    }
}

/// A target ring with the activity glyph (cardio), styled like the rest ring.
struct SystemTargetRing: View {
    var progress: Double?
    var symbol: String
    var size: CGFloat
    /// The planned target is done: the ring closes and the glyph becomes a check.
    var reached = false
    @Environment(\.look) private var look
    @Environment(\.lookOnSlab) private var onSlab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let width = size * (look.id.isPaperClub ? 0.103 : 0.09)
        let track: Color = look.id.isPaperClub
            ? (onSlab ? look.onSlab.opacity(0.16) : look.ringTrack)
            : Color.white.opacity(0.12)
        let glyph: Color = switch look.id {
        case .floodlight: look.live
        case .anatomy: look.textPrimary
        case .paper, .carbon: onSlab ? look.onSlab : look.textPrimary
        }
        ZStack {
            Circle().stroke(track, lineWidth: width)
            if let progress {
                RingArc(start: 0, end: max(0.001, min(1, progress)))
                    .stroke(look.live, style: StrokeStyle(lineWidth: width, lineCap: .round))
                    .animation(reduceMotion ? nil : .linear(duration: 1), value: progress)
            }
            Image(systemName: reached ? "checkmark" : symbol)
                .font(.system(size: size * 0.36, weight: reached ? .heavy : .semibold))
                .foregroundStyle(reached ? look.live : glyph)
                .contentTransition(.symbolEffect(.replace))
        }
        .padding(width / 2)
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// The sets ring. Inside the island and C's ink slab, C draws it in the slab's ink (bone / paper
/// white) so it reads on black; everywhere else it is the look's own `SetsRing`.
struct SystemSetsRing: View {
    var done: Int
    var total: Int
    var size: CGFloat
    @Environment(\.look) private var look
    @Environment(\.lookOnSlab) private var onSlab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if look.id == .floodlight && size < 28 {
            // A's segmented ring turns to dust below 28 pt: one lit arc reads at a glance.
            let width = size * 0.16
            let fraction = total > 0 ? min(1, Double(done) / Double(total)) : 0
            ZStack {
                Circle().stroke(Color.white.opacity(0.16), lineWidth: width)
                RingArc(start: 0, end: fraction)
                    .stroke(look.done, style: StrokeStyle(lineWidth: width, lineCap: .butt))
                    .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.85), value: fraction)
            }
            .padding(width / 2)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
        } else if look.id.isPaperClub && onSlab {
            let width = size * 0.17
            let fraction = total > 0 ? min(1, Double(done) / Double(total)) : 0
            ZStack {
                Circle().stroke(look.onSlab.opacity(0.2), lineWidth: width)
                RingArc(start: 0, end: fraction)
                    .stroke(look.onSlab, style: StrokeStyle(lineWidth: width, lineCap: .butt))
                    .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.85), value: fraction)
            }
            .padding(width / 2)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
        } else {
            SetsRing(done: done, total: total, size: size)
        }
    }
}

/// The next set's marker. A: Ultra passes from the rest ring to the next set once rest is over.
/// Lit (Z03 Recovered): filled in the look's "now" colour — you are ready.
private struct SystemReadyMarker: View {
    var marker: SystemNextMarker
    var side: CGFloat
    var lit = false
    @Environment(\.look) private var look

    var body: some View {
        Group {
            if lit {
                let label = marker.kind.marker ?? "\(marker.number)"
                Text(label)
                    .font(look.id == .anatomy ? .system(.headline, design: .rounded, weight: .heavy)
                          : Font.system(.subheadline, weight: .heavy).width(.expanded))
                    .foregroundStyle(look.onAction)
                    .frame(width: side, height: side)
                    .background {
                        if look.id == .floodlight {
                            RoundedRectangle(cornerRadius: look.radius.marker, style: .continuous).fill(look.live)
                        } else {
                            Circle().fill(look.live)
                        }
                    }
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            } else {
                SetMarker(kind: marker.kind, number: marker.number, done: false, isNextUp: true, side: side)
                    .overlay {
                        if look.id == .floodlight {
                            RoundedRectangle(cornerRadius: look.radius.marker, style: .continuous)
                                .strokeBorder(look.live, lineWidth: 2)
                        }
                    }
            }
        }
        .accessibilityHidden(true)
    }
}

/// The superset letter beside the next set's marker (the live card's chip, in the look).
private struct SystemSupersetChip: View {
    var letter: String
    @Environment(\.look) private var look
    @Environment(\.lookOnSlab) private var onSlab

    var body: some View {
        let ink = onSlab ? look.onSlab : look.textPrimary
        let text = Text(letter)
            .font(.system(.footnote, design: look.id == .anatomy ? .rounded : .default, weight: .heavy))
            .foregroundStyle(ink)
            .frame(width: 24, height: 24)
        Group {
            switch look.id {
            case .floodlight:
                text.overlay { RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(ink, lineWidth: 1.5) }
            case .anatomy:
                text.background(look.positive.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            case .paper, .carbon:
                text.overlay { Circle().strokeBorder(ink, lineWidth: 1.5) }
            }
        }
        .accessibilityLabel("Superset \(letter)")
    }
}

/// The marker with its superset letter, when there is one.
private struct SystemNextMarkerGroup: View {
    var model: SystemActivityModel
    var side: CGFloat

    var body: some View {
        if let marker = model.nextMarker {
            HStack(spacing: 6) {
                SystemReadyMarker(marker: marker, side: side, lit: model.markerLit)
                if let letter = model.nextSupersetLetter {
                    SystemSupersetChip(letter: letter)
                }
            }
        }
    }
}

/// C: the ink slab around the live instrument (rest / cardio / ready). A and B draw nothing extra.
private struct SystemInstrumentPlate: ViewModifier {
    @Environment(\.look) private var look

    func body(content: Content) -> some View {
        if look.id.isPaperClub {
            let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
            content
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(look.slab, in: shape)
                .overlay { shape.strokeBorder(look.slabEdge, lineWidth: 1.5) }
                .environment(\.lookOnSlab, true)
        } else {
            content
        }
    }
}

/// "110 lb × 8": big numbers, small unit and ×.
struct SystemSetValueText: View {
    var value: SetValue
    var loadType: LoadType
    var ink: SystemInk
    var numberStyle: Font.TextStyle = .title
    @Environment(\.look) private var look

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            if let weight = value.weight, loadType.takesWeight {
                Text(Format.weight(weight)).font(look.systemNumberFont(numberStyle)).foregroundStyle(ink.primary)
                Text(value.unit.label).font(.system(.footnote, weight: .semibold)).foregroundStyle(ink.secondary)
                Text("×").font(.system(.title3, weight: .semibold)).foregroundStyle(ink.secondary)
            }
            Text("\(value.reps)").font(look.systemNumberFont(numberStyle)).foregroundStyle(ink.primary)
            if !(value.weight != nil && loadType.takesWeight) {
                Text("reps").font(.system(.footnote, weight: .semibold)).foregroundStyle(ink.secondary)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Format.set(value, loadType: loadType))
    }
}

/// "Rest" over "1:24" (or "Time" over "12:48"): a small label over the big figure.
private struct SystemFigureStack: View {
    var label: String
    var value: String
    var ink: SystemInk
    var dimmed = false
    var countsDown = false
    var alignment: HorizontalAlignment = .leading
    var numberFont: Font? = nil
    /// The rest follows a new best: the look's mark rides on the label line.
    var newBest = false
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: alignment, spacing: -2) {
            HStack(spacing: 6) {
                Text(label).font(look.systemLabelFont).foregroundStyle(ink.secondary)
                if newBest {
                    NewBestBadge(kind: .newBest)
                        .scaleEffect(0.9, anchor: .leading)
                        .transition(reduceMotion ? .opacity : .scale(scale: 1.5).combined(with: .opacity))
                }
            }
            Text(value)
                .font(numberFont ?? look.font.heroNumber)
                .foregroundStyle(dimmed ? ink.secondary : ink.primary)
                .contentTransition(.numericText(countsDown: countsDown))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .fixedSize()
    }
}

/// "PREVIOUS" over "105 × 8": last time's value for the next set (the live row's column).
private struct SystemPreviousStack: View {
    var text: String
    var ink: SystemInk
    var alignment: HorizontalAlignment = .trailing
    @Environment(\.look) private var look

    var body: some View {
        VStack(alignment: alignment, spacing: 3) {
            Text("PREVIOUS")
                .font(look.font.columnHeader)
                .tracking(look.columnTracking)
                .foregroundStyle(ink.secondary)
            Text(text)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(ink.secondary)
        }
        .lineLimit(1)
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Last time \(text)")
    }
}

// MARK: - Lock Screen Live Activity

struct SystemLiveActivityCard: View {
    var model: SystemActivityModel
    var actions: SystemActivityActions
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let radius: CGFloat = 26

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Group {
                if model.isCardio {
                    cardioInstrument
                } else if model.isResting {
                    restInstrument
                } else {
                    readyInstrument
                }
            }
            .modifier(SystemInstrumentPlate())
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
            footer
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 13)
        .background { background }
        .contentShape(RoundedRectangle(cornerRadius: Self.radius, style: .continuous))
        .onTapGesture(perform: actions.open)
        .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.86), value: model.phase)
        .systemActivityTypeCap()
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Open Workout", actions.open)
    }

    // MARK: Header: icon · what you are on · workout clock

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            SystemAppIcon(lookID: look.id, size: 20)
            Text(model.headerTitle)
                .font(look.systemNameFont(.subheadline))
                .foregroundStyle(look.textPrimary)
                .lineLimit(typeSize > .xLarge ? 2 : 1)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Text(Format.elapsed(model.snapshot.elapsedSeconds))
                .font(look.systemNumberFont(.subheadline))
                .foregroundStyle(look.textSecondary)
                .contentTransition(.numericText())
                .accessibilityLabel("Workout time " + Format.spokenElapsed(model.snapshot.elapsedSeconds))
        }
    }

    // MARK: Rest: ring · Rest over the time · +15s · Skip (the rest bar)

    private var restInstrument: some View {
        let ink = SystemInk.instrument(look)
        let ring = RestRing(progress: model.restProgress, isFinal: false, size: look.id.isPaperClub ? 50 : 52)
        let time = SystemFigureStack(label: "Rest", value: Format.duration(model.restRemaining), ink: ink, countsDown: true,
                                     newBest: model.restFollowsNewBest)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel((model.restFollowsNewBest ? "New best. " : "") + "Rest, \(Format.duration(model.restRemaining)) left")
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                ring
                time.layoutPriority(1)
                Spacer(minLength: 4)
                restPills
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) { ring; time; Spacer(minLength: 0) }
                restPills
            }
        }
    }

    private var restPills: some View {
        HStack(spacing: 8) {
            Button("+15s", action: actions.add15).buttonStyle(PillButtonStyle())
                .accessibilityLabel("Add 15 seconds")
            Button("Skip", action: actions.skip).buttonStyle(PillButtonStyle(prominent: true))
                .accessibilityLabel("Skip rest")
        }
        .sensoryFeedback(.impact(weight: .light), trigger: model.snapshot.restTotal)
    }

    // MARK: Ready (rest is over): the next set to load, last time beside it

    private var readyInstrument: some View {
        let ink = SystemInk.instrument(look)
        let value = VStack(alignment: .leading, spacing: 0) {
            Text("Next").font(look.systemLabelFont).foregroundStyle(ink.secondary)
            if let next = model.nextValue {
                SystemSetValueText(value: next, loadType: model.nextLoadType, ink: ink)
            } else {
                Text(model.title).font(look.systemNameFont(.headline)).foregroundStyle(ink.primary)
            }
        }
        .accessibilityElement(children: .combine)
        return HStack(spacing: 12) {
            SystemNextMarkerGroup(model: model, side: 44)
            value.layoutPriority(1)
            Spacer(minLength: 6)
            if let previous = model.nextPrevious {
                SystemPreviousStack(text: previous, ink: ink)
            }
        }
        .frame(minHeight: 52)
    }

    // MARK: Cardio: target ring · Time over the clock · Pause/Resume

    private var cardioInstrument: some View {
        let ink = SystemInk.instrument(look)
        let paused = model.snapshot.isCardioPaused
        let seconds = model.snapshot.cardioSeconds ?? 0
        return HStack(spacing: 12) {
            SystemTargetRing(progress: model.cardioTarget?.progress,
                             symbol: model.snapshot.activity?.symbol ?? "figure.run",
                             size: look.id.isPaperClub ? 50 : 52,
                             reached: model.cardioTarget?.isReached == true)
            // The segment's own clock, named by its activity; the header carries the workout's.
            SystemFigureStack(label: paused ? "Paused" : model.title, value: Format.elapsed(seconds), ink: ink, dimmed: paused)
                .layoutPriority(1)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel((paused ? "Paused, " : "\(model.title), ") + Format.spokenElapsed(seconds))
            Spacer(minLength: 4)
            SystemPauseButton(paused: paused, action: actions.pauseResume)
        }
    }

    // MARK: Footer

    @ViewBuilder private var footer: some View {
        if model.isCardio {
            cardioFooter
        } else {
            liftingFooter
        }
    }

    @ViewBuilder private var liftingFooter: some View {
        if let result = model.restResult {
            resultFooter(result)
        } else {
            plainLiftingFooter
        }
    }

    /// Z03: how the rest ended (drawn, not written) · the sets ring.
    private func resultFooter(_ result: SystemRestResult) -> some View {
        let ink = SystemInk.card(look)
        let sets = SystemSetsReadout(done: model.snapshot.completedSets, total: model.snapshot.totalSets, ink: ink)
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                SystemRestResultRow(result: result, ink: ink)
                Spacer(minLength: 6)
                sets
            }
            VStack(alignment: .leading, spacing: 6) {
                SystemRestResultRow(result: result, ink: ink)
                sets
            }
        }
    }

    private var plainLiftingFooter: some View {
        let ink = SystemInk.card(look)
        let trailing = HStack(spacing: 12) {
            SystemHeartReadout(bpm: model.snapshot.bpm, zone: model.snapshot.zone, ink: ink, showsUnit: false)
            SystemSetsReadout(done: model.snapshot.completedSets, total: model.snapshot.totalSets, ink: ink)
        }
        .fixedSize()
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                footerLeading(ink)
                Spacer(minLength: 6)
                trailing
            }
            VStack(alignment: .leading, spacing: 6) {
                footerLeading(ink)
                trailing
            }
        }
    }

    /// Resting: the next set. Ready: the gym (the next set is already in the instrument).
    @ViewBuilder private func footerLeading(_ ink: SystemInk) -> some View {
        if model.isResting, let moment = model.bestMoment {
            SystemBestLine(moment: moment, ink: ink)
        } else if model.isResting, let line = model.nextLine {
            Text(line)
                .font(look.id.isPaperClub ? .system(.footnote, weight: .semibold) : look.font.footnote)
                .foregroundStyle(ink.secondary)
                .lineLimit(1)
                .fixedSize()
        } else if let gym = model.snapshot.gymName {
            Label(gym, systemImage: look.gymSymbol)
                .labelStyle(SystemTightLabelStyle())
                .font(look.id.isPaperClub ? .system(.footnote, weight: .semibold) : look.font.footnote)
                .foregroundStyle(ink.secondary)
                .lineLimit(1)
                .fixedSize()
        }
    }

    private var cardioFooter: some View {
        let ink = SystemInk.card(look)
        let s = model.snapshot
        let figures = HStack(spacing: 14) {
            if let meters = s.distanceMeters, meters > 0 {
                figure(Format.distance(meters: meters, s.distanceUnit), unit: s.distanceUnit.label, ink: ink)
            }
            if let activity = s.activity, activity.usesSpeed, let meters = s.distanceMeters, let seconds = s.cardioSeconds, seconds > 0 {
                figure(Format.speed(metersPerSecond: meters / Double(seconds), s.distanceUnit), unit: "\(s.distanceUnit.label)/h", ink: ink)
            } else if let pace = s.paceSecondsPerUnit {
                figure(Format.pace(pace), unit: "/\(s.distanceUnit.label)", ink: ink)
            }
            if let target = model.cardioTarget {
                figure("\(target.minutes)", unit: "min", ink: ink, symbol: "target")
                    .accessibilityLabel("Target \(target.minutes) minutes")
            }
        }
        let heart = SystemHeartReadout(bpm: s.bpm, zone: s.zone, ink: ink, showsUnit: false)
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) { figures; Spacer(minLength: 4); heart }
            VStack(alignment: .leading, spacing: 6) { figures; heart }
        }
    }

    private func figure(_ value: String, unit: String, ink: SystemInk, symbol: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            if let symbol {
                Image(systemName: symbol).font(.system(.caption, weight: .bold)).foregroundStyle(ink.secondary)
            }
            Text(value).font(look.systemNumberFont(.subheadline)).foregroundStyle(ink.primary)
                .contentTransition(.numericText())
            Text(unit).font(.system(.caption, weight: .semibold)).foregroundStyle(ink.secondary)
        }
        .lineLimit(1)
        .fixedSize()
    }

    // MARK: Background, per look

    @ViewBuilder private var background: some View {
        let shape = RoundedRectangle(cornerRadius: Self.radius, style: .continuous)
        switch look.id {
        case .floodlight:
            shape.fill(look.ground).overlay { shape.strokeBorder(look.glassEdge, lineWidth: 1) }
        case .anatomy:
            Color.clear
                .glassEffect(.regular.tint(look.slab), in: shape)
                .overlay { shape.strokeBorder(look.slabEdge, lineWidth: 1) }
        case .paper, .carbon:
            shape.fill(look.surface).overlay { shape.strokeBorder(look.hairline, lineWidth: look.stroke.hairline) }
        }
    }
}

/// The set that just beat the best, in the look's new-best language, and by how much:
/// A and B light it in the new-best colour; C lays the yellow highlighter under it.
private struct SystemBestLine: View {
    var moment: SystemBestMoment
    var ink: SystemInk
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        let text = Format.set(moment.value, loadType: moment.loadType)
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if look.id.isPaperClub {
                Text(text)
                    .font(.system(.footnote, weight: .bold))
                    .foregroundStyle(look.onPositive)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(alignment: .leading) {
                        // The highlighter swipe draws on from the left.
                        RoundedRectangle(cornerRadius: 3, style: .continuous).fill(look.positive)
                            .scaleEffect(x: shown ? 1 : 0.02, y: 1, anchor: .leading)
                    }
            } else {
                Text(text)
                    .font(look.systemNumberFont(.footnote))
                    .foregroundStyle(look.positive)
            }
            if let delta = moment.delta {
                Text(delta)
                    .font(.system(.footnote, weight: .bold))
                    .foregroundStyle(look.id.isPaperClub ? ink.primary : look.positive)
            }
        }
        .lineLimit(1)
        .fixedSize()
        .onAppear {
            if reduceMotion { shown = true } else { withAnimation(.easeOut(duration: 0.35).delay(0.1)) { shown = true } }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("New best, \(text)" + (moment.delta.map { ", \($0)" } ?? ""))
    }
}

/// Pause / Resume, the cardio instrument's one command.
private struct SystemPauseButton: View {
    var paused: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(paused ? "Resume" : "Pause", systemImage: paused ? "play.fill" : "pause.fill")
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(PillButtonStyle(prominent: true))
        .sensoryFeedback(.impact(weight: .medium), trigger: paused)
    }
}

/// A label with a tight glyph gap (the footer's gym line).
private struct SystemTightLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon.imageScale(.small)
            configuration.title
        }
    }
}

// MARK: - Rest result (Z03): how the rest ended, drawn

/// Timer: the drained rest ring and its length. Recovered: the reading under the target mark, in
/// the "now" colour. Cap: the capped clock, and the reading still over the mark in heart red.
/// No reading: the struck-out heart beside the timer that took over.
struct SystemRestResultRow: View {
    var result: SystemRestResult
    var ink: SystemInk
    @Environment(\.look) private var look

    var body: some View {
        HStack(alignment: .center, spacing: 7) {
            switch result {
            case .timer(let seconds):
                RestRing(progress: 0, isFinal: false, size: 22)
                number(Format.duration(seconds), color: ink.primary)
            case .noReading(let seconds):
                Image(systemName: "heart.slash.fill")
                    .font(.system(.footnote, weight: .bold))
                    .foregroundStyle(ink.secondary)
                RestRing(progress: 0, isFinal: false, size: 22)
                number(Format.duration(seconds), color: ink.primary)
            case .recovered(let bpm, let target):
                Image(systemName: "heart.fill").font(.system(.caption, weight: .bold)).foregroundStyle(look.heartRate)
                number("\(bpm)", color: ink.primary)
                SystemTargetGauge(bpm: bpm, target: target, tint: look.live, ink: ink)
            case .cap(let bpm, let target, let cap):
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.system(.footnote, weight: .bold))
                    .foregroundStyle(ink.secondary)
                number(Format.duration(cap), color: ink.secondary)
                Image(systemName: "heart.fill").font(.system(.caption, weight: .bold)).foregroundStyle(look.heartRate)
                    .padding(.leading, 4)
                number("\(bpm)", color: look.heartRate)
                SystemTargetGauge(bpm: bpm, target: target, tint: look.heartRate, ink: ink)
            }
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    private func number(_ text: String, color: Color) -> some View {
        Text(text)
            .font(look.systemNumberFont(.subheadline))
            .foregroundStyle(color)
            .contentTransition(.numericText())
    }

    private var spoken: String {
        switch result {
        case .timer(let s): "Rested \(Format.duration(s))"
        case .noReading(let s): "No heart rate reading, rested \(Format.duration(s))"
        case .recovered(let bpm, let target): "\(bpm) beats per minute, under \(target)"
        case .cap(let bpm, let target, let cap): "\(Format.duration(cap)) cap reached, \(bpm) beats per minute, over \(target)"
        }
    }
}

/// A short bpm track with the target as a tick and its number: the fill stops short of the tick
/// (recovered) or runs past it (cap).
private struct SystemTargetGauge: View {
    var bpm: Int
    var target: Int
    var tint: Color
    var ink: SystemInk
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    private let width: CGFloat = 64
    private let span = 30.0

    var body: some View {
        let low = Double(target) - span, high = Double(target) + span
        let fraction = min(1, max(0.04, (Double(bpm) - low) / (high - low)))
        HStack(spacing: 5) {
            ZStack(alignment: .leading) {
                Capsule().fill(ink.secondary.opacity(0.25)).frame(width: width, height: 6)
                Capsule().fill(tint).frame(width: width * (shown ? fraction : 0.04), height: 6)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.4), value: fraction)
                RoundedRectangle(cornerRadius: 1).fill(ink.primary)
                    .frame(width: 2.5, height: 14)
                    .offset(x: width / 2 - 1.25)
            }
            .frame(width: width, height: 14)
            Text("\(target)")
                .font(.system(.caption, weight: .bold).monospacedDigit())
                .foregroundStyle(ink.secondary)
        }
        .onAppear {
            if reduceMotion { shown = true } else { withAnimation(.easeOut(duration: 0.6).delay(0.15)) { shown = true } }
        }
    }
}

// MARK: - Dynamic Island

/// The island's small live glyph: the rest ring, the cardio ring, or the sets ring.
private struct SystemIslandGlyph: View {
    var model: SystemActivityModel
    var size: CGFloat

    var body: some View {
        if model.isCardio {
            SystemTargetRing(progress: model.cardioTarget?.progress,
                             symbol: model.snapshot.isCardioPaused ? "pause.fill" : (model.snapshot.activity?.symbol ?? "figure.run"),
                             size: size, reached: model.cardioTarget?.isReached == true)
        } else if model.isResting {
            RestRing(progress: model.restProgress, isFinal: false, size: size)
        } else {
            SystemSetsRing(done: model.snapshot.completedSets, total: model.snapshot.totalSets, size: size * 0.86)
                .frame(width: size, height: size)
        }
    }
}

/// The TrueDepth camera inside the island (black on black on a device; the mock keeps its room).
enum SystemIslandMetrics {
    static let cameraWidth: CGFloat = 126
    static let cameraHeight: CGFloat = 37
}

struct SystemIslandCompact: View {
    var model: SystemActivityModel
    @Environment(\.look) private var look

    var body: some View {
        HStack(spacing: 0) {
            SystemIslandGlyph(model: model, size: 25)
            Spacer(minLength: SystemIslandMetrics.cameraWidth - 4)
            Text(trailing)
                .font(look.systemNumberFont(.subheadline))
                .foregroundStyle(trailingColor)
                .contentTransition(.numericText(countsDown: model.isResting))
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.leading, 7)
        .padding(.trailing, 13)
        .frame(height: SystemIslandMetrics.cameraHeight)
        .background(Capsule().fill(Color.black))
        .fixedSize()
        .environment(\.lookOnSlab, look.id.isPaperClub)
        .systemActivityTypeCap()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.isResting ? "Rest, \(trailing) left" : (model.isCardio ? "Time \(trailing)" : "\(trailing) sets"))
    }

    private var trailing: String {
        if model.isCardio { return Format.elapsed(model.snapshot.cardioSeconds ?? 0) }
        if model.isResting { return Format.duration(model.restRemaining) }
        return "\(model.snapshot.completedSets)/\(model.snapshot.totalSets)"
    }

    /// A's compact figure is Ultra ("now"); B pearl; C the light cobalt it uses on the slab.
    private var trailingColor: Color {
        if model.isCardio && model.snapshot.isCardioPaused { return SystemInk.island(look).secondary }
        if model.isResting || model.isCardio { return look.live }
        return SystemInk.island(look).primary
    }
}

/// Two activities at once: ours shrinks to a detached circle beside the other one's pill.
struct SystemIslandMinimal: View {
    var model: SystemActivityModel
    @Environment(\.look) private var look

    var body: some View {
        HStack(spacing: 7) {
            Capsule().fill(Color.black).frame(width: SystemIslandMetrics.cameraWidth, height: SystemIslandMetrics.cameraHeight)
            SystemIslandGlyph(model: model, size: 25)
                .frame(width: SystemIslandMetrics.cameraHeight, height: SystemIslandMetrics.cameraHeight)
                .background(Circle().fill(Color.black))
        }
        .environment(\.lookOnSlab, look.id.isPaperClub)
        .accessibilityHidden(true)
    }
}

/// Long-press: the leading and trailing regions flank the camera; the bottom region carries the
/// line under the time and the commands.
struct SystemIslandExpanded: View {
    var model: SystemActivityModel
    var actions: SystemActivityActions
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let ink = SystemInk.island(look)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 0) {
                leadingRegion
                Spacer(minLength: SystemIslandMetrics.cameraWidth + 8)
                trailingRegion(ink)
            }
            .frame(minHeight: 50)
            bottomRegion(ink)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 46, style: .continuous).fill(Color.black)
                .overlay {
                    // The keyline tint: the look's live colour, faint.
                    RoundedRectangle(cornerRadius: 46, style: .continuous)
                        .strokeBorder(look.live.opacity(0.28), lineWidth: 1)
                }
        }
        .contentShape(RoundedRectangle(cornerRadius: 46, style: .continuous))
        .onTapGesture(perform: actions.open)
        .environment(\.lookOnSlab, look.id.isPaperClub)
        .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.86), value: model.phase)
        .systemActivityTypeCap()
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Open Workout", actions.open)
    }

    // MARK: Leading: the live glyph (or the next set's marker)

    @ViewBuilder private var leadingRegion: some View {
        if !model.isCardio && !model.isResting, model.nextMarker != nil {
            SystemNextMarkerGroup(model: model, side: 44)
        } else {
            SystemIslandGlyph(model: model, size: 50)
        }
    }

    // MARK: Trailing: the one big figure

    @ViewBuilder private func trailingRegion(_ ink: SystemInk) -> some View {
        if model.isCardio {
            let paused = model.snapshot.isCardioPaused
            SystemFigureStack(label: paused ? "Paused" : "Time", value: Format.elapsed(model.snapshot.cardioSeconds ?? 0),
                              ink: ink, dimmed: paused, alignment: .trailing)
        } else if model.isResting {
            SystemFigureStack(label: "Rest", value: Format.duration(model.restRemaining), ink: ink, countsDown: true,
                              alignment: .trailing)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Rest, \(Format.duration(model.restRemaining)) left")
        } else if let value = model.nextValue {
            VStack(alignment: .trailing, spacing: 0) {
                Text("Next").font(look.systemLabelFont).foregroundStyle(ink.secondary)
                SystemSetValueText(value: value, loadType: model.nextLoadType, ink: ink, numberStyle: .title2)
            }
            .fixedSize()
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: Bottom: what it's about · the commands

    @ViewBuilder private func bottomRegion(_ ink: SystemInk) -> some View {
        let info = VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text(model.title)
                    .font(look.systemNameFont(.subheadline))
                    .foregroundStyle(ink.primary)
                    .lineLimit(1)
                if model.isResting && model.restFollowsNewBest {
                    NewBestBadge(kind: .newBest)
                        .transition(reduceMotion ? .opacity : .scale(scale: 1.5).combined(with: .opacity))
                }
            }
            if model.isResting, let moment = model.bestMoment {
                SystemBestLine(moment: moment, ink: ink)
            } else if let line = supportLine {
                Text(line)
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(ink.secondary)
                    .lineLimit(1)
                    .fixedSize()
            } else if !model.isCardio && !model.isResting, let previous = model.nextPrevious {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("PREVIOUS").font(look.font.columnHeader).tracking(look.columnTracking)
                    Text(previous).font(.system(.footnote, weight: .semibold))
                }
                .foregroundStyle(ink.secondary)
                .lineLimit(1)
                .fixedSize()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Last time \(previous)")
            }
            SystemHeartReadout(bpm: model.snapshot.bpm, zone: model.snapshot.zone, ink: ink, showsUnit: true, showsZone: false)
        }
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .bottom, spacing: 10) {
                info.layoutPriority(1)
                Spacer(minLength: 0)
                commands
            }
            VStack(alignment: .leading, spacing: 12) {
                info
                commands
            }
        }
    }

    private var supportLine: String? {
        if model.isCardio {
            let s = model.snapshot
            var parts: [String] = []
            if let meters = s.distanceMeters, meters > 0 { parts.append(Format.distanceLabel(meters: meters, s.distanceUnit)) }
            if let pace = s.paceSecondsPerUnit, s.activity?.usesSpeed != true { parts.append(Format.paceLabel(pace, s.distanceUnit)) }
            return parts.isEmpty ? nil : parts.joined(separator: " · ")
        }
        return model.isResting ? model.nextLine : nil
    }

    @ViewBuilder private var commands: some View {
        if model.isCardio {
            SystemPauseButton(paused: model.snapshot.isCardioPaused, action: actions.pauseResume)
        } else if model.isResting {
            HStack(spacing: 8) {
                Button("+15s", action: actions.add15).buttonStyle(PillButtonStyle())
                    .accessibilityLabel("Add 15 seconds")
                Button("Skip", action: actions.skip).buttonStyle(PillButtonStyle(prominent: true))
                    .accessibilityLabel("Skip rest")
            }
        } else {
            SystemSetsReadout(done: model.snapshot.completedSets, total: model.snapshot.totalSets, ink: SystemInk.island(look),
                              ringSize: 22, showsWord: true)
        }
    }
}
