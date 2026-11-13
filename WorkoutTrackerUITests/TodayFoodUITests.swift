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
        launch(goal: false, appearance: "dark", large: true)
        reveal(app.buttons["todaySetGoals"])
        shoot("n5-today-nogoal-dark-axl")
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

    func testBurnedShowsWithAndWithoutAGoalAndIsNeverAdded() {
        // codex-review-n5: D71 — Burned beside Eaten whether or not there is a goal; "left" ignores it.
        launch()
        XCTAssertEqual(number("todayBurned"), 320, "the fixture's measured run")
        // Never added: left + eaten is the goal, whatever was burned (the goal's figure is in "of … today").
        let eaten = number("todayEaten")
        // The headline reads as one element: "1,698, cal left, of 2,763 today".
        let headline = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'cal left'"))
            .firstMatch.label
        let figures = headline.split(whereSeparator: { !$0.isNumber && $0 != "," })
            .compactMap { Int($0.filter(\.isNumber)) }
        XCTAssertEqual(figures.count, 2, headline)
        XCTAssertEqual((figures.first ?? 0) + eaten, figures.last ?? -1, headline)
        app.terminate()
        launch(goal: false)
        XCTAssertEqual(number("todayBurned"), 320)
        XCTAssertTrue(app.buttons["todaySetGoals"].exists)
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

    // MARK: N15 — save any food you open (D87)

    func testAnyLoggedFoodCanBeSaved() { saveFromTheLog(appearance: "light", large: false) }
    func testCaptureSavedEntryDarkAccessibility() { saveFromTheLog(appearance: "dark", large: true) }

    /// Banana (logged from a food) bookmarks that food; the Manual Add entry (no food behind it) makes one. The bookmark
    /// acts at once — Cancel keeps it — and both reach Log food's Saved foods; un-saved, Banana leaves it.
    private func saveFromTheLog(appearance: String, large: Bool) {
        let tag = "\(appearance)-\(large ? "axl" : "default")"
        launch(appearance: appearance, large: large)
        let bookmark = app.buttons["editEntrySaveFood"]
        let banana = app.buttons["todayEntry.Banana"]
        reveal(banana)
        banana.tap()
        XCTAssertTrue(bookmark.waitForExistence(timeout: 5), "an entry offers the bookmark")
        XCTAssertEqual(bookmark.label, "Save to Saved foods")
        shoot("n15-edit-\(tag)")
        bookmark.tap()
        XCTAssertEqual(bookmark.label, "Remove from Saved foods")
        shoot("n15-edit-saved-\(tag)")
        app.buttons["Cancel"].tap()

        let manual = app.buttons["todayEntry.Manual Add"]
        reveal(manual)
        manual.tap()
        XCTAssertTrue(bookmark.waitForExistence(timeout: 5))
        XCTAssertEqual(bookmark.label, "Save to Saved foods", "nothing saved behind it yet")
        bookmark.tap()
        XCTAssertEqual(bookmark.label, "Remove from Saved foods")
        app.buttons["Cancel"].tap()
        guard !large else { return }

        openSavedFoods()
        XCTAssertTrue(app.buttons["logFoodRow.Banana"].waitForExistence(timeout: 5), "the food behind the entry")
        XCTAssertTrue(app.buttons["logFoodRow.Manual Add"].exists, "a new food made from the entry")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // Un-saved from the log, Banana leaves Saved foods (the Manual Add food stays).
        XCTAssertTrue(any("todayEaten").waitForExistence(timeout: 5))
        reveal(banana)
        banana.tap()
        XCTAssertTrue(bookmark.waitForExistence(timeout: 5))
        XCTAssertEqual(bookmark.label, "Remove from Saved foods", "it stays saved after Cancel")
        bookmark.tap()
        XCTAssertEqual(bookmark.label, "Save to Saved foods")
        app.buttons["Cancel"].tap()
        openSavedFoods()
        XCTAssertTrue(app.buttons["logFoodRow.Manual Add"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["logFoodRow.Banana"].exists)
    }

    private func openSavedFoods() {
        let pill = app.buttons["logFoodPill"]
        for _ in 0..<6 where !(pill.exists && pill.isHittable) { app.swipeDown() }
        pill.tap()
        let tab = app.buttons["logFoodTab.Saved foods"].firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 5))
        tab.tap()
    }
}

