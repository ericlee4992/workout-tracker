import XCTest

// Public beta ticket 05 (UI-first): the Settings Account row (signed in and out), the profile page (with and without a
// training profile), the training-profile editor, and Ask AI prefilled from the profile with "Save to my training
// profile" — on sample data, in light and dark at Default and AccessibilityL.
final class FloodlightProfileUITests: XCTestCase {
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

    private func any(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func launch(appearance: String, large: Bool, flags: [String]) {
        app.launchArguments = ["-uiTestReset", "-uiTestDesignSample", "-uiTestDesignGyms", "-uiTestTerra",
                               "-appearance", appearance] + flags
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] }
        app.launch()
        app.tabBars.buttons["Workout"].tap()
    }

    private func openSettings() {
        let gear = app.buttons["openSettings"]
        XCTAssertTrue(gear.waitForExistence(timeout: 15))
        gear.tap()
        XCTAssertTrue(any("settingsAccount").waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 0.8)
    }

    private func onScreen(_ element: XCUIElement, floor: CGFloat? = nil) -> Bool {
        let limit = floor ?? (app.tabBars.firstMatch.exists ? app.tabBars.firstMatch.frame.minY - 8 : app.frame.maxY - 20)
        return element.exists && element.isHittable && element.frame.maxY < limit
    }

    /// Shoots the first page, then drags up and shoots until `last` is on screen.
    private func pages(_ name: String, until last: XCUIElement, inSheet: Bool = false, limit: Int = 8) {
        shoot("\(name)-1")
        var page = 2
        while !onScreen(last, floor: inSheet ? app.frame.maxY - 20 : nil), page <= limit + 1 {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)))
            Thread.sleep(forTimeInterval: 0.6)
            shoot("\(name)-\(page)")
            page += 1
        }
        XCTAssertTrue(last.exists && last.isHittable, "\(name): reached \(last)")
    }

    func testCaptureProfileLightDefault() { capture(appearance: "light", large: false) }
    func testCaptureProfileLightAccessibility() { capture(appearance: "light", large: true) }
    func testCaptureProfileDarkDefault() { capture(appearance: "dark", large: false) }
    func testCaptureProfileDarkAccessibility() { capture(appearance: "dark", large: true) }

    private func capture(appearance: String, large: Bool) {
        let suffix = "\(appearance)-\(large ? "axl" : "default")"

        // Settings, signed out: the Account row says Sign In.
        launch(appearance: appearance, large: large, flags: ["-uiTestProfileSignedOut"])
        openSettings()
        shoot("profile-settings-signedout-\(suffix)")
        app.terminate()

        // Signed in: the row, the page, the editor.
        launch(appearance: appearance, large: large, flags: ["-uiTestProfileSample"])
        openSettings()
        shoot("profile-settings-signedin-\(suffix)")
        any("settingsAccount").tap()
        XCTAssertTrue(any("profileAIUse.scan-machine").waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8)
        pages("profile-page-\(suffix)", until: app.buttons["profileDeleteAccount"])

        // The editor, from Edit.
        for _ in 0..<6 { app.swipeDown() }
        let edit = app.buttons["Edit"].firstMatch
        for _ in 0..<6 where !onScreen(edit) { app.swipeUp() }
        edit.tap()
        XCTAssertTrue(app.buttons["trainingSave"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["trainingSave"].isEnabled, "Save waits for a change")
        Thread.sleep(forTimeInterval: 1.0)
        pages("profile-editor-\(suffix)", until: any("trainingWeight"), inSheet: true)
        app.terminate()

        // No training profile yet.
        launch(appearance: appearance, large: large, flags: ["-uiTestProfileNoTraining"])
        openSettings()
        any("settingsAccount").tap()
        XCTAssertTrue(any("profileSetUpTraining").waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8)
        pages("profile-notraining-\(suffix)", until: any("profileSetUpTraining"))
        app.terminate()

        // Ask AI for Templates prefilled from the profile, with the option the user decides on.
        launch(appearance: appearance, large: large, flags: ["-uiTestProfileSample"])
        let ask = app.buttons["askAIRoutine"]
        XCTAssertTrue(ask.waitForExistence(timeout: 15))
        for _ in 0..<8 where !(ask.isHittable && ask.frame.maxY < app.tabBars.firstMatch.frame.minY - 8) { app.swipeUp() }
        ask.tap()
        XCTAssertTrue(any("routineGoals").waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 1.0)
        pages("profile-askai-\(suffix)", until: any("routineSaveToProfile"), inSheet: true)
    }

    // MARK: Ticket 05 — Ask AI prefilled, and the save switch

    private func openAskAI() {
        app.tabBars.buttons["Workout"].tap()
        let ask = app.buttons["askAIRoutine"]
        XCTAssertTrue(ask.waitForExistence(timeout: 15))
        for _ in 0..<8 where !(ask.isHittable && ask.frame.maxY < app.tabBars.firstMatch.frame.minY - 8) { app.swipeUp() }
        ask.tap()
        XCTAssertTrue(any("routineGoals").waitForExistence(timeout: 10))
    }

    private func onFlowScreen(_ element: XCUIElement) -> Bool {
        let next = app.buttons["routineNext"]
        let floor = next.exists ? next.frame.minY - 12 : app.frame.maxY - 30
        return element.exists && element.isHittable && element.frame.minY > 150 && element.frame.maxY < floor
    }

    private func reachInFlow(_ element: XCUIElement) {
        for _ in 0..<10 where !onFlowScreen(element) {
            let down = element.exists && element.frame.minY <= 150
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: down ? 0.35 : 0.6))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: down ? 0.6 : 0.35)))
        }
        XCTAssertTrue(onFlowScreen(element), "reached \(element)")
    }

    /// Generate week (the Terra fixture answers), then back to the profile page's schedule line.
    private func generateThenReadSchedule() -> Bool {
        app.buttons["routineNext"].tap()
        let dumbbells = any("routineEquipment.dumbbells")
        XCTAssertTrue(dumbbells.waitForExistence(timeout: 5))
        let generate = app.buttons["generateAIRoutine"]
        for _ in 0..<8 where !(dumbbells.isHittable && dumbbells.frame.maxY < generate.frame.minY - 12) { app.swipeUp() }
        dumbbells.tap()
        generate.tap()
        XCTAssertTrue(any("routineDay.0").waitForExistence(timeout: 12))
        any("routineCancel").tap()
        let discard = app.buttons["Discard Week"].firstMatch
        XCTAssertTrue(discard.waitForExistence(timeout: 5))
        discard.tap()
        XCTAssertTrue(any("routineDay.0").waitForNonExistence(timeout: 5))
        openSettings()
        any("settingsAccount").tap()
        XCTAssertTrue(any("profileTraining").waitForExistence(timeout: 5))
        return app.staticTexts["3 days · 45 min"].exists
    }

    /// Ticket 05: Ask AI opens filled in from the training profile, with the switch on; a changed day count is saved
    /// to the profile when the week is requested.
    func testAskAIPrefillsAndSavesToTheTrainingProfile() {
        launch(appearance: "light", large: false, flags: ["-uiTestProfileSample"])
        openAskAI()
        let goals = app.textViews["routineGoals"].exists ? app.textViews["routineGoals"] : app.textFields["routineGoals"]
        XCTAssertEqual(goals.value as? String, "Build strength. Get back to a bodyweight pull-up by spring.")
        XCTAssertEqual(any("routineDays").value as? String, "4", "the profile's four days")
        let toggle = app.switches["routineSaveToProfile"].firstMatch
        reachInFlow(toggle)
        XCTAssertEqual(toggle.value as? String, "1", "on by default")
        XCTAssertTrue(app.staticTexts["Filled in from your training profile."].exists)
        let three = any("routineDays.3")
        reachInFlow(three)
        three.tap()
        XCTAssertTrue(generateThenReadSchedule(), "the profile now says 3 days")
    }

    /// …and with the switch off the profile is left as it was.
    func testAskAIWithTheSwitchOffLeavesTheProfile() {
        launch(appearance: "light", large: false, flags: ["-uiTestProfileSample"])
        openAskAI()
        let three = any("routineDays.3")
        reachInFlow(three)
        three.tap()
        let toggle = app.switches["routineSaveToProfile"].firstMatch
        reachInFlow(toggle)
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(toggle.value as? String, "0")
        XCTAssertFalse(generateThenReadSchedule(), "still 4 days")
        XCTAssertTrue(app.staticTexts["4 days · 45 min"].exists)
    }

    /// codex-review-05d F2: a failed profile save does not hold up the week, and Your week says so.
    func testAFailedProfileSaveIsShownWithTheWeek() {
        launch(appearance: "light", large: false, flags: ["-uiTestProfileSample", "-uiTestProfileSaveFails"])
        openAskAI()
        let three = any("routineDays.3")
        reachInFlow(three)
        three.tap()
        app.buttons["routineNext"].tap()
        let dumbbells = any("routineEquipment.dumbbells")
        XCTAssertTrue(dumbbells.waitForExistence(timeout: 5))
        let generate = app.buttons["generateAIRoutine"]
        for _ in 0..<8 where !(dumbbells.isHittable && dumbbells.frame.maxY < generate.frame.minY - 12) { app.swipeUp() }
        dumbbells.tap()
        generate.tap()
        XCTAssertTrue(any("routineDay.0").waitForExistence(timeout: 12), "the week still arrives")
        XCTAssertTrue(any("routineProfileSaveFailed").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Couldn't save to your training profile."].exists)
    }

    /// codex-review-05 #2: a decimal weight is typed, saved and shown as entered, not rounded.
    func testEditorKeepsADecimalWeightAsTyped() {
        launch(appearance: "dark", large: false, flags: ["-uiTestProfileSample"])
        openSettings()
        any("settingsAccount").tap()
        let edit = app.buttons["Edit"].firstMatch
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        let weight = app.textFields["trainingWeight"]
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        for _ in 0..<6 where !onScreen(weight, floor: app.frame.maxY - 20) {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)))
        }
        weight.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8)
        weight.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 5) + "82.5")
        XCTAssertEqual(weight.value as? String, "82.5", "the field keeps the decimal while typing")
        app.buttons["trainingSave"].tap()
        XCTAssertTrue(app.staticTexts["82.5 lb"].waitForExistence(timeout: 5), "the page shows it as entered")
    }

    private func openEditor() {
        launch(appearance: "dark", large: false, flags: ["-uiTestProfileSample"])
        openSettings()
        any("settingsAccount").tap()
        let edit = app.buttons["Edit"].firstMatch
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        XCTAssertTrue(app.buttons["trainingSave"].waitForExistence(timeout: 5))
        let feet = app.textFields["trainingHeightFeet"]
        for _ in 0..<6 where !onScreen(feet, floor: app.frame.maxY - 20) {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)))
        }
    }

    /// Taps at the field's trailing edge so the cursor is after the text (a tap in the middle of a one-character
    /// field put it before, and the deletes removed nothing).
    private func replace(_ field: XCUIElement, with text: String) {
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.6)
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6) + text)
    }

    /// codex-review-05b #1: replacing the feet keeps the inches the editor shows; the page gets both.
    func testReplacingFeetKeepsTheInches() {
        openEditor()
        replace(app.textFields["trainingHeightFeet"], with: "6")
        XCTAssertEqual(app.textFields["trainingHeightFeet"].value as? String, "6")
        XCTAssertEqual(app.textFields["trainingHeightInches"].value as? String, "10")
        XCTAssertTrue(app.buttons["trainingSave"].isEnabled)
        app.buttons["trainingSave"].tap()
        XCTAssertTrue(app.staticTexts["6 ft 10 in"].waitForExistence(timeout: 5))
    }

    /// codex-review-05b #2: 12 inches is not an entry — Save stays off rather than saving something else; clearing
    /// both fields clears the height.
    func testTwelveInchesKeepsSaveOffAndClearingBothClearsTheHeight() {
        openEditor()
        let save = app.buttons["trainingSave"]
        replace(app.textFields["trainingHeightInches"], with: "12")
        XCTAssertFalse(save.isEnabled, "12 in is refused, not clamped")
        replace(app.textFields["trainingHeightInches"], with: "")
        replace(app.textFields["trainingHeightFeet"], with: "")
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(app.staticTexts["Not set"].waitForExistence(timeout: 5), "the height was cleared")
    }
}
