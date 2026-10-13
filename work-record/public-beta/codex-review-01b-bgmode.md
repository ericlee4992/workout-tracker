# Codex review — public beta 01b: background mode

Reviewed 2026-10-13, branch `ericlee4992/beta-01b-background-mode`, using `git diff main..HEAD`.
Base: `f952262103b8c00c133af36ef82ec52a72d1dec8`; implementation: `2b8d5fc`; HEAD:
`0c93f3f969c5477bde3b71ec3a22bb1a82afa58f` (adds the review prompt). Working tree was clean.
Read the ticket, SPEC, D41–D46, DEVELOPMENT, archived alarm history, prior alarm reviews,
and current alarm/sensor/lifecycle callers. Standards and spec received separate review passes.
No builds, tests, simulators, device operations, or product edits were performed; only this report was written.

The mode removal implements the approved change. It does **not** establish that audio continuously
keeps this app executing, or that background heart-rate delivery is unchanged. There is an ordinary
post-beep interval with no app audio, and the new comments misstate the historical fix. These need
resolution before clearance; merely having a phone check still pending is not itself a code defect.

## Standards

### S1 — P2: Correct the mechanism and verification claims

`Config/WorkoutTracker-Info.plist:49–53`, `WorkoutTrackerTests/BackgroundModesTests.swift:11–13,43–45`,
`WorkoutTrackerTests/RestAlarmTests.swift:156–160`, and ticket `01b-background-mode.md:20–23`
credit the looping keep-alive with the successful background-alarm fix. The archive's definitive
incident account (`docs/archive/STATE-2026-09-17-before-codex-setup.md:538–558`) explicitly lists
the loop among three insufficient attempts. The successful fourth design queued a finite
`[inaudible interval][beep]` asset **when rest began**, eliminating execution at the deadline.
D46 and DEVELOPMENT's background-alarm guidance preserve that distinction. The archive also
contains older, conflicting causal claims later in the file; those are not stronger evidence than
the final incident account and actual code.

The plist additionally says playing audio keeps the workout session alive, although the ticket
explicitly calls background HR delivery without this mode unknown. “Asserted below” in
`BackgroundModesTests:45`, and the analogous ownership-test comment, overclaim coverage:
the tests inspect plist strings, not playback, continuous execution, or HealthKit callbacks.

Correct these changed explanations to describe queued playback, the loop's intended role outside
rests, and unverified device behavior separately. This follows AGENTS' requirement to verify
comments against callers and DEVELOPMENT/D46's requirement to distinguish scheduled output
from evidence of app execution. No code-smell finding applies to this small change.

### S2 — P2: Record the existing verification artifacts

The ticket's `## Evidence` at line 38 is empty. The review prompt supplies Claude's reported
16/16 unit result, clean device build, built plist inspection, and installation, but no commands,
exit/result artifacts, or installed-product identity for independent inspection. AGENTS requires
verification evidence and artifact paths in the ticket; DEVELOPMENT requires checking actual
results rather than another agent's summary.

Record the existing test log/xcresult and build/install/plist evidence, tied to the code revision
and installed product. This requests preservation and inspection of existing evidence, not a
new build. Keep manual launch, phone acceptance, and successful upload validation explicitly pending.

## Spec

### P1 — P1: The claimed continuous audio dependency has a gap after every completed queued rest

Ticket lines 20–23 justify removal on the premise that “the process stays alive through audio.”
An ordinary lifecycle path contradicts that premise:

1. `SystemRestAlarm.beginSession()` starts the infinite loop (`RestAlarmSound.swift:84–96,121–135`).
2. `scheduleBeep` starts a finite rest track and **stops** that loop (`:205–222`).
   `RestAlarmTone.restTrackWav` appends the beep to the interval and returns; it contains no
   post-beep looping tail (`RestAlarmTone.swift:151–159`).
3. No playback-completion handler restarts the loop. With the workout minimized and phone locked,
   the finite track can end while `keepAlive` remains stopped. The coordinator's deadline check
   records `lastSoundedRestEnd` and either returns while the track is playing or emits another
   finite beep; neither path restores the loop (`WorkoutHeartRateCoordinator.swift:268–279`).
   The HR-rest evaluator also does nothing on `.finished(.cap)` (`ActiveWorkoutView.swift:719–720`).
4. An explicit cancellation/requeue, foreground rest refresh, or route/interruption event can
   restore playback later. None guarantees continuous audio across the unattended post-cap interval.

This gap **predates this diff**. The review does not claim that removing `workout-processing`
causes suspension, or that the rejected mode previously prevented it. It establishes that the
proposed safety argument is incomplete: one successful queued beep cannot prove the ongoing
workout still receives HR samples. Resolve the gap or establish and document the actual
background-delivery mechanism with device evidence covering this interval. Do not restore the
known-rejected plist value as a presumed solution.

### P2 — P2: The changed rationale does not match the historical evidence

The ticket's “fix that held is the looping inaudible track” and the changed source/test comments
conflate continuous runtime with pre-scheduled audio. The relevant evidence and correction are
listed under S1. Under the spec axis, this matters because ticket lines 16–18 require a phone
check that the alarm sounds **and heart rate keeps updating** before upload. A queued beep only
tests the first requirement. The mode removal itself matches the request, and there is no scope creep.

## Execution paths and remaining uncertainty

