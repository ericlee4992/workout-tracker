import XCTest

// Floodlight redesign ticket 04: the finish receipt — its record in light and dark at Default
// and AccessibilityL, reached the real way (finish the running fixture workout).
final class FloodlightFinishUITests: XCTestCase {
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

    func testCaptureReceiptLightDefault() { captureReceipt(appearance: "light", large: false) }
    func testCaptureReceiptLightAccessibility() { captureReceipt(appearance: "light", large: true) }
    func testCaptureReceiptDarkDefault() { captureReceipt(appearance: "dark", large: false) }
    func testCaptureReceiptDarkAccessibility() { captureReceipt(appearance: "dark", large: true) }

    private func captureReceipt(appearance: String, large: Bool) {
        app.launchArguments = ["-uiTestReset", "-uiTestDesignSample", "-uiTestDesignLive", "-uiTestHeartRate",
                               "-appearance", appearance]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] }
        app.launch()
        let finish = app.buttons["finishWorkout"]
        XCTAssertTrue(finish.waitForExistence(timeout: 15))
        finish.tap()
        // The fixture's workout drifted from Push Day: keep the template as it is.
        let keep = app.buttons["Keep Original"]
        if keep.waitForExistence(timeout: 3) { keep.tap() }
        XCTAssertTrue(app.buttons["finishedDone"].waitForExistence(timeout: 10), "the receipt opens")
        XCTAssertTrue(any("viewFinishedWorkout").exists)
        let suffix = "\(appearance)-\(large ? "axl" : "default")"
        Thread.sleep(forTimeInterval: 1.5)
        shoot("floodlight-04-finish-\(suffix)-1")
        let exercise = any("summaryExercise")
        for index in 2...6 where !(exercise.exists && exercise.isHittable) {
            app.swipeUp()
            shoot("floodlight-04-finish-\(suffix)-\(index)")
        }
        XCTAssertTrue(exercise.exists, "the exercises are reachable")
    }
}
