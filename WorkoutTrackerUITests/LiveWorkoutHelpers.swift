import XCTest

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
}
