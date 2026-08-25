import Foundation

// Milestone 8, ticket 01 — the numbers behind the progress charts.
//
// Pure logic, no SwiftUI, so the series can be proven without rendering
// anything. A chart that "looked right on my machine" is exactly what this
// project's process refuses; and a second, parallel implementation of best-set
// or volume that can drift from `RecordsMath` would eventually draw a picture
// disagreeing with the records screen. So every judgement here — eligibility,
// ranking direction, volume — delegates to `RecordsMath`.

/// One session's worth of a single exercise, reduced to what a chart plots.
struct ProgressPoint: Equatable, Identifiable {
    var id: Date { date }
    /// The session's date, normalized to its day so points land on an axis.
    let date: Date
    /// Best set that day, in canonical kg — direction already resolved for the
    /// load type (assisted: least assistance).
    let bestKg: Double?
    /// Reps of that best set, for the tooltip.
    let bestReps: Int?
    /// As entered, so the tooltip can show the number the user actually typed
    /// rather than a converted one (D9/D25).
    let bestValue: Double?
    let bestUnit: WeightUnit?
    /// Weighted-only, per `RecordsMath.totalVolumeKg`. Zero for load types
    /// where "volume lifted" is not a meaningful quantity.
    let volumeKg: Double
    /// Best Brzycki estimate that day, weighted only (D20). nil elsewhere.
    let e1rmKg: Double?
}

/// What a chart is allowed to claim about a series.
///
/// Two points are not a trend. Drawing a line between them and letting the eye
/// read a slope is the same false precision D9/D25 mark with `≈` — one domain
/// over, and easier to believe because it looks like maths.
enum ProgressConfidence: Equatable {
    case empty
    /// One session. Render the point, never a line.
    case single
    /// Enough to draw, with the count so the UI can caveat a short series.
    case series(sessions: Int)
}

struct ProgressSeries: Equatable {
    let points: [ProgressPoint]
    let loadType: LoadType
    let confidence: ProgressConfidence

    /// True when a HIGHER value means a better set. False for assisted, where
    /// less assistance is the improvement — a chart that draws that as decline
    /// is worse than no chart at all.
    var higherIsBetter: Bool { loadType != .assisted }

    /// What the load axis is actually measuring, so the direction is
    /// unmistakable on screen.
    var loadAxisLabel: String {
        switch loadType {
        case .assisted: "Assistance (less is better)"
        case .bodyweight: "Reps"
        case .bodyweightPlus: "Added weight"
        case .weighted: "Weight"
        }
    }
}

enum ProgressSeriesMath {

    /// Builds a per-exercise series from logged sets.
    ///
    /// Warmups are excluded by `RecordsMath.isEligible`, the same rule the
    /// records screen uses — not a second filter that could drift from it.
    static func series(
        for sets: [RecordSetInput],
        loadType: LoadType,
        calendar: Calendar = .current
    ) -> ProgressSeries {
        let eligible = sets.filter { RecordsMath.isEligible($0) }
        let byDay = Dictionary(grouping: eligible) { set -> Date in
            calendar.startOfDay(for: set.completedAt ?? .distantPast)
        }

        let points = byDay.keys.sorted().compactMap { day -> ProgressPoint? in
            guard let daySets = byDay[day], !daySets.isEmpty else { return nil }
            // `outranks` owns the direction, so assisted ranks least-assistance
            // best without this file knowing why.
            let best = daySets.dropFirst().reduce(daySets[0]) { incumbent, candidate in
                RecordsMath.outranks(candidate, incumbent) ? candidate : incumbent
            }
            return ProgressPoint(
                date: day,
                bestKg: best.normalizedKg,
                bestReps: best.reps,
                bestValue: best.weightValue,
                bestUnit: best.weightUnit,
                volumeKg: RecordsMath.totalVolumeKg(among: daySets),
                e1rmKg: RecordsMath.bestE1RM(among: daySets)?.e1RMKg)
        }

        return ProgressSeries(
            points: points,
            loadType: loadType,
            confidence: confidence(sessions: points.count))
    }

    static func confidence(sessions: Int) -> ProgressConfidence {
        switch sessions {
        case 0: .empty
        case 1: .single
        default: .series(sessions: sessions)
        }
    }

    /// Change between the first and last point of a series, as a fraction.
    ///
    /// Returns nil for a series too short to have a direction, and nil when the
    /// baseline is zero — a "percentage improvement" over nothing is a division
    /// the app would be inventing.
    static func change(_ series: ProgressSeries) -> Double? {
        guard case .series = series.confidence,
              let first = series.points.first?.bestKg,
              let last = series.points.last?.bestKg,
              first != 0
        else { return nil }
        let raw = (last - first) / abs(first)
        // Assisted improves DOWNWARD, so a drop in assistance is progress.
        return series.higherIsBetter ? raw : -raw
    }
}
