import Foundation

// Floodlight redesign — the live workout's "what do I do now": the next-up set (its check and
// marker lead) and the rest slab's "Next · Set 3 · 110 × 8" / "Next · Incline Chest Press".
// Pure over positions, so the rule is testable without a store.

enum NextSetMath {
    /// One entry as the rule reads it: its superset group and, per set in order, whether done.
    struct Entry: Equatable {
        var group: UUID?
        var done: [Bool]
        /// When each done set was completed (nil for undone sets), to find the last one logged.
        var completedAt: [Date?]
    }

    struct Position: Equatable {
        var entry: Int
        var set: Int
    }

    /// The next set to do after the most recently completed one:
    /// - inside a superset (D48), the next member of the group that still has a set to do,
    ///   cycling back to the first member (A1 → B1 → A2 → B2);
    /// - otherwise the next undone set of the same entry, then of the following entries, then of
    ///   any earlier entry left unfinished.
    /// With nothing completed yet, the first undone set. nil when every set is done.
    static func next(in entries: [Entry]) -> Position? {
        func firstUndone(_ index: Int, after set: Int = -1) -> Position? {
            guard entries.indices.contains(index) else { return nil }
            let done = entries[index].done
            guard let s = done.indices.first(where: { $0 > set && !done[$0] }) else { return nil }
            return Position(entry: index, set: s)
        }
        var last: (entry: Int, set: Int, at: Date)?
        for (e, entry) in entries.enumerated() {
            for (s, at) in entry.completedAt.enumerated() where entry.done[s] {
                guard let at else { continue }
                if last == nil || at >= last!.at { last = (e, s, at) }
            }
        }
        guard let last else {
            return entries.indices.lazy.compactMap { firstUndone($0) }.first
        }
        if let group = entries[last.entry].group {
            // The contiguous run of this group around the last entry.
            var head = last.entry
            while head > 0, entries[head - 1].group == group { head -= 1 }
            var tail = last.entry
            while tail + 1 < entries.count, entries[tail + 1].group == group { tail += 1 }
            let members = Array(head...tail)
            if members.count > 1 {
                let start = members.firstIndex(of: last.entry)!
                for step in 1...members.count {
                    if let found = firstUndone(members[(start + step) % members.count]) { return found }
                }
            }
        }
        if let found = firstUndone(last.entry, after: last.set) { return found }
        for e in (last.entry + 1)..<max(last.entry + 1, entries.count) {
            if let found = firstUndone(e) { return found }
        }
        return entries.indices.lazy.compactMap { firstUndone($0) }.first
    }
}

extension WorkoutSession {
    /// The workout's next-up set (see `NextSetMath.next`).
    static func nextSet(in workout: Workout) -> SetRecord? {
        let entries = orderedEntries(of: workout)
        let sets = entries.map { orderedSets(of: $0) }
        let inputs = zip(entries, sets).map { entry, sets in
            NextSetMath.Entry(group: entry.supersetGroupID, done: sets.map { $0.completedAt != nil },
                              completedAt: sets.map(\.completedAt))
        }
        guard let position = NextSetMath.next(in: inputs) else { return nil }
        return sets[position.entry][position.set]
    }
}
