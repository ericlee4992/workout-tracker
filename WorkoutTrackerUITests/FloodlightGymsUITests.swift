import XCTest

// Floodlight redesign ticket 06: the Gyms tab — the gym list (and its deleted gyms), a gym's page,
// a machine's page, Deleted Machines, Edit Gym, the machine form, the model picker (browse,
// search, no match) and New Model — on record in light and dark at Default and AccessibilityL,
// on the design sample with its History and Gyms extras; and the empty tab.
final class FloodlightGymsUITests: XCTestCase {
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

    func testCaptureGymsLightDefault() { captureGyms(appearance: "light", large: false) }
    func testCaptureGymsLightAccessibility() { captureGyms(appearance: "light", large: true) }
    func testCaptureGymsDarkDefault() { captureGyms(appearance: "dark", large: false) }
    func testCaptureGymsDarkAccessibility() { captureGyms(appearance: "dark", large: true) }

    func testCaptureEditorsLightDefault() { captureEditors(appearance: "light", large: false) }
    func testCaptureEditorsLightAccessibility() { captureEditors(appearance: "light", large: true) }
    func testCaptureEditorsDarkDefault() { captureEditors(appearance: "dark", large: false) }
    func testCaptureEditorsDarkAccessibility() { captureEditors(appearance: "dark", large: true) }

    func testCaptureEmptyLight() { captureEmpty(appearance: "light", large: false) }
    func testCaptureEmptyDark() { captureEmpty(appearance: "dark", large: false) }
    func testCaptureEmptyLightAccessibility() { captureEmpty(appearance: "light", large: true) }
    func testCaptureEmptyDarkAccessibility() { captureEmpty(appearance: "dark", large: true) }

