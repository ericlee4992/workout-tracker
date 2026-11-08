import XCTest

// Soft redesign S5 (D77): Today's Training part — the up-next template learned from the user's order (or their split),
// "Not today", a rest day, and someone without templates (last workout + Repeat, Start workout); Train → My split.
// The sample (DesignSampleFixture) did Push, Pull, Leg, Push, Pull, Leg (yesterday): learned next = Push Day; Next in
// order = Pull Day; My split "In order" (Leg, Pull, Push by name) = Pull Day.
final class TodayUpNextUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private static let sample = ["-uiTestReset", "-uiTestDesignSample", "-uiTestDesignHistory"]

    private func launch(_ arguments: [String] = TodayUpNextUITests.sample, appearance: String = "dark",
                        large: Bool = false) {
        app.launchArguments = arguments + ["-appearance", appearance]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] }
        app.launch()
        let today = app.tabBars.buttons["Today"]
        XCTAssertTrue(today.waitForExistence(timeout: 15))
        today.tap()
    }

    private func shoot(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private var upNextStart: XCUIElement { app.buttons["todayStartUpNext"] }

    private func notToday(_ item: String) {
        let menu = app.descendants(matching: .any)["todayNotToday"].firstMatch
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        menu.tap()
        let button = app.buttons[item].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5), item)
        button.tap()
    }

    private func waitForLabel(_ element: XCUIElement, _ label: String, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "label == %@", label)
        return XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: timeout)
            == .completed
    }

    // MARK: With templates

    func testLearnedTemplateAndNoStartButtonsOnToday() {
        launch()
        XCTAssertTrue(upNextStart.waitForExistence(timeout: 10))
        XCTAssertEqual(upNextStart.label, "Start Push Day", "after Leg comes Push in this user's order")
        XCTAssertFalse(app.buttons["startEmptyWorkout"].exists, "Start Lifting lives in Train only")
        XCTAssertFalse(app.buttons["startCardio"].exists, "Start Cardio lives in Train only")

        notToday("Next in order")
        XCTAssertTrue(waitForLabel(upNextStart, "Start Pull Day"))
        XCTAssertTrue(app.staticTexts["Chosen for today"].exists)
        notToday("Choose template…")
        let leg = app.buttons["Leg Day"].firstMatch
        XCTAssertTrue(leg.waitForExistence(timeout: 5))
        leg.tap()
        XCTAssertTrue(waitForLabel(upNextStart, "Start Leg Day"))

        // Train's leading card shows the same template.
        app.openTrain("Templates")
        XCTAssertTrue(app.buttons["startUpNext"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Leg Day"].exists)
        app.tabBars.buttons["Today"].tap()

        notToday("Back to plan")
        XCTAssertTrue(waitForLabel(upNextStart, "Start Push Day"))
        XCTAssertFalse(app.staticTexts["Chosen for today"].exists)

        upNextStart.tap()
        XCTAssertTrue(app.buttons["minimizeWorkout"].waitForExistence(timeout: 10), "Start opens the workout")
    }

    func testCaptureUpNextLightDefault() { captureUpNext("light", large: false) }
    func testCaptureUpNextDarkDefault() { captureUpNext("dark", large: false) }
    func testCaptureUpNextDarkAccessibility() { captureUpNext("dark", large: true) }

    private func captureUpNext(_ appearance: String, large: Bool) {
        launch(appearance: appearance, large: large)
        XCTAssertTrue(upNextStart.waitForExistence(timeout: 10))
        let suffix = "\(appearance)-\(large ? "axl" : "default")"
        Thread.sleep(forTimeInterval: 1.0)
        shoot("s5-today-upnext-\(suffix)")
        app.descendants(matching: .any)["todayNotToday"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Next in order"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.6)
        shoot("s5-today-nottoday-menu-\(suffix)")
    }

    // MARK: My split

    private func openMySplit() {
        app.openTrain("Templates")
        let row = app.buttons["mySplit"]
        for _ in 0..<8 where !(row.exists && row.isHittable) { app.swipeUp() }
        XCTAssertTrue(row.isHittable, "My Split… in Train → Templates")
        row.tap()
        XCTAssertTrue(app.buttons["mySplitSave"].waitForExistence(timeout: 5))
    }

    func testMySplitInOrderThenARestDay() {
        launch()
        openMySplit()
        app.buttons["In order"].tap()
        XCTAssertTrue(app.staticTexts.matching(identifier: "mySplitOrderRow").firstMatch.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.6)
        shoot("s5-mysplit-inorder-dark-default")
        app.buttons["mySplitSave"].tap()
        app.tabBars.buttons["Today"].tap()
        XCTAssertTrue(waitForLabel(upNextStart, "Start Pull Day"), "In order Leg → Pull → Push: after Leg comes Pull")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'My split'")).firstMatch.exists)

        // By weekday with only tomorrow assigned: today is a rest day.
        openMySplit()
        app.buttons["By weekday"].tap()
        let tomorrow = Calendar.current.component(.weekday, from: Date().addingTimeInterval(86_400))
        let day = app.descendants(matching: .any)["mySplitDay.\(tomorrow)"].firstMatch
        XCTAssertTrue(day.waitForExistence(timeout: 5))
        day.tap()
        let leg = app.buttons["Leg Day"].firstMatch
        XCTAssertTrue(leg.waitForExistence(timeout: 5))
        leg.tap()
        Thread.sleep(forTimeInterval: 0.6)
        shoot("s5-mysplit-weekday-dark-default")
        app.buttons["mySplitSave"].tap()
        app.tabBars.buttons["Today"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["todayRestDay"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(upNextStart.exists)
        Thread.sleep(forTimeInterval: 0.6)
        shoot("s5-today-restday-dark-default")
        // Train anyway: Next in order goes to the next assigned day's template.
        notToday("Next in order")
        XCTAssertTrue(waitForLabel(upNextStart, "Start Leg Day"))
    }

    func testCaptureMySplitLightAccessibility() {
        launch(appearance: "light", large: true)
        openMySplit()
        Thread.sleep(forTimeInterval: 0.6)
        shoot("s5-mysplit-off-light-axl")
        app.buttons["In order"].tap()
        Thread.sleep(forTimeInterval: 0.6)
        shoot("s5-mysplit-inorder-light-axl")
        app.buttons["By weekday"].tap()
        Thread.sleep(forTimeInterval: 0.6)
        shoot("s5-mysplit-weekday-light-axl")
    }

    // MARK: Without templates

    func testNoTemplatesShowsTheLastWorkoutAndRepeatStartsIt() {
        launch(Self.sample + ["-uiTestNoTemplates"], appearance: "light")
        let repeatButton = app.buttons["todayRepeat"]
        XCTAssertTrue(repeatButton.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Last workout"].exists)
        XCTAssertTrue(app.staticTexts["Leg Day"].exists, "yesterday's workout")
        XCTAssertTrue(app.buttons["todayStartWorkout"].exists)
        XCTAssertTrue(app.buttons["todayOpenTrain"].exists)
        XCTAssertFalse(upNextStart.exists)
        Thread.sleep(forTimeInterval: 0.8)
        shoot("s5-today-notemplates-light-default")

        repeatButton.tap()
        XCTAssertTrue(app.buttons["minimizeWorkout"].waitForExistence(timeout: 10), "Repeat opens a workout")
        XCTAssertTrue(app.staticTexts["Leg Press"].waitForExistence(timeout: 5), "with the last workout's exercises")
    }

    func testCaptureNoTemplatesDarkAccessibility() {
        launch(Self.sample + ["-uiTestNoTemplates"], appearance: "dark", large: true)
        XCTAssertTrue(app.buttons["todayRepeat"].waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 0.8)
        shoot("s5-today-notemplates-dark-axl")
    }

    func testAnEmptyStoreStartsAnEmptyWorkoutFromToday() {
        launch(["-uiTestReset"], appearance: "dark")
        let start = app.buttons["todayStartWorkout"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["todayRepeat"].exists, "nothing to repeat yet")
        Thread.sleep(forTimeInterval: 0.6)
        shoot("s5-today-empty-dark-default")
        start.tap()
        XCTAssertTrue(app.buttons["minimizeWorkout"].waitForExistence(timeout: 10))
    }
}
