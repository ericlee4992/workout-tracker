import XCTest

/// Nutrition N4: Log Food (Today's pill → recent foods with a one-tap + and Undo, My meals, a selected food, Manual
/// Add, Quick Add) on record in light at Default and dark at AccessibilityL.
final class LogFoodUITests: XCTestCase {
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

    private func back() { app.navigationBars.buttons.element(boundBy: 0).tap() }

    func testCaptureLightDefault() { capture(appearance: "light", large: false) }
    func testCaptureDarkAccessibility() { capture(appearance: "dark", large: true) }

    private func capture(appearance: String, large: Bool) {
        let tag = "\(appearance)-\(large ? "axl" : "default")"
        app.launchArguments = ["-uiTestReset", "-uiTestDesignSample", "-appearance", appearance]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] }
        app.launch()
        let pill = app.buttons["logFoodPill"]
        XCTAssertTrue(pill.waitForExistence(timeout: 15))
        Thread.sleep(forTimeInterval: 0.8)
        shoot("n4-today-\(tag)")
        pill.tap()
        let add = app.buttons["logFoodAdd.Greek yogurt"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.6)
        shoot("n4-logfood-\(tag)-1")
        add.tap()
        XCTAssertTrue(app.buttons["logFoodUndo"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.6)
        shoot("n4-logfood-added-\(tag)")
        app.buttons["logFoodUndo"].tap()
        if large { app.swipeUp(); Thread.sleep(forTimeInterval: 0.6); shoot("n4-logfood-\(tag)-2"); app.swipeDown() }
        app.buttons["My meals"].firstMatch.tap()
        Thread.sleep(forTimeInterval: 0.6)
        shoot("n4-mymeals-\(tag)")
        app.buttons["All"].firstMatch.tap()

        app.buttons["logFoodRow.Greek yogurt"].tap()
        XCTAssertTrue(app.buttons["selectedFoodLog"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.6)
        shoot("n4-selected-\(tag)")
        back()

        app.buttons["logFoodManualAdd"].tap()
        Thread.sleep(forTimeInterval: 0.8)
        shoot("n4-manual-\(tag)")
        back()
        app.buttons["logFoodQuickAdd"].tap()
        Thread.sleep(forTimeInterval: 0.8)
        shoot("n4-quick-\(tag)")
    }
}
