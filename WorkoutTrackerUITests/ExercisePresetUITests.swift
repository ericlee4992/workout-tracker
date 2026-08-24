import XCTest

/// Exercise presets (D36–D38) end to end: define one, make it a machine's
/// usual, and switch it mid-workout.
///
/// The switch is the part worth driving through the real UI — it is the only
/// place where the D19 freeze rule is visible to a person: change grips after
/// logging a set and you get a *second* exercise card, not a relabelled one.
final class ExercisePresetUITests: XCTestCase {
    private var app: XCUIApplication!

    private let gymName = "Preset Test Gym"
    private let machineLabel = "Cable Row 2"
    private let modelName = "Life Fitness Insignia Series Row"
    private let exerciseName = "Seated Row"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestReset"]
        app.launch()
    }

    func testPresetsAreDefinedChosenAndFrozenOnceLogged() {
        definePresets()
        createGym()
        addMachine()

        // --- Log on the machine's usual preset ------------------------------
        startEmptyWorkout()
        addByMachine()

        let wideChip = anyElement("presetChip.Wide grip")
        XCTAssertTrue(
            wideChip.waitForExistence(timeout: 5),
            "The entry card should offer the exercise's presets")
        XCTAssertTrue(
            anyElement("presetChip.Narrow grip").exists,
            "Every preset should be one tap away, not buried in a menu")

        logSet(weight: "70", reps: "8")

        // --- Switching after a logged set splits the entry (D19 + D36) ------
        anyElement("presetChip.Narrow grip").tap()

        let cards = app.staticTexts.matching(
            NSPredicate(format: "label == %@", exerciseName))
        XCTAssertTrue(
            cards.count >= 2,
            "Switching preset after a logged set must start a new entry, "
                + "not relabel the one holding completed sets")

        finishWorkout()

        // --- History names the variation ------------------------------------
        tab("History").tap()
        let row = app.staticTexts[exerciseName].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "The workout should be in History")
        row.tap()

        // The equipment line in the workout detail is snapshot-rendered, so
        // this is the preset as it was recorded, not as it is named now.
        let equipment = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "Wide grip")).firstMatch
        XCTAssertTrue(
            equipment.waitForExistence(timeout: 5),
            "The logged set should say which variation it was performed in")
    }

    func testChangingPresetClearsPrefilledInputsBeforeTheyCanBeLogged() {
        definePresets()
        createGym()
        addMachine()

        startEmptyWorkout()
        addByMachine()
        logSet(weight: "70", reps: "8")
        finishWorkout()

        // The same machine and its usual Wide grip preset should prefill the
        // previous performance into the next workout.
        startEmptyWorkout()
        addByMachine()
        let weight = app.textFields["setRow.weight"].firstMatch
        let reps = app.textFields["setRow.reps"].firstMatch
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        XCTAssertEqual(weight.value as? String, "70")
        XCTAssertEqual(reps.value as? String, "8")

        anyElement("presetChip.Narrow grip").tap()

        XCTAssertTrue(
            ["", "–"].contains(weight.value as? String ?? "<missing>"),
            "Wide-grip prefill must leave the field when Narrow grip is chosen")
        XCTAssertTrue(["", "–"].contains(reps.value as? String ?? "<missing>"))
        XCTAssertFalse(
            app.buttons["setRow.complete"].firstMatch.isEnabled,
            "stale prefill must not remain one tap from being logged under another preset")
    }

    // MARK: - Steps

    private func definePresets() {
        tab("Exercises").tap()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(exerciseName)

        let row = app.staticTexts[exerciseName].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "The seeded exercise should be listed")
        row.press(forDuration: 1.2)
        app.buttons["Presets…"].firstMatch.tap()

        XCTAssertTrue(
            anyElement("noPresets").waitForExistence(timeout: 5),
            "A fresh exercise has no presets")
        // One from the suggestions, one typed — both paths matter at a gym.
        anyElement("presetSuggestion.Wide grip").tap()
        let name = app.textFields["newPresetName"]
        name.tap()
        name.typeText("Narrow grip")
        app.buttons["addPreset"].tap()

        XCTAssertTrue(anyElement("preset.Wide grip").exists)
        XCTAssertTrue(anyElement("preset.Narrow grip").exists)
        app.buttons["Done"].tap()
    }

    private func createGym() {
        tab("Gyms").tap()
        app.buttons["addGym"].tap()
        let name = app.textFields["gymName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText(gymName)
        app.buttons["saveGym"].tap()
        XCTAssertTrue(anyElement("gymRow.\(gymName)").waitForExistence(timeout: 5))
    }

    private func addMachine() {
        anyElement("gymRow.\(gymName)").tap()
        let add = app.buttons["addMachine"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()

        let label = app.textFields["machineLabel"]
        XCTAssertTrue(label.waitForExistence(timeout: 5))
        label.tap()
        label.typeText(machineLabel)

        anyElement("catalogModel").tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Insignia Series Row")
        let modelRow = anyElement("modelOption.\(modelName)")
        XCTAssertTrue(modelRow.waitForExistence(timeout: 5), "Catalog model should be listed")
        modelRow.tap()

        // D38: the machine's usual preset, offered because this model serves
        // exactly one exercise.
        let picker = anyElement("machinePresetPicker")
        XCTAssertTrue(
            picker.waitForExistence(timeout: 5),
            "A single-exercise machine should offer that exercise's presets")
        picker.tap()
        app.buttons["Wide grip"].firstMatch.tap()

        app.buttons["saveMachine"].tap()
        XCTAssertTrue(app.staticTexts[machineLabel].waitForExistence(timeout: 5))
    }

    private func startEmptyWorkout() {
        tab("Workout").tap()
        // The picker resets to "No gym" on a fresh screen, and Add by Machine
        // only lists the machines of the workout's gym.
        let picker = anyElement("gymPicker")
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        if !picker.label.contains(gymName) {
            picker.tap()
            tapOption(gymName)
        }
        app.buttons["startEmptyWorkout"].tap()
    }

    /// Taps an option however SwiftUI rendered it — menu item, pushed row, or
    /// plain cell.
    private func tapOption(_ label: String) {
        let button = app.buttons[label]
        if button.waitForExistence(timeout: 3) {
            button.tap()
            return
        }
        let text = app.staticTexts[label]
        XCTAssertTrue(text.waitForExistence(timeout: 3), "No option labelled \(label)")
        text.tap()
    }

    private func addByMachine() {
        let add = app.buttons["addByMachine"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        let machine = anyElement("machineOption.\(machineLabel)")
        XCTAssertTrue(machine.waitForExistence(timeout: 5))
        machine.tap()
    }

    private func logSet(weight: String, reps: String) {
        let weightField = app.textFields["setRow.weight"].firstMatch
        XCTAssertTrue(weightField.waitForExistence(timeout: 5))
        weightField.tap()
        weightField.typeText(weight)
        let repsField = app.textFields["setRow.reps"].firstMatch
        repsField.tap()
        repsField.typeText(reps)
        app.buttons["setRow.complete"].firstMatch.tap()
    }

    private func finishWorkout() {
        app.buttons["finishWorkout"].tap()
        let done = app.buttons["Done"].firstMatch
        if done.waitForExistence(timeout: 5) { done.tap() }
    }

    private func tab(_ name: String) -> XCUIElement {
        app.tabBars.buttons[name]
    }

    private func anyElement(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }
}
