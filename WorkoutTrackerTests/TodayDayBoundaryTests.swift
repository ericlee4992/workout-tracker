import Foundation
import Testing
@testable import WorkoutTracker

// Soft redesign S2, codex-review-s2 #2: Today reads one "now" snapshot (refreshed at midnight, on clock/time-zone
// changes and on activation); these pin what that snapshot decides — the log's day and the week's rollover.
struct TodayDayBoundaryTests {
    private func calendar(_ zone: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        calendar.firstWeekday = 1
        return calendar
    }

    private func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }

    @Test func aWorkoutBelongsToTheDayItStarted() {
        let seoul = calendar("Asia/Seoul")
        let started = date("2026-11-07T14:30:00Z")          // 23:30 on Nov 7 in Seoul
        #expect(TodayView.startedOnDay(started, of: date("2026-11-07T14:50:00Z"), calendar: seoul))   // 23:50 same day
        #expect(!TodayView.startedOnDay(started, of: date("2026-11-07T15:10:00Z"), calendar: seoul))  // 00:10 next day
    }

    @Test func theDayFollowsTheTimeZone() {
        let started = date("2026-11-07T14:30:00Z")
        let now = date("2026-11-07T16:00:00Z")
        #expect(!TodayView.startedOnDay(started, of: now, calendar: calendar("Asia/Seoul")))       // Nov 7 vs Nov 8
        #expect(TodayView.startedOnDay(started, of: now, calendar: calendar("America/New_York")))  // both Nov 7
    }

    @Test func theWeekRollsOverOnTheFirstWeekday() {
        let ny = calendar("America/New_York")
        let saturday = date("2026-11-07T17:00:00Z")
        let sunday = date("2026-11-08T17:00:00Z")
        let workout = WeekSummaryInput(id: UUID(), title: "Push Day", startedAt: date("2026-11-04T17:00:00Z"),
                                       durationSeconds: 3_600, hasLifting: true, hasCardio: false,
                                       familySets: [.chest: 4])
        #expect(WeekSummaryMath.summary(of: [workout], now: saturday, calendar: ny).workoutCount == 1)
        #expect(WeekSummaryMath.summary(of: [workout], now: sunday, calendar: ny).workoutCount == 0)
        #expect(WeekSummaryMath.summary(of: [workout], now: sunday, calendar: ny).days.first?.isToday == true)
    }
}
