import SwiftUI

// PROTOTYPE — what floats at the thumb in the live workout: ONE slab that carries the rest (timer,
// heart-rate rest, or the degraded timer fallback), the NEW BEST band docked on top of it while a
// best is fresh, and a short "Rest complete" moment when a rest ends by itself; or the entry bar
// while a number is being typed. Everything here reads the ticking clock, so it is kept apart
// from the list (only this view re-renders every second).

struct LiveBottomDock: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(LiveScreenModel.self) private var model
    @Environment(\.look) private var look
    @Environment(\.liveReduceMotion) private var reduceMotion

    var body: some View {
        let editing = model.editing != nil
        // While the rename alert is up, nothing rides above its keyboard.
        let hidden = model.renaming
        let best = store.freshNewBest
        let end = model.restEnd.flatMap { store.now.timeIntervalSince($0.at) < LiveRestEnd.duration ? $0 : nil }
        VStack(spacing: 0) {
            if editing {
                LiveEntryBar()
                    .transition(.opacity)
            } else if !hidden {
                if store.rest != nil || best != nil {
                    LiveRestSlab(rest: store.rest, best: best)
                        .transition(RestBar.transition(reduceMotion: reduceMotion))
                } else if let end, end.outcome != .skipped {
                    LiveRestEndSlab(end: end)
                        .transition(RestBar.transition(reduceMotion: reduceMotion))
                } else if Proposal.shared.finishAtBottom && !model.reordering {
                    // PROPOSAL: Finish at the thumb, in the slot the rest slab uses.
                    ProposedFinishBar { model.finishTapped(store: store, router: router) }
                        .transition(.opacity)
                }
            }
        }
        .padding(.horizontal, look.space.margin)
        .padding(.bottom, 8)
        // The list aims rows above this edge (an empty dock reports the bottom of the screen).
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { model.dockTop = $0 - 8 }
        .animation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.86), value: store.rest?.setID)
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8), value: best?.id)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: editing)
        .animation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.86), value: end?.at)
        // Rest ran out / recovered / hit the cap (never a Skip): the existing success haptic.
        .sensoryFeedback(.success, trigger: store.restExpiryCount)
        // A new best just landed.
        .sensoryFeedback(trigger: best?.id) { _, new in new == nil ? nil : .success }
        .onChange(of: store.restExpiryCount) { _, _ in
            model.restEnd = LiveRestEnd(outcome: store.lastRestOutcome ?? .timerDone, at: store.now)
        }
    }
}

// MARK: - The rest slab

/// One floating instrument: [NEW BEST band] over [the rest row] (+ the degraded row). The band
/// shares the slab's material and edge, so the celebration and the rest read as one unit. At AX
/// sizes the band does not stack: for its few seconds it takes the place of the Rest/time text.
/// Capped at AX1 so it stays within about 22 % of the screen.
struct LiveRestSlab: View {
    var rest: RestState?
    var best: SetCompletion?
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let ax = typeSize.isAccessibilitySize
        VStack(spacing: 0) {
            if let best, !(ax && rest != nil) {
                LiveBestBand(completion: best)
                    .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
                if rest != nil { LookDivider().padding(.horizontal, 14) }
            }
            if let rest {
                LiveRestRow(rest: rest, axBest: ax ? best : nil)
                if rest.isDegraded {
                    LookDivider().padding(.horizontal, 14)
                    LiveDegradedRow()
                }
            }
        }
        .environment(\.lookOnSlab, look.id.isPaperClub)
        .clipShape(RoundedRectangle(cornerRadius: look.radius.bar, style: .continuous))
        .background { LiveSlabBackground() }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .accessibilityElement(children: .contain)
    }
}

/// The rest row. Timer: ring (hourglass) · "Rest" over the time · Next · +15s · Skip.
/// Heart rate (D43): the ring drains from the reading at rest start toward the target, the big
/// figure is the live bpm → the target, and the cap is a small line beside "Rest".
private struct LiveRestRow: View {
    var rest: RestState
    var axBest: SetCompletion?

