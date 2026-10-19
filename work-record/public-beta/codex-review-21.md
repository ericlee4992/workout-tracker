# Codex review — ticket 21

Reviewed 2026-10-18 as Claude's independent reviewer: `git diff c3952da..67de6eb`.
Branch `ericlee4992/beta-19-bug-fixes`, HEAD `3e6115035633b826a3be7c8112c92c92656e9fb9`.
The later commit only records the ticket status/review SHA; tested application and test sources
match `67de6eb`. Working tree was clean. Read the ticket, D46, Floodlight ticket 11 and its
command/recovery contract, AGENTS.md and the relevant callers.

## Standards

The independent standards pass identified the same two lifecycle problems described below.
No additional schema, dependency or code-convention findings. The presenter boundary remains
injectable, and the patch restores existing behavior rather than adding a public capability
requiring a new README description.

## Spec and lifecycle findings

1. **P2 — Permanently suppressing the card precedes successful workout termination.**
   `WorkoutTracker/Domain/WorkoutActivityController.swift:95` inserts the ID into `ended`, and
   `show` at `:69` will reject it for the rest of the process. However,
   `ActiveWorkoutView.swift:830`, `:841` and `:869` call `stopHeartRate()` (which calls this end
   method at `:674`) **before** the throwing finish, templated-finish or cancel operation.
   **Failure scenario:** the save in `RestTimerService.skip` (`RestTimer.swift:317`) throws.
   Both `WorkoutSession.finishInPlace` (`WorkoutSession.swift:155`) and `cancel` (`:136`)
   invoke it before setting `finishedAt` or deleting the workout, so the workout remains live.
   In Release, the existing catch/dismiss behavior lets the user return to and resume it;
   the new permanent rejection then prevents its card from ever reappearing until process
   restart. Template resolution can likewise throw before finishing. The existing error UI
   is not introduced here, but the permanent inability to restore the card is.
   **Fix:** separate sensor banking from final card termination, and commit permanent
   suppression only once termination succeeds; alternatively, explicitly restore eligibility
   on failure while retaining protection against late pushes after successful termination.
   Add a failed-finish/cancel followed by resume regression.

2. **P2 — Recovery errors are treated as proof that no live workout exists.**
   `WorkoutTracker/App/RootView.swift:130` uses `try? resumableWorkout()`, then the new branch
   at `:133` sweeps all cards whenever the result is nil. **Failure scenario:** fetching
   active workouts fails, or cleaning up an older stray fails saving while the newest workout
   is still live (`WorkoutSession.swift:88–97`). The error becomes nil and the valid workout's
   card is removed. If a background lock-screen command already adopted that workout into
   the shared controller, `endAny()` also permanently suppresses its ID. This violates the
   requirement that recovery preserve a live workout's card.
   **Fix:** use `do/catch` and sweep only after recovery successfully returns nil. Preserve
   the card on an error; add coverage distinguishing successful absence from recovery failure.

These findings follow directly from the error paths and caller ordering; save/fetch failures
were not independently fault-injected during this review.

## Other review results

- The reported cancellation cause is consistent with the source: cancellation ends the card,
  deletion clears rest state, and the still-visible screen has both the rest-change push and
  the two-second tick. Claude's `21-probe.log` records `isDeleted=false`, `finishedAt=nil`,
  `modelContext=nil` after cancellation. I inspected the unfixed `shots21r/21-after-cancel.png`,
  which shows the remaining Lateral Raise card. The new context guard and ended-ID protection
  prevent the successful-cancel late push.
- Ordinary minimize does not end the card; successful finish/templated finish/cancel do.
  “Finish It & Start New” replaces the old card when the new workout calls `show`; that
  replacement remains unchanged. A command arriving after a successful end fetches the
  workout and rejects missing/finished records before runtime attachment or another push.
- A stale end ID leaves a different **tracked** workout alone. With nothing tracked, the
  explicit sweep runs. `endAll()` captures existing activity handles and the just-requested
  tracked handle synchronously before its Task; a subsequently requested different workout
  is not in that captured set. No additional new-workout ordering defect was found.
- Successful launch recovery with a live workout does not sweep; the guided-tour guard exits
  before recovery/sweeping. The new sweep is wired to RootView appearance, not a separate
  scene-phase foreground callback. Finding 2 concerns the error case.
- By comparison with the base controller, the two late-push tests and empty-tracking sweep
  test expose missing behavior. The next-workout test would already pass before this fix and
  appropriately checks compatibility. This comparison was static, not a mutation-test run.
  The UI test asserts a card exists before cancellation and checks the whole activity container
  afterward, so it detects a reposted card without rest buttons. Neither new suite covers the
  two error paths above.

## Independent verification

Both commands used `WorkoutTracker.xcodeproj`, scheme `WorkoutTracker`, SDK `iphonesimulator`,
destination `platform=iOS Simulator,id=9E822EF6-DC67-4958-AEA2-D53D2D36D674`, and
`-derivedDataPath /tmp/codex-21/DerivedData`.

| Check | Result | Evidence |
|---|---|---|
| `xcodebuild … build` | **Exit 0; BUILD SUCCEEDED** | `/tmp/codex-21/build.log`, `build.status`, `build.xcresult` |
| `xcodebuild test … -parallel-testing-enabled NO -collect-test-diagnostics never -only-testing:WorkoutTrackerTests/WorkoutActivityTests -only-testing:WorkoutTrackerTests/WorkoutActivityProviderTests -only-testing:WorkoutTrackerTests/WorkoutActivityContentTests` | **Exit 0; 34 passed, 0 failed, 0 skipped; TEST SUCCEEDED** | `/tmp/codex-21/unit.log`, `unit.status`, `unit.xcresult` |
| `git diff --check c3952da..67de6eb` | **Exit 0** | No whitespace errors |

Inspected the actual exits, status files, success markers and xcresult summary: WT-Floodlight,
iOS **27.0**, no runtime warnings. `WorkoutActivityCommandsTests` does not exist and was omitted
as instructed; command tests reside in the executed `WorkoutActivityContentTests` suite.

**Independent UI tests skipped.** Inspected Claude's `21-ui-1.xcresult` and log: three tests
repeated three times, **9 successful runs**, zero failures/skips, `TEST SUCCEEDED`, recorded
exit **0**. These are the warm-up, real-card commands and real-card cancellation tests.
Separate manual finish and minimize→cancel checks were not independently performed; the phone
check remains deferred to the user on build 9.

Author evidence root:
`/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-beta-19-bug-fixes/5c90b802-2d0b-4541-a832-afac14d838e8/scratchpad/runs/`.

Only this report was written. No commit or push.
Both review axes corroborate **2 P2 lifecycle findings**, counted once above.

Verdict: not clear
