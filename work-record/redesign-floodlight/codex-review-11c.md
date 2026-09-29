# Ticket 11 — independent Codex review, round 3

**Not clear: 1 high, 1 medium, 1 low finding.** Reviewed `ede5583..d1a5e50`
(`d1a5e50c35842c931912796139dd50a7ad402047`) on
`ericlee4992/redesign-floodlight-system`, in `/tmp/wt-floodlight/system`, following
`codex-review-11c-prompt.md`. Claude implemented; Codex reviewed.

## High

### 1. Resume still returns before its provider configuration finishes

**`WorkoutTracker/Features/ActiveWorkout/WorkoutActivityCommands.swift:67–72`**

`coordinator.ready()` awaits only the monitor's initial `startTask`
(`WorkoutHeartRateCoordinator.swift:288`). Pause/Resume schedules different work:
`CardioRecorder.sync` launches an untracked task that awaits `provider.configure`
(`CardioRecorder.swift:131–135`). Neither `ready()` nor the card's `settle()` awaits
that task.

Concrete case: reopen the app with a paused cardio segment and let the runtime finish
attaching. `WorkoutActivityProvider` completes startup without a current provider for
this paused segment (`WorkoutActivityProvider.swift:110–113`). Minimise and press
Resume on the card. The store and clock switch to running, but the new HealthKit
provider starts asynchronously; the initial `startTask` has already completed.
`handle` can return while that new provider is still awaiting authorization or
collection startup, allowing suspension before recording is established. H1's Watch
replay is fixed, but its sensor-readiness requirement remains incomplete.

Await the configuration caused by the command as well as initial attachment. The
injectable provider factory makes this testable without hardware: suspend a fake's
startup after an already-attached paused state, and assert that `handle(.resumeCardio)`
does not finish until that startup completes. The current pause/resume test still
uses the no-op attachment helper and direct store fallback; the new real-attachment
test exercises only +15s/Skip with a fake whose startup never suspends.

## Medium

### 2. Initial attachment can erase the expiry result restored on appearance

**`WorkoutTracker/Domain/WorkoutHeartRateCoordinator.swift:86–88`**

The reset also runs on the first attachment, when `workoutID` is nil. The live screen
has two independent initialization callbacks: `onAppear(refreshRest)` at
`ActiveWorkoutView.swift:367`, and monitor attachment in `.task` at line 375.
When appearance restoration runs first after a cold relaunch with an expired rest,
`refreshRest` saves its inferred result to the coordinator and clears the persisted
dates (`921–925`). Initial monitor attachment then erases that same workout's result;
the subsequent activity push can no longer reconstruct it. The card loses the result
before another set is completed.

Order attachment before expiry restoration in one lifecycle path, or associate the
rest facts with a workout identity so initial attachment preserves facts already
restored for that workout. The two-workout test verifies replacement and teardown,
but not restoration before first attachment. This is a source-level ordering hazard;
no runtime reproduction was performed in this review.

## Low

### 3. The revised alarm bound can accept an unextended alarm

**`WorkoutTrackerTests/WorkoutActivityContentTests.swift:325`**

The assertion now bounds the queued delay using the entire awaited `handle` interval,
including provider startup after the beep was queued. Under the delay this change
was intended to tolerate, it stops proving that the alarm moved by 15 seconds.
For example, with 80 seconds initially remaining and a 60-second `handle`, it accepts
approximately 34.5–95.5 seconds, including an incorrect original 80-second delay.
The actual `sys-unit-23.log` records this case taking 60.890 seconds.

Record the timestamp when the fake receives `scheduleBeep` and compare its computed
deadline with the extended rest end, or inject a controlled clock. The store/card/Watch
assertions do not independently prove the audible alarm's deadline.

## Fixes and verification checked

- Provider replay now reads the latest stored deadline after startup, replays only a
  future deadline, and preserves ordinary immediate forwarding. Explicit cancellation
  replaces the stored deadline with nil. The inspected startup/phase-switch paths do
  not replay a superseded or elapsed rest.
- The fallback-clearing defer preserves the current rest through drop completion and
  unrelated uncompletion, then clears the marker when that rest disappears or changes
  its initiating set. The reported round-2 fallback regression is fixed.
- Same-workout monitor reuse preserves rest facts; replacement and teardown reset them.
  The reported cross-workout leak is fixed, subject to the initial-restoration issue
  above. `settled()` waits for startup and banking for the new tests' cleanup paths.
- Actual exit files and existing xcresult summaries were inspected: `sys-ui-21` exit 0,
  51 passed / 0 failed / 0 skipped; `sys-ui-22` exit 65, 942 passed / 1 failed / 0 skipped
  (unit 904/905, UI 38/38; the sole failure was the previous alarm timing assertion);
  `sys-unit-23` exit 0, 905 passed / 0 failed / 0 skipped. The recorded evidence matches
  the ticket. Focused configuration-readiness and initial-restoration regressions are
  needed; a blanket UI rerun is not requested.

No `xcodebuild` or `simctl` commands were run. The checkout was clean at the start;
only this report was written. **Independent clearance remains pending.**
