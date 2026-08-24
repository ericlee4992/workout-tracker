import XCTest

/// Barbell ticket 03, end to end: pick a bar, type the plates on one end, log
/// the total, and repeat the set from Add Set's carry-forward (B1).
///
/// The assertion that matters is the last one: history says **135 lb**, not 45.
/// The stored weight is the total (D39), and every record in the app reads it.
final class BarbellUITests: XCTestCase {
    private var app: XCUIApplication!

    private let exerciseName = "Seated Chest Press"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestReset"]
        app.launch()
    }

    func testBarPlusPlatesLogsTheTotalAndCarriesForward() {
        startEmptyWorkout()
        addExercise()

        // No bar until the entry is barbell work: a bar row on a machine entry
        // would be noise.
        XCTAssertFalse(
            app.buttons["barPicker"].exists,
            "The bar row belongs to barbell and Smith entries only")

        chooseBarbellEquipment()
        let barPicker = app.buttons["barPicker"]
        XCTAssertTrue(
            barPicker.waitForExistence(timeout: 5),
            "A barbell entry should offer a bar")
        barPicker.tap()
        let olympic = app.descendants(matching: .any)
            .matching(identifier: "barOption.olympic-45lb").firstMatch
        XCTAssertTrue(olympic.waitForExistence(timeout: 5))
        olympic.tap()

        // D40: the row follows the bar into lb, and the unit badge stops being
        // a tap that could reinterpret a 45 lb bar as 45 kg.
        let unit = app.buttons["setRow.unit"].firstMatch
        XCTAssertTrue(unit.waitForExistence(timeout: 5))
        XCTAssertEqual(unit.label, "lb", "Picking an lb bar should put the row in lb")
        XCTAssertFalse(unit.isEnabled, "The unit follows the bar in bar mode")

        let weight = app.textFields["setRow.weight"].firstMatch
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        weight.tap()
        weight.typeText("45")

        // The arithmetic the feature removes, shown before the set is logged.
        let total = app.staticTexts["setRow.total"].firstMatch
        XCTAssertTrue(total.waitForExistence(timeout: 5))
        XCTAssertEqual(
            total.label, "= 135 lb",
            "45 a side on a 45 lb bar is 135 lb, and the row should say so")

        let reps = app.textFields["setRow.reps"].firstMatch
        reps.tap()
        reps.typeText("5")

        // The card in bar mode, kept as a run artifact: this screen is the
        // whole feature, and it is easier to review than to describe.
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "bar-mode-card"
        shot.lifetime = .keepAlways
        add(shot)

        app.buttons["setRow.complete"].firstMatch.tap()

        // B1 carry-forward, in bar mode: Add Set inherits the plates (not the
        // total) and the reps.
        app.buttons["addSet"].firstMatch.tap()
        let secondWeight = app.textFields.matching(identifier: "setRow.weight")
            .element(boundBy: 1)
        XCTAssertTrue(
            secondWeight.waitForExistence(timeout: 5), "Add Set should append a row")
        XCTAssertEqual(
            secondWeight.value as? String, "45",
            "The new row should show the plates per side, not the total")
        XCTAssertEqual(
            app.textFields.matching(identifier: "setRow.reps").element(boundBy: 1).value
                as? String,
            "5")

        // …and it logs with one tap, no typing.
        let secondComplete = app.buttons.matching(identifier: "setRow.complete")
            .element(boundBy: 1)
        XCTAssertEqual(secondComplete.value as? String, "Not completed")
        secondComplete.tap()
        XCTAssertEqual(secondComplete.value as? String, "Completed")

        finishWorkout()

        // History: the total, with the bar shown under it.
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(
            app.staticTexts[exerciseName].waitForExistence(timeout: 5))
        app.staticTexts[exerciseName].tap()
        XCTAssertTrue(
            app.staticTexts["135 lb × 5"].waitForExistence(timeout: 5),
            "History must record the total lifted, not the plates typed")
        XCTAssertTrue(
            app.staticTexts["45 + 45 × 2 = 135 lb"].firstMatch.exists,
            "…with the bar it was loaded on")
    }

    func testEqualValuedBarInAnotherUnitClearsTheOldPlateInput() {
        startEmptyWorkout()
        addExercise()
        chooseBarbellEquipment()

        chooseBar(identifier: "barOption.technique-15lb")
        let weight = app.textFields["setRow.weight"].firstMatch
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        weight.tap()
        weight.typeText("10")
        app.buttons["keyboardDone"].tap()
        XCTAssertEqual(weight.value as? String, "10")

        // Both bars weigh 15 as-entered, so observing barWeightValue alone does
        // not fire. The unit change is part of the input mode and must clear the
        // old lb plate text before it can be recommitted as kg.
        chooseBar(identifier: "barOption.womens-15kg")

        XCTAssertEqual(app.buttons["setRow.unit"].firstMatch.label, "kg")
        XCTAssertTrue(
            ["", "–"].contains(weight.value as? String ?? "<missing>"),
            "lb plates must not survive as kg when equal-valued bars are switched")
        XCTAssertFalse(app.buttons["setRow.complete"].firstMatch.isEnabled)
    }

    // MARK: - Flow helpers

    private func startEmptyWorkout() {
        app.tabBars.buttons["Workout"].tap()
        let start = app.buttons["startEmptyWorkout"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        XCTAssertTrue(app.buttons["finishWorkout"].waitForExistence(timeout: 5))
    }

    private func addExercise() {
        app.buttons["addExercise"].tap()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Seated Chest")
        let option = app.descendants(matching: .any)
            .matching(identifier: "exerciseOption.\(exerciseName)").firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 10))
        option.tap()
        XCTAssertTrue(app.staticTexts[exerciseName].waitForExistence(timeout: 5))
    }

    private func chooseBarbellEquipment() {
        let equipment = app.descendants(matching: .any)
            .matching(identifier: "entryEquipment").firstMatch
        XCTAssertTrue(equipment.waitForExistence(timeout: 5))
        equipment.tap()
        let barbell = app.buttons["Barbell"].firstMatch
        XCTAssertTrue(barbell.waitForExistence(timeout: 5))
        barbell.tap()
    }

    private func chooseBar(identifier: String) {
        let picker = app.buttons["barPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.tap()
        let option = app.descendants(matching: .any)
            .matching(identifier: identifier).firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        option.tap()
    }

    private func finishWorkout() {
        app.buttons["finishWorkout"].tap()
        let done = app.buttons["finishedDone"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
    }
}
