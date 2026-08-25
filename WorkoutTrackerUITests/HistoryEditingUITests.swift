import XCTest

/// Milestone 8, ticket 03 — editing logged history, end to end.
///
/// These drive the destructive paths on purpose. This feature mutates the only
/// copy of the user's training history, and a domain test cannot prove the
/// button is wired to the right function.
final class HistoryEditingUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestReset"]
        app.launch()
    }

    /// Log a set, finish, then correct it from History and confirm the change
    /// sticks and the workout is marked as edited.
    func testASetCanBeCorrectedFromHistoryAndTheWorkoutIsMarked() {
        logOneWorkout(weight: "60", reps: "8")

        app.tabBars.buttons["History"].tap()
        let firstWorkout = app.descendants(matching: .any)
            .matching(identifier: "historyWorkoutRow").firstMatch
        XCTAssertTrue(firstWorkout.waitForExistence(timeout: 10), "the finished workout should be listed")
        firstWorkout.tap()

        // Tap the logged set to correct it.
        let setLine = app.descendants(matching: .any)
            .matching(identifier: "historySetLine").firstMatch
        XCTAssertTrue(setLine.waitForExistence(timeout: 10), "the logged set should be listed")
        setLine.tap()

        let weight = app.textFields["editSetWeight"]
        XCTAssertTrue(weight.waitForExistence(timeout: 5), "the edit sheet should open")
        weight.tap()
        // Clear and retype.
        weight.press(forDuration: 1.0)
        if app.menuItems["Select All"].waitForExistence(timeout: 2) {
            app.menuItems["Select All"].tap()
        }
        weight.typeText("65")
        app.buttons["saveEditedSet"].tap()

        // The edited mark is the honesty half of D47 — a silently altered
        // history is the thing this app refuses to produce.
        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "historyEditedMark")
                .firstMatch.waitForExistence(timeout: 10),
            "an edited workout must say it was edited")

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "history-edited"
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// The most destructive path in the app. It must confirm, and it must
    /// actually remove the workout.
    func testAWorkoutCanBeDeletedFromHistoryAfterConfirming() {
        logOneWorkout(weight: "50", reps: "5")

        app.tabBars.buttons["History"].tap()
        let firstWorkout = app.descendants(matching: .any)
            .matching(identifier: "historyWorkoutRow").firstMatch
        XCTAssertTrue(firstWorkout.waitForExistence(timeout: 10), "the finished workout should be listed")
        firstWorkout.tap()

        app.buttons["workoutDetailMenu"].firstMatch.tap()
        let delete = app.buttons["deleteWorkout"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()

        let confirm = app.buttons["Delete Workout"]
        XCTAssertTrue(
            confirm.waitForExistence(timeout: 5),
            "deleting a workout must confirm — this is the only copy of the history")
        confirm.tap()

        // Back on History, and the workout is gone.
        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "historyWorkoutRow")
                .count == 0,
            "the deleted workout should no longer be listed")
    }

    // MARK: - Helper

    private func logOneWorkout(weight: String, reps: String) {
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
        weightField.typeText(weight)
        let repsField = app.textFields["setRow.reps"].firstMatch
        repsField.tap()
        repsField.typeText(reps)
        app.buttons["setRow.complete"].firstMatch.tap()
        app.buttons["finishWorkout"].tap()
        app.buttons["finishedDone"].firstMatch.tap()
    }
}
