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
