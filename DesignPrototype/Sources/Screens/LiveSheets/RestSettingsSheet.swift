import SwiftUI

// PROTOTYPE — L11 Rest for one exercise. "How this exercise rests": Timer | Heart rate.
// The two rests are always the same dials (the rest bar's ring on a five-minute dial with
// minute ticks, the time inside, − / + under it, hold to repeat) and each dial carries its own
// "Default" switch right under it: on, the dial shows the default dimmed; off, it shows your
// override with the default's value under the switch. Heart rate adds the rule as a picture on
// the heart-rate plate (C: the ink slab) — your heart rate falling from now, the "end rest
// below" line, the cap and where rest would end — with both numbers as big steppers; the dials
// then sit under "No heart rate" (what rest does without a reading).
// Cancel · Save. Variants: "heartRate" (heart-rate mode), "custom" (working rest overridden to
// 2:30), "noSensor" / "noReading" (heart-rate mode with no reading coming in).

struct RestSettingsSheet: View {
    let entryID: UUID

    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var environmentTypeSize
    /// The sheet root sits outside its own `.dynamicTypeSize` override, so it resolves the
    /// prototype override itself (children read the environment as usual).
    private var typeSize: DynamicTypeSize { router.dynamicTypeOverride ?? environmentTypeSize }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var draft = RestSettings()
    @State private var working = 120
    @State private var warmup = 60
    @State private var workingDefault = true
    @State private var warmupDefault = true
    @State private var noReading = false
    @State private var loaded = false
    @State private var page: Int?
    /// Timer mode fits in a shorter sheet (the two dials); heart rate needs the whole height.
    @State private var detent: PresentationDetent = LiveSheetsRestDetent.timer

    private var entry: LiveEntry? { store.liveEntry(entryID) }
    private var exercise: Exercise? { store.exercise(entry?.exerciseID) }
    /// What "global default" means for this entry: the template's planned rest, else Settings.
    private var workingFallback: Int { entry?.plannedRestSeconds ?? store.settings.workingRestSeconds }
    private var warmupFallback: Int { store.settings.warmupRestSeconds }
    private var bpmNow: Int? { noReading ? nil : store.currentBPM }

    var body: some View {
        VStack(spacing: 0) {
            LiveSheetsHeader(title: "Rest", subtitle: exercise?.name,
                             leading: .cancel { router.dismissSheet() },
                             trailing: .commit("Save", enabled: true, action: save))
            LiveSheetsScroll(page: page) {
                VStack(alignment: .leading, spacing: 24) {
                    modePicker
                    if draft.mode == .heartRate {
                        heartRatePlate
                            .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        if draft.mode == .heartRate {
                            Label("No heart rate", systemImage: "heart.slash")
                                .font(.system(.footnote, weight: .semibold))
                                .foregroundStyle(look.textSecondary)
                                .padding(.leading, 4)
                                .accessibilityAddTraits(.isHeader)
                                .transition(.opacity)
                        }
                        dials
                    }
                }
                .padding(.horizontal, look.space.margin)
                .padding(.top, 8)
                .padding(.bottom, 48)
            }
        }
        .liveSheetsPresentation(look)
        .presentationDetents([LiveSheetsRestDetent.timer, .large], selection: $detent)
        .onChange(of: draft.mode) { _, mode in
            let next: PresentationDetent = mode == .heartRate ? .large : LiveSheetsRestDetent.timer
            if reduceMotion { detent = next } else { withAnimation(.snappy) { detent = next } }
        }
        .sensoryFeedback(.selection, trigger: draft.mode)
        .onAppear(perform: load)
    }

