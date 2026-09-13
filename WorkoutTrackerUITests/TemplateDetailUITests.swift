import XCTest

/// Ticket 15 — deleting a template from its opened detail deletes THAT
/// template and no other. The tile's long-press menu, which on the phone
/// deleted the wrong one, is gone: a long press offers nothing.
final class TemplateDetailUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestReset", "-uiTestTemplate"]   // seeds "Whole Body"
        app.launch()
    }

    private func anyElement(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func testDeletingFromTheDetailRemovesOnlyThatTemplate() {
        app.tabBars.buttons["Workout"].tap()
        XCTAssertTrue(anyElement("templateTile.Whole Body").waitForExistence(timeout: 10))
        // A second template, so there is an "other" one to keep.
        app.buttons["New Template…"].tap()
        let field = app.textFields["Template name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Second\n")
        app.buttons["Abdominal Crunch"].firstMatch.tap()
        app.buttons["Save"].tap()
        let second = anyElement("templateTile.Second")
        XCTAssertTrue(second.waitForExistence(timeout: 5))

        // A long press on a tile offers no menu any more — it is a tap, and
        // opens the template like one.
        second.press(forDuration: 1.2)
        XCTAssertFalse(app.buttons["Delete"].waitForExistence(timeout: 2), "no long-press Delete")
        XCTAssertFalse(app.buttons["Edit…"].exists, "no long-press Edit")
        if !app.buttons["deleteTemplate"].exists { second.tap() }
        let delete = app.buttons["deleteTemplate"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()
        XCTAssertTrue(app.alerts["Delete Template"].waitForExistence(timeout: 5))
        app.alerts["Delete Template"].buttons["Delete"].tap()

        // Back on Start: Second is gone, Whole Body — the other one — stays.
        XCTAssertTrue(anyElement("startEmptyWorkout").waitForExistence(timeout: 5), "the detail popped")
        XCTAssertTrue(anyElement("templateTile.Whole Body").waitForExistence(timeout: 5), "the other template survives")
        XCTAssertFalse(anyElement("templateTile.Second").exists, "the deleted template is gone")
    }

    func testCancellingTheDeleteKeepsTheTemplate() {
        app.tabBars.buttons["Workout"].tap()
        let tile = anyElement("templateTile.Whole Body")
        XCTAssertTrue(tile.waitForExistence(timeout: 10))
        tile.tap()
        let delete = app.buttons["deleteTemplate"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()
        XCTAssertTrue(app.alerts["Delete Template"].waitForExistence(timeout: 5))
        app.alerts["Delete Template"].buttons["Cancel"].tap()
        XCTAssertTrue(anyElement("startTemplate").exists, "still on the detail")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(anyElement("templateTile.Whole Body").waitForExistence(timeout: 5))
    }
}
