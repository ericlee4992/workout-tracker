import XCTest

/// Public beta ticket 01 — the backup round-trip check (DEVELOPMENT → Container backup and restore).
///
/// Not a product test: it taps Export → JSON on whatever store the Simulator's installed app already has
/// (no `-uiTestReset`), so `scripts/container-tools/simulator_export.sh` can restore a phone capture into a
/// disposable Simulator and have the app itself export it. Comparing that export with the one taken on the
/// phone before the capture proves the capture holds the same history *values*, not just the same IDs and
/// counts — a capture that lost a committed edit (an incomplete WAL copy) keeps both. Skipped unless the
/// runner's environment sets `WT_BACKUP_EXPORT=1` (`TEST_RUNNER_WT_BACKUP_EXPORT=1` on xcodebuild), so the
/// normal suites never touch a real store.
final class BackupExportUITests: XCTestCase {
    func testExportTheInstalledStoreAsJSON() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["WT_BACKUP_EXPORT"] == "1",
            "Backup tooling only: run through scripts/container-tools/simulator_export.sh")
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Workout"].tap()
        app.buttons["openSettings"].tap()

        let card = app.buttons["exportSettings"]
        XCTAssertTrue(card.waitForExistence(timeout: 10), "The Settings screen should carry the export card")
        print("BACKUP-EXPORT CARD: \(card.label)")
        card.tap()

        let json = app.buttons["exportJSON"]
        XCTAssertTrue(json.waitForExistence(timeout: 5))
        json.tap()

        // The share sheet appears only after the file is written to tmp/Exports.
        let sheet = app.descendants(matching: .any).matching(identifier: "ActivityListView").firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 30), "Exporting should present the share sheet")
        XCTAssertFalse(app.descendants(matching: .any)["exportFailure"].exists, "The export must not fail")
    }
}
