import XCTest

// Public beta ticket 03 (UI-first): the sign-in sheet from Settings (and its failure line), the delete-account
// confirmation and its follow-up, and the welcome page with Sign in with Apple (and after signing in) — on sample
// data, in light and dark at Default and AccessibilityL.
final class FloodlightAccountUITests: XCTestCase {
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

    private func launch(appearance: String, large: Bool, flags: [String], design: Bool = true) {
        app.launchArguments = ["-uiTestReset", "-appearance", appearance] + flags
        if design { app.launchArguments += ["-uiTestDesignSample", "-uiTestDesignGyms", "-uiTestTerra"] }
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] }
        app.launch()
    }

    private func openSettings() {
        app.tabBars.buttons["Workout"].tap()
        let gear = app.buttons["openSettings"]
        XCTAssertTrue(gear.waitForExistence(timeout: 15))
        gear.tap()
        XCTAssertTrue(any("settingsAccount").waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 0.8)
    }

    func testCaptureAccountLightDefault() { capture(appearance: "light", large: false) }
    func testCaptureAccountLightAccessibility() { capture(appearance: "light", large: true) }
    func testCaptureAccountDarkDefault() { capture(appearance: "dark", large: false) }
    func testCaptureAccountDarkAccessibility() { capture(appearance: "dark", large: true) }

    private func capture(appearance: String, large: Bool) {
        let suffix = "\(appearance)-\(large ? "axl" : "default")"

        // Settings → Sign In → the sheet.
        launch(appearance: appearance, large: large, flags: ["-uiTestProfileSignedOut"])
        openSettings()
        any("settingsAccount").tap()
        XCTAssertTrue(any("signInWithApple").waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.0)
        shoot("account-signin-sheet-\(suffix)")
        XCTAssertTrue(any("signInWithApple").isHittable, "Apple's button is reachable")
        app.terminate()

        // The same sheet after a failed attempt.
        launch(appearance: appearance, large: large, flags: ["-uiTestProfileSignedOut", "-uiTestSignInFailed"])
        openSettings()
        any("settingsAccount").tap()
        XCTAssertTrue(any("signInFailure").waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.0)
        shoot("account-signin-failed-\(suffix)")
        app.terminate()

        // Profile → Delete Account… → the confirmation → the follow-up.
        launch(appearance: appearance, large: large, flags: ["-uiTestProfileSample"])
        openSettings()
        any("settingsAccount").tap()
        let delete = any("profileDeleteAccount")
        XCTAssertTrue(any("profileAIUse.scan-machine").waitForExistence(timeout: 5))
        var drags = 0
        while !(delete.exists && delete.isHittable && delete.frame.maxY < app.frame.maxY - 90), drags < 10 {
            app.swipeUp()
            drags += 1
        }
        delete.tap()
        let confirm = app.buttons.matching(identifier: "Delete Account").firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8)
        shoot("account-delete-confirm-\(suffix)")
        confirm.tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8)
        shoot("account-delete-done-\(suffix)")
        app.terminate()

        // The welcome page with Sign in with Apple, and after signing in there.
        launch(appearance: appearance, large: large, flags: ["-uiTestOnboarding", "-uiTestOnboardingFresh"], design: false)
        XCTAssertTrue(app.buttons["welcomeTour"].waitForExistence(timeout: 15))
        XCTAssertTrue(any("signInWithApple").waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8)
        shoot("account-welcome-\(suffix)")
        app.terminate()

        launch(appearance: appearance, large: large,
               flags: ["-uiTestOnboarding", "-uiTestOnboardingFresh", "-uiTestWelcomeSignedIn"], design: false)
        XCTAssertTrue(any("welcomeSignedIn").waitForExistence(timeout: 15))
        Thread.sleep(forTimeInterval: 0.8)
        shoot("account-welcome-signedin-\(suffix)")
    }
}
