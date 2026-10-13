# 01b — Remove `workout-processing` so TestFlight accepts the app

Type: bug (release blocker for ticket 01 phase E)
Status: **Done** — Codex clear (round 4); phone check passed on `fd88791` (the user, 2026-10-13); merged to `main` for the TestFlight upload (ticket 01 phase E)
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
   the old deadline as an immediate second beep. Not covered by the existing fake-alarm tests (round 2 adds state
   tests); the delegate's arrival after real playback is a device question.
2. **P2 / S1 — comments credited the wrong mechanism.** Corrected in the plist, `BackgroundModesTests`,
   `RestAlarmTests` and this ticket: the fix that held is the rest track queued at the rest's start (D46); the loop is
   for between rests; background heart rate without the removed mode is a device question. "Asserted below" no
   longer claims more than a plist check.
3. **S2 — evidence.** Recorded above (commit `4ea8ccf`, after the review prompt was written).

**Unit run after the fix** (`BackgroundModesTests`, `RestAlarmTests`, `RestAlarmOwnershipTests`,
`ScheduledRestBeepTests`): exit 0, `** TEST SUCCEEDED **`, **Passed 27/0/0** (`…/scratchpad/bm/unit2.xcresult`).

## Codex review 01b — response (round 2)

Review: [codex-review-01b-bgmode-b.md](../codex-review-01b-bgmode-b.md) — not clear (three P2); round 1's S1/P2
resolved, P1's ordinary path fixed.

1. **R2-P1 — identity across the main-actor hop.** The delegate now passes the finished `AVAudioPlayer` itself into
   the main-actor task (holding it alive) and `scheduledTrackFinished` compares with `===`; no `ObjectIdentifier`.
   New `QueuedTrackCompletionTests` (real `SystemRestAlarm`, fresh instance; the handler called directly): the
   finished track clears itself and its deadline and restarts the loop; a replaced track's late completion leaves
   the new track and deadline alone; a cancelled track's late completion changes nothing; a completion after
   `endSession` does not reopen audio. `isSessionOpen`, `keepAlive`, `scheduled`, `scheduledEndsAt` became
   `private(set)` for these tests; `scheduledTrackFinished` internal. Not confirmed: whether the simulator opened the
   audio session in these runs (the "loop playing again" check is conditional on it).
2. **R2-S1 — scope rationale.** Corrected: the route/interruption path reads the deadline this change clears, so the
   phone check includes a route change after a beep (below).
3. **R2-P2 — the chart is not live evidence.** The phone check uses the lock-screen Live Activity, whose heart-rate
   number only the running app can update: it must change during the locked minutes after the beep. If the user
   cannot observe that, timely background delivery stays unverified (the chart shows retention only).

**Unit run after round 2** (`BackgroundModesTests`, `RestAlarmTests`, `RestAlarmOwnershipTests`,
`ScheduledRestBeepTests`, `QueuedTrackCompletionTests`): exit 0, `** TEST SUCCEEDED **`, **Passed 31/0/0**; the four
new tests listed as passed in the xcresult. Artifacts:
`/private/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-public-beta/0dc39eb1-054d-49da-bf79-784fabae4a4e/scratchpad/bm/`
(`unit3.xcresult`, `unit3.log`, `unit3.status`; earlier `unit2.*`, `device2.log`, `install2.log` for `7af1445`).

**Phone check (narrowed, per round 2):** the newest build (identity below), launched by hand, heart-rate source on,
lock-screen Live Activity visible: (1) lifting, timed rest, workout minimized, phone locked — the beep sounds; (2)
**3+ minutes locked after the beep, the Live Activity's heart rate keeps changing**; (3) after that beep, take an
AirPod out and put it back (a route change) — no second beep; (4) the next rest beeps too; (5) once with another app
in front. Then Cancel the test workout. Cardio, interruption-during-rest and HR-recovery scenarios are not re-run;
this change does not touch those paths.

**For the phone check:** clean device build of `fd88791` (`device3.log`, `device3.status` exit 0; built
`UIBackgroundModes` `["audio","location"]`; the dylib carries the new log line); app closed (successful process
query, no app process; `procs3.txt`). **Install NOT done:** `devicectl device install` exit 1 — "The tunnel connection
failed … Operation timed out" (`install3.log`, `install3.status`); the phone then showed "unavailable". The phone
still runs `7af1445` (round 1's fix, without the round-2 identity change). (The first version of this entry, in `f5ef000`,
said exit 0 before the result was read; corrected.)

## Codex review 01b — response (round 3)

Review: [codex-review-01b-bgmode-c.md](../codex-review-01b-bgmode-c.md) — not clear: R2-P1, R2-S1 and S2 resolved;
one open P2 (R3-P1): the Live Activity is not a valid live-delivery observation — minimizing removes
`ActiveWorkoutView`, whose liveness tick is the only recurring `pushActivityState()` caller, so the lock-screen number
does not update while minimized even if samples arrive (pre-existing; not this ticket's fix).

**Accepted. Phone check, corrected (replaces the round-2 plan):** the newest build installed, launched by hand,
heart-rate source on: (1) lifting, timed rest, workout minimized, phone locked — the beep sounds; (2) stay locked 3+
minutes after it; (3) after a beep, an AirPod out and back (route change) — no second beep; (4) the next rest beeps;
(5) once with another app in front; then Cancel the test workout. The heart-rate chart afterwards is **retention
evidence only**. **Timely background heart-rate delivery is recorded as UNVERIFIED** for this ticket: the only
observation of sample arrival is the `RestAlarm` "sample tick" log at debug level, which needs Console.app streaming
from the phone with debug messages on — offered to the user as optional, not required. The Live Activity not
updating while minimized is noted as a pre-existing gap for later (not fixed here).

**Installed `fd88791` (2026-10-13, retry over USB):** app closed (successful process query, no app process;
`procs4.txt`); `devicectl device install` **exit 0** (`install4.log`, `install4.status`), the same `dd-device`
product as `device3.*`. The phone check runs on this build.

## Codex review 01b — clear (round 4)

[codex-review-01b-bgmode-d.md](../codex-review-01b-bgmode-d.md): clear — R3-P1 resolved; no open findings. It clears
the code and documentation, not installation, phone acceptance or upload readiness. The ticket's original pre-upload
requirement that heart rate keeps updating while locked is **not satisfied** by retention evidence: before the upload
the user either observes live delivery (Console.app) or accepts it as unverified.

## Phone check — passed (the user, 2026-10-13)

On the installed `fd88791`, the corrected check above (beep while minimized and locked, 3+ minutes locked after it,
AirPod out/in after a beep, the next rest, another app in front). The user's report, verbatim: "it works. You don't
have to accept it as \"not verified\". it's verified." Recorded as the user's verification of the phone check and of
heart rate continuing while locked; the observation method for heart rate was not stated, and Claude collected no
`RestAlarm` log of its own. The earlier build's report ("it works"; heart rate kept updating during a rest with a
sensor on, "Yes") is kept above. Pre-existing and still open: the minimized Live Activity's heart-rate number gets no
recurring update (R3-P1), a later ticket.
