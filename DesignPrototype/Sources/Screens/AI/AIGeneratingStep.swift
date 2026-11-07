import SwiftUI

// PROTOTYPE — A03 generating (and its error state). The wait shows the week being built from
// the store's staged progress: a sweeping live ring with the percentage, the stage line
// ("Checking equipment at Iron Temple…"), then a board where the sessions fill in one by one
// and the muscle families light during "Balancing muscle families…".
// Reduce Motion: no sweep or shimmer; the ring and board step with the stages, text swaps.

struct AIGeneratingStepView: View {
    var actions: AIFlowActions

    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.aiStill) private var still

    private var reduceMotion: Bool { systemReduceMotion || still }

    /// Capture variants "balancing" / "fitting" show a later stage of the (frozen) run: the
    /// store's stage table at 65 % / 90 %. Otherwise the store's live progress.
    private var stage: (progress: Double, text: String) {
        let stages = AISimulator.stages(gymName: store.gym(store.ai.request.gymID)?.name)
        if store.currentScreen == .a03 && store.freezeClock {
            switch router.variant {
            case "balancing": return (stages[2].progress, stages[2].text)
            case "fitting": return (stages[3].progress, stages[3].text)
            default: break
            }
        }
        return (store.ai.progress, store.ai.progressText)
    }

    var body: some View {
        let stage = stage
        ViewThatFits(in: .vertical) {
            content(compact: false, stage: stage)
            ScrollView { content(compact: true, stage: stage) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(look.ground.ignoresSafeArea())
        .safeAreaBar(edge: .top) { AITopBar(step: 2, progress: stage.progress, divider: false, onCancel: actions.close) }
        .safeAreaBar(edge: .bottom) {
            AIBottomBar(fade: false) {
                Button("Back to preferences", action: actions.stopGenerating)
                    .buttonStyle(.lookSecondary)
            }
        }
    }

    private func content(compact: Bool, stage: (progress: Double, text: String)) -> some View {
        VStack(spacing: 0) {
            if !compact { Spacer(minLength: 20) }
            instrument(stage)
                .padding(.top, compact ? 24 : 0)
            AIBuildBoard(progress: stage.progress,
                         days: store.ai.request.daysPerWeek,
                         families: store.aiEligibleFamilies)
                .padding(.top, 20)
            if !compact { Spacer(minLength: 20) }
        }
        .padding(.horizontal, look.space.margin)
        .padding(.bottom, 16)
    }

    /// The ring and the stage line. C puts them on its ink slab (a live instrument).
    @ViewBuilder private func instrument(_ stage: (progress: Double, text: String)) -> some View {
        let stack = VStack(spacing: 18) {
            AIProgressRing(progress: stage.progress, isRunning: store.ai.step == .generating)
            VStack(spacing: 6) {
                Text(stage.text)
                    .font(look.font.title3)
                    .multilineTextAlignment(.center)
                    .id(stage.text)
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .offset(y: 10).combined(with: .opacity),
                        removal: .offset(y: -10).combined(with: .opacity)))
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: stage.text)
                Text(AIRequestLine.text(store: store, omittingGymIn: stage.text))
                    .font(look.font.footnote)
                    .foregroundStyle(look.id.isPaperClub ? look.onSlabSecondary : look.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .accessibilityElement(children: .combine)
        }
        if look.id.isPaperClub {
            stack
                .foregroundStyle(look.onSlab)
                .padding(.vertical, 24)
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity)
                .background(look.slab, in: RoundedRectangle(cornerRadius: look.radius.bar, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: look.radius.bar, style: .continuous)
                        .strokeBorder(look.slabEdge, lineWidth: 1.5)
                }
                .environment(\.lookOnSlab, true)
        } else {
            stack
                .foregroundStyle(look.textPrimary)
                .frame(maxWidth: .infinity)
        }
    }
}

/// "Iron Temple · 3 days · 45 min" — what the request carries.
enum AIRequestLine {
    static func text(store: Store, omittingGymIn line: String = "") -> String {
        let r = store.ai.request
        var parts: [String] = []
        // The gym, unless the stage line already names it ("Checking equipment at Iron Temple…").
        if let gym = store.gym(r.gymID), !line.contains(gym.name) { parts.append(gym.name) }
        parts.append("\(r.daysPerWeek) \(r.daysPerWeek == 1 ? "day" : "days")")
        parts.append("\(r.minutesPerSession) min")
        return parts.joined(separator: " · ")
    }
}

// MARK: - Progress ring

