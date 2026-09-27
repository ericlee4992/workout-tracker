import XCTest

// Floodlight redesign ticket 02 (Codex review 02, finding 5): the template editor's new
// interactions end to end — superset links through reorder and save, the dirty Cancel
// confirmation, rest back to the exercise default — and the Appearance setting reaching screens
// and sheets. Captures of the detail and editor in both schemes are attached for the record.
final class FloodlightWorkoutTabUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(_ extra: [String] = []) {
        app.launchArguments = ["-uiTestReset"] + extra
        app.launch()
        app.tabBars.buttons["Workout"].tap()
    }

    private func any(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func shoot(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func newTemplate(_ name: String, exercises: [String]) {
        let new = app.buttons["New Template…"]
        XCTAssertTrue(new.waitForExistence(timeout: 10))
        new.tap()
        let field = app.textFields["Template name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("\(name)\n")
        app.addTemplateExercises(exercises)
    }

    private func superset(_ letter: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Superset position \(letter)")).firstMatch
    }

    func testSupersetSurvivesReorderAndSave() {
        launch()
        newTemplate("Pair", exercises: ["Bench Press", "Lat Pulldown"])
        let link = app.buttons["Superset with next"].firstMatch
        XCTAssertTrue(link.waitForExistence(timeout: 5))
        link.tap()
        XCTAssertTrue(app.buttons["Break superset"].firstMatch.waitForExistence(timeout: 5), "the seam shows the pair linked")
        app.navigationBars.buttons["Save"].tap()

        let tile = any("templateTile.Pair")
        XCTAssertTrue(tile.waitForExistence(timeout: 5))
        tile.tap()
        XCTAssertTrue(superset("A").waitForExistence(timeout: 5))
        XCTAssertTrue(superset("B").exists)

        // Drag the second card above the first: the pair is reordered, not broken (D48).
        app.buttons["editTemplate"].tap()
        let handles = app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Reorder'"))
        XCTAssertTrue(handles.element(boundBy: 1).waitForExistence(timeout: 5))
        handles.element(boundBy: 1).press(forDuration: 0.3, thenDragTo: handles.element(boundBy: 0))
        XCTAssertTrue(app.buttons["Break superset"].firstMatch.waitForExistence(timeout: 5), "still linked after the drag")
        app.navigationBars.buttons["Save"].tap()

        let bench = any("templateExercise.Bench Press"), pulldown = any("templateExercise.Lat Pulldown")
        XCTAssertTrue(pulldown.waitForExistence(timeout: 5))
        XCTAssertLessThan(pulldown.frame.minY, bench.frame.minY, "the order changed")
        XCTAssertTrue(superset("A").exists && superset("B").exists, "the superset survived the reorder")
    }

    func testUnlinkingBeforeSaveLeavesNoSuperset() {
        launch()
        newTemplate("Loose", exercises: ["Bench Press", "Lat Pulldown"])
        app.buttons["Superset with next"].firstMatch.tap()
        let unlink = app.buttons["Break superset"].firstMatch
        XCTAssertTrue(unlink.waitForExistence(timeout: 5))
        unlink.tap()
        XCTAssertTrue(app.buttons["Superset with next"].firstMatch.waitForExistence(timeout: 5))
        app.navigationBars.buttons["Save"].tap()
        let tile = any("templateTile.Loose")
        XCTAssertTrue(tile.waitForExistence(timeout: 5))
        tile.tap()
        XCTAssertTrue(any("templateExercise.Lat Pulldown").waitForExistence(timeout: 5))
        XCTAssertFalse(superset("A").exists, "no superset was saved")
    }

    /// The superset the editor made starts as one in the workout (D48: its members carry the
    /// A/B badge there, and rest waits for the last member).
    func testEditorSupersetStartsLinkedInTheWorkout() {
        launch()
        newTemplate("Linked", exercises: ["Bench Press", "Lat Pulldown"])
        app.buttons["Superset with next"].firstMatch.tap()
        app.navigationBars.buttons["Save"].tap()
        let tile = any("templateTile.Linked")
        XCTAssertTrue(tile.waitForExistence(timeout: 5))
        tile.tap()
        app.buttons["startTemplate"].tap()
        XCTAssertTrue(app.buttons["finishWorkout"].waitForExistence(timeout: 10))
        let badges = app.descendants(matching: .any).matching(identifier: "supersetBadge")
        XCTAssertTrue(badges.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(badges.count, 2, "both members start in the superset")
    }

    func testDirtyCancelAsksBeforeDiscarding() {
        launch()
        let new = app.buttons["New Template…"]
        XCTAssertTrue(new.waitForExistence(timeout: 10))
        new.tap()
        let field = app.textFields["Template name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Scratch\n")
        app.navigationBars.buttons["Cancel"].tap()
        let keep = app.alerts.buttons["Keep Editing"]
        XCTAssertTrue(keep.waitForExistence(timeout: 5), "an edit is not dropped silently")
        keep.tap()
        XCTAssertTrue(field.exists, "Keep Editing stays in the editor")
        app.navigationBars.buttons["Cancel"].tap()
        app.alerts.buttons["Discard Changes"].tap()
        XCTAssertTrue(app.buttons["New Template…"].waitForExistence(timeout: 5))
        XCTAssertFalse(any("templateTile.Scratch").exists, "nothing was saved")
    }

    func testRestBackToDefaultIsSaved() {
        launch(["-uiTestTemplate"])
        let tile = any("templateTile.Whole Body")
        XCTAssertTrue(tile.waitForExistence(timeout: 10))
        tile.tap()
        app.buttons["editTemplate"].tap()

        // Set a time for the first exercise…
        let rest = app.buttons["templateRest"].firstMatch
        XCTAssertTrue(rest.waitForExistence(timeout: 5))
        XCTAssertTrue(((rest.value as? String) ?? "").hasPrefix("Default"))
        rest.tap()
        let stepper = any("templateRestStepper")
        XCTAssertTrue(stepper.waitForExistence(timeout: 5))
        stepper.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        XCTAssertFalse(((rest.value as? String) ?? "").hasPrefix("Default"), "a time is set")
        let authored = rest.value as? String ?? ""
        shoot("floodlight-02-editor-rest-open")
        app.navigationBars.buttons["Save"].tap()
        let row = any("templateExercise.Bench Press")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Rest \(authored)"), "the detail shows the authored rest, got '\(row.label)'")

        // …then back to the exercise's default, saved.
        app.buttons["editTemplate"].tap()
        let again = app.buttons["templateRest"].firstMatch
        XCTAssertTrue(again.waitForExistence(timeout: 5))
        XCTAssertEqual(again.value as? String, authored, "the time was saved")
        again.tap()
        any("templateRestDefault").tap()
        app.navigationBars.buttons["Save"].tap()
        app.buttons["editTemplate"].tap()
        XCTAssertTrue(((app.buttons["templateRest"].firstMatch.value as? String) ?? "").hasPrefix("Default"),
                      "Default was saved")
    }

    func testAppearanceReachesScreensAndSheets() {
        // No `-appearance` argument here: a launch argument overrides the stored setting.
        launch(["-uiTestTemplate"])
        let gear = app.buttons["openSettings"]
        XCTAssertTrue(gear.waitForExistence(timeout: 10))
        gear.tap()
        // The simulator runs light: System follows it; Light and Dark override it.
        for (choice, light) in [("Dark", false), ("System", true), ("Light", true), ("Dark", false)] {
            let picker = app.buttons["appearanceSetting"]
            XCTAssertTrue(picker.waitForExistence(timeout: 5))
            picker.tap()
            app.buttons[choice].firstMatch.tap()
            assertGround(light: light, "Settings in \(choice)")
        }
        // Dark stays for the pushed detail, the editor sheet, the workout's full-screen cover and
        // an alert over it.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let tile = any("templateTile.Whole Body")
        XCTAssertTrue(tile.waitForExistence(timeout: 5))
        tile.tap()
        assertGround(light: false, "template detail in Dark")
        shoot("floodlight-02-detail-dark")
        app.buttons["editTemplate"].tap()
        XCTAssertTrue(app.navigationBars.buttons["Save"].waitForExistence(timeout: 5))
        assertGround(light: false, "editor sheet in Dark")
        shoot("floodlight-02-editor-dark")
        app.navigationBars.buttons["Cancel"].tap()
        app.buttons["startTemplate"].tap()
        XCTAssertTrue(app.buttons["finishWorkout"].waitForExistence(timeout: 10))
        assertGround(light: false, "workout cover in Dark")
        app.buttons["workoutTitle"].tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        assertAlertIsDark()
        shoot("floodlight-02-alert-dark")
        app.alerts.buttons["Cancel"].tap()
    }

    /// The rename alert's panel, sampled at its centre: dark in Dark.
    private func assertAlertIsDark() {
        Thread.sleep(forTimeInterval: 0.6)
        let alert = app.alerts.firstMatch.frame
        let image = app.screenshot().image
        guard let cg = image.cgImage, let data = cg.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else {
            return XCTFail("no pixels")
        }
        let scale = CGFloat(cg.width) / app.frame.width
        // Just inside the panel's top edge, left of centre (clear of the title text).
        let x = Int((alert.minX + 24) * scale), y = Int((alert.minY + 8) * scale)
        let offset = y * cg.bytesPerRow + x * (cg.bitsPerPixel / 8)
        let luminance = (Double(bytes[offset]) + Double(bytes[offset + 1]) + Double(bytes[offset + 2])) / (3 * 255)
        XCTAssertLessThan(luminance, 0.45, "the alert should be dark in Dark, got \(luminance)")
    }

    /// Samples the screen just under the status bar: the ground is near-white in Light
    /// (#F2F3F5) and near-black in Dark (#060708 / #0B0C0E).
    private func assertGround(light: Bool, _ what: String) {
        // The scheme change animates; let it settle.
        Thread.sleep(forTimeInterval: 1.0)
        let image = app.screenshot().image
        guard let cg = image.cgImage, let data = cg.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else {
            return XCTFail("no pixels")
        }
        let x = cg.width / 2, y = Int(Double(cg.height) * 0.075)
        let offset = y * cg.bytesPerRow + x * (cg.bitsPerPixel / 8)
        let luminance = (Double(bytes[offset]) + Double(bytes[offset + 1]) + Double(bytes[offset + 2])) / (3 * 255)
        if light { XCTAssertGreaterThan(luminance, 0.8, "\(what): expected a light ground, got \(luminance)") }
        else { XCTAssertLessThan(luminance, 0.2, "\(what): expected a dark ground, got \(luminance)") }
    }

    // MARK: Captures (the record of the detail and editor in both schemes and sizes)

    func testCaptureDetailAndEditorLightDefault() { captureDetailAndEditor(appearance: "light", large: false) }
    func testCaptureDetailAndEditorLightAccessibility() { captureDetailAndEditor(appearance: "light", large: true) }
    func testCaptureDetailAndEditorDarkDefault() { captureDetailAndEditor(appearance: "dark", large: false) }
    func testCaptureDetailAndEditorDarkAccessibility() { captureDetailAndEditor(appearance: "dark", large: true) }

    private func captureDetailAndEditor(appearance: String, large: Bool) {
        var args = ["-uiTestTemplate", "-uiTestDesignSample", "-appearance", appearance]
        if large { args += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] }
        launch(args)
        let suffix = "\(appearance)-\(large ? "axl" : "default")"
        shoot("floodlight-02-home-\(suffix)")
        let tile = any("templateTile.Whole Body")
        for _ in 0..<6 where !(tile.exists && tile.isHittable) { app.swipeUp() }
        tile.tap()
        XCTAssertTrue(app.buttons["editTemplate"].waitForExistence(timeout: 5))
        shoot("floodlight-02-detail-\(suffix)")
        app.buttons["editTemplate"].tap()
        XCTAssertTrue(app.navigationBars.buttons["Save"].waitForExistence(timeout: 5))
        shoot("floodlight-02-editor-\(suffix)")
        let rest = app.buttons["templateRest"].firstMatch
        if rest.exists && rest.isHittable {
            rest.tap()
            shoot("floodlight-02-editor-rest-\(suffix)")
        }
    }
}
