# Release review — Stacked 0.2.0 (16)

Reviewed 2026-11-15: `git diff 26642ef8..f93a716c`, branch
`ericlee4992/release-0.2.0-16`, HEAD `f93a716c332cc2e27b50a0ee6f6617f0d858d53c`.
Working tree was clean before review. Followed DEVELOPMENT's TestFlight checklist steps 1–3
and read `work-record/release/0.2.0-build-16.md`. Only this report was written; no commit,
archive, upload, deployment or device installation was performed.

## Standards

No findings.

- Parsed `project.pbxproj` with `plutil` and checked each native target's Debug and Release
  build configurations. All **10 configurations** have `CURRENT_PROJECT_VERSION = 16` and
  `MARKETING_VERSION = 0.2.0`: WorkoutTracker, WorkoutTrackerWidget, WorkoutTrackerWatch,
  WorkoutTrackerTests and WorkoutTrackerUITests. No version overrides were found in Config.
- The release diff contains only the ten build-number increments and the release record.
  `git diff --check 26642ef8..f93a716c` exits 0.
- `git ls-remote` confirms remote `main` at `26642ef847e7d28384c858728286e7f01bc63472` and
  the release branch at the reviewed HEAD. The cleared feature tip `09c19957` is an ancestor
  of main; the subsequent merge-record commit changes no app/widget/watch/test source.
- The complete build-15-to-main file list and domain diff were inspected. Models.swift,
  Nutrition.swift, schema/container construction, migration/storage-format code and `server/`
  are unchanged. The changed domain services introduce runtime behavior/test seams, not stored
  properties. **No Gate S and no deploy are supported for this update from build 15.**

## Spec and release record

No findings.

- The release contains live-workout 04, independently cleared in round 4. The approved What
  to Test note matches the current-set Done flow on the Lock Screen and expanded Dynamic Island,
  directs value editing to the app, and asks testers to exercise supersets and heart-rate rests.
  Those retain their documented rest rules. The record documents the user's choice of no
  in-app What's New entry for this build.
- The record distinguishes implemented/tested work from archive, upload and phone verification,
  which are still pending. Its reported Unit count is supported by the author's xcresult:
  `build/results/r16-unit.xcresult` reports **1312/1312 Passed**, zero failures/skips.
- Old Live Activity payload compatibility was checked by execution, not only inspection:
  encoded a ContentState with NextSet using the actual source at `ed8825ad`, then decoded it
  using the current source. The fixture includes `previous` and lacks `setID`/`fingerprint`.
  The old marker, exercise, superset, weight/unit and reps survive; `previous` is ignored; both
  new optional fields are nil. `isLoggable` is false, so the old card cannot offer Done until
  refreshed with current content. No persisted workout-store migration is involved.

Standards: 0 findings. Spec: 0 findings.

## Reviewer verification

Environment: Xcode 27.2 (`27B52`), WT-Floodlight simulator
`9E822EF6-DC67-4958-AEA2-D53D2D36D674`, iPhone 15 Pro Max / iOS 27.0.

```sh
scripts/prepare-test-simulator.sh
# exit 0

xcodebuild build-for-testing -project WorkoutTracker.xcodeproj -scheme WorkoutTracker \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,id=9E822EF6-DC67-4958-AEA2-D53D2D36D674' \
  -derivedDataPath build/dd-codex
# exit 0; TEST BUILD SUCCEEDED

xcodebuild test-without-building -project WorkoutTracker.xcodeproj -scheme WorkoutTracker \
  -testPlan Unit -destination 'platform=iOS Simulator,id=9E822EF6-DC67-4958-AEA2-D53D2D36D674' \
  -derivedDataPath build/dd-codex -parallel-testing-enabled NO -collect-test-diagnostics never \
  -resultBundlePath build/results/r16-codex-unit.xcresult
# exit 0; 1312/1312 passed, 0 failed, 0 skipped

git diff --exit-code ed8825ad..26642ef8 -- \
  WorkoutTracker/Domain/Models.swift WorkoutTracker/Domain/Nutrition.swift server
# exit 0; no differences

git diff --check 26642ef8..f93a716c
# exit 0
```

Version audit: `plutil -convert json -o - WorkoutTracker.xcodeproj/project.pbxproj`, parsed
with Python to resolve every PBXNativeTarget's configurations and assert both version values;
exit 0. Payload probe: Python read the old file via `git show ed8825ad:...`, read the current
file, renamed the legacy enclosing type, and passed both definitions and assertions to
`xcrun swift -`; exit 0. Only the ActivityKit import was replaced with a minimal protocol
stub for host execution; the actual nested Codable definitions and synthesized decoding were
used unchanged. No repository source or tests were modified for the probe.

Actual build/Unit exit statuses and xcresult summary inspected. Logs and status files:
`build/results/r16-codex-{build,unit,payload}.{log,status}`; Unit result above. No UI suite was
run: no UI/app behavior changed after the feature clearance, and the user requested no UI tests.

Verified: version/build audit; no stored-format/server changes; old-payload decode probe, exit 0;
reviewer build, exit 0; Unit **1312/1312**, exit 0, `build/results/r16-codex-unit.xcresult`.
Not verified: archive/signing checks, upload, installation or physical-phone upgrade/Live Activity
behavior. These remain later release steps; no archive was attempted.
Known flaky: the feature record's parallel keyboard-unit-focus and real Live Activity cases;
not run for this release review. None seen in the reviewer Unit run.

Verdict: clear
