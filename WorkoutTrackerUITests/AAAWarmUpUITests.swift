import XCTest

/// The warm-up every UI test plan starts with (testing-workflow ticket 01). A fresh test runner's first launch can
/// spend up to a minute setting up automation and then fail with `kAXErrorServerNotFound`, which used to land on
/// whichever real test ran first. This test only launches the app and waits for the tab bar, so that cost (and any
/// such failure) is absorbed here, and it does nothing that can itself be flaky. The name sorts it first: XCTest
/// runs classes in name order. It replaces the cardio test that served as the warm-up before (its start was
/// intermittent). A failure here alone says the runner was not ready, not that the app is broken; rerun.
final class AAAWarmUpUITests: XCTestCase {
    func testLaunchReachesTheTabBar() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestReset"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Train"].waitForExistence(timeout: 60), "the tab bar after launch")
    }
}
