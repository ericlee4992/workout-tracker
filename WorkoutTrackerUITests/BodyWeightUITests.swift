import XCTest

/// Nutrition N9a: Profile → Body weight — log a weight with the ± steps, see it as the latest, change it, delete it;
/// the Recalculate offer when the goal's weight is more than 2 kg away. Captures in light at Default and dark at
/// AccessibilityL.
final class BodyWeightUITests: XCTestCase {
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

    private func openBodyWeight(appearance: String = "light", large: Bool = false) {
        app.launchArguments = ["-uiTestReset", "-uiTestDesignSample", "-uiTestPersonalDetails", "-appearance", appearance]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] }
        app.launch()
        let profile = app.tabBars.buttons["Profile"].exists ? app.tabBars.buttons["Profile"] : app.buttons["Profile"]
        XCTAssertTrue(profile.waitForExistence(timeout: 15))
        profile.tap()
        let row = app.buttons["profileBodyWeight"]
        for _ in 0..<6 { guard !(row.exists && row.isHittable) else { break }; app.swipeUp() }
        row.tap()
        XCTAssertTrue(app.buttons["bodyWeightLog"].waitForExistence(timeout: 5))
    }

    func testLogChangeAndDeleteAWeight() {
        openBodyWeight()
        // The fixture's 176.4 lb (Personal details) is the latest.
        XCTAssertTrue(app.descendants(matching: .any)["bodyWeightLatest"].label.contains("176.4"))
        app.buttons["bodyWeightLog"].tap()
        XCTAssertTrue(app.buttons["logWeightSave"].waitForExistence(timeout: 5))
        app.buttons["Less"].tap()
        app.buttons["Less"].tap()
        XCTAssertEqual(app.textFields["logWeightValue"].value as? String, "176")
        app.buttons["logWeightSave"].tap()
        XCTAssertTrue(app.buttons["logWeightSave"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["bodyWeightLatest"].label.contains("176"))
        XCTAssertFalse(app.buttons["bodyWeightRecalculate"].exists, "0.4 lb is not 2 kg")

        let entry = app.buttons["bodyWeightEntry.176 lb"]
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
        entry.tap()
        let field = app.textFields["logWeightValue"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        // Tap at the end of the figure so the deletes clear it (a plain tap left the cursor at the start).
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8) + "170")
        XCTAssertEqual(field.value as? String, "170")
        app.buttons["logWeightSave"].tap()
        XCTAssertTrue(app.buttons["bodyWeightEntry.170 lb"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["bodyWeightRecalculate"].waitForExistence(timeout: 5), "6.4 lb (2.9 kg) away")

        app.buttons["bodyWeightEntry.170 lb"].tap()
        let delete = app.buttons["logWeightDelete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        for _ in 0..<4 { guard !delete.isHittable else { break }; app.swipeUp() }
        delete.tap()
        XCTAssertTrue(app.buttons["bodyWeightEntry.170 lb"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["bodyWeightLatest"].label.contains("176.4"))
    }

    func testCaptureLightDefault() { capture(appearance: "light", large: false) }
    func testCaptureDarkAccessibility() { capture(appearance: "dark", large: true) }

    private func capture(appearance: String, large: Bool) {
        let tag = "\(appearance)-\(large ? "axl" : "default")"
        openBodyWeight(appearance: appearance, large: large)
        shoot("n9-bodyweight-\(tag)")
        app.buttons["bodyWeightLog"].tap()
        XCTAssertTrue(app.buttons["logWeightSave"].waitForExistence(timeout: 5))
        shoot("n9-logweight-\(tag)")
    }
}
