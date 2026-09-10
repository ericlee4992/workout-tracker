import XCTest

/// Machine deletion (2026-09-10): "delete added machines from gym (whether
/// mid workout, or just at gym tab)". Delete is the user's word; D10 keeps
/// archival underneath, so the gym's "Deleted machines" list can restore.
final class MachineDeletionUITests: XCTestCase {
    private var app: XCUIApplication!
    private let gymName = "Delete Test Gym"
    private let machineLabel = "Old Leg Press"
    /// The machine's catalog model and the one exercise it serves, so tapping
    /// the machine mid-workout logs directly (D7).
    private let modelName = "Life Fitness Insignia Series Chest Press"
    private let exerciseName = "Seated Chest Press"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestReset"]
        app.launch()
    }

    /// Gyms tab: swipe → Delete → confirm → gone; Deleted machines → Restore → back.
    func testDeleteFromTheGymsTabAndRestore() {
        createGym()
        addMachine()

        let row = anyElement("machineRow.\(machineLabel)")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeLeft()
        let delete = app.buttons["deleteMachine.\(machineLabel)"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "the swipe reveals Delete")
        delete.tap()

        // Cancel first: the dialog is the safety net, and it must change nothing.
        XCTAssertTrue(app.buttons["Delete Machine"].waitForExistence(timeout: 5), "a confirmation (with Cancel) stands between the swipe and the deletion")
        app.alerts.buttons["Cancel"].firstMatch.tap()
        XCTAssertTrue(waitForAbsence(of: app.buttons["Delete Machine"]), "the alert is dismissed")
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Cancel leaves the machine where it was")
        XCTAssertFalse(anyElement("deletedMachines").exists)

        row.swipeLeft()
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()
        XCTAssertTrue(app.buttons["Delete Machine"].waitForExistence(timeout: 5))
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "delete-machine-confirmation"
        shot.lifetime = .keepAlways
        add(shot)
        app.buttons["Delete Machine"].tap()

        XCTAssertTrue(waitForAbsence(of: row), "the machine leaves the gym's list")
        let deleted = anyElement("deletedMachines")
        XCTAssertTrue(deleted.waitForExistence(timeout: 5), "the gym now offers its deleted machines")
        XCTAssertTrue(deleted.label.contains("1"), "got: \(deleted.label)")
        deleted.tap()

        let restore = app.buttons["restoreMachine.\(machineLabel)"]
        XCTAssertTrue(restore.waitForExistence(timeout: 5), "the deleted machine is listed with Restore")
        restore.tap()
        XCTAssertTrue(app.staticTexts["Nothing deleted"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(row.waitForExistence(timeout: 5), "restored, the machine is back in the gym's list")
        XCTAssertFalse(anyElement("deletedMachines").exists, "and the deleted list is gone")
    }

    /// Mid-workout: a set already logged on the machine, then the same swipe
    /// on the Add-by-Machine sheet. The entry stays on the workout screen with
    /// its numbers, reaches History, and the gym agrees the machine is gone
    /// (codex-review-01: the current-workout claim, pinned).
    func testDeleteMidWorkoutKeepsTheLoggedEntryAndTheGymAgrees() {
        createGym()
        addMachine()
        startEmptyWorkout()

        // Log one set on the machine.
        let addByMachine = app.buttons["addByMachine"]
        XCTAssertTrue(addByMachine.waitForExistence(timeout: 5))
        addByMachine.tap()
        let option = anyElement("machineOption.\(machineLabel)")
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        option.tap()
        XCTAssertTrue(app.staticTexts[exerciseName].waitForExistence(timeout: 5), "a one-exercise model logs its exercise on the tap")
        let weight = app.textFields["setRow.weight"].firstMatch
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        weight.tap()
        weight.typeText("80")
        let reps = app.textFields["setRow.reps"].firstMatch
        reps.tap()
        reps.typeText("8")
        app.buttons["setRow.complete"].firstMatch.tap()

        // Now delete the machine from the same sheet.
        addByMachine.tap()
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        option.swipeLeft()
        let delete = app.buttons["deleteMachine.\(machineLabel)"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "the swipe reveals Delete mid-workout too")
        delete.tap()
        XCTAssertTrue(app.buttons["Delete Machine"].waitForExistence(timeout: 5))
        app.buttons["Delete Machine"].tap()
        XCTAssertTrue(waitForAbsence(of: option), "the machine leaves the sheet")
        XCTAssertTrue(app.staticTexts["No machines yet"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].firstMatch.tap()

        // The entry logged on it is untouched: still here, still 80 × 8.
        XCTAssertTrue(app.staticTexts[exerciseName].waitForExistence(timeout: 5), "the entry stays on the workout screen")
        XCTAssertEqual(app.textFields["setRow.weight"].firstMatch.value as? String, "80")
        XCTAssertEqual(app.textFields["setRow.reps"].firstMatch.value as? String, "8")

        // Finish: History shows the workout with that exercise.
        app.buttons["finishWorkout"].tap()
        let done = app.buttons["finishedDone"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
        tab("History").tap()
        XCTAssertTrue(app.staticTexts[exerciseName].waitForExistence(timeout: 5), "the workout reached History with the deleted machine's entry")

        // The Gyms tab agrees: gone from the list, one deleted machine to restore.
        tab("Gyms").tap()
        // The tab is still on the gym's detail page from earlier; if it shows
        // the list instead, open the gym.
        let gymRow = anyElement("gymRow.\(gymName)")
        if gymRow.waitForExistence(timeout: 2) { gymRow.tap() }
        XCTAssertTrue(anyElement("deletedMachines").waitForExistence(timeout: 5))
        XCTAssertFalse(anyElement("machineRow.\(machineLabel)").exists)
    }

    // MARK: - Helpers


    private func waitForAbsence(of element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let gone = NSPredicate(format: "exists == false")
        return XCTWaiter().wait(for: [expectation(for: gone, evaluatedWith: element)], timeout: timeout) == .completed
    }

    private func tab(_ name: String) -> XCUIElement {
        app.tabBars.buttons[name]
    }

    private func anyElement(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func createGym() {
        tab("Gyms").tap()
        app.buttons["addGym"].tap()
        let name = app.textFields["gymName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        _ = app.keyboards.firstMatch.waitForExistence(timeout: 3)
        name.typeText(gymName)
        app.buttons["saveGym"].tap()
        XCTAssertTrue(anyElement("gymRow.\(gymName)").waitForExistence(timeout: 5))
    }

    /// A machine on a real catalog model (one exercise), as the user's are.
    private func addMachine() {
        anyElement("gymRow.\(gymName)").tap()
        let add = app.buttons["addMachine"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        let label = app.textFields["machineLabel"]
        XCTAssertTrue(label.waitForExistence(timeout: 5))
        label.tap()
        _ = app.keyboards.firstMatch.waitForExistence(timeout: 3)
        label.typeText(machineLabel)
        anyElement("catalogModel").tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Insignia Series Chest Press")
        let modelRow = anyElement("modelOption.\(modelName)")
        XCTAssertTrue(modelRow.waitForExistence(timeout: 5), "the catalog model is listed")
        modelRow.tap()
        XCTAssertTrue(app.textFields["machineLabel"].waitForExistence(timeout: 5))
        app.buttons["saveMachine"].tap()
        XCTAssertTrue(anyElement("machineRow.\(machineLabel)").waitForExistence(timeout: 5), "the new machine is listed at the gym")
    }

    private func startEmptyWorkout() {
        tab("Workout").tap()
        let picker = anyElement("gymPicker")
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        if !picker.label.contains(gymName) {
            picker.tap()
            let option = app.buttons[gymName].firstMatch
            XCTAssertTrue(option.waitForExistence(timeout: 5))
            option.tap()
        }
        app.buttons["startEmptyWorkout"].tap()
    }
}
