import XCTest

/// Nutrition N13 (D84), acceptance 3: a new install is taken from the welcome page into the goal setup and cannot leave
/// it unfinished (no Skip, no Close; quitting part-way brings it back); an existing user's run from Nutrition goals;
/// edits on the plan page; every page on record in light and dark at Default and AccessibilityL.
final class GoalSetupUITests: XCTestCase {
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

    private func launch(_ arguments: [String], appearance: String = "light", large: Bool = false) {
        app.launchArguments = ["-uiTestReset", "-appearance", appearance] + arguments
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] }
        app.launch()
    }

    // MARK: New install

    func testANewInstallIsTakenIntoTheSetupAndCannotLeaveItUnfinished() {
        launch(["-uiTestOnboarding", "-uiTestOnboardingFresh"])
        let start = app.buttons["welcomeGetStarted"]
        XCTAssertTrue(start.waitForExistence(timeout: 15), "a fresh phone shows the welcome page")
        XCTAssertFalse(app.buttons["welcomeSkip"].exists, "no Skip (D84)")
        start.tap()

        let next = app.buttons["goalSetupContinue"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        XCTAssertFalse(next.isEnabled, "nothing chosen yet")
        XCTAssertFalse(app.buttons["goalSetupClose"].exists, "no way out on first launch")
        XCTAssertFalse(app.buttons["goalSetupBack"].exists, "the first page has no Back")
        app.buttons["goalSetupSex.female"].tap()
        XCTAssertTrue(next.isEnabled)
        next.tap()
        XCTAssertTrue(any("goalSetupBirthDate").waitForExistence(timeout: 5))
        next.tap()

        // Quit part-way: the welcome comes back, because nothing was saved.
        app.terminate()
        launch(["-uiTestOnboarding"])
        XCTAssertTrue(start.waitForExistence(timeout: 15), "an unfinished setup brings the welcome back")
        start.tap()
        XCTAssertTrue(app.buttons["goalSetupSex.female"].waitForExistence(timeout: 5))

        app.completeGoalSetup(goal: "lose") { page in
            if page == "pace" {
                let fast = self.app.buttons["goalSetupPaceFast"]
                let pace = self.any("goalSetupPace")
                let before = pace.label
                fast.tap()
                XCTAssertTrue(NSPredicate(format: "label != %@", before).evaluate(with: pace), "Fast changes the pace")
                self.app.buttons["goalSetupPaceRecommended"].tap()
                let reached = self.app.descendants(matching: .any)
                    .matching(NSPredicate(format: "label BEGINSWITH 'Goal reached'")).firstMatch
                XCTAssertTrue(reached.exists, "the date the goal is reached shows live")
            }
            if page == "plan" {
                let protein = self.app.buttons["goalSetup.Protein"]
                protein.tap()
                let field = self.app.textFields["goalProteinField"]
                XCTAssertTrue(field.waitForExistence(timeout: 5))
                field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6) + "150")
                self.app.buttons["detailEditorSave"].tap()
                XCTAssertTrue(protein.label.contains("150") && protein.label.contains("Typed by you"), protein.label)
                XCTAssertTrue(self.app.buttons["goalSetupRecalculate"].exists)
            }
        }
        XCTAssertTrue(app.buttons["goalSetupFinish"].waitForNonExistence(timeout: 5), "Start closes the setup")

        app.openProfile()
        let goals = app.buttons["profileNutritionGoals"]
        XCTAssertTrue(goals.waitForExistence(timeout: 10))
        XCTAssertTrue(goals.label.hasSuffix("cal"), goals.label)
        goals.tap()
        // Signed out (no server): the plan was calculated on the phone (N14 fallback), the typed protein kept.
        let calories = any("nutritionGoalsCalories")
        XCTAssertTrue(calories.waitForExistence(timeout: 5))
        XCTAssertTrue(calories.label.contains("Calculated"), calories.label)
        XCTAssertTrue(app.buttons["nutritionGoals.Protein"].label.contains("150"), "the typed protein was saved")

        // Answered: the next launch goes straight to the app.
        app.terminate()
        launch(["-uiTestOnboarding"])
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        XCTAssertFalse(start.exists, "a finished setup keeps the welcome away")
    }

    // MARK: Existing user

    func testAnExistingUserRunsItFromNutritionGoalsPrefilled() {
        launch(["-uiTestDesignSample", "-uiTestPersonalDetails"])
        app.openProfile()
        app.buttons["profileNutritionGoals"].tap()
        // N14 (D85): the numbers and one command — no Personal details, Activity or Goal weight rows.
        let generate = app.buttons["nutritionGoalsGenerate"]
        XCTAssertTrue(generate.waitForExistence(timeout: 5))
        XCTAssertFalse(any("nutritionGoalsGoalWeight").exists || any("nutritionGoalsActivity").exists
                       || any("nutritionGoalsDetails").exists || any("nutritionGoalsGoal").exists)
        let calories = any("nutritionGoalsCalories")
        let before = calories.label

        // Close leaves everything as it was.
        generate.tap()
        let close = app.buttons["goalSetupClose"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["goalSetupContinue"].isEnabled, "prefilled from Personal details")
        close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 5))
        XCTAssertEqual(calories.label, before)

        generate.tap()
        XCTAssertTrue(app.buttons["goalSetupContinue"].waitForExistence(timeout: 5))
        app.completeGoalSetup(goal: "gain", prefilled: true)
        XCTAssertTrue(app.buttons["goalSetupFinish"].waitForNonExistence(timeout: 5), "Save Goals closes the setup")
        XCTAssertTrue(generate.waitForExistence(timeout: 5))
        XCTAssertNotEqual(calories.label, before, "a gain adds calories")
        XCTAssertTrue(calories.label.contains("Calculated"), "signed out: calculated (\(calories.label))")
    }

    /// N14 (D85): signed in, the plan page asks the server (the Terra fixture's 2,100 cal plan) and says Generated; the
    /// saved goal keeps it. With the server failing, the calculation stands in with one line.
    func testSignedInThePlanIsGeneratedAndAFailureFallsBack() {
        launch(["-uiTestDesignSample", "-uiTestPersonalDetails", "-uiTestTerra", "-uiTestTerraSlow"])
        app.openProfile()
        app.buttons["profileNutritionGoals"].tap()
        let generate = app.buttons["nutritionGoalsGenerate"]
        XCTAssertTrue(generate.waitForExistence(timeout: 5))
        generate.tap()
        app.completeGoalSetup(goal: "maintain", prefilled: true, tapFinish: false) { page in
            guard page == "plan" else { return }
            XCTAssertTrue(self.any("goalSetupGenerating").exists, "a loading state while the server works")
            XCTAssertFalse(self.app.buttons["goalSetupFinish"].isEnabled, "nothing saved mid-request")
        }
        let planCalories = any("goalSetupCalories")
        XCTAssertTrue(planCalories.waitForExistence(timeout: 15))
        XCTAssertTrue(planCalories.label.contains("2,100") && planCalories.label.contains("Generated"), planCalories.label)
        app.buttons["goalSetupFinish"].tap()
        XCTAssertTrue(generate.waitForExistence(timeout: 5))
        let calories = any("nutritionGoalsCalories")
        XCTAssertTrue(calories.label.contains("2,100") && calories.label.contains("Generated"), calories.label)
        XCTAssertTrue(app.buttons["nutritionGoalsRecalculate"].exists, "back to the calculation")
        app.terminate()

        launch(["-uiTestDesignSample", "-uiTestPersonalDetails", "-uiTestTerra", "-uiTestTerraOffline"])
        app.openProfile()
        app.buttons["profileNutritionGoals"].tap()
        XCTAssertTrue(generate.waitForExistence(timeout: 5))
        generate.tap()
        app.completeGoalSetup(goal: "maintain", prefilled: true, tapFinish: false)
        XCTAssertTrue(any("goalSetupCalculatedFallback").waitForExistence(timeout: 10))
        XCTAssertTrue(any("goalSetupCalories").label.contains("Calculated"))
    }

    // MARK: Captures

    func testCaptureLightDefault() { capture(appearance: "light", large: false) }
    func testCaptureDarkDefault() { capture(appearance: "dark", large: false) }
    func testCaptureLightAccessibility() { capture(appearance: "light", large: true) }
    func testCaptureDarkAccessibility() { capture(appearance: "dark", large: true) }

    private func capture(appearance: String, large: Bool) {
        let tag = "\(appearance)-\(large ? "axl" : "default")"
        launch(["-uiTestOnboarding", "-uiTestOnboardingFresh"], appearance: appearance, large: large)
        let start = app.buttons["welcomeGetStarted"]
        XCTAssertTrue(start.waitForExistence(timeout: 15))
        Thread.sleep(forTimeInterval: 0.8)
        shoot("n13-0-welcome-\(tag)")
        start.tap()
        var index = 0
        app.completeGoalSetup(goal: "lose", tapFinish: false) { page in
            index += 1
            Thread.sleep(forTimeInterval: 0.6)
            self.shoot("n13-\(index)-\(page)-\(tag)")
            // AccessibilityL: the blocks below the first viewport too (codex-review-n13 evidence).
            if large, page == "pace" || page == "plan" {
                let from = self.app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
                from.press(forDuration: 0.05, thenDragTo: self.app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)))
                Thread.sleep(forTimeInterval: 0.6)
                self.shoot("n13-\(index)-\(page)-scrolled-\(tag)")
            }
        }
    }
}

