import Foundation

// Milestone 9, ticket 03 — the month grids behind History's calendar.
//
// Pure: dates in, rows of cells out. The view only draws. Month arithmetic is
// where calendars go quietly wrong — a month that starts on the locale's last
// weekday, a DST day that is 23 hours long, a first weekday that is Monday
// in one locale and Sunday in another — and none of that can be proven from
// a screenshot, so it lives here with tests.

struct WorkoutCalendar: Equatable {

    struct Day: Equatable, Identifiable {
        var id: Date { date }
        /// Start of the day in the calendar used to build the grid.
        let date: Date
        let dayOfMonth: Int
        /// At least one finished workout STARTED on this day. Start day, not
        /// finish day, because that is the date everything else in History
        /// uses — the list's month groups, the row's date, the detail's title
        /// — and a calendar that marked the 3rd for a session the list files
        /// under the 2nd (a 23:30 start) would open into a screen that
        /// disagrees with it.
        let isMarked: Bool
        let isToday: Bool
        /// Dimmed: nothing can be marked here yet.
        let isFuture: Bool
    }

    struct Month: Equatable, Identifiable {
        var id: Date { start }
        /// Start of the month.
        let start: Date
        /// "Aug 2026" in the calendar's locale.
        let title: String
        /// Cells in weekday order, exactly `rows × 7`, with nil for the
        /// leading and trailing padding so every week is a full row.
        let cells: [Day?]
        var rows: Int { cells.count / 7 }
    }

    /// Weekday symbols starting at the calendar's `firstWeekday` — the column
    /// headings.
    let weekdaySymbols: [String]
    /// Oldest first, so a list scrolls down towards today.
    let months: [Month]

    /// - Parameters:
    ///   - startedAt: the start times of the FINISHED workouts to mark (the
    ///     caller filters; a running workout is not history).
    ///   - today: the reference "now"; months run from the first marked
    ///     month (or today's) through today's month, never beyond.
    init(startedAt: [Date], today: Date = .now, calendar: Calendar = .current) {
        let markedDays = Set(startedAt.map { calendar.startOfDay(for: $0) })
        let todayStart = calendar.startOfDay(for: today)

        let firstDay = markedDays.min().map { min($0, todayStart) } ?? todayStart
        let firstMonth = Self.monthStart(of: firstDay, calendar: calendar)
        let lastMonth = Self.monthStart(of: todayStart, calendar: calendar)

        var months: [Month] = []
        var cursor = firstMonth
        // Bounded by the span between the first mark and today; the guard
        // exists only so a pathological future `finishedAt` cannot loop.
        while cursor <= lastMonth, months.count < 1_200 {
            months.append(Self.month(
                starting: cursor, markedDays: markedDays,
                today: todayStart, calendar: calendar))
            guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else { break }
            cursor = next
        }
        self.months = months

        // Rotate the symbols so the locale's first weekday leads. `firstWeekday`
        // is 1-based (1 = Sunday) regardless of locale; the symbols are 0-based.
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let offset = (calendar.firstWeekday - 1) % 7
        self.weekdaySymbols = Array(symbols[offset...] + symbols[..<offset])
    }

    // MARK: - Building one month

    private static func monthStart(of date: Date, calendar: Calendar) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    private static func month(
        starting start: Date, markedDays: Set<Date>, today: Date, calendar: Calendar
    ) -> Month {
        let dayCount = calendar.range(of: .day, in: .month, for: start)?.count ?? 30
        // How many blank cells precede day 1 so it lands under its weekday.
        // weekday is 1-based from Sunday; shift by the locale's first weekday.
        let weekdayOfFirst = calendar.component(.weekday, from: start)
        let leading = (weekdayOfFirst - calendar.firstWeekday + 7) % 7

        var cells: [Day?] = Array(repeating: nil, count: leading)
        for offset in 0..<dayCount {
            // `date(byAdding: .day)` rather than adding 86_400 s: a DST day is
            // 23 or 25 hours long, and seconds arithmetic drifts off midnight.
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            let dayStart = calendar.startOfDay(for: date)
            cells.append(Day(
                date: dayStart,
                dayOfMonth: offset + 1,
                isMarked: markedDays.contains(dayStart),
                isToday: dayStart == today,
                isFuture: dayStart > today))
        }
        while cells.count % 7 != 0 { cells.append(nil) }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("MMM yyyy")
        return Month(start: start, title: formatter.string(from: start), cells: cells)
    }

    // MARK: - Picking a session

    /// The workout to open for a tapped day: the LATEST-started finished
    /// workout that began on that day — the same day rule as the marks. Two
    /// sessions on one day is rare and the ticket chose not to build a day
    /// list for it; the newest is what the user most likely means, and the
    /// other is one row away in the list.
    static func workoutToOpen(
        on day: Date, among workouts: [Workout], calendar: Calendar = .current
    ) -> Workout? {
        let dayStart = calendar.startOfDay(for: day)
        return workouts
            .filter { !$0.isDeleted && $0.finishedAt != nil }
            .filter { calendar.startOfDay(for: $0.startedAt) == dayStart }
            .max { $0.startedAt < $1.startedAt }
    }
}
