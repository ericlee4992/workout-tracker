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

    // Codex review 04b: a bar-mode new best (102.5 lb × 10 on a 45 lb bar) at every size.
    func testCaptureBarBestLightDefault() { captureReceipt(appearance: "light", large: false, barBest: true) }
    func testCaptureBarBestLightAccessibility() { captureReceipt(appearance: "light", large: true, barBest: true) }
    func testCaptureBarBestDarkDefault() { captureReceipt(appearance: "dark", large: false, barBest: true) }
    func testCaptureBarBestDarkAccessibility() { captureReceipt(appearance: "dark", large: true, barBest: true) }

    private func captureReceipt(appearance: String, large: Bool, barBest: Bool = false) {
        app.launchArguments = ["-uiTestReset", "-uiTestDesignSample", "-uiTestDesignLive", "-uiTestHeartRate",
                               "-appearance", appearance] + (barBest ? ["-uiTestDesignBarBest"] : [])
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
        // Codex review 04: one line per scope, spoken with its machine / bar (the scope).
        let bests = app.descendants(matching: .any).matching(identifier: "finishNewBest")
        let best = bests.firstMatch
        for _ in 0..<3 where !best.exists { app.swipeUp() }
        XCTAssertEqual(bests.count, barBest ? 2 : 1)
        XCTAssertTrue(bests.element(boundBy: 0).label.contains("Seated Chest Press, Chest Press 2, 110 lb × 8"), bests.element(boundBy: 0).label)
        XCTAssertTrue(bests.element(boundBy: 0).label.contains("previous best 45 lb × 8"))
        if barBest {
            let bench = bests.element(boundBy: 1)
            for _ in 0..<3 where !bench.isHittable { app.swipeUp() }
            XCTAssertTrue(bench.label.contains("Bench Press"), bench.label)
            XCTAssertTrue(bench.label.contains("102.5 lb × 10 (45 lb bar)"), bench.label)
            XCTAssertTrue(bench.label.contains("previous best 90 lb × 10 (45 lb bar)"), bench.label)
            let window = app.windows.firstMatch.frame
            XCTAssertLessThanOrEqual(bench.frame.maxX, window.maxX, "the bar-mode best stays on screen")
            // Hittable can mean its first line only: bring the whole row, bar line included, up.
            if bench.frame.maxY > window.maxY - 160 { app.swipeUp() }
            shoot("floodlight-04-barbest-\(appearance)-\(large ? "axl" : "default")")
            return
        }
        for _ in 0..<4 where !any("viewFinishedWorkout").isHittable { app.swipeDown() }
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
