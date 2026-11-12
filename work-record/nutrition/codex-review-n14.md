# N14 — Codex independent review, round 1

Reviewed 2026-11-12 on `ericlee4992/nutrition-14-ai-goals`, HEAD
`62cb8012241ce668d4fca5ef0a7ff85b995275d7`, against `99bafefd`. The requested `2b05f054` is its parent;
the only later changes are DECISIONS/STATE, recording D85 and the review handoff. The checkout was clean at the start.
Scope: the N14 brief and ticket, D52/D70/D80/D83/D84/D85, project verification/persistence rules, and the applicable
SwiftUI, SwiftData, iOS design and code-review guides. Standards and spec were checked separately.

## Standards

### R1 — P2: Qualify the deployed privacy policy's conflicting non-upload assurance

`server/src/pages.ts:37–40`, contrasted with `:96–107` and `WorkoutTracker/Domain/GoalPlanAI.swift:12–22`.

The “What stays on your iPhone” paragraph includes body weight and personal details (height, date of birth, sex),
then says “I don’t receive it, and nothing uploads it automatically.” N14 sends sex, age, height and the app-entered
weight through the developer's server when the signed-in user reaches the plan. The new AI paragraph accurately
explains that behavior, but the earlier absolute assurance still contradicts it. The release brief explicitly asks
for accurate, complete privacy wording matching the actual payload.

**Fix:** qualify the opening assurance with the goal-generation exception, distinguishing locally stored logs and
Health readings from the setup answers sent for this feature. Preserve the separate Health-data promise; this is
not a request to change D85's consent decision. The supplied deployment record places this source in the live worker, so the corrected privacy page must
be redeployed by the implementing/release session. No deployment was performed during this review.

### R2 — P2: Update README's goal-generation and data-flow claims

`README.md:98–105`.

README still describes the Goal weight entry and promises “Calculated on the phone; nothing is sent anywhere.”
That is false for signed-in N14 goal generation and points to a removed row. It also promises a calorie floor,
although D85 permits generated replies within the broader 500–10,000 calorie plausibility bounds. README was not changed on this branch,
contrary to AGENTS.md's same-branch public-overview requirement when behavior changes.

**Fix:** document Generate Goals, server-generated numbers while signed in, local fallback, and the restriction to
app-entered weight. Update the relevant export/release description for v14 while clearly distinguishing the pending
app release from the already deployed server; do not imply N14 is installed on testers' phones.

### R3 — P3: Remove the in-app instruction to open the deleted Goal weight row

`WorkoutTracker/Domain/WhatsNew.swift:43`.

Profile → What's New still shows “Find it in Profile → Nutrition goals → Goal weight,” but N14 removes that row.
A user following the current in-app instructions cannot find the named control. This is an active UI string, not
merely an archived planning reference; the review brief specifically calls it out.

**Fix:** make the notes displayed with N14 direct users to Generate Goals (or supply the replacement release entry
before this version ships), and update the approved-copy test accordingly. Preserve older wording in historical
records where appropriate.

## Spec

### R4 — P2: Save the fallback plan using the confirmed setup weight

`WorkoutTracker/Domain/GoalSetupStore.swift:80–93`,
`WorkoutTracker/Domain/NutritionGoalStore.swift:49–54,115–117,133`.

Setup correctly prefills only the latest app-entered weight, but commit now uses that app-only prefill to decide
whether to insert a weigh-in. The subsequent goal update still reads the latest weight from **all** sources. With
an app-entered **80 kg** followed by an Apple Health **90 kg** entry, the unchanged 80 kg answer inserts nothing.
For a 30-year-old man, 180 cm, Moderate activity, losing 0.4 kg/week, the fallback preview is **2,319 cal**, but Save
recalculates and stores **2,474 cal** from the Health weight. With a generated plan, the generated numbers remain,
but `goal.weightKg` records 90 kg even though generation used 80 kg.

This violates the intended setup-answer/plan relationship and the acceptance requirement that the fallback uses
the setup answers. It is a **local preview/save mismatch**, not evidence that a Health-sourced weight is uploaded.

**Fix:** make the confirmed setup weight the weight used by commit and subsequent refresh. For example, compare it
against the actual latest weigh-in and record a new app confirmation when needed, while continuing to exclude Health
weights from outbound prefill. Preserve the no-duplicate behavior when the actual latest weight already matches.
Add mixed app/Health history integration tests asserting preview, saved numbers and stored input weight agree,
for both generated and fallback plans. The current Health test checks prefill only.

### R5 — P2: Do not cache request cancellation as a generation failure

`WorkoutTracker/Features/GoalSetup/GoalSetupDraft.swift:244–250`,
`WorkoutTracker/Features/GoalSetup/GoalPlanService.swift:17–19`;
request lifetime at `WorkoutTracker/Features/GoalSetup/GoalSetupFlow.swift:43–46`.

Reach the plan while signed in, then tap Back while generation is pending. Changing the task ID cancels the request;
`GoalPlanService` converts cancellation to nil through `try?`, and `generate` stores that nil as `failedRequest`.
Returning to the plan with unchanged answers hits the failed-request guard, so no new request is made. The user gets
a permanent local fallback for that draft and “Couldn't reach the server” even though the server did not fail.

