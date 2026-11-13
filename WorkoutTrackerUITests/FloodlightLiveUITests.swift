import XCTest

// Floodlight redesign ticket 03 — Codex review 03 regressions on the live workout, on the
// `-uiTestDesignLive` fixture (Push Day at Iron Temple; the chest press's sets 1 and 2 logged,
// 100 × 10 and 110 × 8, both new bests over last week's 45 × 8; set 3 a 110 × 8 draft; rest running).
final class FloodlightLiveUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(_ extra: [String] = []) {
        app.launchArguments = ["-uiTestReset", "-uiTestDesignSample", "-uiTestDesignLive"] + extra
        app.launch()
        XCTAssertTrue(app.buttons["finishWorkout"].waitForExistence(timeout: 15))
    }

    private func shoot(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    // MARK: Captures (L01 with the rest running; the band is captured by its test below)

    func testCaptureLiveLight() { capture("light", large: false) }
    func testCaptureLiveDark() { capture("dark", large: false) }
    func testCaptureLiveLightAccessibility() { capture("light", large: true) }

    private func capture(_ appearance: String, large: Bool) {
        launch(["-appearance", appearance]
               + (large ? ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] : []))
        XCTAssertTrue(any("setRow.badge").waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1)
        shoot("floodlight-03-live-\(appearance)-\(large ? "axl" : "default")")
    }

    // MARK: live-workout-fixes 01 — the unit switch in the keyboard bar

    func testCaptureWeightKeyboardLight() { captureWeightKeyboard("light", large: false) }
    func testCaptureWeightKeyboardDark() { captureWeightKeyboard("dark", large: false) }
    func testCaptureWeightKeyboardLightAccessibility() { captureWeightKeyboard("light", large: true) }

    /// Set 3's draft weight being edited: a tap on its unit focuses the field, and the keyboard
    /// bar carries lb | kg beside Done.
    private func captureWeightKeyboard(_ appearance: String, large: Bool) {
        launch(["-appearance", appearance]
               + (large ? ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] : []))
        let unit = app.staticTexts.matching(identifier: "setRow.unit").element(boundBy: 2)
        XCTAssertTrue(unit.waitForExistence(timeout: 5))
        let before = unit.label
        unit.tap()
        XCTAssertTrue(app.segmentedControls["keyboardUnit"].waitForExistence(timeout: 5),
                      "a tap on the unit edits the weight")
        XCTAssertEqual(unit.label, before, "a tap in the weight box never switches the unit")
        Thread.sleep(forTimeInterval: 1)
        shoot("live-fixes-01-weight-keyboard-\(appearance)-\(large ? "axl" : "default")")
    }

    /// Codex review live-01: switching mid-typing keeps the typed number and the focus (typing
    /// continues), the switch leaves with the weight's focus, and only the focused row's switch
    /// shows — with that row's unit.
    func testTheKeyboardUnitSwitchFollowsTheFocusedWeight() {
        launch()
        let weights = app.textFields.matching(identifier: "setRow.weight")
        let units = app.staticTexts.matching(identifier: "setRow.unit")
        let unitSwitch = app.segmentedControls["keyboardUnit"]
        let draft = weights.element(boundBy: 2)
        XCTAssertTrue(draft.waitForExistence(timeout: 5))
        draft.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
        draft.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4) + "12")
        XCTAssertTrue(unitSwitch.waitForExistence(timeout: 5))
        unitSwitch.buttons["kg"].tap()
        XCTAssertEqual(units.element(boundBy: 2).label, "kg")
        XCTAssertEqual(draft.value as? String, "12", "the typed number is kept, not converted")
        draft.typeText("0")
        XCTAssertEqual(draft.value as? String, "120", "the field keeps its focus after the switch")

        app.textFields.matching(identifier: "setRow.reps").element(boundBy: 2).tap()
        XCTAssertTrue(unitSwitch.waitForNonExistence(timeout: 5), "the switch belongs to the weight field")

        weights.element(boundBy: 1).tap()
        XCTAssertTrue(unitSwitch.waitForExistence(timeout: 5))
        XCTAssertEqual(app.segmentedControls.matching(identifier: "keyboardUnit").count, 1, "one row's switch at a time")
        XCTAssertTrue(unitSwitch.buttons["lb"].isSelected, "the switch shows the focused row's unit")
        XCTAssertEqual(units.element(boundBy: 2).label, "kg", "the switched row keeps its new unit")
    }

    // MARK: live-workout-fixes 02 — the list ends at the add block (no Discard row)

    func testCaptureListEndLight() { captureListEnd("light", large: false) }
    func testCaptureListEndLightAccessibility() { captureListEnd("light", large: true) }

    private func captureListEnd(_ appearance: String, large: Bool) {
        launch(["-appearance", appearance]
               + (large ? ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] : []))
        let addCardio = app.buttons["addCardio"]
        for _ in 0..<20 { app.swipeUp() }
        XCTAssertTrue(addCardio.exists && addCardio.isHittable, "the add block ends the list, above the rest slab")
        XCTAssertFalse(app.buttons["Discard Workout…"].exists, "no Discard row at the end")
        // Public beta ticket 22: two commands — Add Exercise and Add Cardio; machines are a tab of Add Exercise.
        XCTAssertFalse(app.buttons["addByMachine"].exists, "no separate Add by Machine")
        Thread.sleep(forTimeInterval: 1)
        let size = large ? "axl" : "default"
        shoot("live-fixes-02-list-end-\(appearance)-\(size)")
        app.buttons["addExercise"].tap()
        // The switch's pills carry its identifier (the tab bar also has an "Exercises" button).
        let pills = app.buttons.matching(identifier: "addExerciseMode")
        let machines = pills.matching(NSPredicate(format: "label == 'Machines'")).firstMatch
        XCTAssertTrue(machines.waitForExistence(timeout: 5), "Add Exercise opens with the Exercises | Machines switch")
        XCTAssertTrue(pills.matching(NSPredicate(format: "label == 'Exercises'")).firstMatch.isSelected, "it opens on Exercises")
        Thread.sleep(forTimeInterval: 1)
        shoot("beta-22-add-exercises-\(appearance)-\(size)")
        machines.tap()
        let machine = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'machineOption.'")).firstMatch
        XCTAssertTrue(machine.waitForExistence(timeout: 5), "the Machines tab lists Iron Temple's machines")
        Thread.sleep(forTimeInterval: 1)
        shoot("beta-22-add-machines-\(appearance)-\(size)")
    }

    // MARK: Codex review 03 regressions

    private func any(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func all(_ id: String) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: id)
    }

    /// Taps at the field's trailing edge so the caret lands after the text, clears it, types.
    private func replace(_ field: XCUIElement, with text: String) {
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
        let current = (field.value as? String) ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count + 1) + text)
        XCTAssertEqual(field.value as? String, text, "the field holds exactly the typed value")
        app.buttons["keyboardDone"].firstMatch.tap()
    }

    /// Finding 1: a logged set is corrected in place — it stays completed (no re-timed set).
    func testACompletedSetCanBeCorrectedInPlace() {
        launch()
        let weight = app.textFields.matching(identifier: "setRow.weight").element(boundBy: 0)
        let check = app.buttons.matching(identifier: "setRow.complete").element(boundBy: 0)
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        XCTAssertEqual(check.value as? String, "Completed")
        replace(weight, with: "102.5")
        XCTAssertEqual(weight.value as? String, "102.5")
        XCTAssertEqual(check.value as? String, "Completed", "correcting a value does not un-log the set")
    }

    /// Finding 2: marks follow the data — making a best a warmup takes its sticker away at once.
    func testTurningABestIntoAWarmupRemovesItsMark() {
        launch()
        XCTAssertTrue(any("setRow.badge").waitForExistence(timeout: 5))
        XCTAssertEqual(all("setRow.badge").count, 2)
        app.buttons.matching(identifier: "setRow.setType").element(boundBy: 1).tap()
        app.buttons["Warmup"].firstMatch.tap()
        let one = NSPredicate(format: "count == 1")
        expectation(for: one, evaluatedWith: all("setRow.badge"))
        waitForExpectations(timeout: 5)
    }

    /// Finding 4 (L03): logging a new best docks the band on the rest slab for a few seconds.
    func testANewBestDocksTheBandOnTheRestSlab() {
        launch()
        let weight = app.textFields.matching(identifier: "setRow.weight").element(boundBy: 2)
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        replace(weight, with: "115")
        app.buttons.matching(identifier: "setRow.complete").element(boundBy: 2).tap()
        let band = any("liveNewBest")
        XCTAssertTrue(band.waitForExistence(timeout: 5), "the New best band lands")
        XCTAssertTrue(band.label.contains("Seated Chest Press"), band.label)
        XCTAssertTrue(band.label.contains("115 lb × 8"), band.label)
        XCTAssertTrue(band.label.contains("up from 110 lb × 8"), band.label)
        XCTAssertTrue(app.staticTexts["Rest"].exists, "the rest stays under the band")
        shoot("floodlight-03-live-new-best-band")
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: band)
        waitForExpectations(timeout: 8)
        XCTAssertTrue(app.staticTexts["Rest"].exists, "the slab returns to the rest alone")
    }

    /// L03 at AX sizes (the prototype's choice, confirmed by the user): the band does not stack
    /// on the rest — for its seconds it takes the place of the Rest/time text, then gives it back.
    func testAtAccessibilitySizesTheBestTakesTheRestTextsPlace() {
        launch(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"])
        let weight = app.textFields.matching(identifier: "setRow.weight").element(boundBy: 2)
        for _ in 0..<6 { guard !(weight.exists && weight.isHittable) else { break }; app.swipeUp() }
        XCTAssertTrue(weight.isHittable)
        replace(weight, with: "115")
        let check = app.buttons.matching(identifier: "setRow.complete").element(boundBy: 2)
        for _ in 0..<4 { guard !check.isHittable else { break }; app.swipeUp() }
        check.tap()
        let band = any("liveNewBest")
        XCTAssertTrue(band.waitForExistence(timeout: 5), "the compact New best lands")
        XCTAssertTrue(band.label.contains("up from 110 lb × 8"), band.label)
        XCTAssertFalse(app.staticTexts["Rest"].exists, "the best stands in for the Rest/time text")
        XCTAssertTrue(app.buttons["Skip"].exists, "the rest controls stay")
        shoot("floodlight-03-live-new-best-axl")
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: band)
        waitForExpectations(timeout: 8)
        XCTAssertTrue(app.staticTexts["Rest"].waitForExistence(timeout: 2), "the Rest text comes back")
    }

    // MARK: Codex review 03b — the band follows its set

    /// Logs set 3 at 115 × 8 (a new best over set 2's 110 × 8) and returns the band.
    private func celebrateSetThree() -> XCUIElement {
        let weight = app.textFields.matching(identifier: "setRow.weight").element(boundBy: 2)
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        replace(weight, with: "115")
        app.buttons.matching(identifier: "setRow.complete").element(boundBy: 2).tap()
        let band = any("liveNewBest")
        XCTAssertTrue(band.waitForExistence(timeout: 5), "the New best band lands")
        XCTAssertEqual(all("setRow.badge").count, 3)
        return band
    }

    /// With the band held for 30 s, it can only go because it followed its set.
    private func expectGone(_ band: XCUIElement, _ message: String) {
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: band)
        waitForExpectations(timeout: 3)
        XCTAssertFalse(band.exists, message)
    }

    func testMakingAFreshBestAWarmupTakesTheBandAway() {
        launch(["-uiTestLongCelebration"])
        let band = celebrateSetThree()
        app.buttons.matching(identifier: "setRow.setType").element(boundBy: 2).tap()
        app.buttons["Warmup"].firstMatch.tap()
        expectGone(band, "no New best band for a warmup")
        XCTAssertEqual(all("setRow.badge").count, 2, "the warmup loses its sticker")
    }

    func testCorrectingAFreshBestBelowTheRecordTakesTheBandAway() {
        launch(["-uiTestLongCelebration"])
        let band = celebrateSetThree()
        replace(app.textFields.matching(identifier: "setRow.weight").element(boundBy: 2), with: "100")
        expectGone(band, "100 × 8 is no record")
        XCTAssertEqual(all("setRow.badge").count, 2, "the corrected set loses its sticker")
    }

    func testCorrectingAFreshBestThatStaysARecordUpdatesTheBand() {
        launch(["-uiTestLongCelebration"])
        let band = celebrateSetThree()
        replace(app.textFields.matching(identifier: "setRow.weight").element(boundBy: 2), with: "120")
        let updated = NSPredicate(format: "label CONTAINS '120 lb × 8'")
        expectation(for: updated, evaluatedWith: band)
        waitForExpectations(timeout: 3)
        XCTAssertTrue(band.label.contains("up from 110 lb × 8"), band.label)
    }

    // MARK: live-workout 03 — the chart from a live exercise, by machine (D87)

    /// `-uiTestDesignMachines`: the chest press's history is on Chest Press 2 at Iron Temple (the machine in use;
    /// 22, 12 and 7 days ago, best 45 lb × 8) and on the same model, "Chest Press", at Hotel Gym (20 and 16 days ago,
    /// best 70 lb × 8).
    private func openLiveChart(_ extra: [String] = []) {
        launch(["-uiTestDesignMachines"] + extra)
        let chart = app.buttons["entryChart"].firstMatch
        XCTAssertTrue(chart.waitForExistence(timeout: 5), "each live exercise offers its chart")
        chart.tap()
        XCTAssertTrue(any("lastTime").waitForExistence(timeout: 10), "Last time leads the chart")
    }

    func testCaptureLiveChartLight() { captureLiveChart("light", large: false) }
    func testCaptureLiveChartDark() { captureLiveChart("dark", large: false) }
    func testCaptureLiveChartLightAccessibility() { captureLiveChart("light", large: true) }

    /// The first viewport (Last time, the machine selector, the chart), then the selector open, then All machines
    /// scrolled to its sessions (each names its machine).
    private func captureLiveChart(_ appearance: String, large: Bool) {
        openLiveChart(["-appearance", appearance]
                      + (large ? ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] : []))
        let tag = "\(appearance)-\(large ? "axl" : "default")"
        Thread.sleep(forTimeInterval: 1)
        shoot("live-fixes-03-chart-\(tag)")
        if large {
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.5)
            shoot("live-fixes-03-chart-\(tag)-2")
            app.swipeDown(); app.swipeDown()
        }
        let picker = any("chartVariationPicker")
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        if !picker.isHittable { app.swipeUp() }
        picker.tap()
        let pooled = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "All machines")).firstMatch
        XCTAssertTrue(pooled.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.5)
        shoot("live-fixes-03-machines-\(tag)")
        pooled.tap()
        // Down to the Hotel Gym sessions (rows 3–4, both new bests): the badge beside or under the machine name.
        let hotelRow = all("progressSessionMachine").element(boundBy: 3)
        for _ in 0..<6 where !(hotelRow.exists && hotelRow.isHittable) { app.swipeUp() }
        XCTAssertTrue(hotelRow.exists, "each pooled session names its machine")
        Thread.sleep(forTimeInterval: 0.5)
        shoot("live-fixes-03-all-machines-\(tag)")
    }

    /// Acceptance 1–2: the chart icon opens the chart on the machine in use with Last time on top; the selector lists
    /// each machine (name · gym) and All machines, the chart follows the choice, and closing returns to the workout.
    func testLiveChartOpensOnTheMachineInUseAndSwitchesMachines() {
        openLiveChart()
        let lastSets = all("lastTimeSet")
        XCTAssertEqual(lastSets.count, 3, "last time on Chest Press 2: a warmup and two working sets")
        XCTAssertTrue(lastSets.element(boundBy: 2).label.contains("45 lb × 8"), lastSets.element(boundBy: 2).label)
        XCTAssertFalse(any("lastTimeFallback").exists, "this machine has history: no fallback note")

        let picker = any("chartVariationPicker")
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        XCTAssertTrue(picker.label.hasPrefix("Chest Press 2 · Iron Temple"), "opens on the machine in use: \(picker.label)")
        let selection = any("chartSelection")
        XCTAssertTrue(selection.waitForExistence(timeout: 5))
        XCTAssertTrue(selection.label.contains("45"), "Chest Press 2's newest best: \(selection.label)")
        XCTAssertFalse(selection.label.contains("70"), "Hotel Gym's machine is not pooled in: \(selection.label)")

        picker.tap()
        let hotel = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Chest Press · Hotel Gym")).firstMatch
        XCTAssertTrue(hotel.waitForExistence(timeout: 5), "the other machine, named with its gym")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "All machines")).firstMatch.exists)
        hotel.tap()
        let switched = any("chartSelection")
        XCTAssertTrue(switched.waitForExistence(timeout: 5))
        XCTAssertTrue(switched.label.contains("70"), "Hotel Gym's machine charts on its own: \(switched.label)")
        XCTAssertEqual(all("lastTimeSet").count, 3, "Last time stays on the machine in use")

        any("chartVariationPicker").tap()
        let pooled = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "All machines")).firstMatch
        XCTAssertTrue(pooled.waitForExistence(timeout: 5))
        pooled.tap()
        XCTAssertTrue(any("chartVariationPicker").label.hasPrefix("All machines"), any("chartVariationPicker").label)
        for _ in 0..<4 where !any("progressSessionMachine").exists { app.swipeUp() }
        XCTAssertTrue(any("progressSessionMachine").exists, "each pooled session names its machine")

        app.buttons["closeProgress"].tap()
        XCTAssertTrue(app.buttons["finishWorkout"].waitForExistence(timeout: 5), "closing returns to the workout")
    }
}
