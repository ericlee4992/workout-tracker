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

    /// D36's rule is that two variations of one movement never share a line.
    /// The PICKER is the only place that rule is visible, and it renders only
    /// when history exists under more than one variation — so before the
    /// fixture seeded grips, nothing could reach this at all. The identifier
    /// `chartVariationPicker` shipped with no test naming it, which is the
    /// absence-of-a-caller shape this repo keeps hitting.
    func testEachVariationChartsOnItsOwn() {
        openProgress(for: "Seated Chest Press")

        let picker = app.descendants(matching: .any)
            .matching(identifier: "chartVariationPicker").firstMatch
        XCTAssertTrue(
            picker.waitForExistence(timeout: 15),
            "history under three variations should offer a picker")

        let row = app.descendants(matching: .any)
            .matching(identifier: "chartSelection").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))

        // The chart opens on the variation with the most days -- the plain
        // exercise -- whose newest session is yesterday at 120 lb.
        XCTAssertTrue(
            row.label.contains("120"),
            "should open on the plain exercise's newest session, got '\(row.label)'")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "chart-variation-picker"
        attachment.lifetime = .keepAlways
        add(attachment)

        picker.tap()
        let narrow = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Narrow grip")).firstMatch
        XCTAssertTrue(narrow.waitForExistence(timeout: 5), "the menu should list the grips")
        narrow.tap()

        // THE POINT OF THIS TEST. Narrow grip's newest session is 12 days ago
        // at 95 lb; the plain exercise's is yesterday at 120 lb. Pooled -- the
        // exact defect 3ad382d fixed -- the row would still read 120, because
        // the series would still end on the plain exercise's last point.
        let scoped = app.descendants(matching: .any)
            .matching(identifier: "chartSelection").firstMatch
        XCTAssertTrue(scoped.waitForExistence(timeout: 10))
        XCTAssertTrue(
            scoped.label.contains("95"),
            "the chart should now show only narrow-grip history, got '\(scoped.label)'")
        XCTAssertFalse(
            scoped.label.contains("120"),
            "the plain exercise's history is pooled into the grip's line, which D36 forbids")

        let after = XCTAttachment(screenshot: app.screenshot())
        after.name = "chart-narrow-grip"
        after.lifetime = .keepAlways
        add(after)
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
