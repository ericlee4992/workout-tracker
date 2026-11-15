import XCTest

// Tester feedback 02: add a gym from Train → Templates, without visiting Gyms.
final class TrainAddGymUITests: XCTestCase {
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

    private func launch(_ extra: [String], gyms: Bool, large: Bool) {
        app.launchArguments = ["-uiTestReset"] + (gyms ? ["-uiTestDesignSample", "-uiTestDesignGyms"] : []) + extra
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] }
        app.launch()
        app.openTrain()
    }

    /// The New Gym sheet: types the name and saves (or cancels).
    private func fillNewGym(_ name: String, save: Bool) {
        let field = app.textFields["gymName"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "New Gym opens")
        field.tap()
        field.typeText(name)
        if save { app.buttons["saveGym"].tap() } else { app.buttons["Cancel"].firstMatch.tap() }
        XCTAssertTrue(field.waitForNonExistence(timeout: 5), "the sheet closes")
    }

    /// Gyms marks the remembered gym (`AppPreferences.selectedGymID`, D1) "Current": a pick that only the Train screen
    /// held would not show there.
    private func assertRemembered(_ name: String) {
        app.openTrain("Gyms")
        let row = any("gymRow.\(name)")
        XCTAssertTrue(row.waitForExistence(timeout: 10), "\(name) is listed")
        XCTAssertTrue(row.label.contains("Current"), "\(name) is the remembered gym: \(row.label)")
    }

    // MARK: With gyms: the menu's Add Gym…

    func testAddGymFromTheMenuSelectsAndRemembersIt() {
        launch([], gyms: true, large: false)
        let picker = any("gymPicker")
        XCTAssertTrue(picker.waitForExistence(timeout: 15))
        XCTAssertTrue(picker.label.contains("Iron Temple"), "the fixture's gym: \(picker.label)")
        picker.tap()
        let add = app.buttons["trainAddGym"]
        XCTAssertTrue(add.waitForExistence(timeout: 5), "the menu ends with Add Gym…")
        XCTAssertEqual(add.label, "Add Gym…")
        add.tap()
        fillNewGym("Harbor Gym", save: true)
        let selected = NSPredicate(format: "label CONTAINS 'Harbor Gym'")
        XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: selected, evaluatedWith: picker)], timeout: 5), .completed,
                       "the new gym is selected: \(picker.label)")
        assertRemembered("Harbor Gym")
    }

    func testCancelKeepsThePickAndAddsNothing() {
        launch([], gyms: true, large: false)
        let picker = any("gymPicker")
        XCTAssertTrue(picker.waitForExistence(timeout: 15))
        picker.tap()
        app.buttons["trainAddGym"].tap()
        fillNewGym("Ghost Gym", save: false)
        XCTAssertTrue(picker.label.contains("Iron Temple"), "the pick is unchanged: \(picker.label)")
        assertRemembered("Iron Temple")
        XCTAssertFalse(any("gymRow.Ghost Gym").exists, "Cancel created no gym")
    }

    // MARK: No gyms: the row is Add Your Gym…

    func testFirstGymFromTheEmptyRowDefault() { firstGym(large: false) }
    func testFirstGymFromTheEmptyRowAccessibility() { firstGym(large: true) }

    private func firstGym(large: Bool) {
        launch([], gyms: false, large: large)
        let row = any("trainAddGym")
        XCTAssertTrue(row.waitForExistence(timeout: 15), "no gyms: the row adds one")
        XCTAssertEqual(row.label, "Add Your Gym…")
        XCTAssertFalse(any("gymPicker").exists, "nothing to pick yet")
        if large {
            // AccessibilityL: the row's label is whole, inside the screen.
            XCTAssertLessThanOrEqual(row.frame.maxX, app.frame.maxX)
            XCTAssertGreaterThanOrEqual(row.frame.height, 44)
        }
        row.tap()
        fillNewGym("Home Gym", save: true)
        let picker = any("gymPicker")
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "with a gym, the row is the picker again")
        XCTAssertTrue(picker.label.contains("Home Gym"), "the first gym is selected: \(picker.label)")
        assertRemembered("Home Gym")
    }

    // MARK: Captures (light and dark, Default and AccessibilityL)

    func testCaptureLightDefault() { capture("light", large: false) }
    func testCaptureLightAccessibility() { capture("light", large: true) }
    func testCaptureDarkDefault() { capture("dark", large: false) }
    func testCaptureDarkAccessibility() { capture("dark", large: true) }

    private func capture(_ look: String, large: Bool) {
        let suffix = "\(look)-\(large ? "axl" : "default")"
        launch(["-appearance", look], gyms: false, large: large)
        XCTAssertTrue(any("trainAddGym").waitForExistence(timeout: 15))
        Thread.sleep(forTimeInterval: 1.0)
        shoot("tf02-empty-\(suffix)")
        app.terminate()
        launch(["-appearance", look], gyms: true, large: large)
        let picker = any("gymPicker")
        XCTAssertTrue(picker.waitForExistence(timeout: 15))
        picker.tap()
        XCTAssertTrue(app.buttons["trainAddGym"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8)
        shoot("tf02-menu-\(suffix)")
    }
}
