import XCTest

// Public beta ticket 16 (D63): the Progress tab — the pinned panels, the cardio progress sheet and Add Chart — on
// record in light and dark at Default and AccessibilityL, and its flows: add from empty, change what a panel shows,
// move, remove, and the pins surviving a relaunch.
final class FloodlightProgressUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func shoot(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func any(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private var panels: XCUIElementQuery { app.buttons.matching(identifier: "progressPanel") }

    private func panelTitles() -> [String] {
        panels.allElementsBoundByIndex.map(\.label)
    }

    private static let sample = ["-uiTestReset", "-uiTestDesignSample", "-uiTestDesignHistory", "-uiTestDesignGyms"]

    private func launch(_ arguments: [String], appearance: String = "dark", large: Bool = false) {
        app.launchArguments = arguments + ["-appearance", appearance]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] }
        app.launch()
        app.tabBars.buttons["Progress"].tap()
    }

    // MARK: Captures

    func testCaptureProgressLightDefault() { capture(appearance: "light", large: false) }
    func testCaptureProgressLightAccessibility() { capture(appearance: "light", large: true) }
    func testCaptureProgressDarkDefault() { capture(appearance: "dark", large: false) }
    func testCaptureProgressDarkAccessibility() { capture(appearance: "dark", large: true) }

    private func capture(appearance: String, large: Bool) {
        launch(Self.sample + ["-uiTestDesignProgress"], appearance: appearance, large: large)
        let suffix = "\(appearance)-\(large ? "axl" : "default")"
        XCTAssertTrue(panels.firstMatch.waitForExistence(timeout: 15))
        XCTAssertEqual(panels.count, 4, "the four pinned charts")
        Thread.sleep(forTimeInterval: 1.2)
        shoot("progress-16-tab-\(suffix)-1")
        app.swipeUp()
        shoot("progress-16-tab-\(suffix)-2")
        app.swipeUp(); app.swipeUp()
        XCTAssertTrue(any("progressAddChartBottom").waitForExistence(timeout: 5), "Add Chart under the last panel")
        shoot("progress-16-tab-\(suffix)-3")
        app.swipeDown(); app.swipeDown(); app.swipeDown(); app.swipeDown()

        // The cardio sheet: distance, then pace.
        let run = panels.containing(NSPredicate(format: "label CONTAINS 'Outdoor Run'")).firstMatch
        XCTAssertTrue(run.waitForExistence(timeout: 5))
        run.tap()
        XCTAssertTrue(any("cardioProgressPanel").waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 0.8)
        shoot("progress-16-cardio-\(suffix)-1")
        app.buttons["Pace"].tap()
        Thread.sleep(forTimeInterval: 0.8)
        shoot("progress-16-cardio-pace-\(suffix)")
        app.swipeUp()
        XCTAssertTrue(any("cardioProgressSession").waitForExistence(timeout: 5), "the sessions list")
        shoot("progress-16-cardio-\(suffix)-2")
        any("closeCardioProgress").tap()

        // Add Chart, step 2 for a lifting exercise with two machines' worth of history or one.
        XCTAssertTrue(any("progressAddChart").waitForExistence(timeout: 5))
        any("progressAddChart").tap()
        XCTAssertTrue(any("addChartExercise").waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 0.6)
        shoot("progress-16-add-\(suffix)-1")
        any("addChartExercise").tap()
        XCTAssertTrue(any("addChartAdd").waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.6)
        shoot("progress-16-add-\(suffix)-2")
    }

    func testCaptureEmptyDark() {
        launch(Self.sample, appearance: "dark")
        XCTAssertTrue(any("progressEmptyState").waitForExistence(timeout: 15))
        Thread.sleep(forTimeInterval: 0.8)
        shoot("progress-16-empty-dark-default")
    }

    // MARK: Flows

    /// From nothing: Add Chart → a lifting exercise → Add, then cardio → Outdoor Run → Pace → Add.
    func testAddingLiftingAndCardioFromEmpty() {
        launch(Self.sample + ["-uiTestDesignProgress", "-uiTestProgressNoPins"])
        XCTAssertTrue(any("progressEmptyState").waitForExistence(timeout: 15))
        app.buttons["Add Chart"].firstMatch.tap()
        XCTAssertTrue(any("addChartExercise").waitForExistence(timeout: 10))
        let exercise = app.buttons.matching(identifier: "addChartExercise").firstMatch
        let name = exercise.label.components(separatedBy: ",").first ?? ""
        exercise.tap()
        any("addChartAdd").tap()
        XCTAssertTrue(panels.firstMatch.waitForExistence(timeout: 10))
        XCTAssertEqual(panels.count, 1)
        XCTAssertTrue(panels.firstMatch.label.contains(name), "the panel is the exercise added: \(name)")

        any("progressAddChart").tap()
        XCTAssertTrue(any("addChartKind").waitForExistence(timeout: 10))
        app.buttons["Cardio"].tap()
        let run = app.buttons.matching(identifier: "addChartActivity").containing(NSPredicate(format: "label CONTAINS 'Outdoor Run'")).firstMatch
        XCTAssertTrue(run.waitForExistence(timeout: 5))
        run.tap()
        app.buttons["Pace"].tap()
        any("addChartAdd").tap()
        XCTAssertTrue(panels.element(boundBy: 1).waitForExistence(timeout: 10))
        let added = panels.element(boundBy: 1).label
        XCTAssertTrue(added.contains("Outdoor Run") && added.contains("Pace"), added)
    }

    /// Long-press: Show changes the metric, Move Up reorders, Remove drops one; all three survive a relaunch.
    func testChangeMoveRemoveAndRelaunch() {
        launch(Self.sample + ["-uiTestDesignProgress"])
        XCTAssertTrue(panels.firstMatch.waitForExistence(timeout: 15))
        XCTAssertEqual(panels.count, 4)

        // Outdoor Run (second) shows Time.
        // The metric options sit inline in the menu under "Show".
        panels.element(boundBy: 1).press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["Time"].waitForExistence(timeout: 5))
        app.buttons["Time"].tap()
        XCTAssertTrue(waitFor { self.panels.element(boundBy: 1).label.contains("Time") }, panels.element(boundBy: 1).label)

        // Move it up: Outdoor Run leads.
        panels.element(boundBy: 1).press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["Move Up"].waitForExistence(timeout: 5))
        app.buttons["Move Up"].tap()
        XCTAssertTrue(waitFor { self.panels.element(boundBy: 0).label.contains("Outdoor Run") }, panelTitles().joined(separator: " | "))

        // Remove the last (Rowing).
        let last = panels.element(boundBy: 3)
        XCTAssertTrue(last.label.contains("Rowing"), last.label)
        last.press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["Remove from Progress"].waitForExistence(timeout: 5))
        app.buttons["Remove from Progress"].tap()
        XCTAssertTrue(waitFor { self.panels.count == 3 })
        let before = panelTitles()

        app.terminate()
        launch(Self.sample + ["-uiTestDesignProgress", "-uiTestKeepPins"])
        XCTAssertTrue(panels.firstMatch.waitForExistence(timeout: 15))
        XCTAssertTrue(waitFor { self.panelTitles() == before }, "after relaunch: \(panelTitles()) vs \(before)")
    }

    private func waitFor(_ timeout: TimeInterval = 5, _ condition: @escaping () -> Bool) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return condition()
    }
}