    private func launch(_ arguments: [String], appearance: String, large: Bool) {
        app.launchArguments = arguments + ["-appearance", appearance]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] }
        app.launch()
    }

    private func launchSample(appearance: String, large: Bool) {
        launch(["-uiTestReset", "-uiTestDesignSample", "-uiTestDesignHistory", "-uiTestDesignGyms"],
               appearance: appearance, large: large)
        app.tabBars.buttons["Gyms"].tap()
    }

    /// Swipes up until `element` is on screen and clear of the bars, up to `limit` times,
    /// shooting each page after the first under `name`.
    private func page(to element: XCUIElement, name: String, limit: Int = 8) {
        var page = 2
        while !(element.exists && element.isHittable && element.frame.maxY < app.frame.maxY - 100), page <= limit + 1 {
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.5)
            shoot("\(name)-\(page)")
            page += 1
        }
    }

    // MARK: List, gym page, machine page, deleted machines

    private func captureGyms(appearance: String, large: Bool) {
        launchSample(appearance: appearance, large: large)
        let suffix = "\(appearance)-\(large ? "axl" : "default")"

        // G01: Iron Temple (Current) first, Hotel Gym after it; the deleted gym under Add Gym….
        let iron = any("gymRow.Iron Temple")
        XCTAssertTrue(iron.waitForExistence(timeout: 15))
        XCTAssertTrue(iron.label.contains("Current"), "the gym Home is set to is marked: \(iron.label)")
        XCTAssertTrue(any("gymRow.Hotel Gym").exists)
        XCTAssertLessThan(iron.frame.minY, any("gymRow.Hotel Gym").frame.minY, "the Current gym leads")
        Thread.sleep(forTimeInterval: 1.2)
        shoot("floodlight-06-gyms-\(suffix)-1")
        let deleted = any("deletedGyms")
        page(to: deleted, name: "floodlight-06-gyms-\(suffix)")
        deleted.tap()
        XCTAssertTrue(app.buttons["restoreGym.Gangnam Fitness"].waitForExistence(timeout: 5))
        page(to: app.buttons["restoreGym.Gangnam Fitness"], name: "floodlight-06-gyms-deleted-\(suffix)", limit: 2)
        shoot("floodlight-06-gyms-deleted-\(suffix)")
        for _ in 0..<4 { app.swipeDown() }

        // G03: the gym's page, grouped by body area, then by exercise.
        iron.tap()
        XCTAssertTrue(any("scanMachine").waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["editGym"].exists)
        Thread.sleep(forTimeInterval: 1.2)
        let bodyArea = any("machineGrouping.bodyArea")
        if large {
            // AX: the grouping is a compact menu.
            XCTAssertTrue(any("machineGrouping.bodyArea").exists || app.buttons["Group Machines By"].exists)
        } else {
            XCTAssertTrue(bodyArea.exists, "the grouping pills")
            bodyArea.tap()
        }
        shoot("floodlight-06-gym-\(suffix)-1")
        let deletedMachines = any("deletedMachines")
        page(to: deletedMachines, name: "floodlight-06-gym-\(suffix)", limit: 10)
        XCTAssertTrue(deletedMachines.label.contains("1"), "one deleted machine: \(deletedMachines.label)")
        if !large {
            for _ in 0..<10 { app.swipeDown() }
            any("machineGrouping.exercise").tap()
            Thread.sleep(forTimeInterval: 0.8)
            shoot("floodlight-06-gym-exercise-\(suffix)")
            any("machineGrouping.bodyArea").tap()
            page(to: deletedMachines, name: "floodlight-06-gym-back-\(suffix)", limit: 10)
        }

        // G07: Deleted Machines.
        deletedMachines.tap()
        XCTAssertTrue(app.buttons["restoreMachine.Old Row"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8)
        shoot("floodlight-06-deleted-\(suffix)")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // G04: Chest Press 2's page — its bests (charted), setup, exercises, model, delete.
        for _ in 0..<12 { app.swipeDown() }
        let chest = any("machineRow.Chest Press 2")
        for _ in 0..<8 where !(chest.exists && chest.isHittable
                               && chest.frame.maxY < app.tabBars.firstMatch.frame.minY - 8) { app.swipeUp() }
        chest.staticTexts["Chest Press 2"].tap()
        XCTAssertTrue(any("machineDetail.best.0").waitForExistence(timeout: 10), "a used machine shows its bests")
        Thread.sleep(forTimeInterval: 1.4)
        shoot("floodlight-06-machine-\(suffix)-1")
        page(to: any("machineDetail.delete"), name: "floodlight-06-machine-\(suffix)")
        XCTAssertTrue(any("machineDetail.correctModel").exists)
    }

    // MARK: Edit Gym, the machine form, the picker, New Model

    private func captureEditors(appearance: String, large: Bool) {
        launchSample(appearance: appearance, large: large)
        let suffix = "\(appearance)-\(large ? "axl" : "default")"
        let iron = any("gymRow.Iron Temple")
        XCTAssertTrue(iron.waitForExistence(timeout: 15))
        iron.tap()

        // G05: Edit Gym, then its lower half (Delete Gym…).
        let edit = app.buttons["editGym"]
        XCTAssertTrue(edit.waitForExistence(timeout: 10))
        edit.tap()
        XCTAssertTrue(app.textFields["gymName"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["saveGym"].isEnabled, "nothing changed yet: Save waits")
        Thread.sleep(forTimeInterval: 0.8)
        shoot("floodlight-06-editgym-\(suffix)-1")
        if !app.buttons["deleteGym"].isHittable { app.swipeUp(); shoot("floodlight-06-editgym-\(suffix)-2") }
        XCTAssertTrue(app.buttons["deleteGym"].exists)
        app.buttons["Cancel"].firstMatch.tap()

        // The machine form, and the catalog from it.
        let add = any("addMachine")
        // Clear of the tab bar, not just "hittable": a row half under the bar takes the tap there.
        for _ in 0..<10 where !(add.exists && add.isHittable
                                && add.frame.maxY < app.tabBars.firstMatch.frame.minY - 8) { app.swipeUp() }
        add.tap()
        XCTAssertTrue(app.textFields["machineLabel"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8)
        shoot("floodlight-06-machineform-\(suffix)")
        any("catalogModel").tap()
        XCTAssertTrue(any("modelFilter.type.all").waitForExistence(timeout: 10), "the type chips")
        Thread.sleep(forTimeInterval: 1)
        shoot("floodlight-06-picker-\(suffix)-1")
        app.swipeUp()
        shoot("floodlight-06-picker-\(suffix)-2")
        // Back to the top: the pinned New Model… row is the list's first (a lazy row).
        app.swipeDown(); app.swipeDown()
        let field = app.revealedSearchField()
        field.tap()
        field.typeText("hack squat")
        XCTAssertTrue(any("newModelFromSearch").waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8)
        shoot("floodlight-06-picker-search-\(suffix)")
        field.buttons.firstMatch.tap() // clear
        field.typeText("life fitness belt squat")
        XCTAssertTrue(any("noModelsMatch").waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8)
        shoot("floodlight-06-picker-nomatch-\(suffix)")

        // New Model… prefilled from the search.
        any("newModelFromSearch").tap()
        let manufacturer = app.textFields["Manufacturer"]
        XCTAssertTrue(manufacturer.waitForExistence(timeout: 5))
        XCTAssertEqual(manufacturer.value as? String, "Life Fitness", "the maker split off the search")
        XCTAssertEqual(app.textFields["Model"].value as? String, "Belt Squat")
        Thread.sleep(forTimeInterval: 0.8)
        shoot("floodlight-06-newmodel-\(suffix)-1")
        app.swipeUp()
        shoot("floodlight-06-newmodel-\(suffix)-2")
    }

    // MARK: Empty

    private func captureEmpty(appearance: String, large: Bool) {
        launch(["-uiTestReset"], appearance: appearance, large: large)
        app.tabBars.buttons["Gyms"].tap()
        XCTAssertTrue(app.staticTexts["No gyms yet"].waitForExistence(timeout: 10))
        XCTAssertTrue(any("addGym").isHittable, "Add Gym… on screen")
        Thread.sleep(forTimeInterval: 0.6)
        shoot("floodlight-06-empty-\(appearance)\(large ? "-axl" : "")")
    }
}
