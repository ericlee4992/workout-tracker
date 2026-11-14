# CI and T6 — Codex review, round 3

Reviewed 2026-11-14 on `ericlee4992/ci-and-t6`, HEAD
`e33966f1ce475cb273cece351c4b156388797bff`, diff `6f8a9d52..HEAD`. Starting checkout was clean. The functional
change is test-only commit `f6d76f08`; the subsequent commits add the brief and handoff. Only this report was
modified. **This verdict was written after the independent build and test run finished.**

## Standards

No findings. The one-hour fixture preserves every assertion about command delivery, +15-second extension,
provider startup/replay, Skip, cancellation and runtime reuse. Those cases require a rest that remains running,
not a 90-second duration. Explicit expired-rest cases retain their own timestamps and assertions. Production code,
test selection and CI time limits are unchanged.

## Spec / diagnosis

No findings. Independently read the failed [CI run 43590959069](https://github.com/ericlee4992/workout-tracker/actions/runs/43590959069)
and its `xcodebuild-log` artifact. It failed exactly the two named assertions, with test durations of 338.310 and
338.397 seconds.

The cold-command failure has direct timestamp evidence for expiry. For the same test workout, the log records:

| Event | UTC |
|---|---|
| Add Fifteen applied | 11:47:35.609 |
| Resulting rest deadline | 11:49:10 |
| Skip command received | 11:50:42.419 |

Skip arrived about 92 seconds **after** the extended deadline. `WorkoutActivityCommands.perform(.skipRest)`
intentionally returns without broadcasting nil once `end <= .now`. The failed Watch expectation therefore assumed
a running rest after its fixture had expired; it is not evidence that an applied Skip was lost or reordered.

The provider failure is consistent with the same cause: only the new phase's replay assertion failed, after the
earlier startup assertion succeeded. `WorkoutActivityProvider.configure` awaits its queued transition;
`applyDesired` awaits provider startup, then replays only when `restEndsAt > .now` before returning. The test crosses
asynchronous scheduling boundaries with a 90-second deadline. No ordering defect was found in that path. Its log
does not independently timestamp that private deadline, so the provider diagnosis is supported by the code and
failure pattern rather than the direct deadline comparison available for the cold-command case.

The changed default is 3600 seconds total (3590 seconds initially remaining in `startRest`), and the provider test
uses `now + 3600`. Both outlast the workflow's 25-minute step cap and 600-second per-test allowance. `RestTimerService.add`
extends without clamping; these tests do not assert a 90-second total or use the configured 240-second heart-rate
cap as their actual deadline. The tests still fail if delivery/order/replay is broken while the rest is running.

I did not inject a multi-minute stall or edit tests to reproduce the old fixture locally: the diagnosis uses the
recorded failing CI execution, source tracing and the independent run of the unchanged assertions with the fix.

## Other expiry-sensitive tests audited

No additional test was found combining all three conditions of this failure: a short future wall-clock rest,
an asynchronous suspension, and a later assertion requiring that rest still to be future. Related cases include:

| Tests | Why they do not share this failure mode |
|---|---|
| `RestTimerTests.completionReplaceAddAndSkipRescheduleOneTimer`, `relaunchMidRestReconstructsFromAbsoluteEnd`, `returningAfterTimerEndClearsStalePersistenceAndNotification` | Fixed/manual clock; elapsed time is advanced explicitly. |
| `HeartRateRestTimerTests.recoveringEndsTheRestEarlyAndSaysSo`, `switchingModeMidRestLeavesTheRunningRestIntact`, and the other duration/cap cases | Controlled clock, not elapsed CI wall time. |
| `RestAlarmOwnershipTests.theSecondRestOfAWorkoutIsArmedToo` | Synchronous MainActor arm/assert sequence; no async queue gap after deadline creation. |
| `ScheduledRestBeepTests.startingARestQueuesTheBeepImmediately`, `aHeartRateCapIsQueuedLikeAnyOtherDeadline`, `extendingARestRequeuesForTheNewDeadline`, `skippingARestCancelsTheQueuedBeep`, `recoveringEarlyCancelsTheQueuedCapBeep` | Synchronous MainActor sequences with the silent alarm. |
| `ScheduledRestBeepTests.theExecutingFallbackDefersToTheQueuedTrack` | Its one-second deadline is armed synchronously; evaluation receives an explicit simulated time. |
| `QueuedTrackCompletionTests` | Completion is invoked directly and assertions concern ownership/state, not a future rest after awaiting startup. |
| `RestNotificationSchedulerTests.aSlowRemovalDoesNotDelayTheNotificationPastTheRestsEnd`, `aDeadlineAlreadyPassedStillNotifiesASecondLater` | Controlled clock for interval assertions. |
| `RestNotificationSchedulerTests.callsReachTheCenterInCallOrder`, `theCallerIsNotKeptWaitingForTheCenter` | Order/count/nonblocking assertions do not require the supplied deadline to remain future. |
| `WatchRestMirrorTests.theCoordinatorForwardsToTheRunningSession` and other Watch wire/mirror cases | Fixed dates are forwarded without an expiry check. |
| `WorkoutActivityContentTests.phaseFollowsTheRestAndTheStaleDate`, `aRestThatRanOutUnobservedSaysHowItEnded` | Explicit `now` inputs. |
| `WorkoutActivityContentTests.aCommandOnARestThatRanOutKeepsHowItEnded` | Intentionally past deadline; additional delay does not turn it into a running rest. |
| `WorkoutActivityContentTests.resumeOnTheCardWaitsForTheSensorsToStart` | Tests continuation gating, not a short rest remaining future. |

This is a check for the observed rest-expiry pattern, not a claim that every wall-clock tolerance in the suite is
immune to arbitrary process suspension. The other `startRest` callers also receive the longer fixture; none of their
assertions depends on its old duration.

## Verification

Used only WT-Redesign-2 `EB4328A1-87BD-4850-A3B2-A6E604701F1C`, prepared before build/tests; derived data
`/tmp/wt-ci-codex`; evidence root `/tmp/wt-ci-review-r3/`.

- Independent `build-for-testing`: **exit 0**, `build.log` / `build.exit`.
- Independent Unit plan restricted to `WorkoutActivityContentTests` and `WorkoutActivityProviderTests`:
  **21/21 passed**, no failures/skips, **exit 0**, `activity.xcresult`, `activity.log`, `activity.exit`.
  Inspected the actual xcresult summary and process exit files.
- Author's `build/results/r3-activity.xcresult`: inspected, **21/21 passed**, no failures/skips.
- `git diff --check 6f8a9d52..HEAD` and test-plan consistency check: passed.
- Downloaded failed-run artifact under `failed-ci/`; read GitHub run logs directly as well.
- [New branch run 43592530127](https://github.com/ericlee4992/workout-tracker/actions/runs/43592530127), targeting
  `f6d76f08`, was **still in progress at the final check**. No workflow/test changes occurred after that commit.

Verified: independent build and 21 affected tests; failed CI evidence; expiry/ordering analysis; wider rest-test
          audit; unchanged assertions and app code.
Not verified: new hosted run completion; post-merge main run; a forced multi-minute local reproduction; full local
              Unit/UI suites this round. No UI code changed, so no UI run was needed.
Known flaky: the failed hosted run's short-lived rest fixtures are the issue addressed here; the new hosted result
             still needs checking before merge. No failure occurred in the independent local run.

Standards: 0 findings. Spec: 0 findings. Code review is clear; read the pending hosted run before merging, then
verify the main-branch run as STATE directs. No pushes or workflow dispatches were performed by this reviewer.

Verdict: clear
