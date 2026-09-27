import XCTest

// Floodlight redesign ticket 03 — Codex review 03 regressions on the live workout, on the
// `-uiTestDesignLive` fixture (Push Day at Iron Temple; the chest press's sets 1 and 2 logged,
// 100 × 10 and 110 × 8, both new bests over last week's 45 × 8; set 3 a 110 × 8 draft; rest running).
final class FloodlightLiveUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(_ extra: [String] = []) {
        app.launchArguments = ["-uiTestReset", "-uiTestDesignSample", "-uiTestDesignLive"] + extra
        app.launch()
        XCTAssertTrue(app.buttons["finishWorkout"].waitForExistence(timeout: 15))
    }

    private func shoot(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    // MARK: Captures (L01 with the rest running; the band is captured by its test below)

    func testCaptureLiveLight() { capture("light", large: false) }
    func testCaptureLiveDark() { capture("dark", large: false) }
    func testCaptureLiveLightAccessibility() { capture("light", large: true) }

    private func capture(_ appearance: String, large: Bool) {
        launch(["-appearance", appearance]
               + (large ? ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] : []))
        XCTAssertTrue(any("setRow.badge").waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1)
        shoot("floodlight-03-live-\(appearance)-\(large ? "axl" : "default")")
    }

    // MARK: Codex review 03 regressions

    private func any(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func all(_ id: String) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: id)
    }

    /// Taps at the field's trailing edge so the caret lands after the text, clears it, types.
    private func replace(_ field: XCUIElement, with text: String) {
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
        let current = (field.value as? String) ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count + 1) + text)
        XCTAssertEqual(field.value as? String, text, "the field holds exactly the typed value")
        app.buttons["keyboardDone"].firstMatch.tap()
    }

    /// Finding 1: a logged set is corrected in place — it stays completed (no re-timed set).
    func testACompletedSetCanBeCorrectedInPlace() {
        launch()
        let weight = app.textFields.matching(identifier: "setRow.weight").element(boundBy: 0)
        let check = app.buttons.matching(identifier: "setRow.complete").element(boundBy: 0)
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        XCTAssertEqual(check.value as? String, "Completed")
        replace(weight, with: "102.5")
        XCTAssertEqual(weight.value as? String, "102.5")
        XCTAssertEqual(check.value as? String, "Completed", "correcting a value does not un-log the set")
    }

    /// Finding 2: marks follow the data — making a best a warmup takes its sticker away at once.
    func testTurningABestIntoAWarmupRemovesItsMark() {
        launch()
        XCTAssertTrue(any("setRow.badge").waitForExistence(timeout: 5))
        XCTAssertEqual(all("setRow.badge").count, 2)
        app.buttons.matching(identifier: "setRow.setType").element(boundBy: 1).tap()
        app.buttons["Warmup"].firstMatch.tap()
        let one = NSPredicate(format: "count == 1")
        expectation(for: one, evaluatedWith: all("setRow.badge"))
        waitForExpectations(timeout: 5)
    }

    /// Finding 4 (L03): logging a new best docks the band on the rest slab for a few seconds.
    func testANewBestDocksTheBandOnTheRestSlab() {
        launch()
        let weight = app.textFields.matching(identifier: "setRow.weight").element(boundBy: 2)
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        replace(weight, with: "115")
        app.buttons.matching(identifier: "setRow.complete").element(boundBy: 2).tap()
        let band = any("liveNewBest")
        XCTAssertTrue(band.waitForExistence(timeout: 5), "the New best band lands")
        XCTAssertTrue(band.label.contains("Seated Chest Press"), band.label)
        XCTAssertTrue(band.label.contains("115 lb × 8"), band.label)
        XCTAssertTrue(band.label.contains("up from 110 lb × 8"), band.label)
        XCTAssertTrue(app.staticTexts["Rest"].exists, "the rest stays under the band")
        shoot("floodlight-03-live-new-best-band")
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: band)
        waitForExpectations(timeout: 8)
        XCTAssertTrue(app.staticTexts["Rest"].exists, "the slab returns to the rest alone")
    }

    /// L03 at AX sizes (the prototype's choice, confirmed by the user): the band does not stack
    /// on the rest — for its seconds it takes the place of the Rest/time text, then gives it back.
    func testAtAccessibilitySizesTheBestTakesTheRestTextsPlace() {
        launch(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"])
        let weight = app.textFields.matching(identifier: "setRow.weight").element(boundBy: 2)
        for _ in 0..<6 where !(weight.exists && weight.isHittable) { app.swipeUp() }
        XCTAssertTrue(weight.isHittable)
        replace(weight, with: "115")
        let check = app.buttons.matching(identifier: "setRow.complete").element(boundBy: 2)
        for _ in 0..<4 where !check.isHittable { app.swipeUp() }
        check.tap()
        let band = any("liveNewBest")
        XCTAssertTrue(band.waitForExistence(timeout: 5), "the compact New best lands")
        XCTAssertTrue(band.label.contains("up from 110 lb × 8"), band.label)
        XCTAssertFalse(app.staticTexts["Rest"].exists, "the best stands in for the Rest/time text")
        XCTAssertTrue(app.buttons["Skip"].exists, "the rest controls stay")
        shoot("floodlight-03-live-new-best-axl")
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: band)
        waitForExpectations(timeout: 8)
        XCTAssertTrue(app.staticTexts["Rest"].waitForExistence(timeout: 2), "the Rest text comes back")
    }

    // MARK: Codex review 03b — the band follows its set

    /// Logs set 3 at 115 × 8 (a new best over set 2's 110 × 8) and returns the band.
    private func celebrateSetThree() -> XCUIElement {
        let weight = app.textFields.matching(identifier: "setRow.weight").element(boundBy: 2)
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        replace(weight, with: "115")
        app.buttons.matching(identifier: "setRow.complete").element(boundBy: 2).tap()
        let band = any("liveNewBest")
        XCTAssertTrue(band.waitForExistence(timeout: 5), "the New best band lands")
        XCTAssertEqual(all("setRow.badge").count, 3)
        return band
    }

    /// With the band held for 30 s, it can only go because it followed its set.
    private func expectGone(_ band: XCUIElement, _ message: String) {
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: band)
        waitForExpectations(timeout: 3)
        XCTAssertFalse(band.exists, message)
    }

    func testMakingAFreshBestAWarmupTakesTheBandAway() {
        launch(["-uiTestLongCelebration"])
        let band = celebrateSetThree()
        app.buttons.matching(identifier: "setRow.setType").element(boundBy: 2).tap()
        app.buttons["Warmup"].firstMatch.tap()
        expectGone(band, "no New best band for a warmup")
        XCTAssertEqual(all("setRow.badge").count, 2, "the warmup loses its sticker")
    }

    func testCorrectingAFreshBestBelowTheRecordTakesTheBandAway() {
        launch(["-uiTestLongCelebration"])
        let band = celebrateSetThree()
        replace(app.textFields.matching(identifier: "setRow.weight").element(boundBy: 2), with: "100")
        expectGone(band, "100 × 8 is no record")
        XCTAssertEqual(all("setRow.badge").count, 2, "the corrected set loses its sticker")
    }

    func testCorrectingAFreshBestThatStaysARecordUpdatesTheBand() {
        launch(["-uiTestLongCelebration"])
        let band = celebrateSetThree()
        replace(app.textFields.matching(identifier: "setRow.weight").element(boundBy: 2), with: "120")
        let updated = NSPredicate(format: "label CONTAINS '120 lb × 8'")
        expectation(for: updated, evaluatedWith: band)
        waitForExpectations(timeout: 3)
        XCTAssertTrue(band.label.contains("up from 110 lb × 8"), band.label)
    }
}
