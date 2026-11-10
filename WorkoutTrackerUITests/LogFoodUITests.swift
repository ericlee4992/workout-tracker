import XCTest

/// Nutrition N4: Log Food in the user's structure (D81) — Today's pill → All (recent foods with a one-tap + and Undo,
/// Manual Add), My foods (Add food, two steps), My meals, Saved foods, a selected food with its bookmark, Manual Add —
/// on record in light at Default and dark at AccessibilityL, plus the empty My foods / Saved foods.
final class LogFoodUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func shoot(_ name: String) {
        Thread.sleep(forTimeInterval: 0.7)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func back() { app.navigationBars.buttons.element(boundBy: 0).tap() }

    private func tab(_ title: String) { app.buttons["logFoodTab.\(title)"].firstMatch.tap() }

    /// At AccessibilityL the bottom command scrolls with the list: one more shot, scrolled, so it is on record.
    private func shootScrolled(_ name: String, large: Bool) {
        shoot(name)
        guard large else { return }
        app.swipeUp()
        shoot("\(name)-2")
        app.swipeDown()
        app.swipeDown()
    }

    private func launch(appearance: String, large: Bool, extra: [String] = []) {
        app.launchArguments = ["-uiTestReset", "-uiTestDesignSample", "-appearance", appearance] + extra
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] }
        app.launch()
    }

    func testCaptureLightDefault() { capture(appearance: "light", large: false) }
    func testCaptureDarkAccessibility() { capture(appearance: "dark", large: true) }
    func testCaptureEmptyLightDefault() { captureEmpty(appearance: "light", large: false) }
    func testCaptureEmptyDarkAccessibility() { captureEmpty(appearance: "dark", large: true) }

    private func capture(appearance: String, large: Bool) {
        let tag = "\(appearance)-\(large ? "axl" : "default")"
        launch(appearance: appearance, large: large)
        let pill = app.buttons["logFoodPill"]
        XCTAssertTrue(pill.waitForExistence(timeout: 15))
        shoot("n4-today-\(tag)")
        pill.tap()

        // All: recently logged, + and Undo, Manual Add.
        let add = app.buttons["logFoodAdd.Greek yogurt"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        shootScrolled("n4-all-\(tag)", large: large)
        add.tap()
        XCTAssertTrue(app.buttons["logFoodUndo"].waitForExistence(timeout: 5))
        shoot("n4-all-added-\(tag)")
        app.buttons["logFoodUndo"].tap()

        // Manual Add (name optional; Quick Add merged).
        if large { app.swipeUp() }
        app.buttons["logFoodManualAdd"].tap()
        XCTAssertTrue(app.buttons["manualAddLog"].waitForExistence(timeout: 5))
        shootScrolled("n4-manual-\(tag)", large: large)
        back()

        // My foods and Add food's two steps.
        if large { app.swipeDown() }
        tab("My foods")
        XCTAssertTrue(app.buttons["logFoodRow.Turkey chili"].waitForExistence(timeout: 5))
        shootScrolled("n4-myfoods-\(tag)", large: large)
        if large { app.swipeUp() }
        app.buttons["logFoodAddFood"].tap()
        XCTAssertTrue(app.buttons["addFoodNext"].waitForExistence(timeout: 5))
        shoot("n4-addfood-1-\(tag)")
        app.buttons["addFoodNext"].tap()
        XCTAssertTrue(app.buttons["addFoodSave"].waitForExistence(timeout: 5))
        shootScrolled("n4-addfood-2-\(tag)", large: large)
        back()
        back()
        if large { app.swipeDown() }

        // One of My foods: Edit and the bookmark.
        app.buttons["logFoodRow.Turkey chili"].tap()
        XCTAssertTrue(app.buttons["selectedFoodLog"].waitForExistence(timeout: 5))
        shoot("n4-selected-\(tag)")
        app.buttons["selectedFoodSave"].tap()
        shoot("n4-selected-saved-\(tag)")
        back()

        tab("My meals")
        shootScrolled("n4-mymeals-\(tag)", large: large)

        // Create meal: empty, then two foods added (one twice: a second serving).
        if large { app.swipeUp() }
        app.buttons["logFoodCreateMeal"].tap()
        XCTAssertTrue(app.buttons["createMealSave"].waitForExistence(timeout: 5))
        shoot("n4-createmeal-\(tag)")
        app.buttons["createMealAdd.Overnight oats"].tap()
        app.buttons["createMealAdd.Banana"].firstMatch.tap()
        app.buttons["createMealAdd.Banana"].firstMatch.tap()
        shootScrolled("n4-createmeal-filled-\(tag)", large: large)
        back()
        if large { app.swipeDown() }
        tab("Saved foods")
        XCTAssertTrue(app.buttons["logFoodRow.Overnight oats"].waitForExistence(timeout: 5))
        shoot("n4-saved-\(tag)")
    }

    private func captureEmpty(appearance: String, large: Bool) {
        let tag = "\(appearance)-\(large ? "axl" : "default")"
        launch(appearance: appearance, large: large, extra: ["-logFoodMockEmpty"])
        let pill = app.buttons["logFoodPill"]
        XCTAssertTrue(pill.waitForExistence(timeout: 15))
        pill.tap()
        XCTAssertTrue(app.buttons["logFoodTab.My foods"].waitForExistence(timeout: 5))
        tab("My foods")
        shootScrolled("n4-myfoods-empty-\(tag)", large: large)
        tab("Saved foods")
        shootScrolled("n4-saved-empty-\(tag)", large: large)
        tab("My meals")
        shootScrolled("n4-mymeals-empty-\(tag)", large: large)
    }
}
