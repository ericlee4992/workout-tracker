import Foundation
import Testing

@testable import WorkoutTracker

/// Milestone 9, ticket 03 — the grid maths behind History's calendar.
struct WorkoutCalendarTests {

    private func calendar(firstWeekday: Int, tz: String = "America/Los_Angeles") -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = firstWeekday
        c.timeZone = TimeZone(identifier: tz)!
        c.locale = Locale(identifier: "en_US")
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, in c: Calendar) -> Date {
        c.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    // MARK: Shape

    /// Every month is whole weeks: leading blanks put day 1 under its weekday
    /// and trailing blanks square the last row off.
    @Test func monthsAreWholeWeeksWithDayOneUnderItsWeekday() {
        // Sunday-first. 1 Aug 2026 is a Saturday → 6 blanks before it.
        let c = calendar(firstWeekday: 1)
        let today = date(2026, 8, 20, in: c)
        let cal = WorkoutCalendar(startedAt: [], today: today, calendar: c)
        let aug = cal.months.last!
        #expect(aug.cells.count % 7 == 0)
        #expect(aug.cells.prefix(6).allSatisfy { $0 == nil })
        #expect(aug.cells[6]?.dayOfMonth == 1)
        #expect(aug.cells.compactMap { $0 }.count == 31)
    }

    /// Monday-first shifts the same month by one column: Saturday 1 Aug is
    /// now the 6th cell (index 5), not the 7th.
    @Test func mondayFirstLocaleShiftsTheColumns() {
        let c = calendar(firstWeekday: 2)
        let today = date(2026, 8, 20, in: c)
        let cal = WorkoutCalendar(startedAt: [], today: today, calendar: c)
        let aug = cal.months.last!
        #expect(aug.cells.prefix(5).allSatisfy { $0 == nil })
        #expect(aug.cells[5]?.dayOfMonth == 1)
        #expect(cal.weekdaySymbols.first == "M", "the heading row must lead with the locale's first weekday")
        #expect(cal.weekdaySymbols.count == 7)
    }

    /// Months run from the first marked month through today's, never past it.
    @Test func monthsSpanFromTheFirstMarkToToday() {
        let c = calendar(firstWeekday: 1)
        let today = date(2026, 9, 3, in: c)
        let cal = WorkoutCalendar(
            startedAt: [date(2026, 6, 15, in: c), date(2026, 8, 20, in: c)], today: today, calendar: c)
        #expect(cal.months.map(\.title) == ["Jun 2026", "Jul 2026", "Aug 2026", "Sep 2026"])
    }

    @Test func noHistoryShowsJustThisMonthWithNoMarks() {
        let c = calendar(firstWeekday: 1)
        let cal = WorkoutCalendar(startedAt: [], today: date(2026, 9, 3, in: c), calendar: c)
        #expect(cal.months.count == 1)
        #expect(cal.months[0].cells.compactMap { $0 }.allSatisfy { !$0.isMarked })
    }

    // MARK: Marks

    /// A workout belongs to the day it STARTED — the date the rest of History
    /// files it under. A 23:30 session that ends after midnight marks the
    /// day it began, and only that day.
    @Test func marksFollowTheStartDay() {
        let c = calendar(firstWeekday: 1)
        let today = date(2026, 8, 25, in: c)
        let started = date(2026, 8, 20, 23, in: c).addingTimeInterval(30 * 60)  // 23:30 on the 20th
        let cal = WorkoutCalendar(startedAt: [started], today: today, calendar: c)
        let aug = cal.months.last!.cells.compactMap { $0 }
        #expect(aug.first { $0.dayOfMonth == 20 }?.isMarked == true)
        #expect(aug.first { $0.dayOfMonth == 21 }?.isMarked == false)
    }

    @Test func todayAndFutureAreFlagged() {
        let c = calendar(firstWeekday: 1)
        let cal = WorkoutCalendar(startedAt: [], today: date(2026, 9, 3, in: c), calendar: c)
        let sep = cal.months.last!.cells.compactMap { $0 }
        #expect(sep.first { $0.dayOfMonth == 3 }?.isToday == true)
        #expect(sep.first { $0.dayOfMonth == 4 }?.isFuture == true)
        #expect(sep.first { $0.dayOfMonth == 2 }?.isFuture == false)
    }

    /// The DST transition day in Los Angeles (8 Nov 2026 is 25 hours long).
    /// Seconds arithmetic would put day 9 at 01:00 and break `startOfDay`
    /// equality; the calendar must still yield 30 distinct days, each a
    /// midnight, with the mark landing on the right one.
    @Test func aDSTMonthStillHasEveryDayAtMidnight() {
        let c = calendar(firstWeekday: 1)
        let today = date(2026, 11, 20, in: c)
        let started = date(2026, 11, 9, 7, in: c)
        let cal = WorkoutCalendar(startedAt: [started], today: today, calendar: c)
        let nov = cal.months.last!.cells.compactMap { $0 }
        #expect(nov.count == 30)
        #expect(nov.allSatisfy { c.startOfDay(for: $0.date) == $0.date })
        #expect(nov.map(\.dayOfMonth) == Array(1...30))
        #expect(nov.first { $0.dayOfMonth == 9 }?.isMarked == true)
        #expect(nov.first { $0.dayOfMonth == 8 }?.isMarked == false)
    }

    /// codex-review 03: a marked today must be BOTH — the first view branched
    /// on marked first and today lost its highlight the moment a workout was
    /// logged, which is the most common state after finishing one.
    @Test func aMarkedTodayIsBothMarkedAndToday() {
        let c = calendar(firstWeekday: 1)
        let today = date(2026, 9, 3, in: c)
        let cal = WorkoutCalendar(startedAt: [date(2026, 9, 3, 7, in: c), date(2026, 9, 1, in: c)], today: today, calendar: c)
        let sep = cal.months.last!.cells.compactMap { $0 }
        #expect(sep.first { $0.dayOfMonth == 3 }?.emphasis == .markedToday)
        #expect(sep.first { $0.dayOfMonth == 1 }?.emphasis == .marked)
        #expect(sep.first { $0.dayOfMonth == 2 }?.emphasis == .plain)
        #expect(sep.first { $0.dayOfMonth == 4 }?.emphasis == .future)
    }

    /// No iteration cap: an ancient (corrupt) timestamp yields a long calendar
    /// that still ENDS on today's month — the cap that used to exist could
    /// stop decades early and open the sheet there (codex-review 03).
    @Test func anAncientMarkStillReachesTodaysMonth() {
        let c = calendar(firstWeekday: 1)
        let today = date(2026, 9, 3, in: c)
        let cal = WorkoutCalendar(startedAt: [date(1900, 1, 15, in: c)], today: today, calendar: c)
        #expect(cal.months.count == (2026 - 1900) * 12 + 9)
        #expect(cal.months.last?.title == "Sep 2026")
        #expect(cal.months.first?.title == "Jan 1900")
    }

    // MARK: Which session opens

    @Test @MainActor func theLatestSessionStartedOnADayOpensAndOtherDaysDoNot() {
        let c = calendar(firstWeekday: 1)
        let morning = Workout(startedAt: date(2026, 8, 20, 7, in: c), finishedAt: date(2026, 8, 20, 8, in: c))
        // Starts on the 20th, ends on the 21st: filed under the 20th, like the list.
        let late = Workout(startedAt: date(2026, 8, 20, 23, in: c), finishedAt: date(2026, 8, 21, 0, in: c).addingTimeInterval(900))
        let other = Workout(startedAt: date(2026, 8, 21, 7, in: c), finishedAt: date(2026, 8, 21, 8, in: c))
        let running = Workout(startedAt: date(2026, 8, 20, 20, in: c))
        let picked = WorkoutCalendar.workoutToOpen(
            on: date(2026, 8, 20, 0, in: c), among: [morning, other, running, late], calendar: c)
        #expect(picked === late)
        #expect(WorkoutCalendar.workoutToOpen(on: date(2026, 8, 22, in: c), among: [morning, late], calendar: c) == nil)
    }

    // MARK: What the sheet's dismissal pushes

    @Test @MainActor func aDeletedOrRunningPickIsDroppedAndAPendingTargetWins() {
        let c = calendar(firstWeekday: 1)
        let finished = Workout(startedAt: date(2026, 8, 20, in: c), finishedAt: date(2026, 8, 20, 13, in: c))
        let running = Workout(startedAt: date(2026, 8, 20, in: c))
        #expect(WorkoutCalendar.destinationAfterCalendar(pick: finished, otherNavigationPending: false) === finished)
        #expect(WorkoutCalendar.destinationAfterCalendar(pick: running, otherNavigationPending: false) == nil)
        #expect(WorkoutCalendar.destinationAfterCalendar(pick: nil, otherNavigationPending: false) == nil)
        #expect(WorkoutCalendar.destinationAfterCalendar(pick: finished, otherNavigationPending: true) == nil,
                "a C2 View-in-History request that arrived while the sheet was up must not be overwritten")
    }
}
