import XCTest

/// PROTOTYPE (nutrition 16, throwaway; removed with `TodayDayPrototype.swift`): taps through the pick-a-day prototype
/// (round 2) so its flows are checked by real taps — pick a past day, log a food to it, scan to it, back to today;
/// earlier weeks.
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

    /// Scrolls until the element is on screen.
    private func reveal(_ element: XCUIElement, maxSwipes: Int = 8) {
        var swipes = 0
        while !(element.exists && element.isHittable) && swipes < maxSwipes {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(element.exists, "not found: \(element)")
    }

    func testPickAPastDayAndLogToIt() throws {
        launch()
        let day = try pastDayThisWeek()
        let weekday = day.formatted(.dateTime.weekday(.wide))
        let todaysBananas = entries("Banana")
        app.buttons[Self.id(day)].tap()
        XCTAssertTrue(app.staticTexts[weekday].waitForExistence(timeout: 5), "the title is the picked day")
        XCTAssertTrue(app.buttons["todayBackToToday"].exists, "the strip")
        XCTAssertTrue(app.buttons["scanFoodButton"].exists, "the camera stays")
        XCTAssertFalse(app.buttons["todayStartUpNext"].exists, "no Up next on a past day")
        XCTAssertEqual(entries("Banana"), 0)
        shoot("1-past-day")

        app.buttons["logFoodPill"].tap()
        XCTAssertTrue(app.staticTexts[day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())]
            .waitForExistence(timeout: 5), "Log food says which day")
        XCTAssertTrue(app.buttons["logFoodScan"].exists, "Log food's camera stays")
        shoot("2-log-food")
        app.buttons["logFoodAdd.Banana"].firstMatch.tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()

        XCTAssertTrue(app.buttons["todayEntry.Banana"].waitForExistence(timeout: 5), "logged to the picked day")
        shoot("3-logged")
        app.buttons["todayBackToToday"].tap()
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 5))
        XCTAssertEqual(entries("Banana"), todaysBananas, "today unchanged")
    }

    /// A camera photo and a library photo on a past day both land on that day (the user, 2026-11-20).
    func testScansLogToThePickedDay() throws {
        launch(["-uiTestTerra"])
        let day = try pastDayThisWeek()
        app.buttons[Self.id(day)].tap()
        XCTAssertTrue(app.buttons["todayBackToToday"].waitForExistence(timeout: 5))
        app.buttons["scanFoodButton"].tap()
        XCTAssertTrue(app.buttons["scanFoodShutter"].waitForExistence(timeout: 5))
        app.buttons["scanFoodShutter"].tap()
        let entry = app.buttons["todayEntry.Poke bowl"]
        XCTAssertTrue(entry.waitForExistence(timeout: 15), "a camera photo is logged to the picked day")
        reveal(entry)
        shoot("4-scan-logged")

        app.buttons["scanFoodButton"].tap()
        XCTAssertTrue(app.buttons["scanFoodLibrary"].waitForExistence(timeout: 5))
        app.buttons["scanFoodLibrary"].tap()
        let deadline = Date.now.addingTimeInterval(15)
        while entries("Poke bowl") < 2 && Date.now < deadline { Thread.sleep(forTimeInterval: 0.5) }
        XCTAssertEqual(entries("Poke bowl"), 2, "a library photo goes to the picked day too")

        app.swipeDown(); app.swipeDown(); app.swipeDown()
        app.buttons["todayBackToToday"].tap()
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 5))
        XCTAssertEqual(entries("Poke bowl"), 0, "nothing on today")
    }

    func testEarlierWeeks() {
        launch()
        XCTAssertFalse(app.buttons["todayWeekNext"].isEnabled, "no week ahead")
        app.buttons["todayWeekPrevious"].tap()
        XCTAssertTrue(app.staticTexts["Last week"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["todayBackToToday"].exists, "the same weekday of last week is picked")
        shoot("5-last-week")
        app.otherElements["todayWeek"].firstMatch.swipeRight()
        XCTAssertFalse(app.staticTexts["Last week"].waitForExistence(timeout: 2), "swiped further back")
        shoot("6-two-weeks-back")
        app.buttons["todayBackToToday"].tap()
        XCTAssertTrue(app.staticTexts["This week"].waitForExistence(timeout: 5))
    }
}
