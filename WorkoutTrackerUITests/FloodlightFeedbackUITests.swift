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

    private func openForm(appearance: String, large: Bool, filled: Bool) {
        app.launchArguments = ["-uiTestReset", "-uiTestDesignSample", "-appearance", appearance]
            + (filled ? ["-uiTestFeedbackSample"] : [])
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
}
