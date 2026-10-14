# Ticket 06 — app-half re-review

Reviewed 2026-10-14 on `ericlee4992/beta-06-ai-proxy-app`, pinned final HEAD
`fa75a8894c69e78db93b777ee12cf86c10c5fd40`. Scope: `git diff 39455dd..fa75a88`, with
`git diff main..fa75a88` as app-half context, the round-1 report and the ticket responses.

The checkout advanced during review: at entry HEAD was `2149588`, with additional session fixes uncommitted;
those became `8ec380e`, followed by the prompt-only `fa75a88`. This review includes those committed fixes under
the requested “5614642 or later” scope. Source references below are to `fa75a88`. The earlier version of this
report, reviewing `2149588`, is preserved in commit `8ec380e`; its B1/B2 findings are now closed. A concurrent
update to this report identified B3; that finding was independently checked and retained below.

Standards and Spec were reviewed separately. No builds, simulators, devices, test runs or deployed-server calls
were performed. Only this report was edited; STATE, the ticket and implementation were left alone.

## Standards

No P1–P3 findings. **S1 closed.** The corrected comments in
`WorkoutTracker/Features/Settings/SettingsView.swift:348`, `WorkoutTracker/Features/Gyms/AskAI.swift:95` and
`WorkoutTracker/Domain/DesignSampleFixture.swift:39` describe the account/usage/permission sheet and local fixture
behavior. Their callers no longer suggest a saved device or fixture key.

The new session binding centralizes the comparison used by all three flows. The sole production caller of
`AIRoutineFlowModel.generate` supplies `.bind(account)` (`AIRoutineSheet.swift:191`); `.unbound` is used for
model-only tests. The refusal handler invalidates the captured token, consistent with its documentation.
No actionable baseline code smell was identified. The five affected UI suites remain an appropriate targeted
scope under DEVELOPMENT; their completion is still a verification gate, as recorded below.

## Spec

### B3 — P3: Scan can retain “Sign in to use AI” after successful sign-in

`WorkoutTracker/Features/Gyms/IdentifyEquipmentSheet.swift:330–331` invalidates the captured session, stores
“Sign in to use AI.” in `identifyError`, and sets `busy = false`. The token-change hook at `:167` then skips
cleanup, including when the user signs in again. Successful sign-in dismisses its sheet
(`WorkoutTracker/Features/Account/SignInViews.swift:126`); scan's dismissal handler (`:157`) calls `start()`
(`:270–272`), which also leaves that error intact. Once the account is ready, `step` selects `.error` at `:78`,
and `ScanErrorStep` tells the now-signed-in person to sign in, with Retake/catalog actions.

The expired-session fixture takes this branch. Production can also take it if the catch continuation runs before
the transport's unawaited MainActor invalidation task (`WorkoutTracker/Features/Gyms/TerraAccess.swift:39–40`);
there is no enforced ordering between them. If that task wins first, the session guard drops the catch instead.
The new binding therefore protects stale results but does not eliminate this recovery-state race.

Retake recovers, so this is a misleading recovery state rather than a blocked flow. It undermines the ticket's
signed-out error/recovery behavior: that instruction should cease once sign-in succeeds. Clear the obsolete
authentication error as part of refusal handling or successful sign-in, without discarding unrelated confirmed
work. Cover expiry → successful sign-in → usable scan state. The existing expired-session UI test stops when
scan first offers Sign In; it does not exercise this return.

### Round-1 closure, checked against code and callers

