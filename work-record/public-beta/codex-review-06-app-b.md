# Ticket 06 — app-half review, round 2

Reviewed 2026-10-14 on `ericlee4992/beta-06-ai-proxy-app`, HEAD
`21495885bab3f19d69c6e5943adf24074c3b530c`, using `git diff 39455dd..HEAD` and the round-1 report,
ticket response and round-2 prompt. The working tree was clean before this report. The server is unchanged.
Standards and Spec were reviewed separately. No builds, simulators, devices or deployed requests were run;
only this report was written. The round-1 report is untouched.

## Standards

**S1 closed; no new Standards findings.** The comments in `SettingsView.swift:348–350`, `AskAI.swift:95–97`
and `DesignSampleFixture.swift:39–43` now describe account status and permission fixtures without claiming
that a device or fixture key remains. The shared copy helpers are called by the actual error views, and
`routineSignIn` remains the identifier used by the new error-step action and its UI test.

The selected affected-suite rerun is proportionate under DEVELOPMENT. A full UI suite is unnecessary for
these bounded changes. However, the session tests do not establish the completion-boundary guarantees
required below: directly cancelling a flow model does not test account invalidation and SwiftUI observation.

## Spec

### B1 — P2: F2 remains open for routine and New Model between token change and view update

`WorkoutTracker/Features/Templates/AIRoutineSheet.swift:112` and
`WorkoutTracker/Features/Gyms/ModelPicker.swift:596` cancel on `account.token` changes through SwiftUI
`.onChange`. Unlike the corrected scan, their completion paths still do not compare the request's captured
session with the current account: `AIRoutineFlowModel.swift:142–149` checks only task/request cancellation,
and `ModelPicker.swift:770` checks only task cancellation.

The hook is not synchronous with the account mutation. If account invalidation occurs and a queued completion
resumes before the view processes `.onChange`, the routine publishes its preview or New Model inserts its
exercise ticks after sign-out. Running the hook afterward does not repair that state: `cancelGeneration()`
(`AIRoutineFlowModel.swift:176–182`) preserves a preview already published, and `abandonProposal()`
(`ModelPicker.swift:789–792`) does not remove inserted ticks. The launch-refresh overlap described in round 1
still supplies a path for account invalidation while an admitted AI request is outstanding.

This remains contrary to “no stale request can write after sign-out.” Retain the hooks for prompt cancellation,
but compare the captured session synchronously before either success or failure changes state, as scan now
does. Test an actual account-token change with a pending completion before the view hook runs.
`aWeekStillOutWhenTheSessionEndsIsDropped` (`WorkoutTrackerTests/AIServerClientTests.swift:191–206`) instead
calls `cancelGeneration()` directly, immediately after scheduling generation; it neither changes an account
nor ensures the request has started before cancellation.

### B2 — P2: New refusal handlers can invalidate the replacement session

`WorkoutTracker/Features/Templates/AIRoutineSheet.swift:114–115` observes a Boolean `model.signedOut`, then
reads **the current** `account.token` and invalidates that token. The new failure handler at
`WorkoutTracker/Features/Gyms/ModelPicker.swift:783` does the same. Neither value identifies the session
whose request failed.

If an old request's refusal is processed after session replacement but before the token-change cancellation
hook, these handlers invalidate the replacement. This defeats the protection in `TerraAccess.client`, whose
unauthorized callback correctly supplies the refused request's token. It violates “only if that session is
still current.” Carry the refused request token through the model/error path and invalidate that token, or
leave production invalidation to the transport and make fixture invalidation use its captured token. A Boolean
alone cannot preserve this identity. Extend the obsolete-session test through these UI/model handlers; the
existing test exercises only the safe transport callback.

### Closure of the other round-1 findings

| Finding | Result against code and callers |
|---|---|
| F1 | Closed for the error-step action: `AIErrorStep` now reads `aiReady`, offers Sign In when signed out and Generate week after sign-in. The sheet supplies the live account state and opens `AccountSignInSheet`; preferences are retained. B2 concerns the new invalidation path, not this action. |
| F2, scan portion | Closed: scan captures the token and compares it in both completion branches, with token-change cancellation as well. Routine and New Model remain open under B1. |
| F3 | The usage-follow-up 401 now calls `onUnauthorized(token)` with the request token and throws `signedOut`. Ordinary usage failures retain fallback copy; success and ordinary-failure paths check task cancellation after the await. Existing caller guards still suppress results/errors after dismissal. B2 is a separate, unsafe re-invalidation added at callers. |
| F4 | Closed against the spec: the direct routine consent line now names both Stacked's server and OpenAI while retaining the sent-field list. The ticket correctly flags this changed string for the user's confirmation; this review does not supply that approval. |
| F5 | Closed: scan calls `ScanErrorText.shown`, covering both sentence-initial and lowercase manual wording. Routine calls the updated split helper, which removes standalone manual-only follow-up sentences while retaining retry/reset guidance. |

The fixes do not change request fields, routes, timeout, result decoding, validators, consent keys, catalog
resolution or confirmation. The added expired-session fixture remains behind the existing UI-test fixture
path. Dismissal cancellation remains in place. No further regression was found in these touched contracts.

### Verification evidence inspected

Artifacts under `/tmp/wt-floodlight/results/06app/` were read directly:

- `build4.log`: **TEST BUILD SUCCEEDED**, build-for-testing using the separate `dd-06app-b` derived data.
- `unit3.log`: **TEST EXECUTE SUCCEEDED**. `unit3.xcresult`: **991 passed, 0 failed, 0 skipped**.
- Pre-fix `ui1.xcresult`: **97 passed, 2 failed, 0 skipped**; `ui1.status`: **exit 65**. Failures match the
  prompt: `FloodlightSettingsUITests.testCaptureSettingsDarkAccessibility` (reaching `askAISettings`) and
  `AskAIUITests.testEditingGeneratedWeekKeepsRowsAndSavesOnlyOnce` (dragged exercise leading the session).
- Fixed-build `ui2.log` names FloodlightAIAccess, FloodlightAIRoutine, FloodlightScan, AskAI and FloodlightSettings,
  using `test-without-building` against `dd-06app-b` with three workers. At **2026-10-14 03:20 EDT**,
  `ui2.status` was absent and the bundle/log had no completed result summary. This run remains **pending**;
  neither earlier UI failures nor the new expired-session UI test are claimed cleared.

The phone's live smoke remains open. No new claim is made about installation, deployed behavior or the deferred
Workers Free CPU-cap decision. Standards: **0 findings**. Spec: **2 P2 findings**.

Verdict: not clear
