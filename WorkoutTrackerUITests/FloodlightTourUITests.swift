import XCTest

/// Public beta ticket 02 (spec Q8b): the welcome page and the guided tour — captured in light and dark at Default and
/// dark at AccessibilityL — and the flows around them: Skip is remembered, a phone with workouts never sees the
/// welcome, the tour blocks every other tap, Settings → Show Tour, and the user's own (empty) store after the tour.
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

    private func launch(_ extra: [String], appearance: String = "dark", large: Bool = false) {
        app.launchArguments = ["-uiTestReset", "-appearance", appearance] + extra
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] }
        app.launch()
    }

    private var freshWelcome: [String] { ["-uiTestOnboarding", "-uiTestOnboardingFresh"] }

    /// The user's own store is the empty UI-test store: its gym picker reads "No gym".
    private func assertBackOnTheUsersEmptyStore() {
        let picker = app.buttons["gymPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        XCTAssertTrue(picker.label.contains("No gym"), "back on the user's store, not the sample (\(picker.label))")
    }

    private func walkTour(_ name: String) {
        let next = app.buttons["tourNext"]
        for step in 1...8 {
            XCTAssertTrue(next.waitForExistence(timeout: 15), "step \(step) shows Next")
            Thread.sleep(forTimeInterval: 1.0)
            shoot("tour-s\(step)-\(name)")
            next.tap()
        }
        XCTAssertTrue(next.waitForNonExistence(timeout: 5), "the tour ends after its last step")
    }

    private func welcomeThenTour(appearance: String, large: Bool = false) {
        launch(freshWelcome, appearance: appearance, large: large)
        let name = "\(appearance)-\(large ? "AXL" : "default")"
        let tour = app.buttons["welcomeTour"]
        XCTAssertTrue(tour.waitForExistence(timeout: 15), "a fresh phone shows the welcome page")
        Thread.sleep(forTimeInterval: 0.8)
        shoot("welcome-\(name)")
        tour.tap()
        walkTour(name)
        assertBackOnTheUsersEmptyStore()
    }

    func testWelcomeAndTourDark() { welcomeThenTour(appearance: "dark") }
    func testWelcomeAndTourLight() { welcomeThenTour(appearance: "light") }
    func testWelcomeAndTourLargeText() { welcomeThenTour(appearance: "dark", large: true) }

    func testSkipIsRememberedAcrossLaunches() {
        launch(freshWelcome)
        let skip = app.buttons["welcomeSkip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 15))
        skip.tap()
        assertBackOnTheUsersEmptyStore()
        app.terminate()
        launch(["-uiTestOnboarding"])  // answered: no -uiTestOnboardingFresh
        XCTAssertTrue(app.buttons["gymPicker"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["welcomeSkip"].exists, "an answered welcome stays away")
    }

    func testAPhoneWithWorkoutsNeverSeesTheWelcome() {
        launch(freshWelcome + ["-uiTestDesignSample"])
        XCTAssertTrue(app.buttons["gymPicker"].waitForExistence(timeout: 15))
        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertFalse(app.buttons["welcomeTour"].exists)
    }

    func testTheTourBlocksEveryOtherTap() {
        launch(freshWelcome)
        let tour = app.buttons["welcomeTour"]
        XCTAssertTrue(tour.waitForExistence(timeout: 15))
        tour.tap()
        XCTAssertTrue(app.staticTexts["1 of 8"].waitForExistence(timeout: 15))
        // Step 1 highlights the gym picker; the Settings gear and the History tab are under the dimming.
        app.buttons["openSettings"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.tabBars.buttons["History"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertTrue(app.staticTexts["1 of 8"].exists, "still on step 1")
        XCTAssertFalse(app.descendants(matching: .any)["appUnitPreference"].exists, "Settings did not open")
        // Tapping the highlighted control advances the tour; it does not open the gym menu.
        app.buttons["gymPicker"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts["2 of 8"].waitForExistence(timeout: 5))
        app.buttons["tourSkip"].tap()
        assertBackOnTheUsersEmptyStore()
    }

    func testShowTourFromSettings() {
        launch([])  // no welcome under -uiTestReset without -uiTestOnboarding
        let gear = app.buttons["openSettings"]
        XCTAssertTrue(gear.waitForExistence(timeout: 15))
        gear.tap()
        let row = app.buttons["showTour"]
        for _ in 0..<8 where !row.isHittable { app.swipeUp() }
        XCTAssertTrue(row.isHittable)
        row.tap()
        XCTAssertTrue(app.staticTexts["1 of 8"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["gymPicker"].label.contains("Iron Temple"), "the tour runs on the sample world")
        app.buttons["tourSkip"].tap()
        assertBackOnTheUsersEmptyStore()
    }
}
