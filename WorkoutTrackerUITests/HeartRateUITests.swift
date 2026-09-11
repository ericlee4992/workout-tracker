import XCTest

/// Milestone 7, ticket 05 — heart rate on the workout screen, driven end to end
/// by the scripted fixture (`-uiTestHeartRate`).
///
/// The simulator has no heartbeat, no AirPods and no Watch, which is exactly
/// why the source is injectable: without the fixture this screen could only
/// ever be checked by hand, in a gym, one build at a time.
final class HeartRateUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestReset", "-uiTestHeartRate"]
        app.launch()
    }

    func testLiveHeartRateAppearsAndUpdatesDuringAWorkout() {
        app.tabBars.buttons["Workout"].tap()
        let start = app.buttons["startEmptyWorkout"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()

        // The bar is asserted through its contents: an identifier on the
        // container would propagate to every child and clobber theirs.
        let bpm = app.descendants(matching: .any).matching(identifier: "hrBpm").firstMatch
        XCTAssertTrue(bpm.waitForExistence(timeout: 15), "live heart rate should appear")

        // A live feed changes. A single reading proves the label exists; two
        // different readings prove something is actually feeding it.
        let first = readingText(bpm)
        XCTAssertFalse(first.isEmpty)
        var changed = false
        let deadline = Date().addingTimeInterval(20)
        while Date() < deadline {
            if readingText(bpm) != first { changed = true; break }
            _ = app.wait(for: .runningForeground, timeout: 0.5)
        }
        XCTAssertTrue(changed, "the bpm should update as samples arrive, got \(first) throughout")

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "heart-rate-bar"
        shot.lifetime = .keepAlways
        add(shot)

        // The source is always named: an unattributed number invites trust the
        // user cannot check. The fixture says so rather than impersonating a
        // real sensor.
        let source = app.staticTexts["hrSource"].firstMatch
        XCTAssertTrue(source.waitForExistence(timeout: 5))
        XCTAssertEqual(source.label, "Test data")

        // Tidy up so the run leaves nothing behind.
        app.buttons["Cancel"].firstMatch.tap()
        app.buttons["Discard Workout"].firstMatch.tap()
    }

    /// D45: with no measured maximum and no date of birth, no zone is shown at
    /// all — the app does not invent a basis in order to show a badge.
    func testNoZoneIsShownWithoutABasisForOne() {
        app.tabBars.buttons["Workout"].tap()
        app.buttons["startEmptyWorkout"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "hrBpm").firstMatch
                .waitForExistence(timeout: 15))
        XCTAssertFalse(
            app.descendants(matching: .any).matching(identifier: "hrZone").firstMatch.exists,
            "a zone with no maximum behind it would be a fabricated number")

        app.buttons["Cancel"].firstMatch.tap()
        app.buttons["Discard Workout"].firstMatch.tap()
    }

    /// D44: finishing shows what you lifted AND what your heart did, on one
    /// screen — the half Apple's summary cannot show beside the half this app
    /// could not.
    func testFinishingShowsASummaryOfExercisesAndHeartRate() {
        app.tabBars.buttons["Workout"].tap()
        app.buttons["startEmptyWorkout"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "hrBpm").firstMatch
                .waitForExistence(timeout: 15))

        // Log one set so the workout is not discarded as empty (A2).
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
        weight.tap()
        weight.typeText("60")
        let reps = app.textFields["setRow.reps"].firstMatch
        reps.tap()
        reps.typeText("10")
        app.buttons["setRow.complete"].firstMatch.tap()

        app.buttons["finishWorkout"].tap()

        // The exercise performed, with its set count and best set.
        // The heart-rate rows are above the fold; the Exercises section is
        // below it, and a SwiftUI List is lazy — its off-screen rows do not
        // exist to query until they are scrolled into view.
        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "summaryAvgHR").firstMatch
                .waitForExistence(timeout: 10),
            "a workout with a sensor should report an average heart rate")

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "workout-summary"
        shot.lifetime = .keepAlways
        add(shot)

        app.swipeUp()
        let exerciseLine = app.descendants(matching: .any)
            .matching(identifier: "summaryExercise").firstMatch
        XCTAssertTrue(
            exerciseLine.waitForExistence(timeout: 10),
            "the summary should list the exercises completed")

        app.buttons["finishedDone"].tap()
    }

    /// The bug the user hit in a real gym: heart rate worked, no zone ever
    /// appeared, and there was no way to make one appear.
    ///
    /// `MaxHeartRateSheet` sets the maximum that zones need, and its ONLY entry
    /// point was the "zone estimated" button — which renders only once a zone
    /// exists. No maximum meant no zone meant no button meant no maximum. This
    /// asserts the loop is open at both ends: the prompt is reachable from a
    /// workout with no basis set, and using it makes a zone appear *in the
    /// workout already running*, without leaving and re-entering the screen.
    func testZonesCanBeSetUpFromTheWorkoutScreenAndApplyImmediately() {
        app.tabBars.buttons["Workout"].tap()
        app.buttons["startEmptyWorkout"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "hrBpm").firstMatch
                .waitForExistence(timeout: 15))

        let setUp = app.buttons["hrZoneSetup"].firstMatch
        XCTAssertTrue(
            setUp.waitForExistence(timeout: 5),
            "with no maximum set there must be a way to set one")
        setUp.tap()

        // The measured path: a real maximum, so the resulting zone is NOT
        // marked estimated. The fixture peaks at 153, so 180 puts the series
        // across several zones rather than pinning it at the top.
        let field = app.textFields["maxHeartRateField"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("180")
        XCTAssertTrue(
            app.staticTexts["Zones would use"].firstMatch.waitForExistence(timeout: 5),
            "the sheet should preview the zones it would produce")
        app.buttons["saveMaxHeartRate"].tap()

        // The heart of the regression: the monitor's maximum used to be read
        // only in `.task`, so this stayed absent for the rest of the workout.
        let zone = app.descendants(matching: .any).matching(identifier: "hrZone").firstMatch
        XCTAssertTrue(
            zone.waitForExistence(timeout: 15),
            "a zone should appear in the running workout as soon as a maximum exists")

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "heart-rate-zone"
        shot.lifetime = .keepAlways
        add(shot)

        app.buttons["Cancel"].firstMatch.tap()
        app.buttons["Discard Workout"].firstMatch.tap()
    }

    /// A date of birth is not a thing to enter mid-set, so the same screen is
    /// reachable from Settings — and independently of whether a zone exists.
    func testZonesAreReachableFromSettings() {
        app.tabBars.buttons["Workout"].tap()
        app.buttons["openSettings"].tap()
        let row = app.buttons["heartRateZonesSettings"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        XCTAssertTrue(
            app.textFields["maxHeartRateField"].firstMatch.waitForExistence(timeout: 5),
            "the Settings row must actually present the sheet — a `.sheet` on a "
                + "Section inside a List silently never does")
        app.buttons["Cancel"].firstMatch.tap()
    }

    private func readingText(_ element: XCUIElement) -> String {
        element.label.isEmpty ? (element.value as? String ?? "") : element.label
    }
}
