import XCTest

// Floodlight redesign ticket 10: Ask AI for Templates as stepped screens — Goals (A01), Equipment
// (A02, with consent off), Generating (A03), the error step, Your week (A04), Edit session (A05 with an
// open card, the undo bar and the exercise picker), the discard confirmation and the Saved step — on
// record in light and dark at Default and AccessibilityL, on the design sample (Iron Temple and its
// machines) with the Terra fixture; then the flows the steps carry.
final class FloodlightAIRoutineUITests: XCTestCase {
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

    private func launch(appearance: String = "light", large: Bool = false, extra: [String] = []) {
        app.launchArguments = ["-uiTestReset", "-uiTestTerra", "-uiTestTerraFullRoutine", "-uiTestDesignSample",
                               "-uiTestDesignGyms", "-appearance", appearance] + extra
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] }
        app.launch()
        app.tabBars.buttons["Workout"].tap()
        let ask = app.buttons["askAIRoutine"]
        XCTAssertTrue(ask.waitForExistence(timeout: 15))
        for _ in 0..<8 where !(ask.isHittable && ask.frame.maxY < app.tabBars.firstMatch.frame.minY - 8) { app.swipeUp() }
        ask.tap()
        XCTAssertTrue(any("routineGoals").waitForExistence(timeout: 10))
    }

    /// The pinned bars: content must be between the top bar and the bottom bar to be tapped.
    private func visible(_ element: XCUIElement) -> Bool {
        let bottom = [any("routineNext"), any("generateAIRoutine"), any("routineAISettings"), any("saveAIRoutine")]
            .first { $0.exists }.map { $0.frame.minY - 12 } ?? app.frame.maxY - 30
        return element.exists && element.isHittable && element.frame.minY > 150 && element.frame.maxY < bottom
    }

    private func reach(_ element: XCUIElement, limit: Int = 12) {
        for _ in 0..<limit where !visible(element) {
            let down = element.exists && element.frame.minY < 150
            let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: down ? 0.35 : 0.6))
            let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: down ? 0.6 : 0.35))
            from.press(forDuration: 0.05, thenDragTo: to)
        }
        XCTAssertTrue(visible(element), "reached \(element)")
    }

    /// Swipes up until `element` is on screen, shooting each page after the first under `name`.
    private func page(to element: XCUIElement, name: String, limit: Int = 8) {
        var page = 2
        while !visible(element), page <= limit + 1 {
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.6)
            shoot("\(name)-\(page)")
            page += 1
        }
        XCTAssertTrue(visible(element), "\(name): reached \(element)")
    }

    private func fillGoals() {
        any("routineGoalPhrase.0").tap()
        XCTAssertEqual(app.textViews["routineGoals"].exists ? app.textViews["routineGoals"].value as? String
                       : app.textFields["routineGoals"].value as? String, "Build strength.")
    }

    // MARK: Captures

    func testCaptureAIRoutineLightDefault() { capture(appearance: "light", large: false) }
    func testCaptureAIRoutineLightAccessibility() { capture(appearance: "light", large: true) }
    func testCaptureAIRoutineDarkDefault() { capture(appearance: "dark", large: false) }
    func testCaptureAIRoutineDarkAccessibility() { capture(appearance: "dark", large: true) }

    private func capture(appearance: String, large: Bool) {
        launch(appearance: appearance, large: large, extra: ["-uiTestTerraSlow", "-uiTestTerraNeedsConsent"])
        let suffix = "\(appearance)-\(large ? "axl" : "default")"

        // A01: empty, then a goal from a chip, Intermediate, four days.
        Thread.sleep(forTimeInterval: 0.8)
        shoot("floodlight-10-a01-empty-\(suffix)")
        fillGoals()
        let intermediate = any("routineExperience.Intermediate")
        reach(intermediate); intermediate.tap()
        let four = any("routineDays.4")
        reach(four); four.tap()
        for _ in 0..<4 { app.swipeDown() }
        Thread.sleep(forTimeInterval: 0.6)
        shoot("floodlight-10-a01-\(suffix)-1")
        page(to: any("routineWeight"), name: "floodlight-10-a01-\(suffix)")
        any("routineNext").tap()

        // A02: the gym, machines, tiles, consent off; then consent on.
        let consent = app.switches["allowAIRoutine"].firstMatch
        XCTAssertTrue(any("routineMachineCount").waitForExistence(timeout: 5))
        let dumbbells = any("routineEquipment.dumbbells")
        reach(dumbbells); dumbbells.tap()
        let walk = any("routineCardio.outdoorWalk")
        reach(walk); walk.tap()
        for _ in 0..<4 { app.swipeDown() }
        Thread.sleep(forTimeInterval: 0.6)
        shoot("floodlight-10-a02-\(suffix)-1")
        page(to: consent, name: "floodlight-10-a02-\(suffix)")
        XCTAssertEqual(consent.value as? String, "0")
        shoot("floodlight-10-a02-consentoff-\(suffix)")
        consent.tap()
        XCTAssertEqual(consent.value as? String, "1")

        // A03: generating (the fixture takes 4 s), at the last stage.
        any("generateAIRoutine").tap()
        XCTAssertTrue(any("routineProgress").waitForExistence(timeout: 5))
        // The last stage (90 %) starts at 2.5 s; the fixture replies at 4 s.
        Thread.sleep(forTimeInterval: 2.6)
        shoot("floodlight-10-a03-\(suffix)")

        // A04: your week.
        let day0 = any("routineDay.0")
        XCTAssertTrue(day0.waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 1.4)
        shoot("floodlight-10-a04-\(suffix)-1")
        page(to: any("routineChangePreferences"), name: "floodlight-10-a04-\(suffix)")
        for _ in 0..<6 { app.swipeDown() }

        // A05: a session; an open card; a removal's undo bar; the picker.
        reach(day0); day0.tap()
        let item0 = any("routineItem.0")
        XCTAssertTrue(item0.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8)
        shoot("floodlight-10-a05-\(suffix)-1")
        item0.tap()
        let remove = app.buttons["routineRemoveItem"]
        XCTAssertTrue(remove.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.6)
        shoot("floodlight-10-a05-open-\(suffix)")
        reach(remove); remove.tap()
        XCTAssertTrue(app.buttons["routineUndo"].waitForExistence(timeout: 3))
        shoot("floodlight-10-a05-undo-\(suffix)")
        app.buttons["routineUndo"].tap()
        let add = any("routineAddExercise")
        reach(add); add.tap()
        XCTAssertTrue(any("routinePickerSearch").waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.0)
        shoot("floodlight-10-a05-picker-\(suffix)")
        app.buttons["routinePickerCancel"].tap()
        XCTAssertTrue(any("routinePickerSearch").waitForNonExistence(timeout: 5))
        page(to: any("routineAddCardio"), name: "floodlight-10-a05-\(suffix)")
        any("routineBack").tap()

        // Leaving an unsaved week asks first.
        XCTAssertTrue(day0.waitForExistence(timeout: 5))
        any("routineCancel").tap()
        let keep = app.buttons["Keep Editing"].firstMatch
        let discard = app.buttons["Discard Week"].firstMatch
        XCTAssertTrue(discard.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8)
        shoot("floodlight-10-a04-discard-\(suffix)")
        if keep.exists && keep.isHittable { keep.tap() } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        }
        XCTAssertTrue(discard.waitForNonExistence(timeout: 5))

        // Saved.
        any("saveAIRoutine").tap()
        XCTAssertTrue(any("routineSavedDone").waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 1.6)
        shoot("floodlight-10-saved-\(suffix)")

        // The error step (offline).
        app.terminate()
        launch(appearance: appearance, large: large, extra: ["-uiTestTerraOffline"])
        fillGoals()
        any("routineNext").tap()
        let dumbbellsAgain = any("routineEquipment.dumbbells")
        reach(dumbbellsAgain); dumbbellsAgain.tap()
        any("generateAIRoutine").tap()
        XCTAssertTrue(any("routineRetry").waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 0.8)
        shoot("floodlight-10-error-\(suffix)")
    }

    // MARK: Flows

    private func toWeek() {
        fillGoals()
        any("routineNext").tap()
        let dumbbells = any("routineEquipment.dumbbells")
        XCTAssertTrue(dumbbells.waitForExistence(timeout: 5))
        reach(dumbbells); dumbbells.tap()
        any("generateAIRoutine").tap()
        XCTAssertTrue(any("routineDay.0").waitForExistence(timeout: 10))
    }

    /// Cancels a confirmation dialog: iOS 27 draws it without a cancel button (a tap outside cancels).
    private func keepEditing() {
        let keep = app.buttons["Keep Editing"].firstMatch
        if keep.exists && keep.isHittable { keep.tap() } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        }
        XCTAssertTrue(app.buttons["Discard Week"].firstMatch.waitForNonExistence(timeout: 5))
    }

    /// Back keeps every input; leaving a generated week asks first, and Keep Editing keeps it.
    func testBackKeepsInputsAndLeavingTheWeekAsksFirst() {
        launch()
        fillGoals()
        let intermediate = any("routineExperience.Intermediate")
        reach(intermediate); intermediate.tap()
        any("routineNext").tap()
        let dumbbells = any("routineEquipment.dumbbells")
        XCTAssertTrue(dumbbells.waitForExistence(timeout: 5))
        reach(dumbbells); dumbbells.tap()
        any("routineBack").tap()
        XCTAssertTrue(any("routineGoals").waitForExistence(timeout: 5))
        XCTAssertTrue(any("routineGoalPhrase.0").isSelected, "the goal is kept")
        reach(intermediate)
        XCTAssertTrue(intermediate.isSelected, "the experience is kept")
        any("routineNext").tap()
        reach(dumbbells)
        XCTAssertTrue(dumbbells.isSelected, "the equipment is kept")
        any("generateAIRoutine").tap()
        XCTAssertTrue(any("routineDay.0").waitForExistence(timeout: 10))

        // Back, Change preferences and Cancel each ask; Keep Editing keeps the week.
        any("routineBack").tap()
        XCTAssertTrue(app.buttons["Discard Week"].firstMatch.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.6); keepEditing()
        XCTAssertTrue(any("routineDay.0").exists)
        let change = any("routineChangePreferences")
        reach(change); change.tap()
        let discard = app.buttons["Discard Week"].firstMatch
        XCTAssertTrue(discard.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.6); discard.tap()
        XCTAssertTrue(any("routineGoals").waitForExistence(timeout: 5), "Change preferences starts again at Goals")
        XCTAssertTrue(any("routineGoalPhrase.0").isSelected, "with the inputs kept")
        // No week now: Cancel closes at once.
        any("routineCancel").tap()
        XCTAssertTrue(app.buttons["askAIRoutine"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Discard Week"].exists)
    }

    /// A failed request shows the error step; Back to preferences returns to Equipment with the choices.
    func testErrorStepReturnsToEquipment() {
        launch(extra: ["-uiTestTerraOffline"])
        fillGoals()
        any("routineNext").tap()
        let dumbbells = any("routineEquipment.dumbbells")
        XCTAssertTrue(dumbbells.waitForExistence(timeout: 5))
        reach(dumbbells); dumbbells.tap()
        any("generateAIRoutine").tap()
        let error = any("routineAIError")
        XCTAssertTrue(error.waitForExistence(timeout: 10))
        XCTAssertTrue(error.label.contains("Could not reach OpenAI."), error.label)
        XCTAssertTrue(any("routineRetry").isEnabled)
        any("routineErrorBack").tap()
        XCTAssertTrue(dumbbells.waitForExistence(timeout: 5))
        reach(dumbbells)
        XCTAssertTrue(dumbbells.isSelected)
    }

    /// Saved: the tiles are the new templates; a tile closes the flow and opens its template.
    func testSavedTileOpensItsTemplate() {
        launch()
        toWeek()
        any("saveAIRoutine").tap()
        let tile = any("routineSavedTemplate.Day 2 — Fitness")
        XCTAssertTrue(tile.waitForExistence(timeout: 10))
        XCTAssertTrue(any("routineSavedTitle").label.hasPrefix("3 templates saved"))
        reach(tile); tile.tap()
        XCTAssertTrue(app.buttons["startTemplate"].waitForExistence(timeout: 10), "the template's detail opened")
        XCTAssertTrue(app.staticTexts["Day 2 — Fitness"].firstMatch.exists)
    }

    /// Removing an exercise can be undone; the session's figures follow.
    func testUndoRestoresARemovedExercise() {
        launch()
        toWeek()
        any("routineDay.0").tap()
        let first = any("routineItem.0")
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        let count = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'routineItem.'")).count
        let name = first.label
        first.tap()
        let remove = app.buttons["routineRemoveItem"]
        XCTAssertTrue(remove.waitForExistence(timeout: 5))
        reach(remove); remove.tap()
        let undo = app.buttons["routineUndo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 3))
        XCTAssertEqual(app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'routineItem.'")).count,
                       count - 1)
        undo.tap()
        let restored = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", name), object: any("routineItem.0"))
        XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 5), .completed, "the exercise is back in its place")
    }
}
