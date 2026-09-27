import XCTest

// Floodlight redesign ticket 05: History — the list, the calendar, a workout's detail, the set
// editor and the progress chart — on record in light and dark at Default and AccessibilityL,
// on the design sample with its History extras (new bests, heart rate, a note, kg + lb).
final class FloodlightHistoryUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func shoot(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func any(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    func testCaptureHistoryLightDefault() { captureHistory(appearance: "light", large: false) }
    func testCaptureHistoryLightAccessibility() { captureHistory(appearance: "light", large: true) }
    func testCaptureHistoryDarkDefault() { captureHistory(appearance: "dark", large: false) }
    func testCaptureHistoryDarkAccessibility() { captureHistory(appearance: "dark", large: true) }

    func testCaptureEmptyLight() { captureEmpty(appearance: "light") }
    func testCaptureEmptyDark() { captureEmpty(appearance: "dark") }

    private func launch(_ arguments: [String], appearance: String, large: Bool) {
        app.launchArguments = arguments + ["-appearance", appearance]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] }
        app.launch()
    }

    private func captureHistory(appearance: String, large: Bool) {
        launch(["-uiTestReset", "-uiTestDesignSample", "-uiTestDesignHistory"], appearance: appearance, large: large)
        let suffix = "\(appearance)-\(large ? "axl" : "default")"
        app.tabBars.buttons["History"].tap()

        // The list: the month card, then the weeks.
        let row = any("historyWorkoutRow")
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        XCTAssertTrue(any("historyMonthStrip").exists, "the month card leads the list")
        Thread.sleep(forTimeInterval: 1.2)
        shoot("floodlight-05-list-\(suffix)-1")
        app.swipeUp()
        shoot("floodlight-05-list-\(suffix)-2")
        app.swipeDown(); app.swipeDown()

        // The calendar: yesterday's Leg Day selected (the latest training day).
        app.buttons["historyCalendar"].tap()
        XCTAssertTrue(any("historyCalendarSheet").waitForExistence(timeout: 10))
        XCTAssertTrue(any("calendarWorkoutRow").waitForExistence(timeout: 5), "the latest day is selected, its workout listed")
        Thread.sleep(forTimeInterval: 0.8)
        shoot("floodlight-05-calendar-\(suffix)")
        any("calendarWorkoutRow").tap()

        // The detail, page by page down to Delete Workout….
        XCTAssertTrue(app.buttons["historyWorkoutName"].waitForExistence(timeout: 10), "the calendar opens the workout")
        Thread.sleep(forTimeInterval: 1.2)
        shoot("floodlight-05-detail-\(suffix)-1")
        let delete = app.buttons["deleteWorkout"]
        for page in 2...9 where !(delete.exists && delete.isHittable) {
            app.swipeUp()
            shoot("floodlight-05-detail-\(suffix)-\(page)")
        }

        // The set editor, from the first set line.
        for _ in 0..<8 where !(any("historySetLine").exists && any("historySetLine").isHittable) { app.swipeDown() }
        let setLine = any("historySetLine")
        XCTAssertTrue(setLine.waitForExistence(timeout: 5))
        setLine.tap()
        XCTAssertTrue(app.textFields["editSetWeight"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8)
        shoot("floodlight-05-editset-\(suffix)")
        app.buttons["Cancel"].firstMatch.tap()

        // The progress chart of the first exercise.
        let chartButton = app.buttons["historyEntryChart"].firstMatch
        XCTAssertTrue(chartButton.waitForExistence(timeout: 5))
        chartButton.tap()
        XCTAssertTrue(any("progressChart").waitForExistence(timeout: 10), "a multi-day series draws")
        Thread.sleep(forTimeInterval: 1)
        shoot("floodlight-05-progress-\(suffix)-1")
        app.swipeUp()
        shoot("floodlight-05-progress-\(suffix)-2")
    }

    private func captureEmpty(appearance: String) {
        launch(["-uiTestReset"], appearance: appearance, large: false)
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(any("historyStartLifting").waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["historyCalendar"].exists, "no calendar before the first workout")
        shoot("floodlight-05-empty-\(appearance)")
    }
}
