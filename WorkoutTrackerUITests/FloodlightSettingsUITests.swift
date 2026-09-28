import XCTest

// Floodlight redesign ticket 09: Settings (X01: units, appearance, workout, heart-rate zones, Ask AI,
// export, the history note; metric chosen), Ask AI (X02: with a key, typing a new one, the remove
// confirmation, without a key) and Export (X03: idle, sharing, the file card, a failed write) — on
// record in light and dark at Default and AccessibilityL, on the design sample with its History and
// Settings extras; then the flows the new screens carry.
final class FloodlightSettingsUITests: XCTestCase {
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

    private func launch(appearance: String = "light", large: Bool = false, extra: [String] = [],
                        settingsFixture: Bool = true) {
        app.launchArguments = ["-uiTestReset", "-uiTestDesignSample", "-uiTestDesignHistory", "-appearance", appearance]
            + (settingsFixture ? ["-uiTestDesignSettings"] : []) + extra
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] }
        app.launch()
        app.tabBars.buttons["Workout"].tap()
        let gear = app.buttons["openSettings"]
        XCTAssertTrue(gear.waitForExistence(timeout: 15))
        gear.tap()
        XCTAssertTrue(any("appUnitPreference").waitForExistence(timeout: 10))
    }

    /// Scrolls until `element` is on screen and clear of the tab bar and the navigation bar.
    private func reach(_ element: XCUIElement, limit: Int = 12) {
        for _ in 0..<limit where !visible(element) { app.swipeUp() }
        XCTAssertTrue(visible(element), "reached \(element)")
    }

    /// On screen, below the navigation bar and clear of the tab bar — unless a sheet covers the tab
    /// bar (the Ask AI sheet), where the screen's bottom edge is the limit (settings-ui-3).
    private func visible(_ element: XCUIElement) -> Bool {
        let bar = app.tabBars.firstMatch
        let inSheet = app.buttons["askAIDone"].exists
        let floor = inSheet || !bar.exists ? app.frame.maxY - 30 : bar.frame.minY - 8
        return element.exists && element.isHittable && element.frame.minY > 100 && element.frame.maxY < floor
    }

    /// Swipes up until `element` is on screen, shooting each page after the first under `name`.
    private func page(to element: XCUIElement, name: String, limit: Int = 8) {
        var page = 2
        while !visible(element), page <= limit + 1 {
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.6)
            shoot("\(name)-\(page)")
            page += 1
        }
        // The pages prove the content only if the traversal reached it (codex-review-08 #6).
        XCTAssertTrue(element.exists && element.isHittable, "\(name): reached \(element)")
    }

    private func scrollToTop() {
        for _ in 0..<4 { app.swipeDown() }
    }

    /// The system share sheet (the file card also shows the file's name, so match the sheet itself).
    private var shareSheet: XCUIElement { any("ActivityListView") }

    /// Waits for the share sheet to settle, then closes it (a tap while it rises lands where Close
    /// was not yet; settings-ui-1).
    private func cancelShareSheet() {
        let close = app.buttons["header.closeButton"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.0)
        close.tap()
        if !shareSheet.waitForNonExistence(timeout: 3) {
            Thread.sleep(forTimeInterval: 1.0)
            if close.exists { close.tap() }
        }
        XCTAssertTrue(shareSheet.waitForNonExistence(timeout: 5))
    }

    /// Cancels a confirmation dialog: iOS 27 shows it without a Cancel button (a tap outside
    /// cancels), older runtimes with one (settings-ui-2).
    private func cancelDialog() {
        let cancel = app.sheets.buttons["Cancel"].firstMatch
        if cancel.exists { cancel.tap(); return }
        let outside = app.otherElements["PopoverDismissRegion"].firstMatch
        if outside.exists { outside.tap() } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        }
        XCTAssertTrue(app.sheets.firstMatch.waitForNonExistence(timeout: 5), "the dialog closed")
    }

    /// Types into the secure key field once the keyboard is up and the sheet has stopped moving:
    /// the sheet grows to full height as the keyboard rises, and keys typed during that move were
    /// lost (settings-ui-6, seen in its screen recording). Verifies the length and retypes once.
    private func typeKey(_ field: XCUIElement, _ text: String) {
        field.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.2)
        field.typeText(text)
        if (field.value as? String)?.count != text.count {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 30))
            Thread.sleep(forTimeInterval: 0.8)
            field.typeText(text)
        }
        XCTAssertEqual((field.value as? String)?.count, text.count, "the typed key stays in the field (as dots)")
    }

    // MARK: Captures

    func testCaptureSettingsLightDefault() { capture(appearance: "light", large: false) }
    func testCaptureSettingsLightAccessibility() { capture(appearance: "light", large: true) }
    func testCaptureSettingsDarkDefault() { capture(appearance: "dark", large: false) }
    func testCaptureSettingsDarkAccessibility() { capture(appearance: "dark", large: true) }

    private func capture(appearance: String, large: Bool) {
        launch(appearance: appearance, large: large)
        let suffix = "\(appearance)-\(large ? "axl" : "default")"

        // X01: units first, then down to the history note.
        Thread.sleep(forTimeInterval: 1.0)
        shoot("floodlight-09-x01-\(suffix)-1")
        page(to: any("dumbbellMoveNote"), name: "floodlight-09-x01-\(suffix)")
        scrollToTop()
        let metric = app.buttons["appUnitPreference.metric"]
        reach(metric)
        metric.tap()
        XCTAssertTrue(metric.isSelected)
        Thread.sleep(forTimeInterval: 0.6)
        shoot("floodlight-09-x01-metric-\(suffix)")
        app.buttons["appUnitPreference.usCustomary"].tap()

        // X02 with a key: the key card, then (AX) down to Remove key.
        let askAI = app.buttons["askAISettings"]
        reach(askAI)
        askAI.tap()
        let done = app.buttons["askAIDone"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertTrue(any("askAIKeyHint").exists, "the saved key's hint is shown")
        shoot("floodlight-09-x02-\(suffix)-1")
        page(to: app.buttons["askAIRemoveKey"], name: "floodlight-09-x02-\(suffix)")

        // Typing a replacement: Save key appears.
        let field = app.secureTextFields["askAIKeyField"]
        for _ in 0..<4 where !field.isHittable { app.swipeDown() }
        typeKey(field, "sk-proj-new9")
        XCTAssertTrue(app.buttons["askAISaveKey"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.6)
        // iOS blanks secure-entry text and its keyboard in screenshots: the shot shows Save key,
        // not the dots.
        shoot("floodlight-09-x02-typing-\(suffix)")
        // Empty the field, then Return: with nothing typed, Return only ends editing.
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 20) + "\n")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))

        // Remove key asks first; then Off.
        let remove = app.buttons["askAIRemoveKey"]
        reach(remove)
        remove.tap()
        let confirm = app.sheets.buttons["Remove key"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8)
        shoot("floodlight-09-x02-remove-\(suffix)")
        confirm.tap()
        XCTAssertTrue(remove.waitForNonExistence(timeout: 5))
        // Only as far as the key card: a swipe down at the top closes the sheet (settings-ui-2).
        // "Off" below the sheet's header, not scrolled under it (codex-review-09).
        let status = any("askAIStatus")
        for _ in 0..<3 where !(status.exists && status.frame.minY > done.frame.maxY) { app.swipeDown() }
        XCTAssertTrue(status.frame.minY > done.frame.maxY, "Off is on screen")
        Thread.sleep(forTimeInterval: 0.8)
        XCTAssertEqual(status.label, "Ask AI, Off")
        shoot("floodlight-09-x02-nokey-\(suffix)")
        done.tap()
        XCTAssertTrue(done.waitForNonExistence(timeout: 5))

        // X03: idle (an export five days ago), sharing, then the file card.
        let card = app.buttons["exportSettings"]
        reach(card)
        card.tap()
        XCTAssertTrue(any("exportPending").waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.2)
        shoot("floodlight-09-x03-\(suffix)-1")
        let csv = app.buttons["exportCSV"]
        page(to: app.buttons["exportJSON"], name: "floodlight-09-x03-\(suffix)")
        csv.tap()
        XCTAssertTrue(shareSheet.waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 0.8)
        shoot("floodlight-09-x03-sharing-\(suffix)")
        cancelShareSheet()
        let share = app.buttons["exportShare"]
        XCTAssertTrue(share.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertTrue(share.isHittable, "the file card's Share is on screen")
        shoot("floodlight-09-x03-done-\(suffix)")

        // A failed write.
        app.terminate()
        launch(appearance: appearance, large: large, extra: ["-uiTestExportFails"])
        reach(app.buttons["exportSettings"])
        app.buttons["exportSettings"].tap()
        let csvAgain = app.buttons["exportCSV"]
        reach(csvAgain)
        csvAgain.tap()
        let failure = any("exportFailure")
        XCTAssertTrue(failure.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertTrue(failure.isHittable, "the failure is on screen")
        shoot("floodlight-09-x03-failure-\(suffix)")
    }

    // MARK: Flows

    /// The tiles write the canonical preference; the choice is there on the next visit.
    func testUnitTilesSwitchAndPersist() {
        launch(settingsFixture: false)
        let metric = app.buttons["appUnitPreference.metric"]
        let us = app.buttons["appUnitPreference.usCustomary"]
        let start = metric.isSelected
        (start ? us : metric).tap()
        XCTAssertNotEqual(metric.isSelected, start)
        XCTAssertEqual(us.isSelected, start)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["openSettings"].tap()
        XCTAssertTrue(metric.waitForExistence(timeout: 5))
        XCTAssertNotEqual(metric.isSelected, start, "the unit choice persisted")
    }

    /// The rest pill steps by 15 s; "Ask to update templates" is the inverse of the suppression
    /// flag and both survive leaving the screen.
    func testWorkoutDefaults() {
        launch(settingsFixture: false)
        let rest = any("globalWorkingRest")
        reach(rest)
        XCTAssertEqual(rest.value as? String, "2:00")
        rest.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        let stepped = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '2:15'"), object: rest)
        XCTAssertEqual(XCTWaiter.wait(for: [stepped], timeout: 5), .completed)
        let ask = app.switches["askToUpdateTemplates"]
        reach(ask)
        XCTAssertEqual(ask.value as? String, "1", "asking is on by default (nothing suppressed)")
        ask.tap()
        let off = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '0'"), object: ask)
        XCTAssertEqual(XCTWaiter.wait(for: [off], timeout: 5), .completed)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["openSettings"].tap()
        reach(ask)
        XCTAssertEqual(ask.value as? String, "0")
        XCTAssertEqual(any("globalWorkingRest").value as? String, "2:15")
    }

    /// Save shows On with the key's last four; Remove asks first, Cancel keeps it.
    func testAskAIKeySaveAndRemove() {
        launch(settingsFixture: false)
        let row = app.buttons["askAISettings"]
        reach(row)
        XCTAssertEqual(row.label, "Ask AI, Off")
        row.tap()
        let status = any("askAIStatus")
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertEqual(status.label, "Ask AI, Off")
        XCTAssertFalse(app.buttons["askAISaveKey"].exists, "no Save key until something is typed")
        let field = app.secureTextFields["askAIKeyField"]
        typeKey(field, "sk-test-abcd1234")
        let save = app.buttons["askAISaveKey"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        // Let the sheet finish moving with the keyboard before the tap (settings-ui-1).
        Thread.sleep(forTimeInterval: 1.0)
        save.tap()
        let on = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'Ask AI, On, key sk-…1234'"), object: status)
        XCTAssertEqual(XCTWaiter.wait(for: [on], timeout: 5), .completed, status.label)
        XCTAssertFalse(app.buttons["askAISaveKey"].exists, "the field is cleared after saving")
        // Settings' row refreshes On when the sheet closes (codex-review-09).
        app.buttons["askAIDone"].tap()
        let rowOn = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'Ask AI, On'"), object: row)
        XCTAssertEqual(XCTWaiter.wait(for: [rowOn], timeout: 5), .completed, row.label)
        row.tap()
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertEqual(status.label, "Ask AI, On, key sk-…1234", "the key is still saved on reopening")

        let remove = app.buttons["askAIRemoveKey"]
        reach(remove)
        remove.tap()
        XCTAssertTrue(app.sheets.buttons["Remove key"].firstMatch.waitForExistence(timeout: 5))
        cancelDialog()
        XCTAssertTrue(remove.waitForExistence(timeout: 5), "Cancel keeps the key")
        Thread.sleep(forTimeInterval: 0.6)
        remove.tap()
        let confirm = app.sheets.buttons["Remove key"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        let off = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'Ask AI, Off'"), object: status)
        XCTAssertEqual(XCTWaiter.wait(for: [off], timeout: 5), .completed)
        app.buttons["askAIDone"].tap()
        XCTAssertEqual(row.label, "Ask AI, Off")
    }

    /// A cancelled share records nothing; a completed one (Copy) moves the mark to now.
    func testExportRecordsOnlyACompletedShare() {
        launch(settingsFixture: false)
        let card = app.buttons["exportSettings"]
        reach(card)
        XCTAssertFalse(card.label.contains("Last export"), "never exported")
        card.tap()
        let pending = any("exportPending")
        XCTAssertTrue(pending.waitForExistence(timeout: 5))
        let before = pending.label
        XCTAssertFalse(before.hasPrefix("0 "), "the sample's workouts are all pending: \(before)")

        let csv = app.buttons["exportCSV"]
        reach(csv)
        csv.tap()
        XCTAssertTrue(shareSheet.waitForExistence(timeout: 10))
        cancelShareSheet()
        XCTAssertTrue(app.buttons["exportShare"].waitForExistence(timeout: 5))
        XCTAssertEqual(pending.label, before, "a cancelled share is not a backup")

        app.buttons["exportShare"].tap()
        XCTAssertTrue(shareSheet.waitForExistence(timeout: 10))
        let copy = app.cells.matching(NSPredicate(format: "label == 'Copy'")).firstMatch
        XCTAssertTrue(copy.waitForExistence(timeout: 5), "the share sheet offers Copy")
        Thread.sleep(forTimeInterval: 1.0)
        copy.tap()
        XCTAssertTrue(shareSheet.waitForNonExistence(timeout: 5))
        let recorded = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label BEGINSWITH '0 workouts since last export' AND label CONTAINS 'Last export Today · CSV'"),
            object: pending)
        XCTAssertEqual(XCTWaiter.wait(for: [recorded], timeout: 5), .completed, pending.label)

        app.navigationBars.buttons.element(boundBy: 0).tap()
        reach(card)
        XCTAssertTrue(card.label.contains("Last export Today · CSV"), card.label)
    }

    /// Leaving through another tab drops the card with its file: Share never offers a deleted file
    /// (codex-review-09 #1).
    func testTabRoundTripDropsTheFileCard() {
        launch(settingsFixture: false)
        let card = app.buttons["exportSettings"]
        reach(card)
        card.tap()
        let csv = app.buttons["exportCSV"]
        reach(csv)
        csv.tap()
        XCTAssertTrue(shareSheet.waitForExistence(timeout: 10))
        cancelShareSheet()
        XCTAssertTrue(app.buttons["exportShare"].waitForExistence(timeout: 5))
        app.tabBars.buttons["History"].tap()
        Thread.sleep(forTimeInterval: 0.8)
        app.tabBars.buttons["Workout"].tap()
        XCTAssertTrue(any("exportPending").waitForExistence(timeout: 5), "back on Export (the tab kept it)")
        XCTAssertFalse(app.buttons["exportShare"].exists, "no Share for a deleted file")
        XCTAssertFalse(any("exportFileCard").exists)
        reach(csv)
        csv.tap()
        XCTAssertTrue(shareSheet.waitForExistence(timeout: 10), "a fresh export still shares")
        cancelShareSheet()
        XCTAssertTrue(app.buttons["exportShare"].waitForExistence(timeout: 5))
    }

    /// A failed write says so in the warning panel and presents nothing.
    func testExportFailureShowsTheWarning() {
        launch(extra: ["-uiTestExportFails"])
        let card = app.buttons["exportSettings"]
        reach(card)
        card.tap()
        let csv = app.buttons["exportCSV"]
        reach(csv)
        csv.tap()
        let failure = any("exportFailure")
        XCTAssertTrue(failure.waitForExistence(timeout: 5))
        XCTAssertTrue(failure.label.contains("Export failed: couldn’t save the file."), failure.label)
        XCTAssertFalse(shareSheet.exists)
        XCTAssertFalse(app.buttons["exportShare"].exists)
    }
}
