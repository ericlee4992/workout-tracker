import XCTest

/// Nutrition N12 (D86) against the food databases' fixture (`-uiTestTerra`): a Korean barcode no database fills lists
/// the foods matching its name as "Is this it?"; the one logged is linked, so the next scan opens it at once from the
/// phone, and one only opened links nothing; a name nothing matches can be searched by another; Log food's search in
/// Korean (one syllable is enough) shows the ministry's foods, credited, and a restaurant dish without fat and carbs
/// says so. Then the captures, light at Default and dark at AccessibilityL.
final class KoreanFoodUITests: XCTestCase {
    private var app: XCUIApplication!
    private var tag = ""
    private let credit = "Food data from Korea's Ministry of Food and Drug Safety"

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func shoot(_ name: String) {
        Thread.sleep(forTimeInterval: 0.8)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "n12-\(name)-\(tag)"
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
    private var onion: XCUIElement { app.buttons["scanFoodCandidate.양파링 오리지널"] }

    /// Scrolls the step until `element` can be tapped (the list sits under the code at AccessibilityL).
    private func reveal(_ element: XCUIElement) {
        for _ in 0..<4 where !element.isHittable { app.swipeUp() }
    }

    // MARK: Is this it?

    func testAKoreanBarcodeOffersIsThisItAndTheLoggedFoodOpensNextTime() {
        launch("light", large: false, ["-uiTestBarcodeKorean"])
        scanBarcode()
        XCTAssertTrue(onion.waitForExistence(timeout: 10), "the foods matching the product's name")
        XCTAssertTrue(app.descendants(matching: .any)["scanFoodBarcodeNotFound"].label.contains("Not in the database"))
        XCTAssertEqual(app.textFields["scanFoodCandidatesSearch"].value as? String, "양파링 오리지널")
        XCTAssertFalse(app.buttons["scanFoodCandidate.양파링 매콤한맛"].exists, "only the name's matches")
        XCTAssertEqual(app.staticTexts["scanFoodCandidatesAttribution"].label, credit)
        XCTAssertTrue(app.buttons["scanFoodBarcodeLabel"].exists && app.buttons["scanFoodManual"].exists)

        onion.tap()
        XCTAssertTrue(foodLog.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["양파링 오리지널"].exists)
        let attribution = app.staticTexts["selectedFoodAttribution"]
        if !attribution.isHittable { app.swipeUp() }
        XCTAssertEqual(attribution.label, credit)
        foodLog.tap()
        XCTAssertTrue(app.buttons["todayEntry.양파링 오리지널"].waitForExistence(timeout: 5))

        // The same code opens the food it was confirmed as, at once, from the phone (the fixture would answer "not
        // found" again: the candidates are not shown).
        scanBarcode()
        XCTAssertTrue(foodLog.waitForExistence(timeout: 6), "linked: the next scan opens it")
        XCTAssertFalse(onion.exists)
        XCTAssertTrue(app.staticTexts["양파링 오리지널"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["scanFoodBarcodeFailure"].exists)
    }

    func testOpeningACandidateWithoutLoggingLinksNothing() {
        launch("light", large: false, ["-uiTestBarcodeKorean"])
        scanBarcode()
        XCTAssertTrue(onion.waitForExistence(timeout: 10))
        onion.tap()
        XCTAssertTrue(foodLog.waitForExistence(timeout: 5))
        // Back: the list again (the wrong one was opened); then away without logging.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(onion.waitForExistence(timeout: 5), "back at the candidates")
        app.buttons["scanCancel"].tap()
        XCTAssertTrue(app.buttons["logFoodPill"].waitForExistence(timeout: 5))
        scanBarcode()
        XCTAssertTrue(onion.waitForExistence(timeout: 10), "not linked: asked again, not opened")
        XCTAssertFalse(foodLog.exists)
    }

    func testANameNothingMatchesCanBeSearchedByAnother() {
        launch("light", large: false, ["-uiTestBarcodeKoreanNoMatch"])
        scanBarcode()
        let empty = app.staticTexts["scanFoodCandidatesEmpty"]
        XCTAssertTrue(empty.waitForExistence(timeout: 10))
        let field = app.textFields["scanFoodCandidatesSearch"]
        XCTAssertEqual(field.value as? String, "샘표고등어")
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8))
        field.typeText("양파링\n")
        XCTAssertTrue(onion.waitForExistence(timeout: 10), "the other name's foods")
        XCTAssertFalse(empty.exists)
    }

    // MARK: Log food in Korean

    func testAKoreanSearchShowsTheMinistrysFoodsAndANoteForMissingMacros() {
        launch()
        let search = openLogFood()
        search.tap()
        search.typeText("김치")
        XCTAssertTrue(app.buttons["logFoodOnlineRow.김치찌개"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["logFoodOnlineAttribution"].label, credit)

        // One syllable is a search in Korean.
        search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 2))
        search.typeText("떡")
        let rose = app.buttons["logFoodOnlineRow.떡볶이, 로제떡볶이"]
        XCTAssertTrue(rose.waitForExistence(timeout: 10))
        rose.tap()
        XCTAssertTrue(foodLog.waitForExistence(timeout: 5))
        let note = app.staticTexts["selectedFoodMacrosNotListed"]
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        XCTAssertEqual(note.label, "Carbs and fat aren't listed for this food; they count as 0.")

        // A complete food carries no note.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let kimchi = openLogFoodIfNeeded()
        kimchi.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4))
        kimchi.typeText("김치")
        let stew = app.buttons["logFoodOnlineRow.김치찌개"]
        XCTAssertTrue(stew.waitForExistence(timeout: 10))
        stew.tap()
        XCTAssertTrue(foodLog.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["selectedFoodMacrosNotListed"].exists)
    }

    /// Back from a food: Log food's search field again (it keeps its text), tapped for typing.
    private func openLogFoodIfNeeded() -> XCUIElement {
        let search = app.textFields["logFoodSearch"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        return search
    }

    // MARK: Captures

    func testCaptureLightDefault() { capture("light", large: false) }
    func testCaptureDarkAccessibility() { capture("dark", large: true) }

    private func capture(_ appearance: String, large: Bool) {
        // 1. Is this it?: the candidates; scrolled; a name nothing matches.
        launch(appearance, large: large, ["-uiTestBarcodeKorean"])
        scanBarcode()
        XCTAssertTrue(onion.waitForExistence(timeout: 10))
        shoot("is-this-it")
        app.swipeUp()
        shoot("is-this-it-2")
        launch(appearance, large: large, ["-uiTestBarcodeKoreanNoMatch"])
        scanBarcode()
        XCTAssertTrue(app.staticTexts["scanFoodCandidatesEmpty"].waitForExistence(timeout: 10))
        shoot("is-this-it-no-match")

        // 2. Log food in Korean; the restaurant dish with its note.
        launch(appearance, large: large)
        let search = openLogFood()
        search.tap()
        search.typeText("떡")
        let rose = app.buttons["logFoodOnlineRow.떡볶이, 로제떡볶이"]
        XCTAssertTrue(rose.waitForExistence(timeout: 10))
        search.typeText("\n")
        shoot("search-korean")
        // Scrolled: the credit under the results (behind the tab bar at AccessibilityL before scrolling).
        app.swipeUp()
        shoot("search-korean-2")
        reveal(rose)
        rose.tap()
        XCTAssertTrue(foodLog.waitForExistence(timeout: 5))
        shoot("food-not-listed")
        app.swipeUp()
        shoot("food-not-listed-2")
    }
}
