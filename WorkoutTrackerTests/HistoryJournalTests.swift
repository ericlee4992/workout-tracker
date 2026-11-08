import Foundation
import Testing
@testable import WorkoutTracker

// Soft redesign S4: History as a journal — months, then one section per day, newest first.
struct HistoryJournalTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        c.locale = Locale(identifier: "en_US")
        return c
    }

    private func at(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }

    private func facts(_ start: String) -> HistoryWorkoutFacts {
        HistoryWorkoutFacts(id: UUID(), startedAt: at(start), durationSeconds: 3600, sets: 10,
                            hasLifting: true, hasCardio: false)
    }

    @Test func workoutsGroupByTheDayTheyStartedNewestFirst() {
        let now = at("2026-11-07T20:00:00Z")
        let morning = facts("2026-11-07T13:00:00Z"), evening = facts("2026-11-07T22:30:00Z")
        let thursday = facts("2026-11-05T23:00:00Z")
        let months = HistoryOverviewMath.journal([thursday, morning, evening], now: now, calendar: calendar)
        #expect(months.count == 1)
        #expect(months[0].days.map(\.workoutIDs) == [[evening.id, morning.id], [thursday.id]])
        #expect(months[0].days.map(\.title) == ["Today", "Thursday, Nov 5"])
    }

    @Test func aLateNightWorkoutStaysOnItsLocalDay() {
        // 23:30 in New York on Nov 6 is already Nov 7 in UTC.
        let late = facts("2026-11-07T04:30:00Z")
        let months = HistoryOverviewMath.journal([late], now: at("2026-11-07T20:00:00Z"), calendar: calendar)
        #expect(months[0].days[0].title == "Yesterday")
    }

    @Test func monthsSplitAndAnotherYearShowsTheYear() {
        let now = at("2026-11-07T20:00:00Z")
        let october = facts("2026-10-30T15:00:00Z"), lastYear = facts("2025-11-03T15:00:00Z")
        let months = HistoryOverviewMath.journal([october, lastYear], now: now, calendar: calendar)
        #expect(months.count == 2)
        #expect(months[0].days[0].title == "Friday, Oct 30")
        #expect(months[1].days[0].title.contains("2025"))
    }
}