**Fix:** distinguish cancellation from a failed response, clear only the matching pending request, and discard
canceled/superseded completions without caching failure. Returning to an abandoned request should be able to ask
again. Add suspended-generator tests for Back/cancel/return and changed-answer requests; the current generation tests
use immediately returning closures and do not exercise cancellation. Keep the existing one-attempt behavior for an
actual failed response to unchanged answers.

## Verification and supporting checks

Runner: `/tmp/codex-n14/run.sh`, PID **29013**, completed. Simulator preparation ran first on WT-Floodlight
`9E822EF6-DC67-4958-AEA2-D53D2D36D674`. Current source rebuilt in `/tmp/codex-n13/dd`.
The server checks, build and test runs were sequenced, with no competing author run.

- Independent **build-for-testing**: exit **0**, `/tmp/codex-n14/build.log` and `build.status`.
- Independent **Unit** plan: **1339/1339**, no failures or skips, exit **0**, `/tmp/codex-n14/unit.xcresult`.
  Inspected the actual status and xcresult summary (`unit-summary.json`). This includes generated-goal retention,
  overrides/recalculation, migration/fingerprint and export tests.
- Independent server **npm test**: **305/305 Vitest + 4/4 Node script tests**, exit **0**;
  **npm run typecheck**: exit **0**. Logs/statuses: `/tmp/codex-n14/server-test.*`, `server-typecheck.*`.
- Additional isolated SQLite rehearsal of the exact migration 0009: six representative old-flow rows retained
  with every column unchanged, primary key retained, new flow accepted, account-deletion cascade retained. No live D1 database
  was used. Result: `/tmp/codex-n14/migration-check.json`.
- Temporary Swift harness uses the unchanged checked-in draft/calculation code and extracted supporting value,
  comparison and generated-plan resolution code: `/tmp/codex-n14/Repro.swift`, `repro`, `repro.log`.
  R4: confirmed 80 kg yields 2,319; duplicate comparison skips insertion; the calculation with the newer 90 kg
  yields 2,474. Actual fetch/commit consequences were traced in source, not represented as a new SwiftData test.
  R5: a suspended cancellable generator reproduces the service's nil-on-cancellation contract; after Back/cancel/
  return, calls remain **1**, generationFailed is **true**, generatedPlan is absent, and Save is enabled.
- Server implementation checks found no additional defect: authenticated route; whitelisted numeric/enumerated
  input and reserialization; unknown input keys dropped; 4 KB cap; shared atomic quota/accounting; reply bounds
  matching D85. Reviewed the generated marker's defaults, dated updates and optional v14 export field.
- Traced setup prefill to `latestEnteredWeight`, draft inputs and the request body. No direct Health-weight upload
  path found. First-use feature controls remain; the deleted settings sheet/row has no production caller. R3 is the
  remaining active navigation instruction.
- Inspected supplied Nutrition goals/Profile default and AccessibilityL captures in light and dark: Generate Goals
  and the removed Ask AI row match the requested composition; longer content remains readable after scrolling.
- Independent **Full plan narrowed to named UI tests**: **37/37**, no failures or skips, exit **0**,
  `/tmp/codex-n14/ui.xcresult`; log/status: `ui.log`, `ui.status`; inspected summary: `ui-summary.json`.
  Scope: AAAWarmUpUITests (1), GoalSetupUITests (7), NutritionGoalsUITests (6), FloodlightSettingsUITests (10),
  FloodlightAIAccessUITests (10), AskAIUITests/testSignedOutRoutineOffersSignIn and
  testSignedOutRoutineAccessibility (2), plus FloodlightTourUITests/testWelcomeAndTourLight (1), the ticket's
  adjacent tour-caption check. Two workers. No failed tests required a serial rerun.
- Exported 98 attachments from the GoalSetup, NutritionGoals and Settings classes to `/tmp/codex-n14/captures/`,
  with manifests retained and readable filenames in `/tmp/codex-n14/captures-named/`. Checked fresh representative
  Nutrition goals and Profile captures at default/AccessibilityL against the supplied light/dark evidence; no
  additional layout finding. An initial concurrent xcresulttool cache-creation collision was resolved by opening
  the result sequentially; the test run itself succeeded and the summary/exports then read successfully.
- Only this report changed in the checkout; reviewed HEAD remains `62cb8012241ce668d4fca5ef0a7ff85b995275d7`.

## Verification status

Verified: independent build-for-testing — exit 0; Unit — 1339/1339, exit 0, `/tmp/codex-n14/unit.xcresult`;
named UI selection — 37/37, exit 0, `/tmp/codex-n14/ui.xcresult`; server — 305/305 Vitest + 4/4 script tests,
exit 0, typecheck exit 0; migration rehearsal; temporary R4/R5 reproductions and capture review as detailed above.

Not verified: a signed-in device request to the live AI server (network behavior used test fixtures/mocks);
phone installation/Gate S; device HealthKit receipt; human VoiceOver; runtime Reduce Motion; App Store Connect
privacy declarations; the full UI suite. No live-account requests or deployments were made by this reviewer.

Known flaky: none seen in the test runs.

Standards: three findings (two P2 data-handling/copy issues, one P3 navigation issue). Spec: two P2 findings
(preview/save weight mismatch and cancellation cached as failure). Five findings remain.

Verdict: not clear
