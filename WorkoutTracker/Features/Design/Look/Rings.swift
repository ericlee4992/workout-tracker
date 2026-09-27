import SwiftUI

// Rings. A counts with segments (one per set, lit like scoreboard bulbs; a continuous arc
// above 24 sets). B and C draw arcs. The finish status ring is each look's celebration:
// A lights family-coloured segments in sequence, B draws family arcs and lands a check,
// C thunks down a rotated rubber stamp with a dashed inner ring and a popping check.

/// An arc from `start` to `end` (fractions of a turn, 0 = 12 o'clock, clockwise).
struct RingArc: Shape {
    var start: Double
    var end: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(start, end) }
        set { start = newValue.first; end = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        path.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: radius,
                    startAngle: .degrees(start * 360 - 90), endAngle: .degrees(end * 360 - 90), clockwise: false)
        return path
    }
}

/// The check inside status rings (points in a unit square).
struct CheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.31, y: rect.minY + rect.height * 0.515))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.435, y: rect.minY + rect.height * 0.64))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.70, y: rect.minY + rect.height * 0.375))
        return p
    }
}

// MARK: - Sets ring (live header)

struct SetsRing: View {
    var done: Int
    var total: Int
    var size: CGFloat?
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let side = size ?? (look.id == .floodlight ? 34 : 28)
        Group {
            if look.motion.segmentedRings && total > 0 && total <= 24 {
                segmented(side)
            } else {
                arc(side)
            }
        }
        .frame(width: side, height: side)
        .accessibilityElement()
        .accessibilityLabel("\(done) of \(total) sets")
    }

    private func segmented(_ side: CGFloat) -> some View {
        let width = side * 0.1
        let gap = min(0.3, 0.012 * 24 / Double(max(total, 1))) // fraction of a segment left open
        return ZStack {
            ForEach(0..<total, id: \.self) { index in
                let step = 1.0 / Double(total)
                RingArc(start: Double(index) * step + step * gap / 2 + 0.004,
                        end: Double(index + 1) * step - step * gap / 2 - 0.004)
                    .stroke(index < done ? look.done : look.ringTrack, style: StrokeStyle(lineWidth: width, lineCap: .butt))
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: done)
            }
        }
        .padding(width / 2)
    }

    private func arc(_ side: CGFloat) -> some View {
        let width = side * 0.17
        let fraction = total > 0 ? min(1, Double(done) / Double(total)) : 0
        let color: Color = look.id == .floodlight ? look.done : look.textPrimary
        return ZStack {
            Circle().stroke(look.ringTrack, lineWidth: width)
            RingArc(start: 0, end: fraction)
                .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .butt))
                .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.85), value: fraction)
        }
        .padding(width / 2)
    }
}

/// "7/18 sets" beside its ring (the live header's trailing item).
struct SetsRingLabel: View {
    var done: Int
    var total: Int
    @Environment(\.look) private var look

    var body: some View {
        HStack(spacing: 7) {
            SetsRing(done: done, total: total)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(done)/\(total)")
                    .font(numberFont)
                    .foregroundStyle(look.textPrimary)
                    .contentTransition(.numericText(value: Double(done)))
                    .celebrate(done)
                Text("sets").font(look.font.subhead).foregroundStyle(look.textSecondary)
            }
            .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(done) of \(total) sets")
    }

    private var numberFont: Font {
        switch look.id {
        case .floodlight: Font.system(.headline, weight: .heavy).width(.expanded).monospacedDigit()
        case .paper, .carbon: Font.system(.headline, weight: .heavy).width(.expanded).monospacedDigit()
        }
    }
}

// MARK: - Finish status ring

struct FinishStatusRing: View {
    /// Working sets per family in workout order (e.g. chest 8, shoulders 10, arms 4).
    var segments: [FamilyCount]
    var size: CGFloat?
    @State private var drawn = false
    @State private var checkIn = false
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(segments: [FamilyCount], size: CGFloat? = nil) {
        self.segments = segments.filter { $0.sets > 0 }
        self.size = size
    }

    private var total: Int { segments.reduce(0) { $0 + $1.sets } }

    var body: some View {
        let side = size ?? (look.id == .floodlight ? 112 : 100)
        Group {
            switch look.id {
            case .floodlight: floodlight(side)
            case .paper, .carbon: stamp(side)
            }
        }
        .frame(width: side, height: side)
        .onAppear(perform: play)
        .sensoryFeedback(.success, trigger: checkIn) { _, new in new }
        .accessibilityElement()
        .accessibilityLabel("Workout saved, \(total) sets: " + segments.map { "\($0.sets) \($0.family.label.lowercased())" }.joined(separator: ", "))
    }

    /// How long the ring takes to draw before the check lands.
    private var drawDuration: Double {
        switch look.id {
        case .floodlight: Double(min(total, 24)) * 0.028 + 0.2
        case .paper, .carbon: 0.7
        }
    }

    private func play() {
        guard !drawn else { return }
        if reduceMotion { drawn = true; checkIn = true; return }
        drawn = true
        withAnimation(.spring(response: 0.32, dampingFraction: 0.55).delay(drawDuration * 0.95)) { checkIn = true }
    }

