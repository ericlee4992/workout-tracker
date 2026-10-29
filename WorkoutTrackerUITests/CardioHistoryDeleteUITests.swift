import XCTest

// Public beta ticket 20 (the user, 2026-10-18): History can delete one cardio activity from a
// workout through its "…", keeping the rest; the workout's only content offers Delete Workout.
// Fixtures: `-uiTestCardioPlanned` (lifting + an ended Indoor Walk) and `-uiTestCardioSplits`
// (cardio-only: an Outdoor Run hero and an Indoor Cycle card).
final class CardioHistoryDeleteUITests: XCTestCase {
    private var app: XCUIApplication!
    private var tag = ""

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(_ arguments: [String], large: Bool = false) {
        tag = large ? "axl" : "default"
        app.launchArguments = ["-uiTestReset", "-appearance", "dark"] + arguments
            + (large ? ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] : [])
        app.launch()
    }

    private func shoot(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "\(name)-\(tag)"
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func any(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func reach(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        func visible() -> Bool { element.exists && element.isHittable && element.frame.minY > 100 }
        for _ in 0..<24 where !visible() {
            let up = !element.exists || element.frame.minY > 100
            let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: up ? 0.62 : 0.38))
            let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: up ? 0.38 : 0.62))
            from.press(forDuration: 0.05, thenDragTo: to)
        }
        XCTAssertTrue(visible(), "\(element.identifier) not reached", file: file, line: line)
    }

    /// Cancels a confirmation dialog: iOS 27 shows it without a Cancel button (a tap outside
    /// cancels), older runtimes with one (as FloodlightSettingsUITests does).
    private func cancelDialog() {
        let cancel = app.sheets.buttons["Cancel"].firstMatch
        if cancel.exists { cancel.tap(); return }
        let outside = app.otherElements["PopoverDismissRegion"].firstMatch
        if outside.exists { outside.tap() } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        }
        XCTAssertTrue(app.sheets.firstMatch.waitForNonExistence(timeout: 5), "the dialog closed")
    }

    /// Finish the fixture's running workout and open it in History.
    private func finishAndOpenInHistory() {
        let finish = app.buttons["finishWorkout"]
        XCTAssertTrue(finish.waitForExistence(timeout: 15))
        finish.tap()
        XCTAssertTrue(app.buttons["finishedDone"].waitForExistence(timeout: 10))
        let history = app.buttons["viewFinishedWorkout"]
        // Clear of the receipt's pinned header: a link half under it is hittable, but the tap lands on Done.
        func clear() -> Bool { history.exists && history.isHittable && history.frame.minY > 160 }
        for _ in 0..<12 where !clear() { app.swipeDown() }
        for _ in 0..<12 where !clear() { app.swipeUp() }
        XCTAssertTrue(clear(), "View in History clear of the header")
        history.tap()
        XCTAssertTrue(any("historyWorkoutName").waitForExistence(timeout: 15), "History's detail opened")
    }

    func testDeletingTheCardioOfAMixedWorkoutKeepsTheLifting() { mixed(large: false) }
    func testDeletingTheCardioOfAMixedWorkoutAtAccessibilitySize() { mixed(large: true) }

    private func mixed(large: Bool) {
        launch(["-uiTestCardioPlanned"], large: large)
        finishAndOpenInHistory()
        let options = app.buttons["historyCardioOptions.indoorWalk"]
        reach(options)
        shoot("20-mixed-card")
        options.tap()
        let delete = app.buttons["deleteHistoryCardio"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        XCTAssertEqual(delete.label, "Delete Cardio…")
        shoot("20-mixed-menu")
        delete.tap()
        let confirm = app.buttons["Delete Cardio"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        shoot("20-mixed-confirm")
        confirm.tap()
        XCTAssertTrue(any("cardioSummary.indoorWalk").waitForNonExistence(timeout: 5), "the walk is gone")
        XCTAssertFalse(any("historyCardioSection").exists, "no Cardio section is left")
        let lifting = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Seated Chest Press'")).firstMatch
        XCTAssertTrue(lifting.exists, "the lifting stays")
        shoot("20-mixed-after")
    }

    func testCardioOnlyDeletesOneThenOffersDeleteWorkout() {
        launch(["-uiTestCardioSplits"])
        finishAndOpenInHistory()
        // The cycle is a card under the run's hero.
        let cycle = app.buttons["historyCardioOptions.indoorCycle"]
        reach(cycle)
        cycle.tap()
        app.buttons["deleteHistoryCardio"].tap()
        app.buttons["Delete Cardio"].tap()
        XCTAssertTrue(any("cardioSummary.indoorCycle").waitForNonExistence(timeout: 5), "the cycle is gone")
        // The run is now the workout's only content: its "…" deletes the workout, after confirming.
        for _ in 0..<6 { app.swipeDown() }
        let run = app.buttons["historyCardioOptions.outdoorRun"]
        XCTAssertTrue(run.waitForExistence(timeout: 5))
        run.tap()
        let delete = app.buttons["deleteHistoryCardio"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        XCTAssertEqual(delete.label, "Delete Workout…")
        delete.tap()
        XCTAssertTrue(app.buttons["Delete Workout"].waitForExistence(timeout: 5), "the workout's own confirmation")
        shoot("20-only-content-confirm")
        cancelDialog()
        XCTAssertTrue(any("cardioSummary.outdoorRun").exists, "cancel keeps it")
    }
}
