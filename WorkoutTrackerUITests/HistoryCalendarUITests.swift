import XCTest

/// Milestone 9, ticket 03 — the History calendar, on the chart fixture so
/// there are marked days in the past to tap.
final class HistoryCalendarUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestReset", "-uiTestChartHistory"]
        app.launch()
    }

    /// Open the calendar, tap yesterday (the fixture's newest session), and
    /// land on that session's detail.
    func testTappingAMarkedDayOpensThatSession() {
        app.tabBars.buttons["History"].tap()
        let button = app.buttons["historyCalendar"]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        button.tap()

        let sheet = app.descendants(matching: .any).matching(identifier: "historyCalendarSheet").firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 10), "the calendar sheet should open")
        XCTAssertTrue(app.staticTexts.matching(identifier: "calendarMonth").firstMatch.exists)

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "history-calendar"
        shot.lifetime = .keepAlways
        add(shot)

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        let key = Self.key(yesterday)
        let day = app.buttons["calendarDay.\(key)"]
        XCTAssertTrue(day.waitForExistence(timeout: 10), "yesterday should be a marked day")
        day.tap()
        // Floodlight ticket 05: a tap SELECTS the day and lists its workouts; a row opens one.
        let workout = app.descendants(matching: .any).matching(identifier: "calendarWorkoutRow").firstMatch
        XCTAssertTrue(workout.waitForExistence(timeout: 5), "the selected day lists its workout")
        workout.tap()

        // The session detail: its title button (ticket 02) proves we are on a
        // WorkoutDetailView, and its date line says which day.
        let nameRow = app.buttons["historyWorkoutName"]
        XCTAssertTrue(nameRow.waitForExistence(timeout: 10), "tapping the day's workout should open that session")
        let date = app.staticTexts["historyWorkoutDate"]
        let expected = yesterday.formatted(.dateTime.month(.abbreviated).day())
        XCTAssertTrue(date.label.contains(expected), "should be yesterday's session, expected '\(expected)' in '\(date.label)'")

        let after = XCTAttachment(screenshot: app.screenshot())
        after.name = "history-calendar-opened"
        after.lifetime = .keepAlways
        add(after)
    }

    /// A day with nothing on it can be selected and says so; the calendar pages to other months.
    func testAnEmptyDayIsSelectableAndMonthsPage() {
        app.tabBars.buttons["History"].tap()
        app.buttons["historyCalendar"].tap()
        XCTAssertTrue(app.staticTexts.matching(identifier: "calendarMonth").firstMatch.waitForExistence(timeout: 10))
        let today = app.buttons["calendarDay.\(Self.key(.now))"]
        XCTAssertTrue(today.waitForExistence(timeout: 5))
        today.tap()
        XCTAssertTrue(app.staticTexts["No workouts"].waitForExistence(timeout: 5), "today has no workout in the fixture")
        let month = app.staticTexts.matching(identifier: "calendarMonth").firstMatch.label
        app.buttons["Previous month"].tap()
        let previous = app.staticTexts.matching(identifier: "calendarMonth").firstMatch
        XCTAssertTrue(previous.waitForExistence(timeout: 5))
        XCTAssertNotEqual(previous.label, month, "the chevron shows the previous month")
    }

    /// An empty store: no calendar until the first workout (the user's decision, 2026-09-27);
    /// the empty screen's Start Lifting runs the Workout tab's start.
    func testEmptyHistoryHasNoCalendarAndStartsLifting() {
        let empty = XCUIApplication()
        empty.launchArguments = ["-uiTestReset"]
        empty.launch()
        empty.tabBars.buttons["History"].tap()
        let start = empty.buttons["historyStartLifting"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        XCTAssertFalse(empty.buttons["historyCalendar"].exists, "nothing to show on a calendar yet")
        start.tap()
        // The Workout tab's own start: a workout opens (or its gym question first).
        let opened = empty.buttons["finishWorkout"]
        let gymQuestion = empty.sheets.firstMatch
        XCTAssertTrue(opened.waitForExistence(timeout: 10) || gymQuestion.exists, "Start Lifting starts a workout")
    }

    private static func key(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
