import XCTest

// Floodlight redesign ticket 12 — the cardio area in plain Floodlight, light and dark at Default and
// AccessibilityL, with the same fixture and state each time (`CardioDesignFixture`, the route and
// indoor fixtures). Each flow also asserts what it photographs.
//  • live: the planned target and an ended segment (C02 planned), Choose Cardio with the target
//    preselected (C01), Start → recording against the target, Pause (C03); a target run with heart
//    rate (C02), the replace picker, a met target; a measured indoor distance ring; outdoor (C04)
//    and location lost; Distance over an ended segment (C05).
//  • finished: an outdoor run with a pause → the receipt's card with route and splits, History's
//    cardio-only hero and Splits (H04).
final class FloodlightCardioUITests: XCTestCase {
    private var app: XCUIApplication!
    private var tag = ""

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(_ arguments: [String], _ appearance: String, large: Bool) {
        tag = "\(appearance)-\(large ? "axl" : "default")"
        app.launchArguments = ["-uiTestReset", "-appearance", appearance] + arguments
            + (large ? ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] : [])
        app.launch()
    }

    private func shoot(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "\(name)-\(tag)"
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func any(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func labelled(_ text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    /// Scrolls in small steps until the element is on screen above the pinned tray (a tap on a
    /// row half under a bar lands on the bar).
    private func reach(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        func visible() -> Bool {
            guard element.exists, element.isHittable else { return false }
            let tray = app.buttons["cardioPauseResume"]
            if tray.exists, tray.isHittable, element.identifier != "cardioPauseResume", element.identifier != "endCardio" {
                return element.frame.maxY < tray.frame.minY - 8 && element.frame.minY > 100
            }
            return element.frame.minY > 100
        }
        for _ in 0..<12 where !visible() {
            let up = !element.exists || element.frame.minY > 100
            let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: up ? 0.62 : 0.38))
            let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: up ? 0.38 : 0.62))
            from.press(forDuration: 0.05, thenDragTo: to)
        }
        XCTAssertTrue(visible(), "\(element.identifier) not reached", file: file, line: line)
    }

    private func toTop() {
        for _ in 0..<4 { app.swipeDown() }
    }

    private func cardioFocus() {
        let cardio = app.segmentedControls["workoutActivityFocus"].buttons["Cardio"]
        XCTAssertTrue(cardio.waitForExistence(timeout: 15))
        if !cardio.isSelected { cardio.tap() }
    }

    // MARK: Live

    func testLiveDark() { live("dark", large: false) }
    func testLiveLight() { live("light", large: false) }
    func testLiveDarkAccessibility() { live("dark", large: true) }
    func testLiveLightAccessibility() { live("light", large: true) }

    private func live(_ appearance: String, large: Bool) {
        // The planned target and an ended segment; the picker with the target preselected.
        launch(["-uiTestCardioPlanned"], appearance, large: large)
        cardioFocus()
        let start = app.buttons["startPlannedCardio"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        XCTAssertTrue(labelled("Last Indoor Run").exists, "the last run is a fact under the target")
        shoot("C02-planned")
        let walk = any("cardioSummary.indoorWalk")
        reach(walk)
        let walkDistance = app.buttons["cardioSummaryEditDistance"]
        XCTAssertTrue(walkDistance.label.hasPrefix("Entered distance"), walkDistance.label)
        shoot("C02-ended")
        let add = app.buttons["addCardio"]; reach(add); add.tap()
        let startSelected = app.buttons["startSelectedCardio"]
        XCTAssertTrue(startSelected.waitForExistence(timeout: 5))
        XCTAssertEqual(startSelected.label, "Start Indoor Run", "the planned target is preselected")
        XCTAssertTrue(any("cardioPlanOption.0").isSelected)
        shoot("C01-planned")
        let rowing = any("cardioActivity.rowing"); reach(rowing); rowing.tap()
        XCTAssertTrue(rowing.isSelected)
        XCTAssertEqual(startSelected.label, "Start Rowing")
        shoot("C01-rowing")
        app.buttons["cardioPickerCancel"].tap()
        // Start the target: recording against it; then paused.
        toTop(); reach(start); start.tap()
        XCTAssertTrue(any("cardioTimer").waitForExistence(timeout: 10))
        XCTAssertTrue(any("cardioTimer").label.contains("of 20:00"), any("cardioTimer").label)
        let pause = app.buttons["cardioPauseResume"]
        pause.tap()
        let status = any("cardioStatus")
        XCTAssertTrue(status.label.hasPrefix("Paused"), status.label)
        XCTAssertEqual(pause.label, "Resume")
        toTop(); shoot("C03")

        // Recording a target with heart rate: the ring, figures, the plate; the replace picker.
        launch(["-uiTestCardioTarget", "-uiTestHeartRate"], appearance, large: large)
        XCTAssertTrue(any("cardioTimer").waitForExistence(timeout: 15))
        XCTAssertTrue(any("cardioTimer").label.contains("of 20:00"))
        XCTAssertTrue(any("cardioStatus").label == "Recording")
        shoot("C02")
        reach(any("cardioHeartRate"))
        // The seeded 2.36 km plus whatever the heart-rate fixture's sensor adds.
        XCTAssertTrue(any("cardioDistanceMetric").label.hasPrefix("Distance 2."), any("cardioDistanceMetric").label)
        XCTAssertFalse(app.buttons["cardioEditDistance"].exists, "measured distance has no editor")
        shoot("C02-p2")
        let addCardio = app.buttons["addCardio"]; reach(addCardio); addCardio.tap()
        XCTAssertTrue(labelled("Starting another activity ends the current cardio segment.").waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["startSelectedCardio"].isEnabled, "nothing preselected while recording")
        shoot("C01-replace")
        app.buttons["cardioPickerCancel"].tap()
        // Distance over the ended segment (C05): Measured is the blank field's choice.
        let end = app.buttons["endCardio"]; XCTAssertTrue(end.waitForExistence(timeout: 5)); end.tap()
        let edit = app.buttons["cardioSummaryEditDistance"]; reach(edit); edit.tap()
        let field = app.textFields["cardioDistanceField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertTrue(any("cardioMeasuredDistance").isSelected, "a blank field saves the measured distance")
        XCTAssertFalse(app.buttons["saveCardioDistance"].isEnabled)
        shoot("C05")
        field.tap(); field.typeText("2.4")
        XCTAssertTrue(app.buttons["saveCardioDistance"].isEnabled)
        XCTAssertFalse(any("cardioMeasuredDistance").isSelected)
        shoot("C05-typed")

        // A met target.
        launch(["-uiTestCardioTarget", "-uiTestCardioTargetMet"], appearance, large: large)
        XCTAssertTrue(any("cardioTimer").waitForExistence(timeout: 15))
        XCTAssertTrue(any("cardioTimer").label.contains("target reached"), any("cardioTimer").label)
        shoot("C02-met")

        // A measured indoor distance without a target: the ring counts to the next kilometre.
        launch(["-uiTestIndoorDistance"], appearance, large: large)
        let metric = any("cardioDistanceMetric")
        XCTAssertTrue(metric.waitForExistence(timeout: 15))
        XCTAssertTrue(metric.label.contains("1.00 km") && metric.label.contains("of 2 km"), metric.label)
        shoot("C02-distance")

        // Outdoor, then location lost (C04): never a map while recording.
        launch(["-uiTestCardioRoute", "-uiTestHeartRate"], appearance, large: large)
        XCTAssertTrue(any("cardioDistanceMetric").waitForExistence(timeout: 15))
        XCTAssertFalse(any("cardioLocationStatus").exists, "no GPS line while fixes arrive (decision 2)")
        XCTAssertFalse(any("cardioRoute").exists)
        shoot("C04")
        launch(["-uiTestCardioLost"], appearance, large: large)
        let lost = any("cardioLocationStatus")
        XCTAssertTrue(lost.waitForExistence(timeout: 15))
        XCTAssertTrue(lost.label.contains("Location unavailable."), lost.label)
        XCTAssertFalse(any("cardioRoute").exists)
        shoot("C04-lost")
        reach(any("cardioHeartRate"))
        shoot("C04-lost-p2")
    }

    // MARK: Finished

    func testFinishedDark() { finished("dark", large: false) }
    func testFinishedLight() { finished("light", large: false) }
    func testFinishedDarkAccessibility() { finished("dark", large: true) }
    func testFinishedLightAccessibility() { finished("light", large: true) }

    private func finished(_ appearance: String, large: Bool) {
        launch(["-uiTestCardioSplits"], appearance, large: large)
        let card = any("cardioSummary.outdoorRun")
        XCTAssertTrue(card.waitForExistence(timeout: 15))
        XCTAssertFalse(any("cardioRoute").exists, "routes only after Finish")
        shoot("C02-ended-outdoor")
        app.buttons["finishWorkout"].tap()
        XCTAssertTrue(app.buttons["finishedDone"].waitForExistence(timeout: 10))
        let route = any("cardioRoute"); reach(route)
        sleep(2) // the map snapshot fades in
        shoot("F02-route")
        let splits = labelled("Split 2"); reach(splits)
        XCTAssertTrue(labelled("Split 1").exists)
        XCTAssertTrue(app.buttons["cardioSummaryEditDistance"].exists, "the receipt keeps its distance edit (decision 4)")
        shoot("F02-splits")
        // History's cardio-only detail.
        let history = app.buttons["viewFinishedWorkout"]
        for _ in 0..<10 where !history.exists || !history.isHittable { app.swipeDown() }
        history.tap()
        let hero = any("cardioRoute")
        XCTAssertTrue(hero.waitForExistence(timeout: 10))
        sleep(2)
        let heroDistance = app.buttons["cardioSummaryEditDistance"]
        XCTAssertTrue(heroDistance.label.hasPrefix("Distance"), heroDistance.label)
        shoot("H04")
        let section = any("cardioSplits"); reach(section)
        shoot("H04-splits")
    }
}
