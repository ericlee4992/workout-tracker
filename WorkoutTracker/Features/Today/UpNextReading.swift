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
    /// The choice in force (for the menu to continue from), nil when none.
    var activeOverride: UpNextOverride?

    /// - Parameters:
    ///   - finished: finished workouts (any order).
    ///   - splitData / overrideData: the UserDefaults values (`MySplitStore.key`, `UpNextOverride.key`).
    ///   - now: the screen's day snapshot (`refreshingNow`); `clock` is read at each render, so a workout finished in
    ///     this session counts at once — the query re-renders the screen (codex-review-s5 #1).
    static func make(templates: [WorkoutTemplate], finished: [Workout], splitData: Data, overrideData: Data,
                     now: Date, clock: Date = .now) -> UpNextReading {
        let current = max(now, clock)
        let named = templates.map { (id: $0.id, name: $0.name) }
        let valid = finished.filter { !$0.isDeleted && $0.finishedAt != nil }
        let runs = valid.compactMap { workout -> UpNext.Run? in
            guard let id = workout.sourceTemplateID else { return nil }
            return UpNext.Run(templateID: id, startedAt: workout.startedAt)
        }
        let split = MySplitStore.decode(splitData).pruned(to: Set(named.map(\.id)))
        let lastFinishedAt = valid.compactMap(\.finishedAt).filter { $0 <= current }.max()
        let stored = UpNextOverride.decode(overrideData)
        let (suggestion, overridden) = UpNext.resolve(templates: named, runs: runs, split: split, now: current,
                                                      override: stored, lastFinishedAt: lastFinishedAt)
        let template: WorkoutTemplate? = if case .template(let id) = suggestion {
            templates.first { $0.id == id }
        } else {
            nil
        }
        let lastRun = template.flatMap { chosen in
            runs.filter { $0.templateID == chosen.id && $0.startedAt <= current }.map(\.startedAt).max()
        }
        return UpNextReading(suggestion: suggestion, template: template, lastRun: lastRun, isOverridden: overridden,
                             split: split, activeOverride: overridden ? stored : nil)
    }
}
