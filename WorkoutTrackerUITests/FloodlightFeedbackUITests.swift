import XCTest

// Public beta ticket 07: Settings → Help → Send Feedback — the form empty (signed out), filled (a message, a
// screenshot, signed in), and sent — on record in light and dark at Default and AccessibilityL. Sending uses the
// UI-test stub (the app cannot reach a server under -uiTestReset).
final class FloodlightFeedbackUITests: XCTestCase {
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

    private func openForm(appearance: String, large: Bool, filled: Bool, extra: [String] = []) {
        app.launchArguments = ["-uiTestReset", "-uiTestDesignSample", "-appearance", appearance]
            + (filled ? ["-uiTestFeedbackSample"] : []) + extra
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] }
        app.launch()
        app.tabBars.buttons["Workout"].tap()
        let gear = app.buttons["openSettings"]
        XCTAssertTrue(gear.waitForExistence(timeout: 15))
        gear.tap()
        let row = app.buttons["sendFeedback"]
        XCTAssertTrue(any("appUnitPreference").waitForExistence(timeout: 10))
        for _ in 0..<12 where !(row.exists && row.isHittable && row.frame.maxY < app.tabBars.firstMatch.frame.minY - 8) {
            app.swipeUp()
        }
        XCTAssertTrue(row.isHittable, "Send Feedback is reachable in Settings")
        row.tap()
        XCTAssertTrue(app.buttons["feedbackSend"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.0)
    }

    /// Shoots the sheet's first page, then swipes up and shoots until `last` is fully on screen.
    private func pages(_ name: String, until last: XCUIElement, limit: Int = 6) {
        shoot("\(name)-1")
        var page = 2
        while !(last.exists && last.isHittable && last.frame.maxY < app.frame.maxY - 20), page <= limit + 1 {
            // Dragged inside the sheet's scroll view (the category, the first thing on it, scrolls away).
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)))
            Thread.sleep(forTimeInterval: 0.6)
            shoot("\(name)-\(page)")
            page += 1
        }
        XCTAssertTrue(last.exists && last.isHittable, "\(name): reached \(last)")
    }

    func testCaptureFeedbackLightDefault() { capture(appearance: "light", large: false) }
    func testCaptureFeedbackLightAccessibility() { capture(appearance: "light", large: true) }
    func testCaptureFeedbackDarkDefault() { capture(appearance: "dark", large: false) }
    func testCaptureFeedbackDarkAccessibility() { capture(appearance: "dark", large: true) }

    private func capture(appearance: String, large: Bool) {
        let suffix = "\(appearance)-\(large ? "axl" : "default")"

        // Empty, signed out: Send is off until there is a message.
        openForm(appearance: appearance, large: large, filled: false)
        XCTAssertFalse(app.buttons["feedbackSend"].isEnabled, "Send needs a message")
        XCTAssertTrue(any("feedbackAddScreenshot").exists)
        pages("feedback-empty-\(suffix)", until: any("feedbackRecipient"))

        // Filled, signed in, a screenshot attached; then sent.
        app.terminate()
        openForm(appearance: appearance, large: large, filled: true)
        XCTAssertTrue(app.buttons["feedbackSend"].isEnabled)
        XCTAssertTrue(any("feedbackScreenshot").exists)
        pages("feedback-filled-\(suffix)", until: any("feedbackRecipient"))
        app.buttons["feedbackSend"].tap()
        XCTAssertTrue(any("feedbackSent").waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8)
        shoot("feedback-sent-\(suffix)")
        app.buttons["feedbackDone"].tap()
        XCTAssertTrue(app.buttons["sendFeedback"].waitForExistence(timeout: 5), "Done returns to Settings")
    }

    // MARK: Flows

    private func typeMessage(_ text: String) {
        let field = any("feedbackMessage")
        field.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.0)
        field.typeText(text)
    }

    func testTypingEnablesSendAndAFailedSendKeepsTheDraft() {
        openForm(appearance: "dark", large: false, filled: false, extra: ["-uiTestFeedbackFail"])
        let send = app.buttons["feedbackSend"]
        XCTAssertFalse(send.isEnabled)
        typeMessage("   ")
        XCTAssertFalse(send.isEnabled, "whitespace is not a message")
        typeMessage("Rest timer drifts")
        XCTAssertTrue(send.isEnabled)
        app.buttons["Idea"].tap()
        XCTAssertTrue(app.buttons["Idea"].isSelected)
        send.tap()
        XCTAssertTrue(any("feedbackFailure").waitForExistence(timeout: 5))
        XCTAssertEqual(any("feedbackFailure").label, "Couldn't send. Check your connection and try again.")
        XCTAssertTrue((any("feedbackMessage").value as? String ?? "").contains("Rest timer drifts"), "the draft stays")
        XCTAssertTrue(app.buttons["Idea"].isSelected, "the category stays")
        XCTAssertTrue(send.isEnabled, "it can be sent again")
        shoot("feedback-failed-dark-default")
    }

    func testRemovingTheScreenshotOffersAddAgain() {
        openForm(appearance: "light", large: false, filled: true)
        XCTAssertTrue(any("feedbackScreenshot").exists)
        app.buttons["feedbackRemoveScreenshot"].tap()
        XCTAssertTrue(any("feedbackAddScreenshot").waitForExistence(timeout: 3))
        XCTAssertFalse(any("feedbackScreenshot").exists)
        XCTAssertTrue(app.staticTexts["iPhone 15 Pro Max"].exists, "the phone is shown by name")
    }

    /// Sends for real to the build's server (WT_SERVER_URL, a local `wrangler dev`). Opt-in: run with
    /// TEST_RUNNER_WT_FEEDBACK_SMOKE=1; the developer then reads it with `node scripts/feedback.mjs list --local`.
    func testSmokeSendsToTheBuildsServer() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["WT_FEEDBACK_SMOKE"] == "1", "opt-in smoke test")
        openForm(appearance: "dark", large: false, filled: true, extra: ["-uiTestRealServer"])
        app.buttons["feedbackSend"].tap()
        XCTAssertTrue(any("feedbackSent").waitForExistence(timeout: 20),
                      "sent; failure line: \(any("feedbackFailure").exists ? any("feedbackFailure").label : "none")")
    }
}