    // MARK: Mode

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How this exercise rests")
                .font(.system(.footnote, weight: .semibold))
                .foregroundStyle(look.textSecondary)
                .padding(.leading, 4)
                .accessibilityAddTraits(.isHeader)
            SegmentedPills(RestMode.allCases.map(\.label), selection: Binding(
                get: { draft.mode == .timer ? 0 : 1 },
                set: { index in
                    let mode: RestMode = index == 0 ? .timer : .heartRate
                    if reduceMotion { draft.mode = mode } else { withAnimation(.snappy(duration: 0.3)) { draft.mode = mode } }
                }))
                .accessibilityLabel("Rest by")
        }
    }

    // MARK: Heart-rate plate

    private var heartRatePlate: some View {
        HeartRatePlate(title: nil) {
            ZStack(alignment: .topLeading) {
                LiveSheetsRecoveryChart(startBpm: bpmNow, threshold: draft.thresholdBpm, cap: draft.capSeconds)
                    .frame(height: 150)
                if bpmNow == nil { LiveSheetsNoReadingTag() }
            }
            LookDivider()
            VStack(alignment: .leading, spacing: 6) {
                StepperCaption(text: "End rest below")
                LiveSheetsBigStepper(value: $draft.thresholdBpm, range: 40...200, step: 5, unit: "bpm",
                                     accessibilityName: "End rest below") { "\($0)" }
            }
            VStack(alignment: .leading, spacing: 6) {
                StepperCaption(text: "…or after")
                LiveSheetsBigStepper(value: $draft.capSeconds, range: 30...900, step: 30, unit: "at the latest",
                                     accessibilityName: "…or after") { Format.rest($0) }
            }
        }
    }

    // MARK: Dials (one representation in both modes)

    /// The two rests side by side (stacked at accessibility sizes), each with its own
    /// "Default" switch under it.
    private var dials: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 26))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 14))
        return layout {
            LiveSheetsRestDial(title: "Working & failure sets",
                               seconds: steppedBinding($working, useDefault: $workingDefault, fallback: workingFallback),
                               isDefault: defaultBinding($workingDefault, value: $working, fallback: workingFallback),
                               fallback: workingFallback,
                               color: dialColor)
            LiveSheetsRestDial(title: "Warmup sets",
                               seconds: steppedBinding($warmup, useDefault: $warmupDefault, fallback: warmupFallback),
                               isDefault: defaultBinding($warmupDefault, value: $warmup, fallback: warmupFallback),
                               fallback: warmupFallback,
                               color: look.warmup)
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .lookSurface(.panel)
    }

    /// Floodlight keeps Ultra for Save, so its working dial is lit flood; B pearl (its live
    /// instrument); C cobalt ink.
    private var dialColor: Color {
        switch look.id {
        case .floodlight: look.textPrimary
        case .anatomy: look.live
        case .paper, .carbon: look.actionText
        }
    }

    private func defaultBinding(_ useDefault: Binding<Bool>, value: Binding<Int>, fallback: Int) -> Binding<Bool> {
        Binding(
            get: { useDefault.wrappedValue },
            set: { on in
                if !on { value.wrappedValue = fallback }
                if reduceMotion { useDefault.wrappedValue = on } else { withAnimation(.snappy) { useDefault.wrappedValue = on } }
            })
    }

    /// The shown value: the default while "Default" is on; stepping writes the override and
    /// turns the default off.
    private func steppedBinding(_ value: Binding<Int>, useDefault: Binding<Bool>, fallback: Int) -> Binding<Int> {
        Binding<Int>(
            get: { useDefault.wrappedValue ? fallback : value.wrappedValue },
            set: { next in
                value.wrappedValue = next
                if useDefault.wrappedValue {
                    if reduceMotion { useDefault.wrappedValue = false } else { withAnimation(.snappy) { useDefault.wrappedValue = false } }
                }
            })
    }

    // MARK: Actions

    private func save() {
        guard let exercise else { router.dismissSheet(); return }
        var settings = draft
        settings.workingSeconds = workingDefault ? nil : working
        settings.warmupSeconds = warmupDefault ? nil : warmup
        store.setRestSettings(settings, for: exercise.id)
        router.dismissSheet()
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        let variant = LiveSheetsVariant.consume([.l11], store: store, router: router)
        page = LiveSheetsVariant.page(variant)
        if let exercise { draft = store.restSettings(for: exercise.id) }
        workingDefault = draft.workingSeconds == nil
        warmupDefault = draft.warmupSeconds == nil
        working = draft.workingSeconds ?? workingFallback
        warmup = draft.warmupSeconds ?? warmupFallback
        if LiveSheetsVariant.has(variant, "heartRate") { draft.mode = .heartRate }
        if LiveSheetsVariant.has(variant, "noReading") { draft.mode = .heartRate; noReading = true }
        // "noSensor" (applied by the shell: no heart-rate source at all) opens in heart-rate mode.
        if LiveSheetsVariant.has(variant, "noSensor") { draft.mode = .heartRate }
        if LiveSheetsVariant.has(variant, "custom") { working = 150; workingDefault = false }
        // Accessibility sizes stack the dials, so the sheet opens full height; so does heart rate.
        detent = draft.mode == .heartRate || typeSize.isAccessibilitySize ? .large : LiveSheetsRestDetent.timer
    }
}

