import XCTest

// Public beta ticket 06 (app half, UI-first): AI through the server, signed in — Settings' Ask AI card and sheet
// (signed out, signed in with today's use, paused), Scan Machine's consent and sign-in steps and its over-limit and
// paused errors, Ask AI for Templates signed out and over its limit, and New Model's suggestion signed out — on the
// sample account and the Terra fixture, in light and dark at Default and AccessibilityL.
final class FloodlightAIAccessUITests: XCTestCase {
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

    private func any(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func launch(appearance: String, large: Bool, flags: [String]) {
        app.launchArguments = ["-uiTestReset", "-uiTestDesignSample", "-uiTestDesignGyms", "-uiTestTerra",
                               "-appearance", appearance] + flags
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] }
        app.launch()
    }

    private func onScreen(_ element: XCUIElement, floor: CGFloat? = nil) -> Bool {
        let limit = floor ?? (app.tabBars.firstMatch.exists ? app.tabBars.firstMatch.frame.minY - 8 : app.frame.maxY - 20)
        return element.exists && element.isHittable && element.frame.maxY < limit
    }

    /// Shoots the first page, then drags up and shoots until `last` is on screen above `floor`.
    private func pages(_ name: String, until last: XCUIElement, floor: CGFloat? = nil, limit: Int = 8) {
        shoot("\(name)-1")
        var page = 2
        while !onScreen(last, floor: floor ?? app.frame.maxY - 20), page <= limit + 1 {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)))
            Thread.sleep(forTimeInterval: 0.6)
            shoot("\(name)-\(page)")
            page += 1
        }
        XCTAssertTrue(last.exists && last.isHittable, "\(name): reached \(last)")
    }

    private func openSettings() {
        app.tabBars.buttons["Workout"].tap()
        let gear = app.buttons["openSettings"]
        XCTAssertTrue(gear.waitForExistence(timeout: 15))
        gear.tap()
        XCTAssertTrue(any("askAISettings").waitForExistence(timeout: 10))
    }

    private func openAskAISheet(_ name: String) {
        openSettings()
        let card = any("askAISettings")
        for _ in 0..<8 where !onScreen(card) { app.swipeUp() }
        Thread.sleep(forTimeInterval: 0.6)
        shoot("\(name)-settings")
        card.tap()
        XCTAssertTrue(app.buttons["askAIDone"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.0)
        pages("\(name)-sheet", until: app.links.firstMatch.exists ? app.links.firstMatch : any("askAIStatus"))
    }

    private func openScan() {
        app.tabBars.buttons["Gyms"].tap()
        let iron = any("gymRow.Iron Temple")
        XCTAssertTrue(iron.waitForExistence(timeout: 15))
        iron.tap()
        XCTAssertTrue(any("scanMachine").waitForExistence(timeout: 10))
        any("scanMachine").tap()
    }

    private func openRoutineEquipment() {
        app.tabBars.buttons["Workout"].tap()
        let ask = app.buttons["askAIRoutine"]
        XCTAssertTrue(ask.waitForExistence(timeout: 15))
        for _ in 0..<8 where !(ask.isHittable && ask.frame.maxY < app.tabBars.firstMatch.frame.minY - 8) { app.swipeUp() }
        ask.tap()
        XCTAssertTrue(any("routineGoals").waitForExistence(timeout: 10))
        let phrase = any("routineGoalPhrase.0")
        XCTAssertTrue(phrase.waitForExistence(timeout: 5))
        phrase.tap()
        any("routineNext").tap()
        XCTAssertTrue(any("routineMachineCount").waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8)
    }

    func testCaptureAIAccessLightDefault() { capture(appearance: "light", large: false) }
    func testCaptureAIAccessLightAccessibility() { capture(appearance: "light", large: true) }
    func testCaptureAIAccessDarkDefault() { capture(appearance: "dark", large: false) }
    func testCaptureAIAccessDarkAccessibility() { capture(appearance: "dark", large: true) }

    private func capture(appearance: String, large: Bool) {
        let suffix = "\(appearance)-\(large ? "axl" : "default")"

        // Settings → Ask AI: signed out, signed in, paused.
        launch(appearance: appearance, large: large, flags: ["-uiTestProfileSignedOut"])
        openAskAISheet("ai06-signedout-\(suffix)")
        XCTAssertTrue(app.buttons["askAISignIn"].exists)
        app.terminate()

        launch(appearance: appearance, large: large, flags: ["-uiTestProfileSample"])
        openAskAISheet("ai06-signedin-\(suffix)")
        XCTAssertTrue(any("askAIUse.scan-machine").exists)
        app.terminate()

        launch(appearance: appearance, large: large, flags: ["-uiTestProfileSample", "-uiTestAIPaused"])
        openAskAISheet("ai06-paused-\(suffix)")
        app.terminate()

        // Scan Machine: consent (signed in), then the sign-in step (signed out).
        launch(appearance: appearance, large: large, flags: ["-uiTestProfileSample", "-uiTestTerraNeedsConsent"])
        openScan()
        let allow = app.buttons["allowAIPhotos"]
        XCTAssertTrue(allow.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8)
        pages("ai06-scan-consent-\(suffix)", until: app.links.firstMatch, floor: allow.frame.minY - 8)
        app.terminate()

        launch(appearance: appearance, large: large, flags: ["-uiTestProfileSignedOut"])
        openScan()
        XCTAssertTrue(app.buttons["scannerSignIn"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8)
        shoot("ai06-scan-signin-\(suffix)")
        app.terminate()

        // Scan Machine's errors: over the limit, paused.
        for (flag, name) in [("-uiTestTerraLimit", "limit"), ("-uiTestTerraPaused", "paused")] {
            launch(appearance: appearance, large: large, flags: ["-uiTestProfileSample", flag])
            openScan()
            let shutter = app.buttons["scanShutter"]
            XCTAssertTrue(shutter.waitForExistence(timeout: 5))
            shutter.tap()
            XCTAssertTrue(app.buttons["scanManual"].waitForExistence(timeout: 10))
            Thread.sleep(forTimeInterval: 0.8)
            shoot("ai06-scan-\(name)-\(suffix)")
            app.terminate()
        }

        // Ask AI for Templates signed out: the Ask AI row and Sign In in the bar.
        launch(appearance: appearance, large: large, flags: ["-uiTestProfileSignedOut"])
        openRoutineEquipment()
        let signIn = app.buttons["routineSignIn"]
        XCTAssertTrue(signIn.exists)
        pages("ai06-routine-signedout-\(suffix)", until: any("routineAskAIRow"), floor: signIn.frame.minY - 60)
        app.terminate()

        // …and over its limit.
        launch(appearance: appearance, large: large, flags: ["-uiTestProfileSample", "-uiTestTerraRoutineLimit"])
        openRoutineEquipment()
        let dumbbells = any("routineEquipment.dumbbells")
        for _ in 0..<8 where !onScreen(dumbbells, floor: app.buttons["generateAIRoutine"].frame.minY - 12) { app.swipeUp() }
        dumbbells.tap()
        app.buttons["generateAIRoutine"].tap()
        XCTAssertTrue(any("routineRetry").waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 0.8)
        shoot("ai06-routine-limit-\(suffix)")
    }

    /// codex-review-06-app F1: a session the server refuses signs the phone out; the routine's error step then offers
    /// Sign In (not a Generate week that cannot work), and Scan Machine returns to its sign-in step.
    func testRefusedSessionOffersSignIn() {
        launch(appearance: "light", large: false, flags: ["-uiTestProfileSample", "-uiTestTerraExpired"])
        openRoutineEquipment()
        let dumbbells = any("routineEquipment.dumbbells")
        for _ in 0..<8 where !onScreen(dumbbells, floor: app.buttons["generateAIRoutine"].frame.minY - 12) { app.swipeUp() }
        dumbbells.tap()
        app.buttons["generateAIRoutine"].tap()
        let signIn = app.buttons["routineSignIn"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["routineRetry"].exists, "no Generate week while signed out")
        XCTAssertTrue(app.staticTexts["Sign in to use AI."].exists)
        shoot("ai06-routine-expired-light-default")
        signIn.tap()
        XCTAssertTrue(any("signInWithApple").waitForExistence(timeout: 5))
        app.buttons["signInClose"].tap()
        XCTAssertTrue(any("signInWithApple").waitForNonExistence(timeout: 5))
        // Back to preferences keeps the choices and still offers Sign In.
        app.buttons["routineErrorBack"].tap()
        XCTAssertTrue(app.buttons["routineSignIn"].waitForExistence(timeout: 5))
        XCTAssertTrue(any("routineEquipment.dumbbells").isSelected)
        app.terminate()

        launch(appearance: "light", large: false, flags: ["-uiTestProfileSample", "-uiTestTerraExpired"])
        openScan()
        let shutter = app.buttons["scanShutter"]
        XCTAssertTrue(shutter.waitForExistence(timeout: 5))
        shutter.tap()
        XCTAssertTrue(app.buttons["scannerSignIn"].waitForExistence(timeout: 10))
        shoot("ai06-scan-expired-light-default")
    }

    /// codex-review-06-app-c C2: refused once, then signed in again (the sample sign-in stands in for Apple's sheet):
    /// Scan Machine returns to a usable camera — no stale "Sign in to use AI." — and identifies; Ask AI for Templates
    /// offers Generate week again with the choices kept, and the week arrives.
    func testSigningInAfterARefusedSessionMakesAIUsable() {
        let flags = ["-uiTestProfileSample", "-uiTestTerraExpiredOnce", "-uiTestSampleSignIn"]
        launch(appearance: "light", large: false, flags: flags)
        openScan()
        let shutter = app.buttons["scanShutter"]
        XCTAssertTrue(shutter.waitForExistence(timeout: 5))
        shutter.tap()
        let signIn = app.buttons["scannerSignIn"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 10))
        signIn.tap()
        XCTAssertTrue(shutter.waitForExistence(timeout: 10), "the camera is back once signed in")
        XCTAssertFalse(any("scanAIError").exists, "no stale error")
        XCTAssertFalse(app.staticTexts["Sign in to use AI."].exists)
        shutter.tap()
        XCTAssertTrue(app.buttons["scanUseCandidate"].waitForExistence(timeout: 12), "the scan identifies")
        app.terminate()

        launch(appearance: "light", large: false, flags: flags)
        openRoutineEquipment()
        let dumbbells = any("routineEquipment.dumbbells")
        for _ in 0..<8 where !onScreen(dumbbells, floor: app.buttons["generateAIRoutine"].frame.minY - 12) { app.swipeUp() }
        dumbbells.tap()
        app.buttons["generateAIRoutine"].tap()
        let routineSignIn = app.buttons["routineSignIn"]
        XCTAssertTrue(routineSignIn.waitForExistence(timeout: 10))
        routineSignIn.tap()
        let retry = app.buttons["routineRetry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 10), "Generate week once signed in")
        retry.tap()
        XCTAssertTrue(any("routineDay.0").waitForExistence(timeout: 12), "the week arrives")
    }

    func testCaptureNewModelLightDefault() { captureNewModel(appearance: "light", large: false) }
    func testCaptureNewModelLightAccessibility() { captureNewModel(appearance: "light", large: true) }
    func testCaptureNewModelDarkDefault() { captureNewModel(appearance: "dark", large: false) }
    func testCaptureNewModelDarkAccessibility() { captureNewModel(appearance: "dark", large: true) }

    /// New Model from a read plate, signed out: the suggestion asks to sign in.
    private func captureNewModel(appearance: String, large: Bool) {
        let suffix = "\(appearance)-\(large ? "axl" : "default")"
        launch(appearance: appearance, large: large, flags: ["-uiTestProfileSignedOut", "-uiTestScanFixture"])
        app.tabBars.buttons["Gyms"].tap()
        let iron = any("gymRow.Iron Temple")
        XCTAssertTrue(iron.waitForExistence(timeout: 15))
        iron.tap()
        let addMachine = app.buttons["addMachine"]
        for _ in 0..<8 where !onScreen(addMachine) { app.swipeUp() }
        addMachine.tap()
        app.buttons["scanMachineLabel"].tap()
        let cancel = app.buttons["scanCancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        cancel.tap()
        app.buttons["scanLabelOffline"].tap()
        let shutter = app.buttons["scanShutter"]
        XCTAssertTrue(shutter.waitForExistence(timeout: 5))
        shutter.tap()
        let create = app.buttons["scanCreateNew"]
        XCTAssertTrue(create.waitForExistence(timeout: 15))
        let bar = app.buttons["scanUseCandidate"]
        for _ in 0..<8 where !(create.isHittable && (!bar.exists || create.frame.maxY < bar.frame.minY - 20)) { app.swipeUp() }
        create.tap()
        // A Form's rows exist once scrolled into view (the section starts below the fold at AX sizes).
        XCTAssertTrue(app.navigationBars["New Model"].waitForExistence(timeout: 5))
        let note = any("newModelSuggestSignIn")
        for _ in 0..<10 where !onScreen(note, floor: app.frame.maxY - 30) { app.swipeUp(); Thread.sleep(forTimeInterval: 0.4) }
        XCTAssertTrue(app.buttons["newModelSuggestExercises"].exists && note.exists)
        Thread.sleep(forTimeInterval: 0.6)
        shoot("ai06-newmodel-signedout-\(suffix)")
    }
}
