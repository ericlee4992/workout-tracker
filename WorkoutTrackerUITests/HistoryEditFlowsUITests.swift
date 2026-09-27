import XCTest

// Floodlight redesign ticket 05 (Codex review 05): the History edits end to end on the design
// sample (Leg Day yesterday: Leg Press, Leg Extension, Seated Leg Curl, Calf Raise — 9 sets; no
// other workout has 10). An added set or exercise the user abandons leaves nothing — by Cancel
// or by swiping the editor away — a saved one stays; notes are saved and marked; deleting an
// exercise's last set, from the editor or by a swipe, removes the exercise and says so first.
final class HistoryEditFlowsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestReset", "-uiTestDesignSample", "-uiTestDesignHistory"]
        app.launch()
    }

    private func any(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    /// On screen and clear of the tab bar (a button under the bar is "hittable" but the tap
    /// lands on the bar).
    private func reach(_ element: XCUIElement, up: Bool = true) {
        let bar = app.tabBars.firstMatch
        func visible() -> Bool {
            element.exists && element.isHittable && (!bar.exists || element.frame.maxY < bar.frame.minY)
        }
        for _ in 0..<10 where !visible() { up ? app.swipeUp() : app.swipeDown() }
        XCTAssertTrue(visible(), "\(element) should be reachable")
    }

    /// The editor sheet has gone (the detail is back; its title may have scrolled away).
    private func editorClosed() {
        XCTAssertTrue(app.textFields["editSetWeight"].waitForNonExistence(timeout: 5), "the editor closes")
    }

    /// Yesterday's Leg Day, from the list.
    private func openLegDay() {
        app.tabBars.buttons["History"].tap()
        let row = any("historyWorkoutRow")
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        row.tap()
        XCTAssertTrue(app.buttons["historyWorkoutName"].waitForExistence(timeout: 10))
    }

    /// Back to the list (tapping the selected tab pops to its root).
    private func backToList() {
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(any("historyWorkoutRow").waitForExistence(timeout: 10))
    }

    private func rows(endingWith text: String) -> XCUIElementQuery {
        app.staticTexts.matching(NSPredicate(format: "label ENDSWITH %@", text))
    }

    private func dismissSheetBySwipe() {
        let window = app.windows.firstMatch
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12))
            .press(forDuration: 0.05, thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))
    }

    private func openAddSet() {
        let menu = app.buttons["historyEntryLoadType"].firstMatch
        reach(menu)
        menu.tap()
        let add = app.buttons["Add Set"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        XCTAssertTrue(app.textFields["editSetWeight"].waitForExistence(timeout: 5), "the Add Set editor opens")
        XCTAssertTrue(app.staticTexts["Add Set"].exists)
    }

    private func type(_ id: String, _ text: String) {
        let field = app.textFields[id]
        field.tap()
        field.typeText(text)
    }

    func testAnAbandonedAddSetLeavesNothingAndASavedOneStays() {
        openLegDay()
        openAddSet()
        app.buttons["Cancel"].firstMatch.tap()
        editorClosed()
        backToList()
        XCTAssertEqual(rows(endingWith: " · 10 sets").count, 0, "Cancel leaves no set behind")

        openLegDay()
        openAddSet()
        dismissSheetBySwipe()
        editorClosed()
        backToList()
        XCTAssertEqual(rows(endingWith: " · 10 sets").count, 0, "swiping the editor away leaves no set behind")

        openLegDay()
        openAddSet()
        type("editSetWeight", "50")
        type("editSetReps", "5")
        app.buttons["saveEditedSet"].tap()
        editorClosed()
        backToList()
        XCTAssertEqual(rows(endingWith: " · 10 sets").count, 1, "a saved set stays")
    }

    func testAnAbandonedAddExerciseLeavesNothing() {
        openLegDay()
        let add = app.buttons["addHistoryExercise"]
        reach(add)
        add.tap()
        pickExercise("Seated Chest Press")
        dismissSheetBySwipe()
        editorClosed()
        let count = app.staticTexts["4 exercises"]
        reach(count, up: false)
        XCTAssertFalse(app.staticTexts["5 exercises"].exists, "the abandoned exercise is gone")
        backToList()
        XCTAssertEqual(rows(endingWith: " · 10 sets").count, 0)
    }

    func testNotesAreSavedAndMarkTheWorkoutEdited() {
        openLegDay()
        let addNote = app.buttons["addHistoryNote"]
        reach(addNote)
        addNote.tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        // A system alert's field does not carry its SwiftUI identifier.
        let field = alert.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Knees felt good.")
        alert.buttons["saveHistoryNotes"].firstMatch.tap()
        let note = any("historyNotes")
        reach(note)
        XCTAssertTrue(note.label.contains("Knees felt good."), note.label)
        reach(any("historyEditedMark"), up: false)
    }

    func testDeletingTheLastSetFromTheEditorRemovesTheExerciseAfterSayingSo() {
        addOneSetExercise()
        let line = setLine("20 kg × 10")
        reach(line)
        line.tap()
        let delete = app.buttons["deleteEditedSet"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        if !delete.isHittable { app.swipeUp() }
        delete.tap()
        confirmLastSetDeletion()
        reach(app.staticTexts["4 exercises"], up: false)
        XCTAssertFalse(app.staticTexts["5 exercises"].exists)
    }

    func testDeletingTheLastSetBySwipeRemovesTheExerciseAfterSayingSo() {
        addOneSetExercise()
        let line = setLine("20 kg × 10")
        reach(line)
        line.swipeLeft()
        let delete = app.buttons["Delete"].firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()
        confirmLastSetDeletion()
        reach(app.staticTexts["4 exercises"], up: false)
        XCTAssertFalse(app.staticTexts["5 exercises"].exists)
    }

    // MARK: - Helpers

    private func pickExercise(_ name: String) {
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText(name)
        let option = any("exerciseOption.\(name)")
        XCTAssertTrue(option.waitForExistence(timeout: 10))
        option.tap()
        XCTAssertTrue(app.textFields["editSetWeight"].waitForExistence(timeout: 10), "the new exercise's set opens")
    }

    /// Adds Seated Chest Press with one saved set, 20 kg × 10 — an exercise with a single set.
    private func addOneSetExercise() {
        openLegDay()
        let add = app.buttons["addHistoryExercise"]
        reach(add)
        add.tap()
        pickExercise("Seated Chest Press")
        type("editSetWeight", "20")
        type("editSetReps", "10")
        app.buttons["saveEditedSet"].tap()
        editorClosed()
        reach(app.staticTexts["5 exercises"], up: false)
    }

    private func setLine(_ value: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'historySetLine' AND label CONTAINS %@", value)).firstMatch
    }

    /// The dialog names the consequence before anything is deleted.
    private func confirmLastSetDeletion() {
        let message = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "has no other sets, so it is removed from this workout too")).firstMatch
        XCTAssertTrue(message.waitForExistence(timeout: 5), "the dialog says the exercise goes too")
        let confirm = app.buttons.matching(NSPredicate(format: "label == 'Delete Set' AND identifier != 'deleteEditedSet'")).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
    }
}
