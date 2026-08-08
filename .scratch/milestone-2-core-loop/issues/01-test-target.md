# 01 — Unit test target

**What to build:** A `WorkoutTrackerTests` unit-test target exists and runs, so every later ticket can ship tests. This is the one sanctioned `project.pbxproj` edit (buildable folders don't cover target creation).

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

- [ ] `WorkoutTrackerTests` target added to the Xcode project, using a synchronized folder so test files auto-register
- [ ] One trivial passing test proves the pipeline
- [ ] `xcodebuild test` passes against a reproducible destination: use `platform=iOS Simulator,name=<first available iPhone>` resolved via `xcrun simctl list`, creating a device if none exists; exact command + device-bootstrap note documented in CLAUDE.md
