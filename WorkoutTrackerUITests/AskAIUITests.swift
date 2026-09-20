import XCTest

final class AskAIUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUp() { continueAfterFailure = false; app = XCUIApplication() }
    private func launch(_ extra: [String] = [], large: Bool = false) {
        app.launchArguments = ["-uiTestReset", "-uiTestTerra"] + extra
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] }
        app.launch()
    }
    private func any(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }
    private func reach(_ element: XCUIElement) {
        for _ in 0..<20 {
            let top = app.navigationBars.firstMatch.frame.maxY + 8
            let bottom = app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame.minY - 8 : app.frame.maxY - 85
            if element.exists && element.isHittable && element.frame.minY >= top && element.frame.maxY <= bottom { return }
            let down = element.exists && element.frame.minY < top
            let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: down ? 0.4 : 0.65))
            let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: down ? 0.65 : 0.4))
            from.press(forDuration: 0.1, thenDragTo: to)
        }
        XCTAssertTrue(element.exists && element.isHittable)
    }
    private func enable(_ id: String) {
        let control = app.switches[id].firstMatch; reach(control)
        if control.value as? String != "1" { control.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap() }
        XCTAssertEqual(control.value as? String, "1")
    }
    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func scanner() {
        app.tabBars.buttons["Gyms"].tap(); app.buttons["addGym"].tap()
        let field = app.textFields["gymName"]; XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap(); field.typeText("AI Gym")
        app.buttons["saveGym"].tap()
        let row = any("gymRow.AI Gym"); XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
        app.buttons["addMachine"].tap()
        app.buttons["scanMachineLabel"].tap()
    }
    func testGenericScanConfirmsBeforeSavingDefault() { genericScan(large: false) }
    func testGenericScanConfirmsBeforeSavingAccessibility() { genericScan(large: true) }
    private func genericScan(large: Bool) {
        launch(large: large); scanner()
        let shutter = app.buttons["scanShutter"]; XCTAssertTrue(shutter.waitForExistence(timeout: 5)); shutter.tap()
        let use = app.buttons["scanUseCandidate"]; XCTAssertTrue(use.waitForExistence(timeout: 10))
        shot("ai-scan-proposal-\(large ? "axl" : "default")")
        reach(use); use.tap()
        let label = app.textFields["machineLabel"]; XCTAssertTrue(label.waitForExistence(timeout: 5))
        XCTAssertEqual(label.value as? String, "Chest press")
        app.buttons["saveMachine"].tap()
        XCTAssertTrue(app.staticTexts["Chest press"].firstMatch.waitForExistence(timeout: 5))
    }
    func testScanFailureAndRescanRemainUsable() {
        launch(["-uiTestTerraOffline"]); scanner(); app.buttons["scanShutter"].tap()
        XCTAssertTrue(any("scanAIError").waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["scanShutter"].isEnabled)
        XCTAssertFalse(app.buttons["scanUseCandidate"].exists)
    }
    func testRescanDropsLateAIResponse() {
        launch(["-uiTestTerraSlow"]); scanner(); app.buttons["scanShutter"].tap()
        let rescan = app.buttons["scanRescan"]; XCTAssertTrue(rescan.waitForExistence(timeout: 2)); rescan.tap()
        XCTAssertTrue(app.buttons["scanShutter"].waitForExistence(timeout: 5))
        let noResult = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true"), object: app.buttons["scanUseCandidate"])
        noResult.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for: [noResult], timeout: 5), .completed)
    }
    func testWeeklyRoutineDefault() { routine(large: false) }
    func testWeeklyRoutineAccessibility() { routine(large: true) }
    func testEditingGeneratedWeekKeepsRowsAndSavesOnlyOnce() { routine(large: false, edit: true) }
    private func routine(large: Bool, edit: Bool = false) {
        launch(large: large); app.tabBars.buttons["Workout"].tap()
        let ask = app.buttons["askAIRoutine"]; reach(ask); shot("ai-start-\(large ? "axl" : "default")"); ask.tap()
        let goals = app.textFields["routineGoals"].exists ? app.textFields["routineGoals"] : app.textViews["routineGoals"]
        XCTAssertTrue(goals.waitForExistence(timeout: 5)); goals.tap(); _ = app.keyboards.firstMatch.waitForExistence(timeout: 3); goals.typeText("Build strength and endurance")
        app.buttons["dismissRoutineKeyboard"].tap()
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        app.swipeUp()
        enable("routineEquipment.dumbbells")
        shot("ai-routine-inputs-\(large ? "axl" : "default")")
        enable("routineCardio.outdoorWalk")
        let generate = app.buttons["generateAIRoutine"]; reach(generate); XCTAssertTrue(generate.isEnabled); generate.tap()
        let day = any("routineDay.0"); XCTAssertTrue(day.waitForExistence(timeout: 10))
        shot("ai-week-preview-\(large ? "axl" : "default")")
        day.tap(); shot("ai-day-edit-\(large ? "axl" : "default")")
        if edit {
            let add = app.buttons["Add exercise"]; reach(add); add.tap()
            let remove = app.buttons["Remove exercise"].firstMatch; reach(remove); remove.tap()
            XCTAssertTrue(app.buttons["Remove exercise"].firstMatch.exists)
            reach(app.buttons["Add exercise"]); app.buttons["Add exercise"].tap()
            app.navigationBars.buttons["Edit"].tap()
            let handles = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Reorder"))
            XCTAssertGreaterThanOrEqual(handles.count, 2)
            if handles.count >= 2 { handles.element(boundBy: 0).press(forDuration: 0.5, thenDragTo: handles.element(boundBy: 1)) }
            app.navigationBars.buttons["Done"].tap()
        }
        app.navigationBars.buttons.element(boundBy: 0).tap()
        if edit { app.buttons["saveAIRoutine"].doubleTap() }
        else { app.buttons["saveAIRoutine"].tap() }
        let tile = app.buttons["templateTile.Day 1 — Fitness"]; XCTAssertTrue(tile.waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons.matching(identifier: "templateTile.Day 1 — Fitness").count, 1)
        reach(tile); tile.tap()
        shot("ai-template-detail-\(large ? "axl" : "default")")
        if edit {
            app.buttons["editTemplate"].tap()
            let save = app.navigationBars.buttons["Save"]; XCTAssertTrue(save.waitForExistence(timeout: 5)); save.tap()
        }
        app.buttons["startTemplate"].tap()
        let start = app.buttons["startPlannedCardio"]; XCTAssertTrue(start.waitForExistence(timeout: 10)); reach(start)
        shot("ai-planned-cardio-\(large ? "axl" : "default")")
        XCTAssertFalse(any("cardioTimer").exists)
        start.tap()
        XCTAssertTrue(any("cardioTimer").waitForExistence(timeout: 10))
    }
    func testPhotoConsentDefault() { photoConsent(large: false) }
    func testPhotoConsentAccessibility() { photoConsent(large: true) }
    private func photoConsent(large: Bool) {
        launch(["-uiTestTerraNeedsConsent"], large: large); scanner()
        let allow = app.buttons["allowAIPhotos"]
        XCTAssertTrue(allow.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["scanShutter"].exists)
        shot("ai-photo-consent-\(large ? "axl" : "default")")
        reach(allow); allow.tap()
        XCTAssertTrue(app.buttons["scanShutter"].waitForExistence(timeout: 5))
    }

    func testManualModelSuggestionsRequireConsentAndKeepConfirmation() {
        launch(["-uiTestScanFixture"])
        scanner()
        app.navigationBars.buttons["Cancel"].tap()
        app.buttons["scanLabelOffline"].tap()
        let shutter = app.buttons["scanShutter"]; XCTAssertTrue(shutter.waitForExistence(timeout: 5)); shutter.tap()
        let create = app.buttons["scanCreateNew"]; XCTAssertTrue(create.waitForExistence(timeout: 15)); reach(create); create.tap()
        let suggest = app.buttons["newModelSuggestExercises"]; XCTAssertTrue(suggest.waitForExistence(timeout: 5)); reach(suggest); suggest.tap()
        XCTAssertTrue(app.alerts["Send model details to OpenAI?"].waitForExistence(timeout: 5))
        app.alerts.buttons["Allow and send"].tap()
        let save = app.buttons["saveNewModel"]
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: save)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 10), .completed)
        XCTAssertTrue(app.navigationBars["New Model"].exists)
    }

    func testMissingKeyHasReachableSettings() {
        app.launchArguments = ["-uiTestReset"]; app.launch(); app.tabBars.buttons["Workout"].tap()
        reach(app.buttons["askAIRoutine"]); app.buttons["askAIRoutine"].tap()
        let settings = app.buttons["routineAISettings"]; XCTAssertTrue(settings.waitForExistence(timeout: 5)); settings.tap()
        XCTAssertTrue(app.secureTextFields["askAIKeyField"].waitForExistence(timeout: 5))
        shot("ai-key-settings-default")
    }
}
