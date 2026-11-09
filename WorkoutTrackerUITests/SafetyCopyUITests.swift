import XCTest

// Nutrition N1: the safety copy on screen — a copy that failed at launch (the store stays closed until the user
// chooses), the Settings row with its dated confirmation, and the wait for the next launch after Restore. The copy,
// prune and restore themselves are covered by `SafetyCopyTests` and the Simulator rehearsal (ticket N1).
final class SafetyCopyUITests: XCTestCase {
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

    private func launch(_ extra: [String], appearance: String = "light", large: Bool = false) {
        app.launchArguments = ["-uiTestReset", "-uiTestDesignSample", "-appearance", appearance] + extra
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] }
        app.launch()
    }

    private func visible(_ element: XCUIElement) -> Bool {
        let bar = app.tabBars.firstMatch
        let floor = bar.exists ? bar.frame.minY - 8 : app.frame.maxY - 30
        return element.exists && element.isHittable && element.frame.minY > 100 && element.frame.maxY < floor
    }

    /// Scrolls Settings until `element` is on screen and clear of both bars.
    private func reach(_ element: XCUIElement, limit: Int = 16) {
        for _ in 0..<limit { guard !visible(element) else { break }
            let down = element.exists && element.frame.minY <= 100
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: down ? 0.35 : 0.65))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: down ? 0.6 : 0.4)))
            Thread.sleep(forTimeInterval: 0.3)
        }
        XCTAssertTrue(visible(element), "reached \(element)")
    }

    private func openSettings() {
        app.openProfile()
        XCTAssertTrue(any("appUnitPreference").waitForExistence(timeout: 10))
    }

    // MARK: Flows

    func testAFailedCopyKeepsTheDataClosedUntilTheUserContinues() {
        launch([SafetyCopyArguments.fails])
        XCTAssertTrue(any("safetyCopyFailed").waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Couldn't save a safety copy"].exists)
        XCTAssertTrue(any("safetyCopyFailureReason").label.hasPrefix("Not enough free space"), any("safetyCopyFailureReason").label)
        XCTAssertFalse(app.tabBars.firstMatch.exists, "the app's screens wait for the choice")
        // Try Again: the copy still fails, so the screen stays.
        app.buttons["safetyCopyTryAgain"].tap()
        XCTAssertTrue(any("safetyCopyFailed").waitForExistence(timeout: 5))
        XCTAssertFalse(app.tabBars.firstMatch.exists)
        app.buttons["safetyCopyContinue"].tap()
        XCTAssertTrue(app.tabBars.buttons["Train"].waitForExistence(timeout: 15), "Continue opens the app")
        XCTAssertFalse(any("safetyCopyFailed").exists)
    }

    func testRestoreNamesTheCopysDateAndWaitsForTheNextLaunch() {
        launch([SafetyCopyArguments.copy])
        openSettings()
        let row = any("safetyCopyRestore")
        reach(row)
        XCTAssertTrue(row.label.contains("Restore data from before the update"), row.label)
        XCTAssertTrue(row.label.contains("Nov 9, 2026"), row.label)
        row.tap()
        XCTAssertTrue(app.staticTexts["Restore data from Nov 9, 2026?"].waitForExistence(timeout: 5))
        app.buttons["Restore"].firstMatch.tap()
        let pending = any("safetyRestorePending")
        XCTAssertTrue(pending.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Close Stacked to finish"].exists)
        // Nothing underneath can be reached while the restore waits (codex-review-n1 #3): no tab, no row.
        let train = app.tabBars.buttons["Train"]
        XCTAssertFalse(train.exists && train.isHittable, "the Train tab under the full-screen waiting screen")
        XCTAssertFalse(row.exists && row.isHittable, "the Settings row under the waiting screen")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.97)).tap()   // where the tab bar is
        XCTAssertTrue(pending.exists, "a tap on the covered tab bar changes nothing")
        app.buttons["safetyRestoreCancel"].tap()
        XCTAssertTrue(pending.waitForNonExistence(timeout: 5))
        XCTAssertTrue(row.waitForExistence(timeout: 5), "back in Settings, the copy still offered")
    }

    func testWithoutACopyThereIsNoRestoreRow() {
        launch([])
        openSettings()
        reach(any("exportSettings"))
        for _ in 0..<4 { app.swipeUp() }
        XCTAssertFalse(any("safetyCopyRestore").exists)
        XCTAssertFalse(app.staticTexts["Safety copy"].exists)
    }

    // MARK: Captures — the failed copy, the row, the confirmation, the wait; light and dark at Default and AccessibilityL

    func testCaptureLightDefault() { capture(appearance: "light", large: false) }
    func testCaptureDarkDefault() { capture(appearance: "dark", large: false) }
    func testCaptureLightAccessibility() { capture(appearance: "light", large: true) }
    func testCaptureDarkAccessibility() { capture(appearance: "dark", large: true) }

    private func capture(appearance: String, large: Bool) {
        let tag = "\(appearance)-\(large ? "axl" : "default")"
        launch([SafetyCopyArguments.fails, SafetyCopyArguments.copy], appearance: appearance, large: large)
        XCTAssertTrue(any("safetyCopyFailed").waitForExistence(timeout: 15))
        shoot("safety-copy-failed-\(tag)")
        app.buttons["safetyCopyContinue"].tap()
        openSettings()
        let row = any("safetyCopyRestore")
        reach(row)
        shoot("safety-copy-row-\(tag)")
        row.tap()
        XCTAssertTrue(app.buttons["Restore"].firstMatch.waitForExistence(timeout: 5))
        shoot("safety-copy-confirm-\(tag)")
        app.buttons["Restore"].firstMatch.tap()
        XCTAssertTrue(any("safetyRestorePending").waitForExistence(timeout: 5))
        shoot("safety-copy-pending-\(tag)")
    }
}

/// The app's UI-test flags (`SafetyCopyFixture`).
private enum SafetyCopyArguments {
    static let copy = "-uiTestSafetyCopy"
    static let fails = "-uiTestSafetyCopyFails"
}
