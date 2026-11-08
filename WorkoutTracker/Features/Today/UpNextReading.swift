import Foundation

// Soft redesign S5 (D77): Today's card and Train's leading card read the SAME up-next template (the S3 rule that both
// show one template stays): the learned order or the user's split (`UpNext`), with the day's "Not today" choice on top.

struct UpNextReading {
    var suggestion: UpNextSuggestion
    var template: WorkoutTemplate?
    var lastRun: Date?
    /// The day's "Not today" choice is in force.
    var isOverridden: Bool
    var split: MySplit

    /// - Parameters:
    ///   - finished: finished workouts (any order).
    ///   - splitData / overrideData: the UserDefaults values (`MySplitStore.key`, `UpNextOverride.key`).
    static func make(templates: [WorkoutTemplate], finished: [Workout], splitData: Data, overrideData: Data,
                     now: Date) -> UpNextReading {
        let named = templates.map { (id: $0.id, name: $0.name) }
        let runs = finished.compactMap { workout -> UpNext.Run? in
            guard !workout.isDeleted, workout.finishedAt != nil, let id = workout.sourceTemplateID else { return nil }
            return UpNext.Run(templateID: id, startedAt: workout.startedAt)
        }
        let split = MySplitStore.decode(splitData).pruned(to: Set(named.map(\.id)))
        let lastFinishedStart = finished.filter { !$0.isDeleted }.map(\.startedAt).max()
        let choice = UpNextOverride.decode(overrideData).flatMap {
            $0.isCurrent(now: now, lastFinishedStart: lastFinishedStart) ? $0 : nil
        }
        var suggestion = UpNext.suggestion(templates: named, runs: runs, split: split, now: now, skip: choice?.skip ?? 0)
        if let chosen = choice?.chosen, named.contains(where: { $0.id == chosen }) {
            suggestion = .template(chosen)
        }
        let template: WorkoutTemplate? = if case .template(let id) = suggestion {
            templates.first { $0.id == id }
        } else {
            nil
        }
        let lastRun = template.flatMap { chosen in runs.filter { $0.templateID == chosen.id }.map(\.startedAt).max() }
        return UpNextReading(suggestion: suggestion, template: template, lastRun: lastRun, isOverridden: choice != nil,
                             split: split)
    }
}
