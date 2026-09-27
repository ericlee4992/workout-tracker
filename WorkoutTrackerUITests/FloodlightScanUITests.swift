import XCTest

// Floodlight redesign ticket 07: the Scan sheets — Scan Machine (consent, camera, identifying,
// the result for each identity, the error, no key, Change exercises, Added), Read Label
// (viewfinder, results) and Correct Model — on record in light and dark at Default and
// AccessibilityL on the design sample's Iron Temple; plus the direct-add and correction flows.
final class FloodlightScanUITests: XCTestCase {
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

    private func launch(_ extra: [String], appearance: String, large: Bool) {
        app.launchArguments = ["-uiTestReset", "-uiTestDesignSample", "-uiTestDesignHistory", "-uiTestDesignGyms"]
            + extra + ["-appearance", appearance]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] }
        app.launch()
    }

    private func openIronTemple() {
        app.tabBars.buttons["Gyms"].tap()
        let iron = any("gymRow.Iron Temple")
        XCTAssertTrue(iron.waitForExistence(timeout: 15))
        iron.tap()
        XCTAssertTrue(any("scanMachine").waitForExistence(timeout: 10))
    }

    /// The camera's gym chip: "Iron Temple, N machines".
    private func machineCount() -> Int? {
        let chip = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Iron Temple,")).firstMatch
        guard chip.waitForExistence(timeout: 3) else { return nil }
        return chip.label.split(separator: " ").compactMap { Int($0) }.first
    }

    private func openScan() {
        openIronTemple()
        any("scanMachine").tap()
    }

    /// Swipes up inside the sheet until `element` is on screen and clear of the pinned bar.
    private func reach(_ element: XCUIElement, bar: XCUIElement? = nil, name: String? = nil, limit: Int = 8) {
        var page = 2
        func clear() -> Bool {
            guard element.exists, element.isHittable else { return false }
            let floor = bar.map { $0.frame.minY - 12 } ?? app.frame.maxY - 100
            return element.frame.maxY <= floor
        }
        while !clear(), page <= limit + 1 {
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.5)
            if let name { shoot("\(name)-\(page)") }
            page += 1
        }
    }

    // MARK: Scan Machine: consent → camera → identifying → result → Added

    func testCaptureScanLightDefault() { captureScan(appearance: "light", large: false) }
    func testCaptureScanLightAccessibility() { captureScan(appearance: "light", large: true) }
    func testCaptureScanDarkDefault() { captureScan(appearance: "dark", large: false) }
    func testCaptureScanDarkAccessibility() { captureScan(appearance: "dark", large: true) }

    private func captureScan(appearance: String, large: Bool) {
        launch(["-uiTestTerra", "-uiTestTerraSpecific", "-uiTestTerraNeedsConsent", "-uiTestTerraSlow"],
               appearance: appearance, large: large)
        let suffix = "\(appearance)-\(large ? "axl" : "default")"
        openScan()

        // S02: consent comes first (user decision 2), before the camera.
        let allow = app.buttons["allowAIPhotos"]
        XCTAssertTrue(allow.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["scanShutter"].exists)
        Thread.sleep(forTimeInterval: 1.6)
        shoot("floodlight-07-consent-\(suffix)-1")
        reach(any("OpenAI data policies"), bar: allow, name: "floodlight-07-consent-\(suffix)", limit: 2)
        allow.tap()

        // S01: the camera (the fixture's plate stands in), the gym chip with the count.
        let shutter = app.buttons["scanShutter"]
        XCTAssertTrue(shutter.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Scan a machine or its label"].exists)
        let before = machineCount()
        XCTAssertNotNil(before, "the gym chip names the gym and its machine count")
        Thread.sleep(forTimeInterval: 1.0)
        shoot("floodlight-07-camera-\(suffix)")
        shutter.tap()

        // S03: identifying (the slow fixture holds it ~4 s).
        XCTAssertTrue(app.staticTexts["Identifying equipment…"].waitForExistence(timeout: 3)
                      || any("scanRescan").waitForExistence(timeout: 1))
        Thread.sleep(forTimeInterval: 1.0)
        shoot("floodlight-07-identifying-\(suffix)")

        // S04: a catalog match, named by its movement (D3), with the duplicate warning.
        let use = app.buttons["scanUseCandidate"]
        XCTAssertTrue(use.waitForExistence(timeout: 12))
        XCTAssertTrue(use.label.contains("Add to Iron Temple"), use.label)
        let field = app.textFields["identifiedMachineLabel"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, "Seated Chest Press")
        XCTAssertTrue(app.staticTexts["Matches catalog"].exists)
        Thread.sleep(forTimeInterval: 1.2)
        shoot("floodlight-07-result-specific-\(suffix)-1")
        let duplicate = any("scanDuplicate")
        XCTAssertTrue(duplicate.exists, "Chest Press 2 is already on this model")
        reach(any("scanChangeExercises").exists ? any("scanChangeExercises") : app.staticTexts["Exercises"],
              bar: use, name: "floodlight-07-result-specific-\(suffix)", limit: 4)

        // Use generic identity: the answer is set aside, then brought back.
        for _ in 0..<6 { app.swipeDown() }
        let toggle = any("scanGenericToggle")
        reach(toggle, bar: use)
        toggle.tap()
        XCTAssertTrue(app.staticTexts["Generic"].waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 0.8)
        for _ in 0..<6 { app.swipeDown() }
        shoot("floodlight-07-result-generic-toggle-\(suffix)")
        reach(toggle, bar: use)
        toggle.tap()
        XCTAssertTrue(app.staticTexts["Matches catalog"].waitForExistence(timeout: 3))

        // Added: the machine is saved at Iron Temple and the count moves up by one.
        use.tap()
        let done = app.buttons["scanDone"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Added to Iron Temple"].exists)
        Thread.sleep(forTimeInterval: 1.6)
        shoot("floodlight-07-added-\(suffix)")

        // Scan another machine returns to the camera, the gym counting one more.
        app.buttons["scanAnother"].tap()
        XCTAssertTrue(shutter.waitForExistence(timeout: 5))
        XCTAssertEqual(machineCount(), before.map { $0 + 1 }, "the gym chip counts the added machine")
        app.buttons["scanCancel"].tap()
        XCTAssertTrue(any("scanMachine").waitForExistence(timeout: 5))
    }

    // MARK: The other identities, the error, no key, Change exercises

    func testCaptureOutcomesLightDefault() { captureOutcomes(appearance: "light", large: false) }
    func testCaptureOutcomesLightAccessibility() { captureOutcomes(appearance: "light", large: true) }
    func testCaptureOutcomesDarkDefault() { captureOutcomes(appearance: "dark", large: false) }
    func testCaptureOutcomesDarkAccessibility() { captureOutcomes(appearance: "dark", large: true) }

    private func scanTo(_ kind: String?, appearance: String, large: Bool) -> XCUIElement {
        launch(["-uiTestTerra"] + (kind.map { ["-uiTestTerra" + $0] } ?? []), appearance: appearance, large: large)
        openScan()
        let shutter = app.buttons["scanShutter"]
        XCTAssertTrue(shutter.waitForExistence(timeout: 10))
        shutter.tap()
        return app.buttons["scanUseCandidate"]
    }

    private func captureOutcomes(appearance: String, large: Bool) {
        let suffix = "\(appearance)-\(large ? "axl" : "default")"

        // New model: a visible maker/model the catalog lacks.
        var use = scanTo("NewModel", appearance: appearance, large: large)
        XCTAssertTrue(use.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["New model"].waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 1.2)
        shoot("floodlight-07-result-newmodel-\(suffix)")

        // Ambiguous: two catalog rows share the name — listed, saved without a model (D56).
        use = scanTo("Ambiguous", appearance: appearance, large: large)
        XCTAssertTrue(use.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["2 matches"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Saved without a model"].exists)
        Thread.sleep(forTimeInterval: 1.2)
        shoot("floodlight-07-result-ambiguous-\(suffix)")

        // Generic, then Change exercises.
        use = scanTo(nil, appearance: appearance, large: large)
        XCTAssertTrue(use.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Generic"].waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 1.2)
        shoot("floodlight-07-result-generic-\(suffix)-1")
        let change = any("scanChangeExercises")
        reach(change, bar: use, name: "floodlight-07-result-generic-\(suffix)", limit: 4)
        change.tap()
        let count = any("scanExerciseCount")
        XCTAssertTrue(count.waitForExistence(timeout: 5))
        XCTAssertEqual(count.label, "1 of 6 exercises")
        XCTAssertTrue(app.staticTexts["Suggested"].exists)
        Thread.sleep(forTimeInterval: 0.8)
        shoot("floodlight-07-exercises-\(suffix)")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(use.waitForExistence(timeout: 5))

        // Uncertain: no name, no exercises — Add stays disabled.
        use = scanTo("Uncertain", appearance: appearance, large: large)
        XCTAssertTrue(use.waitForExistence(timeout: 10))
        XCTAssertFalse(use.isEnabled)
        Thread.sleep(forTimeInterval: 1.2)
        shoot("floodlight-07-result-uncertain-\(suffix)")

        // The error, beside the photo.
        _ = scanTo("Offline", appearance: appearance, large: large)
        XCTAssertTrue(any("scanAIError").waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 1.0)
        shoot("floodlight-07-error-\(suffix)")

        // No key: consent first, then the key step (no Terra fixture, no key stored).
        launch([], appearance: appearance, large: large)
        openScan()
        // Photo consent may already be stored on this simulator; the key step follows it either way.
        let allow = app.buttons["allowAIPhotos"]
        if allow.waitForExistence(timeout: 5) { allow.tap() }
        XCTAssertTrue(app.buttons["scannerAISettings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["scanManual"].exists)
        Thread.sleep(forTimeInterval: 0.8)
        shoot("floodlight-07-nokey-\(suffix)")
        // Choose a catalog model hands over to the machine form.
        app.buttons["scanManual"].tap()
        XCTAssertTrue(app.textFields["machineLabel"].waitForExistence(timeout: 5))
    }

    // MARK: Read Label (on device)

    func testCaptureReadLabelLightDefault() { captureReadLabel(appearance: "light", large: false) }
    func testCaptureReadLabelLightAccessibility() { captureReadLabel(appearance: "light", large: true) }
    func testCaptureReadLabelDarkDefault() { captureReadLabel(appearance: "dark", large: false) }
    func testCaptureReadLabelDarkAccessibility() { captureReadLabel(appearance: "dark", large: true) }

    private func captureReadLabel(appearance: String, large: Bool) {
        launch(["-uiTestScanFixture"], appearance: appearance, large: large)
        let suffix = "\(appearance)-\(large ? "axl" : "default")"
        openIronTemple()
        let add = any("addMachine")
        reach(add)
        add.tap()
        let offline = app.buttons["scanLabelOffline"]
        XCTAssertTrue(offline.waitForExistence(timeout: 5))
        offline.tap()
        let shutter = app.buttons["scanShutter"]
        XCTAssertTrue(shutter.waitForExistence(timeout: 10))
        XCTAssertTrue(any("scanFramingBox").exists)
        Thread.sleep(forTimeInterval: 2.0) // the sheet slides up over the form; let it land
        shoot("floodlight-07-readlabel-camera-\(suffix)")
        shutter.tap()
        let candidate = any("scanCandidate.Insignia Series Chest Press")
        XCTAssertTrue(candidate.waitForExistence(timeout: 20))
        let use = app.buttons["scanUseCandidate"]
        XCTAssertTrue(use.isEnabled, "a confident match arrives preselected (D33)")
        Thread.sleep(forTimeInterval: 1.2)
        shoot("floodlight-07-readlabel-results-\(suffix)-1")
        reach(any("scanCreateNew"), bar: use, name: "floodlight-07-readlabel-results-\(suffix)", limit: 4)
        use.tap()
        XCTAssertTrue(app.textFields["machineLabel"].waitForExistence(timeout: 5))
    }

    // MARK: Correct Model

    func testCaptureCorrectionLightDefault() { captureCorrection(appearance: "light", large: false) }
    func testCaptureCorrectionLightAccessibility() { captureCorrection(appearance: "light", large: true) }
    func testCaptureCorrectionDarkDefault() { captureCorrection(appearance: "dark", large: false) }
    func testCaptureCorrectionDarkAccessibility() { captureCorrection(appearance: "dark", large: true) }

    private func openCorrection() {
        openIronTemple()
        let chest = any("machineRow.Chest Press 2")
        for _ in 0..<8 where !(chest.exists && chest.isHittable
                               && chest.frame.maxY < app.tabBars.firstMatch.frame.minY - 8) { app.swipeUp() }
        chest.staticTexts["Chest Press 2"].tap()
        let correct = any("machineDetail.correctModel")
        XCTAssertTrue(any("machineDetail.best.0").waitForExistence(timeout: 10))
        reach(correct)
        correct.tap()
        XCTAssertTrue(any("correctModel.commit").waitForExistence(timeout: 5))
    }

    /// The first suggested model that is not the current one.
    private var suggestion: XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND NOT identifier ENDSWITH %@",
                                         "correctModel.option.", "Insignia Series Chest Press")).firstMatch
    }

    private func captureCorrection(appearance: String, large: Bool) {
        launch([], appearance: appearance, large: large)
        let suffix = "\(appearance)-\(large ? "axl" : "default")"
        openCorrection()
        let commit = any("correctModel.commit")
        XCTAssertFalse(commit.isEnabled, "nothing to correct until the model changes")
        Thread.sleep(forTimeInterval: 1.0)
        shoot("floodlight-07-correct-\(suffix)-1")
        let pick = suggestion
        XCTAssertTrue(pick.waitForExistence(timeout: 5), "a likely correction is suggested")
        reach(pick, bar: commit)
        pick.tap()
        let past = any("correctModel.scope.applyToPast")
        reach(past, bar: commit)
        past.tap()
        XCTAssertTrue(commit.isEnabled)
        Thread.sleep(forTimeInterval: 1.0)
        shoot("floodlight-07-correct-picked-\(suffix)")
        commit.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Change the model in")).firstMatch
                        .waitForExistence(timeout: 5), "past workouts are rewritten only after asking")
        Thread.sleep(forTimeInterval: 0.6)
        shoot("floodlight-07-correct-confirm-\(suffix)")
        // Dismiss the question (a popover with no Cancel button at the default size) by a tap
        // outside it; the sheet stays.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)).tap()
        XCTAssertTrue(commit.waitForExistence(timeout: 5), "cancelling the question keeps the sheet")
    }

    // MARK: Flows

    /// What a finished workout says Chest Press 2 was: the history detail's snapshot equipment
    /// line ("Chest Press 2 · <model at log time>", D23). Opens the recent workouts until one used
    /// it, reads the line, and comes back to the Gyms tab where it was.
    private func historyEquipment(_ machine: String = "Chest Press 2") -> String? {
        // Right after a sheet closes the tab bar is still settling; a tap then has no hit point.
        let tab = app.tabBars.buttons["History"]
        for _ in 0..<10 where !tab.isHittable { Thread.sleep(forTimeInterval: 0.5) }
        Thread.sleep(forTimeInterval: 0.6)
        tab.tap()
        defer { app.tabBars.buttons["Gyms"].tap() }
        let rows = app.buttons.matching(identifier: "historyWorkoutRow")
        // The list's rows stay in the accessibility tree under a pushed detail, so "back on the
        // list" means no Back button: pop until there is none.
        let back = app.navigationBars.buttons["BackButton"]
        func popToList() {
            for _ in 0..<4 where back.exists {
                back.firstMatch.tap()
                Thread.sleep(forTimeInterval: 0.8)
            }
        }
        popToList()
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10))
        for index in 0..<5 {
            let row = rows.element(boundBy: index)
            guard row.exists else { break }
            for _ in 0..<4 where !(row.isHittable && row.frame.maxY < app.tabBars.firstMatch.frame.minY - 8) { app.swipeUp() }
            row.tap()
            let line = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "\(machine) · ")).firstMatch
            let found = line.waitForExistence(timeout: 3) ? line.label : nil
            popToList()
            XCTAssertFalse(back.exists, "back on the History list")
            if let found { return found }
        }
        return nil
    }

    private var currentModel: String { "Insignia Series Chest Press" }

    /// The machine page exists UNDER the sheet too, so "closed" means the sheet's own commit is gone.
    private func assertSheetClosed() {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: any("correctModel.commit"))
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 5), .completed, "the Correct Model sheet closed")
        XCTAssertTrue(any("machineDetail.correctModel").waitForExistence(timeout: 5))
    }

    /// The suggestion's model name, from its identifier ("correctModel.option.<maker model>").
    private func pickSuggestion() -> String {
        let pick = suggestion
        XCTAssertTrue(pick.waitForExistence(timeout: 5), "a likely correction is suggested")
        let displayName = pick.identifier.replacingOccurrences(of: "correctModel.option.", with: "")
        reach(pick, bar: any("correctModel.commit"))
        pick.tap()
        return displayName
    }

    /// Future-only needs no question, changes the machine's model, and leaves history as logged.
    func testFutureOnlyCorrectionAppliesWithoutAsking() {
        launch([], appearance: "dark", large: false)
        let before = historyEquipment()
        XCTAssertTrue(before?.contains(currentModel) == true, "history names the model at log time: \(String(describing: before))")
        openCorrection()
        let chosen = pickSuggestion()
        any("correctModel.commit").tap()
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Change the model in")).firstMatch.exists)
        assertSheetClosed()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", chosen)).firstMatch
                        .waitForExistence(timeout: 5), "the machine page shows \(chosen)")
        XCTAssertEqual(historyEquipment(), before, "future-only leaves logged workouts on the old model")
    }

    /// Apply to Past asks first; cancelling the question (and the sheet) changes nothing; confirming
    /// rewrites this machine's logged workouts to the new model.
    func testPastCorrectionAsksThenApplies() {
        launch([], appearance: "light", large: false)
        let before = historyEquipment()
        XCTAssertTrue(before?.contains(currentModel) == true, "history names the model at log time: \(String(describing: before))")
        openCorrection()
        let chosen = pickSuggestion()
        let past = any("correctModel.scope.applyToPast")
        reach(past, bar: any("correctModel.commit"))
        XCTAssertTrue(past.value.map { "\($0)" }?.hasPrefix("Rewrites") == true, "\(String(describing: past.value))")
        past.tap()
        any("correctModel.commit").tap()
        // The scope tile carries the same label; the question's button is the one that is not the tile.
        let confirm = app.buttons.matching(NSPredicate(format: "label == %@ AND identifier != %@",
                                                       "Apply to Past Workouts Too", "correctModel.scope.applyToPast")).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))

        // Cancel the question (on iOS 27 a popover on the tile, with no Cancel button: a tap
        // outside it), then the sheet: nothing changed.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)).tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: confirm)
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 5), .completed, "the question closed")
        XCTAssertTrue(any("correctModel.commit").waitForExistence(timeout: 5), "cancelling the question keeps the sheet")
        app.buttons["scanCancel"].tap()
        assertSheetClosed()
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", chosen)).firstMatch.exists,
                       "the machine keeps its model")
        XCTAssertEqual(historyEquipment(), before, "cancelling leaves history alone")

        // Now confirm it.
        any("machineDetail.correctModel").tap()
        XCTAssertTrue(any("correctModel.commit").waitForExistence(timeout: 5))
        XCTAssertEqual(pickSuggestion(), chosen)
        reach(past, bar: any("correctModel.commit"))
        past.tap()
        any("correctModel.commit").tap()
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        assertSheetClosed()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", chosen)).firstMatch
                        .waitForExistence(timeout: 5), "the machine page shows \(chosen)")
        let after = historyEquipment()
        XCTAssertEqual(after, "Chest Press 2 · \(chosen)", "the logged workouts now name the corrected model")
    }

    /// Clearing Maker or Model on the way to retyping it keeps both fields (the answer resolves to
    /// generic for a moment), and an unedited name follows the new catalog match — the SAME name
    /// the form then receives (codex-review-07).
    func testEditingMakerAndModelKeepsTheFieldsAndTheNameFollows() {
        launch(["-uiTestTerra", "-uiTestTerraSpecific"], appearance: "dark", large: false)
        openIronTemple()
        let add = any("addMachine")
        reach(add)
        add.tap()
        let scan = app.buttons["scanMachineLabel"]
        XCTAssertTrue(scan.waitForExistence(timeout: 5))
        scan.tap()
        let shutter = app.buttons["scanShutter"]
        XCTAssertTrue(shutter.waitForExistence(timeout: 10))
        shutter.tap()
        let use = app.buttons["scanUseCandidate"]
        XCTAssertTrue(use.waitForExistence(timeout: 10))
        let name = any("identifiedMachineLabel")
        XCTAssertEqual(name.value as? String, "Seated Chest Press")
        let model = any("identifiedModel")
        reach(model, bar: use)
        let old = model.value as? String ?? ""
        model.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: model.frame.width - 10, dy: 14)).tap()
        _ = app.keyboards.firstMatch.waitForExistence(timeout: 3)
        model.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count + 2))
        XCTAssertTrue(any("identifiedModel").exists && any("identifiedManufacturer").exists,
                      "the editors stay while the field is empty")
        XCTAssertTrue(app.staticTexts["Generic"].waitForExistence(timeout: 3), "an empty model resolves to no model")
        any("identifiedModel").typeText("Insignia Series Shoulder Press")
        app.buttons["dismissEquipmentKeyboard"].tap()
        XCTAssertTrue(app.staticTexts["Matches catalog"].waitForExistence(timeout: 3))
        let followed = any("identifiedMachineLabel").value as? String ?? ""
        XCTAssertFalse(followed.isEmpty)
        XCTAssertNotEqual(followed, "Seated Chest Press", "the unedited name follows the new match")
        use.tap()
        let label = app.textFields["machineLabel"]
        XCTAssertTrue(label.waitForExistence(timeout: 5))
        XCTAssertEqual(label.value as? String, followed, "the form receives the name the result showed")
        let row = any("catalogModel")
        XCTAssertTrue(row.label.contains("Insignia Series Shoulder Press"), row.label)
    }

    /// The generic answer is added straight to the gym and listed on its page.
    func testScanMachineAddsTheMachineDirectly() {
        launch(["-uiTestTerra"], appearance: "dark", large: false)
        openScan()
        app.buttons["scanShutter"].tap()
        let use = app.buttons["scanUseCandidate"]
        XCTAssertTrue(use.waitForExistence(timeout: 10))
        XCTAssertEqual(app.textFields["identifiedMachineLabel"].value as? String, "Chest press")
        use.tap()
        XCTAssertTrue(app.buttons["scanDone"].waitForExistence(timeout: 5))
        app.buttons["scanDone"].tap()
        let row = any("machineRow.Chest press")
        for _ in 0..<10 where !row.exists { app.swipeUp() }
        XCTAssertTrue(row.waitForExistence(timeout: 5), "the scanned machine is at Iron Temple")
    }
}
