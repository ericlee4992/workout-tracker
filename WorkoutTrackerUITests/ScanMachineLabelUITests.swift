import XCTest

/// Photo machine capture, ticket 03 — the scan flow end to end.
///
/// The Simulator has no camera, so the app is launched with
/// `-uiTestScanFixture`: the viewfinder is a stand-in and the shutter reads a
/// rendered name plate WHOLE (the real shutter reads inside the framing box —
/// only the gym can verify that mapping). Everything after that point —
/// Vision, the matcher, the candidate list, accepting a model — is the real
/// code path.
final class ScanMachineLabelUITests: XCTestCase {
    private var app: XCUIApplication!

    private let gymName = "Scan Test Gym"
    /// What `ScanFixture` renders, and a real row in the seeded catalog.
    private let expectedModel = "Insignia Series Chest Press"
    /// The movement that model serves — what the machine should be *called*.
    private let expectedMovement = "Seated Chest Press"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestReset", "-uiTestScanFixture"]
        app.launch()
    }

    func testScanningALabelFindsTheCatalogModelAndCanBeOverridden() {
        createGym()
        openNewMachineSheet()

        // --- Scan: the viewfinder, the box, the shutter -------------------
        app.buttons["scanLabelOffline"].tap()
        tapShutter(screenshotNamed: "scan-viewfinder")

        let candidate = app.descendants(matching: .any)
            .matching(identifier: "scanCandidate.\(expectedModel)").firstMatch
        XCTAssertTrue(
            candidate.waitForExistence(timeout: 20),
            "Scanning the fixture label should offer its catalog model")

        let readingText = app.staticTexts["scanReadingText"]
        XCTAssertTrue(readingText.exists, "The sheet should echo what it read")
        XCTAssertTrue(
            readingText.label.uppercased().contains("LIFE FITNESS"),
            "Expected the plate's text, got: \(readingText.label)")

        let results = XCTAttachment(screenshot: app.screenshot())
        results.name = "scan-results"
        results.lifetime = .keepAlways
        add(results)

        // Scanner accuracy, ticket 03: "Scan again" returns to the viewfinder
        // and nothing is read until the shutter is tapped AGAIN — a rebuilt
        // camera must not replay the previous tap (codex-review-03).
        app.buttons["Scan again"].firstMatch.tap()
        tapShutter(screenshotNamed: nil)
        XCTAssertTrue(candidate.waitForExistence(timeout: 20), "the second scan offers the model again")

        // D33: a confident match is *preselected*, so accepting is one tap —
        // but it is still a tap.
        let use = app.buttons["scanUseCandidate"]
        XCTAssertTrue(use.isEnabled, "A confident match should arrive preselected")
        use.tap()

        // --- Back on the New Machine sheet, with the model filled in -------
        let modelRow = app.descendants(matching: .any)
            .matching(identifier: "catalogModel").firstMatch
        XCTAssertTrue(modelRow.waitForExistence(timeout: 5))
        XCTAssertTrue(
            modelRow.label.contains(expectedModel),
            "The scanned model should be filled in, got: \(modelRow.label)")

        // D3: picking a model names the machine, however it was picked — and
        // it names it after the *movement*, since the row already prints the
        // model underneath (user feedback, 2026-08-12).
        let label = app.textFields["machineLabel"]
        XCTAssertTrue(label.waitForExistence(timeout: 5))
        XCTAssertEqual(
            label.value as? String, expectedMovement,
            "The machine should be labelled by what you do on it, not by its model")
        // Saved as-is: the whole point of the default is that a scan leaves
        // nothing to type while standing at the machine.
        app.buttons["saveMachine"].tap()
        XCTAssertTrue(
            app.staticTexts[expectedMovement].waitForExistence(timeout: 5),
            "The machine should be saved at the gym under the movement it serves")

        // The label alone proves nothing — it was defaulted from the candidate.
        // The machine row's subtitle is `machine.model?.displayName`, so this
        // is the persisted *relationship* talking (codex-review, finding 10).
        XCTAssertTrue(
            app.staticTexts["Life Fitness \(expectedModel)"].waitForExistence(timeout: 5),
            "The saved machine should carry the scanned catalog model, not just its name")
    }

    /// The other half of the ask: when the catalog does not have the machine,
    /// the scan still gets you a model — a user-created one, prefilled (D35).
    func testCreateNewFromAScanPrefillsTheModelSheet() {
        createGym()
        openNewMachineSheet()

        app.buttons["scanLabelOffline"].tap()
        tapShutter(screenshotNamed: nil)
        let createNew = app.buttons["scanCreateNew"]
        XCTAssertTrue(
            createNew.waitForExistence(timeout: 20),
            "Create-new must always be reachable from a scan")
        createNew.tap()

        let manufacturer = app.textFields["Manufacturer"]
        XCTAssertTrue(
            manufacturer.waitForExistence(timeout: 5),
            "Create-new should open the New Model sheet")
        XCTAssertEqual(
            manufacturer.value as? String, "Life Fitness",
            "The manufacturer should arrive prefilled in the catalog's spelling")
        let modelField = app.textFields["Model"]
        XCTAssertEqual(
            modelField.value as? String, expectedModel,
            "The model name should arrive prefilled from the plate")

        // Finish the path: a user-space model has to link an exercise, save,
        // and end up attached to the machine. Prefilled fields alone proved
        // nothing about what gets stored (codex-review-2, finding 7).
        // Any exercise satisfies "link at least one"; take whichever row is
        // on screen rather than scrolling a 75-row list to a chosen name.
        let exercise = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "newModelExercise.")).firstMatch
        XCTAssertTrue(exercise.waitForExistence(timeout: 5), "The New Model sheet lists exercises")
        exercise.tap()
        app.buttons["saveNewModel"].firstMatch.tap()

        let label = app.textFields["machineLabel"]
        XCTAssertTrue(label.waitForExistence(timeout: 5), "Back on the New Machine sheet")
        app.buttons["saveMachine"].tap()

        let row = app.staticTexts["Life Fitness \(expectedModel)"]
        XCTAssertTrue(
            row.waitForExistence(timeout: 5),
            "The machine should carry the model created from the scan")

        // "Rename Model…" only appears for models the user owns
        // (`!model.isSeeded`), so its presence is the proof that create-new
        // produced a user-space row rather than reusing a seeded one (D35/D4).
        row.press(forDuration: 1.2)
        XCTAssertTrue(
            app.buttons["Rename Model…"].waitForExistence(timeout: 5),
            "A scanned create-new model must be user-created, not seeded")
    }

    // MARK: - Helpers

    /// Scanner accuracy, ticket 03: nothing is read until the shutter. The
    /// fixture stands in for the camera; the box and the shutter are real.
    private func tapShutter(screenshotNamed name: String?) {
        let shutter = app.buttons["scanShutter"]
        XCTAssertTrue(shutter.waitForExistence(timeout: 10), "the viewfinder should show a shutter")
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "scanFramingBox").firstMatch.exists,
                      "and the framing box")
        // Held for a moment: a replayed capture would leave the viewfinder on its own.
        sleep(2)
        XCTAssertTrue(shutter.exists, "still on the viewfinder — nothing was read without a tap")
        XCTAssertFalse(app.staticTexts["scanReadingText"].exists, "nothing is read before the shutter")
        if let name {
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = name
            shot.lifetime = .keepAlways
            add(shot)
        }
        shutter.tap()
    }

    private func createGym() {
        app.tabBars.buttons["Gyms"].tap()
        app.buttons["addGym"].tap()

        let name = app.textFields["gymName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText(gymName)
        app.buttons["saveGym"].tap()

        let row = app.descendants(matching: .any)
            .matching(identifier: "gymRow.\(gymName)").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "The new gym should be listed")
    }

    private func openNewMachineSheet() {
        app.descendants(matching: .any)
            .matching(identifier: "gymRow.\(gymName)").firstMatch.tap()
        let add = app.buttons["addMachine"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        XCTAssertTrue(app.textFields["machineLabel"].waitForExistence(timeout: 5))
    }
}
