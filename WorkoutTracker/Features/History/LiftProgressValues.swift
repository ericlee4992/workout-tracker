import Foundation
import SwiftData

/// One lifting metric's numbers for a variation: what the chart plots, the text the user typed, the change since the
/// first session. Shared by `ExerciseProgressView` and the Progress tab's panels (ticket 16), so a pinned chart and
/// the exercise's own chart cannot draw different pictures of the same history.
struct LiftProgressValues {
    let metric: ExerciseProgressView.Metric
    let loadType: LoadType
    let displayUnit: WeightUnit

    /// The app's default weight unit (D2/T7 precedence, app level).
    ///
    /// Reported 2026-08-26: a chart of lb-logged sets plotted in kg. The series is computed in canonical kg so
    /// mixed-unit sessions share one axis (D25), but the AXIS should read in the unit the user thinks in.
    static func displayUnit(in context: ModelContext) -> WeightUnit {
        displayUnit(preferences: (try? context.fetch(FetchDescriptor<AppPreferences>())) ?? [])
    }

    /// The same, from preferences a view already queried (no fetch per render).
    static func displayUnit(preferences rows: [AppPreferences]) -> WeightUnit {
        UnitPrecedence.defaultUnit(
            machineUnit: nil, gymUnit: nil,
            appPreference: AppPreferences.canonical(of: rows)?.unitPreference)
    }

    /// Volume and e1RM are weighted-only concepts (D20, `RecordsMath`). Offering them for an assisted movement would
    /// draw a flat zero line and invite the user to read meaning into it.
    var availableMetrics: [ExerciseProgressView.Metric] {
        loadType == .weighted ? ExerciseProgressView.Metric.allCases : [.bestSet]
    }

    func plotted(_ point: ProgressPoint) -> Double? {
        let convert = { WeightMath.convert($0, from: .kg, to: displayUnit) }
        switch metric {
        case .bestSet:
            // Bodyweight plots REPS, which have no unit to convert.
            return loadType == .bodyweight ? point.bestKg : point.bestKg.map(convert)
        case .volume: return convert(point.volumeKg)
        case .e1rm: return point.e1rmKg.map(convert)
        }
    }

    /// Since the first session, for this metric. Best set: the Domain's rule (assisted improves downward). Volume and
    /// 1RM are weighted only, where more is better.
    func change(_ series: ProgressSeries) -> Double? {
        switch metric {
        case .bestSet: return ProgressSeriesMath.change(series)
        case .volume:
            return ProgressSeriesMath.change(first: series.points.first?.volumeKg, last: series.points.last?.volumeKg)
        case .e1rm:
            return ProgressSeriesMath.change(first: series.points.first?.e1rmKg, last: series.points.last?.e1rmKg)
        }
    }

    /// D9/D25: show the number the user typed. The chart plots canonical kg so mixed-unit sessions share an axis, but
    /// the text says what was entered.
    func asEntered(_ point: ProgressPoint) -> String {
        // Plain bodyweight has no load to show — reps ARE the achievement.
        if loadType == .bodyweight {
            return point.bestReps.map { "\($0) reps" } ?? "—"
        }
        guard let value = point.bestValue, let unit = point.bestUnit else { return "—" }
        let reps = point.bestReps.map { " × \($0)" } ?? ""
        return "\(Format.weight(value)) \(unit.rawValue)\(reps)"
    }

    /// The metric being viewed. Best set is the number the user typed; volume and 1RM are in the display unit, plain
    /// (D52 — the point still records which units its contributors were entered in).
    func calloutValue(_ point: ProgressPoint) -> String {
        switch metric {
        case .bestSet:
            return asEntered(point)
        case .volume:
            return WeightMath.displayLabel(kilograms: point.volumeKg, in: displayUnit)
        case .e1rm:
            guard let kg = point.e1rmKg else { return "—" }
            return WeightMath.displayLabel(kilograms: kg, in: displayUnit)
        }
    }
}
