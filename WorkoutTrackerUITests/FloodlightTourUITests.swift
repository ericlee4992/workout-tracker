import XCTest

/// Public beta ticket 02 (spec Q8b): the guided tour on record — every step on the design sample (the throwaway
/// UI-test store), light and dark at Default, and dark at AccessibilityL.
final class FloodlightTourUITests: XCTestCase {
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

    private func walk(appearance: String, large: Bool = false) {
        app.launchArguments = ["-uiTestReset", "-uiTestDesignSample", "-uiTestDesignHistory", "-uiTestDesignGyms",
                               "-uiTestDesignExercises", "-tourPrototype", "-appearance", appearance]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] }
        app.launch()
        let size = large ? "AXL" : "default"
        let next = app.buttons["tourNext"]
        for step in 1...8 {
            XCTAssertTrue(next.waitForExistence(timeout: 15), "step \(step) shows Next")
            Thread.sleep(forTimeInterval: 1.0)
            shoot("tour-s\(step)-\(appearance)-\(size)")
            next.tap()
        }
        XCTAssertTrue(next.waitForNonExistence(timeout: 5), "the tour ends after its last step")
    }

    func testTourDark() { walk(appearance: "dark") }
    func testTourLight() { walk(appearance: "light") }
    func testTourLargeText() { walk(appearance: "dark", large: true) }
}
