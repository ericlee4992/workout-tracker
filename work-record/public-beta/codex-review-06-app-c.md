# Ticket 06 — app-half review, round 3

Reviewed 2026-10-14 on `ericlee4992/beta-06-ai-proxy-app`, HEAD
`fa75a8894c69e78db93b777ee12cf86c10c5fd40`, using `git diff 2149588..HEAD`, the round-3 prompt,
round-2 findings and ticket response. Standards and Spec were reviewed separately. No builds, simulators,
devices or deployed requests were run. Only this report was written by this review. A concurrent edit to
the round-2 report appeared during review; it was left untouched.

## Standards

### C1 — P3: Synchronize the session-race tests with response delivery

`WorkoutTrackerTests/AIServerClientTests.swift:246–267` claims the old 401 arrives after `tok-2` replaces
`tok-1`, but its fixed 500 ms responder delay does not establish that ordering. Sign-in can finish after the
refusal; all assertions still pass if the refusal was processed during the signed-out interval. The responder
blocks inside `AIStub.startLoading` (`:372`), rather than holding an asynchronously releasable response.

Gate the old response until sign-in has succeeded, then release it and await completion processing before
asserting the replacement survived. Likewise, `aWeekWhoseSessionEndsWhileOutIsDropped` (`:208–220`) should
observe request start and completion rather than assume them after 150/900 ms: an outstanding request can
satisfy its nil-result assertions. These tests now use a real account and exercise more than direct cancellation,
but they do not reliably establish the exact interleavings claimed in their comments and the ticket.

`aWeekForTheCurrentSessionLands` (`:224–232`) does wait for and assert an actual preview, so its positive-control
claim is supported. The first half of the refusal test (`:237–244`) also meaningfully checks that the model
records the bound refused token, although it obtains the signed-out error from a nil client rather than HTTP.

No other Standards finding. The shared binding removes the inconsistent per-flow identity handling, its comments
match its callers, and the selected five-suite UI rerun remains proportionate under DEVELOPMENT.

## Spec

**B1 and B2 are closed in the production code.** No further defect was found in the synchronous binding or
captured-token invalidation changes. One scan recovery issue remains in the touched lifecycle.

### C2 — P3: Scan retains its expired-session error after successful sign-in

`WorkoutTracker/Features/Gyms/IdentifyEquipmentSheet.swift:330–331` invalidates the captured session, stores
“Sign in to use AI.” in `identifyError`, and sets `busy = false`. The token-change hook at `:167` consequently
skips cleanup. This path occurs with the expired-session fixture and can occur in production when the catch
runs before the transport's queued invalidation callback.

After successful sign-in, the sheet's dismissal calls only `start()` (`:157`, `:270–273`), which does not clear
the error. With the account ready, `step` selects `.error` at `:78`, telling the now-signed-in person to sign in
again. Retake recovers, so this is misleading recovery rather than a blocked flow. Clear the expired-session
error when sign-in succeeds, or avoid retaining it when the sign-in step handles that refusal. Cover expiry,
successful sign-in, and the resulting usable scan state. The existing expired-session UI test stops at the
first Sign In step. This is the same current-code issue added concurrently as B3 in the round-2 report;
the new binding does not resolve it.

### B1/B2 closure and regression checks

- `AISessionBinding.bind` (`TerraAccess.swift:11–13`) captures the account token and compares it synchronously
  on the main actor. The sole production routine-generation caller (`AIRoutineSheet.swift:191–192`) passes
  `.bind(account)`; scan and New Model bind the same account used to obtain their clients. No production
  routine caller falls through to the test-only `.unbound` default.
- Both scan branches (`IdentifyEquipmentSheet.swift:324/328`) and routine branches
  (`AIRoutineFlowModel.swift:144/151`) check the binding before publishing results or errors. New Model checks
  it before switching over either outcome (`ModelPicker.swift:775`). There is no suspension between these
  checks and their result writes, so a deferred view hook is no longer the only protection.
- Refusals name the captured token: scan `:330`, New Model `:786`, and routine `refusedSession` at `:154`
  consumed by `AIRoutineSheet.swift:114–115`. Even if another session appears before that observer runs,
  `AccountStore.invalidate(token:)` compares the refused token with the current token; it cannot invalidate
  the replacement merely because it is current.
- New Model clears `proposing` before dropping a stale response (`ModelPicker.swift:772–775`). Scan's retained
  token hook invokes `cancel()` and clears `busy`; routine's hook invokes `cancelGeneration()`, cancels stage
  work and returns a generating flow to Equipment. A response dropped before those hooks run can briefly
  leave the old progress state, but the attached hooks still perform cleanup. No permanently stuck
  production busy/generating state was found.
- An unchanged token passes the binding, including the supported nil-token UI fixture. The current-session
  unit test confirms a valid routine reaches preview. Existing task/request guards still reject dismissal
  and superseded-request completions. Validation, consent, manual paths and confirmation are unchanged.

### Evidence inspected

Artifacts under `/tmp/wt-floodlight/results/06app/` were read directly:

- `build5.log`: **TEST BUILD SUCCEEDED**, using `dd-06app-c`.
- `unit4.log`: **TEST EXECUTE SUCCEEDED**. `unit4.xcresult`: **992 passed, 0 failed, 0 skipped**.
- `ui3.log` identifies the fixed-build run of FloodlightAIAccess, FloodlightAIRoutine, FloodlightScan, AskAI and
  FloodlightSettings, using `test-without-building`, `dd-06app-c`, and three workers. At
  **2026-10-14 03:33 EDT**, `ui3.status` was absent and the log/bundle had no completed test summary.
  UI verification is **pending**, not passed. `ui2` was stopped unfinished and supplies no passing gate.

The phone's live smoke remains open. This review does not claim installation or repeat deployed checks.
Standards: **1 P3 finding**. Spec: **1 P3 finding; B1 and B2 closed**. No P1 or P2 findings remain in this review.

Verdict: not clear
