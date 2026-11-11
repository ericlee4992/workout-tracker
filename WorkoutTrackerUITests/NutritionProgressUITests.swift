import XCTest

/// Nutrition N10: Progress → Add Chart → Nutrition (Body and Food groups) pins body and food charts, a chart opens its
/// page with ranges and its days, a food day opens that day's food; History's food line opens the day's food page, where
/// an entry deletes with Undo. Captures in light at Default and dark at AccessibilityL.
final class NutritionProgressUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private static let food = ["-uiTestReset", "-uiTestDesignSample", "-uiTestFoodSample", "-uiTestFoodDiary"]

    private func launch(_ extra: [String] = [], goal: Bool = true, appearance: String = "light", large: Bool = false) {
        app.launchArguments = Self.food + (goal ? ["-uiTestPersonalDetails"] : []) + extra + ["-appearance", appearance]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] }
        app.launch()
        XCTAssertTrue(any("todayEaten").waitForExistence(timeout: 15))
    }

    private func any(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }

    private var panels: XCUIElementQuery { app.buttons.matching(identifier: "progressPanel") }

    private func tab(_ name: String) {
        let button = app.tabBars.buttons[name].exists ? app.tabBars.buttons[name] : app.buttons[name]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        button.tap()
    }

    private func reveal(_ element: XCUIElement) {
        for _ in 0..<8 {
            guard !(element.exists && element.isHittable) else { break }
            app.swipeUp()
        }
    }

    private func waitFor(_ timeout: TimeInterval = 5, _ condition: @escaping () -> Bool) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return condition()
    }

    private func shoot(_ name: String) {
        Thread.sleep(forTimeInterval: 0.8)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func addNutritionChart(_ id: String) {
        if any("progressEmptyState").exists { app.buttons["Add Chart"].firstMatch.tap() } else { any("progressAddChart").tap() }
        XCTAssertTrue(any("addChartKind").waitForExistence(timeout: 10))
        app.buttons["Nutrition"].tap()
        let row = any("addChartNutrition.\(id)")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        reveal(row)
        row.tap()
    }

    func testAddingBodyAndFoodChartsAndOpeningADay() {
        launch()
        tab("Progress")
        XCTAssertTrue(any("progressEmptyState").waitForExistence(timeout: 10))
        addNutritionChart("bodyWeight")
        XCTAssertTrue(waitFor { self.panels.count == 1 })
        XCTAssertTrue(panels.element(boundBy: 0).label.contains("Body weight"), panels.element(boundBy: 0).label)
        XCTAssertTrue(panels.element(boundBy: 0).label.contains("176.4"), "the Personal details weight, in lb")
        addNutritionChart("calories")
        XCTAssertTrue(waitFor { self.panels.count == 2 })
        let calories = panels.element(boundBy: 1)
        XCTAssertTrue(calories.label.contains("Calories") && calories.label.contains("Daily average"), calories.label)

        calories.tap()
        XCTAssertTrue(app.navigationBars["Calories"].waitForExistence(timeout: 10))
        app.buttons["30D"].tap()
        let day = app.buttons.matching(identifier: "nutritionChartDay").firstMatch
        reveal(day)
        XCTAssertTrue(day.waitForExistence(timeout: 5))
        day.tap()
        XCTAssertTrue(any("todayEaten").waitForExistence(timeout: 5), "the day's food page, its fuel card")
    }

    func testHistorysFoodLineOpensTheDayAndAnEntryDeletesWithUndo() {
        launch(["-uiTestDesignHistory"])
        tab("History")
        let food = app.buttons.matching(identifier: "historyFoodRow").firstMatch
        XCTAssertTrue(food.waitForExistence(timeout: 10))
        XCTAssertTrue(food.label.contains("cal eaten"), food.label)
        XCTAssertTrue(food.label.contains("under goal") || food.label.contains("over goal"), food.label)
        food.tap()
        XCTAssertTrue(any("todayEaten").waitForExistence(timeout: 5))
        let eaten = Int(any("todayEaten").label.filter(\.isNumber)) ?? -1
        let banana = app.buttons["todayEntry.Banana"]
        reveal(banana)
        XCTAssertTrue(banana.waitForExistence(timeout: 5))
        banana.tap()
        let delete = app.buttons["editEntryDelete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        reveal(delete)
        delete.tap()
        XCTAssertTrue(app.staticTexts["todayDeletedToast"].waitForExistence(timeout: 5))
        XCTAssertFalse(banana.exists)
        app.buttons["todayUndoDelete"].tap()
        XCTAssertTrue(banana.waitForExistence(timeout: 5), "Undo puts it back")
        app.swipeDown(); app.swipeDown()
        XCTAssertEqual(Int(any("todayEaten").label.filter(\.isNumber)), eaten)
    }

    /// codex-review-n10 S1: today's food page shows Health's Burned as Today does — with a goal and without one.
    func testTodaysFoodPageShowsHealthsBurned() {
        for goal in [true, false] {
            launch(["-uiTestDesignHistory", "-uiTestHealthSample", "-uiTestHealthOn"], goal: goal)
            let burned = NSPredicate(format: "label CONTAINS '412'")
            XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: burned, evaluatedWith: any("todayBurned"))], timeout: 5),
                           .completed, "Today: \(any("todayBurned").label)")
            tab("History")
            let food = app.buttons.matching(identifier: "historyFoodRow").firstMatch
            XCTAssertTrue(food.waitForExistence(timeout: 10))
            food.tap()
            XCTAssertTrue(any("todayBurned").waitForExistence(timeout: 5))
            XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: burned, evaluatedWith: any("todayBurned"))], timeout: 5),
                           .completed, "today's page (goal \(goal)): \(any("todayBurned").label)")
            app.terminate()
        }
    }

    func testCaptureLightDefault() { capture(appearance: "light", large: false) }
    func testCaptureDarkAccessibility() { capture(appearance: "dark", large: true) }

    private func capture(appearance: String, large: Bool) {
        let tag = "\(appearance)-\(large ? "axl" : "default")"
        launch(["-uiTestDesignHistory", "-uiTestNutritionCharts"], appearance: appearance, large: large)
        tab("Progress")
        XCTAssertTrue(panels.firstMatch.waitForExistence(timeout: 10))
        XCTAssertEqual(panels.count, 5, "the five body and food charts")
        shoot("n10-progress-\(tag)-1")
        for index in 2...4 {
            app.swipeUp()
            shoot("n10-progress-\(tag)-\(index)")
        }
        let trend = panels.element(boundBy: 1)
        for _ in 0..<8 where !trend.isHittable { app.swipeDown() }
        trend.tap()
        XCTAssertTrue(app.navigationBars["Weight trend"].waitForExistence(timeout: 10))
        shoot("n10-trend-\(tag)")
        app.buttons["Done"].tap()
        any("progressAddChart").tap()
        XCTAssertTrue(any("addChartKind").waitForExistence(timeout: 10))
        app.buttons["Nutrition"].tap()
        shoot("n10-addchart-\(tag)")
        app.buttons["addChartCancel"].tap()
        tab("History")
        XCTAssertTrue(app.buttons.matching(identifier: "historyFoodRow").firstMatch.waitForExistence(timeout: 10))
        shoot("n10-history-\(tag)")
        // A past day, explicitly (codex-review-n10): the second food line, scrolled to.
        let rows = app.buttons.matching(identifier: "historyFoodRow")
        for _ in 0..<8 where rows.count < 2 { app.swipeUp() }
        let past = rows.element(boundBy: 1)
        reveal(past)
        past.tap()
        XCTAssertTrue(any("todayEaten").waitForExistence(timeout: 5))
        let pastWording = NSPredicate(format: "label CONTAINS 'goal' AND NOT (label CONTAINS 'today')")
        XCTAssertTrue(app.descendants(matching: .any).matching(pastWording).firstMatch.exists, "a past day's fuel card")
        shoot("n10-day-\(tag)")
    }
}
