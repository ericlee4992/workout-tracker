# Stacked 0.2.0 (17) — independent release review

Reviewed branch `ericlee4992/release-0.2.0-17` at `fceb589303da92fa7626e9d3ab5b301d43a721ed`: release diff `b539c99e..fceb5893`, contents since build 16 `0449f245..b539c99e`. HEAD stayed unchanged and the working tree was clean before this report. Read STATE, the release record and prompt, the feature's prior review evidence, and DEVELOPMENT's TestFlight checklist and backup rule.

## Findings

No findings.

## Standards

All 10 target/configuration pairs in `project.pbxproj` have `CURRENT_PROJECT_VERSION = 17` and `MARKETING_VERSION = 0.2.0`: app, widget, Watch, unit tests and UI tests, each Debug/Release. Parsed the project configuration and checked each pair. The newly built simulator app and embedded widget Info.plists both report **0.2.0 (17)**.

The release diff contains only the ten build-number increments and two release records. `git diff --exit-code a53662d5..fceb5893 -- WorkoutTracker WorkoutTrackerTests WorkoutTrackerUITests Config server` passes: the app/test code is the version reviewed clear in feature round 2. That commit is an ancestor of the release baseline. No unrelated implementation change was introduced.

The repository secret scan, release-diff whitespace check, test-plan consistency check and release-record relative-link check passed. Inspection found no secrets or personal tester data in the new release records.

## Spec

The release record's contents match the eight changed app source files since build 16, all belonging to My settings. The What to Test note accurately describes the card, tap-to-edit, first-use hint, menu, machine page, separate notes per station exercise, and adding/changing/clearing a note.

Gate S is correctly required before the user's phone installs build 17. The stored-format change is the already-reviewed `MachineSettingsNote` model and cascade relationship from `MachineInstance`; the fingerprint changes from `9d83c203…` to `016aa14c…`. The migration and format-guard tests passed in the independent Unit run. The fixture addition remains gated to the disposable UI-test store. There is no additional production first-launch rewrite in this release.

No files under `server/`, the app startup directory, or `WhatsNew.swift` changed since build 16. No server deployment is needed, and no What's New entry was added, matching the user's recorded choice. Archive/upload are correctly recorded as pending; this review does not claim either has occurred.

Standards: 0 findings. Spec: 0 findings.

## Independent verification

Xcode 27.2 (27B52). Used only WT-Redesign-2 (`EB4328A1-87BD-4850-A3B2-A6E604701F1C`) and derived data `/tmp/wt-r17-codex`.

```sh
scripts/prepare-test-simulator.sh EB4328A1-87BD-4850-A3B2-A6E604701F1C
xcodebuild -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -destination 'platform=iOS Simulator,id=EB4328A1-87BD-4850-A3B2-A6E604701F1C' -derivedDataPath /tmp/wt-r17-codex build
xcodebuild test -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -testPlan Unit -destination 'platform=iOS Simulator,id=EB4328A1-87BD-4850-A3B2-A6E604701F1C' -derivedDataPath /tmp/wt-r17-codex -parallel-testing-enabled NO -resultBundlePath /tmp/wt-r17-codex-unit.xcresult
xcrun xcresulttool get test-results summary --path /tmp/wt-r17-codex-unit.xcresult --format json
xcrun xcresulttool get test-results summary --path build/results/r17-unit.xcresult --format json
scripts/check-secrets.sh --all
python3 scripts/test-plans.py --check
git diff --check b539c99e..fceb5893
```

Preparation and build exited 0. The independent Unit command exited 0; the completed xcresult reports **1329/1329 passed, 0 failed, 0 skipped**. Logs: `/tmp/wt-r17-codex-build.log` and `/tmp/wt-r17-codex-unit.log`; corresponding `.exit` files both contain `0`. The author's actual `build/results/r17-unit.xcresult` also reports 1329/1329, no failures/skips. Supporting checks above exited 0. Version assertions passed for all ten project configurations and both built app/widget plists.

No UI suite was rerun for the version/records-only release diff. Feature round 1 independently passed MySettingsUITests 9/9; feature round 2 cleared the domain-only fix, and the source/tests are unchanged here. Hosted CI status was not independently queried in this review; code identity with the recorded CI commit `4c91d905` was checked locally.

Verified: build — exit 0; Unit plan — 1329/1329, exit 0, `/tmp/wt-r17-codex-unit.xcresult`; project and built app/widget versions; secret/consistency checks.
Not verified: archive, release signing, upload, App Store Connect distribution, phone Gate S/installation, CloudKit sync, or a new UI run. Only the requested review report was modified; no phone, Apple-account, private backup-directory, deployment or desktop-control access.
Known flaky: none seen in the selected scope.

Verdict: clear
