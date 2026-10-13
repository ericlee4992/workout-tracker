# Codex review — public beta 01b, round 3

Reviewed `git diff efb96d4..HEAD` on `ericlee4992/beta-01b-background-mode`, including the
latest install-record corrections through `110ed0b433c8e6fc1fc5697dc6747eb9c6458114`.
Product/test change: `fd88791`; subsequent commits contain the prompt, evidence and its corrections.
No builds, tests, simulators or device operations were run. Existing result bundles and build/install
artifacts were read. Only this report was written.

The completion implementation and its identity fix are clear. One acceptance-plan issue remains:
the minimized Live Activity is not wired to receive recurring heart-rate updates, so it cannot
serve as the proposed sole observation of live sample delivery. The failed install is now recorded
correctly and is not a new code finding.

## Standards

**R2-S1 resolved.** The ticket now includes a route change after the completed beep, no duplicate
beep, and a subsequent rest. This exercises the changed deadline state used by interruption/route
recovery. The earlier claim that this state handling was not unit-testable is corrected.

**S2 resolved in the latest handoff.** The ticket supplies the exact artifact root, test results,
built revision and failed installation result. Commits `905139a` and `110ed0b` correct the premature
success claim in `f5ef000`. The current facts are **`fd88791` built, installation failed; phone still
on `7af1445`**. Phone acceptance of the newest code requires a later successful install.

The tests and ticket honestly distinguish direct completion-handler tests from actual delegate
delivery. The loop-playing assertion is conditional on audio-session activation, and the ticket
discloses that limitation. No new documented-standard violation found.

## Spec

**R2-P1 resolved.** `TrackEndObserver` now captures the actual `AVAudioPlayer` in the main-actor
task (`RestAlarmSound.swift:370–373`), keeping it alive until the handler compares it with the
current track using `===` (`:244–245`). An old object's address cannot be reused while this
reference survives. The retained delegate and weak alarm capture do not introduce a retain cycle.

The current track clears itself and its deadline, then restarts the loop only in an open session.
Replacement, cancellation and teardown leave a different or nil scheduled player, so a stale
completion returns without mutating the successor or reopening audio. Standalone `sound()`
still uses its separate player; early recovery cancels the scheduled track before sounding.
Interruption rebuilding can replace a track safely under the new identity check.

The four `QueuedTrackCompletionTests` cover ordinary completion, stale completion after replacement,
cancellation and ended session (`RestAlarmTests.swift:321–362`). They test the real handler's state
transitions directly. They do not exercise the asynchronous delegate hop or natural playback
completion; source inspection establishes the retention fix, and the phone check must establish
actual background behavior. No new product-code defect found in this round's change.

### R3-P1 — P2: Use an observation path that survives minimizing the workout

**R2-P2 remains open.** Ticket lines 90–92 and 100–103 replace the saved-chart check with a
requirement that the Live Activity HR number keeps changing for 3+ minutes while the workout
is minimized and the phone locked. That would be useful positive evidence if updates were sent,
but the current source does not supply recurring updates on this path:

- Minimize removes `ActiveWorkoutView` by setting the full-screen cover item to nil
  (`RootView.swift:88–93`).
- Recurring `pushActivityState()` calls belong to that view's `.onReceive(livenessTick)`
  (`ActiveWorkoutView.swift:428–431`); the initial push and rest/command changes also live there.
- The surviving coordinator's sample callback checks the alarm, refreshes cardio and forwards
  `onSample` (`WorkoutHeartRateCoordinator.swift:128–135`). Its installed view callback only
  calls `evaluateHeartRateRest()`, not `pushActivityState()` (`ActiveWorkoutView.swift:414`).
- The other production `activity.show` call is after an explicit Lock Screen command
  (`WorkoutActivityCommands.swift:129–135`). `WorkoutActivityController.show` forwards supplied
  state; it has no independent HR subscription or update timer (`WorkoutActivityController.swift:54–74`).

Consequently, a frozen number in this test can mean no Live Activity publication even while
the app receives samples. The plan risks sending the user through a test that cannot reach its
expected pass condition for an unrelated reason. Pressing Lock Screen commands to refresh the
number would also confound an unattended-continuity check.

Correct the acceptance plan to observe actual sample arrivals during the locked/minimized
post-beep interval—for example, collect the existing `RestAlarm` sample-tick logs without an
attached debugger and correlate them with readings—or document another observation path after
verifying its callers. Keep the saved chart as retention evidence only. If timely delivery cannot
be observed, leave it explicitly unverified. The missing minimized Live Activity publisher is
pre-existing; this ticket need not expand into a product fix for it merely to obtain evidence.

The narrowed lifting, post-beep route-change and next-rest checks remain proportionate. The issue
is the observation method, not a demand to rerun the full cardio/HR-recovery matrix. Pending
installation and phone acceptance alone are not reasons to reject the code.

## Evidence inspected

Root:
`/private/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-public-beta/0dc39eb1-054d-49da-bf79-784fabae4a4e/scratchpad/bm/`

- `unit3.status`: `exit=0`; `unit3.log`: `** TEST SUCCEEDED **`, selecting the five named suites.
  Read `unit3.xcresult` with `xcresulttool`: **31 passed, 0 failed, 0 skipped**, WT-Floodlight,
  iOS 27.0. The four `QueuedTrackCompletionTests` individually report Passed. The result includes
  warnings about synchronous AVAudioSession activation/deactivation on the main thread; these
  originate from the existing real-audio methods exercised by the new tests, not new failures.
- `device3.status`: `build=0`; `device3.log`: `** BUILD SUCCEEDED **`. The existing device product's
  plist has `["audio", "location"]` and the HealthKit/camera usage strings. Its dylib exports
  `scheduledTrackFinished` with an `AVAudioPlayer` argument, confirming the new identity fix is built.
- `install3.status`: **`install=1`**. `install3.log` reports a CoreDevice tunnel failure and operation
  timeout. It is not a successful installation receipt. `procs3.txt` lists no main app process;
  it does list the widget from the previously installed bundle `06C09C19-C26C-47DC-AF0E-84924049EB57`.
  This is consistent with the corrected ticket and the user's statement that the phone still runs
  `7af1445`. No phone query or installation was attempted by this review.

Standards: 0 open findings. Spec: 1 P2 finding, the remaining R2-P2 acceptance-observation gap.
Actual phone acceptance and upload validation remain pending.

Verdict: not clear
