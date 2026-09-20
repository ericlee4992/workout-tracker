import XCTest

final class CardioUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }
    private func launch(large: Bool = false, sensor: Bool = true) {
        app.launchArguments = ["-uiTestReset"] + (sensor ? ["-uiTestHeartRate"] : [])
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] }
        app.launch()
        app.tabBars.buttons["Workout"].tap()
    }
    private func any(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }
    private func reach(_ element: XCUIElement) {
        func visible() -> Bool {
            guard element.exists && element.isHittable else { return false }
            let controls = app.buttons["cardioPauseResume"]
            if controls.exists && controls.isHittable,
               element.identifier != "cardioPauseResume", element.identifier != "endCardio" {
                return element.frame.maxY < controls.frame.minY - 8
            }
            return true
        }
        for _ in 0..<10 where !visible() {
            if element.exists && element.frame.maxY < 130 { app.swipeDown() }
            else { app.swipeUp() }
        }
        XCTAssertTrue(visible())
    }
    private func openFinishedHistory() {
        // The receipt link is above its metrics/map. Lazy content can remove it
        // from the accessibility tree, so an absent element must scroll upward.
        let history = app.buttons["viewFinishedWorkout"]
        for _ in 0..<10 where !history.exists || !history.isHittable { app.swipeDown() }
        XCTAssertTrue(history.exists && history.isHittable)
        history.tap()
    }
    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func choose(_ kind: String) {
        let option = any("cardioActivity.\(kind)")
        reach(option); option.tap()
        XCTAssertTrue(any("cardioTimer").waitForExistence(timeout: 10))
    }
    private func waitForAutomaticDistance() {
        let measured = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "[0-9]+\\.[0-9]{2}")).firstMatch
        XCTAssertTrue(measured.waitForExistence(timeout: 10))
        reach(app.buttons["addCardio"])
        XCTAssertFalse(app.buttons["cardioEditDistance"].exists)
        XCTAssertFalse(app.staticTexts["HealthKit estimate"].exists)
        XCTAssertFalse(app.staticTexts["Phone motion estimate"].exists)
    }
    private func enterDistance(_ value: String, captureName: String? = nil) {
        let edit = app.buttons["cardioEditDistance"]
        reach(edit); edit.tap()
        let field = app.textFields["cardioDistanceField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        if let captureName { shot(captureName) }
        field.tap()
        let current = (field.value as? String) ?? ""
        if !current.isEmpty, current != "Distance" {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        field.typeText(value)
        app.buttons["saveCardioDistance"].tap()
        XCTAssertTrue(any("cardioTimer").waitForExistence(timeout: 5))
    }
    private func addLiftingSet() {
        let add = app.buttons["addExercise"]
        reach(add); add.tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap(); search.typeText("Seated Chest Press")
        let option = any("exerciseOption.Seated Chest Press")
        XCTAssertTrue(option.waitForExistence(timeout: 5)); option.tap()
        let weight = app.textFields["setRow.weight"].firstMatch
        XCTAssertTrue(weight.waitForExistence(timeout: 5)); weight.tap(); weight.typeText("60")
        let reps = app.textFields["setRow.reps"].firstMatch
        reps.tap(); reps.typeText("10")
        app.buttons["setRow.complete"].firstMatch.tap()
    }

    func testCardioFirstThenLiftingSavesOneMixedWorkout() {
        launch()
        app.buttons["startCardio"].tap()
        choose("indoorRun")
        // Wait for actual fixture distance before asserting that its old source row is gone.
        waitForAutomaticDistance()
        shot("cardio-built-automatic-distance")
        reach(app.buttons["endCardio"]); app.buttons["endCardio"].tap()
        XCTAssertTrue(any("cardioSummary.indoorRun").waitForExistence(timeout: 5))
        reach(app.buttons["cardioSummaryEditDistance"])
        XCTAssertEqual(app.buttons["cardioSummaryEditDistance"].label, "Distance")
        addLiftingSet()
        app.buttons["finishWorkout"].tap()
        XCTAssertTrue(app.buttons["viewFinishedWorkout"].waitForExistence(timeout: 10))
        reach(app.buttons["cardioSummaryEditDistance"])
        XCTAssertEqual(app.buttons["cardioSummaryEditDistance"].label, "Distance")
        openFinishedHistory()
        let summary = any("cardioSummary.indoorRun")
        reach(summary)
        XCTAssertTrue(summary.exists)
        reach(app.buttons["cardioSummaryEditDistance"])
        XCTAssertEqual(app.buttons["cardioSummaryEditDistance"].label, "Distance")
        XCTAssertTrue(app.navigationBars.buttons.firstMatch.exists)
        shot("cardio-built-mixed-history")
    }

    func testLiftingFirstThenManualCardioWithoutWearable() {
        launch(sensor: false)
        app.buttons["startEmptyWorkout"].tap()
        addLiftingSet()
        reach(app.buttons["addCardio"]); app.buttons["addCardio"].tap()
        choose("indoorCycle")
        enterDistance("3")
        reach(app.buttons["cardioPauseResume"]); app.buttons["cardioPauseResume"].tap()
        XCTAssertTrue(app.staticTexts["Paused"].exists)
        app.buttons["minimizeWorkout"].tap()
        XCTAssertTrue(any("resumeWorkout").waitForExistence(timeout: 5)); any("resumeWorkout").tap()
        XCTAssertTrue(app.staticTexts["Paused"].waitForExistence(timeout: 5))
        reach(app.buttons["cardioPauseResume"]); app.buttons["cardioPauseResume"].tap()
        app.buttons["finishWorkout"].tap()
        XCTAssertTrue(app.buttons["finishedDone"].waitForExistence(timeout: 10))
        let summary = any("cardioSummary.indoorCycle"); reach(summary)
        XCTAssertTrue(summary.exists)
        XCTAssertFalse(app.staticTexts["Heart rate"].exists)
        shot("cardio-built-manual-finish")
    }

    func testSavedDistanceEditorKeepsEnteredUnitsAndUntouchedMeasurements() {
        launch()
        app.buttons["startCardio"].tap(); choose("indoorRun")
        waitForAutomaticDistance()
        app.buttons["endCardio"].tap()
        reach(app.buttons["cardioSummaryEditDistance"]); app.buttons["cardioSummaryEditDistance"].tap()
        let field = app.textFields["cardioDistanceField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Measured:")).firstMatch.exists)
        XCTAssertFalse(app.buttons["saveCardioDistance"].isEnabled)
        XCTAssertTrue((field.value as? String) == "Distance" || (field.value as? String) == "")
        field.tap(); field.typeText("5")
        app.segmentedControls["cardioDistanceUnit"].buttons["km"].tap()
        XCTAssertEqual(field.value as? String, "5")
        app.segmentedControls["cardioDistanceUnit"].buttons["mi"].tap()
        XCTAssertEqual(field.value as? String, "5")
        app.buttons["saveCardioDistance"].tap()
        XCTAssertTrue(app.staticTexts["Entered distance"].waitForExistence(timeout: 5))
    }

    func testOutdoorRouteDefaultCapture() { outdoorCapture(large: false) }
    func testOutdoorRouteAccessibilityCapture() { outdoorCapture(large: true) }
    private func outdoorCapture(large: Bool) {
        app.launchArguments = ["-uiTestReset", "-uiTestHeartRate", "-uiTestCardioRoute"]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] }
        app.launch()
        // RootView intentionally restores an unfinished session on launch.
        XCTAssertTrue(any("cardioTimer").waitForExistence(timeout: 10))
        shot("cardio-built-outdoor-\(large ? "axl" : "default")")
        reach(any("cardioDistanceMetric"))
        XCTAssertTrue(app.staticTexts["0.67"].exists, "GPS fixture distance stays in the main metric")
        reach(app.buttons["addCardio"])
        XCTAssertFalse(app.buttons["cardioEditDistance"].exists)
        XCTAssertFalse(app.staticTexts["GPS"].exists)
        XCTAssertFalse(any("cardioRoute").exists)
        shot("cardio-built-outdoor-details-\(large ? "axl" : "default")")
        app.buttons["endCardio"].tap()
        reach(app.buttons["cardioSummaryEditDistance"])
        XCTAssertFalse(any("cardioRoute").exists)
        shot("cardio-built-ended-outdoor-\(large ? "axl" : "default")")
        app.buttons["finishWorkout"].tap()
        XCTAssertTrue(app.buttons["finishedDone"].waitForExistence(timeout: 10))
        reach(any("cardioRoute"))
        shot("cardio-built-finish-route-\(large ? "axl" : "default")")
        openFinishedHistory()
        reach(any("cardioRoute"))
        shot("cardio-built-history-route-\(large ? "axl" : "default")")
    }

    func testIndoorPhoneMotionDefaultCapture() { phoneMotionCapture(large: false) }
    func testIndoorPhoneMotionAccessibilityCapture() { phoneMotionCapture(large: true) }
    private func phoneMotionCapture(large: Bool) {
        app.launchArguments = ["-uiTestReset", "-uiTestIndoorDistance"]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] }
        app.launch()
        XCTAssertTrue(any("cardioTimer").waitForExistence(timeout: 10))
        reach(any("cardioDistanceMetric"))
        XCTAssertTrue(app.staticTexts["1.00"].exists)
        shot("indoor-measured-\(large ? "axl" : "default")")
        reach(app.buttons["addCardio"])
        XCTAssertFalse(app.buttons["cardioEditDistance"].exists)
        XCTAssertFalse(app.staticTexts["Phone motion estimate"].exists)
        shot("indoor-measured-details-\(large ? "axl" : "default")")
        app.buttons["endCardio"].tap()
        reach(app.buttons["cardioSummaryEditDistance"])
        XCTAssertEqual(app.buttons["cardioSummaryEditDistance"].label, "Distance")
    }

    func testCardioDefaultCaptureAndSave() { capture(large: false) }
    func testCardioAccessibilityCaptureAndSave() { capture(large: true) }
    private func capture(large: Bool) {
        launch(large: large)
        shot("cardio-built-start-\(large ? "axl" : "default")")
        app.buttons["startCardio"].tap()
        shot("cardio-built-picker-\(large ? "axl" : "default")")
        choose("indoorRun")
        let size = large ? "axl" : "default"
        waitForAutomaticDistance()
        shot("cardio-built-automatic-\(size)")
        app.swipeDown(); app.swipeDown()
        shot("cardio-built-live-\(size)")
        reach(app.buttons["addCardio"])
        shot("cardio-built-controls-\(size)")
        app.buttons["cardioPauseResume"].tap()
        app.swipeDown(); app.swipeDown()
        XCTAssertTrue(app.staticTexts["Paused"].exists)
        shot("cardio-built-paused-\(size)")
        app.buttons["cardioPauseResume"].tap()
        let lifting = app.segmentedControls["workoutActivityFocus"].buttons["Lifting"]
        reach(lifting); lifting.tap()
        XCTAssertTrue(app.staticTexts["Recording"].exists)
        shot("cardio-built-lifting-banner-\(size)")
        reach(app.buttons["addCardio"]); app.buttons["addCardio"].tap()
        XCTAssertTrue(app.staticTexts["Starting another activity ends the current cardio segment."].waitForExistence(timeout: 5))
        shot("cardio-built-replace-picker-\(size)")
        app.navigationBars["Choose Cardio"].buttons["Cancel"].tap()
        app.buttons["finishWorkout"].tap()
        XCTAssertTrue(app.buttons["finishedDone"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["saveFinishedAsTemplate"].exists)
        shot("cardio-built-finish-\(large ? "axl" : "default")")
        let summary = any("cardioSummary.indoorRun")
        for page in 1...8 {
            app.swipeUp()
            shot("cardio-built-summary-\(large ? "axl" : "default")-\(page)")
            if app.buttons["cardioSummaryEditDistance"].exists && app.buttons["cardioSummaryEditDistance"].isHittable { break }
        }
        XCTAssertTrue(summary.exists)
        XCTAssertTrue(app.buttons["cardioSummaryEditDistance"].isHittable)
    }
}

// Automatic phone-motion values use the same screen as compatible-device readings.
// This fixture verifies presentation only, not physical sensor delivery.