enum LiveSheetsRestDetent {
    static let timer = PresentationDetent.fraction(0.64)
}

/// "No heart rate" on the plate when no reading is coming in (the curve is then a sketch).
private struct LiveSheetsNoReadingTag: View {
    @Environment(\.look) private var look
    @Environment(\.lookOnSlab) private var onSlab
    var body: some View {
        Label("No heart rate", systemImage: "heart.slash")
            .font(.system(.caption, weight: .bold))
            .foregroundStyle(onSlab ? look.onSlabSecondary : look.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(onSlab ? look.slab : look.surfaceSheet))
            .overlay(Capsule().strokeBorder(onSlab ? look.onSlab.opacity(0.25) : look.hairline, lineWidth: 1))
            .padding(.leading, 30)
    }
}

/// A small caption above a stepper on the plate (slab-aware).
private struct StepperCaption: View {
    var text: String
    @Environment(\.look) private var look
    @Environment(\.lookOnSlab) private var onSlab
    var body: some View {
        Text(text)
            .font(.system(.footnote, weight: .semibold))
            .foregroundStyle(onSlab ? look.onSlabSecondary : look.textSecondary)
            .accessibilityHidden(true)
    }
}

// MARK: - Recovery chart

/// Heart rate falling from now after a set, the "end rest below" line, the cap, and the point
/// where rest would end (the line if you get there first, else the cap). Numbers only:
/// start bpm, the threshold, 0:00 and the cap time. The lines glide when the steppers move.
struct LiveSheetsRecoveryChart: View {
    /// nil when no reading comes in: the curve is then a grey sketch from a nominal 140.
    var startBpm: Int?
    var threshold: Int
    var cap: Int
    @Environment(\.look) private var look
    @Environment(\.lookOnSlab) private var onSlab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn: Double = 0

    private let floorBpm = 92.0
    private let tau = 95.0

    private var start: Double { Double(max(startBpm ?? 140, threshold + 5)) }
    private var curveColor: Color { startBpm == nil ? secondary : look.heartRate }
    private var crossing: Double? {
        let t = Double(threshold)
        guard t > floorBpm, t < start else { return t >= start ? 0 : nil }
        return -tau * log((t - floorBpm) / (start - floorBpm))
    }
    private var endSeconds: Double { min(crossing ?? .infinity, Double(cap)) }
    private var xMax: Double { max(Double(cap) * 1.18, 200) }
    private var yMin: Double { min(Double(threshold), floorBpm) - 12 }
    private var yMax: Double { max(start, Double(threshold)) + 14 }

