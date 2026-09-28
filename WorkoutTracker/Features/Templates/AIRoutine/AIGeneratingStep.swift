import SwiftUI

/// A03 generating (Floodlight ticket 10, decision 1): the ring with the percentage, the stage line
/// ("Checking equipment at Iron Temple…"), then a board where the sessions fill in one by one and the
/// families light during "Balancing muscle families…". The stages are timed (the API reports no
/// progress) and hold at 90 % until the reply. Reduce Motion: no sweep or shimmer; text swaps.
struct AIGeneratingStep: View {
    var model: AIRoutineFlowModel
    var gymName: String?
    var families: Set<MuscleFamily>
    var onCancel: () -> Void
    @Environment(\.look) private var look

    var body: some View {
        ViewThatFits(in: .vertical) {
            content(compact: false)
            ScrollView { content(compact: true) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(look.ground.ignoresSafeArea())
        .safeAreaBar(edge: .top) { AITopBar(step: 2, progress: model.progress, divider: false, onCancel: onCancel) }
        .safeAreaBar(edge: .bottom) {
            AIBottomBar(fade: false) {
                Button("Back to preferences") { model.cancelGeneration() }
                    .buttonStyle(.lookSecondary)
                    .accessibilityIdentifier("routineStopGenerating")
            }
        }
    }

    private func content(compact: Bool) -> some View {
        VStack(spacing: 0) {
            if !compact { Spacer(minLength: 20) }
            instrument.padding(.top, compact ? 24 : 0)
            AIBuildBoard(progress: model.progress, days: model.days, families: families)
                .padding(.top, 20)
            if !compact { Spacer(minLength: 20) }
        }
        .padding(.horizontal, look.space.margin)
        .padding(.bottom, 16)
    }

    private var instrument: some View {
        VStack(spacing: 18) {
            AIProgressRing(progress: model.progress, isRunning: model.step == .generating)
            VStack(spacing: 6) {
                AIStageLine(text: model.progressText)
                Text(AIRoutineReadouts.requestLine(gymName: gymName, days: model.days, minutes: model.minutes,
                                                   omittingGymIn: model.progressText))
                    .font(look.font.footnote)
                    .foregroundStyle(look.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .accessibilityElement(children: .combine)
        }
        .foregroundStyle(look.textPrimary)
        .frame(maxWidth: .infinity)
    }
}

private struct AIStageLine: View {
    var text: String
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(text)
            .font(look.font.title3)
            .multilineTextAlignment(.center)
            .id(text)
            .transition(reduceMotion ? .opacity : .asymmetric(
                insertion: .offset(y: 10).combined(with: .opacity),
                removal: .offset(y: -10).combined(with: .opacity)))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: text)
            .accessibilityIdentifier("routineStage")
    }
}

// MARK: - Progress ring

/// The live ring: a bright glint sweeps the unfilled track while the request runs; the live-coloured
/// arc is the stage's progress.
struct AIProgressRing: View {
    var progress: Double
    var isRunning: Bool
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var sizeScaled: CGFloat = 188
    @ScaledMetric(relativeTo: .largeTitle) private var numberSize: CGFloat = 54

    var body: some View {
        let side = min(sizeScaled, 240)
        let width = side * 0.075
        ZStack {
            Circle().stroke(look.ringTrack, lineWidth: width)
            if isRunning && !reduceMotion {
                TimelineView(.animation) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    let span = max(0.08, 1 - progress)
                    let head = progress + (t / 1.6).truncatingRemainder(dividingBy: 1) * span
                    RingArc(start: max(progress, head - 0.12), end: head)
                        .stroke(AngularGradient(colors: [look.textPrimary.opacity(0), look.textPrimary.opacity(0.16)],
                                                center: .center,
                                                startAngle: .degrees(max(progress, head - 0.12) * 360 - 90),
                                                endAngle: .degrees(head * 360 - 90)),
                                style: StrokeStyle(lineWidth: width, lineCap: .round))
                }
            }
            RingArc(start: 0, end: max(0.001, min(1, progress)))
                .stroke(look.live, style: StrokeStyle(lineWidth: width, lineCap: .round))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.7), value: progress)
            VStack(spacing: 2) {
                Image(systemName: "sparkles")
                    .font(.system(.title3, weight: .semibold))
                    .foregroundStyle(look.textSecondary)
                    .symbolEffect(.pulse, options: .repeating, isActive: isRunning && !reduceMotion)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(Int((progress * 100).rounded()))")
                        .font(Font.system(size: numberSize, weight: .heavy).width(.expanded).monospacedDigit())
                        .foregroundStyle(look.textPrimary)
                        .contentTransition(.numericText(value: progress))
                        .animation(reduceMotion ? nil : .snappy, value: progress)
                    Text("%")
                        .font(.system(.title3, weight: .bold))
                        .foregroundStyle(look.textSecondary)
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
        .accessibilityIdentifier("routineProgress")
    }
}

// MARK: - Build board

/// The week taking shape: one cell per session (filled as progress passes it) and the five family
/// maps, lit one after another once the families are being balanced.
private struct AIBuildBoard: View {
    var progress: Double
    var days: Int
    var families: Set<MuscleFamily>
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shimmer = false

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
            HStack(spacing: 2) {
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .title3) private var height: CGFloat = 46

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        Text("\(number)")
            .font(look.font.smallNumber)
            .foregroundStyle(built ? look.onDone : look.textTertiary)
            .frame(maxWidth: .infinity, minHeight: height)
            .background {
                if built { shape.fill(look.done) } else { shape.fill(look.surfaceRaised).opacity(building ? 0.45 : 1) }
            }
            .overlay { if !built { shape.strokeBorder(look.dash, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])) } }
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

