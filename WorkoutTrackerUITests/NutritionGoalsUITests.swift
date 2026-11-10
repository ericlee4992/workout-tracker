import XCTest

/// Nutrition N3 (D70, D80): Personal details filled by hand make a goal; a typed number stays until Recalculate; the
/// two pages on record in light and dark at Default and AccessibilityL.
final class NutritionGoalsUITests: XCTestCase {
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

    private func type(_ text: String, into id: String) {
        let field = app.textFields[id]
        XCTAssertTrue(field.waitForExistence(timeout: 5), id)
        if !field.hasFocus { field.tap() }
        if let old = field.value as? String, !old.isEmpty, old != field.placeholderValue {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count))
        }
        field.typeText(text)
    }

    private func save() {
        let save = app.buttons["detailEditorSave"]
        XCTAssertTrue(save.isEnabled, "Save is enabled")
        save.tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 5))
    }

    // MARK: Flow

    func testPersonalDetailsMakeAGoalAndATypedNumberStaysUntilRecalculate() {
        app.launchArguments = ["-uiTestReset", "-uiTestDesignSample"]
        app.launch()
        app.openProfile()
        let goalsRow = app.buttons["profileNutritionGoals"]
        XCTAssertTrue(goalsRow.waitForExistence(timeout: 10))
        XCTAssertTrue(goalsRow.label.hasSuffix("Not set"), goalsRow.label)

        let details = app.buttons["profilePersonalDetails"]
        for _ in 0..<4 where !details.isHittable { app.swipeUp() }
        details.tap()
        app.buttons["personalWeight"].tap()
        type("176.4", into: "weightField")
        save()
        app.buttons["personalHeight"].tap()
        if app.textFields["heightFeet"].waitForExistence(timeout: 3) {
            type("5", into: "heightFeet")
            type("11", into: "heightInches")
        } else {
            type("180", into: "heightCm")
        }
        save()
        app.buttons["personalBirthDate"].tap()
        XCTAssertTrue(any("birthDatePicker").waitForExistence(timeout: 5))
        save()  // the picker opens on 30 years ago
        XCTAssertTrue(app.buttons["personalWeight"].label.contains("176.4"), app.buttons["personalWeight"].label)
        any("personalSex").tap()
        app.buttons["Male"].firstMatch.tap()
        let sex = any("personalSex")
        XCTAssertTrue(NSPredicate(format: "label CONTAINS 'Male'").evaluate(with: sex), sex.label)

        app.openProfile()  // back to the root: the goal now exists
        XCTAssertTrue(goalsRow.waitForExistence(timeout: 5))
        XCTAssertFalse(goalsRow.label.hasSuffix("Not set"), goalsRow.label)
        XCTAssertTrue(goalsRow.label.hasSuffix("cal"), goalsRow.label)
        goalsRow.tap()
        let calories = any("nutritionGoalsCalories")
        XCTAssertTrue(calories.waitForExistence(timeout: 5))
        XCTAssertTrue(calories.label.contains("Calculated"), calories.label)

        let protein = app.buttons["nutritionGoals.Protein"]
        protein.tap()
        type("200", into: "goalProteinField")
        save()
        XCTAssertTrue(protein.label.contains("200") && protein.label.contains("Typed by you"), protein.label)
        let recalculate = app.buttons["nutritionGoalsRecalculate"]
        XCTAssertTrue(recalculate.waitForExistence(timeout: 5))

        // A typed number stays when the goal choice changes; the calories follow it.
        let before = calories.label
        any("nutritionGoalsGoal").tap()
        app.buttons["Lose weight"].firstMatch.tap()
        XCTAssertTrue(NSPredicate(format: "label != %@", before).evaluate(with: calories), "the calories followed the goal")
        XCTAssertTrue(protein.label.contains("200"), protein.label)

        recalculate.tap()
        XCTAssertTrue(recalculate.waitForNonExistence(timeout: 5))
        XCTAssertFalse(protein.label.contains("Typed by you"), protein.label)
    }

    /// codex-review-n3 #1: the date of birth is shared with the zones sheet. Clearing it there leaves nothing to
    /// calculate, so the goals page offers no numbers to edit (an edit would otherwise be dropped silently).
    func testClearingTheBirthDateInTheZonesSheetLeavesNothingToEdit() {
        app.launchArguments = ["-uiTestReset", "-uiTestDesignSample", "-uiTestPersonalDetails"]
        app.launch()
        app.openProfile()
        let zones = app.buttons["heartRateZonesSettings"]
        XCTAssertTrue(zones.waitForExistence(timeout: 10))
        zones.tap()
        let useBirthDate = app.switches["useBirthDate"]
        XCTAssertTrue(useBirthDate.waitForExistence(timeout: 5))
        XCTAssertEqual(useBirthDate.value as? String, "1", "the fixture's date of birth")
        useBirthDate.switches.firstMatch.exists ? useBirthDate.switches.firstMatch.tap() : useBirthDate.tap()
        app.buttons["saveMaxHeartRate"].tap()
        XCTAssertTrue(app.buttons["saveMaxHeartRate"].waitForNonExistence(timeout: 5))

        app.buttons["profileNutritionGoals"].tap()
        let details = app.buttons["nutritionGoalsDetails"]
        XCTAssertTrue(details.waitForExistence(timeout: 5))
        XCTAssertTrue(details.label.contains("Not set"), details.label)
        XCTAssertFalse(any("nutritionGoalsCalories").exists, "no numbers to edit without complete details")
        XCTAssertFalse(app.alerts.firstMatch.exists, "opening the page is not an error")
    }

    /// codex-review-n3b #1: Recalculate pressed while the details are incomplete is kept, and applied once they are
    /// complete again — the typed number does not come back.
    func testRecalculateWhileDetailsAreIncompleteSticks() {
        app.launchArguments = ["-uiTestReset", "-uiTestDesignSample", "-uiTestPersonalDetails"]
        app.launch()
        app.openProfile()
        app.buttons["profileNutritionGoals"].tap()
        let protein = app.buttons["nutritionGoals.Protein"]
        XCTAssertTrue(protein.waitForExistence(timeout: 5))
        protein.tap()
        type("200", into: "goalProteinField")
        save()
        XCTAssertTrue(protein.label.contains("Typed by you"), protein.label)

        app.openProfile()  // pops to the root
        let zones = app.buttons["heartRateZonesSettings"]
        XCTAssertTrue(zones.waitForExistence(timeout: 5))
        zones.tap()
        let useBirthDate = app.switches["useBirthDate"]
        XCTAssertTrue(useBirthDate.waitForExistence(timeout: 5))
        useBirthDate.switches.firstMatch.exists ? useBirthDate.switches.firstMatch.tap() : useBirthDate.tap()
        app.buttons["saveMaxHeartRate"].tap()
        XCTAssertTrue(app.buttons["saveMaxHeartRate"].waitForNonExistence(timeout: 5))

        app.buttons["profileNutritionGoals"].tap()
        let recalculate = app.buttons["nutritionGoalsRecalculate"]
        XCTAssertTrue(recalculate.waitForExistence(timeout: 5), "the typed protein still offers Recalculate")
        recalculate.tap()
        XCTAssertTrue(recalculate.waitForNonExistence(timeout: 5))

        app.buttons["nutritionGoalsDetails"].tap()
        tapRow("personalBirthDate")
        XCTAssertTrue(any("birthDatePicker").waitForExistence(timeout: 5))
        save()  // the picker opens on 30 years ago: the details are complete again
        app.navigationBars.buttons.element(boundBy: 0).tap()  // back to Nutrition goals
        XCTAssertTrue(protein.waitForExistence(timeout: 5))
        XCTAssertFalse(protein.label.contains("Typed by you"), "Recalculate was kept: \(protein.label)")
        XCTAssertFalse(recalculate.exists)
    }

    // MARK: Onboarding step (new installs)

    /// Skip on the Welcome page → the goals sheet; an activity chosen before the details is kept for the first goal.
    func testWelcomeSkipOffersTheGoalsSheetOnce() { onboarding(appearance: "light", large: false) }
    /// The same flow on record in dark at AccessibilityL, with each editor and its keyboard.
    func testWelcomeSkipOffersTheGoalsSheetDarkAccessibility() { onboarding(appearance: "dark", large: true) }

    private func onboarding(appearance: String, large: Bool) {
        let tag = "\(appearance)-\(large ? "axl" : "default")"
        app.launchArguments = ["-uiTestReset", "-uiTestOnboarding", "-uiTestOnboardingFresh", "-uiTestFoodGoalsStep",
                               "-appearance", appearance]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] }
        app.launch()
        let skip = app.buttons["welcomeSkip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 15))
        skip.tap()
        let done = app.buttons["foodGoalsDone"]
        XCTAssertTrue(done.waitForExistence(timeout: 10), "the goals sheet follows the Welcome page")
        XCTAssertFalse(any("foodGoalsCalories").exists, "nothing to calculate yet")
        shoot("n3-onboarding-empty-\(tag)")

        let activity = any("nutritionGoalsActivity")
        reveal(activity)
        activity.tap()
        app.buttons["Light"].firstMatch.tap()
        tapRow("personalWeight")
        type("176.4", into: "weightField")
        shoot("n3-editor-weight-\(tag)")
        save()
        tapRow("personalHeight")
        if app.textFields["heightFeet"].waitForExistence(timeout: 3) {
            type("5", into: "heightFeet")
            type("11", into: "heightInches")
        } else {
            type("180", into: "heightCm")
        }
        shoot("n3-editor-height-\(tag)")
        save()
        tapRow("personalBirthDate")
        XCTAssertTrue(any("birthDatePicker").waitForExistence(timeout: 5))
        shoot("n3-editor-birthdate-\(tag)")
        save()
        let sexRow = any("personalSex")
        reveal(sexRow)
        sexRow.tap()
        app.buttons["Male"].firstMatch.tap()
        let calories = any("foodGoalsCalories")
        XCTAssertTrue(calories.waitForExistence(timeout: 5), "the calories appear once complete")
        reveal(calories)
        XCTAssertTrue(NSPredicate(format: "label CONTAINS 'Light'").evaluate(with: any("nutritionGoalsActivity")),
                      "the activity chosen first is kept: \(any("nutritionGoalsActivity").label)")
        shoot("n3-onboarding-filled-\(tag)")
        done.tap()
        XCTAssertTrue(done.waitForNonExistence(timeout: 5))

        app.openProfile()
        let goals = app.buttons["profileNutritionGoals"]
        XCTAssertTrue(goals.waitForExistence(timeout: 5))
        XCTAssertTrue(goals.label.hasSuffix("cal"), goals.label)
    }

    /// Scrolls a Personal details row on screen (AccessibilityL pushes the lower rows down) and taps it.
    private func tapRow(_ id: String) {
        let row = app.buttons[id]
        XCTAssertTrue(row.waitForExistence(timeout: 5), id)
        reveal(row)
        row.tap()
    }

    /// Short drags towards `element` until it is hittable — never a full swipe down, which at the top of a sheet's
    /// content dismisses the sheet (the first dark/AXL run).
    private func reveal(_ element: XCUIElement) {
        for _ in 0..<10 where !(element.exists && element.isHittable) {
            let below = !element.exists || element.frame.minY > app.frame.midY
            let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: below ? 0.7 : 0.45))
            let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: below ? 0.45 : 0.7))
            from.press(forDuration: 0.05, thenDragTo: to)
            Thread.sleep(forTimeInterval: 0.3)
        }
        XCTAssertTrue(element.isHittable, "reached \(element)")
    }

    // MARK: Captures

    func testCaptureLightDefault() { capture(appearance: "light", large: false) }
    func testCaptureDarkDefault() { capture(appearance: "dark", large: false) }
    func testCaptureLightAccessibility() { capture(appearance: "light", large: true) }
    func testCaptureDarkAccessibility() { capture(appearance: "dark", large: true) }

    private func capture(appearance: String, large: Bool) {
        app.launchArguments = ["-uiTestReset", "-uiTestDesignSample", "-uiTestPersonalDetails", "-appearance", appearance]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] }
        app.launch()
        let tag = "\(appearance)-\(large ? "axl" : "default")"
        app.openProfile()
        let goals = app.buttons["profileNutritionGoals"]
        XCTAssertTrue(goals.waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 0.8)
        shoot("n3-profile-\(tag)")
        goals.tap()
        XCTAssertTrue(any("nutritionGoalsCalories").waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8)
        shoot("n3-goals-\(tag)-1")
        if large { app.swipeUp(); Thread.sleep(forTimeInterval: 0.6); shoot("n3-goals-\(tag)-2") }
        app.buttons["nutritionGoals.Protein"].firstMatch.tap()
        XCTAssertTrue(app.textFields["goalProteinField"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8)
        shoot("n3-goals-edit-\(tag)")
        app.buttons["Cancel"].firstMatch.tap()
        app.openProfile()
        let details = app.buttons["profilePersonalDetails"]
        XCTAssertTrue(details.waitForExistence(timeout: 5))
        for _ in 0..<4 where !details.isHittable { app.swipeUp() }
        details.tap()
        XCTAssertTrue(app.buttons["personalWeight"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8)
        shoot("n3-details-\(tag)")
    }
}
