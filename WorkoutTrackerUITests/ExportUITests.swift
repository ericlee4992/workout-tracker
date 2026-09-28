import XCTest

/// Milestone 3, ticket 03 — the export is reachable and really produces a file.
///
/// Deliberately short: the store starts empty (`-uiTestReset`), so this proves
/// the wiring (tap → build → share sheet holding a named file) without paying
/// for a second full logging walkthrough. What the file *contains* is covered
/// by `ExportTests` and `ExportFidelityTests`, where it can be asserted
/// precisely and in a second rather than a minute.
final class ExportUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestReset"]
        app.launch()
    }

    func testExportSectionProducesAShareableFile() {
        // Ticket 05: Settings is behind the gear on the Workout tab; Floodlight ticket 09 moved
        // Export to its own screen behind Settings' export card.
        app.tabBars.buttons["Workout"].tap()
        app.buttons["openSettings"].tap()

        let card = app.buttons["exportSettings"]
        XCTAssertTrue(
            card.waitForExistence(timeout: 5),
            "The Settings screen should carry the export card")
        XCTAssertTrue(
            card.label.hasPrefix("0 workouts · 0 sets"),
            "An empty store should say so rather than showing nothing (\(card.label))")
        card.tap()

        let exportCSV = app.buttons["exportCSV"]
        XCTAssertTrue(exportCSV.waitForExistence(timeout: 5))
        exportCSV.tap()

        // The share sheet names the file it is about to share.
        let named = app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@", "workout-tracker-")).firstMatch
        XCTAssertTrue(
            named.waitForExistence(timeout: 10),
            "Exporting should present the share sheet with the written file")

        // Dismissing returns to the app with no error surfaced, and the file stays on the card.
        let close = app.buttons["Close"]
        if close.waitForExistence(timeout: 3) {
            close.tap()
        } else {
            app.swipeDown(velocity: .fast)
        }
        XCTAssertTrue(app.descendants(matching: .any)["exportFileCard"].waitForExistence(timeout: 5))
        XCTAssertFalse(
            app.descendants(matching: .any)["exportFailure"].exists,
            "A completed export must not report a failure")
    }
}
