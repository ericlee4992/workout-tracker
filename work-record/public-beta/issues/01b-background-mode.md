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

Why the alarm is expected to hold: the 2026-08-25 incident account (archived STATE, "the background rest alarm";
D46) says the design that worked queues each rest's [silence][beep] track when the rest starts, so nothing has to
execute at the deadline; it plays under the `audio` mode, which stays. `workout-processing` was one of the earlier
attempts. **Corrected after Codex review 01b:** an earlier version of this ticket and of the changed comments
credited the inaudible loop with the fix; the incident account lists the loop among the insufficient attempts.
Unknown: whether the iPhone `HKWorkoutSession` keeps delivering heart-rate samples in the background without the
removed mode; between rests the app's only background activity is the inaudible loop.

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
- Unit run (`BackgroundModesTests` + `RestAlarmTests`, WT-Floodlight `9E822EF6…`, iOS 27): `xcodebuild test` exit 0,
  `** TEST SUCCEEDED **`, xcresult **Passed 16/0/0** (`…/scratchpad/bm/unit.xcresult`, ephemeral).
- Clean device build (fresh derived data, commit `2b8d5fc`): exit 0; built `Info.plist` `UIBackgroundModes` =
  `["audio","location"]`; HealthKit and camera usage strings present; profile to 2027-10-13. Installed over the app
  with the app closed (successful process query, no app process): `devicectl device install` exit 0.
- **The user's phone check, 2026-10-13:** asked to start a workout, log a set, lock the phone (then once with another
  app open), and listen for the rest-end beep; also to check heart rate if a source was on. Reply: "it works." —
  taken as the beep sounding with the app in the background. Heart rate in the background was not reported
  separately.
- **The user, 2026-10-13, to "did you have a Watch or strap on, and did heart rate keep updating while locked?":
  "Yes."** That test covered a rest, while the queued track was playing — not the minutes after the beep (below).

## Codex review 01b — response (round 1)

Review: [codex-review-01b-bgmode.md](../codex-review-01b-bgmode.md) — not clear (P1, P2, S1, S2).

1. **P1 — after a rest's beep nothing plays.** Confirmed in source: `scheduleBeep` stops the loop; the queued track
   ends with its beep; nothing restarted the loop, so from the beep to the next set the app played no audio and could
   be suspended (heart-rate samples and timers with it). Pre-existing, but it undercut this ticket's argument.
   **Fixed:** the queued track's player has a delegate (`TrackEndObserver`); when it finishes, the alarm clears the
   track and its deadline and restarts the loop (`SystemRestAlarm.scheduledTrackFinished`). Clearing the deadline
   also fixes a second pre-existing defect it found adjacent: an interruption or route change *after* a beep rebuilt
   the old deadline as an immediate second beep. Not unit-testable (the tests use a fake alarm; `AVAudioPlayer`
   completion needs a device): the phone check below covers it.
2. **P2 / S1 — comments credited the wrong mechanism.** Corrected in the plist, `BackgroundModesTests`,
   `RestAlarmTests` and this ticket: the fix that held is the rest track queued at the rest's start (D46); the loop is
   for between rests; background heart rate without the removed mode is a device question. "Asserted below" no
   longer claims more than a plist check.
3. **S2 — evidence.** Recorded above (commit `4ea8ccf`, after the review prompt was written).

**Unit run after the fix** (`BackgroundModesTests`, `RestAlarmTests`, `RestAlarmOwnershipTests`,
`ScheduledRestBeepTests`): exit 0, `** TEST SUCCEEDED **`, **Passed 27/0/0** (`…/scratchpad/bm/unit2.xcresult`).

**Phone check scope (Codex's list, cut to what this change touches — the user's call to widen it):** one lifting
workout, phone locked and workout minimized, heart-rate source on: a timed rest's beep, then **3+ minutes locked after
the beep**, then reopen and check the heart-rate chart for that interval has readings throughout, not a gap; once
more with another app in front. Indoor cardio, interruption and HR-recovery scenarios are not re-run: this change does
not touch them, and they ran on this path before. Background delivery is judged from the saved chart, which can hide
delay; recorded as such.