    @Environment(Store.self) private var store
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.liveReduceMotion) private var reduceMotion

    private var isHeart: Bool { rest.mode == .heartRate && !rest.isDegraded }
    private var remaining: Int { rest.remaining(at: store.now) }
    private var bpm: Int? { store.currentBPM }
    private var threshold: Int { rest.thresholdBpm ?? 110 }
    private var onSlabText: Color { look.id.isPaperClub ? look.onSlab : look.textPrimary }
    private var onSlabSecondary: Color { look.id.isPaperClub ? look.onSlabSecondary : look.textSecondary }
    private var next: String? { store.liveNextLabel(look) }

    /// Timer: remaining ÷ total. Heart rate: how much of the way from the rest-start reading down
    /// to the target is still to go (full at the start, empty at the target).
    private var progress: Double {
        guard isHeart else { return rest.totalSeconds > 0 ? Double(remaining) / Double(rest.totalSeconds) : 0 }
        guard let bpm else { return 1 }
        let peak = Double(max(store.liveRestPeakBPM(rest) ?? bpm, bpm, threshold + 1))
        return min(1, max(0, (Double(bpm) - Double(threshold)) / (peak - Double(threshold))))
    }

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize { axLayout } else { defaultLayout }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: Layouts

    private var defaultLayout: some View {
        HStack(spacing: isHeart ? 8 : 10) {
            ring(size: look.id.isPaperClub ? (isHeart ? 54 : 58) : (isHeart ? 52 : 56))
            textBlock(showNext: true)
            Spacer(minLength: 0)
            add15(fill: false)
            skip(fill: false)
        }
        .padding(.leading, 12).padding(.trailing, look.id.isPaperClub ? 14 : 12)
        .frame(minHeight: look.id.isPaperClub ? 94 : 82)
    }

    /// AX: ring + figure on one row (heart rate: bpm, target and cap on that row too), then the
    /// equal +15s / Skip halves. The Next line stays only for B and C timer rests; otherwise it
    /// is spoken (A SPEC §9) so the slab keeps within about 22 % of the screen.
    /// PROPOSAL: at AX sizes the slab is one row — ring · time · +15s · Skip — so the sets above
    /// it stay in view (it was about a quarter of the screen). +15s drops to a second row only
    /// when the row cannot fit it.
    private var axLayout: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                ring(size: 40)
                axLead
                Spacer(minLength: 0)
                add15(fill: false)
                skip(fill: false)
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    ring(size: 40)
                    axLead
                    Spacer(minLength: 0)
                    skip(fill: false)
                }
                add15(fill: false)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
    }

    @ViewBuilder private var axLead: some View {
        if let axBest { LiveBestCompact(completion: axBest) } else { textBlock(showNext: false) }
    }

    private var axLayoutOld: some View {
        // The degraded line takes the Next line's place (it is spoken instead), keeping the budget.
        let showsNext = !isHeart && look.id != .floodlight && axBest == nil && !rest.isDegraded
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ring(size: 48)
                if let axBest { LiveBestCompact(completion: axBest) } else { textBlock(showNext: false) }
                Spacer(minLength: 0)
            }
            if showsNext, let next {
                Text(next)
                    .font(nextFont)
                    .foregroundStyle(onSlabSecondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 10) {
                add15(fill: true)
                skip(fill: true)
            }
        }
        .padding(14)
    }

    // MARK: Pieces

    private func ring(size: CGFloat) -> some View {
        LiveRestRing(progress: progress, isFinal: !isHeart && remaining <= 10 && remaining > 0, size: size,
                     glyph: isHeart ? .heart(bpm) : .hourglass)
    }

    private func textBlock(showNext: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if isHeart {
                HStack(spacing: 6) {
                    Text("Rest").font(labelFont).foregroundStyle(onSlabSecondary)
                    capLine
                }
                bpmFigure
            } else {
                Text("Rest").font(labelFont).foregroundStyle(onSlabSecondary)
                Text(Format.duration(remaining))
                    .font(look.font.bigNumber)
                    .foregroundStyle(onSlabText)
                    .contentTransition(.numericText(countsDown: true))
                    .lineLimit(1)
            }
            if showNext, let next {
                Text(next)
                    .font(nextFont)
                    .foregroundStyle(onSlabSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .layoutPriority(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    /// "124 → 110 bpm": the reading big (heart colour in A and B; C keeps numbers in ink and the
    /// heart glyph red), the target after the arrow, small. Tighter forms drop "bpm" (the heart
    /// in the ring already says it), then shrink the target, so the row never outgrows the bar.
    private var bpmFigure: some View {
        ViewThatFits(in: .horizontal) {
            figure(targetFont: look.font.smallNumber, unit: true)
            figure(targetFont: look.font.smallNumber, unit: false)
            figure(targetFont: .system(.subheadline, weight: .heavy).monospacedDigit(), unit: false)
        }
    }

    private func figure(targetFont: Font, unit: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(bpm.map(String.init) ?? "—")
                .font(look.font.bigNumber)
                .foregroundStyle(look.id.isPaperClub ? onSlabText : look.heartRate)
                .contentTransition(.numericText(value: Double(bpm ?? 0)))
            Image(systemName: "arrow.right")
                .font(.system(.caption, weight: .heavy))
                .foregroundStyle(onSlabSecondary)
            Text("\(threshold)")
                .font(targetFont)
                .foregroundStyle(onSlabText)
            if unit {
                Text("bpm").font(.system(.footnote, weight: .medium)).foregroundStyle(onSlabSecondary)
            }
        }
        .lineLimit(1)
        .fixedSize()
    }

    /// The cap, small: a stopwatch and the time left before the rest ends anyway.
    private var capLine: some View {
        HStack(spacing: 3) {
            Image(systemName: "timer").font(.system(.caption2, weight: .bold))
            Text(Format.duration(remaining)).monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
        }
        .font(labelFont)
        .foregroundStyle(onSlabSecondary)
        .fixedSize()
    }

    private var spoken: String {
        if isHeart {
            let reading = bpm.map { "Heart rate \($0), " } ?? ""
            return "Rest, \(reading)ends below \(threshold) beats per minute or in \(Format.duration(remaining))" + (next.map { ". \($0)" } ?? "")
        }
        return "Rest, \(Format.duration(remaining)) left" + (next.map { ". \($0)" } ?? "")
    }

    private var labelFont: Font {
        look.id.isPaperClub ? .system(.caption, weight: .semibold) : .system(.footnote, weight: look.id == .anatomy ? .bold : .regular)
    }
    private var nextFont: Font { look.id.isPaperClub ? .system(.caption, weight: .semibold) : look.font.footnote }

    private func add15(fill: Bool) -> some View {
        Button("+15s") { store.addRest(seconds: 15) }
            .buttonStyle(LivePillStyle(fill: fill))
            .accessibilityLabel("Add 15 seconds")
    }

    private func skip(fill: Bool) -> some View {
        Button("Skip") {
            withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.9)) { store.skipRest() }
        }
        .buttonStyle(LivePillStyle(prominent: true, fill: fill))
        // PROPOSAL: on the ink slab the filled pill takes the accent's light form (a dark accent
        // would vanish into the slab in light mode).
        .environment(\.look, slabButtonLook)
        .accessibilityLabel("Skip rest")
    }

    private var slabButtonLook: Look {
        var l = look
        if let light = look.liveOnSlabOverride {
            l.action = light
            l.onAction = Color(hex: 0x0B0C0E)
        }
        return l
    }
}

