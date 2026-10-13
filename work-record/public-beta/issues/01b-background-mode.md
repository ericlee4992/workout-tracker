# 01b — Remove `workout-processing` so TestFlight accepts the app

Type: bug (release blocker for ticket 01 phase E)
Status: implemented; waiting for the user's phone check and Codex review
Implementer: Claude; Reviewer: Codex (visible Orca terminal), to "clear".
Branch: `ericlee4992/beta-01b-background-mode` off `main`.

## Problem

The first TestFlight upload (ticket 01 E1; archive of `main` `f952262`, version 0.1.0 build 1, paid team) failed:
`xcodebuild -exportArchive` exit 70, "Invalid Info.plist value. The Info.plist key UIBackgroundModes contains an
invalid value: 'workout-processing'" (ID MTCLDKI2RRIKIBM5LOO4LSCBU4). App Store Connect refuses it for the iPhone app.

## Decision (the user, 2026-10-13: "go ahead")

Remove `workout-processing` from `Config/WorkoutTracker-Info.plist`; keep `audio` and `location`. Before any TestFlight
upload, the user checks on the phone that the screen-off rest alarm still sounds (and, with heart rate connected,
that it keeps updating). If the alarm stops working, stop and find another way before uploading.

Why it is expected to hold: the 2026-08-25 history (archived STATE; `RestAlarmSound.swift` `startKeepAlive`) says
`workout-processing` alone did not fix the silent screen-off alarm; the fix that held is the looping inaudible track
under the `audio` mode, which keeps the process alive. Unknown: whether the iPhone `HKWorkoutSession` keeps
delivering heart-rate samples in the background without it (the process stays alive through audio).

## Change

- `Config/WorkoutTracker-Info.plist`: `workout-processing` removed, with a comment saying why.
- `WorkoutTrackerTests/BackgroundModesTests.swift`: the test that required `workout-processing` now requires its
  absence (an App Store Connect rejection); `audio` and the usage-string checks unchanged. Header comment updated.
- `WorkoutTrackerTests/RestAlarmTests.swift`: comment updated.

## Verification scope

A build setting with device-only behavior: build; `BackgroundModesTests` + `RestAlarmTests` (unit, the built app's
plist); a clean device build whose built `Info.plist` lacks the mode; the user's phone check (screen-off rest alarm,
heart rate); then the TestFlight upload must pass validation.

## Evidence
