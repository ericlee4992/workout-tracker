import XCTest

// Public beta ticket 23 (the user, 2026-10-23): New Template → Add Exercise has Exercises | Machines. The Machines tab
// lists the selected gym's machines (Iron Temple in the sample), offers Add Machine… (whose form has Scan
// equipment…), and a picked machine is remembered for its exercise at that gym when the template is saved (D66) — so
// the template's detail, which shows what each row starts on, names it.
final class TemplateMachinesUITests: XCTestCase {
    private var app: XCUIApplication!
    private var tag = ""

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(large: Bool) {
        tag = large ? "axl" : "default"
        app.launchArguments = ["-uiTestReset", "-uiTestDesignSample", "-uiTestDesignGyms", "-appearance", "light"]
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

    /// Scrolls until the element is on screen below the navigation bar: at AccessibilityL a tile can be "hittable"
    /// while its top is under the bar, where a tap lands on the bar instead.
    private func reach(_ element: XCUIElement) {
        func clear() -> Bool { element.exists && element.isHittable && element.frame.minY > 120 }
        for _ in 0..<8 where !clear() {
            if element.exists && element.frame.minY <= 120 { app.swipeDown() } else { app.swipeUp() }
        }
        XCTAssertTrue(element.waitForExistence(timeout: 5), "\(element) not reached")
    }

    func testAPickedStationMachineIsWhereTheTemplateStarts() { pickStation(large: false) }
    func testThePickAtAccessibilitySize() { pickStation(large: true) }

    /// A second gym (no machines), so the Machines tab's gym menu has somewhere to switch to.
    private func addSecondGym() {
        app.tabBars.buttons["Gyms"].tap()
        app.buttons["addGym"].tap()
        let name = app.textFields["gymName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Second Gym")
        app.buttons["saveGym"].tap()
        XCTAssertTrue(any("gymRow.Second Gym").waitForExistence(timeout: 5))
    }

    private func modePill(_ label: String) -> XCUIElement {
        app.buttons.matching(identifier: "addExerciseMode").matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    private func pickStation(large: Bool) {
        launch(large: large)
        addSecondGym()
        app.tabBars.buttons["Workout"].tap()
        let new = app.buttons["New Template…"].firstMatch
        reach(new)
        new.tap()
        let field = app.textFields["Template name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Machine Day\n")
        let add = app.buttons["addTemplateExercise"]
        reach(add)
        add.tap()

        let machines = modePill("Machines")
        XCTAssertTrue(machines.waitForExistence(timeout: 5), "the template picker has the Exercises | Machines switch")
        machines.tap()
        let gym = any("templateMachinesGym")
        XCTAssertTrue(gym.waitForExistence(timeout: 5))
        XCTAssertTrue(gym.label.contains("Iron Temple"), gym.label)
        shoot("beta-23-machines")

        // Add Machine… opens the machine form, which has Scan equipment….
        let addMachine = app.buttons["templateAddMachine"]
        reach(addMachine)
        addMachine.tap()
        XCTAssertTrue(app.buttons["scanMachineLabel"].waitForExistence(timeout: 5), "Scan equipment… in the form")
        shoot("beta-23-add-machine")
        app.buttons["Cancel"].firstMatch.tap()
        XCTAssertTrue(addMachine.waitForExistence(timeout: 5))

        // The Pec Deck is a station: it asks which exercise. Rear Delt Fly is already remembered on it; pick the other.
        let pecDeck = any("machineOption.Pec Deck")
        for _ in 0..<8 where !(pecDeck.exists && pecDeck.isHittable) { app.swipeDown() }
        reach(pecDeck)
        pecDeck.tap()
        let options = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'exerciseOption.' AND NOT (identifier == 'exerciseOption.Rear Delt Fly')"))
        XCTAssertTrue(options.firstMatch.waitForExistence(timeout: 5), "the station's exercises")
        let exercise = String(options.firstMatch.identifier.dropFirst("exerciseOption.".count))
        shoot("beta-23-station")
        options.firstMatch.tap()
        XCTAssertTrue(pecDeck.waitForExistence(timeout: 5), "back on the machines after the pick")
        XCTAssertEqual(pecDeck.value as? String, "Added")

        // codex-review-23 #1: the gym and the ✓ survive a trip to Exercises and back.
        for _ in 0..<8 where !gym.isHittable { app.swipeDown() }
        gym.tap()
        let second = app.buttons["Second Gym"].firstMatch
        XCTAssertTrue(second.waitForExistence(timeout: 5), "the gym menu lists the second gym")
        second.tap()
        XCTAssertTrue(gym.label.contains("Second Gym"), gym.label)
        modePill("Exercises").tap()
        modePill("Machines").tap()
        XCTAssertTrue(gym.waitForExistence(timeout: 5))
        XCTAssertTrue(gym.label.contains("Second Gym"), "the switched gym is kept: \(gym.label)")
        gym.tap()
        app.buttons["Iron Temple"].firstMatch.tap()
        reach(pecDeck)
        XCTAssertEqual(pecDeck.value as? String, "Added", "the ✓ is kept too")

        // codex-review-23b #1: the same exercise picked again on another machine (the model-less Biceps Curl machine
        // offers the full catalog) — that machine becomes the choice, and the Pec Deck loses its ✓.
        let modelless = any("machineOption.Biceps Curl")
        for _ in 0..<8 where !(modelless.exists && modelless.isHittable) { app.swipeDown() }
        reach(modelless)
        modelless.tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5), "the full catalog's search")
        search.tap()
        search.typeText(exercise)
        let same = app.buttons["exerciseOption.\(exercise)"].firstMatch
        XCTAssertTrue(same.waitForExistence(timeout: 5), "\(exercise) in the full catalog")
        same.tap()
        XCTAssertTrue(modelless.waitForExistence(timeout: 5))
        XCTAssertEqual(modelless.value as? String, "Added")
        reach(pecDeck)
        XCTAssertEqual(pecDeck.value as? String, "", "the superseded Pec Deck is no longer marked")
        app.buttons["templatePickerDone"].tap()

        // The cards say where they will start — both rows of the exercise on the latest pick, none still on the Pec
        // Deck (codex-review-23 #2); Save remembers it; the detail shows it.
        let latest = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Biceps Curl · Iron Temple'"))
        XCTAssertTrue(latest.firstMatch.waitForExistence(timeout: 5), "the card names the picked machine")
        // (Counting matches would count each caption's nested elements too.) The earlier row was the Pec Deck's.
        XCTAssertFalse(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Pec Deck · Iron Temple'")).firstMatch.exists,
                       "the earlier row of \(exercise) now carries the latest pick too")
        shoot("beta-23-editor")
        app.buttons["Save"].tap()
        let tile = any("templateTile.Machine Day")
        reach(tile)
        tile.tap()
        // The row's equipment line is its own part of the combined label ("…, 3 sets · 10, 10, 10 reps, Biceps Curl"):
        // an exercise's name can contain a machine's name too (codex-review-23 #4), so match the part, not a substring.
        let row = any("templateExercise.\(exercise)")
        XCTAssertTrue(row.waitForExistence(timeout: 5), "\(exercise) in the template")
        XCTAssertTrue(row.label.components(separatedBy: ", ").contains("Biceps Curl"),
                      "the template starts \(exercise) on the latest pick at Iron Temple: \(row.label)")
        shoot("beta-23-detail")
    }
}
