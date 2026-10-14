import XCTest

// Public beta ticket 04 (UI-first): "Sign in with Google" under Sign in with Apple — the sign-in sheet (from Settings,
// and with a failure line) and the welcome page — on the sample account with `-uiTestGoogleButton`, in light and dark
// at Default and AccessibilityL.
final class FloodlightGoogleUITests: XCTestCase {
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
        app.launchArguments = ["-uiTestReset", "-appearance", appearance, "-uiTestGoogleButton"] + flags
        if design { app.launchArguments += ["-uiTestDesignSample", "-uiTestDesignGyms"] }
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] }
        app.launch()
    }

    private func openSignInSheet() {
        app.tabBars.buttons["Workout"].tap()
        let gear = app.buttons["openSettings"]
        XCTAssertTrue(gear.waitForExistence(timeout: 15))
        gear.tap()
        XCTAssertTrue(any("settingsAccount").waitForExistence(timeout: 10))
        any("settingsAccount").tap()
        XCTAssertTrue(any("signInWithGoogle").waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.0)
    }

    func testCaptureGoogleLightDefault() { capture(appearance: "light", large: false) }
    func testCaptureGoogleLightAccessibility() { capture(appearance: "light", large: true) }
    func testCaptureGoogleDarkDefault() { capture(appearance: "dark", large: false) }
    func testCaptureGoogleDarkAccessibility() { capture(appearance: "dark", large: true) }

    private func capture(appearance: String, large: Bool) {
        let suffix = "\(appearance)-\(large ? "axl" : "default")"

        launch(appearance: appearance, large: large, flags: ["-uiTestProfileSignedOut"])
        openSignInSheet()
        let apple = any("signInWithApple"), google = any("signInWithGoogle")
        XCTAssertTrue(apple.isHittable && google.isHittable, "both buttons reachable")
        XCTAssertLessThan(apple.frame.minY, google.frame.minY, "Apple's first")
        XCTAssertEqual(apple.frame.height, google.frame.height, accuracy: 1, "the same height")
        shoot("google-signin-sheet-\(suffix)")
        app.terminate()

        launch(appearance: appearance, large: large, flags: ["-uiTestProfileSignedOut", "-uiTestSignInFailed"])
        openSignInSheet()
        XCTAssertTrue(any("signInFailure").exists)
        shoot("google-signin-failed-\(suffix)")
        app.terminate()

        launch(appearance: appearance, large: large,
               flags: ["-uiTestOnboarding", "-uiTestOnboardingFresh", "-uiTestProfileSignedOut"], design: false)
        XCTAssertTrue(app.buttons["welcomeTour"].waitForExistence(timeout: 15))
        XCTAssertTrue(any("signInWithGoogle").waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.0)
        shoot("google-welcome-\(suffix)")
        XCTAssertTrue(app.buttons["welcomeSkip"].isHittable, "Skip still reachable")
    }
}
