import XCTest

/// PROTOTYPE (nutrition 16, throwaway; removed with `TodayDayPrototype.swift`): taps through the pick-a-day prototype
/// so its flows are checked by real taps — pick a past day, log a food to it, back to today; earlier weeks; the day
/// page option.
final class TodayDayPrototypeUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(_ extra: [String] = []) {
        app.launchArguments = ["-uiTestReset", "-uiTestDesignSample", "-uiTestFoodSample", "-uiTestFoodDiary",
                               "-uiTestPersonalDetails", "-appearance", "light", "-todayPickDayPrototype"] + extra
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["todayEaten"].waitForExistence(timeout: 15))
    }

    private func shoot(_ name: String) {
        Thread.sleep(forTimeInterval: 0.6)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private static func id(_ date: Date) -> String {
        "todayDay." + date.formatted(.iso8601.year().month().day())
    }

    /// A past day of this week (three days back, or the week's first day).
    private func pastDayThisWeek() throws -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)!.start
        let day = max(weekStart, calendar.date(byAdding: .day, value: -3, to: today)!)
        if day == today { throw XCTSkip("Today is the week's first day: no past day this week") }
        return day
    }

    private func entries(_ name: String) -> Int {
        app.buttons.matching(identifier: "todayEntry.\(name)").count
    }

    func testPickAPastDayAndLogToIt() throws {
        launch()
        let day = try pastDayThisWeek()
        let weekday = day.formatted(.dateTime.weekday(.wide))
        let todaysBananas = entries("Banana")
        app.buttons[Self.id(day)].tap()
        XCTAssertTrue(app.staticTexts[weekday].waitForExistence(timeout: 5), "the title is the picked day")
        XCTAssertTrue(app.buttons["todayBackToToday"].exists)
        XCTAssertEqual(app.buttons["logFoodPill"].label, "Log to \(weekday)")
        XCTAssertFalse(app.buttons["scanFoodButton"].exists, "no scan on a past day (prototype)")
        XCTAssertFalse(app.buttons["todayStartUpNext"].exists, "no Up next on a past day")
        XCTAssertEqual(entries("Banana"), 0)
        shoot("1-past-day")

        app.buttons["logFoodPill"].tap()
        XCTAssertTrue(app.staticTexts[day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())]
            .waitForExistence(timeout: 5), "Log food says which day")
        XCTAssertFalse(app.buttons["logFoodScan"].exists)
        shoot("2-log-food")
        app.buttons["logFoodAdd.Banana"].firstMatch.tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()

        XCTAssertTrue(app.buttons["todayEntry.Banana"].waitForExistence(timeout: 5), "logged to the picked day")
        shoot("3-logged")
        app.buttons["todayBackToToday"].tap()
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 5))
        XCTAssertEqual(entries("Banana"), todaysBananas, "today unchanged")
        XCTAssertEqual(app.buttons["logFoodPill"].label, "Log food")
        XCTAssertTrue(app.buttons["scanFoodButton"].exists)
    }

    func testEarlierWeeks() {
        launch(["-todayPickDayPrototypeRange", "earlier"])
        XCTAssertFalse(app.buttons["todayWeekNext"].isEnabled, "no week ahead")
        app.buttons["todayWeekPrevious"].tap()
        XCTAssertTrue(app.staticTexts["Last week"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["todayBackToToday"].exists, "the same weekday of last week is picked")
        shoot("4-last-week")
        app.otherElements["todayWeek"].firstMatch.swipeRight()
        XCTAssertFalse(app.staticTexts["Last week"].waitForExistence(timeout: 2), "swiped further back")
        shoot("5-two-weeks-back")
        app.buttons["todayBackToToday"].tap()
        XCTAssertTrue(app.staticTexts["This week"].waitForExistence(timeout: 5))
    }

    func testDayPageOption() throws {
        launch(["-todayPickDayPrototypeOpens", "page"])
        let day = try pastDayThisWeek()
        app.buttons[Self.id(day)].tap()
        XCTAssertTrue(app.buttons["logFoodPill"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["logFoodPill"].label, "Log to \(day.formatted(.dateTime.weekday(.wide)))")
        shoot("6-day-page")
    }
}
