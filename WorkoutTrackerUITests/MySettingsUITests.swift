import XCTest

/// Machine settings 01 (D91): "My settings" on the live card (the note line, the editor's Cancel and Save, the
/// first-use chip, the "⋯" item) and on the machine page (one row on a single-exercise machine, a row per exercise on
/// a station), on the design sample's live Push Day with `-uiTestDesignMySettings`. Captures light/dark × Default/
/// AccessibilityL.
final class MySettingsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func any(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func shoot(_ name: String) {
        Thread.sleep(forTimeInterval: 0.8)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func launch(appearance: String = "light", large: Bool = false) {
        app.launchArguments = ["-uiTestReset", "-uiTestDesignSample", "-uiTestDesignLive", "-uiTestDesignGyms",
                               "-uiTestDesignMySettings", "-appearance", appearance]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] }
        app.launch()
        XCTAssertTrue(any("entryTitle.Seated Chest Press").waitForExistence(timeout: 20), "the live workout opens")
    }

    /// Swipes up until `element` is on screen and clear of the bottom (the rest slab), up to `limit` times.
    private func scroll(to element: XCUIElement, limit: Int = 12) {
        for _ in 0..<limit {
            if element.exists && element.isHittable && element.frame.maxY < app.frame.maxY - 220 { return }
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.4)
        }
    }

    private var field: XCUIElement { any("mySettings.field") }

    /// Replaces the editor's text: the cursor to the end, delete everything, type.
    private func replaceText(with text: String) {
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        let current = (field.value as? String) ?? ""
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.9)).tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count + 4) + text)
    }

    // MARK: The live card

    func testCardLineCancelDiscardsAndSaveKeeps() {
        launch()
        let line = any("mySettings.cardLine")
        XCTAssertTrue(line.waitForExistence(timeout: 10))
        XCTAssertEqual(line.value as? String, "Seat 4 · back pad 2 · handles at the second notch")

        line.tap()
        replaceText(with: "Seat 9")
        app.buttons["mySettings.cancel"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5))
        XCTAssertEqual(line.value as? String, "Seat 4 · back pad 2 · handles at the second notch", "Cancel discards")

        line.tap()
        replaceText(with: "Seat 5 · back pad 2")
        app.buttons["mySettings.save"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5))
        XCTAssertEqual(line.value as? String, "Seat 5 · back pad 2", "Save keeps")

        // A blank note clears it: the line goes (the chest press has history, so no chip either).
        line.tap()
        replaceText(with: "")
        app.buttons["mySettings.save"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5))
        XCTAssertFalse(any("entryTitle.Seated Chest Press").exists && line.exists
                       && (line.value as? String)?.hasPrefix("Seat") == true, "the chest press's line is gone")
    }

    func testFirstUseChipBecomesTheNoteLine() {
        launch()
        // The Shoulder Press machine has no finished workout for the shoulder press: the chip offers a note.
        let chip = any("mySettings.addChip")
        scroll(to: chip)
        XCTAssertTrue(chip.exists, "first use offers Add My Settings")
        chip.tap()
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertEqual((field.value as? String).map { $0.isEmpty || $0.hasPrefix("Seat 4 · pad 2") }, true,
                       "empty, with the placeholder: \(String(describing: field.value))")
        XCTAssertFalse(app.buttons["mySettings.save"].isEnabled, "nothing to save yet")
        field.tap()
        field.typeText("Seat 2 · pins at 3")
        app.buttons["mySettings.save"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5))
        XCTAssertFalse(any("mySettings.addChip").exists, "the chip goes once a note exists")
        let saved = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@ AND value == %@",
                                                                         "mySettings.cardLine", "Seat 2 · pins at 3"))
        XCTAssertEqual(saved.count, 1)
    }

    func testMenuItemOpensTheEditorOnACardWithAMachine() {
        launch()
        // The chest press card's "⋯" (the first card).
        let options = app.buttons.matching(NSPredicate(format: "label == %@", "Exercise options")).firstMatch
        XCTAssertTrue(options.waitForExistence(timeout: 5))
        options.tap()
        let item = app.buttons["mySettings.menuItem"]
        XCTAssertTrue(item.waitForExistence(timeout: 5))
        item.tap()
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, "Seat 4 · back pad 2 · handles at the second notch")
        app.buttons["mySettings.cancel"].tap()
    }

    // MARK: The machine page

    private func openMachine(_ label: String) {
        let minimize = any("minimizeWorkout")
        XCTAssertTrue(minimize.waitForExistence(timeout: 5))
        minimize.tap()
        app.openTrain("Gyms")
        let iron = any("gymRow.Iron Temple")
        XCTAssertTrue(iron.waitForExistence(timeout: 10))
        iron.tap()
        let row = any("machineRow.\(label)")
        for _ in 0..<10 { guard !(row.exists && row.isHittable
                                  && row.frame.maxY < app.tabBars.firstMatch.frame.minY - 8) else { break }; app.swipeUp() }
        row.staticTexts[label].tap()
        XCTAssertTrue(any("machineDetail.name").waitForExistence(timeout: 10), "\(label)'s page")
    }

    func testStationKeepsANotePerExercise() {
        launch()
        openMachine("Cable Station")
        let pushdown = any("mySettings.machineRow.Triceps Pushdown")
        scroll(to: pushdown)
        XCTAssertEqual(pushdown.value as? String, "Rope · pulley at the top · hurt my elbow at 4, stay at 3")
        XCTAssertEqual(any("mySettings.machineRow.Cable Crossover").value as? String, "Both pulleys at 6 · one step forward")
        let row = any("mySettings.machineRow.Low Row")
        scroll(to: row)
        XCTAssertEqual(row.value as? String, "None")
        row.tap()
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Seat 3 · chest pad 2")
        app.buttons["mySettings.save"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5))
        XCTAssertEqual(row.value as? String, "Seat 3 · chest pad 2")
        XCTAssertEqual(pushdown.value as? String, "Rope · pulley at the top · hurt my elbow at 4, stay at 3",
                       "the other exercise's note is untouched")
    }

    func testASingleExerciseMachineHasOneRow() {
        launch()
        openMachine("Chest Press 2")
        let row = any("mySettings.machineRow.single")
        scroll(to: row)
        XCTAssertEqual(row.value as? String, "Seat 4 · back pad 2 · handles at the second notch")
        XCTAssertFalse(any("mySettings.machineRow.Seated Chest Press").exists, "no exercise name on a single machine")
    }

    // MARK: Captures

    func testCaptureLightDefault() { capture(appearance: "light", large: false) }
    func testCaptureLightAccessibility() { capture(appearance: "light", large: true) }
    func testCaptureDarkDefault() { capture(appearance: "dark", large: false) }
    func testCaptureDarkAccessibility() { capture(appearance: "dark", large: true) }

    private func capture(appearance: String, large: Bool) {
        let tag = "\(appearance)-\(large ? "axl" : "default")"
        launch(appearance: appearance, large: large)
        XCTAssertTrue(any("mySettings.cardLine").waitForExistence(timeout: 10))
        shoot("ms01-card-note-\(tag)")
        any("mySettings.cardLine").tap()
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        shoot("ms01-editor-\(tag)")
        app.buttons["mySettings.cancel"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5))
        let chip = any("mySettings.addChip")
        scroll(to: chip)
        shoot("ms01-card-chip-\(tag)")
        let station = app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier == %@ AND value BEGINSWITH %@", "mySettings.cardLine", "Rope")).firstMatch
        scroll(to: station)
        shoot("ms01-card-station-\(tag)")

        for _ in 0..<10 { app.swipeDown() }
        openMachine("Cable Station")
        scroll(to: any("mySettings.machineRow.Low Row"))
        shoot("ms01-page-station-\(tag)")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let chest = any("machineRow.Chest Press 2")
        for _ in 0..<10 { guard !(chest.exists && chest.isHittable
                                  && chest.frame.maxY < app.tabBars.firstMatch.frame.minY - 8) else { break }; app.swipeUp() }
        chest.staticTexts["Chest Press 2"].tap()
        let single = any("mySettings.machineRow.single")
        scroll(to: single)
        shoot("ms01-page-single-\(tag)")
    }
}