    private var primary: Color { onSlab ? look.onSlab : look.textPrimary }
    private var secondary: Color { onSlab ? look.onSlabSecondary : look.textSecondary }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width - 34, h = geo.size.height - 22
            let x = { (s: Double) in CGFloat(s / xMax) * w }
            let y = { (b: Double) in CGFloat(1 - (b - yMin) / (yMax - yMin)) * h }
            let bpmAtEnd = floorBpm + (start - floorBpm) * exp(-endSeconds / tau)
            ZStack(alignment: .topLeading) {
                // Threshold line and its number.
                Path { p in p.move(to: CGPoint(x: 0, y: y(Double(threshold)))); p.addLine(to: CGPoint(x: w, y: y(Double(threshold)))) }
                    .stroke(primary.opacity(0.55), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                Text("\(threshold)")
                    .font(.system(.caption, weight: .bold).monospacedDigit())
                    .foregroundStyle(primary)
                    .position(x: w + 18, y: y(Double(threshold)))
                // Cap line and its time.
                Path { p in p.move(to: CGPoint(x: x(Double(cap)), y: 0)); p.addLine(to: CGPoint(x: x(Double(cap)), y: h)) }
                    .stroke(secondary.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                Text(Format.rest(cap))
                    .font(.system(.caption2, weight: .semibold).monospacedDigit())
                    .foregroundStyle(secondary)
                    .position(x: min(w - 10, x(Double(cap))), y: h + 12)
                Text("0:00")
                    .font(.system(.caption2, weight: .semibold).monospacedDigit())
                    .foregroundStyle(secondary)
                    .position(x: 14, y: h + 12)
                // What happens after rest ends (faint), then the rest itself (solid).
                LiveSheetsRecoveryCurve(start: start, floor: floorBpm, tau: tau, from: endSeconds, to: xMax,
                                        xMax: xMax, yMin: yMin, yMax: yMax)
                    .stroke(curveColor.opacity(0.28), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 4]))
                    .frame(width: w, height: h)
                LiveSheetsRecoveryCurve(start: start, floor: floorBpm, tau: tau, from: 0, to: endSeconds * drawn,
                                        xMax: xMax, yMin: yMin, yMax: yMax)
                    .stroke(curveColor, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round,
                                                           dash: startBpm == nil ? [6, 5] : []))
                    .frame(width: w, height: h)
                // Now, and where rest ends.
                Circle().fill(curveColor).frame(width: 9, height: 9)
                    .position(x: 0, y: y(start))
                if startBpm != nil {
                    Text("\(Int(start))")
                        .font(.system(.caption, weight: .bold).monospacedDigit())
                        .foregroundStyle(look.heartRate)
                        .position(x: 22, y: y(start) - 12)
                }
                Circle()
                    .fill(onSlab ? look.slab : look.surfaceSheet)
                    .overlay { Circle().strokeBorder(curveColor, lineWidth: 3) }
                    .frame(width: 14, height: 14)
                    .position(x: x(endSeconds), y: y(bpmAtEnd))
                    .opacity(drawn)
            }
            .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: threshold)
            .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: cap)
        }
        .appearProgress($drawn, delay: 0.15, duration: 0.8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rest ends below \(threshold) bpm or after \(Format.rest(cap))")
    }
}

/// bpm(t) = floor + (start − floor) · e^(−t/τ), drawn between two times.
struct LiveSheetsRecoveryCurve: Shape {
    var start: Double
    var floor: Double
    var tau: Double
    var from: Double
    var to: Double
    var xMax: Double
    var yMin: Double
    var yMax: Double

