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

    /// Where the real app's controls are, read before a tour hides them (the tour's sample app lays out the same).
    private struct Spots { let start: CGRect; let settings: CGRect; let historyTab: CGRect; let gymPicker: CGRect }

    private func tap(_ rect: CGRect) {
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: rect.midX, dy: rect.midY)).tap()
    }

    /// Launches on the user's empty store, records the spots, and starts the tour from Settings → Show Tour.
    private func startTourFromSettings(_ extra: [String] = [], tapStartImmediately: Bool = false) -> Spots {
        launch(extra)
        let gear = app.buttons["openSettings"]
        XCTAssertTrue(gear.waitForExistence(timeout: 15))
        let spots = Spots(start: app.buttons["startEmptyWorkout"].frame, settings: gear.frame,
                          historyTab: app.tabBars.buttons["History"].frame, gymPicker: app.buttons["gymPicker"].frame)
        gear.tap()
        let row = app.buttons["showTour"]
        for _ in 0..<8 where !row.isHittable { app.swipeUp() }
        XCTAssertTrue(row.isHittable)
        row.tap()
        if tapStartImmediately { for _ in 0..<3 { tap(spots.start) } }
        XCTAssertTrue(app.staticTexts["1 of 8"].waitForExistence(timeout: 15))
        return spots
    }

    private func assertNothingEscaped() {
        XCTAssertFalse(app.buttons["minimizeWorkout"].exists, "no workout opened")
        XCTAssertFalse(app.descendants(matching: .any)["appUnitPreference"].exists, "Settings did not open")
    }

    func testTheAppUnderTheTourIsInert() {
        let spots = startTourFromSettings()
        // Disabled: VoiceOver and Full Keyboard Access can focus these but not activate them.
        for id in ["startEmptyWorkout", "startCardio", "openSettings", "gymPicker"] {
            let control = app.buttons[id]
            XCTAssertTrue(control.exists && !control.isEnabled, "\(id) is disabled during the tour")
        }
        // Touch: Start, the gear and the History tab are under the barrier.
        tap(spots.start); tap(spots.settings); tap(spots.historyTab)
        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertTrue(app.staticTexts["1 of 8"].exists, "still on step 1")
        assertNothingEscaped()
        // A tap on the highlighted control (the gym picker) advances the tour; it does not open the gym menu.
        tap(spots.gymPicker)
        XCTAssertTrue(app.staticTexts["2 of 8"].waitForExistence(timeout: 5))
        app.buttons["tourSkip"].tap()
        assertBackOnTheUsersEmptyStore()
    }

    func testTapsAtTheVeryStartCannotEscape() {
        _ = startTourFromSettings(tapStartImmediately: true)
        Thread.sleep(forTimeInterval: 1.0)
        assertNothingEscaped()
        app.buttons["tourSkip"].tap()
        assertBackOnTheUsersEmptyStore()
    }

    func testTourButtonsTakeTapsAtTheirEdges() {
        _ = startTourFromSettings()
        let next = app.buttons["tourNext"]
        next.coordinate(withNormalizedOffset: CGVector(dx: 0.06, dy: 0.12)).tap()
        XCTAssertTrue(app.staticTexts["2 of 8"].waitForExistence(timeout: 5), "Next near its top-left edge")
        next.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.88)).tap()
        XCTAssertTrue(app.staticTexts["3 of 8"].waitForExistence(timeout: 5), "Next near its bottom-right edge")
        app.buttons["tourSkip"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        assertBackOnTheUsersEmptyStore()
    }

    func testShowTourRefusesDuringAWorkout() {
        launch(["-uiTestDesignSample", "-uiTestDesignLiveEmpty"])
        let minimize = app.buttons["minimizeWorkout"]
        XCTAssertTrue(minimize.waitForExistence(timeout: 15), "the running workout reopens")
        minimize.tap()
        let gear = app.buttons["openSettings"]
        XCTAssertTrue(gear.waitForExistence(timeout: 10))
        gear.tap()
        let row = app.buttons["showTour"]
        for _ in 0..<8 where !row.isHittable { app.swipeUp() }
        row.tap()
        XCTAssertTrue(app.alerts["Finish your workout first."].waitForExistence(timeout: 5))
        app.alerts.buttons["OK"].tap()
        XCTAssertFalse(app.staticTexts["1 of 8"].exists, "no tour while a workout runs")
    }

    func testShowTourFromSettings() {
        _ = startTourFromSettings()
        let picker = app.buttons["gymPicker"]
        XCTAssertTrue(picker.label.contains("Iron Temple") && !picker.isEnabled, "the tour runs on the sample, inert")
        app.buttons["tourSkip"].tap()
        assertBackOnTheUsersEmptyStore()
    }
}
