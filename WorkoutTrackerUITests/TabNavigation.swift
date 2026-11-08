import XCTest

// Soft redesign S2 (D68): the tabs are Today · Train · History · Progress · Profile. The old Workout, Gyms and
// Exercises tabs are Train's parts (Templates | Gyms | Exercises, a segmented switch in Train's bar), and Settings
// is the Profile tab (it was behind the Workout tab's gear, `openSettings`). Today shares Train's Resume identifier
// (`resumeWorkout`). S5 (D77): Start Lifting / Start Cardio (`startEmptyWorkout`, `startCardio`) are on Train only —
// reach them with `trainStartButton(_:)`.
extension XCUIApplication {
    /// Train, on the given part ("Templates", "Gyms" or "Exercises").
    func openTrain(_ part: String = "Templates", file: StaticString = #filePath, line: UInt = #line) {
        let tab = tabBars.buttons["Train"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15), "Train tab", file: file, line: line)
        tab.tap()
        // The switch is on Train's root pages only (codex-review-s2 #1): a page left pushed in the shown part hides
        // it, and tapping the selected tab again pops that part back to its root.
        if !segmentedControls["trainSwitcher"].waitForExistence(timeout: 3) { tab.tap() }
        let segment = segmentedControls["trainSwitcher"].buttons[part]
        XCTAssertTrue(segment.waitForExistence(timeout: 10), "Train → \(part)", file: file, line: line)
        if !segment.isSelected { segment.tap() }
    }

    /// Train's Start Lifting (`startEmptyWorkout`) or Start Cardio (`startCardio`). S5 (D77): Today no longer has them,
    /// so when the button is not on screen this opens Train → Templates first (a no-op when Train already shows it,
    /// e.g. under the tour).
    func trainStartButton(_ id: String, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let button = buttons[id]
        if !button.exists { openTrain("Templates", file: file, line: line) }
        return button
    }

    /// The Profile tab: the account and every setting.
    func openProfile(file: StaticString = #filePath, line: UInt = #line) {
        let tab = tabBars.buttons["Profile"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15), "Profile tab", file: file, line: line)
        tab.tap()
    }
}
