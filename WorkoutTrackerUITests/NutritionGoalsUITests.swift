import XCTest

/// Nutrition N3: Profile → Nutrition goals and Profile → Personal details, on record in light and dark at Default and
/// AccessibilityL (the mock captures shown to the user first).
final class NutritionGoalsUITests: XCTestCase {
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

    func testCaptureLightDefault() { capture(appearance: "light", large: false) }
    func testCaptureDarkDefault() { capture(appearance: "dark", large: false) }
    func testCaptureLightAccessibility() { capture(appearance: "light", large: true) }
    func testCaptureDarkAccessibility() { capture(appearance: "dark", large: true) }

    private func capture(appearance: String, large: Bool) {
        app.launchArguments = ["-uiTestReset", "-uiTestDesignSample", "-appearance", appearance]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] }
        app.launch()
        let tag = "\(appearance)-\(large ? "axl" : "default")"
        app.openProfile()
        let goals = app.buttons["profileNutritionGoals"]
        XCTAssertTrue(goals.waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 0.8)
        shoot("n3-profile-\(tag)")
        goals.tap()
        XCTAssertTrue(app.descendants(matching: .any)["nutritionGoalsCalories"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8)
        shoot("n3-goals-\(tag)-1")
        if large { app.swipeUp(); Thread.sleep(forTimeInterval: 0.6); shoot("n3-goals-\(tag)-2") }
        app.openProfile()  // the selected tab again: back to the root
        let details = app.buttons["profilePersonalDetails"]
        XCTAssertTrue(details.waitForExistence(timeout: 5))
        for _ in 0..<4 where !details.isHittable { app.swipeUp() }
        details.tap()
        Thread.sleep(forTimeInterval: 0.8)
        shoot("n3-details-\(tag)")
    }
}
