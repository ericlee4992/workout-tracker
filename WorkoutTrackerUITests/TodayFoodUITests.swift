import XCTest

/// Nutrition N5: Today's food parts — the fuel card (with a goal, over it, and without one: "Set your goals"), the
/// rings, today's log by meal, editing and deleting an entry with Undo, and a log from Log food reaching the totals.
/// Captures in light at Default and dark at AccessibilityL.
final class TodayFoodUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(goal: Bool = true, over: Bool = false, appearance: String = "light", large: Bool = false) {
        app.launchArguments = ["-uiTestReset", "-uiTestDesignSample", "-appearance", appearance,
                               "-uiTestFoodSample", "-uiTestFoodDiary"]
            + (goal ? ["-uiTestPersonalDetails"] : []) + (over ? ["-uiTestFoodOver"] : [])
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] }
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["todayEaten"].waitForExistence(timeout: 15))
    }

    private func shoot(_ name: String) {
        Thread.sleep(forTimeInterval: 0.7)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func any(_ id: String) -> XCUIElement { app.descendants(matching: .any)[id] }

    /// The number in a stat's spoken label ("Eaten 1,245" → 1245).
    private func number(_ id: String) -> Int {
        let digits = any(id).label.filter(\.isNumber)
        return Int(digits) ?? -1
    }

    /// Scrolls until the element is on screen (AX layouts are long).
    private func reveal(_ element: XCUIElement) {
        for _ in 0..<8 {
            guard !(element.exists && element.isHittable) else { break }
            app.swipeUp()
        }
    }

    // MARK: Captures

    func testCaptureLightDefault() { capture(appearance: "light", large: false) }
    func testCaptureDarkAccessibility() { capture(appearance: "dark", large: true) }

    private func capture(appearance: String, large: Bool) {
        let tag = "\(appearance)-\(large ? "axl" : "default")"
        launch(appearance: appearance, large: large)
        shoot("n5-today-\(tag)-1")
        for index in 2...(large ? 6 : 3) {
            app.swipeUp()
            shoot("n5-today-\(tag)-\(index)")
        }
        let banana = app.buttons["todayEntry.Banana"]
        reveal(banana)
        banana.tap()
        XCTAssertTrue(app.buttons["editEntrySave"].waitForExistence(timeout: 5))
        shoot("n5-edit-\(tag)")
        if large { app.swipeUp(); shoot("n5-edit-\(tag)-2") }
    }

    func testCaptureOverAndNoGoal() {
        launch(over: true)
        XCTAssertTrue(app.staticTexts["cal over"].exists)
        shoot("n5-today-over-light-default")
        app.terminate()
        launch(goal: false)
        XCTAssertTrue(app.buttons["todaySetGoals"].exists)
        shoot("n5-today-nogoal-light-default")
        app.terminate()
        launch(over: true, appearance: "dark", large: true)
        shoot("n5-today-over-dark-axl")
        app.swipeUp()
        shoot("n5-today-over-dark-axl-2")
    }

    // MARK: Flows

    func testEditingAnEntryChangesTheTotals() {
        launch()
        let eaten = number("todayEaten")
        XCTAssertGreaterThan(eaten, 0)
        let banana = app.buttons["todayEntry.Banana"]
        reveal(banana)
        banana.tap()
        XCTAssertTrue(app.buttons["editEntrySave"].waitForExistence(timeout: 5))
        app.buttons["More servings"].tap()
        app.buttons["More servings"].tap()
        XCTAssertEqual(app.staticTexts["editEntryServings"].label, "2")
        app.buttons["editEntryMeal.snacks"].tap()
        app.buttons["editEntrySave"].tap()
        XCTAssertTrue(app.buttons["editEntrySave"].waitForNonExistence(timeout: 5))
        XCTAssertEqual(number("todayEaten"), eaten + 105, "one more banana (105 cal)")
        XCTAssertTrue(any("todayMeal.snacks").exists)
        app.swipeDown(); app.swipeDown()
        XCTAssertEqual(number("todayEaten"), eaten + 105)
    }

    func testDeletingAnEntryOffersUndo() {
        launch()
        let eaten = number("todayEaten")
        let banana = app.buttons["todayEntry.Banana"]
        reveal(banana)
        banana.tap()
        let delete = app.buttons["editEntryDelete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        reveal(delete)
        delete.tap()
        let toast = app.staticTexts["todayDeletedToast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 5))
        XCTAssertEqual(toast.label, "Deleted Banana")
        XCTAssertFalse(banana.exists)
        app.buttons["todayUndoDelete"].tap()
        XCTAssertTrue(banana.waitForExistence(timeout: 5), "Undo puts it back")
        app.swipeDown(); app.swipeDown()
        XCTAssertEqual(number("todayEaten"), eaten)
    }

    func testALogFromLogFoodReachesTodayAndSetGoalsOpensTheGoals() {
        launch(goal: false)
        let eaten = number("todayEaten")
        app.buttons["logFoodPill"].tap()
        XCTAssertTrue(app.buttons["logFoodAdd.Greek yogurt"].waitForExistence(timeout: 5))
        app.buttons["logFoodAdd.Greek yogurt"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(any("todayEaten").waitForExistence(timeout: 5))
        XCTAssertEqual(number("todayEaten"), eaten + 100, "Greek yogurt, 100 cal")
        app.buttons["todaySetGoals"].tap()
        XCTAssertTrue(app.staticTexts["Nutrition goals"].waitForExistence(timeout: 5))
    }
}
