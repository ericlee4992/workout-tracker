import XCTest

/// End-to-end walkthrough of the product's core claim: create a gym and a
/// machine, log a set on it, finish, and prove the *second* workout on the
/// same machine arrives prefilled and needs a single tap to log the repeat
/// set (ticket 11 / SPEC "Speed bar").
///
/// The app is launched with `-uiTestReset` so every run starts from an empty
/// store (only the seeded catalog is present).
final class CoreLoopUITests: XCTestCase {
    private var app: XCUIApplication!

    private let gymName = "Gangnam Fitness"
    private let machineLabel = "Chest Press 2"
    private let modelName = "Life Fitness Insignia Series Chest Press"
    private let exerciseName = "Seated Chest Press"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestReset"]
        app.launch()
    }

    // MARK: - The walkthrough

    func testCoreLoopFromEmptyStoreToOneTapRepeatSet() {
        createGym()
        addMachine()

        // --- First workout -------------------------------------------------
        startEmptyWorkout()
        addByMachine()

        // D7: a single-exercise machine fills its exercise in with zero
        // further prompts — the sheet closes straight onto the entry.
        XCTAssertTrue(
            app.staticTexts[exerciseName].waitForExistence(timeout: 5),
            "Picking a single-exercise machine should auto-fill its exercise")

        let weight = app.textFields["setRow.weight"].firstMatch
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        weight.tap()
        weight.typeText("60")

        let reps = app.textFields["setRow.reps"].firstMatch
        reps.tap()
        reps.typeText("10")

        // Unit chip: the gym default is kg; one tap makes this set lb.
        let unitChip = app.buttons["setRow.unit"].firstMatch
        XCTAssertEqual(unitChip.label, "kg", "Gym default unit should seed the set")
        unitChip.tap()
        XCTAssertEqual(unitChip.label, "lb", "Tapping the unit chip should switch the set to lb")

        let complete = app.buttons["setRow.complete"].firstMatch
        complete.tap()
        XCTAssertEqual(completeValue(of: complete), "Completed")

        finishWorkout()

        // --- History -------------------------------------------------------
        tab("History").tap()
        let summary = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "1 exercises · 1 sets")).firstMatch
        XCTAssertTrue(
            summary.waitForExistence(timeout: 5),
            "The finished workout should appear in History with 1 exercise and 1 set")

        // --- Second workout on the same machine ----------------------------
        startEmptyWorkout()
        addByMachine()

        let previous = app.staticTexts["setRow.previous"].firstMatch
        XCTAssertTrue(previous.waitForExistence(timeout: 5))
        XCTAssertEqual(
            previous.label, "60 lb × 10",
            "The PREVIOUS column should show last session's set on this machine")

        let repeatWeight = app.textFields["setRow.weight"].firstMatch
        XCTAssertEqual(value(of: repeatWeight), "60", "Prefill should populate the weight field")
        XCTAssertEqual(
            value(of: app.textFields["setRow.reps"].firstMatch), "10",
            "Prefill should populate the reps field")
        XCTAssertEqual(
            app.buttons["setRow.unit"].firstMatch.label, "lb",
            "Prefill should keep the unit as entered last time")

        // The one-tap guarantee: an untouched prefilled row is logged by a
        // single tap on the checkmark — no typing, no extra confirmation.
        let repeatComplete = app.buttons["setRow.complete"].firstMatch
        XCTAssertEqual(completeValue(of: repeatComplete), "Not completed")
        repeatComplete.tap()
        XCTAssertEqual(
            completeValue(of: repeatComplete), "Completed",
            "One tap on the checkmark should log the repeat set")

        finishWorkout()

        tab("History").tap()
        let rows = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "1 exercises · 1 sets"))
        XCTAssertEqual(rows.count, 2, "Both workouts should be in History")
    }

    // MARK: - Flow helpers

    private func createGym() {
        tab("Gyms").tap()
        app.buttons["addGym"].tap()

        let name = app.textFields["gymName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText(gymName)

        anyElement("gymUnitPicker").tap()
        tapOption("kg")

        app.buttons["saveGym"].tap()
        XCTAssertTrue(
            anyElement("gymRow.\(gymName)").waitForExistence(timeout: 5),
            "The new gym should be listed")
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
        let modelRow = anyElement("modelOption.\(modelName)")
        XCTAssertTrue(modelRow.waitForExistence(timeout: 5), "Catalog model should be listed")
        modelRow.tap()

        app.buttons["saveMachine"].tap()
        XCTAssertTrue(
            app.staticTexts[machineLabel].waitForExistence(timeout: 5),
            "The new machine should be listed at the gym")
    }

    private func startEmptyWorkout() {
        tab("Workout").tap()
        // Pick the gym (the picker resets to "No gym" on a fresh screen).
        let picker = anyElement("gymPicker")
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        if !picker.label.contains(gymName) {
            picker.tap()
            tapOption(gymName)
        }
        app.buttons["startEmptyWorkout"].tap()
    }

    private func addByMachine() {
        let addByMachine = app.buttons["addByMachine"]
        XCTAssertTrue(
            addByMachine.waitForExistence(timeout: 5),
            "The active workout should offer the machine-first path at a gym")
        addByMachine.tap()

        let machine = anyElement("machineOption.\(machineLabel)")
        XCTAssertTrue(machine.waitForExistence(timeout: 5))
        machine.tap()
    }

    private func finishWorkout() {
        app.buttons["finishWorkout"].tap()
        // A from-scratch workout with completed sets asks whether to keep it
        // as a template before it will finish — the toolbar "Finish" only
        // opens that dialog, so finishing always costs a second tap.
        let confirm = app.sheets.buttons["Finish"].firstMatch
        if confirm.waitForExistence(timeout: 3) {
            confirm.tap()
        }
        XCTAssertTrue(
            tab("History").waitForExistence(timeout: 5),
            "Finishing should return to the tab bar")
    }

    // MARK: - Element helpers

    private func tab(_ name: String) -> XCUIElement {
        app.tabBars.buttons[name]
    }

    /// Identifier lookup that does not care which element type SwiftUI chose
    /// for a row, picker, or menu.
    private func anyElement(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// Taps an option by its visible label, whether it renders as a menu
    /// item, a pushed list row, or a plain cell.
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

    private func value(of element: XCUIElement) -> String? {
        element.value as? String
    }

    private func completeValue(of element: XCUIElement) -> String? {
        value(of: element)
    }
}