extension XCUIApplication {
    /// N13: walks the goal setup from its first page — female, the default date of birth, 150 (kg or lb, whichever the
    /// page shows), 3–5 workouts, `goal`, the default desired weight and the recommended pace — calling `onPage` once a
    /// page is filled in, then taps Start / Save Goals. `prefilled`: an existing user's run, every answer already there.
    func completeGoalSetup(goal: String, prefilled: Bool = false, tapFinish: Bool = true,
                           onPage: (String) -> Void = { _ in }) {
        let next = buttons["goalSetupContinue"]
        func advance() {
            XCTAssertTrue(next.isEnabled, "Continue is enabled")
            next.tap()
        }
        XCTAssertTrue(buttons["goalSetupSex.female"].waitForExistence(timeout: 10))
        if !prefilled { buttons["goalSetupSex.female"].tap() }
        onPage("sex")
        advance()
        XCTAssertTrue(descendants(matching: .any)["goalSetupBirthDate"].waitForExistence(timeout: 5))
        onPage("birthdate")
        advance()
        let weight = textFields["goalSetupWeight"]
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        if !prefilled {
            weight.tap()
            weight.typeText("150")
        }
        onPage("body")
        advance()
        XCTAssertTrue(buttons["goalSetupWorkouts.some"].waitForExistence(timeout: 5))
        if !prefilled { buttons["goalSetupWorkouts.some"].tap() }
        onPage("workouts")
        advance()
        let choice = buttons["goalSetupGoal.\(goal)"]
        XCTAssertTrue(choice.waitForExistence(timeout: 5))
        choice.tap()
        onPage("goal")
        advance()
        if goal != "maintain" {
            XCTAssertTrue(descendants(matching: .any)["goalSetupDesired"].waitForExistence(timeout: 5))
            onPage("desired")
            advance()
            XCTAssertTrue(descendants(matching: .any)["goalSetupPace"].waitForExistence(timeout: 5))
            onPage("pace")
            advance()
        }
        let finish = buttons["goalSetupFinish"]
        XCTAssertTrue(finish.waitForExistence(timeout: 5))
        onPage("plan")
        if tapFinish { finish.tap() }
    }
}