/// Heart-rate rest that fell back to the timer: why, in the app's existing words.
/// No reading: heart.slash + "No sensor reporting". An old reading: the grey bpm + "Not
/// reporting · 18s ago". Trailing: "Timer" — the rest now ends by the clock.
private struct LiveDegradedRow: View {
    @Environment(Store.self) private var store
    @Environment(\.look) private var look

    var body: some View {
        let text = look.id.isPaperClub ? look.onSlab : look.textPrimary
        let secondary = look.id.isPaperClub ? look.onSlabSecondary : look.textSecondary
        let font: Font = look.id.isPaperClub ? .system(.caption, weight: .semibold) : .system(.footnote, weight: .medium)
        let status: (glyph: String, value: String?, words: String) = {
            if case .stale(let last, let ago) = store.hrFeed { return ("heart.fill", "\(last)", "Not reporting · \(ago)s ago") }
            return ("heart.slash", nil, "No sensor reporting")
        }()
        let lead = HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: status.glyph).font(.system(.footnote, weight: .bold)).foregroundStyle(secondary)
            if let value = status.value {
                Text(value).font(.system(.subheadline, weight: .heavy).monospacedDigit()).foregroundStyle(secondary)
            }
            Text(status.words).font(font).foregroundStyle(text)
        }
        let tag = HStack(spacing: 4) {
            Image(systemName: "timer").font(.system(.caption, weight: .bold))
            Text("Timer").font(font)
        }
        .foregroundStyle(secondary)
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { lead.fixedSize(); Spacer(minLength: 8); tag.fixedSize() }
            VStack(alignment: .leading, spacing: 4) { lead; tag }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(status.value.map { "Last heart rate \($0), " } ?? "")\(status.words). Resting by the timer.")
    }
}

