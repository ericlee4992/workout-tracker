import XCTest

// The Floodlight redesign's template editor adds exercises from a searchable picker sheet
// (it used to list every exercise inline in the Form).
extension XCUIApplication {
    /// Opens Add Exercise, searches each name and adds it, then closes the picker.
    func addTemplateExercises(_ names: [String], file: StaticString = #filePath, line: UInt = #line) {
        let add = buttons["addTemplateExercise"]
        for _ in 0..<4 where !(add.exists && add.isHittable) { swipeUp() }
        XCTAssertTrue(add.waitForExistence(timeout: 5), "Add Exercise in the editor", file: file, line: line)
        add.tap()
        let search = textFields["Search exercises"]
        XCTAssertTrue(search.waitForExistence(timeout: 5), "the exercise picker's search", file: file, line: line)
        for name in names {
            search.tap()
            search.typeText(name)
            let row = buttons[name].firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 5), "\(name) in the picker", file: file, line: line)
            row.tap()
            buttons["Clear"].firstMatch.tap()
        }
        buttons["templatePickerDone"].tap()
    }
}
