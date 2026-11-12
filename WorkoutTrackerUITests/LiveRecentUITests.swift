import XCTest

// Performance P1 (Codex review P3): "Recent at <gym>" is read once when the screen or the sheet appears, no longer
// in every redraw. Both places must still show it. `-uiTestDesignLiveEmpty`: an empty workout just started at Iron
// Temple, whose newest finished workout (yesterday's Leg Day) began with the Leg Press.
final class LiveRecentUITests: XCTestCase {
    private let app = XCUIApplication()

    private func any(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    func testRecentAtTheGymShowsOnTheEmptyWorkoutAndInAddExercise() {
        continueAfterFailure = false
        app.launchArguments = ["-uiTestReset", "-uiTestDesignSample", "-uiTestDesignLiveEmpty"]
        app.launch()
        XCTAssertTrue(app.buttons["finishWorkout"].waitForExistence(timeout: 15))

        XCTAssertTrue(app.staticTexts["Recent at Iron Temple"].waitForExistence(timeout: 5), "the empty workout's section")
        XCTAssertTrue(any("recentExercise.Leg Press").exists)

        let add = app.buttons["addExercise"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        XCTAssertTrue(any("recentOption.Leg Press").waitForExistence(timeout: 5), "Add Exercise leads with the gym's recent")

        // A search hides the section; clearing it brings the same rows back.
        let search = app.searchFields.firstMatch.exists ? app.searchFields.firstMatch : app.textFields.firstMatch
        search.tap()
        search.typeText("Leg")
        XCTAssertFalse(any("recentOption.Leg Press").exists)
        search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 3))
        XCTAssertTrue(any("recentOption.Leg Press").waitForExistence(timeout: 5))
    }
}
