import Foundation
import Testing
@testable import WorkoutTracker

// Soft redesign S5 (D77): Today's "Up next" — the learned order, My split, "Next in order", the fallbacks.
struct UpNextTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }

    private let push = UUID(), pull = UUID(), legs = UUID(), deload = UUID(), fresh = UUID()
    private var ppl: [(id: UUID, name: String)] { [(push, "Push"), (pull, "Pull"), (legs, "Legs")] }

    /// Sunday, Nov 8, 2026, 10:00 in New York.
    private var now: Date { ISO8601DateFormatter().date(from: "2026-11-08T15:00:00Z")! }

    private func run(_ id: UUID, daysAgo: Double) -> UpNext.Run {
        UpNext.Run(templateID: id, startedAt: now.addingTimeInterval(-daysAgo * 86_400))
    }

    /// Push, Pull, Legs, Push, Pull — two weeks of rhythm.
    private var rhythm: [UpNext.Run] {
        [run(push, daysAgo: 10), run(pull, daysAgo: 9), run(legs, daysAgo: 8), run(push, daysAgo: 3), run(pull, daysAgo: 2)]
    }

    @Test func afterPullComesLegs() {
        #expect(UpNext.suggestion(templates: ppl, runs: rhythm, split: .off, now: now) == .template(legs))
    }

    @Test func upperLowerABFollowsItsCycle() {
        let ua = UUID(), la = UUID(), ub = UUID(), lb = UUID()
        let templates = [(ua, "Upper A"), (la, "Lower A"), (ub, "Upper B"), (lb, "Lower B")].map { (id: $0.0, name: $0.1) }
        let runs = [run(ua, daysAgo: 12), run(la, daysAgo: 11), run(ub, daysAgo: 9), run(lb, daysAgo: 8),
                    run(ua, daysAgo: 5), run(la, daysAgo: 4)]
        #expect(UpNext.suggestion(templates: templates, runs: runs, split: .off, now: now) == .template(ub))
    }

    @Test func aRarelyUsedOrBrandNewTemplateDoesNotTakeOver() {
        // "Longest ago" alone would pick Deload (40 days) or the never-run template.
        let templates = ppl + [(id: deload, name: "Deload"), (id: fresh, name: "AI Day 1")]
        let runs = [run(deload, daysAgo: 40)] + rhythm
        #expect(UpNext.suggestion(templates: templates, runs: runs, split: .off, now: now) == .template(legs))
        #expect(TemplateStats.dueNext(templates, lastRun: [deload: runs[0].startedAt]) != legs)
    }

    @Test func withoutAFollowerTheLongestAgoAmongRecentlyUsed() {
        // Legs was done last and never before in the window: no follower → longest ago among used (Push).
        let runs = [run(push, daysAgo: 5), run(pull, daysAgo: 3), run(legs, daysAgo: 1)]
        #expect(UpNext.suggestion(templates: ppl, runs: runs, split: .off, now: now) == .template(push))
    }

    @Test func oneTemplateUsedOverAndOverStaysIt() {
        let templates = [(id: push, name: "Full Body"), (id: fresh, name: "New")]
        let runs = [run(push, daysAgo: 6), run(push, daysAgo: 4), run(push, daysAgo: 2)]
        #expect(UpNext.suggestion(templates: templates, runs: runs, split: .off, now: now) == .template(push))
    }

    @Test func noHistoryFallsBackToLongestAgoThenName() {
        #expect(UpNext.suggestion(templates: ppl, runs: [], split: .off, now: now) == .template(legs)) // by name
        let old = [run(push, daysAgo: 60), run(pull, daysAgo: 50)]   // outside the window
        #expect(UpNext.suggestion(templates: ppl, runs: old, split: .off, now: now) == .template(legs)) // never run
    }

    @Test func deletedTemplatesAreNeverSuggestedAndNoTemplatesIsNone() {
        let gone = UUID()
        let runs = [run(pull, daysAgo: 9), run(gone, daysAgo: 8), run(pull, daysAgo: 2)]
        #expect(UpNext.suggestion(templates: ppl, runs: runs, split: .off, now: now) != .template(gone))
        #expect(UpNext.suggestion(templates: [], runs: rhythm, split: .off, now: now) == .none)
    }

    @Test func nextInOrderSkipsAsIfDone() {
        #expect(UpNext.suggestion(templates: ppl, runs: rhythm, split: .off, now: now, skip: 1) == .template(push))
        #expect(UpNext.suggestion(templates: ppl, runs: rhythm, split: .off, now: now, skip: 2) == .template(pull))
    }

    @Test func mySplitInOrderWraps() {
        let split = MySplit.inOrder([push, pull, legs])
        #expect(UpNext.suggestion(templates: ppl, runs: [run(legs, daysAgo: 1)], split: split, now: now) == .template(push))
        #expect(UpNext.suggestion(templates: ppl, runs: [], split: split, now: now) == .template(push))
        #expect(UpNext.suggestion(templates: ppl, runs: rhythm, split: split, now: now, skip: 1) == .template(push))
    }

    @Test func mySplitByWeekdayWithRestDays() {
        // Monday Push, Wednesday Pull, Friday Legs; now is a Sunday.
        let split = MySplit.byWeekday([2: push, 4: pull, 6: legs])
        #expect(UpNext.suggestion(templates: ppl, runs: [], split: split, now: now, calendar: calendar) == .restDay)
        #expect(UpNext.suggestion(templates: ppl, runs: [], split: split, now: now, skip: 1, calendar: calendar) == .template(push))
        #expect(UpNext.suggestion(templates: ppl, runs: [], split: split, now: now, skip: 3, calendar: calendar) == .template(legs))
        let monday = now.addingTimeInterval(86_400)
        #expect(UpNext.suggestion(templates: ppl, runs: [], split: split, now: monday, calendar: calendar) == .template(push))
    }

    @Test func aSplitDropsDeletedTemplatesAndAnEmptySplitIsOff() {
        let gone = UUID()
        #expect(MySplit.inOrder([gone, pull]).pruned(to: Set(ppl.map(\.id))) == .inOrder([pull]))
        #expect(MySplit.byWeekday([2: gone]).pruned(to: Set(ppl.map(\.id))) == .off)
        #expect(UpNext.suggestion(templates: ppl, runs: rhythm, split: .inOrder([gone]), now: now) == .template(legs))
    }

    @Test func storedSplitAndOverrideDecodeSafely() {
        for split in [MySplit.off, .inOrder([push, pull]), .byWeekday([2: push, 6: legs])] {
            #expect(MySplitStore.decode(MySplitStore.encode(split)) == split)
        }
        #expect(MySplitStore.decode(nil) == .off)
        #expect(MySplitStore.decode(Data("garbage".utf8)) == .off)
        let choice = UpNextOverride(madeAt: now, skip: 1, chosen: pull)
        #expect(UpNextOverride.decode(UpNextOverride.encode(choice)) == choice)
        #expect(UpNextOverride.decode(Data()) == nil)
    }

    @Test func notTodayLastsTheDayAndUntilAWorkoutFinishes() {
        let choice = UpNextOverride(madeAt: now, skip: 1)
        #expect(choice.isCurrent(now: now.addingTimeInterval(3600), lastFinishedStart: nil, calendar: calendar))
        #expect(!choice.isCurrent(now: now.addingTimeInterval(86_400), lastFinishedStart: nil, calendar: calendar))
        #expect(!choice.isCurrent(now: now.addingTimeInterval(7200), lastFinishedStart: now.addingTimeInterval(60),
                                  calendar: calendar))
        #expect(choice.isCurrent(now: now.addingTimeInterval(7200), lastFinishedStart: now.addingTimeInterval(-60),
                                 calendar: calendar))
    }
}
