import XCTest

// Performance ticket P1, the second opinion's data question: a set row decides whether last session's numbers may
// fill it from its own `isDirty` state, which a new row does not have. Minimise and resume build every row anew, so a
// weight the user typed into an exercise with nothing logged yet must not be replaced by last session's on resume.
// `-uiTestDesignLive`: Push Day with the chest press's sets 1–2 logged (three rows); the Incline Chest Press below
// has nothing logged and last week's 55 lb to offer.
final class LivePrefillUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
        app.launchArguments = ["-uiTestReset", "-uiTestDesignSample", "-uiTestDesignLive"]
        app.launch()
        XCTAssertTrue(app.buttons["finishWorkout"].waitForExistence(timeout: 15))
    }

    func testATypedWeightSurvivesMinimiseAndResume() {
        // The rest slab covers the bottom of the list: skip the rest rather than scroll, so the field indices
        // below keep naming the same rows (scrolling drops off-screen rows from the element list).
        let skip = app.buttons["Skip"].firstMatch
        XCTAssertTrue(skip.waitForExistence(timeout: 5))
        skip.tap()
        let weights = app.textFields.matching(identifier: "setRow.weight")
        // The incline press's first row: after the chest press's three.
        let incline = weights.element(boundBy: 3)
        XCTAssertTrue(incline.waitForExistence(timeout: 5))
        XCTAssertEqual(incline.value as? String, "55", "last session's weight is offered first")
        XCTAssertTrue(incline.isHittable)
        incline.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
        incline.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 3) + "77")
        XCTAssertEqual(incline.value as? String, "77")
        app.buttons["keyboardDone"].firstMatch.tap()

        app.buttons["minimizeWorkout"].tap()
        let resume = app.buttons["resumeWorkout"].firstMatch
        XCTAssertTrue(resume.waitForExistence(timeout: 5))
        resume.tap()
        XCTAssertTrue(app.buttons["finishWorkout"].waitForExistence(timeout: 5))

        let again = app.textFields.matching(identifier: "setRow.weight").element(boundBy: 3)
        XCTAssertTrue(again.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1) // the row's prefill task runs as it appears
        XCTAssertEqual(again.value as? String, "77", "the typed weight must survive the rows being rebuilt")
    }
}
