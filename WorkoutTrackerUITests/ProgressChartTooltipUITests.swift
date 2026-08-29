import XCTest

/// The progress chart with a REAL series, which no test could reach before:
/// the simulator has no past, so workouts logged in a test all land on one day
/// and collapse into the single-point state. `-uiTestChartHistory` seeds a few
/// weeks of history so the drawn chart — and its tooltip — can be exercised.
final class ProgressChartTooltipUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestReset", "-uiTestChartHistory"]
        app.launch()
    }

    func testTappingTheChartShowsTheValueAsEntered() {
        openProgress(for: "Seated Chest Press")

        let chart = app.descendants(matching: .any)
            .matching(identifier: "progressChart").firstMatch
        XCTAssertTrue(
            chart.waitForExistence(timeout: 15),
            "a multi-day series should draw a chart rather than a single point")

        let before = XCTAttachment(screenshot: app.screenshot())
        before.name = "chart-series"
        before.lifetime = .keepAlways
        add(before)

        // Press and drag across the chart. `chartXSelection` tracks a drag;
        // a single synthetic tap did not register.
        let from = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.5))
        let to = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.5))
        from.press(forDuration: 0.4, thenDragTo: to)

        let row = app.descendants(matching: .any)
            .matching(identifier: "chartSelection").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "the selection row should exist")
        // The row falls back to the most recent session when nothing is
        // selected, so asserting it merely EXISTS would pass even if the
        // gesture did nothing. The drag landed mid-series, so the newest
        // session is exactly what must NOT be showing.
        XCTAssertFalse(
            row.label.contains(newestSessionDay),
            "the row still shows the newest session, so the drag selected nothing")

        let after = XCTAttachment(screenshot: app.screenshot())
        after.name = "chart-tooltip"
        after.lifetime = .keepAlways
        add(after)

        // D25: the chart plots converted values, so this row is the only place
        // the number the user actually typed appears. The fixture logs lb.
        XCTAssertTrue(
            row.label.contains("lb"),
            "the row should show the as-entered value, got '\(row.label)'")
    }

    /// The fixture's most recent session is yesterday.
    private var newestSessionDay: String {
        let yesterday = Date().addingTimeInterval(-86_400)
        return yesterday.formatted(.dateTime.month(.abbreviated).day())
    }

    private func openProgress(for exercise: String) {
        app.tabBars.buttons["Exercises"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText(exercise)

        let row = app.staticTexts[exercise].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.press(forDuration: 1.0)

        let progress = app.buttons["Progress…"].firstMatch
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        progress.tap()
    }
}
