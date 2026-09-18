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
        for _ in 0..<8 where !(element.exists && element.isHittable) { app.swipeUp() }
        XCTAssertTrue(element.exists && element.isHittable)
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
    private func enterDistance(_ value: String) {
        let edit = app.buttons["cardioEditDistance"]
        reach(edit); edit.tap()
        let field = app.textFields["cardioDistanceField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
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

    func testCardioDefaultCaptureAndSave() { capture(large: false) }
    func testCardioAccessibilityCaptureAndSave() { capture(large: true) }
    private func capture(large: Bool) {
        launch(large: large)
        shot("cardio-built-start-\(large ? "axl" : "default")")
        app.buttons["startCardio"].tap()
        shot("cardio-built-picker-\(large ? "axl" : "default")")
        choose("indoorRun")
        enterDistance("2.40")
        app.swipeDown(); app.swipeDown()
        shot("cardio-built-live-\(large ? "axl" : "default")")
        reach(app.buttons["cardioPauseResume"])
        shot("cardio-built-controls-\(large ? "axl" : "default")")
        app.buttons["cardioPauseResume"].tap()
        app.buttons["finishWorkout"].tap()
        XCTAssertTrue(app.buttons["finishedDone"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["saveFinishedAsTemplate"].exists)
        shot("cardio-built-finish-\(large ? "axl" : "default")")
        let summary = any("cardioSummary.indoorRun"); reach(summary)
        shot("cardio-built-summary-\(large ? "axl" : "default")")
    }
}
