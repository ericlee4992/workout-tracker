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

/// The day's "Not today" choice on Today's card. It holds for the day it was made and until a workout finishes after
/// it (`isCurrent`), so finishing the chosen workout — or the next morning — brings the plan back.
struct UpNextOverride: Codable, Equatable, Sendable {
    /// When the choice was made.
    var madeAt: Date
    /// How many suggestions to skip ("Next in order", tapped repeatedly).
    var skip: Int = 0
    /// A template picked with "Choose template…" (wins over `skip`).
    var chosen: UUID?

    static let key = "upNextOverride"

    func isCurrent(now: Date, lastFinishedStart: Date?, calendar: Calendar = .current) -> Bool {
        guard calendar.isDate(madeAt, inSameDayAs: now) else { return false }
        if let lastFinishedStart, lastFinishedStart >= madeAt { return false }
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
    /// One finished workout started from a template.
    struct Run: Equatable, Sendable {
        var templateID: UUID
        var startedAt: Date
    }

    /// How far back the learned order looks.
    static let windowDays = 42

    /// Today's suggestion: the split when set, else the learned order; `skip` steps past that many suggestions as if
    /// they had been done ("Next in order").
    static func suggestion(templates: [(id: UUID, name: String)], runs: [Run], split: MySplit, now: Date, skip: Int = 0,
                           calendar: Calendar = .current) -> UpNextSuggestion {
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
            var done = runs
            guard var pick = learned(templates: templates, runs: done, now: now) else { return .none }
            for step in 0..<max(0, skip) {
                done.append(Run(templateID: pick, startedAt: now.addingTimeInterval(Double(step + 1))))
                pick = learned(templates: templates, runs: done, now: now) ?? pick
            }
            return .template(pick)
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
