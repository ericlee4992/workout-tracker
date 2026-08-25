import XCTest

/// Milestone 8, ticket 01 — the progress chart, end to end.
final class ProgressChartUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestReset"]
        app.launch()
    }

    /// With nothing logged, the screen must say so rather than drawing an
    /// empty pair of axes that reads as a broken chart.
    func testProgressSaysSoWhenNothingHasBeenLogged() {
        openProgress(for: "Seated Chest Press")
        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "progressEmpty")
                .firstMatch.waitForExistence(timeout: 10),
            "an exercise with no history should explain itself")
    }

    /// One session is a point, not a trend — the app must not draw a line
    /// through a single dot.
    func testOneSessionRendersAPointAndRefusesATrend() {
        logSet(weight: "60", reps: "8")
        openProgress(for: "Seated Chest Press")

        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "progressSinglePoint")
                .firstMatch.waitForExistence(timeout: 10),
            "one logged session should render as a point")
        XCTAssertFalse(
            app.descendants(matching: .any).matching(identifier: "progressChart")
                .firstMatch.exists,
            "a line drawn through one point invites the eye to read a slope that is not there")

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "progress-single-session"
        shot.lifetime = .keepAlways
        add(shot)
    }

    // MARK: - Helpers

    private func openProgress(for exercise: String) {
        app.tabBars.buttons["Exercises"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText(exercise)

        let row = app.staticTexts[exercise].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "\(exercise) should be listed")
        row.press(forDuration: 1.0)

        let progress = app.buttons["Progress…"].firstMatch
        XCTAssertTrue(progress.waitForExistence(timeout: 5), "the context menu should offer Progress")
        progress.tap()
    }

    private func logSet(weight: String, reps: String) {
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
