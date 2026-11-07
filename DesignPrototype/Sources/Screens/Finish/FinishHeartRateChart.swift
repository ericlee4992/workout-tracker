import SwiftUI

// PROTOTYPE — the receipt's heart-rate graph: one thin range bar per minute (A SPEC: 52 bars
// for the 52:10 Push Day; C SPEC §7 "one per minute"; Apple Fitness's lifting graph), all one
// width, lifting and cardio alike, each coloured by the zones it spans. The bars come straight
// from the data (`FinishHeartRateFixture`); nothing is reshaped here.

// MARK: - The chart

/// Thin floating range bars (low…high per minute), each split where it crosses a zone bound
/// and coloured by that zone. Labels: max / min trailing, start / end below. It draws in the
/// first time it is `revealed`: C a pen trace left to right (1 s), A the bars switching on
/// left to right like scoreboard bulbs (0.9 s), B each bar growing from its middle in a quick
/// left-to-right wave (0.8 s). Reduce Motion: drawn complete.
struct FinishHeartRateChart: View {
    var slots: [HRSlot]
    /// Lower bound in bpm of each zone, index 0 (Warm-up) … 5.
    var zoneBounds: [Int]
    var startLabel: String
    var endLabel: String
    var revealed: Bool
    var height: CGFloat = 150

    @State private var progress: Double
    @Environment(\.look) private var look
    @Environment(\.lookOnSlab) private var onSlab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .caption2) private var labelColumn: CGFloat = 30

    init(slots: [HRSlot], zoneBounds: [Int], startLabel: String, endLabel: String, revealed: Bool, height: CGFloat = 150) {
        self.slots = slots
        self.zoneBounds = zoneBounds
        self.startLabel = startLabel
        self.endLabel = endLabel
        self.revealed = revealed
        self.height = height
        _progress = State(initialValue: revealed ? 1 : 0)
    }

    private var range: ClosedRange<Int>? {
        guard let lo = slots.map(\.low).min(), let hi = slots.map(\.high).max() else { return nil }
        return lo...max(hi, lo + 1)
    }

    var body: some View {
        let labelColor = onSlab ? look.onSlabSecondary : look.textTertiary
        let labelFont = Font.system(.caption2, weight: .semibold).monospacedDigit()
        // AX sizes: the plot grows 1.25× and B keeps only the first time label (B SPEC §8).
        let plotHeight = typeSize.isAccessibilitySize ? height * 1.25 : height
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                EmptyView()
                    .modifier(FinishHRBars(slots: slots, zoneBounds: zoneBounds, progress: progress, look: look,
                                           barWidth: barWidth))
                    .frame(maxWidth: .infinity)
                    .frame(height: plotHeight)
                VStack(alignment: .trailing) {
                    Text(range.map { "\($0.upperBound)" } ?? "").fixedSize()
                    Spacer(minLength: 0)
                    Text(range.map { "\($0.lowerBound)" } ?? "").fixedSize()
                }
                .font(labelFont)
                .foregroundStyle(labelColor)
                .frame(minWidth: labelColumn, alignment: .trailing)
                .frame(height: plotHeight)
            }
            HStack {
                Text(startLabel)
                Spacer()
                if !(typeSize.isAccessibilitySize && look.id == .anatomy) { Text(endLabel) }
            }
            .font(labelFont)
            .foregroundStyle(labelColor)
            .lineLimit(1)
            .padding(.trailing, labelColumn + 8)
        }
        .onChange(of: revealed) { _, shown in
            guard shown else { progress = 0; return }
            if reduceMotion { progress = 1; return }
            withAnimation(animation) { progress = 1 }
        }
        .onAppear { if reduceMotion { progress = 1 } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Heart rate from \(range?.lowerBound ?? 0) to \(range?.upperBound ?? 0) beats per minute")
    }

    private var animation: Animation {
        switch look.id {
        case .floodlight: .linear(duration: 0.9)
        case .anatomy: .easeOut(duration: 0.8)
        case .paper, .carbon: .easeInOut(duration: 1)
        }
    }

    private var barWidth: CGFloat {
        switch look.id {
        case .floodlight: 3
        case .anatomy: 3.4
        case .paper, .carbon: 3
        }
    }
}

/// The bars, redrawn per animation frame (`progress` is animatable).
private struct FinishHRBars: ViewModifier, Animatable {
    var slots: [HRSlot]
    var zoneBounds: [Int]
    var progress: Double
    var look: Look
    var barWidth: CGFloat

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        Canvas { context, size in
            guard let lo = slots.map(\.low).min(), let hi = slots.map(\.high).max(), !slots.isEmpty else { return }
            let bottomValue = Double(lo) - 2, topValue = Double(max(hi, lo + 1)) + 2
            let span = max(1, topValue - bottomValue)
            let count = (slots.map(\.index).max() ?? 0) + 1
            let step = size.width / CGFloat(count)
            let width = min(barWidth, step * 0.72)
            func y(_ bpm: Double) -> CGFloat { size.height * CGFloat(1 - (bpm - bottomValue) / span) }
            for slot in slots {
                let fraction = (Double(slot.index) + 0.5) / Double(count)
                let x = (CGFloat(slot.index) + 0.5) * step - width / 2
                var top = y(Double(slot.high)), bottom = y(Double(slot.low))
                var lit = true
                switch look.id {
                case .paper, .carbon:
                    // Pen trace: nothing beyond the pen yet.
                    if fraction > progress { continue }
                case .floodlight:
                    // Bulbs: unlit (track colour) until the sweep passes.
                    lit = fraction <= progress
                case .anatomy:
                    // Grow from the middle, in a left-to-right wave.
                    let local = min(1, max(0, (progress * 1.5 - fraction * 0.5)))
                    let mid = (top + bottom) / 2, half = (bottom - top) / 2 * CGFloat(local)
                    guard local > 0 else { continue }
                    top = mid - half; bottom = mid + half
                }
                let rect = CGRect(x: x, y: top, width: width, height: max(width, bottom - top))
                let capsule = Path(roundedRect: rect, cornerRadius: width / 2)
                if !lit {
                    context.fill(capsule, with: .color(look.ringTrack))
                    continue
                }
                context.drawLayer { layer in
                    layer.clip(to: capsule)
                    for zone in HeartRateZone.allCases {
                        let lower = Double(zone.rawValue < zoneBounds.count ? zoneBounds[zone.rawValue] : 0)
                        let upper = zone.rawValue + 1 < zoneBounds.count ? Double(zoneBounds[zone.rawValue + 1]) : 1000
                        let segTop = max(rect.minY, y(upper)), segBottom = min(rect.maxY, y(lower))
                        guard segBottom > segTop else { continue }
                        layer.fill(Path(CGRect(x: x, y: segTop, width: width, height: segBottom - segTop)),
                                   with: .color(look.zone(zone)))
                    }
                }
            }
        }
    }
}