| Finding | Result |
|---|---|
| **F1** | **Closed.** `AIErrorStep` (`AIGeneratingStep.swift:250–254`) reads live readiness and offers Sign In or Generate week. `AIRoutineSheet.swift:124,157–158` opens `AccountSignInSheet`; retry at `:191–192` obtains a fresh client and binding. Cancellation preserves preferences. If transport invalidation precedes the catch, `cancelGeneration()` returns to equipment, whose live readiness also offers Sign In. |
| **F2** | **Closed at this HEAD.** Scan checks the binding before success and failure (`IdentifyEquipmentSheet.swift:324,328`); routine does likewise (`AIRoutineFlowModel.swift:144,151`); New Model checks before inserting ticks or displaying a note (`ModelPicker.swift:775`). Token `onChange` hooks remain prompt cancellation helpers, rather than the only protection. Dismissal/task identity guards remain. The earlier B1 is closed by `8ec380e`. |
| **F3** | **Closed.** `AIServerClient.swift:103–111` handles usage-follow-up 401 through `onUnauthorized(token)` and `signedOut`. Ordinary typed `AccountClient.Failure` errors preserve fallback limit/reset wording. Successful and ordinary-failure paths check cancellation after the await; cancellation propagated as `.unreachable` by `AccountClient` is recovered as cancellation by that check. A received 401 still invalidates only its own token. View guards suppress cancelled results/errors. |
| **F4** | **Closed against the spec.** `AIEquipmentStep.swift:236` names both Stacked's server and OpenAI, retaining the field list and independent consent flag. This judges spec compliance only. |
| **F5** | **Closed.** `ScanErrorText.shown` handles both sentence-initial and lowercase manual wording; `ScanSteps.swift:581` uses it. `AIRoutineErrorText.split` removes standalone manual-only follow-ups and retains retry/reset guidance; `AIGeneratingStep.swift:267` uses it. |

The additional refusal regression B2 is also closed: `AIRoutineFlowModel.refusedSession` replaces the Boolean
`signedOut`, carries the bound token (`AIRoutineFlowModel.swift:154`), and the sheet invalidates exactly that
value (`AIRoutineSheet.swift:114–115`). New Model and scan invalidate their captured tokens too. The synchronous
binding checks reject obsolete failures, and `AccountStore.invalidate(token:)` (`AccountStore.swift:178–179`)
rejects an obsolete token even if session replacement occurs before the sheet's observation callback.

The fixes leave request fields, routes, timeout, result decoding, validators, consent keys, catalog resolution
and confirmation unchanged. The new expired-session flag remains in the gated UI-test fixture path. Previously
confirmed key removal and untouched transport contracts were not reopened. No additional regression was found
in the touched contracts beyond B3.

### Verification evidence inspected

Artifacts are under `/tmp/wt-floodlight/results/06app/`; logs and result bundles were read directly.

- **Round-1 fixes:** `build4.log` ends **TEST BUILD SUCCEEDED**, using separate `dd-06app-b` derived data.
  `unit3.log` ends **TEST EXECUTE SUCCEEDED**; `unit3.xcresult` reports **991 passed, 0 failed, 0 skipped**.
- **Pre-fix UI:** `ui1.xcresult` reports **97 passed, 2 failed, 0 skipped**. The failures match the prompt:
  `FloodlightSettingsUITests.testCaptureSettingsDarkAccessibility` (“reached askAISettings”) and
  `AskAIUITests.testEditingGeneratedWeekKeepsRowsAndSavesOnlyOnce` (“the dragged exercise leads the session”).
- **Round-1 UI rerun:** `ui2.status` remains absent; `ui2.log` ends **BUILD INTERRUPTED**. Its bundle lacks
  `Info.plist`, and `xcresulttool` exits 64 rather than yielding a completed summary. The ticket says it was
  stopped for replacement by `ui3`. This is **incomplete, not passed**.
- **Additional committed session fixes:** `build5.log` ends **TEST BUILD SUCCEEDED**, using `dd-06app-c`.
  `unit4.log` ends **TEST EXECUTE SUCCEEDED**; `unit4.xcresult` reports **992 passed, 0 failed, 0 skipped**.
  The new tests exercise actual account invalidation while a routine reply is outstanding without relying on the
  view hook, a current-session success, and a refusal after session replacement. These support the source review;
  they do not exercise successful sign-in returning to scan.
- **Latest UI rerun:** at **2026-10-14 03:32 EDT**, `ui3.status` was absent and no completed summary was available.
  Its log selects FloodlightAIAccess, FloodlightAIRoutine, FloodlightScan, AskAI and FloodlightSettings against
  `dd-06app-c`, with three workers. This run is **pending**. Neither earlier UI failure nor the new expired-session
  UI test is claimed cleared.

The phone's live smoke remains open. No installation or deployed behavior was reverified, and the deferred
Workers Free CPU-cap decision is unchanged. Standards: **0 findings**. Spec: **1 P3 finding**. UI completion and
phone smoke remain separate from this code-review verdict.

Verdict: not clear
