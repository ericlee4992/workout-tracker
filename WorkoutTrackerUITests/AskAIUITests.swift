import XCTest

final class AskAIUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUp() { continueAfterFailure = false; app = XCUIApplication() }
    private func launch(_ extra: [String] = [], large: Bool = false) {
        app.launchArguments = ["-uiTestReset", "-uiTestTerra"] + extra
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] }
        app.launch()
    }
    private func any(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }
    private func reach(_ element: XCUIElement) {
        for _ in 0..<14 {
            if element.exists && element.isHittable && element.frame.maxY < app.frame.maxY - 85 { return }
            if element.exists && element.frame.minY < 120 { app.swipeDown() } else { app.swipeUp() }
        }
        XCTAssertTrue(element.exists && element.isHittable)
    }
    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func scanner() {
        app.tabBars.buttons["Gyms"].tap(); app.buttons["addGym"].tap()
        let field = app.textFields["gymName"]; XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap(); field.typeText("AI Gym")
        app.buttons["saveGym"].tap()
        let row = any("gymRow.AI Gym"); XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
        app.buttons["addMachine"].tap()
        app.buttons["scanMachineLabel"].tap()
    }
    func testGenericScanConfirmsBeforeSavingDefault() { genericScan(large: false) }
    func testGenericScanConfirmsBeforeSavingAccessibility() { genericScan(large: true) }
    private func genericScan(large: Bool) {
        launch(large: large); scanner()
        let shutter = app.buttons["scanShutter"]; XCTAssertTrue(shutter.waitForExistence(timeout: 5)); shutter.tap()
        let use = app.buttons["scanUseCandidate"]; XCTAssertTrue(use.waitForExistence(timeout: 10))
        shot("ai-scan-proposal-\(large ? "axl" : "default")")
        reach(use); use.tap()
        let label = app.textFields["machineLabel"]; XCTAssertTrue(label.waitForExistence(timeout: 5))
        XCTAssertEqual(label.value as? String, "Chest press")
        app.buttons["saveMachine"].tap()
        XCTAssertTrue(app.staticTexts["Chest press"].firstMatch.waitForExistence(timeout: 5))
    }
    func testScanFailureAndRescanRemainUsable() {
        launch(["-uiTestTerraOffline"]); scanner(); app.buttons["scanShutter"].tap()
        XCTAssertTrue(any("scanAIError").waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["scanShutter"].isEnabled)
        XCTAssertFalse(app.buttons["scanUseCandidate"].exists)
    }
    func testRescanDropsLateAIResponse() {
        launch(["-uiTestTerraSlow"]); scanner(); app.buttons["scanShutter"].tap()
        let rescan = app.buttons["scanRescan"]; XCTAssertTrue(rescan.waitForExistence(timeout: 2)); rescan.tap()
        XCTAssertTrue(app.buttons["scanShutter"].waitForExistence(timeout: 5))
        let noResult = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.buttons["scanUseCandidate"])
        XCTAssertEqual(XCTWaiter.wait(for: [noResult], timeout: 5), .completed)
    }
    func testWeeklyRoutineDefault() { routine(large: false) }
    func testWeeklyRoutineAccessibility() { routine(large: true) }
    private func routine(large: Bool) {
        launch(large: large); app.tabBars.buttons["Workout"].tap()
        let ask = app.buttons["askAIRoutine"]; reach(ask); shot("ai-start-\(large ? "axl" : "default")"); ask.tap()
        let goals = app.textFields["routineGoals"].exists ? app.textFields["routineGoals"] : app.textViews["routineGoals"]
        XCTAssertTrue(goals.waitForExistence(timeout: 5)); goals.tap(); goals.typeText("Build strength and endurance")
        app.swipeUp()
        let dumbbells = any("routineEquipment.dumbbells"); reach(dumbbells); dumbbells.tap()
        shot("ai-routine-inputs-\(large ? "axl" : "default")")
        let walk = any("routineCardio.outdoorWalk"); reach(walk); walk.tap()
        let generate = app.buttons["generateAIRoutine"]; reach(generate); generate.tap()
        let day = any("routineDay.0"); XCTAssertTrue(day.waitForExistence(timeout: 10))
        shot("ai-week-preview-\(large ? "axl" : "default")")
        day.tap(); shot("ai-day-edit-\(large ? "axl" : "default")")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["saveAIRoutine"].tap()
        let tile = app.buttons["templateTile.Day 1 — Fitness"]; XCTAssertTrue(tile.waitForExistence(timeout: 10)); reach(tile); tile.tap()
        shot("ai-template-detail-\(large ? "axl" : "default")")
        app.buttons["startTemplate"].tap()
        let start = app.buttons["startPlannedCardio"]; XCTAssertTrue(start.waitForExistence(timeout: 10)); reach(start)
        shot("ai-planned-cardio-\(large ? "axl" : "default")")
        XCTAssertFalse(any("cardioTimer").exists)
        start.tap()
        XCTAssertTrue(any("cardioTimer").waitForExistence(timeout: 10))
    }
    func testMissingKeyHasReachableSettings() {
        app.launchArguments = ["-uiTestReset"]; app.launch(); app.tabBars.buttons["Workout"].tap()
        reach(app.buttons["askAIRoutine"]); app.buttons["askAIRoutine"].tap()
        let settings = app.buttons["routineAISettings"]; XCTAssertTrue(settings.waitForExistence(timeout: 5)); settings.tap()
        XCTAssertTrue(app.secureTextFields["askAIKeyField"].waitForExistence(timeout: 5))
        shot("ai-key-settings-default")
    }
}
