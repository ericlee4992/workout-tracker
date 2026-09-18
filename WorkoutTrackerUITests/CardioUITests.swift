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
    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func choose(_ kind: String) {
        let option = any("cardioActivity.\(kind)")
        reach(option); option.tap()
        XCTAssertTrue(any("cardioTimer").waitForExistence(timeout: 10))
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
        // The fixture emits measured distance through the same provider interface.
        let source = app.staticTexts["HealthKit estimate"].firstMatch
        for _ in 0..<4 where !source.exists { app.swipeUp() }
        XCTAssertTrue(source.waitForExistence(timeout: 10))
        enterDistance("1.25")
        reach(app.buttons["endCardio"]); app.buttons["endCardio"].tap()
        XCTAssertTrue(any("cardioSummary.indoorRun").waitForExistence(timeout: 5))
        addLiftingSet()
        app.buttons["finishWorkout"].tap()
        XCTAssertTrue(app.buttons["viewFinishedWorkout"].waitForExistence(timeout: 10))
        app.buttons["viewFinishedWorkout"].tap()
        let summary = any("cardioSummary.indoorRun")
        reach(summary)
        XCTAssertTrue(summary.exists)
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

    func testDistanceEditorDoesNotFreezeAnUntouchedMeasurementOrRewriteTypedUnits() {
        launch()
        app.buttons["startCardio"].tap(); choose("indoorRun")
        reach(app.buttons["cardioEditDistance"]); app.buttons["cardioEditDistance"].tap()
        let field = app.textFields["cardioDistanceField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
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
        let route = any("cardioRoute"); reach(route)
        shot("cardio-built-route-\(large ? "axl" : "default")")
        app.buttons["finishWorkout"].tap()
        XCTAssertTrue(app.buttons["finishedDone"].waitForExistence(timeout: 10))
        app.buttons["viewFinishedWorkout"].tap()
        reach(any("cardioRoute"))
        shot("cardio-built-history-route-\(large ? "axl" : "default")")
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
        enterDistance("0.03", captureName: "cardio-built-editor-\(size)")
        app.swipeDown(); app.swipeDown()
        shot("cardio-built-live-\(large ? "axl" : "default")")
        reach(app.buttons["cardioEditDistance"])
        shot("cardio-built-controls-\(large ? "axl" : "default")")
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
        app.buttons["Cancel"].tap()
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
