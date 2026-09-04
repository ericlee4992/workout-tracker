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
        XCTAssertTrue(day.waitForExistence(timeout: 10), "yesterday should be a tappable marked day")
        day.tap()

        // The session detail: its Name row (ticket 02) proves we are on a
        // WorkoutDetailView, and the nav title is the session's date.
        let nameRow = app.buttons["historyWorkoutName"]
        XCTAssertTrue(nameRow.waitForExistence(timeout: 10), "tapping a marked day should open that session")
        let title = yesterday.formatted(date: .abbreviated, time: .omitted)
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5), "should be yesterday's session, expected title '\(title)'")

        let after = XCTAttachment(screenshot: app.screenshot())
        after.name = "history-calendar-opened"
        after.lifetime = .keepAlways
        add(after)
    }

    /// An empty store: the calendar still opens, shows this month, marks nothing.
    func testCalendarOpensWithNoHistory() {
        let empty = XCUIApplication()
        empty.launchArguments = ["-uiTestReset"]
        empty.launch()
        empty.tabBars.buttons["History"].tap()
        let button = empty.buttons["historyCalendar"]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        button.tap()
        XCTAssertTrue(empty.staticTexts.matching(identifier: "calendarMonth").firstMatch.waitForExistence(timeout: 10))
        let todayKey = Self.key(.now)
        XCTAssertTrue(empty.descendants(matching: .any).matching(identifier: "calendarDay.\(todayKey)").firstMatch.exists)
        XCTAssertEqual(empty.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'calendarDay.'")).count, 0,
                       "no marked (tappable) days without history")
    }

    private static func key(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
