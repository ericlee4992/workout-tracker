import Foundation

/// Nutrition N16 (D92): the day Today shows and the week its rings show. Tapping a ring picks a past day (Today turns
/// into that day; tapping today's ring goes back); ‹ › and a swipe move the rings a week, picking the same weekday.
/// View state only — nothing here is stored.
struct TodayDayPick: Equatable {
    /// The picked day (its start); nil = today, which follows the clock across midnight.
    private(set) var day: Date?
    /// A date in the week the rings show; nil = the current week, which follows the clock across a week's end.
    private(set) var week: Date?

    init() {}

    /// The day Today shows: the picked day while it is still in the past, else `now`.
    func shownDay(now: Date, calendar: Calendar = .current) -> Date {
        guard let day, day < calendar.startOfDay(for: now) else { return now }
        return day
    }

    /// A past day is shown (not today).
    func showsPastDay(now: Date, calendar: Calendar = .current) -> Bool {
        guard let day else { return false }
        return day < calendar.startOfDay(for: now)
    }

    /// The day food logged from Today goes to: the picked past day, or nil for today (logged at now).
    func logDay(now: Date, calendar: Calendar = .current) -> Date? {
        showsPastDay(now: now, calendar: calendar) ? day : nil
    }

    /// The week the rings show: nil for the current one, else a date in that earlier week. Without a week of its own
    /// it is the picked day's, so a day picked this week stays in view when the screen is left open into the next.
    func shownWeek(now: Date, calendar: Calendar = .current) -> Date? {
        guard let shown = week ?? (showsPastDay(now: now, calendar: calendar) ? day : nil),
              Self.weekStart(of: shown, calendar) < Self.weekStart(of: now, calendar) else { return nil }
        return shown
    }

    /// A ring: today → back to today; a past day → that day. A day ahead changes nothing (its ring is not a button).
    mutating func pick(_ date: Date, now: Date, calendar: Calendar = .current) {
        let picked = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: now)
        guard picked <= today else { return }
        if picked == today {
            self = TodayDayPick()
        } else {
            day = picked
            week = Self.weekStart(of: picked, calendar) < Self.weekStart(of: now, calendar) ? picked : nil
        }
    }

    /// ‹ (−1) and › (+1), and the swipe: the rings move a week, never past the current one, and the same weekday of
    /// that week is picked — today or later is today.
    mutating func moveWeek(by step: Int, now: Date, calendar: Calendar = .current) {
        let current = Self.weekStart(of: now, calendar)
        let shown = Self.weekStart(of: shownWeek(now: now, calendar: calendar) ?? now, calendar)
        guard let target = calendar.date(byAdding: .weekOfYear, value: step, to: shown), target <= current,
              target != shown else { return }
        let today = calendar.startOfDay(for: now)
        let from = shownDay(now: now, calendar: calendar)
        let moved = calendar.date(byAdding: .weekOfYear, value: step, to: calendar.startOfDay(for: from)) ?? today
        day = moved < today ? moved : nil
        week = target < current ? target : nil
    }

    /// Back to today when the app returns on another calendar day or after an hour away (D92); a short trip out of the
    /// app, or a tab switch, keeps the pick.
    static func resetsOnReturn(backgroundedAt: Date, now: Date, calendar: Calendar = .current) -> Bool {
        now.timeIntervalSince(backgroundedAt) >= 3_600 || !calendar.isDate(backgroundedAt, inSameDayAs: now)
    }

    /// The rings' title: "This week", "Last week", then the week's dates ("Nov 1 – 7", "Oct 26 – Nov 1").
    static func weekTitle(week: Date?, now: Date, calendar: Calendar = .current) -> String {
        guard let week else { return "This week" }
        let start = weekStart(of: week, calendar)
        let current = weekStart(of: now, calendar)
        if start >= current { return "This week" }
        if calendar.date(byAdding: .weekOfYear, value: -1, to: current) == start { return "Last week" }
        let last = calendar.date(byAdding: .day, value: 6, to: start) ?? start
        let sameMonth = calendar.isDate(start, equalTo: last, toGranularity: .month)
        func style(_ withMonth: Bool) -> Date.FormatStyle {
            var style = withMonth ? Date.FormatStyle.dateTime.month(.abbreviated).day() : .dateTime.day()
            style.calendar = calendar
            style.timeZone = calendar.timeZone
            style.locale = calendar.locale ?? .current
            return style
        }
        return start.formatted(style(true)) + " – " + last.formatted(style(!sameMonth))
    }

    static func weekStart(of date: Date, _ calendar: Calendar) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }
}

/// Nutrition N16 (D92): when food logged to a picked past day is eaten — that day at the meal's usual time. Rows show
/// no time; it orders a meal's entries and is the time Apple Health receives (D74). The entry's `createdAt` and the
/// food's "last used" stay now (`FoodLog`'s `loggedAt:`), so Recently logged is not pushed back.
enum FoodLogDay {
    /// The logged-at time for `meal` on `day`; nil when `day` is nil or not a past day (logged at now, as before).
    static func loggedAt(meal: MealSlot, on day: Date?, now: Date = .now, calendar: Calendar = .current) -> Date? {
        guard let day else { return nil }
        let start = calendar.startOfDay(for: day)
        guard start < calendar.startOfDay(for: now) else { return nil }
        return mealTime(meal, on: start, calendar: calendar)
    }

    /// A label's two times (codex-review-n16 #2): created — the entry, the food saved to My foods and its "last used" —
    /// now; eaten — the picked day at the meal's time, else the photo's own time (D83(9); now for a camera label).
    static func labelTimes(photoEatenAt: Date, meal: MealSlot, day: Date?, now: Date = .now,
                           calendar: Calendar = .current) -> (created: Date, eaten: Date) {
        (now, loggedAt(meal: meal, on: day, now: now, calendar: calendar) ?? photoEatenAt)
    }

    /// Log food's line under its title for a picked day: "Tuesday, Nov 17".
    static func title(_ day: Date) -> String {
        day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    /// Breakfast 8:00, Lunch 12:30, Snacks 3:30 PM, Dinner 6:30 PM.
    static func mealTime(_ meal: MealSlot, on day: Date, calendar: Calendar = .current) -> Date {
        let (hour, minute) = switch meal {
        case .breakfast: (8, 0)
        case .lunch: (12, 30)
        case .snacks: (15, 30)
        case .dinner: (18, 30)
        }
        let start = calendar.startOfDay(for: day)
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: start) ?? start
    }
}
