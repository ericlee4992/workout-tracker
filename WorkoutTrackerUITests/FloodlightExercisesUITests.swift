import XCTest

// Floodlight redesign ticket 08: the Exercises tab (E01: the family filter, the sections, a
// search with no match), an exercise's page (E02: trained with two variations and records, an
// assisted one, a user-made one, an untrained one), New Exercise (E03: empty and a taken name),
// Presets (E04: the list, empty, a duplicate) and Load Type (E05: unchanged and changed) — on
// record in light and dark at Default and AccessibilityL, on the design sample with its History,
// Gyms and Exercises extras; then the flows the new screens carry.
final class FloodlightExercisesUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func shoot(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func any(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func launch(appearance: String = "light", large: Bool = false) {
        app.launchArguments = ["-uiTestReset", "-uiTestDesignSample", "-uiTestDesignHistory", "-uiTestDesignGyms",
                               "-uiTestDesignExercises", "-appearance", appearance]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] }
        app.launch()
        app.tabBars.buttons["Exercises"].tap()
        XCTAssertTrue(any("exerciseSearch").waitForExistence(timeout: 15))
    }

    /// Scrolls until `element` is on screen and clear of the tab bar (a row half under the bar is
    /// "hittable" but the tap lands on the bar).
    private func reach(_ element: XCUIElement, limit: Int = 12) {
        for _ in 0..<limit where !(element.exists && element.isHittable
                                   && element.frame.maxY < app.tabBars.firstMatch.frame.minY - 8
                                   && element.frame.minY > 100) {
            app.swipeUp()
        }
    }

    /// Swipes up until `element` is on screen and clear of the bars, shooting each page after the
    /// first under `name`.
    private func page(to element: XCUIElement, name: String, limit: Int = 8) {
        var page = 2
        while !(element.exists && element.isHittable && element.frame.maxY < app.frame.maxY - 110), page <= limit + 1 {
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.6)
            shoot("\(name)-\(page)")
            page += 1
        }
    }

    private func search(_ text: String) {
        let field = app.textFields["exerciseSearch"]
        field.tap()
        field.typeText(text)
    }

    private func clearSearch() {
        app.buttons["Clear"].firstMatch.tap()
        if app.keyboards.firstMatch.exists { app.swipeDown() }
    }

    /// Opens an exercise's page from the tab by searching for it.
    private func open(_ name: String) {
        search(name)
        let row = any("exerciseRow.\(name)")
        XCTAssertTrue(row.waitForExistence(timeout: 5), "\(name) is listed")
        if app.keyboards.firstMatch.exists { app.swipeDown() }
        row.tap()
        XCTAssertTrue(any("exerciseDetail").waitForExistence(timeout: 5), "\(name)'s page opened")
    }

    private func back() {
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(any("exerciseSearch").waitForExistence(timeout: 5))
    }

    // MARK: Captures

    func testCaptureExercisesLightDefault() { capture(appearance: "light", large: false) }
    func testCaptureExercisesLightAccessibility() { capture(appearance: "light", large: true) }
    func testCaptureExercisesDarkDefault() { capture(appearance: "dark", large: false) }
    func testCaptureExercisesDarkAccessibility() { capture(appearance: "dark", large: true) }

    private func capture(appearance: String, large: Bool) {
        launch(appearance: appearance, large: large)
        let suffix = "\(appearance)-\(large ? "axl" : "default")"

        // E01: the family strip over the body-area sections.
        let chest = any("exerciseRow.Seated Chest Press")
        XCTAssertTrue(chest.waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 1.2)
        shoot("floodlight-08-e01-\(suffix)-1")
        app.swipeUp()
        Thread.sleep(forTimeInterval: 0.6)
        shoot("floodlight-08-e01-\(suffix)-2")
        for _ in 0..<3 { app.swipeDown() }

        // A family chosen: only its rows, the summary with Clear.
        any("exerciseFamily.Arms").tap()
        XCTAssertTrue(any("clearExerciseFilters").waitForExistence(timeout: 5))
        XCTAssertFalse(chest.exists, "a chest exercise leaves the Arms list")
        Thread.sleep(forTimeInterval: 0.8)
        shoot("floodlight-08-e01-arms-\(suffix)")
        any("clearExerciseFilters").tap()

        // No match: Add “…”.
        search("Zercher Squat")
        XCTAssertTrue(any("addTypedExercise").waitForExistence(timeout: 5))
        shoot("floodlight-08-e01-nomatch-\(suffix)")
        clearSearch()

        // E02: trained, two variations, records, setup, machines, history.
        open("Seated Chest Press")
        XCTAssertTrue(any("exerciseProgressPanel").exists)
        Thread.sleep(forTimeInterval: 1.5)
        shoot("floodlight-08-e02-\(suffix)-1")
        let session = any("exerciseSession.2")
        page(to: session, name: "floodlight-08-e02-\(suffix)", limit: large ? 12 : 6)

        // E04: Presets (two, used / not used), then a duplicate.
        for _ in 0..<12 { app.swipeDown() }
        reach(any("exerciseSetupPresets"))
        any("exerciseSetupPresets").tap()
        XCTAssertTrue(any("preset.Narrow grip").waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.0)
        shoot("floodlight-08-e04-\(suffix)")
        let name = app.textFields["newPresetName"]
        name.tap()
        name.typeText("narrow grip")
        XCTAssertFalse(app.buttons["addPreset"].isEnabled, "a duplicate cannot be added")
        shoot("floodlight-08-e04-duplicate-\(suffix)")
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(any("preset.Narrow grip").waitForNonExistence(timeout: 5))

        // E05: Load Type, unchanged then changed (the ledger).
        any("exerciseSetupLoadType").tap()
        XCTAssertTrue(any("loadType.assisted").waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["saveLoadType"].isEnabled, "Save is off until the type changes")
        Thread.sleep(forTimeInterval: 0.8)
        shoot("floodlight-08-e05-\(suffix)")
        any("loadType.assisted").tap()
        XCTAssertTrue(any("editLoadTypeHistoryNote").waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8)
        shoot("floodlight-08-e05-changed-\(suffix)")
        app.buttons["Cancel"].firstMatch.tap()
        XCTAssertTrue(any("loadType.assisted").waitForNonExistence(timeout: 5))
        back()
        clearSearch()

        // E02 assisted (least-assistance records), user-made (Rename…), untrained.
        open("Assisted Pull-Up")
        Thread.sleep(forTimeInterval: 1.2)
        shoot("floodlight-08-e02-assisted-\(suffix)-1")
        page(to: any("exerciseSession.1"), name: "floodlight-08-e02-assisted-\(suffix)", limit: large ? 10 : 4)
        // E04 empty.
        for _ in 0..<10 { app.swipeDown() }
        reach(any("exerciseSetupPresets"))
        any("exerciseSetupPresets").tap()
        XCTAssertTrue(any("noPresets").waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.0)
        shoot("floodlight-08-e04-empty-\(suffix)")
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(any("noPresets").waitForNonExistence(timeout: 5))
        back()
        clearSearch()

        open("Landmine Press")
        Thread.sleep(forTimeInterval: 1.0)
        shoot("floodlight-08-e02-custom-\(suffix)-1")
        page(to: any("exerciseRename"), name: "floodlight-08-e02-custom-\(suffix)", limit: large ? 8 : 3)
        back()
        clearSearch()

        open("Nordic Hamstring Curl")
        XCTAssertTrue(any("exerciseProgressEmpty").exists, "an untrained exercise says so")
        Thread.sleep(forTimeInterval: 1.0)
        shoot("floodlight-08-e02-untrained-\(suffix)")
        back()
        clearSearch()

        // E03: New Exercise, empty then a taken name.
        any("addExerciseToolbar").tap()
        let field = app.textFields["newExerciseName"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["saveNewExercise"].isEnabled, "Add is off while the name is blank")
        Thread.sleep(forTimeInterval: 1.0)
        shoot("floodlight-08-e03-\(suffix)")
        field.tap()
        field.typeText("Bench press")
        XCTAssertTrue(any("newExerciseTaken").waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["saveNewExercise"].isEnabled, "a taken name cannot be added")
        app.swipeDown(velocity: .slow)
        shoot("floodlight-08-e03-taken-\(suffix)")
    }

    // MARK: Flows

    /// A row opens its page; Load type → a different type shows how many logged sets keep the old
    /// one, and Save changes the exercise (the page and the row say the new type).
    func testRowOpensTheExerciseAndLoadTypeSaves() {
        launch()
        open("Dip")
        any("exerciseSetupLoadType").tap()
        XCTAssertTrue(any("loadType.weighted").waitForExistence(timeout: 5))
        any("loadType.weighted").tap()
        let note = any("editLoadTypeHistoryNote")
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        XCTAssertTrue(note.label.contains("3 sets already logged"), "the three dip sets keep BW + added: \(note.label)")
        XCTAssertTrue(note.label.contains("BW + added"), note.label)
        app.buttons["saveLoadType"].tap()
        XCTAssertTrue(app.buttons["saveLoadType"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(any("exerciseSetupLoadType").label.contains("Weighted"), any("exerciseSetupLoadType").label)
    }

    /// Presets: a suggestion adds one; a tap renames it; a swipe deletes it only after the
    /// confirmation.
    func testPresetsAddRenameAndDeleteAfterConfirmation() {
        launch()
        open("Assisted Pull-Up")
        reach(any("exerciseSetupPresets"))
        any("exerciseSetupPresets").tap()
        XCTAssertTrue(any("noPresets").waitForExistence(timeout: 5))
        any("presetSuggestion.Wide grip").tap()
        let wide = any("preset.Wide grip")
        XCTAssertTrue(wide.waitForExistence(timeout: 5))
        XCTAssertTrue(wide.label.contains("Not used yet"), wide.label)

        wide.tap()
        let rename = app.alerts.textFields.firstMatch
        XCTAssertTrue(rename.waitForExistence(timeout: 5), "a tap renames")
        rename.tap()
        // The alert prefills the name with the cursor at its end: delete it, then type the new one.
        rename.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 12))
        rename.typeText("Chin-up grip")
        app.alerts.buttons["Save"].tap()
        let chin = any("preset.Chin-up grip")
        XCTAssertTrue(chin.waitForExistence(timeout: 5))

        chin.swipeLeft()
        let delete = app.buttons["Delete"].firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()
        let confirm = any("presetDelete")
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "a confirmation stands between the swipe and the deletion")
        XCTAssertTrue(chin.exists, "nothing is deleted before the confirmation")
        confirm.tap()
        XCTAssertTrue(chin.waitForNonExistence(timeout: 5))
        XCTAssertTrue(any("noPresets").waitForExistence(timeout: 5))
    }

    /// New Exercise from the tab refuses a taken name, then adds one with its body area and opens
    /// its page.
    func testNewExerciseRefusesATakenNameAndOpensTheNewExercise() {
        launch()
        any("addExerciseToolbar").tap()
        let field = app.textFields["newExerciseName"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("  seated chest PRESS ")
        XCTAssertTrue(any("newExerciseTaken").waitForExistence(timeout: 5), "case and spacing do not make a new name")
        XCTAssertFalse(app.buttons["saveNewExercise"].isEnabled)
        for _ in 0..<22 { field.typeText(XCUIKeyboardKey.delete.rawValue) }
        field.typeText("Zercher Squat")
        XCTAssertTrue(any("newExerciseTaken").waitForNonExistence(timeout: 5))
        if app.keyboards.firstMatch.exists { app.swipeDown(velocity: .slow) }
        any("newExerciseBodyArea.Quads").tap()
        any("newExerciseTag.barbell").tap()
        app.buttons["saveNewExercise"].tap()
        XCTAssertTrue(any("exerciseDetail").waitForExistence(timeout: 5), "Add opens the new exercise")
        XCTAssertTrue(app.staticTexts["Zercher Squat"].exists)
        XCTAssertTrue(app.staticTexts["Quads"].exists, "the body area was saved")
        XCTAssertTrue(any("exerciseRename").exists, "a user-made exercise can be renamed")
        back()
        search("Zercher")
        XCTAssertTrue(any("exerciseRow.Zercher Squat").waitForExistence(timeout: 5))
    }

    /// A search with no match offers to add what was typed, with the name filled in.
    func testNoMatchOffersToAddTheTypedName() {
        launch()
        search("Zercher")
        let add = any("addTypedExercise")
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        let field = app.textFields["newExerciseName"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, "Zercher")
    }

    /// The family strip filters and remembers; Clear brings everything back.
    func testFamilyFilterHidesOtherFamiliesUntilCleared() {
        launch()
        let chest = any("exerciseRow.Seated Chest Press")
        XCTAssertTrue(chest.waitForExistence(timeout: 10))
        any("exerciseFamily.Legs").tap()
        XCTAssertTrue(chest.waitForNonExistence(timeout: 5))
        XCTAssertTrue(any("exerciseRow.Leg Press").exists)
        XCTAssertTrue(any("exerciseFamily.Legs").isSelected)
        app.tabBars.buttons["Workout"].tap()
        app.tabBars.buttons["Exercises"].tap()
        XCTAssertTrue(any("exerciseFamily.Legs").waitForExistence(timeout: 5))
        XCTAssertTrue(any("exerciseFamily.Legs").isSelected, "the family is remembered")
        any("clearExerciseFilters").tap()
        XCTAssertTrue(chest.waitForExistence(timeout: 5))
    }

    /// A machine page's exercise row opens that exercise (user decision 1).
    func testMachinePageExerciseRowOpensTheExercise() {
        launch()
        app.tabBars.buttons["Gyms"].tap()
        let gym = any("gymRow.Iron Temple")
        XCTAssertTrue(gym.waitForExistence(timeout: 10))
        gym.tap()
        let machine = any("machineRow.Chest Press 2")
        XCTAssertTrue(machine.waitForExistence(timeout: 10))
        reach(machine)
        machine.tap()
        let row = any("machineExercise.Seated Chest Press")
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        reach(row)
        row.tap()
        XCTAssertTrue(any("exerciseDetail").waitForExistence(timeout: 5))
        XCTAssertTrue(any("exerciseProgressPanel").exists)
    }
}