/// The rest ring: drains in the live colour (A Ultra, B pearl, C light cobalt on the slab). The
/// glyph says what the rest waits for: the hourglass (time), the beating heart (heart rate), or
/// the check (done, in the look's done colour).
struct LiveRestRing: View {
    enum Glyph: Equatable { case hourglass, heart(Int?), check }
    var progress: Double
    var isFinal = false
    var size: CGFloat
    var glyph: Glyph
    @Environment(\.look) private var look
    @Environment(\.lookOnSlab) private var onSlab
    @Environment(\.liveReduceMotion) private var reduceMotion

    var body: some View {
        let width = look.id.isPaperClub ? size * 0.103 : size * 0.09
        let done = glyph == .check
        let color: Color = done ? (onSlab ? look.onSlab : look.done) : (look.id == .floodlight && isFinal ? look.done : (onSlab ? look.liveOnSlab : look.live))
        let track: Color = look.id.isPaperClub ? (onSlab ? look.onSlab.opacity(0.16) : look.ringTrack) : look.wash(0.12)
        let glyphColor: Color = switch look.id {
        case .floodlight: color
        case .anatomy: look.textPrimary
        case .paper, .carbon: onSlab ? look.onSlab : look.textPrimary
        }
        ZStack {
            Circle().stroke(track, lineWidth: width)
            RingArc(start: 0, end: max(0, min(1, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round))
                .animation(reduceMotion ? nil : .linear(duration: 1), value: progress)
            switch glyph {
            case .hourglass:
                Image(systemName: "hourglass").font(.system(size: size * 0.36, weight: .semibold)).foregroundStyle(glyphColor)
            case .heart(let bpm):
                BeatingHeart(bpm: bpm, isFresh: bpm != nil, font: .system(size: size * 0.34, weight: .semibold))
            case .check:
                Image(systemName: "checkmark").font(.system(size: size * 0.36, weight: .heavy)).foregroundStyle(color)
            }
        }
        .padding(width / 2)
        .frame(width: size, height: size)
        .scaleEffect(isFinal && !reduceMotion && look.id == .floodlight ? 1.04 : 1)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: isFinal)
        .accessibilityHidden(true)
    }
}

// MARK: - Rest complete

/// The rest ended by itself: for a few seconds the slab says so — the ring closes with a check,
/// "Rest complete" over what ended it (the recovered reading, or the cap), and what is next.
/// Then it drops away and the next set's check takes the lead.
private struct LiveRestEndSlab: View {
    var end: LiveRestEnd
    @Environment(Store.self) private var store
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let text = look.id.isPaperClub ? look.onSlab : look.textPrimary
        let secondary = look.id.isPaperClub ? look.onSlabSecondary : look.textSecondary
        let next = store.liveNextLabel(look)
        HStack(spacing: 12) {
            LiveRestRing(progress: 1, size: typeSize.isAccessibilitySize ? 48 : (look.id.isPaperClub ? 58 : 56), glyph: .check)
            VStack(alignment: .leading, spacing: 0) {
                if hasFigure {
                    Text("Rest complete")
                        .font(look.id.isPaperClub ? .system(.caption, weight: .semibold) : .system(.footnote, weight: .semibold))
                        .foregroundStyle(secondary)
                    figure(text: text, secondary: secondary)
                } else {
                    // The timer ran out: the words are the figure.
                    Text("Rest complete").font(look.font.title3).foregroundStyle(text)
                }
                if let next {
                    Text(next)
                        .font(look.id.isPaperClub ? .system(.caption, weight: .semibold) : look.font.footnote)
                        .foregroundStyle(secondary)
                        .lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, typeSize.isAccessibilitySize ? 12 : 0)
        .frame(minHeight: look.id.isPaperClub ? 94 : 82)
        .environment(\.lookOnSlab, look.id.isPaperClub)
        .background { LiveSlabBackground() }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(["Rest complete", end.outcome.notificationBody, next].compactMap { $0 }.joined(separator: ". "))
    }

    private var hasFigure: Bool {
        switch end.outcome {
        case .recovered, .cap: true
        case .timerDone, .skipped: false
        }
    }

    @ViewBuilder private func figure(text: Color, secondary: Color) -> some View {
        switch end.outcome {
        case .recovered(let bpm):
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(bpm)").font(look.font.bigNumber)
                    .foregroundStyle(look.id.isPaperClub ? text : look.heartRate)
                Text("bpm").font(.system(.footnote, weight: .medium)).foregroundStyle(secondary)
            }
        case .cap:
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "timer").font(.system(.title3, weight: .bold)).foregroundStyle(secondary)
                Text(Format.duration(store.restSettingsCap)).font(look.font.bigNumber).foregroundStyle(text)
                if let bpm = store.currentBPM {
                    Text("\(bpm) bpm").font(.system(.footnote, weight: .semibold))
                        .foregroundStyle(look.id.isPaperClub ? secondary : look.heartRate)
                }
            }
        case .timerDone, .skipped:
            EmptyView()
        }
    }
}

