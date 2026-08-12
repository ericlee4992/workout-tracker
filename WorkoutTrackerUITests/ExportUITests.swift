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
        app.tabBars.buttons["Gyms"].tap()

        let summary = app.staticTexts["exportSummary"]
        XCTAssertTrue(
            summary.waitForExistence(timeout: 5),
            "The Gyms screen should carry the export section")
        XCTAssertEqual(
            summary.label, "0 workouts · 0 sets",
            "An empty store should say so rather than showing nothing")

        let exportCSV = app.buttons["exportCSV"]
        XCTAssertTrue(exportCSV.waitForExistence(timeout: 5))
        exportCSV.tap()

        // The share sheet names the file it is about to share.
        let named = app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@", "workout-tracker-")).firstMatch
        XCTAssertTrue(
            named.waitForExistence(timeout: 10),
            "Exporting should present the share sheet with the written file")

        // Dismissing returns to the app with no error surfaced.
        let close = app.buttons["Close"]
        if close.waitForExistence(timeout: 3) {
            close.tap()
        } else {
            app.swipeDown(velocity: .fast)
        }
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertFalse(
            app.staticTexts["exportFailure"].exists,
            "A completed export must not report a failure")
    }
}
