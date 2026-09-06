import XCTest

/// Scanner accuracy, ticket 05 (D53) — "Ask AI" from the scan sheet, end to
/// end in the Simulator: `-uiTestAskAI` stands in a stub key and a stub
/// transcriber (no network), `-uiTestScanFixtureNoBrand` renders a plate
/// that names no brand so the on-device read cannot preselect. Everything
/// else — Vision, the matcher, D33, the sheet — is the real code path.
final class AskAIUITests: XCTestCase {
    private var app: XCUIApplication!
    private let gymName = "Ask AI Gym"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(_ extra: [String]) {
        app.launchArguments = ["-uiTestReset", "-uiTestScanFixture", "-uiTestAskAI"] + extra
        app.launch()
    }

    /// The whole path: the camera read offers the button because nothing
    /// preselected; the ask's reading preselects; one tap accepts it.
    func testAskAIRanksWhatClaudeReadAndTheUserStillConfirms() {
        launch(["-uiTestScanFixtureNoBrand"])
        createGym()
        openNewMachineSheet()
        app.buttons["scanMachineLabel"].tap()
        tapShutter()

        let ask = app.buttons["scanAskAI"]
        XCTAssertTrue(ask.waitForExistence(timeout: 20), "a plate the phone could not place offers Ask AI")
        XCTAssertEqual(app.staticTexts["scanAskAICalls"].label, "AI calls: 0", "no call before the tap")
        // The button exists only when nothing preselected (by construction —
        // pinned in `PlateTranscriptionTests`); the accept button below the
        // candidates confirms it from the other side.
        XCTAssertFalse(scrolledTo("scanUseCandidate").isEnabled, "nothing is preselected before the ask")
        let before = XCTAttachment(screenshot: app.screenshot())
        before.name = "ask-ai-offered"
        before.lifetime = .keepAlways
        add(before)

        ask.tap()
        let candidate = app.descendants(matching: .any)
            .matching(identifier: "scanCandidate.Eagle NX Overhead Press").firstMatch
        XCTAssertTrue(candidate.waitForExistence(timeout: 20), "the AI reading is ranked by the app's matcher")
        let reading = app.staticTexts["scanReadingText"]
        XCTAssertTrue(reading.label.contains("Cybex"), "the sheet echoes what AI read, got: \(reading.label)")
        XCTAssertTrue(app.staticTexts["What AI read"].exists, "and says who read it")
        XCTAssertFalse(ask.exists, "an AI reading is not asked about again")
        XCTAssertEqual(app.staticTexts["scanAskAICalls"].label, "AI calls: 1", "one tap, one call")
        let use = scrolledTo("scanUseCandidate")
        XCTAssertTrue(use.isEnabled, "the AI reading preselected (D33) — still a tap, never applied on its own")
        let after = XCTAttachment(screenshot: app.screenshot())
        after.name = "ask-ai-results"
        after.lifetime = .keepAlways
        add(after)

        use.tap()
        let modelRow = app.descendants(matching: .any).matching(identifier: "catalogModel").firstMatch
        XCTAssertTrue(modelRow.waitForExistence(timeout: 5))
        XCTAssertTrue(modelRow.label.contains("Eagle NX Overhead Press"), "got: \(modelRow.label)")
    }

    /// Fail closed: offline leaves the on-device results exactly as they
    /// were, says so, and create-new is still one tap away.
    func testAnOfflineAskLeavesTheSheetUsable() {
        launch(["-uiTestScanFixtureNoBrand", "-uiTestAskAIOffline"])
        createGym()
        openNewMachineSheet()
        app.buttons["scanMachineLabel"].tap()
        tapShutter()

        let ask = app.buttons["scanAskAI"]
        XCTAssertTrue(ask.waitForExistence(timeout: 20))
        ask.tap()
        let note = app.staticTexts["scanAskAINote"]
        XCTAssertTrue(note.waitForExistence(timeout: 10), "a failed ask is explained, not silent")
        XCTAssertTrue(note.label.lowercased().contains("offline"), "got: \(note.label)")
        XCTAssertTrue(ask.exists, "the button stays for a manual retry")
        XCTAssertTrue(app.staticTexts["What the camera read"].exists, "the camera's results are untouched")
        XCTAssertFalse(scrolledTo("scanUseCandidate").isEnabled, "and still nothing is preselected")
        XCTAssertTrue(scrolledTo("scanCreateNew").exists, "create-new is still reachable")
    }