private extension Store {
    /// The heart-rate cap of the exercise that was resting (defaults to 4:00).
    var restSettingsCap: Int {
        guard let id = liveEntry(currentEntryID)?.exerciseID else { return 240 }
        return restSettings(for: id).capSeconds
    }
}

// MARK: - New best

/// The NEW BEST band, docked on the rest slab for the few seconds after the set: the look's mark,
/// the exercise, today's set and — dimmed, with an up arrow — the best it beat. A strobes the band
/// once, B pops the pill, C swipes the highlighter and slaps the sticker. Tapping opens previous
/// performance. Reduce Motion: it simply appears.
struct LiveBestBand: View {
    var completion: SetCompletion

    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.liveReduceMotion) private var reduceMotion
    @State private var landed = 0

    private var previous: SetValue? {
        if case .newBest(let previous) = completion.outcome { return previous }
        return nil
    }

    var body: some View {
        let loadType = store.loadType(entryID: completion.entryID)
        let now = look.previousLabel(completion.value, rowUnit: completion.value.unit, loadType: loadType)
        let was = previous.map { look.previousLabel($0, rowUnit: completion.value.unit, loadType: loadType) }
        let secondary = look.id.isPaperClub ? look.onSlabSecondary : look.textSecondary
        Button {
            router.present(.previousPerformance(entryID: completion.entryID))
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    NewBestBadge(kind: .newBest)
                        .modifier(LiveLandEffect(trigger: landed, look: look))
                    Text(completion.exerciseName)
                        .font(.system(.subheadline, design: look.id == .anatomy ? .rounded : .default, weight: .semibold))
                        .foregroundStyle(secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 3) {
                    LiveBestValue(text: now, trigger: landed)
                    if let was {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.up").font(.system(.caption2, weight: .heavy))
                            Text(was).font(.system(.footnote, weight: .medium)).monospacedDigit()
                        }
                        .foregroundStyle(secondary.opacity(0.85))
                        .lineLimit(1)
                        .fixedSize()
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay { strobe }
            .contentShape(Rectangle())
        }
        .buttonStyle(.lookPressable)
        .onAppear { if !reduceMotion { landed += 1 } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("New best, \(completion.exerciseName), \(Format.set(completion.value))"
                            + (previous.map { ", up from \(Format.set($0))" } ?? ""))
        .accessibilityHint("Opens previous performance")
    }

    /// A: the floodlight double strobe across the band (the row strobes too).
    @ViewBuilder private var strobe: some View {
        if look.id == .floodlight && !reduceMotion {
            Rectangle()
                .fill(look.positive)
                .allowsHitTesting(false)
                .keyframeAnimator(initialValue: 0.0, trigger: landed) { view, opacity in
                    view.opacity(opacity)
                } keyframes: { _ in
                    KeyframeTrack {
                        LinearKeyframe(0.26, duration: 0.14)
                        LinearKeyframe(0, duration: 0.16)
                        LinearKeyframe(0.16, duration: 0.14)
                        LinearKeyframe(0, duration: 0.4)
                    }
                }
        }
    }
}

/// AX: the band's few seconds take the place of the Rest/time text — just the value (with the
/// look's one mark) and the exercise.
private struct LiveBestCompact: View {
    var completion: SetCompletion
    @Environment(Store.self) private var store
    @Environment(\.look) private var look
    @Environment(\.liveReduceMotion) private var reduceMotion
    @State private var landed = 0

    var body: some View {
        let loadType = store.loadType(entryID: completion.entryID)
        let now = look.previousLabel(completion.value, rowUnit: completion.value.unit, loadType: loadType)
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                switch look.id {
                case .floodlight: Image(systemName: "burst.fill").font(.system(.headline, weight: .bold)).foregroundStyle(look.positive)
                case .anatomy: Image(systemName: "star.fill").font(.system(.headline, weight: .heavy)).foregroundStyle(look.textPrimary)
                case .paper, .carbon: EmptyView()
                }
                LiveBestValue(text: now, trigger: landed)
            }
            .modifier(LiveLandEffect(trigger: landed, look: look))
            Text(completion.exerciseName)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(look.id.isPaperClub ? look.onSlabSecondary : look.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onAppear { if !reduceMotion { landed += 1 } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("New best, \(completion.exerciseName), \(Format.set(completion.value))")
    }
}

/// Today's best value: A and B plain figures; C swiped in highlighter (ink on yellow).
private struct LiveBestValue: View {
    var text: String
    var trigger: Int
    @Environment(\.look) private var look

    var body: some View {
        let font = look.id == .anatomy ? look.font.statNumber : look.font.smallNumber
        switch look.id {
        case .paper, .carbon:
            Text(text).font(font).foregroundStyle(look.onPositive)
                .lineLimit(1)
                .padding(.horizontal, 6).padding(.vertical, 1)
                .background { LiveHighlighterSwipe(trigger: trigger) }
                .fixedSize()
        default:
            Text(text).font(font).foregroundStyle(look.textPrimary).lineLimit(1).fixedSize()
        }
    }
}

/// How the mark lands: A drops in with an overshoot, B pops, C slaps on with a twist.
private struct LiveLandEffect: ViewModifier {
    var trigger: Int
    var look: Look

    struct Value { var scale: CGFloat = 1; var rotation: Double = 0; var y: CGFloat = 0 }

    /// (start scale, overshoot, start rotation, overshoot rotation, start y, first leg, settle leg)
    private var params: (CGFloat, CGFloat, Double, Double, CGFloat, Double, Double) {
        switch look.id {
        case .floodlight: (1.3, 0.96, 0, 0, -8, 0.2, 0.22)
        case .anatomy: (0.6, 1.12, 0, 0, 0, 0.25, 0.2)
        case .paper, .carbon: (1.5, 0.97, -6, 1.2, 0, 0.18, 0.14)
        }
    }

    func body(content: Content) -> some View {
        let p = params
        return content.keyframeAnimator(initialValue: Value(), trigger: trigger) { view, v in
            view.scaleEffect(v.scale).rotationEffect(.degrees(v.rotation)).offset(y: v.y)
        } keyframes: { _ in
            KeyframeTrack(\.scale) {
                MoveKeyframe(p.0)
                CubicKeyframe(p.1, duration: p.5)
                CubicKeyframe(1, duration: p.6)
            }
            KeyframeTrack(\.rotation) {
                MoveKeyframe(p.2)
                CubicKeyframe(p.3, duration: p.5)
                CubicKeyframe(0, duration: p.6)
            }
            KeyframeTrack(\.y) {
                MoveKeyframe(p.4)
                CubicKeyframe(0, duration: p.5 + p.6)
            }
        }
    }
}

/// C: the highlighter swipes left to right behind the value.
private struct LiveHighlighterSwipe: View {
    var trigger: Int
    @Environment(\.look) private var look
    @Environment(\.liveReduceMotion) private var reduceMotion

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 3, style: .continuous)
        if reduceMotion || trigger == 0 {
            shape.fill(look.positive)
        } else {
            shape.fill(look.positive)
                .keyframeAnimator(initialValue: 1.0, trigger: trigger) { view, fraction in
                    view.scaleEffect(x: fraction, y: 1, anchor: .leading)
                } keyframes: { _ in
                    KeyframeTrack {
                        MoveKeyframe(0.0)
                        CubicKeyframe(1.0, duration: 0.4)
                    }
                }
        }
    }
}

