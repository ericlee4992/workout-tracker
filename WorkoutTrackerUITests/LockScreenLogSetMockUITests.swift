import XCTest

// MOCK (log a set from the Lock Screen): captures of today's ready card and options A and B, through the activity
// gallery. Removed once the user picks an option.
final class LockScreenLogSetMockUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func shoot(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testMockCaptures() {
        for (appearance, large) in [("light", false), ("dark", false), ("dark", true)] {
            for option in ["today", "A"] {
                for state in ["ready", "warmup"] {
                    app.launchArguments = ["-uiTestActivityGallery", state, "-appearance", appearance]
                        + (option == "today" ? [] : ["-protoLogSet", option])
                        + (large ? ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] : [])
                    app.launch()
                    XCTAssertTrue(app.descendants(matching: .any)["activityGallery"].waitForExistence(timeout: 15))
                    let card = app.descendants(matching: .any)["galleryLockScreen"].frame
                    XCTAssertLessThanOrEqual(card.height, 160, "\(option) \(state): the card is \(card.height) pt tall")
                    Thread.sleep(forTimeInterval: 0.6)
                    shoot("logset-\(option)-\(state)-\(appearance)\(large ? "-axl" : "")")
                    app.terminate()
                }
            }
        }
    }
}
