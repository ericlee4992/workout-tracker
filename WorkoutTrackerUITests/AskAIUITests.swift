import XCTest
import Vision

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
    func testAllThreeGeneratedTemplatesAppearWithoutRestart() { allThreeTemplates() }
    func testAllThreeGeneratedTemplatesInPopulatedListDefault() { allThreeTemplates(populated: true) }
    func testAllThreeGeneratedTemplatesInPopulatedListAccessibility() { allThreeTemplates(populated: true, large: true) }
    private func allThreeTemplates(populated: Bool = false, large: Bool = false) {
        launch(populated ? ["-uiTestTemplate", "-uiTestTerraFullRoutine"] : [], large: large); app.tabBars.buttons["Workout"].tap()
        if populated {
            app.tabBars.buttons["Gyms"].tap(); app.buttons["addGym"].tap()
            let name = app.textFields["gymName"]; XCTAssertTrue(name.waitForExistence(timeout: 5))
            name.tap(); name.typeText("Template Gym"); app.buttons["saveGym"].tap()
            app.tabBars.buttons["Workout"].tap(); app.buttons["gymPicker"].tap()
            app.buttons["Template Gym"].tap()
        }
        let ask = app.buttons["askAIRoutine"]; reach(ask); ask.tap()
        let goals = app.textFields["routineGoals"].exists ? app.textFields["routineGoals"] : app.textViews["routineGoals"]
        XCTAssertTrue(goals.waitForExistence(timeout: 5)); goals.tap(); goals.typeText("Build strength")
        app.buttons["dismissRoutineKeyboard"].tap()
        enable("routineEquipment.dumbbells")
        let generate = app.buttons["generateAIRoutine"]; reach(generate); generate.tap()
        XCTAssertTrue(any("routineDay.2").waitForExistence(timeout: 10))
        app.buttons["saveAIRoutine"].tap()
        XCTAssertTrue(app.navigationBars["Workout"].waitForExistence(timeout: 10))
        for day in 1...3 {
            for _ in 0..<4 { app.swipeDown() }
            let tile = app.buttons["templateTile.Day \(day) — Fitness"]
            reach(tile)
            shot("ai-immediate-template-\(day)-\(large ? "axl" : "default")")
            assertDrawn("Day \(day)", in: tile)
            XCTAssertEqual(app.buttons.matching(identifier: "templateTile.Day \(day) — Fitness").count, 1)
            tile.tap()
            XCTAssertTrue(app.buttons["startTemplate"].waitForExistence(timeout: 5))
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
    }

    /// Accessibility can report an invisible lazy-grid cell as present. Inspect rendered pixels too.
    private func assertDrawn(_ text: String, in element: XCUIElement) {
        let screenshot = app.screenshot().image
        guard let pixels = screenshot.cgImage else { return XCTFail("Screenshot has no pixels") }
        let frame = element.frame.intersection(app.frame)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.regionOfInterest = CGRect(x: frame.minX / app.frame.width,
                                         y: 1 - frame.maxY / app.frame.height,
                                         width: frame.width / app.frame.width,
                                         height: frame.height / app.frame.height)
        do { try VNImageRequestHandler(cgImage: pixels).perform([request]) }
        catch { return XCTFail("Screenshot OCR failed: \(error)") }
        let visible = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
        print("Rendered template OCR: \(visible)")
        XCTAssertTrue(visible.contains(text), "Card exists in accessibility but its title is not drawn: \(text). Pixels read: \(visible)")
    }

    func testScanMachinesDuringRoutineSetupDefault() { scanDuringRoutine(large: false) }
    func testScanMachinesDuringRoutineSetupAccessibility() { scanDuringRoutine(large: true) }
    private func scanDuringRoutine(large: Bool) {
        launch(large: large); app.tabBars.buttons["Workout"].tap()
        let ask = app.buttons["askAIRoutine"]; reach(ask)
        XCTAssertEqual(ask.label, "Ask AI for Templates")
        shot("followup-start-\(large ? "axl" : "default")"); ask.tap()
        let goals = app.textFields["routineGoals"].exists ? app.textFields["routineGoals"] : app.textViews["routineGoals"]
        XCTAssertTrue(goals.waitForExistence(timeout: 5)); goals.tap(); goals.typeText("Build strength with my machines")
        app.buttons["dismissRoutineKeyboard"].tap()
        let addGym = app.buttons["routineAddGym"]; reach(addGym)
        shot("followup-no-gym-\(large ? "axl" : "default")"); addGym.tap()
        let name = app.textFields["gymName"]; XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap(); name.typeText("Routine Gym"); app.buttons["saveGym"].tap()
        let scan = app.buttons["routineScanMachine"]; XCTAssertTrue(scan.waitForExistence(timeout: 5)); reach(scan)
        XCTAssertEqual(any("routineMachineCount").label, "0 saved machines")
        shot("followup-empty-gym-\(large ? "axl" : "default")")
        for count in 1...2 {
            scan.tap()
            let shutter = app.buttons["scanShutter"]; XCTAssertTrue(shutter.waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts["Scan a machine or its label"].exists)
            shot("followup-capture-\(large ? "axl" : "default")"); shutter.tap()
            let use = app.buttons["scanUseCandidate"]; XCTAssertTrue(use.waitForExistence(timeout: 10)); reach(use)
            shot("followup-proposal-\(large ? "axl" : "default")"); use.tap()
            let add = app.buttons["saveMachine"]; XCTAssertTrue(add.waitForExistence(timeout: 5))
            shot("followup-machine-editor-\(large ? "axl" : "default")"); add.tap()
            XCTAssertTrue(scan.waitForExistence(timeout: 5)); reach(scan)
            XCTAssertEqual(any("routineMachineCount").label, "\(count) saved machines")
        }
        shot("followup-scanned-equipment-\(large ? "axl" : "default")")
        scan.tap(); XCTAssertTrue(app.buttons["scanShutter"].waitForExistence(timeout: 5))
        app.navigationBars["Scan Equipment"].buttons["Cancel"].tap()
        app.navigationBars["New Machine"].buttons["Cancel"].tap()
        XCTAssertTrue(scan.waitForExistence(timeout: 5))
        XCTAssertEqual(any("routineMachineCount").label, "2 saved machines")
        for _ in 0..<6 { app.swipeDown() }
        XCTAssertEqual(goals.value as? String, "Build strength with my machines")
        let generate = app.buttons["generateAIRoutine"]; reach(generate)
        XCTAssertTrue(generate.isEnabled); generate.tap()
        XCTAssertTrue(any("routineDay.2").waitForExistence(timeout: 10))
        any("routineDay.0").tap()
        XCTAssertTrue(app.staticTexts["Seated Chest Press"].firstMatch.waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.navigationBars.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Workout"].waitForExistence(timeout: 5))
        for _ in 0..<6 { app.swipeDown() }
        XCTAssertTrue(app.buttons["gymPicker"].label.contains("Routine Gym"))
        app.tabBars.buttons["Gyms"].tap()
        let gymRow = any("gymRow.Routine Gym"); XCTAssertTrue(gymRow.waitForExistence(timeout: 5)); gymRow.tap()
        XCTAssertEqual(app.staticTexts.matching(identifier: "Chest press").count, 2,
                       "Explicitly added machines survive cancelling the unsaved routine")
    }

    func testRoutineGymPickerRemembersExistingGymAndNoGym() {
        launch(); app.tabBars.buttons["Gyms"].tap()
        for name in ["First Gym", "Second Gym"] {
            app.buttons["addGym"].tap()
            let field = app.textFields["gymName"]; XCTAssertTrue(field.waitForExistence(timeout: 5))
            field.tap(); field.typeText(name); app.buttons["saveGym"].tap()
        }
        app.tabBars.buttons["Workout"].tap()
        let ask = app.buttons["askAIRoutine"]; reach(ask); ask.tap()
        let picker = app.buttons["routineGym"]; reach(picker); picker.tap()
        app.buttons["Second Gym"].tap()
        let scan = app.buttons["routineScanMachine"]; XCTAssertTrue(scan.waitForExistence(timeout: 5))
        XCTAssertEqual(any("routineMachineCount").label, "0 saved machines")
        app.navigationBars.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Workout"].waitForExistence(timeout: 5))
        for _ in 0..<4 { app.swipeDown() }
        XCTAssertTrue(app.buttons["gymPicker"].label.contains("Second Gym"))
        reach(ask); ask.tap(); reach(picker); picker.tap(); app.buttons["No gym"].tap()
        XCTAssertFalse(scan.exists)
        XCTAssertTrue(app.staticTexts["Choose or add a gym to save scanned machines."].exists)
        app.navigationBars.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Workout"].waitForExistence(timeout: 5))
        for _ in 0..<4 { app.swipeDown() }
        XCTAssertTrue(app.buttons["gymPicker"].label.contains("No gym"))
    }

    func testRoutineScannerConsentAndFailureKeepPreferences() {
        launch(["-uiTestTerraNeedsConsent", "-uiTestTerraOffline"])
        app.tabBars.buttons["Workout"].tap()
        let ask = app.buttons["askAIRoutine"]; reach(ask); ask.tap()
        let goals = app.textFields["routineGoals"].exists ? app.textFields["routineGoals"] : app.textViews["routineGoals"]
        XCTAssertTrue(goals.waitForExistence(timeout: 5)); goals.tap(); goals.typeText("Keep these preferences")
        app.buttons["dismissRoutineKeyboard"].tap()
        enable("routineEquipment.dumbbells"); enable("routineCardio.outdoorWalk")
        let addGym = app.buttons["routineAddGym"]
        for _ in 0..<5 { app.swipeDown() }; reach(addGym); addGym.tap()
        let name = app.textFields["gymName"]; XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("Consent Gym")
        app.buttons["saveGym"].tap()
        let scan = app.buttons["routineScanMachine"]; XCTAssertTrue(scan.waitForExistence(timeout: 5)); reach(scan); scan.tap()
        let allow = app.buttons["allowAIPhotos"]; XCTAssertTrue(allow.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["scanShutter"].exists)
        app.navigationBars["Scan Equipment"].buttons["Cancel"].tap()
        app.navigationBars["New Machine"].buttons["Cancel"].tap()
        XCTAssertTrue(scan.waitForExistence(timeout: 5)); XCTAssertEqual(any("routineMachineCount").label, "0 saved machines")
        scan.tap(); XCTAssertTrue(allow.waitForExistence(timeout: 5)); reach(allow); allow.tap()
        app.buttons["scanShutter"].tap()
        XCTAssertTrue(any("scanAIError").waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["scanUseCandidate"].exists)
        app.navigationBars["Scan Equipment"].buttons["Cancel"].tap()
        app.navigationBars["New Machine"].buttons["Cancel"].tap()
        XCTAssertTrue(scan.waitForExistence(timeout: 5)); XCTAssertEqual(any("routineMachineCount").label, "0 saved machines")
        for _ in 0..<5 { app.swipeDown() }
        XCTAssertEqual(goals.value as? String, "Keep these preferences")
        let dumbbells = app.switches["routineEquipment.dumbbells"].firstMatch; reach(dumbbells); XCTAssertEqual(dumbbells.value as? String, "1")
        let cardio = app.switches["routineCardio.outdoorWalk"].firstMatch; reach(cardio); XCTAssertEqual(cardio.value as? String, "1")
        let consent = app.switches["allowAIRoutine"].firstMatch; reach(consent); XCTAssertEqual(consent.value as? String, "0")
        let generate = app.buttons["generateAIRoutine"]; reach(generate); XCTAssertFalse(generate.isEnabled)
    }

    func testWeeklyRoutineDefault() { routine(large: false) }
    func testWeeklyRoutineAccessibility() { routine(large: true) }
    func testEditingGeneratedWeekKeepsRowsAndSavesOnlyOnce() { routine(large: false, edit: true) }
    private func routine(large: Bool, edit: Bool = false) {
        launch(large: large); app.tabBars.buttons["Workout"].tap()
        let ask = app.buttons["askAIRoutine"]; reach(ask); shot("ai-start-\(large ? "axl" : "default")"); ask.tap()
        let goals = app.textFields["routineGoals"].exists ? app.textFields["routineGoals"] : app.textViews["routineGoals"]
        XCTAssertTrue(goals.waitForExistence(timeout: 5)); goals.tap(); _ = app.keyboards.firstMatch.waitForExistence(timeout: 3); goals.typeText("Build strength and endurance")
        XCTAssertEqual(goals.value as? String, "Build strength and endurance")
        app.buttons["dismissRoutineKeyboard"].tap()
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        shot("ai-routine-goals-\(large ? "axl" : "default")")
        app.swipeUp()
        enable("routineEquipment.dumbbells")
        shot("ai-routine-inputs-\(large ? "axl" : "default")")
        enable("routineCardio.outdoorWalk")
        shot("ai-routine-cardio-\(large ? "axl" : "default")")
        let generate = app.buttons["generateAIRoutine"]; reach(generate); XCTAssertTrue(generate.isEnabled); generate.tap()
        let day = any("routineDay.0"); XCTAssertTrue(day.waitForExistence(timeout: 10))
        shot("ai-week-preview-\(large ? "axl" : "default")")
        day.tap(); shot("ai-day-edit-\(large ? "axl" : "default")")
        reach(app.buttons["Add cardio"]); shot("ai-day-cardio-\(large ? "axl" : "default")")
        if edit {
            let add = app.buttons["Add exercise"]; reach(add); add.tap()
            let remove = app.buttons["Remove exercise"].firstMatch; reach(remove); remove.tap()
            XCTAssertTrue(app.buttons["Remove exercise"].firstMatch.exists)
            reach(app.buttons["Add exercise"]); app.buttons["Add exercise"].tap()
            for _ in 0..<3 { app.swipeDown() }
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
        app.buttons["editTemplate"].tap()
        let save = app.navigationBars.buttons["Save"]; XCTAssertTrue(save.waitForExistence(timeout: 5))
        shot("ai-template-editor-\(large ? "axl" : "default")")
        reach(app.buttons["Add cardio target"]); shot("ai-template-cardio-editor-\(large ? "axl" : "default")")
        save.tap()
        app.buttons["startTemplate"].tap()
        let start = app.buttons["startPlannedCardio"]; XCTAssertTrue(start.waitForExistence(timeout: 10)); reach(start)
        shot("ai-planned-cardio-\(large ? "axl" : "default")")
        XCTAssertFalse(any("cardioTimer").exists)
        start.tap()
        XCTAssertTrue(any("cardioTimer").waitForExistence(timeout: 10))
    }
    func testExistingTemplateDefaultRestDefault() { defaultRestCapture(large: false) }
    func testExistingTemplateDefaultRestAccessibility() { defaultRestCapture(large: true) }
    private func defaultRestCapture(large: Bool) {
        launch(["-uiTestTemplate"], large: large); app.tabBars.buttons["Workout"].tap()
        let tile = app.buttons["templateTile.Whole Body"]; reach(tile); tile.tap()
        app.buttons["editTemplate"].tap()
        let toggle = app.switches["Use exercise rest default"].firstMatch; reach(toggle)
        XCTAssertEqual(toggle.value as? String, "1")
        shot("ai-template-default-rest-\(large ? "axl" : "default")")
        app.navigationBars.buttons["Cancel"].firstMatch.tap()
        app.buttons["startTemplate"].tap()
        XCTAssertTrue(app.staticTexts["Bench Press"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Target:")).firstMatch.exists)
        shot("ai-existing-log-\(large ? "axl" : "default")")
    }

    func testEditedProposalLabelSurvivesCatalogSelection() {
        launch(["-uiTestTerraSpecific"]); scanner(); app.buttons["scanShutter"].tap()
        let field = app.textFields["identifiedMachineLabel"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.96, dy: 0.5)).tap()
        _ = app.keyboards.firstMatch.waitForExistence(timeout: 3)
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (field.value as? String ?? "").count))
        field.typeText("Press by window")
        app.buttons["dismissEquipmentKeyboard"].tap()
        let use = app.buttons["scanUseCandidate"]; reach(use); use.tap()
        let label = app.textFields["machineLabel"]; XCTAssertTrue(label.waitForExistence(timeout: 5))
        XCTAssertEqual(label.value as? String, "Press by window")
        app.buttons["saveMachine"].tap()
        XCTAssertTrue(app.staticTexts["Press by window"].waitForExistence(timeout: 5))
    }

    func testSpecificIdentityDefault() { identityCapture("Specific", large: false) }
    func testSpecificIdentityAccessibility() { identityCapture("Specific", large: true) }
    func testNewModelIdentityDefault() { identityCapture("NewModel", large: false) }
    func testNewModelIdentityAccessibility() { identityCapture("NewModel", large: true) }
    func testAmbiguousIdentityDefault() { identityCapture("Ambiguous", large: false) }
    func testAmbiguousIdentityAccessibility() { identityCapture("Ambiguous", large: true) }
    func testUncertainIdentityDefault() { identityCapture("Uncertain", large: false) }
    func testUncertainIdentityAccessibility() { identityCapture("Uncertain", large: true) }
    private func identityCapture(_ kind: String, large: Bool) {
        launch(["-uiTestTerra" + kind], large: large); scanner(); app.buttons["scanShutter"].tap()
        let field = app.textFields["identifiedMachineLabel"]; XCTAssertTrue(field.waitForExistence(timeout: 10))
        let use = app.buttons["scanUseCandidate"]
        shot("ai-identity-\(kind.lowercased())-\(large ? "axl" : "default")")
        reach(use)
        shot("ai-identity-action-\(kind.lowercased())-\(large ? "axl" : "default")")
        if kind == "Uncertain" { XCTAssertFalse(use.isEnabled) }
        else {
            use.tap()
            let label = app.textFields["machineLabel"]; XCTAssertTrue(label.waitForExistence(timeout: 5))
            let savedName = label.value as? String ?? ""
            XCTAssertFalse(savedName.isEmpty)
            app.buttons["saveMachine"].tap()
            XCTAssertTrue(app.staticTexts[savedName].firstMatch.waitForExistence(timeout: 5))
            if kind == "Ambiguous" { XCTAssertFalse(app.staticTexts["Life Fitness Insignia Series Chest Press"].exists) }
            if kind == "NewModel" { XCTAssertTrue(app.staticTexts["Fixture Brand Printed Test Press"].exists) }
            if kind == "Specific" { XCTAssertTrue(app.staticTexts["Life Fitness Insignia Series Chest Press"].exists) }
        }
    }

    func testPhotoConsentDefault() { photoConsent(large: false) }
    func testPhotoConsentAccessibility() { photoConsent(large: true) }
    private func photoConsent(large: Bool) {
        launch(["-uiTestTerraNeedsConsent"], large: large); scanner()
        let allow = app.buttons["allowAIPhotos"]
        XCTAssertTrue(allow.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["scanShutter"].exists)
        shot("ai-photo-consent-\(large ? "axl" : "default")")
        reach(allow); shot("ai-photo-consent-action-\(large ? "axl" : "default")"); allow.tap()
        XCTAssertTrue(app.buttons["scanShutter"].waitForExistence(timeout: 5))
    }

    func testManualModelSuggestionsRequireConsentAndKeepConfirmation() {
        launch(["-uiTestScanFixture"])
        scanner()
        app.navigationBars["Scan Equipment"].buttons["Cancel"].tap()
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

    func testMissingKeyHasReachableSettings() { keySettings(large: false) }
    func testMissingKeySettingsAccessibility() { keySettings(large: true) }
    private func keySettings(large: Bool) {
        app.launchArguments = ["-uiTestReset"] + (large ? ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] : [])
        app.launch(); app.tabBars.buttons["Workout"].tap()
        reach(app.buttons["askAIRoutine"]); app.buttons["askAIRoutine"].tap()
        let settings = app.buttons["routineAISettings"]; XCTAssertTrue(settings.waitForExistence(timeout: 5)); settings.tap()
        let done = app.buttons["Done"].firstMatch
        let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in done.exists && done.frame.minY < 150 }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 5), .completed)
        shot("ai-key-settings-overview-\(large ? "axl" : "default")")
        reach(app.switches["Send equipment photos to OpenAI"].firstMatch)
        shot("ai-key-settings-permissions-\(large ? "axl" : "default")")
        let key = app.secureTextFields["askAIKeyField"]; reach(key)
        XCTAssertTrue(key.exists)
        shot("ai-key-settings-key-\(large ? "axl" : "default")")
    }
}
