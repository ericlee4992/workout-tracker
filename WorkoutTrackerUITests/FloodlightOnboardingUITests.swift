import XCTest

/// Public beta ticket 02: the onboarding walkthrough on record — the prototype's three directions (A showcase,
/// B poster, C one page), every page, light and dark at Default, and AccessibilityL.
final class FloodlightOnboardingUITests: XCTestCase {
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

    private func launch(_ style: String, appearance: String, large: Bool = false) {
        app.launchArguments = ["-uiTestReset", "-onboardingPrototype", style, "-appearance", appearance]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] }
        app.launch()
        let first = app.buttons.matching(NSPredicate(format: "identifier IN %@",
                                                     ["onboardingContinue", "onboardingGetStarted"])).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 15), "the walkthrough is on screen")
    }

    /// Shoots each page of a paged direction, tapping Continue between them; ends on Get started.
    private func walk(_ style: String, appearance: String, large: Bool = false) {
        launch(style, appearance: appearance, large: large)
        let size = large ? "AXL" : "default"
        for page in 1...5 {
            Thread.sleep(forTimeInterval: 0.8)
            shoot("onboarding-\(style)-p\(page)-\(appearance)-\(size)")
            if page < 5 {
                let next = app.buttons["onboardingContinue"]
                XCTAssertTrue(next.waitForExistence(timeout: 5), "Continue on page \(page)")
                next.tap()
            }
        }
        XCTAssertTrue(app.buttons["onboardingGetStarted"].exists, "the last page offers Get started")
        XCTAssertFalse(app.buttons["onboardingSkip"].exists, "no Skip on the last page")
    }

    func testDirectionA() {
        for appearance in ["dark", "light"] { walk("A", appearance: appearance) }
        walk("A", appearance: "dark", large: true)
    }

    func testDirectionB() {
        for appearance in ["dark", "light"] { walk("B", appearance: appearance) }
        walk("B", appearance: "dark", large: true)
    }

    func testDirectionC() {
        for appearance in ["dark", "light"] {
            launch("C", appearance: appearance)
            Thread.sleep(forTimeInterval: 0.8)
            shoot("onboarding-C-p1-\(appearance)-default")
            XCTAssertTrue(app.buttons["onboardingGetStarted"].exists)
        }
        launch("C", appearance: "dark", large: true)
        Thread.sleep(forTimeInterval: 0.8)
        shoot("onboarding-C-p1-dark-AXL")
        app.swipeUp()
        Thread.sleep(forTimeInterval: 0.8)
        shoot("onboarding-C-p2-dark-AXL")
    }
}