    /// The on-device-first rule: a plate the phone placed never offers the
    /// button — so no ask can happen — and Settings shows the feature on.
    func testAPreselectedPlateNeverOffersAskAI() {
        launch([])
        app.tabBars.buttons["Gyms"].tap()
        let settings = app.descendants(matching: .any).matching(identifier: "askAISettings").firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 5), "the Ask AI row is in Settings")
        XCTAssertTrue(settings.label.contains("On"), "a saved key shows as On, got: \(settings.label)")

        createGym()
        openNewMachineSheet()
        app.buttons["scanMachineLabel"].tap()
        tapShutter()
        let use = app.buttons["scanUseCandidate"]
        XCTAssertTrue(use.waitForExistence(timeout: 20))
        XCTAssertTrue(use.isEnabled, "the fixture plate preselects on device")
        XCTAssertFalse(app.buttons["scanAskAI"].exists, "so Ask AI is never offered")
        XCTAssertEqual(app.staticTexts["scanAskAICalls"].label, "AI calls: 0", "and no call was made")
    }

    /// Fail closed, the third way: the request timed out.
    func testATimedOutAskIsSaidPlainly() {
        launch(["-uiTestScanFixtureNoBrand", "-uiTestAskAITimeout"])
        createGym()
        openNewMachineSheet()
        app.buttons["scanMachineLabel"].tap()
        tapShutter()
        let ask = app.buttons["scanAskAI"]
        XCTAssertTrue(ask.waitForExistence(timeout: 20))
        ask.tap()
        let note = app.staticTexts["scanAskAINote"]
        XCTAssertTrue(note.waitForExistence(timeout: 10))
        XCTAssertTrue(note.label.lowercased().contains("too long"), "got: \(note.label)")
        XCTAssertTrue(ask.exists, "the button stays for a manual retry")
    }

    /// Ticket 06: from a scan that matched nothing, create-new carries the
    /// plate into the New Model sheet, and one tap ticks the exercise AI
    /// picked from the app's own list — with its reason — so Add is enabled.
    func testSuggestExercisesTicksWhatThePlateSaysAndTheUserKeepsTheFinalSay() {
        launch(["-uiTestScanFixtureNoBrand"])
        createGym()
        openNewMachineSheet()
        app.buttons["scanMachineLabel"].tap()
        tapShutter()
        XCTAssertTrue(app.buttons["scanAskAI"].waitForExistence(timeout: 20))
        scrolledTo("scanCreateNew").tap()

        let manufacturer = app.textFields["Manufacturer"]
        XCTAssertTrue(manufacturer.waitForExistence(timeout: 5), "the New Model sheet opens")
        let suggest = app.buttons["newModelSuggestExercises"]
        XCTAssertTrue(suggest.exists, "a scanned plate with Ask AI on offers a suggestion")
        let save = app.buttons["saveNewModel"]
        XCTAssertFalse(save.isEnabled, "nothing linked yet")

        // The plate named no brand, so the manufacturer is the user's to type
        // (done first: swiping back up a sheet can dismiss it). With the
        // names in, the tick AI makes is what enables Add.
        manufacturer.tap()
        manufacturer.typeText("Cybex")
        let model = app.textFields["Model"]
        if (model.value as? String ?? "").isEmpty || model.value as? String == "Model" {
            model.tap()
            model.typeText("Overhead Press")
        }
        XCTAssertFalse(save.isEnabled, "names alone do not satisfy 'link at least one'")
        suggest.tap()

        let reason = app.staticTexts["newModelExerciseReason.Machine Shoulder Press"]
        XCTAssertTrue(waitScrolling(for: reason), "the picked exercise shows AI's reason under it")
        XCTAssertFalse(app.staticTexts["newModelSuggestNote"].exists, "no failure note")
        XCTAssertTrue(save.isEnabled, "the AI-ticked exercise satisfies 'link at least one'")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "suggest-exercises"
        shot.lifetime = .keepAlways
        add(shot)

        // The user keeps the final say: untick it and Add goes away again.
        let row = app.descendants(matching: .any).matching(identifier: "newModelExercise.Machine Shoulder Press").firstMatch
        XCTAssertTrue(waitScrolling(for: row))
        row.tap()
        XCTAssertFalse(save.isEnabled, "unticking the proposal is one tap")
    }

    /// Fail closed, the other way: the model declined. Same shape as offline.
    func testARefusedAskIsSaidPlainly() {
        launch(["-uiTestScanFixtureNoBrand", "-uiTestAskAIRefused"])
        createGym()
        openNewMachineSheet()
        app.buttons["scanMachineLabel"].tap()
        tapShutter()
        let ask = app.buttons["scanAskAI"]
        XCTAssertTrue(ask.waitForExistence(timeout: 20))
        ask.tap()
        let note = app.staticTexts["scanAskAINote"]
        XCTAssertTrue(note.waitForExistence(timeout: 10))
        XCTAssertTrue(note.label.lowercased().contains("declined"), "got: \(note.label)")
        XCTAssertTrue(app.staticTexts["What the camera read"].exists, "the camera's results are untouched")
    }

    /// One tap, one call, and a rescan CANCELS it: the reply from before the
    /// rescan never lands on the new results (codex-review-05, high).
    func testARescanDropsTheAskInFlight() {
        launch(["-uiTestScanFixtureNoBrand", "-uiTestAskAISlow"])
        createGym()
        openNewMachineSheet()
        app.buttons["scanMachineLabel"].tap()
        tapShutter()
        let ask = app.buttons["scanAskAI"]
        XCTAssertTrue(ask.waitForExistence(timeout: 20))
        ask.tap()
        XCTAssertTrue(app.staticTexts["scanAskAIStatus"].waitForExistence(timeout: 3), "the ask is in flight")

        // Rescan through it: back to the viewfinder, shutter again.
        let again = scrolledTo("Scan again")
        XCTAssertTrue(again.exists)
        again.tap()
        tapShutter()
        XCTAssertTrue(ask.waitForExistence(timeout: 20), "fresh camera results, the button offered anew")
        // Longer than the slow stub's 4 s: had the old reply survived the
        // rescan it would have landed by now.
        sleep(6)
        XCTAssertTrue(app.staticTexts["What the camera read"].exists, "still the camera's reading")
        XCTAssertFalse(app.staticTexts["What AI read"].exists, "the cancelled ask's reply never landed")
        XCTAssertFalse(app.staticTexts["scanAskAINote"].exists, "and left no note either")
        XCTAssertTrue(ask.exists, "one tap, one call — the button is back for a NEW tap")
    }

    // MARK: - Helpers

    /// Swipes up until `element` exists (a lazy List row below the fold).
    private func waitScrolling(for element: XCUIElement) -> Bool {
        for _ in 0..<12 {
            if element.waitForExistence(timeout: 1) { return true }
            app.swipeUp()
        }
        return element.exists
    }

    /// A `List` is lazy: a row below the fold is not in the hierarchy until
    /// it scrolls into view. Swipes until `identifier` exists (or gives up
    /// and returns the non-existent element for the assertion to report).
    private func scrolledTo(_ identifier: String) -> XCUIElement {
        let element = app.buttons[identifier]
        for _ in 0..<4 where !element.exists {
            app.swipeUp()
        }
        return element
    }

    private func tapShutter() {
        let shutter = app.buttons["scanShutter"]
        XCTAssertTrue(shutter.waitForExistence(timeout: 10), "the viewfinder should show a shutter")
        shutter.tap()
    }

    private func createGym() {
        app.tabBars.buttons["Gyms"].tap()
        app.buttons["addGym"].tap()
        let name = app.textFields["gymName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        // On the suite's cold first launch the keyboard can lag the tap and
        // swallow the first characters, so the row never gets its name
        // (seen once in a full-suite run): wait for it, then verify.
        _ = app.keyboards.firstMatch.waitForExistence(timeout: 3)
        name.typeText(gymName)
        XCTAssertEqual(name.value as? String, gymName, "the whole name was typed")
        app.buttons["saveGym"].tap()
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(identifier: "gymRow.\(gymName)").firstMatch.waitForExistence(timeout: 10))
    }

    private func openNewMachineSheet() {
        app.descendants(matching: .any)
            .matching(identifier: "gymRow.\(gymName)").firstMatch.tap()
        let add = app.buttons["addMachine"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        XCTAssertTrue(app.textFields["machineLabel"].waitForExistence(timeout: 5))
    }
}
