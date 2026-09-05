import Charts
import SwiftUI

/// Milestone 9, ticket 05 — the heart-rate graph, shared by the finish sheet
/// and History detail so the two never drift. Redrawn in the finish-graph
/// ticket 01 to the shape of Apple Fitness's workout detail, which the user
/// put beside the first cut and called messy.
///
/// The shape, and why each part is the way it is:
/// - One thin bar per display slot spanning that slot's LOW to HIGH bpm,
///   floating — nothing is drawn down to zero, because the heart never was
///   there. The first cut filled from 0 to the mean and 268 such bars fused
///   into a solid block.
/// - The y-axis is the series' own range, labelled only at its low and high
///   (the reference shows 75 and 159 at the right edge and nothing else); no
///   horizontal gridlines.
/// - Three faint separators carry the CLOCK time, as the reference does.
/// - The average sits under the plot in the bar colour. The dashed average
///   rule and its annotation over the bars are gone.
///
/// Says nothing at all when there is no series: a workout logged before the
/// series existed shows its aggregates and no chart, never an empty one. Gaps
/// are simply not drawn.
struct HeartRateSummarySection: View {
    let series: [Int]
    /// Per-bucket range beside the mean; empty for workouts folded before
    /// they existed, which then draw from their means (`displaySlots`).
    let low: [Int]
    let high: [Int]
    let intervalSeconds: Int
    /// The workout's real length. The last bucket is usually partial, and a
    /// 31 s workout must not be drawn or announced as 45 s (codex-review 05).
    let durationSeconds: Int
    /// For the clock labels on the x-axis.
    let startedAt: Date
    let averageBpm: Int?
    let maxBpm: Int?

    private var xEnd: Int {
        HeartRateSeriesMath.plotExtentSeconds(
            durationSeconds: durationSeconds, bucketCount: series.count, intervalSeconds: intervalSeconds)
    }

    private var slots: [HeartRateSeriesMath.DisplaySlot] {
        HeartRateSeriesMath.displaySlots(
            mean: series, low: low, high: high,
            intervalSeconds: intervalSeconds, durationSeconds: xEnd)
    }

    /// The bpm the bars actually span.
    private var drawnRange: ClosedRange<Int>? { HeartRateSeriesMath.range(of: slots) }

    /// The plot's vertical extent: the drawn range with a little air above
    /// and below so the extreme bars do not touch the frame. Never 0…220.
    private func yDomain(_ range: ClosedRange<Int>) -> ClosedRange<Double> {
        let pad = Double(max(4, (range.upperBound - range.lowerBound) / 8))
        return (Double(range.lowerBound) - pad)...(Double(range.upperBound) + pad)
    }

    /// Clock time at the start and at thirds, like the reference (18:29,
    /// 18:48, 19:07). The end is not labelled: its label would run off the
    /// plot's right edge.
    private var timeTicks: [Double] {
        [0, Double(xEnd) / 3, Double(xEnd) * 2 / 3]
    }

    var body: some View {
        if let drawnRange, !slots.isEmpty {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    chart(drawnRange)
                        .frame(height: 160)
                        .accessibilityIdentifier("heartRateChart")
                        .accessibilityLabel(accessibilitySummary)
                    if let averageBpm {
                        Text("\(averageBpm) BPM AVG")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.red)
                            .monospacedDigit()
                            .accessibilityIdentifier("heartRateAverageCaption")
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Heart rate")
            }
        }
    }

    private func chart(_ range: ClosedRange<Int>) -> some View {
        Chart {
            ForEach(slots) { slot in
                // A rectangle spanning the slot's range, inset so bars have
                // air between them (a BarMark on a quantitative x-axis draws
                // no width at all — the milestone-9 lesson). Half a bpm of
                // ink at each end so a flat slot is a visible tick rather
                // than a zero-height nothing; the axis is labelled only at
                // the extremes, so that ink claims no number.
                let inset = Double(slot.endSeconds - slot.startSeconds) * 0.3
                RectangleMark(
                    xStart: .value("From", Double(slot.startSeconds) + inset),
                    xEnd: .value("To", Double(slot.endSeconds) - inset),
                    yStart: .value("Low", Double(slot.low) - 0.5),
                    yEnd: .value("High", Double(slot.high) + 0.5))
                .foregroundStyle(Color.red)
                .cornerRadius(1)
            }
        }
        .chartYScale(domain: yDomain(range))
        .chartXScale(domain: 0...Double(xEnd))
        .chartXAxis {
            AxisMarks(values: timeTicks) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                    .foregroundStyle(.quaternary)
                AxisValueLabel(anchor: .topLeading) {
                    if let seconds = value.as(Double.self) {
                        Text(clockLabel(elapsed: seconds))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartYAxis {
            // Exactly two numbers, at the drawn extremes, and no gridlines.
            AxisMarks(position: .trailing, values: [Double(range.lowerBound), Double(range.upperBound)]) { value in
                AxisValueLabel {
                    if let bpm = value.as(Double.self) {
                        Text("\(Int(bpm))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
        }
    }

    private func clockLabel(elapsed seconds: Double) -> String {
        startedAt.addingTimeInterval(seconds)
            .formatted(date: .omitted, time: .shortened)
    }

    private var accessibilitySummary: String {
        var parts = ["Heart rate over \(Format.duration(seconds: xEnd))"]
        if let averageBpm { parts.append("average \(averageBpm) BPM") }
        if let maxBpm { parts.append("maximum \(maxBpm) BPM") }
        return parts.joined(separator: ", ")
    }
}
