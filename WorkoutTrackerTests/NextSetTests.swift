import Foundation
import Testing
@testable import WorkoutTracker

// Floodlight redesign — the live workout's next-up set and the rest slab's "Next" line.

struct NextSetTests {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    private func at(_ minute: Int) -> Date { t0.addingTimeInterval(Double(minute) * 60) }

    private func entry(_ done: [Int?], group: UUID? = nil) -> NextSetMath.Entry {
        NextSetMath.Entry(group: group, done: done.map { $0 != nil }, completedAt: done.map { $0.map(at) })
    }

    @Test func nothingDoneStartsAtTheFirstUndoneSet() {
        let next = NextSetMath.next(in: [entry([]), entry([nil, nil])])
        #expect(next == .init(entry: 1, set: 0))
    }

    @Test func continuesInTheSameEntryThenMovesOn() {
        #expect(NextSetMath.next(in: [entry([1, nil, nil]), entry([nil])]) == .init(entry: 0, set: 1))
        #expect(NextSetMath.next(in: [entry([1, 2]), entry([nil, nil])]) == .init(entry: 1, set: 0))
    }

    @Test func followsTheLastCompletedSetNotTheFirstGap() {
        // A skipped set early on does not pull "next" back while later work continues.
        let entries = [entry([1, nil, 3]), entry([4, nil])]
        #expect(NextSetMath.next(in: entries) == .init(entry: 1, set: 1))
    }

    @Test func wrapsToEarlierUnfinishedEntries() {
        #expect(NextSetMath.next(in: [entry([nil]), entry([2, 3])]) == .init(entry: 0, set: 0))
    }

    @Test func supersetsAlternateMembers() {
        let g = UUID()
        #expect(NextSetMath.next(in: [entry([1, nil], group: g), entry([nil, nil], group: g)]) == .init(entry: 1, set: 0))
        #expect(NextSetMath.next(in: [entry([1, nil], group: g), entry([2, nil], group: g)]) == .init(entry: 0, set: 1))
        // A finished member hands over to the one that still has sets.
        #expect(NextSetMath.next(in: [entry([1, 3], group: g), entry([2, nil, nil], group: g)]) == .init(entry: 1, set: 1))
    }

    @Test func everythingDoneHasNoNext() {
        #expect(NextSetMath.next(in: [entry([1]), entry([2])]) == nil)
    }
}
