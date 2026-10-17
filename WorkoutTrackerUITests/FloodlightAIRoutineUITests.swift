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

    private var goalsField: XCUIElement {
        app.textViews["routineGoals"].exists ? app.textViews["routineGoals"] : app.textFields["routineGoals"]
    }

    // Public beta 13: neither path may depend on the keyboard toolbar appearing on the phone.
    func testGoalsReturnDismissesWithoutANewline() {
        launch()
        let goals = goalsField
        goals.tap()
        assertSoftwareKeyboard()
        goals.typeText("Get stronger\n")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertEqual(goalsField.value as? String, "Get stronger")
        XCTAssertTrue(app.buttons["routineNext"].isHittable)
    }

    func testGoalsDoneRevealsPinnedNext() {
        launch()
        let next = app.buttons["routineNext"]
        let restingFrame = next.frame
        // The quiet Next still focuses an empty goal.
        next.tap()
        assertSoftwareKeyboard()
        // Read once settled: after typing, the simulator can report this keyboard's frame below the screen again.
        let keyboardTop = app.keyboards.firstMatch.frame.minY
        goalsField.typeText("Get stronger")
        XCTAssertTrue(next.exists)
        XCTAssertEqual(next.frame.minY, restingFrame.minY, accuracy: 1, "Next stays at the screen bottom")
        XCTAssertGreaterThanOrEqual(next.frame.minY, keyboardTop - 64, "the settled keyboard covers Next")
        assertFieldAboveDone(goalsField)
        app.buttons["dismissRoutineKeyboard"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.buttons["dismissRoutineKeyboard"].exists)
        XCTAssertTrue(next.isHittable)
        XCTAssertEqual(goalsField.value as? String, "Get stronger")
        next.tap()
        XCTAssertTrue(any("routineGym").waitForExistence(timeout: 5))
    }

    func testGoalsNumberPadsHaveAppDone() {
        launch()
        let height = app.textFields["routineHeightFeet"].exists
            ? app.textFields["routineHeightFeet"] : app.textFields["routineHeight"]
        for (field, value) in [(height, "6"), (app.textFields["routineWeight"], "180")] {
            reach(field)
            field.tap()
            assertSoftwareKeyboard()
            field.typeText(value)
            assertFieldAboveDone(field)
            app.buttons["dismissRoutineKeyboard"].tap()
            XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
            XCTAssertEqual(field.value as? String, value)
            XCTAssertTrue(app.buttons["routineNext"].isHittable)
        }
    }

    private func assertSoftwareKeyboard() {
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.keys.firstMatch.waitForExistence(timeout: 5),
                      "Require software keys, not just a hardware-keyboard accessory")
        XCTAssertGreaterThan(app.keyboards.firstMatch.frame.height, 200)
        // Measure only once the keyboard has risen: mid-animation its frame can still start below the screen.
        let keyboard = app.keyboards.firstMatch
        for _ in 0..<15 where keyboard.frame.minY > app.frame.maxY - 200 { Thread.sleep(forTimeInterval: 0.2) }
        XCTAssertLessThan(keyboard.frame.minY, app.frame.maxY - 200, "the keyboard settled on screen: \(keyboard.frame)")
        Thread.sleep(forTimeInterval: 0.4)
    }

    private func assertFieldAboveDone(_ field: XCUIElement) {
        let done = app.buttons["dismissRoutineKeyboard"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "dismissRoutineKeyboard").count, 1)
        XCTAssertTrue(done.isHittable)
        XCTAssertTrue(field.isHittable)
        XCTAssertGreaterThan(field.frame.height, 0)
        XCTAssertGreaterThanOrEqual(field.frame.minY, app.buttons["routineCancel"].frame.maxY)
        // The whole field sits above Done; only the capsule's glass edge may touch its last 4 pt (measured: 3 pt).
        XCTAssertLessThanOrEqual(field.frame.maxY, done.frame.minY + 4, "focused field: \(field.frame), Done: \(done.frame)")
        // The keyboard's reported frame starts below its suggestion strip (about 44 pt on iOS 27), so Done, which
        // sits on the visible keyboard, measures up to about 60 pt above that edge.
        XCTAssertLessThanOrEqual(done.frame.maxY, app.keyboards.firstMatch.frame.minY)
        XCTAssertLessThanOrEqual(app.keyboards.firstMatch.frame.minY - done.frame.maxY, 64)
    }

    func testCaptureGoalsKeyboardLightDefault() { captureGoalsKeyboard(appearance: "light", large: false) }
    func testCaptureGoalsKeyboardDarkDefault() { captureGoalsKeyboard(appearance: "dark", large: false) }
    func testCaptureGoalsKeyboardLightAccessibility() { captureGoalsKeyboard(appearance: "light", large: true) }
    func testCaptureGoalsKeyboardDarkAccessibility() { captureGoalsKeyboard(appearance: "dark", large: true) }

    /// The whole screen: an app screenshot leaves out the keyboard, which is drawn in its own window.
    private func shootScreen(_ name: String) {
        Thread.sleep(forTimeInterval: 1.0)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func captureGoalsKeyboard(appearance: String, large: Bool) {
        launch(appearance: appearance, large: large)
        let suffix = "\(appearance)-\(large ? "axl" : "default")"
        goalsField.tap()
        assertSoftwareKeyboard()
        goalsField.typeText("Build strength and stay consistent at the gym.")
        shootScreen("beta-13-goals-keyboard-\(suffix)")
        assertFieldAboveDone(goalsField)
        app.buttons["dismissRoutineKeyboard"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["routineNext"].isHittable)
        if appearance == "light" && !large { shootScreen("beta-13-goals-keyboard-closed") }

        let weight = app.textFields["routineWeight"]
        // Weight is the last row: swipe to the end (short drags from mid-screen can land on the minutes control).
        for _ in 0..<10 where !visible(weight) { app.swipeUp() }
        XCTAssertTrue(visible(weight), "reached \(weight)")
        weight.tap()
        assertSoftwareKeyboard()
        weight.typeText("180")
        shootScreen("beta-13-weight-keyboard-\(suffix)")
        assertFieldAboveDone(weight)
        app.buttons["dismissRoutineKeyboard"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["routineNext"].isHittable)
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
        let bottom = [any("routineNext"), any("generateAIRoutine"), any("routineSignIn"), any("saveAIRoutine")]
            .first { $0.exists }.map { $0.frame.minY - 12 } ?? app.frame.maxY - 30
        guard element.exists && element.isHittable && element.frame.minY > 150 else { return false }
        // A card taller than the space between the bars (a session at AX sizes) counts once its
        // top half is in view: its tap target is there.
        return element.frame.maxY < bottom || (element.frame.height > bottom - 150 && element.frame.minY < bottom - 120)
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

    /// Taps near an element's top: a tall card's centre can sit under the pinned Save button.
    private func topTap(_ element: XCUIElement) {
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: min(0.5, 40 / max(1, element.frame.height)))).tap()
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
        reach(day0); topTap(day0)
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
        // Slow as well: the failure arrives after 4 s, so the retried request's wait is observable.
        launch(extra: ["-uiTestTerraOffline", "-uiTestTerraSlow"])
        fillGoals()
        any("routineNext").tap()
        let dumbbells = any("routineEquipment.dumbbells")
        XCTAssertTrue(dumbbells.waitForExistence(timeout: 5))
        reach(dumbbells); dumbbells.tap()
        any("generateAIRoutine").tap()
        let error = any("routineAIError")
        XCTAssertTrue(error.waitForExistence(timeout: 10))
        XCTAssertTrue(error.label.contains("Could not reach the server."), error.label)
        // Retry sends again: the wait shows, then (still offline) the error returns (codex-review-10 L4).
        any("routineRetry").tap()
        XCTAssertTrue(any("routineProgress").waitForExistence(timeout: 3), "retry started a new request")
        XCTAssertTrue(any("routineErrorBack").waitForExistence(timeout: 10))
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

    private var itemLabels: [String] {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'routineItem.'"))
            .allElementsBoundByIndex.map(\.label)
    }

    /// Undo restores the exact day: an edited prescription, every exercise in order, the figures
    /// (codex-review-10 L4).
    func testUndoRestoresTheExactDay() {
        launch()
        toWeek()
        topTap(any("routineDay.0"))
        let first = any("routineItem.0")
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        // Edit first: four sets on the first exercise.
        first.tap()
        let sets = any("routineStepper.Sets")
        XCTAssertTrue(sets.waitForExistence(timeout: 5))
        sets.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(sets.value as? String, "4")
        first.tap()
        XCTAssertTrue(sets.waitForNonExistence(timeout: 5))
        let before = itemLabels
        let figures = any("routineSessionFigures").label
        XCTAssertFalse(before.contains(""), "every card is named by its exercise")
        XCTAssertTrue(figures.contains("19 sets"), figures)
        // Remove the second exercise, then undo.
        let second = any("routineItem.1")
        second.tap()
        let remove = app.buttons["routineRemoveItem"]
        XCTAssertTrue(remove.waitForExistence(timeout: 5))
        reach(remove); remove.tap()
        let undo = app.buttons["routineUndo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 3))
        XCTAssertEqual(itemLabels.count, before.count - 1)
        undo.tap()
        let restored = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in self.itemLabels == before }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 5), .completed, "every exercise back in its place")
        XCTAssertEqual(any("routineSessionFigures").label, figures, "the figures are the edited day's")
        first.tap()
        XCTAssertEqual(any("routineStepper.Sets").value as? String, "4", "the edit survived the undo")
    }
}
