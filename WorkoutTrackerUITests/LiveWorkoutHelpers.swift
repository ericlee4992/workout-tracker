import XCTest

// UI-test helpers shared by the Floodlight redesign's tickets.
// The Floodlight redesign moved discarding a workout from a toolbar Cancel to
// "Discard Workout…" at the end of the workout list (still confirmed by the same dialog).
extension XCUIApplication {
    func discardActiveWorkout(file: StaticString = #filePath, line: UInt = #line) {
        let discard = buttons["discardWorkout"]
        for _ in 0..<8 where !(discard.exists && discard.isHittable) { swipeUp() }
        XCTAssertTrue(discard.exists && discard.isHittable, "Discard Workout… at the end of the list", file: file, line: line)
        discard.tap()
        let confirm = buttons["Discard Workout"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "the discard is confirmed", file: file, line: line)
        confirm.tap()
    }

    /// A tab root's search field: iOS 27 keeps a large-title list's search in the navigation
    /// bar's drawer, hidden until the list is pulled down (it failed on main a0364f2, the
    /// Exercises tab). A sheet's field is already visible, so this is a no-op there.
    /// Floodlight ticket 08: the Exercises tab searches in its own field under the title (not the
    /// bar's drawer), and each row is one element named by its identifier. Types `name` and
    /// returns that row.
    func exercisesTabRow(_ name: String, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let field = textFields["exerciseSearch"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "The Exercises tab should be searchable", file: file, line: line)
        field.tap()
        // Search ends editing: with the field still focused, closing a sheet opened from the row
        // gives the keyboard back, and it covers the tab bar (ExercisePreset's next tab tap).
        field.typeText(name + "\n")
        return descendants(matching: .any).matching(identifier: "exerciseRow.\(name)").firstMatch
    }

    func revealedSearchField(file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let field = searchFields.firstMatch
        for _ in 0..<3 where !field.waitForExistence(timeout: 2) {
            let top = navigationBars.firstMatch.exists ? navigationBars.firstMatch : windows.firstMatch
            top.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1.2))
                .press(forDuration: 0.05, thenDragTo: top.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 4)))
        }
        XCTAssertTrue(field.exists, "This screen should be searchable", file: file, line: line)
        return field
    }
}
