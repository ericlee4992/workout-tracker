# Ticket 06 — app-half review

Reviewed 2026-10-14 in `ericlee4992/beta-06-ai-proxy-app`, using `git diff main..HEAD` with
`main = 0998e401f96160594eb75ae309630d334baf7111`. Initial HEAD was `459ffa0773ece60b34c8e5f3a119a3a86a0deff8`;
during review it advanced to `39455dd71334d1c96628fa6cbaf4a1cdd3d0090a`, changing only `docs/STATE.md`.
The app/server comparison is unchanged. The server half has no diff and was not re-reviewed for clearance.

Read the ticket's Scope, Acceptance, UI-first, wiring and deployed-check sections; the public-beta spec's AI
contract; D60 and retained D53/D56/D58 rules; AGENTS/DEVELOPMENT; server README and actual request/reply handling;
the changed app code, callers and tests. Standards and Spec received separate parallel reviews. No builds,
simulators, devices or deployed requests were run. Only this report was written.

## Standards

### S1 — P3: Remove comments describing the deleted key path

`WorkoutTracker/Features/Settings/SettingsView.swift:348–350` says the key lives in the sheet immediately before
saying there is no key on the phone. `WorkoutTracker/Features/Gyms/AskAI.swift:95–97` promises a stub key, and
`WorkoutTracker/Domain/DesignSampleFixture.swift:43` says the fixture saves one. These paths were removed.
Update these comments to describe account-backed availability and permission fixtures. AGENTS requires internal
functions and doc comments to be checked against their callers before closure.

No material architecture or ordinary UI-fixture isolation violation found. The targeted scope is appropriate
under DEVELOPMENT: AI transport, its three flows, Settings and adjacent account/gym flows are bounded; a full UI
suite is not necessary. Coverage does need focused cases for the session failures below and successful sign-in
returning into each entry point. Opening/cancelling Sign In or launching an already-signed-in sample does not
exercise that transition.

## Spec

### F1 — P2: Routine expiry leaves a primary action that cannot recover

`WorkoutTracker/Features/Templates/AIRoutineSheet.swift:151` passes `canRetry: permitted` and `onRetry: generate`
after a 401. `WorkoutTracker/Features/Templates/AIRoutine/AIGeneratingStep.swift:246` therefore keeps **Generate
week** enabled. Once the unauthorized callback invalidates the session, each retry supplies a nil client and
returns “Sign in to use AI.” again. Sign In is available only after taking the secondary Back to preferences path.
The ticket promises “every entry point then shows Sign In.” Make the error action account-aware and return from
sign-in with the existing preferences usable; cover an actual 401 followed by sign-in and retry.

### F2 — P2: In-flight replies can update AI state after sign-out

`WorkoutTracker/Features/Templates/AIRoutine/AIRoutineFlowModel.swift:139`,
`WorkoutTracker/Features/Gyms/IdentifyEquipmentSheet.swift:320`, and
`WorkoutTracker/Features/Gyms/ModelPicker.swift:768` check task cancellation/request identity, but never compare the
captured session with the current account. These views also do not cancel their work when the account changes.

This is reachable without navigating out of the flow: launch starts `account.refresh()`
(`WorkoutTracker/App/WorkoutTrackerApp.swift:162`). An AI request admitted before remote session revocation can
remain in flight while that refresh receives 401 and forgets the account (`AccountStore.swift:148–155`). The server
authenticates before starting the AI operation, so its eventual success can still arrive. The routine then publishes
its preview, New Model inserts exercise ticks, and scan stores a hidden proposal that can reappear after sign-in.
This violates the requested “no stale request can write after sign-out.” Bind each operation to its session and
cancel/discard results when that session changes; test delayed success and failure across invalidation/replacement.
The existing dismissal guards themselves are retained.

### F3 — P2: The over-limit follow-up discards a refused session

`WorkoutTracker/Domain/AIServerClient.swift:97–100` wraps `AccountClient.usage` in `try?`. If the AI POST returns
`429 ai_limit` but the follow-up `GET /v1/ai/usage` returns 401, the client silently substitutes the fallback limit
message and never calls `onUnauthorized`. The phone remains signed in despite the server explicitly refusing its
session. Handle `.unauthorized` through the same token-aware invalidation callback and signed-out error as the
POST; retain fallback wording for ordinary usage-fetch failures. Add a POST-429/GET-401 test, including a replaced
session. Also check cancellation after this extra await: currently it is swallowed by the helper, although the
view-level cancellation guards prevent an error from appearing after dismissal.