/// The live ring: A Ultra (A's "live now"), B pearl, C light cobalt on the slab. A bright
/// comet sweeps the track while the request runs. The percentage is the store's progress.
struct AIProgressRing: View {
    var progress: Double
    var isRunning: Bool
    @Environment(\.look) private var look
    @Environment(\.lookOnSlab) private var onSlab
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.aiStill) private var still
    @ScaledMetric(relativeTo: .largeTitle) private var sizeScaled: CGFloat = 188

    private var reduceMotion: Bool { systemReduceMotion || still }
    @ScaledMetric(relativeTo: .largeTitle) private var numberSize: CGFloat = 54

    var body: some View {
        let side = min(sizeScaled, 240)
        let width = side * (look.id == .anatomy ? 0.07 : 0.075)
        let color = look.live
        let track: Color = onSlab ? look.onSlab.opacity(0.14) : look.ringTrack
        ZStack {
            Circle().stroke(track, lineWidth: width)
            if isRunning && !reduceMotion {
                // A neutral glint sweeps the unfilled track (the request is live); the only
                // live-coloured arc is the real progress.
                let glint: Color = onSlab ? look.onSlab : look.textPrimary
                TimelineView(.animation) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    let span = max(0.08, 1 - progress)
                    let head = progress + (t / 1.6).truncatingRemainder(dividingBy: 1) * span
                    RingArc(start: max(progress, head - 0.12), end: head)
                        .stroke(AngularGradient(colors: [glint.opacity(0), glint.opacity(0.16)],
                                                center: .center,
                                                startAngle: .degrees(max(progress, head - 0.12) * 360 - 90),
                                                endAngle: .degrees(head * 360 - 90)),
                                style: StrokeStyle(lineWidth: width, lineCap: .round))
                }
            }
            RingArc(start: 0, end: max(0.001, min(1, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.7), value: progress)
            VStack(spacing: 2) {
                Image(systemName: "sparkles")
                    .font(.system(.title3, weight: .semibold))
                    .foregroundStyle(onSlab ? look.onSlabSecondary : look.textSecondary)
                    .symbolEffect(.pulse, options: .repeating, isActive: isRunning && !reduceMotion)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(Int((progress * 100).rounded()))")
                        .font(numberFont)
                        .foregroundStyle(onSlab ? look.onSlab : look.textPrimary)
                        .contentTransition(.numericText(value: progress))
                        .animation(reduceMotion ? nil : .snappy, value: progress)
                    Text("%")
                        .font(.system(.title3, design: look.id == .anatomy ? .rounded : .default, weight: .bold))
                        .foregroundStyle(onSlab ? look.onSlabSecondary : look.textSecondary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
        }
        .padding(width / 2)
        .frame(width: side, height: side)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Building your week")
        .accessibilityValue("\(Int((progress * 100).rounded())) percent")
    }

    private var numberFont: Font {
        switch look.id {
        case .anatomy: .system(size: numberSize, weight: .heavy, design: .rounded).monospacedDigit()
        default: Font.system(size: numberSize, weight: .heavy).width(.expanded).monospacedDigit()
        }
    }
}

// MARK: - Build board

/// The week taking shape: one cell per session (filled as progress passes it) and the five
/// family maps, lit one after another once the families are being balanced.
private struct AIBuildBoard: View {
    var progress: Double
    var days: Int
    var families: Set<MuscleFamily>
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.aiStill) private var still
    @State private var shimmer = false

    private var reduceMotion: Bool { systemReduceMotion || still }

    private var balancing: Bool { progress >= 0.65 }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 6) {
                ForEach(0..<days, id: \.self) { index in
                    let built = progress >= Double(index + 1) / Double(max(days, 1)) * 0.9
                    let building = !built && (index == 0 || progress >= Double(index) / Double(max(days, 1)) * 0.9)
                    AIBuildCell(number: index + 1, built: built, building: building && shimmer)
                }
            }
            LookDivider()
            HStack(spacing: look.id.isPaperClub ? 6 : 2) {
                ForEach(Array(MuscleFamily.allCases.enumerated()), id: \.element) { index, family in
                    AIDelayedSticker(family: family, lit: balancing && families.contains(family),
                                     delay: reduceMotion ? 0 : Double(index) * 0.12)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .lookSurface(.panel)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { shimmer = true }
        }
        .accessibilityHidden(true)
    }
}

