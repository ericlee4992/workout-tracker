import XCTest

/// Repeatable visual review fixtures for the Codex design, using real UI flows.
final class CodexScreenshotUITests: XCTestCase {
    private var app: XCUIApplication!
    private let gymName = "Gangnam Fitness"
    private let machineLabel = "Chest Press 2"
    private let modelName = "Life Fitness Insignia Series Chest Press"
    private let exerciseName = "Seated Chest Press"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestReset", "-uiTestHeartRate"]
        if name.contains("Accessibility") {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"]
        }
        addUIInterruptionMonitor(withDescription: "Simulator permissions") { alert in
            if alert.buttons["Allow"].exists {
                alert.buttons["Allow"].tap()
                return true
            }
            return false
        }
        app.launch()
        XCTAssertTrue(app.buttons["startEmptyWorkout"].waitForExistence(timeout: 15))
    }

    func testWorkoutScreens() {
        capture("codex-01-root")
        createGym()
        addMachine()
        tab("Workout").tap()
        anyElement("gymPicker").tap()
        tapOption(gymName)
        createTemplate()
        capture("codex-04-start")
        startEmptyWorkout()
        setUpZones()
        addByMachine()
        enterSet(weight: "60", reps: "10")
        app.buttons["addSet"].firstMatch.tap()
        enterSet(weight: "65", reps: "8", index: 1)
        capture("codex-02-active-workout")
        app.buttons["setRow.complete"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Skip"].waitForExistence(timeout: 5))
        capture("codex-02-active-workout-rest")
    }

    func testBarMode() {
        tab("Workout").tap()
        app.buttons["startEmptyWorkout"].tap()
        app.buttons["addExercise"].tap()
        typeInSearchField("Seated Chest")
        anyElement("exerciseOption.\(exerciseName)").tap()
        anyElement("entryEquipment").tap()
        app.buttons["Barbell"].firstMatch.tap()
        app.buttons["barPicker"].tap()
        anyElement("barOption.olympic-45lb").tap()
        enterSet(weight: "45", reps: "5")
        capture("codex-02-bar-mode")
    }

    func testAccessibilityWorkout() {
        XCTAssertTrue(app.buttons["startEmptyWorkout"].waitForExistence(timeout: 5))
        app.buttons["startEmptyWorkout"].tap()
        app.buttons["addExercise"].tap()
        typeInSearchField("Seated Chest")
        anyElement("exerciseOption.\(exerciseName)").tap()
        app.swipeUp()
        capture("codex-02-accessibility")
    }

    private func setUpZones() {
        let setup = app.buttons["hrZoneSetup"]
        XCTAssertTrue(setup.waitForExistence(timeout: 10))
        setup.tap()
        let field = app.textFields["maxHeartRateField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("180")
        app.buttons["saveMaxHeartRate"].tap()
        XCTAssertTrue(anyElement("hrZone").waitForExistence(timeout: 10))
    }

    private func createTemplate() {
        app.buttons["New Template…"].tap()
        let field = app.textFields["Template name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Core Session")
        app.buttons["Abdominal Crunch"].firstMatch.tap()
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Core Session"].waitForExistence(timeout: 5))
    }

    private func enterSet(weight: String, reps: String, index: Int = 0) {
        let field = app.textFields.matching(identifier: "setRow.weight").element(boundBy: index)
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(weight)
        let repsField = app.textFields.matching(identifier: "setRow.reps").element(boundBy: index)
        repsField.tap()
        repsField.typeText(reps)
        app.buttons["keyboardDone"].tap()
    }

    private func capture(_ name: String) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        if springboard.alerts.buttons["Allow"].waitForExistence(timeout: 1) {
            springboard.alerts.buttons["Allow"].tap()
        }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

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

        pickCatalogModel()

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

    // MARK: - Element helpers

    private func tab(_ name: String) -> XCUIElement {
        app.tabBars.buttons[name]
    }

    /// Types into the screen's search field. The seeded catalog is ~1900 models
    /// and ~75 exercises (ticket 20), so a target row is usually only rendered
    /// once a search has narrowed the list.
    private func typeInSearchField(_ text: String) {
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "This screen should be searchable")
        field.tap()
        field.typeText(text)
    }

    /// Opens the catalog-model picker and selects the fixture model.
    private func pickCatalogModel() {
        anyElement("catalogModel").tap()
        typeInSearchField("Insignia Series Chest Press")
        let modelRow = anyElement("modelOption.\(modelName)")
        XCTAssertTrue(modelRow.waitForExistence(timeout: 5), "Catalog model should be listed")
        modelRow.tap()
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

}
