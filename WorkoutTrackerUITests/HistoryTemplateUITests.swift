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
        if name.contains("LargeText") {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"]
        }
        app.launch()
    }

    private func anyElement(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func shoot(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// The same flow at AccessibilityL: the menu item, the alert and the
    /// confirmation row hold (codex-review-13, the capture record).
    func testAHistoryWorkoutCanBeSavedAsATemplateLargeText() {
        testAHistoryWorkoutCanBeSavedAsATemplate()
    }

    func testAHistoryWorkoutCanBeSavedAsATemplate() {
        let suffix = name.contains("LargeText") ? "-axl" : ""
        app.tabBars.buttons["History"].tap()
        let row = anyElement("historyWorkoutRow")
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        XCTAssertTrue(app.buttons["historyWorkoutName"].waitForExistence(timeout: 10))
        app.buttons["workoutDetailMenu"].tap()
        let save = app.buttons["saveAsTemplate"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "the menu offers Save as Template… for a workout with completed sets")
        shoot("history-13-menu\(suffix)")
        save.tap()
        let field = app.textFields["Template name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertTrue(((field.value as? String) ?? "").hasPrefix("Workout "), "the default name is filled in")
        shoot("history-13-alert\(suffix)")
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
        shoot("history-13-confirmation\(suffix)")

        app.tabBars.buttons["Workout"].tap()
        let tile = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'templateTile.Workout' AND identifier ENDSWITH 'From History'")).firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 10), "the template is on the Workout tab")
        tile.tap()
        XCTAssertTrue(anyElement("startTemplate").waitForExistence(timeout: 5))
        XCTAssertTrue(anyElement("templateExercise.Seated Chest Press").exists,
                      "the template holds the workout's exercise")
    }

    /// The finish sheet's own save — the flow was extracted from it (ticket 13)
    /// and no test had exercised it: the prefilled name, Save, the
    /// confirmation in place of the button (codex-review-13).
    func testTheFinishSheetStillSavesATemplate() {
        app.tabBars.buttons["Workout"].tap()
        app.buttons["startEmptyWorkout"].tap()
        app.buttons["addExercise"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Seated Chest")
        let option = anyElement("exerciseOption.Seated Chest Press")
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        option.tap()
        let weight = app.textFields["setRow.weight"].firstMatch
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        weight.tap()
        weight.typeText("60")
        let reps = app.textFields["setRow.reps"].firstMatch
        reps.tap()
        reps.typeText("10")
        app.buttons["setRow.complete"].firstMatch.tap()
        app.buttons["finishWorkout"].tap()
        XCTAssertTrue(app.buttons["finishedDone"].waitForExistence(timeout: 10))
        let save = app.buttons["saveAsTemplate"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()
        let field = app.textFields["Template name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertTrue(((field.value as? String) ?? "").hasPrefix("Workout "), "the default name is filled in")
        app.buttons["Save"].tap()
        let confirmation = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Saved as template “Workout'")).firstMatch
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5), "the button gives way to the confirmation")
        XCTAssertFalse(save.exists, "and the button is gone")
        shoot("history-13-finish-sheet-saved")
    }
}