### F4 — P2: Routine consent does not disclose the server in the direct flow

`WorkoutTracker/Features/Templates/AIRoutine/AIEquipmentStep.swift:212–246` names OpenAI and lists the fields sent,
but never identifies Stacked's server. A person can sign in, enable consent and generate here without opening the
optional Ask AI settings sheet. The spec explicitly requires “the disclosure now names both the developer's server
and OpenAI.” Add the server to this flow's disclosure, retaining its field list and independent consent flag.

### F5 — P3: The scan's manual-action rewrite misses the new rejected-request line

`WorkoutTracker/Domain/AIServerClient.swift:164` introduces “AI couldn't take this request. Continue manually.”
The scan rewrite at `WorkoutTracker/Features/Gyms/Scan/ScanSteps.swift:582` replaces only lowercase
`continue manually`, so this error retains **Continue manually** rather than the promised **Choose a catalog
model** wording. Handle the sentence-initial case and test every new server line through the presentation helper.
The routine's first-sentence split handles the new multi-sentence messages, but its removal of only
`" or continue manually."` also leaves the new standalone manual sentences intact; include those in the copy check.

### Confirmed behavior and limits of verification

- Request routes, Bearer session, input-only bodies and 75-second request timeout match the server's 60-second
  OpenAI deadline. Scan sends UUID strings and the four accepted `loadType` raw values; the server normalizes UUID
  case. Model suggestions omit nil `muscleGroup` and preserve empty strings, both accepted. Routine uses synthesized
  `JSONEncoder` fields, omits nil `heightCm`/`weightKg`, and supplies the required routine muscle group as `""` when
  absent. No model, instructions, schema or OpenAI credential is sent.
- `{result}` still reaches `EquipmentIdentification.validated`, `AIRoutine.validated`, and
  `ExerciseProposalAPI.parse`. Editable proposals, confirmation, catalog resolution and the three consent flags
  remain. Ordinary POST status/code mappings match the approved lines; limit/reset lookup and local-time display
  are present. Direct POST 401 uses `invalidate(token:)`, protecting a newer session.
- No OpenAI key read/write path remains in production or tests. The purge's generic-password class, bundle-derived
  `.askai` service and `openai-api-key` account exactly match `git show main:…/AskAIKeyStore.swift`. Normal
  `-uiTestReset` launches bypass it and account networking. The literal “never under UI tests” has an existing tooling
  exception: opt-in `BackupExportUITests.swift:19` intentionally launches without reset and therefore follows normal
  app launch, including purge. It is skipped in ordinary suites. Anthropic client construction remains confined to
  unit tests; the production transcriber is nil. Legacy fixture prompt builders remain, but the server-backed
  production calls do not use them.
- `-uiTestTerra` can answer locally without a sample account while signed out; a present sample account controls
  readiness. Normal AI UI fixtures use local answers and disposable account/store paths.

### Evidence inspected

All paths below are under `/tmp/wt-floodlight/results/06app/`.

- `build2.log` and `build3.log` each end with **TEST BUILD SUCCEEDED** (build-for-testing).
- `unit2.log` reports **TEST EXECUTE SUCCEEDED**; `unit2.xcresult` directly reports **986 passed, 0 failed,
  0 skipped**, WT-iPhone27/iOS 27. The per-device 998 count includes parameterized executions.
- `cap-ld.xcresult`: **1 passed**; `cap-ld.status`: **exit 0**.
- `cap-rest.xcresult`: **1 passed, 2 failed**; `cap-rest.status`: **exit 65**. Both Accessibility test failure
  details point to line 191 of the capture version of `FloodlightAIAccessUITests`: waiting for New Model's suggestion
  button. This matches the recorded failure location; splitting/scrolling that test still needs a successful rerun.
- `ui1.log` names the requested eight targeted suites and three parallel workers. At the final check on
  **2026-10-14 02:22 EDT**, `ui1.status` was absent and no final test summary was available. This run is **pending,
  not passed**. No replacement run was started.

The ticket honestly leaves the phone's one-request-per-flow smoke open for build 3. Its deployed results are
recorded evidence, not calls repeated by this review: maximum scans used 43–45 ms CPU; app-sized scans 15–16 ms,
above Workers Free's stated 10 ms. The user's decision to retain Free and revisit before external testers is
explicit; this is not a passed CPU-cap gate. Adversarial and forced-refusal checks are recorded separately.

Standards: **1 finding, worst P3**. Spec: **5 findings, worst P2**. Targeted UI completion and phone smoke remain open.

Verdict: not clear
