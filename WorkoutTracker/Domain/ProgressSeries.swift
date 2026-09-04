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
    /// Enough to draw, with the count of DAYS so the UI can caveat a short series.
    case series(days: Int)
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

/// One chartable variation of an exercise: a snapshot load type plus a preset.
///
/// D36 keeps records per variation, so a chart must be per variation too —
/// pooling narrow- and wide-grip lets one set a record the other can never
/// beat, and draws a line describing neither. The load type is part of the key
/// for the same reason: after a D47 correction an exercise can hold history
/// under two different types, and they rank in opposite directions.
struct ProgressVariationKey: Hashable, Sendable {
    var loadType: LoadType
    var presetID: UUID?
}

enum ProgressSeriesMath {

    /// The variations present in history, with how many DAYS each has.
    ///
    /// The count drives which one a chart opens on: the variation the user has
    /// actually trained, rather than whichever the live exercise happens to
    /// name today.
    static func variations(
        in sets: [RecordSetInput], calendar: Calendar = .current
    ) -> [ProgressVariationKey: Int] {
        var days: [ProgressVariationKey: Set<Date>] = [:]
        for set in sets where RecordsMath.isEligible(set) {
            guard let completedAt = set.completedAt else { continue }
            let key = ProgressVariationKey(loadType: set.loadType, presetID: set.presetID)
            days[key, default: []].insert(calendar.startOfDay(for: completedAt))
        }
        return days.mapValues(\.count)
    }

    /// The variation a chart should open on: most days, ties broken by the one
    /// with no preset so a plain exercise is not shadowed by a variation with
    /// equal history.
    static func defaultVariation(
        in sets: [RecordSetInput], calendar: Calendar = .current
    ) -> ProgressVariationKey? {
        let counts = variations(in: sets, calendar: calendar)
        guard let most = counts.values.max() else { return nil }
        let tied = counts.filter { $0.value == most }.keys
        return tied.first { $0.presetID == nil } ?? tied.sorted {
            ($0.presetID?.uuidString ?? "") < ($1.presetID?.uuidString ?? "")
        }.first
    }

    /// Builds a per-exercise series from logged sets.
    ///
    /// Warmups are excluded by `RecordsMath.isEligible`, the same rule the
    /// records screen uses — not a second filter that could drift from it.
    static func series(
        for sets: [RecordSetInput],
        loadType: LoadType,
        /// The variation to chart. nil charts sets logged with no preset,
        /// which is a real group, not "all of them" (D36).
        presetID: UUID?,
        calendar: Calendar = .current
    ) -> ProgressSeries {
        // FILTER TO ONE CLASSIFICATION, then judge within it.
        //
        // codex-review 2 (critical): this used to accept whatever it was
        // handed, so a chart mixed every snapshot load type and every preset
        // for an exercise, and `outranks` then compared them using each
        // CANDIDATE's own direction. After a load-type correction, old weighted
        // sets were ranked as assistance; narrow- and wide-grip bests were
        // pooled, which D36 exists to prevent because one variation could then
        // set a record the other can never beat.
        //
        // The series is now scoped the way a record group is: one load type,
        // one preset.
        // `presetID` nil means "sets logged with NO preset" — its own group,
        // exactly as `RecordsMath.groupKeys` treats it. It is NOT a wildcard.
        //
        // It was written as one (`presetID == nil || …`), so a chart opened
        // without a preset pooled narrow- and wide-grip history into a single
        // line — the pooling D36 exists to forbid, and the opposite of what
        // this function's own caller documented. Contract and caller
        // disagreed; the caller won, silently.
        let eligible = sets
            .filter { $0.loadType == loadType }
            .filter { $0.presetID == presetID }
            .filter { RecordsMath.isEligible($0) }
        // Grouped by calendar DAY, which is not identical to "session": two
        // workouts in one day collapse to a point, and one workout spanning
        // midnight becomes two (codex-review 2). Day is still the right x-axis
        // for a progression chart — the naming is what was wrong, and
        // `ProgressConfidence` now says "days" rather than claiming sessions.
        let byDay = Dictionary(grouping: eligible) { set -> Date in
            calendar.startOfDay(for: set.completedAt ?? .distantPast)
        }

        let points = byDay.keys.sorted().compactMap { day -> ProgressPoint? in
            guard let daySets = byDay[day], !daySets.isEmpty else { return nil }
            // `outranks` owns the direction, so assisted ranks least-assistance
            // best without this file knowing why.
            let best: RecordSetInput
            if loadType == .bodyweight {
                // Most reps wins, matching `RecordsMath.mostRepsRecord`.
                best = daySets.dropFirst().reduce(daySets[0]) { incumbent, candidate in
                    (candidate.reps ?? 0) > (incumbent.reps ?? 0) ? candidate : incumbent
                }
            } else {
                best = daySets.dropFirst().reduce(daySets[0]) { incumbent, candidate in
                    RecordsMath.outranks(candidate, incumbent) ? candidate : incumbent
                }
            }
            // D20: plain bodyweight has no load, so its progression is MOST
            // REPS. Plotting `normalizedKg` — nil for bodyweight — drew an
            // empty chart under an axis labelled "Reps (kg)"
            // (codex-review 2, high).
            let plotted: Double? = loadType == .bodyweight
                ? best.reps.map(Double.init)
                : best.normalizedKg
            return ProgressPoint(
                date: day,
                bestKg: plotted,
                bestReps: best.reps,
                bestValue: best.weightValue,
                bestUnit: best.weightUnit,
                volumeKg: RecordsMath.totalVolumeKg(among: daySets),
                e1rmKg: RecordsMath.bestE1RM(among: daySets)?.e1RMKg)
        }

        return ProgressSeries(
            points: points,
            loadType: loadType,
            confidence: confidence(days: points.count))
    }

    static func confidence(days sessions: Int) -> ProgressConfidence {
        switch sessions {
        case 0: .empty
        case 1: .single
        default: .series(days: sessions)
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
