import XCTest

// Floodlight redesign ticket 06: the Gyms flows the redesign adds — Delete Gym… (confirmed) and
// Restore from the Gyms list, and the machine page's inline setup (name, unit, usual preset) and
// its Delete Machine… — on the design sample with its Gyms extras.
final class GymsFlowsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestReset", "-uiTestDesignSample", "-uiTestDesignHistory", "-uiTestDesignGyms"]
        app.launch()
        app.tabBars.buttons["Gyms"].tap()
    }

    private func any(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func waitForAbsence(of element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let gone = NSPredicate(format: "exists == false")
        return XCTWaiter().wait(for: [expectation(for: gone, evaluatedWith: element)], timeout: timeout) == .completed
    }

    /// Scrolls the page until `element` is on screen and clear of the tab bar.
    private func reach(_ element: XCUIElement) {
        for _ in 0..<10 where !(element.exists && element.isHittable
                                && element.frame.maxY < app.tabBars.firstMatch.frame.minY - 8) {
            app.swipeUp()
        }
    }

    /// Edit Gym → Delete Gym… → Cancel changes nothing; → Delete Gym leaves the list and pops the
    /// page; the deleted gym is restorable from the list, and comes back with its machines.
    func testDeleteGymIsConfirmedAndRestorable() {
        let hotel = any("gymRow.Hotel Gym")
        XCTAssertTrue(hotel.waitForExistence(timeout: 15))
        hotel.tap()
        app.buttons["editGym"].tap()
        let delete = app.buttons["deleteGym"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()
        let confirm = app.alerts.buttons["Delete Gym"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "a confirmation stands between the tap and the deletion")
        XCTAssertTrue(app.alerts.staticTexts["Delete Hotel Gym?"].exists)
        app.alerts.buttons["Cancel"].tap()
        XCTAssertTrue(waitForAbsence(of: confirm))
        delete.tap()
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()

        // Back on the list (the gym's page closed): gone from the cards, listed as deleted.
        let deleted = any("deletedGyms")
        XCTAssertTrue(deleted.waitForExistence(timeout: 10), "the Gyms list offers its deleted gyms")
        XCTAssertTrue(waitForAbsence(of: any("gymRow.Hotel Gym")), "the gym left the list")
        reach(deleted)
        deleted.tap()
        let restore = app.buttons["restoreGym.Hotel Gym"]
        XCTAssertTrue(restore.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["restoreGym.Gangnam Fitness"].exists, "the fixture's deleted gym is listed too")
        reach(restore)
        restore.tap()
        XCTAssertTrue(any("gymRow.Hotel Gym").waitForExistence(timeout: 5), "restored, the gym is back")
        XCTAssertFalse(app.buttons["restoreGym.Hotel Gym"].exists)
    }

    /// The machine page: a best that opens its chart, the name edited inline (a blank one puts the
    /// old one back), the unit override set, and Delete Machine… closing the page.
    func testMachinePageEditsApplyAndDeleteCloses() {
        XCTAssertTrue(any("gymRow.Iron Temple").waitForExistence(timeout: 15))
        any("gymRow.Iron Temple").tap()
        let row = any("machineRow.Seated Row")
        reach(row)
        row.staticTexts["Seated Row"].tap()

        // The best opens the progress chart on this machine's variation.
        let best = any("machineDetail.best.0")
        XCTAssertTrue(best.waitForExistence(timeout: 10), "Seated Row carries Pull Day's history")
        XCTAssertTrue(best.label.contains("Seated Row"), "got \(best.label)")
        best.tap()
        XCTAssertTrue(any("progressChart").waitForExistence(timeout: 10), "the best opens its chart")
        app.buttons["closeProgress"].tap()

        // Rename inline: a blank name restores the old one; a new one is saved.
        let name = app.textFields["machineDetail.name"]
        reach(name)
        // The field is trailing-aligned: tap its trailing end so the cursor lands after the text.
        let end = name.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5))
        let clear = String(repeating: XCUIKeyboardKey.delete.rawValue, count: 16)
        end.tap()
        name.typeText(clear + "\n")
        XCTAssertEqual(name.value as? String, "Seated Row", "a blank name puts the old one back")
        end.tap()
        name.typeText(clear + "Seated Row 2\n")
        XCTAssertEqual(name.value as? String, "Seated Row 2")

        // The unit override: kg, applied at once (its tag shows on the hero).
        let unit = any("machineDetail.unit")
        reach(unit)
        unit.buttons["kg"].tap()
        XCTAssertTrue(app.staticTexts["kg"].waitForExistence(timeout: 5), "the kg override is tagged")

        // Delete Machine… → confirmed → the page closes and the gym lists it as deleted.
        let delete = any("machineDetail.delete")
        reach(delete)
        delete.tap()
        let confirm = app.alerts.buttons["Delete Machine"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        let deletedMachines = any("deletedMachines")
        reach(deletedMachines)
        XCTAssertTrue(deletedMachines.waitForExistence(timeout: 10), "back on the gym's page")
        XCTAssertTrue(deletedMachines.label.contains("2"), "Old Row and Seated Row 2: \(deletedMachines.label)")
        XCTAssertFalse(any("machineRow.Seated Row 2").exists)
    }
}
