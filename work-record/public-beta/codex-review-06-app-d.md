# Ticket 06 — app-half review, round 4

Reviewed 2026-10-14 on `ericlee4992/beta-06-ai-proxy-app`, HEAD
`ee8485b3aebf48dc5fa682786ada70aab4d0fbc5`, using `git diff 8ec380e..HEAD`, the round-4 prompt,
round-3 report and ticket response. Standards and Spec were reviewed separately. The working tree was clean
at entry. No builds, simulators, devices or deployed requests were run. Only this report was written;
earlier reports were left untouched.

## Standards

**No findings. C1 is closed.**

The race tests now establish the ordering they claim:

- `WorkoutTrackerTests/AIServerClientTests.swift:208–223`: the success response is held until
  `Gate.untilHeld()` confirms arrival and the account has been invalidated. The test then releases the
  response and awaits `generationFinished()` before checking that nothing landed.
- `WorkoutTrackerTests/AIServerClientTests.swift:249–273`: the old 401 remains held while the account signs
  out and completes sign-in with `tok-2`. Only after asserting the replacement token does the test release
  the refusal, await generation completion, and verify the replacement survived without a stale error.
- `Gate` and the asynchronous stub delivery (`AIServerClientTests.swift:335–346`, `:385–400`) allow the
  sign-in/profile/usage requests to finish while the old response is held. The tests no longer assume that
  elapsed time proves arrival or completion. `AIRoutineFlowModel.generationFinished()` (`:163`) awaits
  the retained generation task; neither test invokes the view's cancellation hook or clears that task.

The current-session positive control remains in place. The focused recovery UI tests are appropriate for
the changed scan branch and fixture hook; the broader targeted run remains a separate verification gate.

## Spec

**No findings. C2 is closed; no regression found in the reviewed changes.**

`WorkoutTracker/Features/Gyms/IdentifyEquipmentSheet.swift:292` clears the previous error before a request.
The refused-session branch at `:331–334` now invalidates only the captured token, clears busy/photo state,
and returns without storing “Sign in to use AI.” Successful sign-in therefore returns to a usable camera
instead of the stale error step. If transport invalidation wins the race, the existing session guard and
token-change cancellation still discard the result and clean up the active request.

`testSigningInAfterARefusedSessionMakesAIUsable` exercises expiry → Sign In → camera without the stale
error → successful identification. It separately exercises routine expiry → Sign In → Generate week →
generated week. The first-request-only refusal resets with each app launch. B1/B2's synchronous result
checks and captured-token invalidation remain intact.

The sample sign-in cannot modify a production account:

- `ProfileSample.signsInAtOnce` (`ProfileSample.swift:13–20`) requires both `-uiTestReset` and
  `-uiTestSampleSignIn`; the latter flag alone does not enable it.
- Its sole caller is `AccountSignInSheet` (`SignInViews.swift:127–130`).
- `AccountStore.completeSampleSignIn()` (`AccountStore.swift:179–182`) additionally requires `sample`.
  The private sample constructor is reached only through the reset branch of `forThisApp()` (`:68–84`);
  ordinary account construction sets `sample = false`.
- The sample store has no network client and inert token storage. The hook updates only its in-memory
  token/profile. The `ExpiredOnce` response is reached through fixture-delay callers gated by
  `TerraAccess.fixture`, which requires `-uiTestTerra` together with `-uiTestReset`.

### Verification evidence

Read directly under `/tmp/wt-floodlight/results/06app/`:

- `build6.log`: **TEST BUILD SUCCEEDED**, using `dd-06app-d`.
- `unit5.xcresult`: **992 passed, 0 failed, 0 skipped**.
- `ui4.xcresult`: **2 passed, 0 failed, 0 skipped**, WT-iPhone27. The result tree confirms both
  `testRefusedSessionOffersSignIn` and `testSigningInAfterARefusedSessionMakesAIUsable` passed.
- At **2026-10-14 03:54 EDT**, `ui3.status` was absent and the log had no completed test summary.
  The five-class run on the earlier build remains **pending**, not passed. These two focused UI successes
  do not establish that the broader run or its earlier failures have cleared.

This clears the reviewed code and findings, not the remaining verification or delivery gates. The broader
targeted UI result and the phone's live smoke remain open. No installation, merge, deployed check or
resolution of the deferred Workers Free CPU-cap decision is claimed.

Standards: **0 findings**. Spec: **0 findings**. C1 and C2 closed.

Verdict: clear
