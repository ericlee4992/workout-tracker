import XCTest

/// Milestone 9, ticket 04 — the equipment sheet offers the dumbbell EXERCISE
/// where it used to offer the Dumbbell tag, so the split cannot re-grow.
final class DumbbellCounterpartUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestReset"]
        app.launch()
    }

    func testBenchPressOffersDumbbellBenchPressInsteadOfTheTag() {
        app.tabBars.buttons["Workout"].tap()
        let start = app.buttons["startEmptyWorkout"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()

        app.buttons["addExercise"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Bench Press")
        let option = app.descendants(matching: .any)
            .matching(identifier: "exerciseOption.Bench Press").firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 10))
        // Tapping the row's TEXT rather than the identified button: with the
        // keyboard up, a tap on the row element itself did not register here
        // (the same XCUITest quirk STATE records for picker rows).
        let row = option.staticTexts["Bench Press"].firstMatch
        (row.exists ? row : option).tap()
        // The card's equipment chip is the proof an entry exists; the title is
        // checked by visible text, the pattern BarbellUITests already relies on.
        let equipment = app.descendants(matching: .any)
            .matching(identifier: "entryEquipment").firstMatch
        XCTAssertTrue(equipment.waitForExistence(timeout: 10), "adding Bench Press should create an entry")
        XCTAssertTrue(app.staticTexts["Bench Press"].firstMatch.exists)
        equipment.tap()

        let counterpart = app.buttons["logAsCounterpart"]
        XCTAssertTrue(counterpart.waitForExistence(timeout: 5), "Bench Press should offer its dumbbell counterpart")
        XCTAssertTrue(counterpart.label.contains("Dumbbell Bench Press"))
        XCTAssertFalse(app.buttons["Dumbbell"].exists, "the bare tag must not also be offered")

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "equipment-counterpart"
        shot.lifetime = .keepAlways
        add(shot)

        counterpart.tap()
        XCTAssertTrue(app.staticTexts["Dumbbell Bench Press"].firstMatch.waitForExistence(timeout: 10),
                      "the entry should now be Dumbbell Bench Press")
        XCTAssertFalse(app.staticTexts["Bench Press"].exists, "and no longer plain Bench Press")
    }
}
