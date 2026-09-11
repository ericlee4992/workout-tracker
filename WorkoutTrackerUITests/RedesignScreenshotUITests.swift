import XCTest

/// UI redesign (D54) — the review surface: one test per screen, each built
/// with the existing fixtures and ending in a named screenshot. Run on
/// `main` first for the "before" set, then on each ticket for the "after".
/// The tests assert only what they need to reach the screen.
final class RedesignScreenshotUITests: XCTestCase {
    private var app: XCUIApplication!
    private let gymName = "Iron Temple"
    private let machineLabel = "Chest Press"
    private let modelSearch = "Insignia Series Chest Press"
    private let modelName = "Life Fitness Insignia Series Chest Press"
    private let exerciseName = "Seated Chest Press"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(_ arguments: [String] = [], env: [String: String] = [:]) {
        app.launchArguments = ["-uiTestReset"] + arguments
        app.launchEnvironment = env
        app.launch()
    }

    private func shoot(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    // MARK: - Screens

    /// Active workout with a live heart-rate feed, one set completed (rest
    /// bar showing) and a second set waiting; then the finish summary.
    func test02_activeWorkoutAndFinish() {
        launch(["-uiTestHeartRate"])
        createGym()
        addMachine()
        startEmptyWorkout()
        let addByMachine = app.buttons["addByMachine"]
        XCTAssertTrue(addByMachine.waitForExistence(timeout: 10))
        addByMachine.tap()
        let option = anyElement("machineOption.\(machineLabel)")
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        option.tap()
        XCTAssertTrue(app.staticTexts[exerciseName].waitForExistence(timeout: 5))
        logSet(weight: "60", reps: "10")
        app.buttons["addSet"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Rest"].waitForExistence(timeout: 5) || app.buttons["Skip"].waitForExistence(timeout: 5))
        shoot("redesign-02-active-workout")

        app.buttons["finishWorkout"].tap()
        XCTAssertTrue(app.buttons["finishedDone"].waitForExistence(timeout: 10))
        shoot("redesign-03-finish-summary")
    }

    /// The receipt at the largest non-accessibility-menu text size the plan
    /// promised per ticket (AXL): tiles must wrap, never truncate.
    func test03_finishSummaryLargeText() {
        app.launchArguments = ["-uiTestReset", "-uiTestHeartRate",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"]
        app.launch()
        createGym()
        addMachine()
        startEmptyWorkout()
        let addByMachine = app.buttons["addByMachine"]
        XCTAssertTrue(addByMachine.waitForExistence(timeout: 10))
        addByMachine.tap()
        let option = anyElement("machineOption.\(machineLabel)")
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        option.tap()
        logSet(weight: "60", reps: "10")
        app.buttons["finishWorkout"].tap()
        XCTAssertTrue(app.buttons["finishedDone"].waitForExistence(timeout: 10))
        shoot("redesign-03-finish-summary-axl")
        // The grid runs past one screen at this size: scroll until the last
        // tile is in view and capture again, so every tile is on record.
        let volume = anyElement("summaryVolume")
        for _ in 0..<6 where !(volume.exists && volume.isHittable) { app.swipeUp() }
        XCTAssertTrue(volume.isHittable, "all six tiles reachable at AccessibilityL")
        shoot("redesign-03-finish-summary-axl-2")
    }

    /// The Start tab with a gym chosen and a workout in progress (resume banner).
    func test04_start() {
        launch()
        createGym()
        startEmptyWorkout()
        XCTAssertTrue(app.buttons["minimizeWorkout"].waitForExistence(timeout: 10))
        app.buttons["minimizeWorkout"].tap()
        XCTAssertTrue(anyElement("resumeWorkout").waitForExistence(timeout: 5))
        shoot("redesign-04-start")
    }

    /// Settings behind the gear on the Workout tab (ticket 05).
    func test05_settings() {
        launch()
        app.tabBars.buttons["Workout"].tap()
        let gear = app.buttons["openSettings"]
        XCTAssertTrue(gear.waitForExistence(timeout: 10))
        gear.tap()
        XCTAssertTrue(anyElement("heartRateZonesSettings").waitForExistence(timeout: 5))
        shoot("redesign-05-settings")
    }

    /// History list, the calendar, a workout's detail and the progress chart,
    /// all from the chart fixture (four weeks of one exercise).
    func test05_history() {
        launch(["-uiTestChartHistory"])
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(anyElement("historyWorkoutRow").waitForExistence(timeout: 10))
        shoot("redesign-05-history")
        app.buttons["historyCalendar"].tap()
        XCTAssertTrue(anyElement("historyCalendarSheet").waitForExistence(timeout: 5))
        shoot("redesign-05-calendar")
        app.buttons["closeCalendar"].tap()
        anyElement("historyWorkoutRow").tap()
        XCTAssertTrue(anyElement("historySetLine").waitForExistence(timeout: 5))
        shoot("redesign-05-detail")

        app.tabBars.buttons["Exercises"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText(exerciseName)
        let row = app.staticTexts[exerciseName].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.press(forDuration: 1.0)
        let progress = app.buttons["Progress…"].firstMatch
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        progress.tap()
        XCTAssertTrue(anyElement("progressChart").waitForExistence(timeout: 10))
        shoot("redesign-05-chart")
    }

    /// The History list and a workout's detail at AccessibilityL (ticket 06,
    /// codex-review-06): the day tile must grow with its text, the entry
    /// header wrap rather than clip. The chart fixture has a two-digit day
    /// (Aug 31) in its second month.
    func test05_historyLargeText() {
        app.launchArguments = ["-uiTestReset", "-uiTestChartHistory",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"]
        app.launch()
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(anyElement("historyWorkoutRow").waitForExistence(timeout: 10))
        shoot("redesign-05-history-axl")
        anyElement("historyWorkoutRow").tap()
        XCTAssertTrue(anyElement("historySetLine").waitForExistence(timeout: 5))
        shoot("redesign-05-detail-axl")
    }

    /// A finished hour with a full heart-rate series, in History.
    func test05_historyHeartRate() {
        launch(["-uiTestHeartRateHistory"])
        app.tabBars.buttons["History"].tap()
        let row = anyElement("historyWorkoutRow")
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        XCTAssertTrue(anyElement("heartRateChart").waitForExistence(timeout: 10))
        shoot("redesign-05-detail-heart-rate")
    }

    /// The Gyms tab, a gym's detail, and the Exercises tab (Settings left the Gyms list in ticket 05).
    func test06_gymsAndExercises() {
        launch()
        createGym()
        addMachine()
        shoot("redesign-06-gym-detail")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(anyElement("gymRow.\(gymName)").waitForExistence(timeout: 5))
        shoot("redesign-06-gyms")
        app.tabBars.buttons["Exercises"].tap()
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 10))
        shoot("redesign-07-exercises")
    }

    /// A gym's detail and the Gyms list at AccessibilityL (ticket 07,
    /// codex-review-07): the machine's model must stay whole — a caption
    /// there, not the chip — and the gym card's chips must not clip.
    func test06_gymsLargeText() {
        app.launchArguments = ["-uiTestReset",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"]
        app.launch()
        createGym()
        addMachine()
        XCTAssertTrue(anyElement("machineRow.\(machineLabel)").waitForExistence(timeout: 10))
        shoot("redesign-06-gym-detail-axl")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(anyElement("gymRow.\(gymName)").waitForExistence(timeout: 5))
        shoot("redesign-06-gyms-axl")
    }

    /// Empty states: History and Gyms on a fresh store.
    func test08_emptyStates() {
        launch()
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["No workouts yet"].waitForExistence(timeout: 10))
        shoot("redesign-08-empty-history")
        app.tabBars.buttons["Gyms"].tap()
        XCTAssertTrue(app.buttons["addGym"].waitForExistence(timeout: 5))
        shoot("redesign-08-empty-gyms")
        app.tabBars.buttons["Workout"].tap()
        XCTAssertTrue(app.buttons["startEmptyWorkout"].waitForExistence(timeout: 5))
        shoot("redesign-01-root")
    }

    // MARK: - Helpers (mirroring CoreLoopUITests)

    private func anyElement(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func createGym() {
        app.tabBars.buttons["Gyms"].tap()
        app.buttons["addGym"].tap()
        let name = app.textFields["gymName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        _ = app.keyboards.firstMatch.waitForExistence(timeout: 3)
        name.typeText(gymName)
        app.buttons["saveGym"].tap()
        XCTAssertTrue(anyElement("gymRow.\(gymName)").waitForExistence(timeout: 5))
    }

    private func addMachine() {
        anyElement("gymRow.\(gymName)").tap()
        let add = app.buttons["addMachine"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        let label = app.textFields["machineLabel"]
        XCTAssertTrue(label.waitForExistence(timeout: 5))
        label.tap()
        _ = app.keyboards.firstMatch.waitForExistence(timeout: 3)
        label.typeText(machineLabel)
        anyElement("catalogModel").tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText(modelSearch)
        let modelRow = anyElement("modelOption.\(modelName)")
        XCTAssertTrue(modelRow.waitForExistence(timeout: 5))
        modelRow.tap()
        XCTAssertTrue(app.textFields["machineLabel"].waitForExistence(timeout: 5))
        app.buttons["saveMachine"].tap()
        XCTAssertTrue(anyElement("machineRow.\(machineLabel)").waitForExistence(timeout: 5))
    }

    private func startEmptyWorkout() {
        app.tabBars.buttons["Workout"].tap()
        let picker = anyElement("gymPicker")
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        if !picker.label.contains(gymName) {
            picker.tap()
            let option = app.buttons[gymName].firstMatch
            XCTAssertTrue(option.waitForExistence(timeout: 5))
            option.tap()
        }
        app.buttons["startEmptyWorkout"].tap()
        XCTAssertTrue(app.buttons["finishWorkout"].waitForExistence(timeout: 10))
    }

    private func logSet(weight: String, reps: String) {
        let weightField = app.textFields["setRow.weight"].firstMatch
        XCTAssertTrue(weightField.waitForExistence(timeout: 5))
        weightField.tap()
        weightField.typeText(weight)
        let repsField = app.textFields["setRow.reps"].firstMatch
        repsField.tap()
        repsField.typeText(reps)
        app.buttons["setRow.complete"].firstMatch.tap()
    }
}
