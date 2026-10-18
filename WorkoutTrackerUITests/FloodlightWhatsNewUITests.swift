import XCTest

// Public beta ticket 14 (D62): the What's New sheet on record in light and dark at Default and AccessibilityL, and its
// flow — Continue closes it, Settings → What's New opens it again, and a test launch without the argument never sees it.
final class FloodlightWhatsNewUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func shoot(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func any(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func launch(_ extra: [String], appearance: String = "dark", large: Bool = false) {
        app.launchArguments = ["-uiTestReset", "-uiTestDesignSample"] + extra + ["-appearance", appearance]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] }
        app.launch()
    }

    func testCaptureLightDefault() { capture(appearance: "light", large: false) }
    func testCaptureLightAccessibility() { capture(appearance: "light", large: true) }
    func testCaptureDarkDefault() { capture(appearance: "dark", large: false) }
    func testCaptureDarkAccessibility() { capture(appearance: "dark", large: true) }

    private func capture(appearance: String, large: Bool) {
        launch(["-uiTestWhatsNew"], appearance: appearance, large: large)
        XCTAssertTrue(any("whatsNewSheet").waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["New: Progress"].exists)
        XCTAssertTrue(any("whatsNewContinue").isHittable, "Continue is reachable")
        Thread.sleep(forTimeInterval: 1.0)
        shoot("whatsnew-14-\(appearance)-\(large ? "axl" : "default")")
    }

    /// Continue closes it; Settings → What's New shows the same notes again; a launch without the argument shows none.
    func testContinueSettingsAndNotByDefault() {
        launch(["-uiTestWhatsNew"])
        XCTAssertTrue(any("whatsNewSheet").waitForExistence(timeout: 15))
        any("whatsNewContinue").tap()
        XCTAssertTrue(any("whatsNewSheet").waitForNonExistence(timeout: 5))

        app.tabBars.buttons["Workout"].tap()
        any("openSettings").tap()
        let row = any("settingsWhatsNew")
        for _ in 0..<6 where !row.isHittable { app.swipeUp() }
        XCTAssertTrue(row.isHittable, "What's New in Settings")
        row.tap()
        XCTAssertTrue(any("whatsNewSheet").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["New: Progress"].exists)
        any("whatsNewContinue").tap()
        XCTAssertTrue(any("whatsNewSheet").waitForNonExistence(timeout: 5))

        app.terminate()
        launch([])
        XCTAssertTrue(app.tabBars.buttons["Workout"].waitForExistence(timeout: 15))
        Thread.sleep(forTimeInterval: 2)
        XCTAssertFalse(any("whatsNewSheet").exists, "UI tests never see it unless they ask")
    }
}
