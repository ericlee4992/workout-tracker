# My settings — independent review, round 2

Reviewed `a84a6b4e..a53662d5` on `ericlee4992/my-settings`; HEAD remained `a53662d5d73e741ffde3bf59c57e3a7c98d573ec`. Read the round-2 prompt, current STATE, ticket and round-1 report. Only the new report was modified by the reviewer.

## Findings

No new findings. Round-1 P2 #1 is resolved.

## Standards

`WorkoutTracker/Domain/MachineSettings.swift:60` now uses `max(previous.1, date)`. An existing canonical row cannot move backward in the ordering, and its unchanged UUID preserves its winning position when timestamps tie. Both blank clears and nonblank edits therefore retain the selected row.

The failed-save catch still restores the original text and timestamp. The insert/detach/delete path is unchanged. The focused tests exercise both failure paths, ordinary updates, clears, duplicate resolution, ownership, history, export and migration. No schema, UI, export-format or first-launch changes were introduced in this round.

## Spec

D91's clear/edit contract is satisfied for the reported backward-clock scenario. `anEditAtAnEarlierTimeKeepsTheRowCanonical` tests both clear and edit with duplicates at 200/300 and a save at 100. `anEqualDateTieStaysWithTheEditedRow` tests clearing the UUID winner among equal-date duplicates. Both passed independently, along with the existing failed-save regressions.

Standards: 0 outstanding findings. Spec: 0 outstanding findings.

## Verification

Xcode 27.2 (27B52); only WT-Redesign-2 (`EB4328A1-87BD-4850-A3B2-A6E604701F1C`), with `/tmp/wt-ms01-codex` derived data. No phone, Apple-account, private backup-directory, deployment or desktop-control access.

```sh
scripts/prepare-test-simulator.sh EB4328A1-87BD-4850-A3B2-A6E604701F1C
xcodebuild -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -destination 'platform=iOS Simulator,id=EB4328A1-87BD-4850-A3B2-A6E604701F1C' -derivedDataPath /tmp/wt-ms01-codex build
xcodebuild test -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -testPlan Unit -only-testing:WorkoutTrackerTests/MachineSettingsTests -only-testing:WorkoutTrackerTests/MachineSettingsMigrationTests -destination 'platform=iOS Simulator,id=EB4328A1-87BD-4850-A3B2-A6E604701F1C' -derivedDataPath /tmp/wt-ms01-codex -parallel-testing-enabled NO -resultBundlePath /tmp/wt-ms01-codex-r2-unit.xcresult
xcrun xcresulttool get test-results summary --path /tmp/wt-ms01-codex-r2-unit.xcresult --format json
xcrun xcresulttool get test-results summary --path build/results/unit-ms3.xcresult --format json
git diff --check a84a6b4e..a53662d5 -- WorkoutTracker WorkoutTrackerTests
```

Preparation, build and code-diff whitespace check exited 0. The independent test command exited 0; its xcresult reports **17/17 passed, 0 failed, 0 skipped**. Logs: `/tmp/wt-ms01-codex-r2-build.log`, `/tmp/wt-ms01-codex-r2-unit.log`; corresponding `.exit` files both contain `0`. The author's `build/results/unit-ms3.xcresult` also reports 17/17, no failures/skips, and its log ends `TEST SUCCEEDED`.

UI tests were **not rerun**, as requested for this domain-only fix. No UI source or UI test changed. Reinspected the independent round-1 `/tmp/wt-ms01-codex-ui.xcresult`: 9/9 passed, no failures/skips (round-1 process exit 0). The round-1 capture-helper limitation remains nonblocking: one fresh AccessibilityL station screenshot overscrolled past its note; the committed captures supplied the wrapping evidence. The broader Unit run from round 1 remains 1327/1327; this round's deliberately narrower scope covers the changed save logic and migration without repeating the full plan.

The unscoped diff whitespace check detects one trailing space in the previously committed round-1 review report, not product/test code; no behavioral finding.

Verified: build — exit 0; MachineSettingsTests + MachineSettingsMigrationTests — 17/17, exit 0, `/tmp/wt-ms01-codex-r2-unit.xcresult`; no skipped tests. New regressions and both failed-save tests passed.
Not verified: UI rerun or full Unit rerun this round; phone upgrade/Gate S or installation; CloudKit sync (disabled); VoiceOver by ear; runtime Reduce Motion. The feature remains a stored-format change requiring Gate S before a phone install.
Known flaky: none seen in the selected scope.

Verdict: clear
