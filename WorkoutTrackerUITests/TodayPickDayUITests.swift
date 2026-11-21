import XCTest

/// N16 (D92): picking a day on Today — Today turns into that day, Log food and the camera log to it (a library photo
/// too), today's ring goes back, ‹ › and a swipe reach earlier weeks — on record in light at Default and dark at
/// AccessibilityL.
final class TodayPickDayUITests: XCTestCase {
    private var app: XCUIApplication!
    private var tag = ""

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(appearance: String = "light", large: Bool = false, _ extra: [String] = []) {
        tag = "\(appearance)-\(large ? "axl" : "default")"
        app.launchArguments = ["-uiTestReset", "-uiTestDesignSample", "-uiTestFoodSample", "-uiTestFoodDiary",
                               "-uiTestPersonalDetails", "-appearance", appearance] + extra
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] }
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["todayEaten"].waitForExistence(timeout: 15))
    }

    private func shoot(_ name: String) {
        Thread.sleep(forTimeInterval: 0.6)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "n16-\(name)-\(tag)"
        shot.lifetime = .keepAlways
        add(shot)
    }

    private static func id(_ date: Date) -> String {
        "todayDay." + date.formatted(.iso8601.year().month().day())
    }

    private var today: Date { Calendar.current.startOfDay(for: .now) }

    /// A past day of this week (three days back, or the week's first day).
    private func pastDayThisWeek() throws -> Date {
        let calendar = Calendar.current
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

    private func backToTop() {
        for _ in 0..<4 { app.swipeDown() }
    }

    // MARK: Behaviour

    func testPickAPastDayLogToItAndGoBack() throws {
        launch()
        let day = try pastDayThisWeek()
        let weekday = day.formatted(.dateTime.weekday(.wide))
        let todaysBananas = entries("Banana")
        app.buttons[Self.id(day)].tap()
        XCTAssertTrue(app.staticTexts[weekday].waitForExistence(timeout: 5), "the title is the picked day")
        XCTAssertTrue(app.buttons[Self.id(day)].isSelected)
        XCTAssertFalse(app.buttons["todayStartUpNext"].exists, "no Up next on a past day")
        XCTAssertTrue(app.buttons["scanFoodButton"].exists, "the camera stays")
        XCTAssertEqual(app.buttons["logFoodPill"].label.contains("Log food"), true, "the pill reads the same")
        XCTAssertEqual(entries("Banana"), 0)

        app.buttons["logFoodPill"].tap()
        XCTAssertTrue(app.staticTexts[day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())]
            .waitForExistence(timeout: 5), "Log food says which day")
        app.buttons["logFoodAdd.Banana"].firstMatch.tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["todayEntry.Banana"].waitForExistence(timeout: 5), "logged to the picked day")

        app.buttons[Self.id(today)].tap()
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 5), "today's ring goes back")
        XCTAssertEqual(entries("Banana"), todaysBananas, "today unchanged")
        XCTAssertTrue(app.buttons["todayStartUpNext"].exists || app.buttons["resumeWorkout"].exists
                      || app.descendants(matching: .any)["todayRestDay"].exists, "Training is back")
    }

    func testAFutureDayIsNotAButton() {
        launch()
        let calendar = Calendar.current
        let weekEnd = calendar.dateInterval(of: .weekOfYear, for: today)!.end
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today), tomorrow < weekEnd else { return }
        XCTAssertFalse(app.buttons[Self.id(tomorrow)].exists)
    }

    /// A camera photo and a library photo (the picked day wins over its own date) both land on the picked day.
    func testScansLogToThePickedDay() throws {
        launch(["-uiTestTerra"])
        let day = try pastDayThisWeek()
        app.buttons[Self.id(day)].tap()
        XCTAssertTrue(app.staticTexts[day.formatted(.dateTime.weekday(.wide))].waitForExistence(timeout: 5))
        app.buttons["scanFoodButton"].tap()
        XCTAssertTrue(app.buttons["scanFoodShutter"].waitForExistence(timeout: 5))
        app.buttons["scanFoodShutter"].tap()
        XCTAssertTrue(app.buttons["todayEntry.Poke bowl"].waitForExistence(timeout: 15), "a camera photo")
        XCTAssertFalse(app.descendants(matching: .any)["scanPending"].exists, "its card leaves once logged")

        app.buttons["scanFoodButton"].tap()
        XCTAssertTrue(app.buttons["scanFoodLibrary"].waitForExistence(timeout: 5))
        app.buttons["scanFoodLibrary"].tap()
        let deadline = Date.now.addingTimeInterval(15)
        while entries("Poke bowl") < 2 && Date.now < deadline { Thread.sleep(forTimeInterval: 0.5) }
        XCTAssertEqual(entries("Poke bowl"), 2, "a library photo goes to the picked day too")

        backToTop()
        app.buttons[Self.id(today)].tap()
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 5))
        XCTAssertEqual(entries("Poke bowl"), 0, "nothing on today")
        XCTAssertFalse(app.staticTexts["scanLoggedEarlierTitle"].exists, "no leftover card on today")
    }

    /// codex-review-n16 #1: a failed scan from a picked day, then a Log food visit from today (which resets the
    /// visit's day), then Manual Add on the failed card: the entry goes to the scan's day, not today.
    func testAFailedScansManualAddGoesToItsDay() throws {
        launch(["-uiTestTerra", "-uiTestFoodScanFail", "nothing"])
        let day = try pastDayThisWeek()
        app.buttons[Self.id(day)].tap()
        app.buttons["scanFoodButton"].tap()
        XCTAssertTrue(app.buttons["scanFoodShutter"].waitForExistence(timeout: 5))
        app.buttons["scanFoodShutter"].tap()
        XCTAssertTrue(app.staticTexts["scanFailedTitle"].waitForExistence(timeout: 10))

        // An intervening visit from today: Log food opened and closed.
        app.buttons[Self.id(today)].tap()
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 5))
        app.buttons["logFoodPill"].tap()
        XCTAssertTrue(app.buttons["logFoodScan"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let todaysCookies = entries("Cookie")

        app.buttons[Self.id(day)].tap()
        let manual = app.buttons["scanManualAdd"]
        reveal(manual)
        manual.tap()
        let name = app.textFields["manualAddName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Cookie")
        let calories = app.textFields["manualAddCalories"]
        calories.tap()
        calories.typeText("200")
        app.buttons["manualAddLog"].tap()
        XCTAssertTrue(app.buttons["todayEntry.Cookie"].waitForExistence(timeout: 5), "logged to the scan's day")

        backToTop()
        app.buttons[Self.id(today)].tap()
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 5))
        XCTAssertEqual(entries("Cookie"), todaysCookies, "nothing on today")
    }

    func testEarlierWeeks() {
        launch()
        XCTAssertFalse(app.buttons["todayWeekNext"].isEnabled, "no week ahead")
        app.buttons["todayWeekPrevious"].tap()
        XCTAssertTrue(app.staticTexts["Last week"].waitForExistence(timeout: 5))
        let lastWeek = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: today)!
        XCTAssertTrue(app.buttons[Self.id(lastWeek)].isSelected, "the same weekday last week")
        XCTAssertTrue(app.staticTexts[lastWeek.formatted(.dateTime.weekday(.wide))].exists)
        app.otherElements["todayWeek"].firstMatch.swipeRight()
        XCTAssertFalse(app.staticTexts["Last week"].waitForExistence(timeout: 2), "swiped further back")
        app.buttons["todayWeekNext"].tap()
        app.buttons["todayWeekNext"].tap()
        XCTAssertTrue(app.staticTexts["This week"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Today"].exists, "back on this week's weekday: today")
    }

    // MARK: Captures

    func testCaptureLightDefault() throws { try capture(appearance: "light", large: false) }
    func testCaptureDarkAccessibility() throws { try capture(appearance: "dark", large: true) }

    private func capture(appearance: String, large: Bool) throws {
        launch(appearance: appearance, large: large)
        let day = try pastDayThisWeek()
        shoot("1-today")
        let ring = app.buttons[Self.id(day)]
        reveal(ring)
        ring.tap()
        XCTAssertTrue(app.staticTexts[day.formatted(.dateTime.weekday(.wide))].waitForExistence(timeout: 5))
        backToTop()
        shoot("2-past-day")
        app.swipeUp()
        if large { app.swipeUp() }
        shoot("3-past-day-log")
        backToTop()
        app.buttons["logFoodPill"].tap()
        XCTAssertTrue(app.buttons["logFoodScan"].waitForExistence(timeout: 5))
        shoot("4-log-food")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["todayWeekPrevious"].tap()
        XCTAssertTrue(app.staticTexts["Last week"].waitForExistence(timeout: 5))
        shoot("5-last-week")
    }
}
