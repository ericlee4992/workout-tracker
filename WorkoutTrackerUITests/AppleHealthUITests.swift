import XCTest

/// Nutrition N9b: Profile → Apple Health with Health faked (`-uiTestHealthSample`: two scale weights this week, 412 cal
/// of active energy today). Turning reading on shows Health's weights on Body weight (read-only, "Apple Health") and
/// Health's active energy as Burned on Today; turning it off takes them away; a save Health refused is said under its
/// switch. Captures in light at Default and dark at AccessibilityL.
final class AppleHealthUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(_ extra: [String] = [], appearance: String = "light", large: Bool = false) {
        app.launchArguments = ["-uiTestReset", "-uiTestDesignSample", "-uiTestPersonalDetails", "-uiTestFoodSample",
                               "-uiTestFoodDiary", "-uiTestHealthSample", "-appearance", appearance] + extra
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] }
        app.launch()
        XCTAssertTrue(any("todayEaten").waitForExistence(timeout: 15))
    }

    private func any(_ id: String) -> XCUIElement { app.descendants(matching: .any)[id] }

    private func number(_ id: String) -> Int { Int(any(id).label.filter(\.isNumber)) ?? -1 }

    private func tab(_ name: String) {
        let button = app.tabBars.buttons[name].exists ? app.tabBars.buttons[name] : app.buttons[name]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        button.tap()
    }

    private func reveal(_ element: XCUIElement) {
        for _ in 0..<8 {
            guard !(element.exists && element.isHittable) else { break }
            app.swipeUp()
        }
    }

    private func openProfileRow(_ id: String) {
        tab("Profile")
        let row = app.buttons[id]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        reveal(row)
        row.tap()
    }

    private func back() {
        app.navigationBars.buttons.firstMatch.tap()
    }

    private func toggle(_ part: String, on: Bool) {
        let control = app.switches["appleHealth.\(part)"].firstMatch
        XCTAssertTrue(control.waitForExistence(timeout: 5))
        reveal(control)
        if (control.value as? String == "1") != on {
            control.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        }
        let expected = on ? "1" : "0"
        let predicate = NSPredicate(format: "value == %@", expected)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: predicate, evaluatedWith: control)], timeout: 5),
                       .completed, "\(part) \(expected)")
    }

    private func shoot(_ name: String) {
        Thread.sleep(forTimeInterval: 0.7)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testReadingWeightAndBurnedFromHealthAndTurningItOff() {
        launch()
        XCTAssertEqual(number("todayBurned"), 320, "Health off: the fixture's measured run")

        tab("Profile")
        XCTAssertTrue(app.buttons["profileAppleHealth"].label.hasSuffix("Off"), app.buttons["profileAppleHealth"].label)
        openProfileRow("profileAppleHealth")
        toggle("readWeight", on: true)
        toggle("readBurned", on: true)
        back()
        XCTAssertTrue(app.buttons["profileAppleHealth"].label.hasSuffix("On"), app.buttons["profileAppleHealth"].label)

        // Health's two weights (81.2 and 81.6 kg) beside the app's own, in the app's unit (lb), read-only.
        openProfileRow("profileBodyWeight")
        let reading = any("bodyWeightEntry.179.9 lb")
        reveal(reading)
        XCTAssertTrue(reading.waitForExistence(timeout: 5))
        XCTAssertTrue(reading.label.contains("Apple Health"), reading.label)
        XCTAssertTrue(any("bodyWeightEntry.179 lb").exists)
        XCTAssertTrue(any("bodyWeightLatest").label.contains("176.4"), "the app's own weight is still the latest")
        reading.tap()
        XCTAssertFalse(app.buttons["logWeightSave"].waitForExistence(timeout: 1.5), "Health's weight is not edited here")

        tab("Today")
        let burned = NSPredicate(format: "label CONTAINS '412'")
        XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: burned, evaluatedWith: any("todayBurned"))], timeout: 5),
                       .completed, any("todayBurned").label)

        tab("Profile")
        back()  // Body weight → Profile
        openProfileRow("profileAppleHealth")
        toggle("readWeight", on: false)
        toggle("readBurned", on: false)
        back()
        openProfileRow("profileBodyWeight")
        XCTAssertTrue(any("bodyWeightEntry.179.9 lb").waitForNonExistence(timeout: 5))
        tab("Today")
        XCTAssertEqual(number("todayBurned"), 320)
    }

    func testASaveHealthRefusedIsSaidUnderItsSwitch() {
        launch(["-uiTestHealthRefused"])
        openProfileRow("profileAppleHealth")
        toggle("writeWeight", on: true)
        toggle("writeFood", on: true)
        XCTAssertTrue(any("appleHealthRefused.writeFood").waitForExistence(timeout: 5))
        XCTAssertFalse(any("appleHealthRefused.writeWeight").exists, "weight was allowed")
        XCTAssertTrue(app.switches["appleHealth.writeWeight"].firstMatch.value as? String == "1")
    }

    func testCaptureLightDefault() { capture(appearance: "light", large: false) }
    func testCaptureDarkAccessibility() { capture(appearance: "dark", large: true) }

    private func capture(appearance: String, large: Bool) {
        let tag = "\(appearance)-\(large ? "axl" : "default")"
        launch([HealthFixture.on, HealthFixture.refused], appearance: appearance, large: large)
        openProfileRow("profileAppleHealth")
        XCTAssertTrue(app.switches["appleHealth.readWeight"].firstMatch.waitForExistence(timeout: 5))
        shoot("n9b-applehealth-\(tag)")
        app.swipeUp()
        shoot("n9b-applehealth-end-\(tag)")
        back()
        openProfileRow("profileBodyWeight")
        let reading = any("bodyWeightEntry.179.9 lb")
        reveal(reading)
        shoot("n9b-bodyweight-health-\(tag)")
        tab("Today")
        shoot("n9b-today-burned-\(tag)")
    }
}

/// The fixture's launch arguments (the app's `HealthFixture`; the UI test target does not link the app's code).
private enum HealthFixture {
    static let on = "-uiTestHealthOn"
    static let refused = "-uiTestHealthRefused"
}
