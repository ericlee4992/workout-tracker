import XCTest

/// Nutrition N7 — Scan Food against the server's fixture (`-uiTestTerra`; the drawn meal and label stand in for the
/// camera): a meal photo's card (D82) becomes ONE entry named for the meal (D83) with its photo, whose items are edited
/// and which is deleted with Undo; a library photo logged at its own time; a label read into the food and logged; a
/// description logged at once; each failure's card; signed out; camera off. Then the captures, light at Default and
/// dark at AccessibilityL.
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

    private func launch(_ appearance: String = "light", large: Bool = false, _ extra: [String] = []) {
        tag = "\(appearance)-\(large ? "axl" : "default")"
        app.launchArguments = ["-uiTestReset", "-uiTestDesignSample", "-uiTestFoodSample", "-uiTestTerra",
                               "-appearance", appearance] + extra
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

    private var card: XCUIElement { app.descendants(matching: .any)["scanPending"] }

    private func openCamera() {
        app.buttons["scanFoodButton"].tap()
        XCTAssertTrue(app.buttons["scanFoodShutter"].waitForExistence(timeout: 5))
    }

    // MARK: Behaviour

    func testAMealPhotoIsLoggedAsOneEntryAndItsItemsEdit() {
        launch()
        openCamera()
        app.buttons["scanFoodShutter"].tap()
        // The camera closes at once and the card counts up on Today.
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        let entry = app.buttons["todayEntry.Poke bowl"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10), "the estimate is logged as one entry named for the meal")
        XCTAssertFalse(card.exists)
        reveal(entry)
        XCTAssertTrue(entry.label.contains("550 cal"), entry.label)

        // The items screen: remove an item, save — the entry's total follows.
        entry.tap()
        XCTAssertTrue(app.buttons["scanEntrySave"].waitForExistence(timeout: 5))
        let mango = app.buttons["scanItem.Mango"]
        if !mango.isHittable { app.swipeUp() }
        mango.tap()
        XCTAssertTrue(app.buttons["scanItemRemove"].waitForExistence(timeout: 5))
        app.buttons["scanItemRemove"].tap()
        XCTAssertFalse(app.buttons["scanItem.Mango"].waitForExistence(timeout: 2))
        app.buttons["scanEntrySave"].tap()
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
        XCTAssertTrue(entry.label.contains("500 cal"), entry.label)

        // Delete with Undo: it comes back with its items.
        entry.tap()
        XCTAssertTrue(app.buttons["scanEntryDelete"].waitForExistence(timeout: 5))
        app.swipeUp()
        app.buttons["scanEntryDelete"].tap()
        XCTAssertTrue(app.buttons["todayUndoDelete"].waitForExistence(timeout: 5))
        app.buttons["todayUndoDelete"].tap()
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
        reveal(entry)
        entry.tap()
        XCTAssertTrue(app.buttons["scanItem.Tuna poke"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["scanItem.Mango"].exists)
    }

    func testALibraryPhotoIsLoggedWhenItWasTaken() {
        launch()
        openCamera()
        app.buttons["scanFoodLibrary"].tap()
        let entry = app.buttons["todayEntry.Poke bowl"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        reveal(entry)
        // The fixture's picked photo was taken at 12:40 (or now, if that is still ahead).
        let hour = Calendar.current.component(.hour, from: .now)
        let minute = Calendar.current.component(.minute, from: .now)
        if hour * 60 + minute >= 12 * 60 + 40 {
            XCTAssertTrue(entry.label.contains("12:40"), entry.label)
            XCTAssertTrue(app.descendants(matching: .any)["todayMeal.lunch"].exists)
        }
    }

    func testALabelIsReadIntoTheFoodAndLogged() {
        launch()
        openCamera()
        app.buttons["scanFoodMode.label"].tap()
        app.buttons["scanFoodShutter"].tap()
        let log = app.buttons["labelFoodLog"]
        XCTAssertTrue(log.waitForExistence(timeout: 10))
        XCTAssertFalse(log.isEnabled, "a label has no name: the user's")
        let name = app.textFields["labelFoodName"]
        name.tap()
        name.typeText("Maple granola")
        app.buttons["labelFoodLog"].tap()
        let entry = app.buttons["todayEntry.Maple granola"]
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
        // Save to My foods was on: it is one of My foods now.
        app.buttons["logFoodPill"].tap()
        app.buttons["logFoodTab.My foods"].firstMatch.tap()
        XCTAssertTrue(app.buttons["logFoodRow.Maple granola"].waitForExistence(timeout: 5))
    }

    func testADescriptionIsLoggedAtOnce() {
        launch()
        app.buttons["logFoodPill"].tap()
        let search = app.textFields["logFoodSearch"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("2 eggs and toast")
        app.buttons["logFoodDescribe"].tap()
        XCTAssertTrue(app.buttons["todayEntry.Eggs and toast"].waitForExistence(timeout: 10))
    }

    func testEachFailureKeepsItsCard() {
        for (flag, expected, action) in [("nothing", "No food found", "scanManualAdd"),
                                         ("limit", "Daily limit reached", "scanManualAdd"),
                                         ("offline", "Couldn't analyze", "scanTryAgain")] {
            launch("light", large: false, ["-uiTestFoodScanFail", flag])
            openCamera()
            app.buttons["scanFoodShutter"].tap()
            let title = app.staticTexts["scanFailedTitle"]
            XCTAssertTrue(title.waitForExistence(timeout: 10), flag)
            XCTAssertEqual(title.label, expected, flag)
            XCTAssertTrue(app.buttons[action].exists, flag)
            XCTAssertFalse(app.buttons["todayEntry.Poke bowl"].exists, flag)
        }
        // Remove takes the card away.
        app.buttons["scanPendingRemove"].tap()
        XCTAssertFalse(card.waitForExistence(timeout: 2))
    }

    // MARK: Captures

    func testCaptureLightDefault() { capture("light", large: false) }
    func testCaptureDarkAccessibility() { capture("dark", large: true) }

    private func capture(_ appearance: String, large: Bool) {
        // 1. Today's buttons, the camera's three modes.
        launch(appearance, large: large, ["-uiTestFoodScanHold"])
        shoot("today-buttons")
        openCamera()
        shoot("camera-meal")
        app.buttons["scanFoodMode.barcode"].tap()
        shoot("camera-barcode")
        app.buttons["scanFoodMode.label"].tap()
        shoot("camera-label")

        // 2. A meal photo: the card, held.
        app.buttons["scanFoodMode.meal"].tap()
        app.buttons["scanFoodShutter"].tap()
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        reveal(card)
        shoot("today-card")

        // 3. Logged: the entry with its photo, its items screen and an item.
        launch(appearance, large: large)
        openCamera()
        app.buttons["scanFoodShutter"].tap()
        let entry = app.buttons["todayEntry.Poke bowl"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        reveal(entry)
        shoot("today-logged")
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

        // 4. A label: reading (held), then the food.
        launch(appearance, large: large, ["-uiTestFoodScanHold"])
        openCamera()
        app.buttons["scanFoodMode.label"].tap()
        app.buttons["scanFoodShutter"].tap()
        XCTAssertTrue(app.buttons["scanFoodRetake"].waitForExistence(timeout: 5))
        shoot("label-reading")
        launch(appearance, large: large)
        openCamera()
        app.buttons["scanFoodMode.label"].tap()
        app.buttons["scanFoodShutter"].tap()
        XCTAssertTrue(app.buttons["labelFoodLog"].waitForExistence(timeout: 10))
        shoot("label-food")
        app.swipeUp()
        shoot("label-food-2")

        // 5. The failures.
        for flag in ["nothing", "limit", "offline"] {
            launch(appearance, large: large, ["-uiTestFoodScanFail", flag])
            openCamera()
            app.buttons["scanFoodShutter"].tap()
            XCTAssertTrue(app.staticTexts["scanFailedTitle"].waitForExistence(timeout: 10))
            reveal(card)
            shoot("today-failed-\(flag)")
        }
        launch(appearance, large: large, ["-uiTestFoodScanFail", "nothing"])
        openCamera()
        app.buttons["scanFoodMode.label"].tap()
        app.buttons["scanFoodShutter"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["scanFoodLabelFailure"].waitForExistence(timeout: 10))
        shoot("label-not-found")

        // 6. Signed out; camera off.
        launch(appearance, large: large, ["-uiTestProfileSignedOut"])
        app.buttons["scanFoodButton"].tap()
        XCTAssertTrue(app.buttons["scanFoodSignIn"].waitForExistence(timeout: 5))
        shoot("signed-out")
        launch(appearance, large: large, ["-uiTestFoodScanNoCamera"])
        app.buttons["scanFoodButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["scanFoodCameraOff"].waitForExistence(timeout: 5))
        shoot("camera-off")

        // 7. Log food: the estimate row, then its card on Today (held).
        launch(appearance, large: large, ["-uiTestFoodScanHold"])
        app.buttons["logFoodPill"].tap()
        let search = app.textFields["logFoodSearch"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("2 eggs and toast")
        XCTAssertTrue(app.buttons["logFoodDescribe"].waitForExistence(timeout: 5))
        shoot("describe")
        app.buttons["logFoodDescribe"].tap()
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        reveal(card)
        shoot("today-describe-card")
    }
}
