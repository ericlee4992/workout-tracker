import XCTest

/// Nutrition N8 (D72) against the food databases' fixture (`-uiTestTerra`; the drawn barcode stands in for the camera
/// and is "read" a moment after Barcode mode shows it): a found product opens credited to its source and logs, and then
/// opens at once with no connection; not found offers the label scan and Manual Add; offline offers Try again and
/// Manual Add; Log food's search shows the user's foods, then online foods, credited, with other servings by weight.
/// Then the captures, light at Default and dark at AccessibilityL.
final class BarcodeSearchUITests: XCTestCase {
    private var app: XCUIApplication!
    private var tag = ""

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func shoot(_ name: String) {
        Thread.sleep(forTimeInterval: 0.8)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "n8-\(name)-\(tag)"
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

    private func scanBarcode() {
        app.buttons["scanFoodButton"].tap()
        let mode = app.buttons["scanFoodMode.barcode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 5))
        mode.tap()
    }

    private func openLogFood() -> XCUIElement {
        let pill = app.buttons["logFoodPill"]
        pill.tap()
        let search = app.textFields["logFoodSearch"]
        if !search.waitForExistence(timeout: 5) { pill.tap() }
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        return search
    }

    private var foodLog: XCUIElement { app.buttons["selectedFoodLog"] }

    // MARK: Barcodes

    func testAFoundBarcodeIsCreditedLoggedAndThenOpensOffline() {
        launch("light", large: false, ["-uiTestFoodDatabaseOfflineAfterOne"])
        scanBarcode()
        XCTAssertTrue(foodLog.waitForExistence(timeout: 10), "the found food opens to log")
        XCTAssertTrue(app.staticTexts["Hazelnut spread"].exists)
        let credit = app.staticTexts["selectedFoodAttribution"]
        if !credit.isHittable { app.swipeUp() }
        XCTAssertEqual(credit.label, "Food data from Open Food Facts")
        foodLog.tap()
        XCTAssertTrue(app.buttons["todayEntry.Hazelnut spread"].waitForExistence(timeout: 5))

        // The connection is gone now; the same code opens at once from the phone, no lookup screen.
        scanBarcode()
        XCTAssertTrue(foodLog.waitForExistence(timeout: 6))
        XCTAssertFalse(app.descendants(matching: .any)["scanFoodBarcodeFailure"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["scanFoodMode.barcode"].waitForExistence(timeout: 5), "back at the camera")
        XCTAssertFalse(foodLog.waitForExistence(timeout: 2), "the code just left is not read again at once")
        app.buttons["scanFoodCancel"].tap()

        // And it is in Recently logged, still credited there (codex-review-n8 S6).
        _ = openLogFood()
        XCTAssertTrue(app.buttons["logFoodRow.Hazelnut spread"].waitForExistence(timeout: 5))
        let credits = app.staticTexts["logFoodCredits"]
        if !credits.isHittable { app.swipeUp() }
        XCTAssertTrue(credits.waitForExistence(timeout: 5))
        XCTAssertTrue(credits.label.contains("Food data from Open Food Facts"), credits.label)
    }

    func testABarcodeNotFoundOffersTheLabelScanAndManualAdd() {
        launch("light", large: false, ["-uiTestBarcodeNotFound"])
        scanBarcode()
        let notFound = app.descendants(matching: .any)["scanFoodBarcodeNotFound"]
        XCTAssertTrue(notFound.waitForExistence(timeout: 10))
        XCTAssertTrue(notFound.label.contains("Not in the database"), notFound.label)
        XCTAssertEqual(app.staticTexts["scanFoodBarcodeCode"].label, "Barcode 3017620422003")
        app.buttons["scanFoodBarcodeLabel"].tap()
        XCTAssertTrue(app.buttons["scanFoodShutter"].waitForExistence(timeout: 5), "the camera, in Food label mode")
        XCTAssertTrue(app.buttons["scanFoodMode.label"].isSelected)
        XCTAssertEqual(app.staticTexts["scanFoodHint"].label, "Fit the Nutrition Facts in the box")

        // Manual Add from not found.
        app.buttons["scanFoodMode.barcode"].tap()
        XCTAssertTrue(notFound.waitForExistence(timeout: 10))
        app.buttons["scanFoodManual"].tap()
        XCTAssertTrue(app.buttons["manualAddLog"].waitForExistence(timeout: 5))
    }

    func testOfflineOffersTryAgainAndManualAdd() {
        launch("light", large: false, ["-uiTestTerraOffline"])
        scanBarcode()
        let failure = app.descendants(matching: .any)["scanFoodBarcodeFailure"]
        XCTAssertTrue(failure.waitForExistence(timeout: 10))
        XCTAssertTrue(failure.label.contains("No connection"), failure.label)
        app.buttons["scanFoodBarcodeRetry"].tap()
        XCTAssertTrue(failure.waitForExistence(timeout: 10), "still offline: still the failure")
        app.buttons["scanFoodManual"].tap()
        XCTAssertTrue(app.buttons["manualAddLog"].waitForExistence(timeout: 5))
    }

    // MARK: Search

    func testSearchShowsMyFoodsThenOnlineFoodsWithOtherServings() {
        launch()
        let search = openLogFood()
        search.tap()
        search.typeText("banana")
        let raw = app.buttons["logFoodOnlineRow.Bananas, raw"]
        XCTAssertTrue(raw.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["logFoodDescribe"].exists, "anything else: Estimate")
        XCTAssertEqual(app.staticTexts["logFoodOnlineAttribution"].label, "Food data from USDA FoodData Central")

        // + logs one serving with Undo, and the food is the user's now (Your foods), not an online row.
        app.buttons["logFoodOnlineAdd.Banana chips"].tap()
        XCTAssertTrue(app.staticTexts["logFoodToast"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["logFoodRow.Banana chips"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["logFoodOnlineRow.Banana chips"].exists)

        // A row opens the food: its other servings by weight, credited.
        raw.tap()
        XCTAssertTrue(foodLog.waitForExistence(timeout: 5))
        let serving = app.buttons["selectedFoodServing"]
        XCTAssertTrue(serving.waitForExistence(timeout: 5))
        XCTAssertTrue(serving.label.contains("1 medium"), serving.label)
        serving.tap()
        let cup = app.buttons["1 cup, sliced (150 g)"]
        XCTAssertTrue(cup.waitForExistence(timeout: 5))
        cup.tap()
        XCTAssertTrue(serving.label.contains("1 cup, sliced"), serving.label)
        foodLog.tap()
        XCTAssertTrue(app.staticTexts["logFoodToast"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        // 89 kcal per 100 g → 133.5 for 150 g: Today rounds it.
        let entry = app.buttons["todayEntry.Bananas, raw"]
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
        XCTAssertTrue(entry.label.contains("134 cal") || entry.label.contains("133 cal"), entry.label)
    }

    /// codex-review-n8 T1: an online row that stays (the query is not the name as a whole) shows its check after +,
    /// after the toast too, and Undo clears it.
    func testAnOnlineRowShowsItsCheckUntilUndo() {
        launch()
        let search = openLogFood()
        search.tap()
        search.typeText("banana raw")
        let add = app.buttons["logFoodOnlineAdd.Bananas, raw"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        XCTAssertEqual(add.value as? String ?? "", "")
        add.tap()
        XCTAssertTrue(app.staticTexts["logFoodToast"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["logFoodRow.Bananas, raw"].exists, "\"banana raw\" is not in its name: it stays online")
        XCTAssertEqual(add.value as? String, "Logged")
        app.buttons["logFoodUndo"].tap()
        XCTAssertFalse(app.staticTexts["logFoodToast"].waitForExistence(timeout: 2))
        XCTAssertEqual(add.value as? String ?? "", "")
        add.tap()
        XCTAssertTrue(app.staticTexts["logFoodToast"].waitForExistence(timeout: 5))
        // The toast leaves after 5 s; the check stays.
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: app.staticTexts["logFoodToast"])
        waitForExpectations(timeout: 10)
        XCTAssertEqual(add.value as? String, "Logged")
    }

    func testSearchSignedOutOffersSignInAndSaysWhenItIsOff() {
        launch("light", large: false, ["-uiTestProfileSignedOut"])
        var search = openLogFood()
        search.tap()
        search.typeText("banana")
        XCTAssertTrue(app.buttons["logFoodOnlineSignIn"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["logFoodOnlineRow.Bananas, raw"].waitForExistence(timeout: 2))

        launch("light", large: false, ["-uiTestFoodSearchOff"])
        search = openLogFood()
        search.tap()
        search.typeText("banana")
        let failure = app.staticTexts["logFoodOnlineFailure"]
        XCTAssertTrue(failure.waitForExistence(timeout: 10))
        XCTAssertEqual(failure.label, "Online search isn't available yet.")
        XCTAssertTrue(app.buttons["logFoodDescribe"].exists, "Estimate still works")
    }

    // MARK: Captures

    func testCaptureLightDefault() { capture("light", large: false) }
    func testCaptureDarkAccessibility() { capture("dark", large: true) }

    private func capture(_ appearance: String, large: Bool) {
        // 1. Looking up (held), then the found food.
        launch(appearance, large: large, ["-uiTestTerraSlow"])
        scanBarcode()
        XCTAssertTrue(app.staticTexts["scanFoodBarcodeCode"].waitForExistence(timeout: 6))
        shoot("barcode-looking-up")
        XCTAssertTrue(foodLog.waitForExistence(timeout: 10))
        shoot("barcode-found")
        app.swipeUp()
        shoot("barcode-found-2")

        // 2. Not found; offline.
        launch(appearance, large: large, ["-uiTestBarcodeNotFound"])
        scanBarcode()
        XCTAssertTrue(app.descendants(matching: .any)["scanFoodBarcodeNotFound"].waitForExistence(timeout: 10))
        shoot("barcode-not-found")
        launch(appearance, large: large, ["-uiTestTerraOffline"])
        scanBarcode()
        XCTAssertTrue(app.descendants(matching: .any)["scanFoodBarcodeFailure"].waitForExistence(timeout: 10))
        shoot("barcode-offline")

        // 3. Search: the user's foods, then online foods; an online food with its servings.
        launch(appearance, large: large)
        let search = openLogFood()
        search.tap()
        search.typeText("banana")
        XCTAssertTrue(app.buttons["logFoodOnlineRow.Bananas, raw"].waitForExistence(timeout: 10))
        shoot("search")
        // The keyboard away (Search): the user's foods, then More foods, credited.
        search.typeText("\n")
        shoot("search-2")
        app.swipeUp()
        shoot("search-3")
        app.buttons["logFoodOnlineRow.Bananas, raw"].tap()
        XCTAssertTrue(foodLog.waitForExistence(timeout: 5))
        shoot("search-food")
    }
}
