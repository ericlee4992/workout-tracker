# Independent review — live-workout-fixes 01, round 2

Reviewed `git diff ecc82a7..HEAD` on `ericlee4992/live-01-weight-unit`, HEAD `49cd6663f5c51dc54a8bf15030208b6b955270b4`. Claude authored; Codex reviewed. The working tree was clean. Only this report was written.

## Prior findings

Both P3 findings are resolved.

- The original run is correctly recorded as 13 Floodlight + 2 Barbell + 2 CoreLoop = 17 tests. The new test's separate 1/0/0 result is distinguished from that original run.
- All three keyboard captures are tracked under `work-record/live-workout-fixes/captures/01/`, and the ticket's relative links resolve. SHA-256 hashes match the original reviewed light/default, dark/default, and light/AccessibilityL attachments byte-for-byte. The tested implementation revision is recorded. Scratch paths are abbreviated in the ticket, but the linked first review supplies the full evidence root.

## Standards findings

No blocking findings.

1. **P3 — Optional: wait explicitly for picker disappearance.** `WorkoutTrackerUITests/FloodlightLiveUITests.swift:83` uses `XCTAssertFalse(unitSwitch.waitForExistence(timeout: 2))`. This checks that the picker does not appear during the observation period; it does not allow an existing picker two seconds to disappear. If a transient accessibility snapshot still contains the old toolbar after the reps tap, the assertion can fail before the removal settles. **Suggested improvement:** use `XCTAssertTrue(unitSwitch.waitForNonExistence(timeout: 2))`, or a predicate waiting for `exists == false`. This is a nonblocking robustness suggestion: the inspected run passed, its tap waited for app idleness, and no delayed-removal failure was observed.

## Spec and test assessment

The new test supports the response's claims for the exercised flow:

- `launch()` resets and seeds `-uiTestDesignSample -uiTestDesignLive`. The fixture creates three ordered sets in the first entry: 100 lb, 110 lb, 110 lb, with the first two completed (`DesignSampleFixture.swift:337–351`; gym default lb at `:127`). Thus index 2 is the intended draft and index 1 is the other, completed row. This test does not add, delete, or reorder rows while those indices are used.
- The initial coordinate is relative to the weight field, not a fixed screen location. Tapping at 97% of its width places the caret at the end of the fixture's three-character `110`; four backspaces safely clear it. The subsequent exact `12` assertion also detects a failed clear. These choices are consistent with this fixture and default-size test, rather than claims of arbitrary-layout coverage.
- Selecting kg happens immediately after typing `12`, without first moving to reps or pressing Done. The assertions verify that the unit changes and the entered number remains `12`.
- `draft.typeText("0")` is called without another tap. The installed XCTest header explicitly requires keyboard focus for `typeText`, otherwise it raises an error. The resulting `120` therefore checks retained focus and continued editing, rather than silently refocusing the field.
- Moving to reps checks absence of the picker. Moving to index 1 then checks exactly one picker, lb selected, while the draft remains kg. This meaningfully detects a stale kg selection or duplicate picker at that final state. It does not claim continuous observation of every animation frame.

No product code changed in round 2, and no new product/spec defect was identified. The response accurately leaves deletion of a focused row and human VoiceOver/Switch Control discovery unverified. This test also does not independently prove crash/relaunch durability; the existing persistence coverage and source assessment remain as recorded in round 1.

## Verification

Independently inspected `r2.status` (**exit 0**), `r2.log` (**TEST SUCCEEDED**, named new test passed), and `xcresulttool get test-results summary` for `r2.xcresult` (**Passed, 1 passed, 0 failed, 0 skipped**). Evidence root:

`/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-public-beta/0dc39eb1-054d-49da-bf79-784fabae4a4e/scratchpad/live01/`

`git diff --check ecc82a7..HEAD` passed. The new focused run plus the previously verified 17-test run is proportionate for this test/evidence-only follow-up under DEVELOPMENT. One successful run cannot establish an absolute absence of flakiness; no concrete coordinate or fixture-index defect was found, and the timing improvement above is advisory.

No new build/test run, simulator interaction, desktop control, phone/account/backup access, or deployment was performed. No new captures were necessary because the preserved files are identical to those already visually reviewed.

Standards: prior findings resolved; one nonblocking robustness suggestion. Spec: clear.

Verdict: clear
