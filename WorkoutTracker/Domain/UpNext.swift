import Foundation

// Soft redesign S5 (D77): which template Today (and Train's leading card) offers next. Pure; derived on read from the
// finished workouts' `sourceTemplateID`s, the user's optional split (a UserDefaults view preference — no store change)
// and the day's "Not today" choice.

/// The user's optional split, set in Train → My split.
enum MySplit: Codable, Equatable, Sendable {
    /// Learned from history (the default).
    case off
    /// These templates in this order; next = the one after the last done, wrapping.
    case inOrder([UUID])
    /// A template per weekday (`Calendar` weekday: 1 = Sunday … 7 = Saturday); a weekday without one is a rest day.
    case byWeekday([Int: UUID])

    /// Drops templates that no longer exist; a split left empty is `.off`.
    func pruned(to existing: Set<UUID>) -> MySplit {
        switch self {
        case .off: return .off
        case .inOrder(let ids):
            let kept = ids.filter(existing.contains)
            return kept.isEmpty ? .off : .inOrder(kept)
        case .byWeekday(let days):
            let kept = days.filter { (1...7).contains($0.key) && existing.contains($0.value) }
            return kept.isEmpty ? .off : .byWeekday(kept)
        }
    }
}

/// Where the split lives: UserDefaults, as JSON. Unreadable or missing data is `.off` — never an error.
enum MySplitStore {
    static let key = "mySplit"

    static func decode(_ data: Data?) -> MySplit {
        guard let data, !data.isEmpty, let split = try? JSONDecoder().decode(MySplit.self, from: data) else { return .off }
        return split
    }

    static func encode(_ split: MySplit) -> Data {
        (try? JSONEncoder().encode(split)) ?? Data()
    }
}

/// The day's "Not today" choice on Today's card. It holds for the day it was made and until a workout FINISHES after
/// it (`isCurrent`), so finishing the chosen workout — or the next morning — brings the plan back.
struct UpNextOverride: Codable, Equatable, Sendable {
    /// When the choice was made.
    var madeAt: Date
    /// "Next in order" taps: steps past the plan's suggestion — or past `chosen` when one was picked.
    var skip: Int = 0
    /// A template picked with "Choose template…"; "Next in order" then continues from it (codex-review-s5 #2).
    var chosen: UUID?

    static let key = "upNextOverride"

    /// - Parameter lastFinishedAt: the latest COMPLETION time among finished workouts, not later than `now` — a record
    ///   dated in the future (a clock correction, a restore) must not cancel today's choice (codex-review-s5 #3).
    func isCurrent(now: Date, lastFinishedAt: Date?, calendar: Calendar = .current) -> Bool {
        guard calendar.isDate(madeAt, inSameDayAs: now) else { return false }
        if let lastFinishedAt, lastFinishedAt <= now, lastFinishedAt >= madeAt { return false }
        return true
    }

    static func decode(_ data: Data?) -> UpNextOverride? {
        guard let data, !data.isEmpty else { return nil }
        return try? JSONDecoder().decode(UpNextOverride.self, from: data)
    }

    static func encode(_ value: UpNextOverride?) -> Data {
        guard let value else { return Data() }
        return (try? JSONEncoder().encode(value)) ?? Data()
    }
}

enum UpNextSuggestion: Equatable, Sendable {
    case template(UUID)
    /// The split assigns nothing to today.
    case restDay
    /// No templates.
    case none
}

enum UpNext {
    /// Today's suggestion with the day's "Not today" choice applied: a chosen template shows as is; "Next in order"
    /// after a choice continues from the chosen template (as if it had been done; a weekday split steps through its
    /// days instead); without a choice it skips past the plan's suggestions. `overridden` tells the card to say so.
    static func resolve(templates: [(id: UUID, name: String)], runs: [Run], split: MySplit, now: Date,
                        override: UpNextOverride?, lastFinishedAt: Date?,
                        calendar: Calendar = .current) -> (suggestion: UpNextSuggestion, overridden: Bool) {
        guard let choice = override, choice.isCurrent(now: now, lastFinishedAt: lastFinishedAt, calendar: calendar) else {
            return (suggestion(templates: templates, runs: runs, split: split, now: now, calendar: calendar), false)
        }
        let ids = Set(templates.map(\.id))
        guard let chosen = choice.chosen, ids.contains(chosen) else {
            return (suggestion(templates: templates, runs: runs, split: split, now: now, skip: choice.skip,
                               calendar: calendar), true)
        }
        if choice.skip <= 0 { return (.template(chosen), true) }
        if case .byWeekday = split.pruned(to: ids) {
            return (suggestion(templates: templates, runs: runs, split: split, now: now, skip: choice.skip,
                               calendar: calendar), true)
        }
        let past = runs.filter { $0.startedAt <= now } + [Run(templateID: chosen, startedAt: now)]
        return (suggestion(templates: templates, runs: past, split: split, now: now, skip: choice.skip - 1,
                           alreadyShown: [chosen], calendar: calendar), true)
    }

    /// One finished workout started from a template.
    struct Run: Equatable, Sendable {
        var templateID: UUID
        var startedAt: Date
    }

    /// How far back the learned order looks.
    static let windowDays = 42

