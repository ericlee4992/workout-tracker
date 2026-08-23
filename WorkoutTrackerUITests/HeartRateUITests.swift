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

    private func readingText(_ element: XCUIElement) -> String {
        element.label.isEmpty ? (element.value as? String ?? "") : element.label
    }
}
