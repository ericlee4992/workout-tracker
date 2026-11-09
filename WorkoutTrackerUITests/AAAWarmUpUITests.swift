import XCTest

/// The warm-up in every UI test plan (testing-workflow ticket 01). A fresh test runner's first launch can spend up to
/// a minute setting up automation and then fail with `kAXErrorServerNotFound`, which used to land on whichever real
/// test ran first. This test only launches the app and waits for the tab bar. Its name sorts it first, so a serial
/// run starts with it; a parallel run hands it to one clone, and the other clones' first tests are not warmed.
/// It replaces the cardio test that served as the warm-up before (its start was intermittent, ticket 01).
/// A failure here can be the runner (`kAXErrorServerNotFound`, a slow automation set-up in the log) or a real launch
/// regression: read the failure and the app's log before rerunning it as infrastructure.
final class AAAWarmUpUITests: XCTestCase {
    func testLaunchReachesTheTabBar() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestReset"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Train"].waitForExistence(timeout: 60), "the tab bar after launch")
    }
}
