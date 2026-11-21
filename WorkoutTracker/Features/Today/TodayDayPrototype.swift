import SwiftData
import SwiftUI

// PROTOTYPE (nutrition 16, throwaway): picking a day on Today to see it and log food to it, on sample data, for the
// user to check (D92). Round 2 (the user's answers, 2026-11-20): Today turns into the picked day; a "Back to Today"
// strip under the week; earlier weeks (‹ › and a swipe); Log food and the scan camera look the same on every day and
// log to the day shown — a scan too, a library photo included (the picked day wins over its own date). Shown only
// under `-uiTestReset -todayPickDayPrototype` with the food sample (`-uiTestDesignSample -uiTestFoodSample
// -uiTestFoodDiary -uiTestPersonalDetails`; add `-uiTestTerra` so scans are answered on the phone). Logging really
// writes to the sample store (reset on every launch); no schema change. Removed once approved; the kept parts are
// `TodayWeekRings`' selection and chevrons and Today's past-day layout (`TodayView`, behind `dayPick`).
//
// Hooks, each marked `PROTOTYPE (nutrition 16)` and a no-op without the flag: `TodayView` (the picked day, the
// switcher), `LogFoodView` / `SelectedFoodView` / `SelectedMealView` / `FoodScanFlow` / `FoodScanQueue` (log at the
// picked day), `WorkoutTrackerApp.prepare` (the seed).
//
// Capture arguments: `-todayPickDayPrototypeDay <days back>` picks that day at launch;
// `-todayPickDayPrototypeCapture` hides the switcher (light/dark only).

@Observable
@MainActor
final class TodayDayPrototype {
    static let shared = TodayDayPrototype()
    nonisolated static let launchArgument = "-todayPickDayPrototype"
    nonisolated static var isEnabled: Bool { WorkoutTrackerStore.fixtureIsEnabled(launchArgument) }
    nonisolated static var hidesSwitcher: Bool {
        ProcessInfo.processInfo.arguments.contains("-todayPickDayPrototypeCapture")
    }

    /// The day Today shows (its start); nil = today, which follows the clock across midnight.
    var selectedDay: Date?
    /// 0 = this week, -1 = last week, …
    var weekOffset = 0
    /// The day Log food logs to, set by the pill that opened it; nil = now.
    var logDay: Date?

    private init() {
        let arguments = ProcessInfo.processInfo.arguments
        func argument(_ flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
            return arguments[index + 1]
        }
        if let back = argument("-todayPickDayPrototypeDay").flatMap(Int.init), back > 0,
           let day = Calendar.current.date(byAdding: .day, value: -back, to: Calendar.current.startOfDay(for: .now)) {
            selectedDay = day
            weekOffset = Self.weekOffset(of: day, now: .now)
        }
    }

    // MARK: Picking

    /// A day's ring: Today shows it (today itself → nil).
    func pick(_ day: Date, now: Date) {
        let calendar = Calendar.current
        selectedDay = calendar.isDate(day, inSameDayAs: now) ? nil : calendar.startOfDay(for: day)
    }

    /// The chevrons and the swipe: the week moves and the same weekday of that week is picked (never past today).
    func moveWeek(by step: Int, now: Date) {
        let calendar = Calendar.current
        let target = min(0, weekOffset + step)
        guard target != weekOffset else { return }
        weekOffset = target
        let anchor = selectedDay ?? calendar.startOfDay(for: now)
        guard let day = calendar.date(byAdding: .weekOfYear, value: step, to: anchor) else { return }
        selectedDay = day >= calendar.startOfDay(for: now) ? nil : day
    }

    func backToToday() {
        selectedDay = nil
        weekOffset = 0
    }