    var animatableData: AnimatablePair<AnimatablePair<Double, Double>, AnimatablePair<Double, Double>> {
        get { AnimatablePair(AnimatablePair(from, to), AnimatablePair(xMax, yMin)) }
        set {
            from = newValue.first.first
            to = newValue.first.second
            xMax = newValue.second.first
            yMin = newValue.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard to > from else { return p }
        let steps = 48
        for i in 0...steps {
            let t = from + (to - from) * Double(i) / Double(steps)
            let bpm = floor + (start - floor) * exp(-t / tau)
            let point = CGPoint(x: rect.minX + CGFloat(t / xMax) * rect.width,
                                y: rect.minY + CGFloat(1 - (bpm - yMin) / (yMax - yMin)) * rect.height)
            if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
        }
        return p
    }
}

// MARK: - Rest dial

/// One rest as the rest bar's ring at full size on a five-minute dial (a tick per minute, the
/// ring grows as you step), the time inside, − / + under it (hold to repeat), then its own
/// "Default" switch. While the default is on the dial reads dimmed; off, the default's value
/// sits under the switch. VoiceOver adjusts the dial like a stepper.
struct LiveSheetsRestDial: View {
    var title: String
    @Binding var seconds: Int
    @Binding var isDefault: Bool
    var fallback: Int
    var color: Color
    var range: ClosedRange<Int> = 0...600
    var step: Int = 15
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .title) private var button: CGFloat = 46
    @ScaledMetric(relativeTo: .title) private var size: CGFloat = 128

    private let lineWidth: CGFloat = 12

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.system(.footnote, design: look.id == .anatomy ? .rounded : .default, weight: .semibold))
                .foregroundStyle(look.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
            dial
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(title)
                .accessibilityValue(Format.rest(seconds) + (isDefault ? ", default" : ""))
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: change(step)
                    case .decrement: change(-step)
                    @unknown default: break
                    }
                }
            HStack(spacing: 18) {
                LiveSheetsRoundButton(symbol: "minus", enabled: seconds - step >= range.lowerBound, size: button) { change(-step) }
                LiveSheetsRoundButton(symbol: "plus", enabled: seconds + step <= range.upperBound, size: button) { change(step) }
            }
            .accessibilityHidden(true)
            LookDivider()
            Toggle(isOn: $isDefault) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Default")
                        .font(.system(.subheadline, design: look.id == .anatomy ? .rounded : .default, weight: .semibold))
                        .foregroundStyle(look.textPrimary)
                    if !isDefault {
                        Text(Format.rest(fallback))
                            .font(.system(.footnote, weight: .medium).monospacedDigit())
                            .foregroundStyle(look.textSecondary)
                            .transition(.opacity)
                    }
                }
            }
            .toggleStyle(LiveSheetsToggleStyle())
            .frame(minHeight: 44)
            .accessibilityLabel("Use global default, \(title)")
        }
        .frame(maxWidth: .infinity)
        .sensoryFeedback(.selection, trigger: seconds)
    }

    private var dial: some View {
        ZStack {
            Circle().stroke(look.id.isPaperClub ? look.ringTrack : look.controlFill, lineWidth: lineWidth)
            // A tick per minute on the inside of the track: the dial's scale (0–5 min).
            ForEach(0..<5, id: \.self) { minute in
                Capsule()
                    .fill(look.textTertiary.opacity(0.7))
                    .frame(width: 2, height: 6)
                    .offset(y: -(size / 2 - lineWidth - 8))
                    .rotationEffect(.degrees(Double(minute) * 72))
            }
            RingArc(start: 0, end: max(0.004, min(1, Double(seconds) / 300)))
                .stroke(isDefault ? color.opacity(0.38) : color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: seconds)
            VStack(spacing: 2) {
                Image(systemName: "hourglass")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(look.textSecondary)
                Text(Format.rest(seconds))
                    .font(look.font.bigNumber)
                    .foregroundStyle(look.textPrimary)
                    .contentTransition(.numericText(value: Double(seconds)))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .padding(lineWidth + 10)
        }
        .padding(lineWidth / 2)
        .frame(width: size, height: size)
    }

    private func change(_ delta: Int) {
        let next = min(range.upperBound, max(range.lowerBound, seconds + delta))
        guard next != seconds else { return }
        if reduceMotion { seconds = next } else { withAnimation(.snappy(duration: 0.22)) { seconds = next } }
    }
}