    /// Each set is one segment, lit in its family colour, in order (28 ms stagger).
    private func floodlight(_ side: CGFloat) -> some View {
        let width = side * 0.1
        let colors: [Color] = segments.flatMap { Array(repeating: look.family($0.family), count: $0.sets) }
        let count = colors.count
        return ZStack {
            if count <= 24 && count > 0 {
                ForEach(0..<count, id: \.self) { index in
                    let step = 1.0 / Double(count)
                    RingArc(start: Double(index) * step + step * 0.14, end: Double(index + 1) * step - step * 0.14)
                        .stroke(drawn ? colors[index] : look.ringTrack, style: StrokeStyle(lineWidth: width))
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.18).delay(Double(index) * 0.028), value: drawn)
                }
            } else {
                runs(width: width, cap: .butt, gap: 0.004)
            }
            CheckShape()
                .stroke(look.textPrimary, style: StrokeStyle(lineWidth: side * 0.065, lineCap: .round, lineJoin: .round))
                .scaleEffect(checkIn ? 1 : look.motion.stampScale)
                .rotationEffect(.degrees(checkIn ? 0 : look.motion.stampRotation))
                .opacity(checkIn ? 1 : 0)
        }
        .padding(width / 2)
    }

    /// Family-coloured runs around the ring, drawn family by family (Floodlight's > 24-set fallback).
    private func runs(width: CGFloat, cap: CGLineCap, gap: Double) -> some View {
        let fractions = segments.map { Double($0.sets) / Double(max(total, 1)) }
        let starts = fractions.indices.map { i in fractions[..<i].reduce(0, +) }
        return ZStack {
            ForEach(Array(segments.enumerated()), id: \.element.family) { index, segment in
                let start = starts[index] + gap / 2
                let end = max(start, starts[index] + fractions[index] - gap / 2)
                RingArc(start: start, end: drawn ? end : start)
                    .stroke(look.family(segment.family), style: StrokeStyle(lineWidth: width, lineCap: cap))
                    .opacity(drawn ? 1 : 0)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.7).delay(Double(index) * 0.25), value: drawn)
            }
        }
    }

    /// C: the rubber stamp, rotated −8°. The thick ink ring is the outermost edge (the sheet
    /// fill sits under it, never beyond it); a dashed ring runs just inside.
    private func stamp(_ side: CGFloat) -> some View {
        let ring = side * 0.045
        return ZStack {
            Circle().fill(look.surface).padding(ring / 2)
            RingArc(start: 0, end: drawn ? 1 : 0)
                .stroke(look.textPrimary, lineWidth: ring)
                .padding(ring / 2)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.7).delay(0.1), value: drawn)
            Circle()
                .stroke(look.textPrimary, style: StrokeStyle(lineWidth: side * 0.016, dash: [3, 3.2]))
                .padding(side * 0.096)
            CheckShape()
                .stroke(look.textPrimary, style: StrokeStyle(lineWidth: side * 0.08, lineCap: .round, lineJoin: .round))
                .scaleEffect(checkIn ? 1 : 0.01)
                .opacity(checkIn ? 1 : 0)
        }
        .scaleEffect(drawn || reduceMotion ? 1 : 1.45)
        .opacity(drawn || reduceMotion ? 1 : 0)
        .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.6), value: drawn)
        .rotationEffect(.degrees(-8))
    }
}

// MARK: - Rest ring

/// The draining rest ring with its hourglass. `progress` = remaining ÷ total.
/// A: Ultra, turning floodlight and beating in the final 10 s. B: pearl, throbbing at the end.
/// C: light cobalt on the ink slab.
struct RestRing: View {
    var progress: Double
    var isFinal = false
    var size: CGFloat?
    @Environment(\.look) private var look
    @Environment(\.lookOnSlab) private var onSlab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let side = size ?? (look.id.isPaperClub ? 58 : 56)
        let width = look.id.isPaperClub ? side * 0.103 : side * 0.09
        let color: Color = switch look.id {
        case .floodlight: isFinal ? look.done : look.live
        case .paper, .carbon: look.live
        }
        let track: Color = look.id.isPaperClub
            ? (onSlab ? look.onSlab.opacity(0.16) : look.ringTrack)
            : look.wash(0.12)
        let glyph: Color = switch look.id {
        case .floodlight: color
        case .paper, .carbon: onSlab ? look.onSlab : look.textPrimary
        }
        ZStack {
            Circle().stroke(track, lineWidth: width)
            RingArc(start: 0, end: max(0, min(1, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round))
                .animation(reduceMotion ? nil : .linear(duration: 1), value: progress)
            Image(systemName: "hourglass")
                .font(.system(size: side * 0.36, weight: .semibold))
                .foregroundStyle(glyph)
        }
        .padding(width / 2)
        .frame(width: side, height: side)
        .modifier(FinalBeat(active: isFinal && !reduceMotion, throb: false))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: isFinal)
        .accessibilityHidden(true)
    }
}

/// Final-10-s beat (A scale, B opacity throb, C none beyond the tick).
private struct FinalBeat: ViewModifier {
    var active: Bool
    var throb: Bool
    @Environment(\.look) private var look

    func body(content: Content) -> some View {
        if active && !look.id.isPaperClub {
            TimelineView(.animation) { context in
                let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1)
                let pulse = phase < 0.3 ? phase / 0.3 : max(0, 1 - (phase - 0.3) / 0.7)
                if throb {
                    content.opacity(1 - 0.55 * pulse)
                } else {
                    content.scaleEffect(1 + 0.08 * pulse)
                }
            }
        } else {
            content
        }
    }
}
