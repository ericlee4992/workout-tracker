import SwiftUI

// PROTOTYPE — the kept receipt top: status ring + "Workout saved" + summary line.
// A: 112 pt family-coloured segment ring at leading; the headline wraps to two lines, then
//    "Push Day · Iron Temple", "5 exercises · 22 sets" and the ring's key — each family's map
//    with its set count in the family colour (the counts the 22 segments add up to).
// B: a status card, 96 pt family arcs at leading, "Workout saved" and the summary beside it.
// C: the rubber stamp at leading, "Push Day" eyebrow over the serif headline and summary.
// AX: A and C put the ring above the text; B keeps it at leading (120 pt) until AX3 — except
// "Nothing to save", which stacks at every AX size (its sentence needs the width).
// Before the reveal the ring slot shows its resting state (A unlit segments, B the track,
// C the dashed unstamped outline), so it never reads as a hole.
// A mixed session (lifting + cardio) in A and B: the family ring sits inside a thin arc in
// the heart-rate colour whose length is the cardio's share of the workout time (19:30 of
// 1:13:10), drawn after the ring. C's stamp carries no data (it is the "saved" mark), so it
// stays as it is; the summary line names the cardio in every look.

struct FinishStatusHeader: View {
    let data: FinishData
    /// The ring is inserted when the reveal starts (so it draws once the sheet has landed).
    let ringShown: Bool
    /// Changing it re-creates the ring, which plays its celebration again.
    let replayID: Int
    var onReplay: () -> Void = {}

    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .subheadline) private var keySize: CGFloat = 36

    private var saved: Bool { data.summary.saved }

    var body: some View {
        Group {
            if look.id == .anatomy {
                layout
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lookSurface(.card)
            } else {
                layout.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var stacked: Bool {
        guard look.id == .anatomy, saved else { return typeSize.isAccessibilitySize }
        return typeSize >= .accessibility3
    }

    private var layout: some View {
        let layout = stacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
            : AnyLayout(HStackLayout(alignment: .center, spacing: look.id == .anatomy ? 18 : 16))
        return layout {
            ring
            textBlock
        }
    }

    // MARK: Ring

    private var ringSide: CGFloat {
        switch look.id {
        case .floodlight: 112
        case .anatomy: typeSize.isAccessibilitySize ? 120 : 96
        case .paper, .carbon: 100
        }
    }

    private var segmentCount: Int { data.allSetsByFamily.reduce(0) { $0 + $1.sets } }

    /// A and B: the lifting ring shares the hero with the cardio arc around it.
    private var hasCardioArc: Bool {
        saved && !look.id.isPaperClub && data.cardioSeconds > 0 && !data.allSetsByFamily.isEmpty
    }

    private var cardioFraction: Double {
        min(1, Double(data.cardioSeconds) / Double(max(1, data.summary.durationSeconds)))
    }

    @ViewBuilder private var ring: some View {
        let side = ringSide
        let inner = hasCardioArc ? (side * 0.8).rounded() : side
        ZStack {
            if !saved {
                FinishEmptyRing(size: side)
            } else {
                if hasCardioArc {
                    FinishCardioArc(fraction: cardioFraction, size: side, drawn: ringShown)
                        .id(replayID)
                }
                // The resting ring; C's outline lifts off as the stamp comes down.
                FinishRingRest(size: inner, segments: data.allSetsByFamily.isEmpty ? 0 : segmentCount)
                    .opacity(look.id.isPaperClub && ringShown ? 0 : 1)
                    .animation(.easeOut(duration: 0.25).delay(0.12), value: ringShown)
                if ringShown { savedRing(inner).id(replayID) }
            }
        }
        .frame(width: side, height: side)
        .contentShape(Circle())
        .onTapGesture { if saved { onReplay() } }
        .accessibilityElement(children: .combine)
        .accessibilityValue(hasCardioArc ? data.cardio.map { "\($0.activity.name), \(Format.elapsed($0.activeSeconds))" }.joined(separator: ", ") : "")
        .accessibilityAction(named: "Replay") { if saved { onReplay() } }
    }

    @ViewBuilder private func savedRing(_ side: CGFloat) -> some View {
        let families = look.id == .floodlight ? data.allSetsByFamily : data.workingSetsByFamily
        if look.id.isPaperClub {
            FinishRubberStamp(size: side, setCount: data.summary.setCount)
        } else if !families.isEmpty {
            FinishStatusRing(segments: families, size: side)
        } else {
            FinishZoneRing(zoneSeconds: data.zoneSeconds, size: side)
        }
    }

    // MARK: Text

    @ViewBuilder private var textBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            if saved {
                switch look.id {
                case .floodlight: floodlightText
                case .anatomy: anatomyText
                case .paper, .carbon: paperText
                }
            } else {
                headline("Nothing to save")
                Text(data.summary.summaryLine)
                    .font(look.font.subhead)
                    .foregroundStyle(look.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func headline(_ text: String) -> some View {
        Text(text)
            .font(look.font.title)
            .foregroundStyle(look.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    /// A SPEC §10: "Push Day · Iron Temple", then "5 exercises · 22 sets", then the key.
    @ViewBuilder private var floodlightText: some View {
        headline("Workout saved")
        FinishFlowLine(parts: [data.summary.title, data.summary.gymName].compactMap { $0 })
            .font(.system(.subheadline, weight: .semibold))
            .foregroundStyle(look.textPrimary)
            .padding(.top, 2)
        if !countParts.isEmpty {
            FinishFlowLine(parts: countParts)
                .font(look.font.caption)
                .foregroundStyle(look.textSecondary)
        }
        if !data.allSetsByFamily.isEmpty {
            floodlightKey.padding(.top, 8)
        }
    }

    /// The ring's key: each family's map with the number of segments it lit, in ring order
    /// and in the family colour (8 + 10 + 4 = the 22 segments), then the cardio arc's time in
    /// the heart-rate colour. Wraps (never truncates) at large sizes.
    private var floodlightKey: some View {
        let size = min(keySize, 46)
        return FinishFlowLayout(spacing: 12, lineSpacing: 6, separators: false) {
            ForEach(data.allSetsByFamily) { count in
                HStack(alignment: .center, spacing: 3) {
                    MuscleMap(family: count.family, lit: true, size: size)
                    Text("\(count.sets)")
                        .font(Font.system(.headline, weight: .heavy).width(.expanded).monospacedDigit())
                        .foregroundStyle(look.family(count.family))
                        .fixedSize()
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(count.family.label), \(Format.count(count.sets, "set"))")
            }
            if hasCardioArc {
                HStack(alignment: .center, spacing: 4) {
                    Image(systemName: data.cardio.first?.activity.symbol ?? "figure.run")
                        .font(.system(.body, weight: .bold))
                        .frame(width: size * 0.7, height: size)
                    Text(Format.elapsed(data.cardioSeconds))
                        .font(Font.system(.headline, weight: .heavy).width(.expanded).monospacedDigit())
                        .fixedSize()
                }
                .foregroundStyle(look.heartRate)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Cardio, \(Format.elapsed(data.cardioSeconds))")
            }
        }
    }

    @ViewBuilder private var anatomyText: some View {
        headline("Workout saved")
        summaryText
    }

    @ViewBuilder private var paperText: some View {
        Text(data.summary.title)
            .font(.system(.subheadline, weight: .semibold))
            .foregroundStyle(look.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        headline("Workout saved")
        summaryText
    }

    /// The kept summary line ("5 exercises · 22 sets · Iron Temple"); it wraps only between
    /// its parts and drops the "·" at a wrap, so no line starts or ends with one.
    private var summaryText: some View {
        FinishFlowLine(parts: countParts + [data.summary.gymName].compactMap { $0 })
            .font(look.font.subhead)
            .foregroundStyle(look.textSecondary)
    }

    private var countParts: [String] {
        var parts: [String] = []
        let s = data.summary
        if s.setCount > 0 {
            parts.append(Format.count(s.exerciseCount, "exercise"))
            parts.append(Format.count(s.setCount, "set"))
        }
        if !s.cardio.isEmpty { parts.append(Format.count(s.cardio.count, "cardio activity", "cardio activities")) }
        return parts
    }
}

// MARK: - C's rubber stamp

/// C's status: a rubber stamp that thunks down. A thick ink ring (with the small gaps of a
/// real stamp's worn rubber), a thinner ring doubled just inside it and printed a hair off
/// register, and a heavy check that breaks out past the rings at the top right, knocked out
/// of the ink where it crosses. Tilted −8°: the check and the broken ring make the tilt read.
/// Motion: the stamp drops from 1.5× (−16°) and overshoots (0.93×, 1.02×, 1×) as the ring
/// inks round; the check pops in last with the success haptic. Reduce Motion: stamped.
struct FinishRubberStamp: View {
    var size: CGFloat
    var setCount: Int

    @State private var landed = false
    @State private var checkIn = false
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let ink = look.textPrimary
        let paper = look.surface
        let outer = size * 0.05
        ZStack {
            Circle().fill(paper).padding(outer / 2)
            // Outer ring, inked round as the stamp lands; worn gaps in the rubber.
            RingArc(start: 0, end: landed ? 1 : 0)
                .stroke(ink, style: StrokeStyle(lineWidth: outer, lineCap: .butt,
                                                dash: [size * 0.62, size * 0.018, size * 0.9, size * 0.012, size * 0.45, size * 0.02]))
                .padding(outer / 2)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.55).delay(0.08), value: landed)
            // The doubled inner ring, a hair off register.
            Circle()
                .stroke(ink, lineWidth: size * 0.018)
                .padding(size * 0.105)
                .offset(x: size * 0.008, y: -size * 0.006)
            Circle()
                .stroke(ink.opacity(0.55), style: StrokeStyle(lineWidth: size * 0.011, dash: [2.4, 2.6]))
                .padding(size * 0.15)
            // The check breaks out past the rings (top right), knocked out where it crosses.
            FinishStampCheck()
                .stroke(paper, style: StrokeStyle(lineWidth: size * 0.17, lineCap: .round, lineJoin: .round))
                .scaleEffect(checkIn ? 1 : 0.2)
                .opacity(checkIn ? 1 : 0)
            FinishStampCheck()
                .stroke(ink, style: StrokeStyle(lineWidth: size * 0.095, lineCap: .round, lineJoin: .round))
                .scaleEffect(checkIn ? 1 : 0.2)
                .opacity(checkIn ? 1 : 0)
        }
        .frame(width: size, height: size)
        // The pose rests at "stamped"; the thunk plays once when `landed` flips.
        .keyframeAnimator(initialValue: FinishStampPose.stamped, trigger: landed && !reduceMotion) { view, pose in
            view.scaleEffect(pose.scale).rotationEffect(.degrees(pose.rotation)).opacity(pose.opacity)
        } keyframes: { _ in
            KeyframeTrack(\.scale) {
                LinearKeyframe(1.5, duration: 0.01)
                CubicKeyframe(0.93, duration: 0.2)
                SpringKeyframe(1.02, duration: 0.14, spring: .snappy)
                SpringKeyframe(1, duration: 0.2, spring: .smooth)
            }
            KeyframeTrack(\.rotation) {
                LinearKeyframe(-16, duration: 0.01)
                CubicKeyframe(-8, duration: 0.24)
            }
            KeyframeTrack(\.opacity) {
                LinearKeyframe(0, duration: 0.01)
                LinearKeyframe(1, duration: 0.1)
            }
        }
        .opacity(landed ? 1 : 0)
        .onAppear {
            if reduceMotion { landed = true; checkIn = true; return }
            landed = true
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5).delay(0.62)) { checkIn = true }
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: landed) { _, new in new }
        .sensoryFeedback(.success, trigger: checkIn) { _, new in new }
        .accessibilityElement()
        .accessibilityLabel("Workout saved, \(Format.count(setCount, "set"))")
    }
}

private struct FinishStampPose {
    var scale: CGFloat
    var rotation: Double
    var opacity: Double
    static let stamped = FinishStampPose(scale: 1, rotation: -8, opacity: 1)
}

/// The stamp's check: a short arm and a long arm that runs out past the rings.
private struct FinishStampCheck: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.27, y: rect.minY + rect.height * 0.52))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.43, y: rect.minY + rect.height * 0.68))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.86, y: rect.minY + rect.height * 0.15))
        return p
    }
}

// MARK: - A and B: the cardio arc

/// A thin arc around the lifting ring in the heart-rate colour: the cardio's share of the
/// workout time, from 12 o'clock, over a faint track. It draws after the ring's first
/// segments (0.6 s); Reduce Motion: drawn.
struct FinishCardioArc: View {
    var fraction: Double
    var size: CGFloat
    /// The reveal has started (false = the resting track only).
    var drawn: Bool

    @State private var progress: Double = 0
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let width = size * 0.055
        ZStack {
            Circle().stroke(look.ringTrack, lineWidth: width)
            RingArc(start: 0, end: fraction * progress)
                .stroke(look.heartRate, style: StrokeStyle(lineWidth: width, lineCap: .round))
        }
        .padding(width / 2)
        .frame(width: size, height: size)
        .onAppear { if drawn { play() } }
        .onChange(of: drawn) { _, on in if on { play() } else { progress = 0 } }
        .accessibilityHidden(true)
    }

    private func play() {
        guard !reduceMotion else { progress = 1; return }
        withAnimation(.easeOut(duration: 0.6).delay(0.45)) { progress = 1 }
    }
}
