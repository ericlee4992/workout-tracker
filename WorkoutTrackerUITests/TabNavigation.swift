import XCTest

// Soft redesign S2 (D68): the tabs are Today · Train · History · Progress · Profile. The old Workout, Gyms and
// Exercises tabs are Train's parts (Templates | Gyms | Exercises, a segmented switch in Train's bar), and Settings
// is the Profile tab (it was behind the Workout tab's gear, `openSettings`). Today shares Train's Start Lifting /
// Start Cardio / Resume identifiers (`startEmptyWorkout`, `startCardio`, `resumeWorkout`), so a test that starts
// a workout straight after launch still finds them.
extension XCUIApplication {
    /// Train, on the given part ("Templates", "Gyms" or "Exercises").
    func openTrain(_ part: String = "Templates", file: StaticString = #filePath, line: UInt = #line) {
        let tab = tabBars.buttons["Train"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15), "Train tab", file: file, line: line)
        tab.tap()
        let segment = segmentedControls["trainSwitcher"].buttons[part]
        XCTAssertTrue(segment.waitForExistence(timeout: 10), "Train → \(part)", file: file, line: line)
        if !segment.isSelected { segment.tap() }
    }

    /// The Profile tab: the account and every setting.
    func openProfile(file: StaticString = #filePath, line: UInt = #line) {
        let tab = tabBars.buttons["Profile"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15), "Profile tab", file: file, line: line)
        tab.tap()
    }
}