// MARK: - Entry bar (while typing)

/// Rides above the number pad while a weight or reps field is being typed: −/+ steppers
/// (5 lb / 2.5 kg, per side 2.5 lb / 1.25 kg; reps ±1), the rest still counting down, Next and Done.
struct LiveEntryBar: View {
    @Environment(Store.self) private var store
    @Environment(LiveScreenModel.self) private var model
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let target = model.editing
        let ax = typeSize.isAccessibilitySize
        let stepLabel: (Bool) -> String = { up in
            guard let t = target else { return up ? "+" : "−" }
            if t.field == .reps { return up ? "+1" : "−1" }
            return LiveNumberEntry.stepLabel(store.liveWeightStep(entryID: t.entryID, setID: t.setID), up: up)
        }
        let hasNext = model.nextTarget(store: store) != nil
        let steppers = Group {
            Button(stepLabel(false)) { model.step(up: false, store: store) }
                .buttonStyle(LivePillStyle(fill: ax))
                .accessibilityLabel(target?.field == .reps ? "One rep fewer" : "Less weight")
            Button(stepLabel(true)) { model.step(up: true, store: store) }
                .buttonStyle(LivePillStyle(fill: ax))
                .accessibilityLabel(target?.field == .reps ? "One rep more" : "More weight")
        }
        let actions = Group {
            if hasNext {
                Button("Next") { model.next(store: store) }.buttonStyle(LivePillStyle(fill: ax))
            }
            Button("Done") { model.endEditing() }.buttonStyle(LivePillStyle(prominent: true, fill: ax))
        }
        Group {
            if ax {
                VStack(spacing: 10) {
                    HStack(spacing: 10) { restMini; steppers }
                    HStack(spacing: 10) { actions }
                }
                .padding(12)
            } else {
                HStack(spacing: 8) {
                    restMini
                    steppers
                    Spacer(minLength: 0)
                    actions
                }
                .padding(.horizontal, 10)
                .frame(minHeight: 64)
            }
        }
        .environment(\.lookOnSlab, look.id.isPaperClub)
        .background { LiveSlabBackground() }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { model.entryBarHeight = $0 }
    }

    /// The rest keeps counting while you type (ring + time), so the bar never hides it.
    @ViewBuilder private var restMini: some View {
        if let rest = store.rest {
            let remaining = rest.remaining(at: store.now)
            HStack(spacing: 6) {
                LiveRestRing(progress: rest.totalSeconds > 0 ? Double(remaining) / Double(rest.totalSeconds) : 0,
                             isFinal: remaining <= 10 && remaining > 0, size: 30, glyph: .hourglass)
                Text(Format.duration(remaining))
                    .font(.system(.headline, design: look.id == .anatomy ? .rounded : .default, weight: .heavy).monospacedDigit())
                    .foregroundStyle(look.id.isPaperClub ? look.onSlab : look.textPrimary)
                    .contentTransition(.numericText(countsDown: true))
                    .fixedSize()
            }
            .padding(.leading, 2)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Rest, \(Format.duration(remaining)) left")
        }
    }
}

// MARK: - PROPOSAL: Finish at the thumb

/// One place to end every session: the bottom of the screen, where the rest slab and cardio's
/// Pause live. Shown whenever nothing else floats there; the rest slab takes the slot while
/// resting (Skip, then Finish).
struct ProposedFinishBar: View {
    var action: () -> Void
    @Environment(Store.self) private var store
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let done = store.session?.completedSetCount ?? 0
        let total = store.session?.totalSetCount ?? 0
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark")
                    .font(.system(.body, weight: .bold))
                Text("Finish Workout")
                    .font(.system(.headline, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if total > 0 && !typeSize.isAccessibilitySize {
                    Spacer(minLength: 8)
                    Text("\(done)/\(total) sets")
                        .font(.system(.subheadline, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(look.textSecondary)
                }
            }
            .foregroundStyle(look.textPrimary)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: total > 0 && !typeSize.isAccessibilitySize ? .leading : .center)
            .contentShape(Capsule())
        }
        .buttonStyle(.lookPressable)
        .background { Capsule().fill(look.surfaceRaised) }
        .overlay { Capsule().strokeBorder(look.hairline) }
        .shadow(color: .black.opacity(look.isDark ? 0.4 : 0.12), radius: 12, y: 4)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }
}
