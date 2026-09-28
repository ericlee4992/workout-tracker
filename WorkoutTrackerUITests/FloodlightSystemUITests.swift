import XCTest

// Floodlight redesign ticket 11 — the system surfaces.
// • Z01 / Z03 captures: the Live Activity's own views (compiled into the app for this) in every
//   state, through the test-only gallery (`-uiTestActivityGallery <state>`), light and dark at
//   Default and AccessibilityL. XCUITest cannot put the real Lock Screen through those four.
// • One real Live Activity: the live fixture posts it (`-uiTestRealLiveActivity`); the compact
//   island and the card in Notification Center are photographed, and +15s and Skip are pressed ON
//   THE CARD — the commands must reach the workout (the rest bar in the app moves / goes).
final class FloodlightSystemUITests: XCTestCase {
    private var app: XCUIApplication!
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    static let states = ["resting", "best", "nextExercise", "ready", "superset", "warmup", "nohr", "done",
                         "timer", "recovered", "cap", "noreading", "cardio", "cardioTarget", "cardioPaused"]

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func shoot(_ name: String, _ screenshot: XCUIScreenshot? = nil) {
        let shot = XCTAttachment(screenshot: screenshot ?? app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func any(_ id: String, in root: XCUIApplication? = nil) -> XCUIElement {
        (root ?? app).descendants(matching: .any).matching(identifier: id).firstMatch
    }

    // MARK: Gallery captures

    func testGalleryDark() { gallery("dark", large: false) }
    func testGalleryLight() { gallery("light", large: false) }
    func testGalleryDarkAccessibility() { gallery("dark", large: true) }
    func testGalleryLightAccessibility() { gallery("light", large: true) }

    private func gallery(_ appearance: String, large: Bool) {
        for state in Self.states {
            app.launchArguments = ["-uiTestActivityGallery", state, "-appearance", appearance]
                + (large ? ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] : [])
            app.launch()
            XCTAssertTrue(any("activityGallery").waitForExistence(timeout: 15), state)
            XCTAssertTrue(any("galleryLockScreen").exists, state)
            // What each state must draw: the rest commands while resting, Pause / Resume in
            // cardio, neither once rest is over.
            let resting = ["resting", "best", "nextExercise", "nohr"].contains(state)
            let cardio = state.hasPrefix("cardio")
            XCTAssertEqual(app.buttons["activitySkipRest"].exists, resting, "\(state): Skip")
            XCTAssertEqual(app.buttons["activityPauseResume"].exists, cardio, "\(state): Pause")
            Thread.sleep(forTimeInterval: 0.8)
            shoot("Z01-\(state)-\(appearance)-\(large ? "axl" : "default")")
        }
    }

    // MARK: The real Live Activity

    /// "1:24" out of the in-app rest bar's label ("Rest, 1:24 left…"), in seconds.
    private func restSecondsInApp() -> Int? {
        let bar = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH 'Rest, '")).firstMatch
        guard bar.waitForExistence(timeout: 5) else { return nil }
        let text = bar.label.dropFirst("Rest, ".count).split(separator: " ").first ?? ""
        let parts = text.split(separator: ":").compactMap { Int($0) }
        return parts.count == 2 ? parts[0] * 60 + parts[1] : nil
    }

    /// Notification Center shows the Lock Screen's Live Activities.
    private func openNotificationCenter() {
        let top = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.005))
        top.press(forDuration: 0.1, thenDragTo: springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.7)))
        Thread.sleep(forTimeInterval: 1.5)
    }

    private func closeNotificationCenter() {
        let bottom = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98))
        bottom.press(forDuration: 0.1, thenDragTo: springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)))
        Thread.sleep(forTimeInterval: 1)
    }

    func testRealLiveActivityCommandsReachTheWorkout() {
        app.launchArguments = ["-uiTestReset", "-uiTestDesignSample", "-uiTestDesignLive", "-uiTestRealLiveActivity",
                               "-appearance", "dark"]
        app.launch()
        XCTAssertTrue(app.buttons["finishWorkout"].waitForExistence(timeout: 15))
        guard let before = restSecondsInApp() else { return XCTFail("no rest running in the fixture") }
        let readAt = Date()
        Thread.sleep(forTimeInterval: 2)

        // The compact island over the Home Screen.
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 2)
        shoot("Z01-real-home-compact", XCUIScreen.main.screenshot())

        // The card, and +15s pressed on it.
        openNotificationCenter()
        // The first interactive activity asks to be allowed; its buttons do nothing until then.
        // First "Allow", later "Always Allow" ("continue to allow"); never "Don't Allow".
        let allow = springboard.buttons.matching(NSPredicate(format: "label ENDSWITH 'Allow' AND NOT (label BEGINSWITH 'Don')")).firstMatch
        if allow.waitForExistence(timeout: 2) {
            shoot("Z01-real-card-permission", XCUIScreen.main.screenshot())
            allow.tap()
            Thread.sleep(forTimeInterval: 1.5)
        }
        shoot("Z01-real-card-resting", XCUIScreen.main.screenshot())
        let add = springboard.buttons["Add 15 seconds"]
        XCTAssertTrue(add.waitForExistence(timeout: 5), "the card's +15s")
        add.tap()
        // The intent runs in the app, then the system re-renders the card: give it time, and
        // reopen Notification Center so the shot is the redrawn card.
        Thread.sleep(forTimeInterval: 5)
        closeNotificationCenter()
        openNotificationCenter()
        shoot("Z01-real-card-after-add", XCUIScreen.main.screenshot())
        closeNotificationCenter()

        app.activate()
        XCTAssertTrue(app.buttons["finishWorkout"].waitForExistence(timeout: 10))
        guard let after = restSecondsInApp() else { return XCTFail("the rest ended after +15s") }
        let elapsed = Int(Date().timeIntervalSince(readAt).rounded(.up))
        // Without the command the rest would read `before − elapsed` (± a second of label
        // rounding); +15s puts it about 15 higher.
        XCTAssertGreaterThanOrEqual(after, before - elapsed + 12, "+15s on the card moved the rest (\(before) → \(after) over \(elapsed) s)")

        // Skip on the card ends the rest in the app.
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 1.5)
        openNotificationCenter()
        let skip = springboard.buttons["Skip rest"]
        XCTAssertTrue(skip.waitForExistence(timeout: 5), "the card's Skip")
        skip.tap()
        Thread.sleep(forTimeInterval: 5)
        closeNotificationCenter()
        openNotificationCenter()
        shoot("Z01-real-card-after-skip", XCUIScreen.main.screenshot())
        closeNotificationCenter()
        app.activate()
        XCTAssertTrue(app.buttons["finishWorkout"].waitForExistence(timeout: 10))
        let bar = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Rest, '")).firstMatch
        XCTAssertFalse(bar.waitForExistence(timeout: 3), "Skip on the card ended the rest")

        shoot("Z01-real-app-after-skip")
        // The card stays on the Simulator's Lock Screen; the next real-activity run ends it (a new
        // workout's card ends any card left by another, WorkoutActivityController).
        app.terminate()
    }
}