private struct AIBuildCell: View {
    var number: Int
    var built: Bool
    var building: Bool
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.aiStill) private var still

    private var reduceMotion: Bool { systemReduceMotion || still }
    @ScaledMetric(relativeTo: .title3) private var height: CGFloat = 46

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: look.id.isPaperClub ? height / 2 : (look.id == .anatomy ? 14 : 10),
                                     style: .continuous)
        Text("\(number)")
            .font(look.font.smallNumber)
            .foregroundStyle(built ? (look.id == .anatomy ? look.textPrimary : look.onDone) : look.textTertiary)
            .frame(maxWidth: .infinity, minHeight: height)
            .background {
                if built {
                    if look.id == .anatomy {
                        shape.fill(look.segmentFill)
                    } else {
                        shape.fill(look.done)
                    }
                } else {
                    shape.fill(look.id == .floodlight ? look.surfaceRaised : .clear)
                        .opacity(building ? 0.45 : 1)
                }
            }
            .overlay {
                if !built {
                    shape.strokeBorder(look.dash, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                } else if look.id == .anatomy {
                    shape.strokeBorder(look.textPrimary.opacity(0.35), lineWidth: 1)
                }
            }
            .scaleEffect(built || reduceMotion ? 1 : 0.96)
            .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.55), value: built)
    }
}

/// A family sticker that lights `delay` seconds after its `lit` input turns on.
private struct AIDelayedSticker: View {
    var family: MuscleFamily
    var lit: Bool
    var delay: Double
    @State private var shown: Bool?

    var body: some View {
        FamilySticker(family: family, lit: shown ?? lit, size: 40)
            .onChange(of: lit) { _, new in
                DispatchQueue.main.asyncAfter(deadline: .now() + (new ? delay : 0)) { shown = new }
            }
    }
}

// MARK: - Error

/// Generation failed. The ring the wait was drawn on stays, broken (dashed, unlit) with the
/// error glyph inside, so the failure reads in the same place as the progress did. Below: what
/// happened (big), what to do (small), and the request that failed. "Generate week" retries
/// (the prototype turns the failure switch off so the retry succeeds); "Back to preferences".
struct AIErrorStepView: View {
    var actions: AIFlowActions
    @Environment(Store.self) private var store
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .largeTitle) private var ringSize: CGFloat = 150

    var body: some View {
        ViewThatFits(in: .vertical) {
            content(compact: false)
            ScrollView { content(compact: true) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(look.ground.ignoresSafeArea())
        .safeAreaBar(edge: .top) { AITopBar(step: 2, divider: false, onCancel: actions.close) }
        .safeAreaBar(edge: .bottom) {
            AIBottomBar(fade: false) {
                AIPrimaryButton("Generate week", symbol: "sparkles", isEnabled: store.aiCanGenerate, action: actions.retry)
                Button("Back to preferences", action: actions.back)
                    .buttonStyle(.lookSecondary)
            }
        }
    }

    private func content(compact: Bool) -> some View {
        VStack(spacing: 22) {
            if !compact { Spacer(minLength: 12) }
            brokenRing
            // The real copy, split: what happened (big) · what to do (small). The displayed
            // second sentence drops "or continue manually": this screen offers no manual path.
            let parts = Self.split(store.ai.error ?? AISimulator.failureMessage)
            VStack(spacing: 8) {
                Text(parts.what)
                    .font(look.font.title2)
                    .foregroundStyle(look.textPrimary)
                if let next = parts.next {
                    Text(next)
                        .font(look.font.body)
                        .foregroundStyle(look.textSecondary)
                }
                Text(AIRequestLine.text(store: store))
                    .font(look.font.footnote)
                    .foregroundStyle(look.textSecondary)
                    .padding(.top, 10)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
            if !compact { Spacer(minLength: 12); Spacer(minLength: 0) }
        }
        .padding(.horizontal, look.space.margin + 8)
        .padding(.vertical, compact ? 24 : 0)
        .frame(maxWidth: .infinity)
    }

    private var brokenRing: some View {
        let side = min(ringSize, 200)
        let width = side * 0.06
        return ZStack {
            Circle()
                .strokeBorder(look.id.isPaperClub ? look.textSecondary : look.ringTrack,
                              style: StrokeStyle(lineWidth: width, lineCap: .round, dash: [width * 0.2, width * 1.6]))
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: side * 0.26, weight: .semibold))
                .foregroundStyle(look.textPrimary)
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)
    }

    /// "Could not reach OpenAI. Check your connection or continue manually." →
    /// ("Could not reach OpenAI.", "Check your connection.").
    static func split(_ message: String) -> (what: String, next: String?) {
        let shown = message.replacingOccurrences(of: " or continue manually.", with: ".")
        guard let range = shown.range(of: ". ") else { return (shown, nil) }
        return (String(shown[..<range.lowerBound]) + ".", String(shown[range.upperBound...]))
    }
}