    static func weekOffset(of day: Date, now: Date, calendar: Calendar = .current) -> Int {
        guard let shown = calendar.dateInterval(of: .weekOfYear, for: day)?.start,
              let current = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return 0 }
        return calendar.dateComponents([.weekOfYear], from: current, to: shown).weekOfYear ?? 0
    }

    /// The week shown: this week as Today builds it, or an earlier one with no day marked today or ahead.
    static func week(offset: Int, workouts: [Workout], now: Date, calendar: Calendar = .current) -> WeekSummary {
        guard offset < 0, let anchor = calendar.date(byAdding: .weekOfYear, value: offset, to: now) else {
            return WeekSummaryMath.summary(ofWorkouts: workouts, now: now, calendar: calendar)
        }
        var summary = WeekSummaryMath.summary(ofWorkouts: workouts, now: anchor, calendar: calendar)
        summary.days = summary.days.map { day in
            var day = day
            day.isToday = false
            day.isFuture = false
            return day
        }
        return summary
    }

    /// "This week", "Last week", "Nov 1 – 7".
    static func weekTitle(offset: Int, now: Date, calendar: Calendar = .current) -> String {
        switch offset {
        case 0: return "This week"
        case -1: return "Last week"
        default:
            guard let anchor = calendar.date(byAdding: .weekOfYear, value: offset, to: now),
                  let week = calendar.dateInterval(of: .weekOfYear, for: anchor) else { return "Earlier" }
            let last = week.end.addingTimeInterval(-1)
            return week.start.formatted(.dateTime.month(.abbreviated).day()) + " – "
                + last.formatted(calendar.isDate(week.start, equalTo: last, toGranularity: .month)
                                 ? .dateTime.day() : .dateTime.month(.abbreviated).day())
        }
    }

    // MARK: Logging to the picked day

    /// When a food logged now goes: now, or — logging to a picked past day — that day at the meal's usual time
    /// (Breakfast 8:00, Lunch 12:30, Snacks 3:30 PM, Dinner 6:30 PM). Rows show no time; the time orders a meal's
    /// entries and is the time Apple Health gets. The prototype back-dates the entry's `createdAt` and the food's
    /// "last used" too (`FoodLog.log(at:)` sets all three); the real build keeps those at now.
    static func logDate(for meal: MealSlot, now: Date = .now) -> Date {
        logDate(for: meal, otherwise: now)
    }

    /// The scans: the picked day at the meal's time, or `otherwise` (now, or a library photo's own time — D83(9)).
    static func logDate(for meal: MealSlot, otherwise: Date) -> Date {
        guard isEnabled, let day = shared.logDay else { return otherwise }
        return mealTime(meal, on: day)
    }

    static func mealTime(_ meal: MealSlot, on day: Date, calendar: Calendar = .current) -> Date {
        let minutes = switch meal {
        case .breakfast: 8 * 60
        case .lunch: 12 * 60 + 30
        case .snacks: 15 * 60 + 30
        case .dinner: 18 * 60 + 30
        }
        return calendar.startOfDay(for: day).addingTimeInterval(Double(minutes * 60))
    }

    /// Log food's subtitle: "Tuesday, Nov 18" while logging to a past day.
    static var logDaySubtitle: String? {
        guard isEnabled, let day = shared.logDay else { return nil }
        return day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    /// Log food's and the camera's target, set when either is tapped on Today: a past day, or nil for today (now).
    static func setLogDay(_ day: Date?, now: Date = .now) {
        guard isEnabled else { return }
        shared.logDay = day.flatMap { Calendar.current.isDate($0, inSameDayAs: now) ? nil : Calendar.current.startOfDay(for: $0) }
    }

    // MARK: Seed

    /// After the food diary: three earlier weeks of food (a day with nothing every fifth day), and the goal in force
    /// from before them, so last week and earlier have rings to pick even early in this week.
    static func seed(in context: ModelContext, now: Date = .now, calendar: Calendar = .current) throws {
        let foods = try context.fetch(FetchDescriptor<SavedFood>())
        func food(_ name: String) -> SavedFood? { foods.first { $0.name == name } }
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? calendar.startOfDay(for: now)
        guard let from = calendar.date(byAdding: .day, value: -21, to: weekStart),
              let goalFrom = calendar.date(byAdding: .day, value: -1, to: from) else { return }
        for goal in try context.fetch(FetchDescriptor<NutritionGoal>()) where goal.effectiveFrom > goalFrom {
            goal.effectiveFrom = goalFrom
        }
        var day = from
        var index = 0
        while day < weekStart {
            defer {
                index += 1
                day = calendar.date(byAdding: .day, value: 1, to: day) ?? weekStart
            }
            if index % 5 == 3 { continue }
            let picks: [(String, Double, MealSlot)] = index % 3 == 1
                ? [("Greek yogurt", 1, .breakfast), ("Chicken breast", 2, .lunch), ("Turkey chili", 1.5, .dinner)]
                : [("Overnight oats", 1, .breakfast), ("Chicken breast", 2.5, .lunch), ("Protein shake", 1, .snacks),
                   ("Turkey chili", 2, .dinner)]
            for pick in picks {
                if let food = food(pick.0) {
                    context.insert(FoodEntry(logging: food, servings: pick.1, meal: pick.2,
                                             at: mealTime(pick.2, on: day, calendar: calendar)))
                }
            }
        }
        try context.save()
    }
}

// MARK: - The strip

/// "Showing Tuesday, Nov 18" with Back to Today, under the week while a past day is shown.
struct TodayDayPrototypeStrip: View {
    var day: Date
    var back: () -> Void
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 12))
        layout {
            Text("Showing \(day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))")
                .font(look.font.subhead.weight(.semibold))
                .foregroundStyle(look.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: back) {
                Label("Back to Today", systemImage: "arrow.uturn.backward")
                    .font(look.font.footnote.weight(.semibold))
                    .foregroundStyle(look.onAction)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 36)
                    .background(look.action, in: Capsule())
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.lookPressable)
            .accessibilityIdentifier("todayBackToToday")
        }
        .padding(.horizontal, look.space.panelPadding)
        .padding(.vertical, 8)
        .lookSurface(.panel)
    }
}

// MARK: - The switcher (over Today)

private struct TodayDayPrototypeSwitcher: ViewModifier {
    @State private var state = TodayDayPrototype.shared

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top, spacing: 0) {
                if !TodayDayPrototype.hidesSwitcher { TodayDayPrototypeMenu() }
            }
    }
}

private struct TodayDayPrototypeMenu: View {
    @State private var state = TodayDayPrototype.shared
    @AppStorage(AppearanceSetting.key) private var appearanceRaw = Appearance.system.rawValue

    var body: some View {
        Menu {
            Picker("Appearance", selection: $appearanceRaw) {
                ForEach(Appearance.allCases) { Text($0.label).tag($0.rawValue) }
            }
            .pickerStyle(.menu)
        } label: {
            Text("Prototype · Pick a day")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color.orange, in: Capsule())
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("todayDayPrototypeSwitcher")
    }
}

extension View {
    /// On Today.
    @ViewBuilder func todayDayPrototypeSwitcher() -> some View {
        if TodayDayPrototype.isEnabled { modifier(TodayDayPrototypeSwitcher()) } else { self }
    }
}
