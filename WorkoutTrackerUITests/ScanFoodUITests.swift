import XCTest

/// Nutrition N7 MOCK — Scan Food on record before it is wired (the user, 2026-11-10: mocks first): Today's progress
/// card (D82) and the logged photo entry as one entry or one per item, the failures, the camera's three modes, consent,
/// sign in, camera off, reading a label and the prefilled food, the entry's items and an item, and Log food's estimate
/// row — light at Default and dark at AccessibilityL. Sample data in memory only (`-scanFoodMock`).
final class ScanFoodUITests: XCTestCase {
    private var app: XCUIApplication!
    private var tag = ""

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func shoot(_ name: String) {
        Thread.sleep(forTimeInterval: 0.8)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "n7-\(name)-\(tag)"
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func launch(_ appearance: String, large: Bool, _ extra: [String] = []) {
        tag = "\(appearance)-\(large ? "axl" : "default")"
        app.launchArguments = ["-uiTestReset", "-uiTestDesignSample", "-uiTestFoodSample", "-appearance", appearance,
                               "-scanFoodMock"] + extra
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] }
        app.launch()
        XCTAssertTrue(app.buttons["logFoodPill"].waitForExistence(timeout: 15))
    }

    /// Scrolls Today until the element is on screen.
    private func reveal(_ element: XCUIElement, maxSwipes: Int = 8) {
        var swipes = 0
        while !(element.exists && element.isHittable) && swipes < maxSwipes {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(element.exists, "not found: \(element)")
    }

    func testCaptureLightDefault() { capture("light", large: false) }
    func testCaptureDarkAccessibility() { capture("dark", large: true) }

    private func capture(_ appearance: String, large: Bool) {
        // 1. Today: the progress card at 9 % over a logged photo (option A, one entry).
        launch(appearance, large: large, ["-scanFoodMockSample", "analyzing"])
        let card = app.descendants(matching: .any)["scanPending"]
        reveal(card)
        shoot("today-analyzing")
        app.swipeUp()
        shoot("today-analyzing-2")

        // 2. The entry's items screen, then one item.
        let entry = app.buttons["scanEntry.Poke bowl"]
        reveal(entry)
        entry.tap()
        XCTAssertTrue(app.buttons["scanEntrySave"].waitForExistence(timeout: 5))
        shoot("entry")
        app.swipeUp()
        shoot("entry-2")
        let item = app.buttons["scanItem.Tuna poke"]
        if !item.isHittable { app.swipeDown() }
        item.tap()
        XCTAssertTrue(app.buttons["scanItemRemove"].waitForExistence(timeout: 5))
        shoot("item")

        // 3. Option B: one entry per item under the photo.
        launch(appearance, large: large, ["-scanFoodMockSample", "done", "-scanFoodMockGrouping", "perItem"])
        let group = app.buttons["scanPhotoGroup"]
        reveal(group)
        shoot("today-per-item")
        app.swipeUp()
        shoot("today-per-item-2")

        // 4. The failures on Today.
        launch(appearance, large: large, ["-scanFoodMockSample", "failures"])
        reveal(app.descendants(matching: .any)["scanFailed.nothingFound"])
        shoot("today-failures")
        app.swipeUp()
        shoot("today-failures-2")

        // 5. The camera's three modes (from Today's camera button).
        launch(appearance, large: large, ["-scanFoodMockSample", "none", "-scanFoodMockSlow"])
        shoot("today-buttons")
        app.buttons["scanFoodButton"].tap()
        XCTAssertTrue(app.buttons["scanFoodShutter"].waitForExistence(timeout: 5))
        shoot("camera-meal")
        app.buttons["scanFoodMode.barcode"].tap()
        shoot("camera-barcode")
        app.buttons["scanFoodMode.label"].tap()
        shoot("camera-label")

        // 6. A meal photo: the camera closes, the card counts up on Today, then becomes the entry.
        app.buttons["scanFoodMode.meal"].tap()
        app.buttons["scanFoodShutter"].tap()
        let live = app.descendants(matching: .any)["scanPending"]
        XCTAssertTrue(live.waitForExistence(timeout: 5))
        reveal(live)
        shoot("today-live-card")
        XCTAssertTrue(app.buttons["scanEntry.Poke bowl"].waitForExistence(timeout: 25))
        shoot("today-live-logged")

        // 7. A label: read, then the food prefilled (named, as if typed).
        launch(appearance, large: large, ["-scanFoodMockSample", "none", "-scanFoodMockMode", "label",
                                          "-scanFoodMockHoldLabel"])
        app.buttons["scanFoodButton"].tap()
        XCTAssertTrue(app.buttons["scanFoodShutter"].waitForExistence(timeout: 5))
        app.buttons["scanFoodShutter"].tap()
        XCTAssertTrue(app.buttons["scanFoodRetake"].waitForExistence(timeout: 5))
        shoot("label-reading")
        launch(appearance, large: large, ["-scanFoodMockSample", "none", "-scanFoodMockMode", "label",
                                          "-scanFoodMockNamed"])
        app.buttons["scanFoodButton"].tap()
        XCTAssertTrue(app.buttons["scanFoodShutter"].waitForExistence(timeout: 5))
        app.buttons["scanFoodShutter"].tap()
        XCTAssertTrue(app.buttons["labelFoodLog"].waitForExistence(timeout: 8))
        shoot("label-food")
        app.swipeUp()
        shoot("label-food-2")

        // 8. First scan: consent; signed out; camera off.
        launch(appearance, large: large, ["-scanFoodMockSample", "none", "-scanFoodMockConsent"])
        app.buttons["scanFoodButton"].tap()
        XCTAssertTrue(app.buttons["scanFoodAllow"].waitForExistence(timeout: 5))
        shoot("consent")
        launch(appearance, large: large, ["-scanFoodMockSample", "none", "-scanFoodMockSignedOut"])
        app.buttons["scanFoodButton"].tap()
        XCTAssertTrue(app.buttons["scanFoodSignIn"].waitForExistence(timeout: 5))
        shoot("signed-out")
        launch(appearance, large: large, ["-scanFoodMockSample", "none", "-scanFoodMockNoCamera"])
        app.buttons["scanFoodButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["scanFoodCameraOff"].waitForExistence(timeout: 5))
        shoot("camera-off")

        // 9. Log food: the estimate row for what was typed, and the camera in the bar.
        launch(appearance, large: large, ["-scanFoodMockSample", "none", "-scanFoodMockSlow"])
        app.buttons["logFoodPill"].tap()
        let search = app.textFields["logFoodSearch"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("2 eggs and toast")
        XCTAssertTrue(app.buttons["logFoodDescribe"].waitForExistence(timeout: 5))
        shoot("describe")
        app.buttons["logFoodDescribe"].tap()
        let describing = app.descendants(matching: .any)["scanPending"]
        XCTAssertTrue(describing.waitForExistence(timeout: 5))
        reveal(describing)
        shoot("today-describe-card")
    }
}
