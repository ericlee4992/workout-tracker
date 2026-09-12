import XCTest

/// Ticket 13 — "Save as Template…" from a History workout: the finish sheet's
/// naming flow, reached from the detail's menu; the template then appears on
/// the Workout tab as a tile.
final class HistoryTemplateUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        // Four weeks of finished sessions with completed sets (ChartFixture).
        app.launchArguments = ["-uiTestReset", "-uiTestChartHistory"]
        app.launch()
    }

    private func anyElement(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func testAHistoryWorkoutCanBeSavedAsATemplate() {
        app.tabBars.buttons["History"].tap()
        let row = anyElement("historyWorkoutRow")
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        XCTAssertTrue(app.buttons["historyWorkoutName"].waitForExistence(timeout: 10))
        app.buttons["workoutDetailMenu"].tap()
        let save = app.buttons["saveAsTemplate"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "the menu offers Save as Template… for a workout with completed sets")
        save.tap()
        let field = app.textFields["Template name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        // The default name is filled in ("Workout <date>"). A tap lands the
        // cursor where it hits, so tap the field's far end and append there:
        // the saved name is "Workout <date> From History".
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
        field.typeText(" From History")
        app.buttons["Save"].tap()
        // The row's identifier lands on the cell (whose label is its selection
        // state); the words are the static text inside it.
        let confirmation = app.staticTexts
            .matching(NSPredicate(format: "label BEGINSWITH 'Saved as template “Workout' AND label ENDSWITH 'From History”'")).firstMatch
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5), "the detail confirms the save in place, naming the template")

        app.tabBars.buttons["Workout"].tap()
        let tile = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'templateTile.Workout' AND identifier ENDSWITH 'From History'")).firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 10), "the template is on the Workout tab")
        tile.tap()
        XCTAssertTrue(anyElement("startTemplate").waitForExistence(timeout: 5))
        XCTAssertTrue(anyElement("templateExercise.Seated Chest Press").exists,
                      "the template holds the workout's exercise")
    }
}
