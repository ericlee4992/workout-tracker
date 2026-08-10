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
        // E1/E2 (ticket 17): the row is headlined by what was performed, not
        // by the gym, and the counts agree with their nouns.
        XCTAssertTrue(
            app.staticTexts[exerciseName].waitForExistence(timeout: 5),
            "The history row should be titled by the exercise performed")
        let summary = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "1 exercise · 1 set")).firstMatch
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
            NSPredicate(format: "label CONTAINS %@", "1 exercise · 1 set"))
        XCTAssertEqual(rows.count, 2, "Both workouts should be in History")
    }

    // MARK: - A2: an empty workout never reaches History

    /// Ticket 17 A2: Start → Finish with nothing logged leaves no trace, and
    /// says so rather than confirming a save that never happened.
    func testFinishingAnEmptyWorkoutDiscardsItAndSaysSo() {
        tab("Workout").tap()
        app.buttons["startEmptyWorkout"].tap()
        XCTAssertTrue(app.buttons["finishWorkout"].waitForExistence(timeout: 5))

        // D1: with no gym the machine-first path stays visible and explains
        // itself instead of silently disappearing.
        let addByMachine = app.buttons["addByMachine"]
        XCTAssertTrue(
            addByMachine.waitForExistence(timeout: 5),
            "Add by Machine should stay visible without a gym")
        XCTAssertFalse(addByMachine.isEnabled, "…but disabled")
        XCTAssertTrue(
            anyElement("addByMachineUnavailable").exists,
            "…with a short explanation of why")

        app.buttons["finishWorkout"].tap()
        let summary = app.staticTexts["finishedSummary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertTrue(
            summary.label.contains("wasn't saved"),
            "Finishing an empty workout should say nothing was saved, got: \(summary.label)")
        app.buttons["finishedDone"].tap()

        tab("History").tap()
        XCTAssertTrue(
            app.staticTexts["No workouts yet"].waitForExistence(timeout: 5),
            "An empty workout must never reach History")
    }

    // MARK: - C2: the receipt links to the workout, not just the tab

    /// Ticket 17 C2 (post-review): "View in History" used to select the
    /// History tab and stop there. It must open the workout just logged.
    func testViewInHistoryOpensTheWorkoutJustLogged() {
        createGym()
        addMachine()
        startEmptyWorkout()
        addByMachine()

        let weight = app.textFields["setRow.weight"].firstMatch
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        weight.tap()
        weight.typeText("70")
        let reps = app.textFields["setRow.reps"].firstMatch
        reps.tap()
        reps.typeText("8")
        app.buttons["setRow.complete"].firstMatch.tap()

        app.buttons["finishWorkout"].tap()
        let link = app.buttons["viewFinishedWorkout"]
        XCTAssertTrue(link.waitForExistence(timeout: 5))
        link.tap()

        // The workout detail screen, not the History list: it renders the
        // snapshot equipment label and the per-workout unit toggle.
        XCTAssertTrue(
            app.buttons["As entered"].waitForExistence(timeout: 5),
            "View in History should push the finished workout's detail")
        XCTAssertTrue(
            app.staticTexts["70 kg × 8"].waitForExistence(timeout: 5),
            "The opened workout should show the set just logged")
    }

    // MARK: - D2/D3: gyms and machines are editable

    /// Ticket 17 D2: a gym's unit and city are corrections, not one-shot
    /// choices. D3: picking a catalog model names the machine for you.
    func testGymSettingsAreEditableAndModelNamesTheMachine() {
        createGym()

        anyElement("gymRow.\(gymName)").tap()
        app.buttons["editGym"].tap()
        let city = app.textFields["City (optional)"]
        XCTAssertTrue(city.waitForExistence(timeout: 5))
        city.tap()
        city.typeText("Seoul")
        anyElement("gymUnitPicker").tap()
        tapOption("lb")
        app.buttons["saveGym"].tap()

        XCTAssertTrue(
            app.staticTexts["Seoul"].waitForExistence(timeout: 5),
            "The edited city should show on the gym")

        // D3: a model supplies the label, so Add is enabled without typing.
        app.buttons["addMachine"].tap()
        XCTAssertTrue(app.textFields["machineLabel"].waitForExistence(timeout: 5))
        let save = app.buttons["saveMachine"]
        XCTAssertFalse(save.isEnabled, "A label-less, model-less machine cannot be added")
        anyElement("catalogModel").tap()
        let modelRow = anyElement("modelOption.\(modelName)")
        XCTAssertTrue(modelRow.waitForExistence(timeout: 5))
        modelRow.tap()
        XCTAssertTrue(save.isEnabled, "Picking a model should supply a default label")
        save.tap()

        // D2: the machine's default unit is editable after creation.
        let machineRow = app.staticTexts["Insignia Series Chest Press"]
        XCTAssertTrue(
            machineRow.waitForExistence(timeout: 5),
            "The machine should be labelled after the model")
        machineRow.press(forDuration: 1.2)
        app.buttons["Edit Machine…"].tap()
        XCTAssertTrue(anyElement("machineUnitPicker").waitForExistence(timeout: 5))
        anyElement("machineUnitPicker").tap()
        tapOption("kg")
        app.buttons["saveMachine"].tap()
        XCTAssertTrue(machineRow.waitForExistence(timeout: 5))
    }

    // MARK: - B1: within-session carry-forward

    /// Ticket 17 B1: the second set of an exercise must not be retyped. Add
    /// Set inherits the last completed row's weight, unit and reps, arrives
    /// uncompleted, and logs in a single tap.
    func testAddSetCarriesForwardTheLastCompletedSet() {
        createGym()
        addMachine()
        startEmptyWorkout()
        addByMachine()

        let weight = app.textFields["setRow.weight"].firstMatch
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        weight.tap()
        weight.typeText("80")
        let reps = app.textFields["setRow.reps"].firstMatch
        reps.tap()
        reps.typeText("12")
        app.buttons["setRow.unit"].firstMatch.tap() // kg → lb, as entered
        app.buttons["setRow.complete"].firstMatch.tap()

        app.buttons["addSet"].firstMatch.tap()

        let secondWeight = app.textFields.matching(identifier: "setRow.weight")
            .element(boundBy: 1)
        XCTAssertTrue(
            secondWeight.waitForExistence(timeout: 5), "Add Set should append a row")
        XCTAssertEqual(
            value(of: secondWeight), "80",
            "The new set should inherit the last completed set's weight")
        XCTAssertEqual(
            value(of: app.textFields.matching(identifier: "setRow.reps").element(boundBy: 1)),
            "12",
            "The new set should inherit the last completed set's reps")
        XCTAssertEqual(
            app.buttons.matching(identifier: "setRow.unit").element(boundBy: 1).label, "lb",
            "The new set should inherit the unit as entered")

        // Populated but uncompleted: one tap logs it, no typing.
        let secondComplete = app.buttons.matching(identifier: "setRow.complete")
            .element(boundBy: 1)
        XCTAssertEqual(completeValue(of: secondComplete), "Not completed")
        secondComplete.tap()
        XCTAssertEqual(
            completeValue(of: secondComplete), "Completed",
            "One tap should log the carried-forward set")

        finishWorkout()
    }

    // MARK: - Ticket 18 B: swipe-to-delete on a set row

    /// Deleting a set was always possible from the row's menu; nobody found
    /// it. The swipe is the discoverable half of the same action — and
    /// deleting an entry's *last* set must leave the exercise standing, not
    /// quietly remove it mid-workout.
    func testSwipeToDeleteRemovesASetAndLeavesTheExerciseIntact() {
        createGym()
        addMachine()
        startEmptyWorkout()
        addByMachine()

        XCTAssertTrue(
            app.textFields["setRow.weight"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["addSet"].firstMatch.tap()
        XCTAssertEqual(setRowCount(), 2, "Add Set should append a second row")

        swipeLeftOnSetRow(at: 1)
        let delete = app.buttons["setRow.swipeDelete"].firstMatch
        XCTAssertTrue(
            delete.waitForExistence(timeout: 5),
            "Swiping a set row left should reveal a Delete action")
        delete.tap()
        XCTAssertTrue(
            waitForSetRowCount(1), "Swipe-to-delete should remove the swiped set")

        // The last remaining set: the exercise stays, ready to log again.
        swipeLeftOnSetRow(at: 0)
        let deleteLast = app.buttons["setRow.swipeDelete"].firstMatch
        XCTAssertTrue(deleteLast.waitForExistence(timeout: 5))
        deleteLast.tap()
        XCTAssertTrue(
            waitForSetRowCount(0), "The last set should be deletable too")
        XCTAssertTrue(
            app.staticTexts[exerciseName].exists,
            "Deleting the last set must not remove the exercise mid-workout")
        XCTAssertTrue(
            app.buttons["addSet"].firstMatch.exists,
            "The emptied exercise must stay usable")

        // Leave nothing behind.
        app.buttons["Cancel"].firstMatch.tap()
        app.buttons["Discard Workout"].firstMatch.tap()
        XCTAssertTrue(tab("History").waitForExistence(timeout: 5))
    }

    private func setRowCount() -> Int {
        app.textFields.matching(identifier: "setRow.weight").count
    }

    private func waitForSetRowCount(_ expected: Int, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if setRowCount() == expected { return true }
            _ = app.wait(for: .runningForeground, timeout: 0.2)
        }
        return setRowCount() == expected
    }

    /// A horizontal drag across the row's PREVIOUS column — the one wide part
    /// of the row that is neither a text field nor a button.
    private func swipeLeftOnSetRow(at index: Int) {
        let label = app.staticTexts.matching(identifier: "setRow.previous")
            .element(boundBy: index)
        XCTAssertTrue(label.waitForExistence(timeout: 5))
        let start = label.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
        start.press(
            forDuration: 0.1,
            thenDragTo: start.withOffset(CGVector(dx: -140, dy: 0)))
    }

    // MARK: - C1: leaving and resuming an active workout

    /// Ticket 17 C1: the active workout is no longer a trap — it can be
    /// minimised, the tabs are usable, and the Workout tab offers the way
    /// back in.
    func testMinimizeKeepsTheWorkoutActiveAndResumeReopensIt() {
        tab("Workout").tap()
        app.buttons["startEmptyWorkout"].tap()
        XCTAssertTrue(app.buttons["finishWorkout"].waitForExistence(timeout: 5))

        app.buttons["minimizeWorkout"].tap()

        let resume = app.buttons["resumeWorkout"]
        XCTAssertTrue(
            resume.waitForExistence(timeout: 5),
            "Minimising should reveal a resume affordance on the Workout tab")

        // The tab bar is genuinely usable again.
        let history = tab("History")
        XCTAssertTrue(history.isHittable, "The tab bar should be hittable once minimised")
        history.tap()
        tab("Workout").tap()

        XCTAssertTrue(resume.waitForExistence(timeout: 5))
        resume.tap()
        XCTAssertTrue(
            app.buttons["finishWorkout"].waitForExistence(timeout: 5),
            "Resuming should reopen the still-active workout")

        // Leave nothing behind.
        app.buttons["Cancel"].firstMatch.tap()
        app.buttons["Discard Workout"].firstMatch.tap()
        XCTAssertTrue(tab("History").waitForExistence(timeout: 5))
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
        // B2/C2 (ticket 17): Finish finishes on the first tap; what follows
        // is a confirmation of what was saved, not a question blocking it.
        let done = app.buttons["finishedDone"]
        XCTAssertTrue(
            done.waitForExistence(timeout: 5),
            "Finishing should confirm what was saved")
        done.tap()
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
