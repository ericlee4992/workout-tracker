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
    }

    // MARK: - Helpers

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
        name.typeText(gymName)
        app.buttons["saveGym"].tap()
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(identifier: "gymRow.\(gymName)").firstMatch.waitForExistence(timeout: 5))
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
