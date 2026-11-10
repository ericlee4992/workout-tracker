import XCTest

/// Nutrition N4: Log Food against the stored foods — one tap logs (the food moves to the top of Recently logged) and
/// Undo takes it back; Add food makes one of My foods and the bookmark puts it in Saved foods; Manual Add logs calories
/// alone; a meal is created, logged and deleted.
final class LogFoodFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func open(foods: Bool) {
        app.launchArguments = ["-uiTestReset", "-uiTestDesignSample", "-appearance", "light"]
            + (foods ? ["-uiTestFoodSample"] : [])
        app.launch()
        let pill = app.buttons["logFoodPill"]
        XCTAssertTrue(pill.waitForExistence(timeout: 15))
        pill.tap()
        XCTAssertTrue(app.buttons["logFoodMeal.lunch"].waitForExistence(timeout: 5))
        app.buttons["logFoodMeal.lunch"].tap()
    }

    private func type(_ text: String, into identifier: String) {
        let field = app.textFields[identifier]
        XCTAssertTrue(field.waitForExistence(timeout: 5), identifier)
        field.tap()
        field.typeText(text)
    }

    private func row(_ name: String) -> XCUIElement { app.buttons["logFoodRow.\(name)"] }

    private func isAbove(_ upper: String, _ lower: String) -> Bool { row(upper).frame.minY < row(lower).frame.minY }

    func testOneTapLogsAndUndoTakesItBack() {
        open(foods: true)
        XCTAssertTrue(row("Banana").waitForExistence(timeout: 5))
        XCTAssertTrue(isAbove("Greek yogurt", "Banana"))
        app.buttons["logFoodAdd.Banana"].tap()
        let toast = app.staticTexts["logFoodToast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 5))
        XCTAssertEqual(toast.label, "Logged Banana to Lunch")
        XCTAssertTrue(isAbove("Banana", "Greek yogurt"), "the logged food leads Recently logged")
        app.buttons["logFoodUndo"].tap()
        XCTAssertTrue(toast.waitForNonExistence(timeout: 5))
        XCTAssertTrue(isAbove("Greek yogurt", "Banana"), "Undo puts it back where it was")
    }

    func testASecondLogKeepsItsOwnUndo() {
        // codex-review-n4: the first log's toast timer cleared the second log's Undo.
        open(foods: true)
        XCTAssertTrue(row("Chicken breast").waitForExistence(timeout: 5))
        app.buttons["logFoodAdd.Banana"].tap()
        app.buttons["logFoodAdd.Chicken breast"].tap()
        let toast = app.staticTexts["logFoodToast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 5))
        XCTAssertEqual(toast.label, "Logged Chicken breast to Lunch")
        Thread.sleep(forTimeInterval: 2)  // past the moment the first log's timer was cancelled
        XCTAssertTrue(app.buttons["logFoodUndo"].exists, "the second log still offers Undo")
        app.buttons["logFoodUndo"].tap()
        XCTAssertTrue(toast.waitForNonExistence(timeout: 5))
        XCTAssertTrue(isAbove("Banana", "Greek yogurt"), "the first log stays")
        XCTAssertTrue(isAbove("Greek yogurt", "Chicken breast"), "only the second is undone")
        // After the toast expires, logging again shows a fresh Undo.
        app.buttons["logFoodAdd.Overnight oats"].tap()
        XCTAssertTrue(toast.waitForExistence(timeout: 5))
        XCTAssertTrue(toast.waitForNonExistence(timeout: 10), "the toast leaves on its own")
        app.buttons["logFoodAdd.Greek yogurt"].tap()
        XCTAssertTrue(app.buttons["logFoodUndo"].waitForExistence(timeout: 5))
    }

    func testSelectedFoodLogsTheServingsChosen() {
        open(foods: true)
        XCTAssertTrue(row("Greek yogurt").waitForExistence(timeout: 5))
        row("Greek yogurt").tap()
        XCTAssertTrue(app.buttons["selectedFoodLog"].waitForExistence(timeout: 5))
        app.buttons["More servings"].tap()
        XCTAssertEqual(app.staticTexts["selectedFoodServings"].label, "1.5")
        XCTAssertTrue(app.staticTexts["150"].exists, "the calories follow the servings")
        app.buttons["selectedFoodLog"].tap()
        XCTAssertTrue(app.staticTexts["logFoodToast"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["logFoodToast"].label, "Logged Greek yogurt to Lunch")
    }

    func testAddFoodMakesOneOfMyFoodsAndTheBookmarkSavesIt() {
        open(foods: false)
        app.buttons["logFoodTab.My foods"].tap()
        let empty = app.buttons["Add food"]
        XCTAssertTrue(empty.waitForExistence(timeout: 5))
        empty.tap()
        let next = app.buttons["addFoodNext"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        XCTAssertFalse(next.isEnabled, "a description and a serving first")
        type("Overnight oats", into: "addFoodName")
        type("1 jar", into: "addFoodServing")
        XCTAssertTrue(next.isEnabled)
        next.tap()
        let save = app.buttons["addFoodSave"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertFalse(save.isEnabled, "calories first")
        type("380", into: "addFoodCalories")
        type("22", into: "addFoodProtein")
        save.tap()

        XCTAssertTrue(row("Overnight oats").waitForExistence(timeout: 5), "in My foods")
        row("Overnight oats").tap()
        XCTAssertTrue(app.buttons["selectedFoodEdit"].waitForExistence(timeout: 5), "one of My foods can be edited")
        app.buttons["selectedFoodSave"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["logFoodTab.Saved foods"].tap()
        XCTAssertTrue(row("Overnight oats").waitForExistence(timeout: 5), "bookmarked into Saved foods")

        // Delete Food… (the user, 2026-11-10): gone from Saved foods and My foods.
        row("Overnight oats").tap()
        XCTAssertTrue(app.buttons["selectedFoodMore"].waitForExistence(timeout: 5))
        app.buttons["selectedFoodMore"].tap()
        app.buttons["deleteFood"].tap()
        let alert = app.alerts["Delete Food"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["Delete"].tap()
        XCTAssertTrue(app.staticTexts["No saved foods"].waitForExistence(timeout: 5))
        app.buttons["logFoodTab.My foods"].tap()
        XCTAssertTrue(app.staticTexts["No foods yet"].waitForExistence(timeout: 5))
    }

    func testManualAddLogsCaloriesAloneAndAMealIsCreatedLoggedAndDeleted() {
        open(foods: true)
        app.buttons["logFoodManualAdd"].tap()
        let log = app.buttons["manualAddLog"]
        XCTAssertTrue(log.waitForExistence(timeout: 5))
        XCTAssertFalse(log.isEnabled)
        type("250", into: "manualAddCalories")
        log.tap()
        XCTAssertTrue(app.staticTexts["logFoodToast"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["logFoodToast"].label, "Logged 250 cal to Lunch")

        app.buttons["logFoodTab.My meals"].tap()
        app.buttons["logFoodCreateMeal"].tap()
        let save = app.buttons["createMealSave"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        type("Snack box", into: "createMealName")
        XCTAssertFalse(save.isEnabled, "a food first")
        app.buttons["createMealUsual.lunch"].tap()
        app.buttons["createMealAdd.Banana"].firstMatch.tap()
        app.buttons["createMealAdd.Banana"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["2 servings"].exists, "a second + is a second serving")
        save.tap()

        let meal = row("meal.Snack box")
        XCTAssertTrue(meal.waitForExistence(timeout: 5))
        XCTAssertTrue(isAbove("meal.Snack box", "meal.Usual breakfast"), "a lunch meal leads while Lunch is chosen")
        app.buttons["logFoodAdd.meal.Snack box"].tap()
        XCTAssertTrue(app.staticTexts["logFoodToast"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["logFoodToast"].label, "Logged Snack box to Lunch")

        meal.tap()
        app.buttons["selectedMealMore"].tap()
        app.buttons["deleteMeal"].tap()
        let alert = app.alerts["Delete Meal"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["Delete"].tap()
        XCTAssertTrue(row("meal.Usual breakfast").waitForExistence(timeout: 5))
        XCTAssertFalse(meal.exists, "the meal is gone")
    }
}
