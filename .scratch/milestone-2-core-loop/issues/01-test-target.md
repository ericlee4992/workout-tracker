# 01 — Unit test target

**What to build:** A `WorkoutTrackerTests` unit-test target exists and runs, so every later ticket can ship tests. This is the one sanctioned `project.pbxproj` edit (buildable folders don't cover target creation).

**Blocked by:** None — can start immediately.

**Status:** resolved

- [x] `WorkoutTrackerTests` target added to the Xcode project, using a synchronized folder so test files auto-register
- [x] One trivial passing test proves the pipeline
- [x] `xcodebuild test` passes against a reproducible destination: use `platform=iOS Simulator,name=<first available iPhone>` resolved via `xcrun simctl list`, creating a device if none exists; exact command + device-bootstrap note documented in CLAUDE.md

## Comments

Resolved 2026-08-08. `WorkoutTrackerTests` added as a `PBXFileSystemSynchronizedRootGroup`
target (unit-test bundle, TEST_HOST/BUNDLE_LOADER against the app, iOS 17, signing disabled).
One Swift Testing test in `WorkoutTrackerTests/WorkoutTrackerTests.swift` passes. A shared
`WorkoutTracker` scheme with a TestAction was added so `xcodebuild test` works headlessly.
Destination standardized on the `WT-iPhone` simulator (created if missing); exact command and
bootstrap note live in CLAUDE.md's Build & run section.