    /// Today's suggestion: the split when set, else the learned order; `skip` steps past that many suggestions as if
    /// they had been done ("Next in order").
    /// - Parameter alreadyShown: templates this "Next in order" chain has already shown (a chosen template), so a
    ///   learned suggestion never repeats them before every template has had its turn.
    static func suggestion(templates: [(id: UUID, name: String)], runs: [Run], split: MySplit, now: Date, skip: Int = 0,
                           alreadyShown: [UUID] = [], calendar: Calendar = .current) -> UpNextSuggestion {
        guard !templates.isEmpty else { return .none }
        let existing = Set(templates.map(\.id))
        let runs = runs.filter { existing.contains($0.templateID) && $0.startedAt <= now }
            .sorted { $0.startedAt < $1.startedAt }
        switch split.pruned(to: existing) {
        case .byWeekday(let days):
            return weekday(days, now: now, skip: skip, calendar: calendar)
        case .inOrder(let ids):
            var done = runs
            var pick = nextInOrder(ids, runs: done)
            for step in 0..<max(0, skip) {
                done.append(Run(templateID: pick, startedAt: now.addingTimeInterval(Double(step + 1))))
                pick = nextInOrder(ids, runs: done)
            }
            return .template(pick)
        case .off:
            // Each "Next in order" shows a template not shown yet in this chain (then wraps): with no rhythm to follow
            // — a new user, a fresh AI week, history outside the window — the learned rule alone would repeat its
            // single synthetic run forever (codex-review-s5b #1). An established rhythm already yields new ones.
            var done = runs
            var shown = alreadyShown
            var realLastRun: [UUID: Date] = [:]
            for run in runs { realLastRun[run.templateID] = max(realLastRun[run.templateID] ?? .distantPast, run.startedAt) }
            func pick() -> UUID? {
                if shown.count >= templates.count { shown.removeAll() }
                guard let candidate = learned(templates: templates, runs: done, now: now) else { return nil }
                if !shown.contains(candidate) { return candidate }
                let fresh = templates.filter { !shown.contains($0.id) }
                return TemplateStats.dueNext(fresh, lastRun: realLastRun) ?? candidate
            }
            guard var current = pick() else { return .none }
            for step in 0..<max(0, skip) {
                shown.append(current)
                done.append(Run(templateID: current, startedAt: now.addingTimeInterval(Double(step + 1))))
                current = pick() ?? current
            }
            return .template(current)
        }
    }

    /// The learned order: the template that followed the last-done one the previous times it was done (the most
    /// frequent follower; ties to the most recent). Without such a follower: the one done longest ago among the
    /// templates used in the window; without any use in the window: `TemplateStats.dueNext` over all templates.
    /// Rarely used and never-run templates therefore don't take the slot once there is a rhythm.
    static func learned(templates: [(id: UUID, name: String)], runs: [Run], now: Date) -> UUID? {
        let windowStart = now.addingTimeInterval(-Double(windowDays) * 86_400)
        let recent = runs.filter { $0.startedAt >= windowStart }.sorted { $0.startedAt < $1.startedAt }
        var lastRun: [UUID: Date] = [:]
        for run in runs { lastRun[run.templateID] = max(lastRun[run.templateID] ?? .distantPast, run.startedAt) }
        guard let last = recent.last?.templateID else {
            return TemplateStats.dueNext(templates, lastRun: lastRun)
        }
        // Followers of `last`'s earlier runs (not counting a repeat of itself).
        var count: [UUID: Int] = [:]
        var latest: [UUID: Int] = [:]
        for index in recent.indices.dropLast() where recent[index].templateID == last {
            let follower = recent[index + 1].templateID
            guard follower != last else { continue }
            count[follower, default: 0] += 1
            latest[follower] = index
        }
        if let best = count.keys.max(by: { lhs, rhs in
            (count[lhs]!, latest[lhs]!) < (count[rhs]!, latest[rhs]!)
        }) {
            return best
        }
        let used = Set(recent.map(\.templateID))
        let pool = templates.filter { used.contains($0.id) && ($0.id != last || used.count == 1) }
        return TemplateStats.dueNext(pool.isEmpty ? templates : pool, lastRun: lastRun)
    }

    /// In order: the template after the last one done (wrapping); the first when none has been done.
    static func nextInOrder(_ ids: [UUID], runs: [Run]) -> UUID {
        guard let last = runs.last(where: { ids.contains($0.templateID) })?.templateID,
              let index = ids.firstIndex(of: last) else { return ids[0] }
        return ids[(index + 1) % ids.count]
    }

    /// By weekday: today's template, or a rest day; `skip` moves to the next assigned weekdays.
    static func weekday(_ days: [Int: UUID], now: Date, skip: Int, calendar: Calendar) -> UpNextSuggestion {
        let today = calendar.component(.weekday, from: now)
        if skip <= 0 { return days[today].map(UpNextSuggestion.template) ?? .restDay }
        var found = 0
        for offset in 1...7 {
            let day = (today - 1 + offset) % 7 + 1
            if let id = days[day] {
                found += 1
                if found == skip { return .template(id) }
            }
        }
        // Fewer assigned days than steps: wrap around them.
        let ordered = (1...7).map { (today - 1 + $0) % 7 + 1 }.compactMap { days[$0] }
        return ordered.isEmpty ? .restDay : .template(ordered[(skip - 1) % ordered.count])
    }
}
