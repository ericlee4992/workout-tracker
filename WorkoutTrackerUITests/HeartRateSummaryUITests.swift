import XCTest

/// Milestone 9, ticket 05 — the heart-rate graph on the finish sheet and in
/// History, and its ABSENCE for a workout that has no series.
final class HeartRateSummaryUITests: XCTestCase {

    /// Under the scripted sensor: finish → the receipt has the chart and the
    /// total-calories tile → View in History → the detail has the chart too.
    func testFinishShowsTheChartAndHistoryShowsItAgain() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestReset", "-uiTestHeartRate"]
        app.launch()

        app.tabBars.buttons["Workout"].tap()
        app.buttons["startEmptyWorkout"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "hrBpm").firstMatch
            .waitForExistence(timeout: 15))

        app.buttons["addExercise"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Seated Chest")
        let option = app.descendants(matching: .any)
            .matching(identifier: "exerciseOption.Seated Chest Press").firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 10))
        option.tap()
        let weight = app.textFields["setRow.weight"].firstMatch
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        weight.tap(); weight.typeText("60")
        let reps = app.textFields["setRow.reps"].firstMatch
        reps.tap(); reps.typeText("10")
        app.buttons["setRow.complete"].firstMatch.tap()
        // Let the fixture run long enough for more than one 15 s bucket.
        sleep(20)
        app.buttons["finishWorkout"].tap()

        XCTAssertTrue(app.buttons["finishedDone"].waitForExistence(timeout: 15), "the receipt opens")
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "summaryTotalCalories").firstMatch.waitForExistence(timeout: 5),
                      "the fixture supplies basal energy, so Total calories shows")
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "summaryAvgHR").firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "summaryMaxHR").firstMatch.exists,
                      "the fixture's series has a maximum")
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "summaryVolume").firstMatch.exists,
                      "60 × 10 is a volume")
        // The chart sits under the tiles (D54 ticket 03); a lazy List only
        // materialises it once scrolled into view. Scroll until the caption
        // UNDER the chart is on screen, so the screenshot holds the whole chart.
        let chart = app.descendants(matching: .any).matching(identifier: "heartRateChart").firstMatch
        let caption = app.descendants(matching: .any).matching(identifier: "heartRateAverageCaption").firstMatch
        for _ in 0..<6 where !(chart.exists && caption.exists && caption.isHittable) { app.swipeUp() }
        XCTAssertTrue(chart.waitForExistence(timeout: 5), "the receipt should draw the heart-rate series")
        XCTAssertTrue(caption.isHittable, "the whole chart, caption included, is in view")

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "finish-heart-rate"
        shot.lifetime = .keepAlways
        add(shot)

        // Back up to the actions: the chart scroll left them above the fold.
        let viewInHistory = app.buttons["viewFinishedWorkout"].firstMatch
        for _ in 0..<6 where !(viewInHistory.exists && viewInHistory.isHittable) { app.swipeDown() }
        XCTAssertTrue(viewInHistory.isHittable, "View in History is reachable after the chart scroll")
        viewInHistory.tap()
        let section = app.descendants(matching: .any).matching(identifier: "historyHeartRateSection").firstMatch
        XCTAssertTrue(section.waitForExistence(timeout: 15), "History detail should show the heart-rate section")
        app.swipeUp()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "heartRateChart").firstMatch
            .waitForExistence(timeout: 10), "and the same chart")

        let after = XCTAttachment(screenshot: app.screenshot())
        after.name = "history-heart-rate"
        after.lifetime = .keepAlways
        add(after)
    }

    /// Finish-graph ticket 01: the chart at REAL density. The scripted sensor
    /// gives two buckets in a 20 s test; the seeded hour-long workout is the
    /// screenshot to hold against the Apple Fitness reference.
    func testAnHourLongWorkoutDrawsTheAppleShapedChartInHistory() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestReset", "-uiTestHeartRateHistory"]
        app.launch()
        app.tabBars.buttons["History"].tap()
        let row = app.descendants(matching: .any).matching(identifier: "historyWorkoutRow").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        let section = app.descendants(matching: .any).matching(identifier: "historyHeartRateSection").firstMatch
        XCTAssertTrue(section.waitForExistence(timeout: 15))
        app.swipeUp()
        let chart = app.descendants(matching: .any).matching(identifier: "heartRateChart").firstMatch
        XCTAssertTrue(chart.waitForExistence(timeout: 10), "the seeded series must draw")
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "heartRateAverageCaption").firstMatch.exists,
                      "the average sits under the plot, as the reference draws it")
        // Ticket 14: time in zones under the graph, from the workout's own zoneSeconds.
        app.swipeUp()
        let zones = app.descendants(matching: .any).matching(identifier: "historyZoneCard").firstMatch
        XCTAssertTrue(zones.waitForExistence(timeout: 5), "time in zones sits under the graph")
        XCTAssertTrue(app.staticTexts["Time in zones"].exists)
        XCTAssertTrue(app.staticTexts["Zone 2"].exists, "the seeded hour spends time in zone 2")

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "history-heart-rate-hour"
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// A workout with no sensor data — every session in the chart fixture —
    /// shows neither the section nor an empty chart.
    func testAWorkoutWithoutASeriesShowsNoChart() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestReset", "-uiTestChartHistory"]
        app.launch()
        app.tabBars.buttons["History"].tap()
        let row = app.descendants(matching: .any).matching(identifier: "historyWorkoutRow").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        XCTAssertTrue(app.buttons["historyWorkoutName"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "historyHeartRateSection").firstMatch.exists)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "heartRateChart").firstMatch.exists)
    }
}