/// Generation failed. The ring the wait was drawn on stays, broken (dashed, unlit) with the error
/// glyph inside, so the failure reads where the progress did. Below: what happened (big), what to do
/// (small), and the request that failed. "Generate week" retries; "Back to preferences".
struct AIErrorStep: View {
    var model: AIRoutineFlowModel
    var gymName: String?
    var canRetry: Bool
    var onRetry: () -> Void
    var onCancel: () -> Void
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .largeTitle) private var ringSize: CGFloat = 150

    private var offline: Bool { (model.error ?? "").localizedCaseInsensitiveContains("reach") }

    var body: some View {
        ViewThatFits(in: .vertical) {
            content(compact: false)
            ScrollView { content(compact: true) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(look.ground.ignoresSafeArea())
        .safeAreaBar(edge: .top) { AITopBar(step: 2, divider: false, onCancel: onCancel) }
        .safeAreaBar(edge: .bottom) {
            AIBottomBar(fade: false) {
                AIPrimaryButton("Generate week", symbol: "sparkles", isEnabled: canRetry, identifier: "routineRetry",
                                disabledHint: "Allow sending routine details to OpenAI first.", action: onRetry)
                Button("Back to preferences") { model.back() }
                    .buttonStyle(.lookSecondary)
                    .accessibilityIdentifier("routineErrorBack")
            }
        }
    }

    private func content(compact: Bool) -> some View {
        VStack(spacing: 22) {
            if !compact { Spacer(minLength: 12) }
            brokenRing
            let parts = AIRoutineErrorText.split(model.error ?? "")
            VStack(spacing: 8) {
                Text(parts.what)
                    .font(look.font.title2)
                    .foregroundStyle(look.textPrimary)
                if let next = parts.next {
                    Text(next)
                        .font(look.font.body)
                        .foregroundStyle(look.textSecondary)
                }
                Text(AIRoutineReadouts.requestLine(gymName: gymName, days: model.days, minutes: model.minutes))
                    .font(look.font.footnote)
                    .foregroundStyle(look.textSecondary)
                    .padding(.top, 10)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("routineAIError")
            if !compact { Spacer(minLength: 12) }
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
                .strokeBorder(look.ringTrack, style: StrokeStyle(lineWidth: width, lineCap: .round, dash: [width * 0.2, width * 1.6]))
            // The network glyph only for the offline message; any other failure (an invalid reply,
            // a key problem) takes the plain warning.
            Image(systemName: offline ? "wifi.exclamationmark" : "exclamationmark.triangle")
                .font(.system(size: side * 0.26, weight: .semibold))
                .foregroundStyle(look.textPrimary)
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)
    }
}
