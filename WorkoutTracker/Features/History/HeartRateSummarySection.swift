import Charts
import SwiftUI

/// Milestone 9, ticket 05 — the heart-rate graph, shared by the finish sheet
/// and History detail so the two never drift.
///
/// Draws `HeartRateSeriesMath.points` as bars over elapsed time, the average
/// as a rule, and says nothing at all when there is no series: a workout
/// logged before the series existed shows its aggregates and no chart, never
/// an empty one. Gaps (0 buckets) are simply not drawn.
struct HeartRateSummarySection: View {
    let series: [Int]
    let intervalSeconds: Int
    /// The workout's real length. The last bucket is usually partial, and a
    /// 31 s workout must not be drawn or announced as 45 s (codex-review 05).
    let durationSeconds: Int
    let averageBpm: Int?
    let maxBpm: Int?

    private var xEnd: Int { max(1, min(durationSeconds, series.count * intervalSeconds)) }

    private var points: [HeartRateSeriesMath.Point] {
        HeartRateSeriesMath.points(from: series, intervalSeconds: intervalSeconds)
    }

    /// Top of the axis: the recorded maximum (or the series' own), with a
    /// little headroom, so the shape fills the chart rather than hugging
    /// the bottom of a 0–220 range.
    private var yTop: Int {
        let observed = max(maxBpm ?? 0, points.map(\.bpm).max() ?? 0)
        return max(60, ((observed + 10) / 10) * 10)
    }

    var body: some View {
        if !points.isEmpty {
            Section {
                Chart {
                    // A rectangle spanning the bucket, not a BarMark: on a
                    // quantitative x-axis a BarMark's width collapses to
                    // nothing (the first build drew axes and no bars), and a
                    // span IS what a 15 s average describes.
                    ForEach(points) { point in
                        RectangleMark(
                            xStart: .value("From", point.elapsedSeconds),
                            xEnd: .value("To", min(point.elapsedSeconds + intervalSeconds, xEnd)),
                            yStart: .value("Rest", 0),
                            yEnd: .value("BPM", point.bpm))
                        .foregroundStyle(Color.red.gradient)
                        .cornerRadius(2)
                    }
                    if let averageBpm {
                        RuleMark(y: .value("Average", averageBpm))
                            .foregroundStyle(.secondary.opacity(0.7))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                            .annotation(position: .top, alignment: .trailing) {
                                Text("avg \(averageBpm)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                .chartYScale(domain: 0...yTop)
                .chartXScale(domain: 0...xEnd)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let seconds = value.as(Int.self) {
                                Text(Format.duration(seconds: seconds))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 4))
                }
                .frame(height: 180)
                .accessibilityIdentifier("heartRateChart")
                .accessibilityLabel(accessibilitySummary)
            } header: {
                Text("Heart rate")
            }
        }
    }

    private var accessibilitySummary: String {
        var parts = ["Heart rate over \(Format.duration(seconds: xEnd))"]
        if let averageBpm { parts.append("average \(averageBpm) BPM") }
        if let maxBpm { parts.append("maximum \(maxBpm) BPM") }
        return parts.joined(separator: ", ")
    }
}
