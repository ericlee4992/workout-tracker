import Foundation
import SwiftData
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
        #expect(choice.isCurrent(now: now.addingTimeInterval(3600), lastFinishedAt: nil, calendar: calendar))
        #expect(!choice.isCurrent(now: now.addingTimeInterval(86_400), lastFinishedAt: nil, calendar: calendar))
        #expect(!choice.isCurrent(now: now.addingTimeInterval(7200), lastFinishedAt: now.addingTimeInterval(60),
                                  calendar: calendar))
        #expect(choice.isCurrent(now: now.addingTimeInterval(7200), lastFinishedAt: now.addingTimeInterval(-60),
                                 calendar: calendar))
    }

    // MARK: codex-review-s5

    /// #2: Choose template… then Next in order continues from the CHOSEN template, in order and learned.
    @Test func nextInOrderAfterAChoiceContinuesFromTheChoice() {
        let split = MySplit.inOrder([push, pull, legs])
        let runs = [run(legs, daysAgo: 1)]                            // plan: Push is due
        func pick(_ o: UpNextOverride, _ s: MySplit = split, _ r: [UpNext.Run]? = nil) -> UpNextSuggestion {
            UpNext.resolve(templates: ppl, runs: r ?? runs, split: s, now: now, override: o, lastFinishedAt: nil,
                           calendar: calendar).suggestion
        }
        #expect(pick(UpNextOverride(madeAt: now, skip: 0, chosen: pull)) == .template(pull))
        #expect(pick(UpNextOverride(madeAt: now, skip: 1, chosen: pull)) == .template(legs))
        #expect(pick(UpNextOverride(madeAt: now, skip: 2, chosen: pull)) == .template(push))   // wraps
        #expect(pick(UpNextOverride(madeAt: now, skip: 1, chosen: legs)) == .template(push))   // wraps from the end
        // Learned order: after choosing Pull, next is what follows Pull (Legs).
        #expect(pick(UpNextOverride(madeAt: now, skip: 1, chosen: pull), .off, rhythm) == .template(legs))
        // Without a choice, Next skips past the plan's suggestion.
        #expect(pick(UpNextOverride(madeAt: now, skip: 1)) == .template(pull))
    }

    /// codex-review-s5b #1: with no recent history (a new user, a fresh AI week, or history outside the window), Next
    /// in order still walks through every template — Legs, Pull, Push by name, then wraps — and from a choice too.
    @Test func nextInOrderWalksEveryTemplateWithoutHistory() {
        func plan(_ skip: Int, runs: [UpNext.Run] = []) -> UpNextSuggestion {
            UpNext.suggestion(templates: ppl, runs: runs, split: .off, now: now, skip: skip, calendar: calendar)
        }
        #expect((0...3).map { plan($0) } == [.template(legs), .template(pull), .template(push), .template(legs)])
        let old = [run(push, daysAgo: 60), run(pull, daysAgo: 55), run(legs, daysAgo: 50)]
        #expect((0...2).map { plan($0, runs: old) }.count == Set((0...2).map { "\(plan($0, runs: old))" }).count)
        func chose(_ skip: Int) -> UpNextSuggestion {
            UpNext.resolve(templates: ppl, runs: [], split: .off, now: now,
                           override: UpNextOverride(madeAt: now, skip: skip, chosen: pull), lastFinishedAt: nil,
                           calendar: calendar).suggestion
        }
        #expect((0...2).map(chose) == [.template(pull), .template(legs), .template(push)])
    }

    /// #3: a finished record dated in the future does not cancel today's choice; a workout finished after the choice
    /// does (expiry follows completion, not start).
    @Test func aChoiceExpiresOnARealFinishNotOnFutureHistory() {
        let choice = UpNextOverride(madeAt: now, skip: 0, chosen: pull)
        let later = now.addingTimeInterval(1800)
        let tomorrow = now.addingTimeInterval(86_400 + 3600)
        #expect(choice.isCurrent(now: later, lastFinishedAt: tomorrow, calendar: calendar))
        #expect(!choice.isCurrent(now: later, lastFinishedAt: now.addingTimeInterval(600), calendar: calendar))
        // A workout started before the choice but finished after it ends the choice too.
        #expect(!choice.isCurrent(now: later, lastFinishedAt: now.addingTimeInterval(60), calendar: calendar))
        let resolved = UpNext.resolve(templates: ppl, runs: rhythm, split: .off, now: later, override: choice,
                                      lastFinishedAt: tomorrow, calendar: calendar)
        #expect(resolved.suggestion == .template(pull) && resolved.overridden)
    }
}

/// #1: the shared reading counts a workout finished after the screen's day snapshot (`now`) — the render's clock wins.
@MainActor
struct UpNextReadingTests {
    private func makeInMemoryContext() throws -> ModelContext {
        let schema = WorkoutTrackerStore.schema
        let container = try ModelContainer(
            for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        return ModelContext(container)
    }

    @Test func aWorkoutFinishedThisSessionAdvancesTheSuggestion() throws {
        let context = try makeInMemoryContext()
        let push = WorkoutTemplate(name: "Push"), pull = WorkoutTemplate(name: "Pull"), legs = WorkoutTemplate(name: "Legs")
        [push, pull, legs].forEach(context.insert)
        let snapshot = Date.now.addingTimeInterval(-3600)              // the screen's `now`, an hour old
        for (template, hoursAgo) in [(push, 30.0), (pull, 20.0), (legs, 10.0)] {
            let start = snapshot.addingTimeInterval(-hoursAgo * 3600)
            context.insert(Workout(startedAt: start, finishedAt: start.addingTimeInterval(3000),
                                   sourceTemplateID: template.id, sourceTemplateName: template.name))
        }
        let split = MySplitStore.encode(.inOrder([push.id, pull.id, legs.id]))
        let before = try context.fetch(FetchDescriptor<Workout>())
        #expect(UpNextReading.make(templates: [push, pull, legs], finished: before, splitData: split, overrideData: Data(),
                                   now: snapshot).template?.id == push.id)
        // Push done just now, after the snapshot: the next render suggests Pull.
        let justNow = Date.now.addingTimeInterval(-600)
        context.insert(Workout(startedAt: justNow, finishedAt: justNow.addingTimeInterval(300),
                               sourceTemplateID: push.id, sourceTemplateName: push.name))
        let after = try context.fetch(FetchDescriptor<Workout>())
        #expect(UpNextReading.make(templates: [push, pull, legs], finished: after, splitData: split, overrideData: Data(),
                                   now: snapshot).template?.id == pull.id)
    }
}
