import XCTest

/// Milestone 9, ticket 02 — naming a workout, from both places it can be done.
final class WorkoutNameUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestReset"]
        app.launch()
    }

    /// Tap the title mid-workout, type a name, finish: History lists it under
    /// that name — and it is not marked as edited, because nothing was.
    func testAWorkoutCanBeNamedWhileRunningAndHistoryShowsIt() {
        startWorkoutWithOneSet()

        let title = app.buttons["workoutTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 10), "the title should be tappable")
        title.tap()
        typeIntoNameAlert("Push A")

        XCTAssertTrue(
            app.buttons["workoutTitle"].label.contains("Push A"),
            "the bar should show the new name at once, got '\(app.buttons["workoutTitle"].label)'")

        app.buttons["finishWorkout"].tap()
        app.buttons["finishedDone"].firstMatch.tap()

        app.tabBars.buttons["History"].tap()
        let row = app.descendants(matching: .any).matching(identifier: "historyWorkoutRow").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Push A"].firstMatch.exists, "History should list the workout by its name")
        row.tap()
        XCTAssertFalse(
            app.descendants(matching: .any).matching(identifier: "historyEditedMark").firstMatch.exists,
            "naming a running workout is not a history edit")

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "workout-named-live"
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Rename from History: the title changes AND the workout is marked as
    /// edited (D47) — a logged workout that quietly changed its name would be
    /// history changing without saying so.
    func testRenamingFromHistoryIsAMarkedEdit() {
        startWorkoutWithOneSet()
        app.buttons["finishWorkout"].tap()
        app.buttons["finishedDone"].firstMatch.tap()

        app.tabBars.buttons["History"].tap()
        let row = app.descendants(matching: .any).matching(identifier: "historyWorkoutRow").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()

        let nameRow = app.buttons["historyWorkoutName"]
        XCTAssertTrue(nameRow.waitForExistence(timeout: 10))
        nameRow.tap()
        typeIntoNameAlert("Push B")

        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "historyEditedMark")
                .firstMatch.waitForExistence(timeout: 10),
            "a renamed workout must say it was edited")
        XCTAssertTrue(app.buttons["historyWorkoutName"].label.contains("Push B"))

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "workout-renamed-history"
        shot.lifetime = .keepAlways
        add(shot)
    }

    // MARK: Helpers

    private func typeIntoNameAlert(_ name: String) {
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "the name alert should open")
        let field = alert.textFields.firstMatch
        field.tap()
        field.typeText(name)
        alert.buttons["Save"].firstMatch.tap()
    }

    private func startWorkoutWithOneSet() {
        app.tabBars.buttons["Workout"].tap()
        let start = app.buttons["startEmptyWorkout"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()

        app.buttons["addExercise"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Seated Chest")
        let option = app.descendants(matching: .any)
            .matching(identifier: "exerciseOption.Seated Chest Press").firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 10))
        option.tap()

        let weightField = app.textFields["setRow.weight"].firstMatch
        XCTAssertTrue(weightField.waitForExistence(timeout: 5))
        weightField.tap()
        weightField.typeText("60")
        let repsField = app.textFields["setRow.reps"].firstMatch
        repsField.tap()
        repsField.typeText("8")
        app.buttons["setRow.complete"].firstMatch.tap()
    }
}