| Path | What the current source does |
|---|---|
| Lifting before a rest, or after skip/recovery | The shared coordinator starts audio before starting the sensor provider (`WorkoutHeartRateCoordinator:120–150`). The loop is intended to hold the route. Canceling a scheduled track restarts it (`RestAlarmSound:231–239`); early recovery cancels the cap first (`WorkoutHeartRateCoordinator:256–259`). |
| Timed rest / HR cap | The finite pre-rendered track replaces the loop. Its beep needs no Swift execution at the deadline. After completion, the no-audio interval described above is possible. |
| Cardio | Uses the same coordinator and audio session. Starting planned or selected cardio clears the lifting rest and broadcasts `nil`, canceling any track and restoring the loop (`ActiveWorkoutView:73–79,366–369`). `CardioRecorder:105–160` and `WorkoutActivityProvider:91–135` change sensor phases, not the audio lifetime. Pause/resume does not intentionally stop audio. |
| Outdoor vs indoor cardio | Outdoor cardio additionally requests background location updates when authorized (`CardioRecorder:220–227,273–284`). Indoor cardio does not have that location path. Outdoor success alone cannot establish the audio/HR behavior needed indoors or while lifting. |
| Minimize / resume | Minimize dismisses the workout cover without ending the shared coordinator (`ActiveWorkoutView:640–647`, `RootView:88–98`). Resume returns the existing monitor (`WorkoutHeartRateCoordinator:98–100`), so it does not itself call `beginSession` again; foreground rest refresh can separately repair an expired track. |
| Finish / cancel / replacement | Coordinator teardown releases the alarm and stops audio (`WorkoutHeartRateCoordinator:161–208,286–329`). This is intentional. |

Other no-audio cases exist: activation/player construction can fail nonfatally, `play()` success
is not enforced, and interruptions stop playback. The recovery handler tries reactivation and
rebuilds the queued deadline, but this is not proof of successful recovery (`RestAlarmSound:98–105,
121–138,144–185,205–226`). These are existing limitations, not newly introduced regressions.

`HealthKitHeartRateProvider` still starts an iPhone `HKWorkoutSession` and live builder
(`:85–104`), consumes delegate statistics (`:159–189`), and handles session failure (`:228–240`).
There is no replacement background-delivery mechanism added by this diff. No source branch
conditionally requires the removed string; whether delivery remains timely without it is a
device question. Apple's iOS workout presentation distinguishes foreground metric updates from
locked-device data access; locked access permission alone is not evidence that this app's
callbacks execute continuously. [Apple: Track workouts with HealthKit on iOS and iPadOS](https://developer.apple.com/videos/play/wwdc2025/322/).

## What the supplied tests establish

The reported 16 tests correspond to four `BackgroundModesTests` and twelve `RestAlarmTests`:
built-bundle keys, waveform/container properties, and the pure once-only decision. The new
negative assertion is appropriate for the observed upload rejection. These checks do not run
the real background audio/HealthKit lifecycle. `RestAlarmOwnershipTests` and
`ScheduledRestBeepTests` are separate suites in the same file; the reported suite selection
must not be described as having run them without the actual result showing that. Their fake
alarm also cannot establish AVAudioPlayer completion or device suspension behavior.

Claude reports an installed clean device product with modes `["audio", "location"]` and the
usage strings. That is configuration/install evidence, not launch, runtime, or App Store
validation evidence. This review has not independently verified those artifacts.

## Required phone acceptance before upload

Record the installed revision/build, phone/iOS version, sensor and output route, tested intervals,
results, and evidence in the ticket. Manually launch from the Home Screen with **no debugger
attached**. Use the actual HR sensor/AirPods, establish fresh readings first, and resolve any
HealthKit/locked-data permission prompts before the test. Keep media volume audible.

1. **Timed lifting rest:** complete a set, lock the phone promptly, and hear the actual cap
   pattern through the intended audio route at the deadline. Repeat after minimizing the workout
   inside the app, and with another app foregrounded. Check another rest in the same workout.
   A notification, vibration, or ticking system countdown is not a pass for audible playback.
2. **After the beep:** leave the phone locked and workout minimized for several minutes after
   the queued track finishes. Verify HR delivery throughout this interval as well as before/during
   the rest. Also cover a period with no rest queued, to exercise the loop by itself. Avoid using
   other music as the only test condition; repeat in the user's normal music setup too.
3. **HR rests:** observe an early recovery tone before the cap and no later cap tone for that
   rest, then a separate rest that reaches its cap. Test locked/minimized behavior, and confirm
   the UI's recovered/capped/fallback result after returning. A cap alone does not prove threshold
   evaluation or live sample delivery.
4. **Cardio:** run indoor cardio with the phone locked for several minutes, including minimize,
   pause/resume, and lifting → cardio → lifting transitions. Check sample continuity while running;
   paused HR behavior need not look like active recording. Separately check an outdoor segment
   and its background route if claiming outdoor acceptance—GPS must not mask the indoor case.
5. **Interruption recovery:** interrupt an active rest with a call/Siri or an audio-route
   disconnect/reconnect; end the interruption before the deadline and check the remaining-time
   beep, subsequent rest, and HR resumption. Finish/cancel and confirm no leftover rest beep.

For HR, capture evidence that distinguishes **measurement timestamps** from **callback arrival
times**. The saved graph spanning the locked interval helps verify retained data, but can conceal
delayed delivery; a fresh number immediately after reopening can do so too. Existing device
`RestAlarm` sample-tick logs can establish execution during the locked interval if collected
without attaching a debugger, correlated with sensor/record timestamps or observed live updates.
If such evidence is unavailable, report timely background delivery as unverified rather than
inferring it from the beep or a post-unlock value. A pass establishes the tested configuration,
not a universal continuous-runtime guarantee.

Standards: 2 findings (highest P2, inaccurate claims / missing evidence). Spec: 2 findings
(highest P1, unaddressed post-beep audio gap); S1 and spec P2 describe the same issue on separate axes.

Verdict: not clear
