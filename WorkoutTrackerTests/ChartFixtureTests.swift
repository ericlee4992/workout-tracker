import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

// Ticket 13 (release-candidate pass): the History calendar's paging test ran on the chart
// fixture, whose oldest session (28 days back) shares today's month on the 29th–31st — the
// calendar then has one month and nothing to page to. `-uiTestChartHistoryOlderMonth` adds one
// session forty days back.

struct ChartFixtureTests {

    private func makeContext() throws -> ModelContext {
        let schema = WorkoutTrackerStore.schema
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        context.insert(Exercise(name: ChartFixture.exerciseName, loadType: .weighted))
        try context.save()
        return context
    }

    private func calendarMonths(seededAt now: Date, includeOlderMonth: Bool) throws -> Int {
        let context = try makeContext()
        try ChartFixture.seed(in: context, now: now, includeOlderMonth: includeOlderMonth)
        let starts = try context.fetch(FetchDescriptor<Workout>()).map(\.startedAt)
        return WorkoutCalendar(startedAt: starts, today: now).months.count
    }

    /// The date the paging test failed on: the fixture alone gives a one-month calendar.
    @Test func theFixtureAloneSpansOneMonthAtTheEndOfAMonth() throws {
        let now = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 29, hour: 8)))
        #expect(try calendarMonths(seededAt: now, includeOlderMonth: false) == 1)
        #expect(try calendarMonths(seededAt: now, includeOlderMonth: true) == 2)
    }

    /// Forty days back is in an earlier calendar month on every day of a year (the fixture dates
    /// sessions `now - days × 86,400 s`), so the calendar always has a previous month.
    @Test func theOlderSessionIsAlwaysInAnEarlierMonth() throws {
        let calendar = Calendar.current
        let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 8)))
        for offset in 0..<366 {
            let now = try #require(calendar.date(byAdding: .day, value: offset, to: start))
            let older = now.addingTimeInterval(-Double(ChartFixture.olderMonthSession.daysAgo) * 86_400)
            let thisMonth = try #require(calendar.dateInterval(of: .month, for: now)).start
            #expect(older < thisMonth, "\(now)")
        }
    }

    /// The extra session is the one working set; the chart tests' series is unchanged without it.
    @Test func theOlderSessionOnlyArrivesWithItsArgument() throws {
        let now = Date.now
        let plain = try makeContext()
        try ChartFixture.seed(in: plain, now: now, includeOlderMonth: false)
        let older = try makeContext()
        try ChartFixture.seed(in: older, now: now, includeOlderMonth: true)
        let plainCount = try plain.fetchCount(FetchDescriptor<Workout>())
        #expect(plainCount == ChartFixture.script.count + 1)
        #expect(try older.fetchCount(FetchDescriptor<Workout>()) == plainCount + 1)
        #expect(!ChartFixture.includesOlderMonth, "unit tests never launch with UI-test flags")
        #expect(!WorkoutTrackerStore.fixtureIsEnabled(
            ChartFixture.olderMonthArgument, in: [ChartFixture.olderMonthArgument]))
    }
}
