import XCTest

/// Throwaway capture driver; these are design fixtures, not feature acceptance tests.
final class CardioPrototypeCaptureUITests: XCTestCase {
    func testCaptureDefault() { capture(accessibility: false) }
    func testCaptureAccessibility() { capture(accessibility: true) }

    private func capture(accessibility: Bool) {
        continueAfterFailure = false
        let cases = [("mixed", "A"), ("mixed", "B"), ("mixed", "C"),
                     ("start", "A"), ("picker", "A"), ("gym", "A"),
                     ("outdoor", "A"), ("summary", "A")]
        for (screen, variant) in cases {
            let app = XCUIApplication()
            app.launchArguments = ["-uiTestReset"]
            if accessibility {
                app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"]
            }
            app.launchEnvironment = ["CARDIO_SCREEN": screen, "CARDIO_VARIANT": variant, "CARDIO_CAPTURE": "1"]
            app.launch()
            XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "cardioPrototype.\(screen).\(variant)").firstMatch.waitForExistence(timeout: 10))
            let prefix = "cardio-\(screen)-\(variant)-\(accessibility ? "axl" : "default")"
            take(app, prefix)
            if accessibility || screen == "picker" || screen == "summary" || screen == "mixed" {
                app.swipeUp()
                take(app, prefix + "-scroll1")
                if accessibility {
                    app.swipeUp()
                    take(app, prefix + "-scroll2")
                }
            }
            app.terminate()
        }
    }

    private func take(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
