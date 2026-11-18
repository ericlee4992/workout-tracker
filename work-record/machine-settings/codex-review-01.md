# My settings — independent review, round 1

Reviewed `0916cc97..a84a6b4e` on `ericlee4992/my-settings`, with the full feature diff against `9d7ac436` checked as well. HEAD advanced to `1c96db4a` during review; the intervening commits change only `docs/STATE.md`. App/test code is unchanged. Reviewer changed no product code.

## Findings

1. **P2 — Keep the edited row canonical when the clock moves backward.** `WorkoutTracker/Domain/MachineSettings.swift:57` assigns the supplied/current wall-clock time directly. Given two rows for the same machine × exercise, `Old@200` and `New@300`, clearing at time `100` produces `Old@200` and `blank@100`. The next `note()` call selects “Old”: Save succeeds but the cleared note immediately resurfaces on both the live card and machine page. A nonblank edit can likewise appear lost. This violates the ticket/D91 contract that clearing the canonical row must suppress older duplicates. Sync is currently disabled, which reduces exposure, but duplicate handling is an explicit supported invariant of this implementation. Preserve the edited row's ordering, e.g. `existing.updatedAt = max(previous.1, date)` (its UUID tie-break already won), while retaining failure restoration. Add domain regressions for both clearing and editing duplicate rows at an earlier timestamp, plus an equal-timestamp UUID tie. `MachineSettingsTests.swift:89–103` currently exercises only increasing dates.

   Reproduction: executed the repository's actual `CanonicalRow` implementation via `swift -` with two small conforming rows and the same text/date assignments as `MachineSettings.save`. Exit 0; output: `Before clear: New` → `After successful blank update, selected text: Old`. This is a deterministic selection/mutation probe, not a SwiftData integration test; source establishes the call path.

## Standards

One domain correctness finding above; no additional actionable standards violations. UUID/default/optional schema rules and the explicit cascade inverse are satisfied. Failed updates restore the original text/date; failed inserts detach/delete the new row without rolling back unrelated workout edits. Export v15 carries every note field, cleared rows, the count and referenced exercises; v14 additions are optional. No unrelated modernization or file splits requested.

## Spec

Apart from finding 1, no additional implementation defects found. The machine × exercise key is used consistently by the card, sheet and machine page. First-use history is fetched by the frozen machine/exercise IDs in `.task(id:)`, not during body evaluation; machine changes invalidate the task and a new workout creates a fresh card hierarchy. A failed history fetch suppresses the offer. Cancel uses local draft state; failed Save retains the draft and presents the specified error.

Reader search (`settingsNotes|MachineSettings`, plus export field names) found only intended UI, export, schema and isolated fixture uses. No automatic note path into AI, server/feedback payloads, History, D23 snapshots or Live Activities was found. The new fixture is gated through `DesignSampleFixture.isEnabled` → `fixtureIsEnabled`, requiring `-uiTestReset` and its disposable store.

The Build16 fixture's metadata is checked against the pre-feature shipped fingerprint. The model change is additive; there is no new production first-launch rewrite. N1 copies the complete SQLite store/WAL/SHM files before opening an incompatible model, so no table-specific copy change is needed. Migration tests check old-format detection, selected row counts, and saving a note on an existing machine; they do not establish byte-for-byte fidelity for every old field. Gate S remains necessary before a phone install.

Inspected the four committed real capture contact sheets (light/dark × default/AccessibilityL): the note and station rows wrap, and the editor controls remain usable. No new visual finding. README/SPEC/D91 describe the implemented feature. 

Scope is appropriate per DEVELOPMENT: full Unit plan for the new persistence/export domain behavior, plus `MySettingsUITests` for the two affected UI surfaces. Optional coverage beyond the required fix: switch a draft entry between machines, finish the first workout and start another, and exercise the failed-save alert in UI. These paths were inspected, not separately driven by added tests.

## Independent verification

Xcode 27.2 (27B52). Only WT-Redesign-2 (`EB4328A1-87BD-4850-A3B2-A6E604701F1C`) was used; derived data `/tmp/wt-ms01-codex`. No phone, Apple-account, private backup-directory, deployment or desktop-control access.

Commands:

```sh
scripts/prepare-test-simulator.sh EB4328A1-87BD-4850-A3B2-A6E604701F1C
xcodebuild -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -destination 'platform=iOS Simulator,id=EB4328A1-87BD-4850-A3B2-A6E604701F1C' -derivedDataPath /tmp/wt-ms01-codex build
xcodebuild test -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -testPlan Unit -destination 'platform=iOS Simulator,id=EB4328A1-87BD-4850-A3B2-A6E604701F1C' -derivedDataPath /tmp/wt-ms01-codex -parallel-testing-enabled NO -resultBundlePath /tmp/wt-ms01-codex-unit.xcresult
xcodebuild test -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -testPlan Workout -only-testing:WorkoutTrackerUITests/MySettingsUITests -destination 'platform=iOS Simulator,id=EB4328A1-87BD-4850-A3B2-A6E604701F1C' -derivedDataPath /tmp/wt-ms01-codex -parallel-testing-enabled NO -resultBundlePath /tmp/wt-ms01-codex-ui.xcresult
python3 scripts/test-plans.py --check
git diff --check 0916cc97..a84a6b4e
```

- Simulator preparation, build, plan consistency and diff whitespace checks: exit 0.
- Unit: **1327/1327 passed, 0 failed, 0 skipped, exit 0**. Independently read with `xcrun xcresulttool get test-results summary --path /tmp/wt-ms01-codex-unit.xcresult --format json`.
- Focused UI: **9/9 passed, 0 failed, 0 skipped, exit 0**. Independently read the xcresult summary. Log `/tmp/wt-ms01-codex-ui.log`, result `/tmp/wt-ms01-codex-ui.xcresult`, status `/tmp/wt-ms01-codex-ui.exit`. Fresh capture attachments exported to `/tmp/wt-ms01-codex-captures`. The AccessibilityL editor is usable. The fresh dark AccessibilityL station-card capture overscrolled past the note: it is not evidence of note visibility, despite the test passing. The note-wrapping assessment uses the four committed contact sheets. Consider making the capture helper assert its target is visible before shooting (the current bounded swipe loop can exhaust silently).
- Build/unit logs: `/tmp/wt-ms01-codex-build.log`, `/tmp/wt-ms01-codex-unit.log`; corresponding `.exit` files contain 0.
- Also inspected the author's actual xcresults: `build/results/unit-ms2.xcresult` reports 1327/1327; `build/results/ui-ms1.xcresult` reports 9/9, neither has failures/skips. These do not substitute for the independent runs.

Standards: 1 P2 finding (canonical-row demotion). Spec axis: no additional findings beyond that D91 invariant failure.

Verified: build — exit 0; Unit plan — 1327/1327, exit 0, `/tmp/wt-ms01-codex-unit.xcresult`; MySettingsUITests — 9/9, exit 0, `/tmp/wt-ms01-codex-ui.xcresult`; no skipped tests. Format-guard and migration tests passed within Unit. Plan/diff checks passed.
Not verified: phone upgrade/Gate S or install; CloudKit sync (disabled); VoiceOver by ear; runtime Reduce Motion; a SwiftData integration reproduction of finding 1. No full UI suite was required or run.
Known flaky: none seen in this review's selected scope.

Verdict: not clear
