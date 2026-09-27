import Foundation

/// A template's use, derived from finished workouts that started from it (`sourceTemplateID`):
/// the tile's "Last run" and the detail's "Times run" / "Avg. time" (Floodlight redesign).
/// Derived on read, never stored.
struct TemplateStats: Equatable {
    var timesRun: Int
    var lastRun: Date?
    var averageDurationSeconds: Int?

    static let none = TemplateStats(timesRun: 0, lastRun: nil, averageDurationSeconds: nil)

    /// `runs`: (start, duration) of each FINISHED workout started from the template.
    static func make(runs: [(startedAt: Date, durationSeconds: Int)]) -> TemplateStats {
        guard !runs.isEmpty else { return .none }
        let total = runs.reduce(0) { $0 + $1.durationSeconds }
        return TemplateStats(timesRun: runs.count, lastRun: runs.map(\.startedAt).max(),
                             averageDurationSeconds: total / runs.count)
    }

    /// Stats for every template id at once, from the finished workouts.
    static func byTemplate(_ workouts: [Workout]) -> [UUID: TemplateStats] {
        var runs: [UUID: [(startedAt: Date, durationSeconds: Int)]] = [:]
        for workout in workouts {
            guard let id = workout.sourceTemplateID, let duration = workout.duration else { continue }
            runs[id, default: []].append((workout.startedAt, Int(duration)))
        }
        return runs.mapValues(make(runs:))
    }
}
