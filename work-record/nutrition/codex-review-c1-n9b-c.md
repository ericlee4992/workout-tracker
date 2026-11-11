# C1 + N9b independent review — round 3

Reviewed by Codex on 2026-11-11 in the same reviewer session. Checkout started clean on `ericlee4992/c1-n9b`, HEAD `f0736d78dbab93a5b0d7df0dade85cfb7d3ac008`; reviewed `4605b1b..f0736d7`, the round-3 brief and ticket update. Project rules and applicable review/SwiftUI/SwiftData guidance remain unchanged. Separate standards and spec passes completed. Reviewer edits only this report; no commit, push, deployment, phone installation, live inference request or key access.

## Findings

**R2-S1 — fixed.** `WorkoutTracker/Domain/HealthNutritionSync.swift:322–334` assigns a request number before awaiting Health. Publishing requires that number to remain latest, the part's generation to remain current, reading to remain enabled, and the calling task not to be cancelled. An older query cannot replace a newer result, including across a time-zone change. Cancellation does not clear an already published value or authorize an older pending request to publish; a subsequent successful refresh updates it normally.

`FakeHealthStore.answerEnergy` preserves normal query recording and default results while allowing tests to control completion timing. `HealthNutritionSyncTests.anOlderBurnedAnswerNeverReplacesANewerOne` (`:467–498`) exercises the actual setting path and newer-before-older replies for both a different-zone key and the same day's key.

**Additional verification against the production engine:** recompiled the prior controlled-store probes against this tip, preserving the earlier evidence. Both the direct overlap and setting-task overlap now retain the newer Los Angeles value **600** after the older New York reply **100**. A separate cancellation probe verified:

- Published **500** remains after the latest request is cancelled and returns **900**.
- The older pending reply **600** also cannot replace that published value.
- The next successful refresh publishes **700**.
- Switching reading off before a late **800** reply leaves the cache empty.

All three builds/runs exited **0**. Evidence under `/tmp/codex-c1n9b-r3/`: `health-burned-order-probe`, `health-burned-set-probe`, and `health-burned-cancel-probe`, each with source, build/run logs and status files. These use the actual engine with minimal domain stubs and controlled Health responses, not a real Health database or UI timing reproduction.

**Standards: no new findings. Spec: no new findings.** The prior round-1 fixes remain unchanged; the remaining round-2 finding is resolved. No P1/P2/P3 finding remains from these review rounds within the recorded scope.

## Verification

Prepared **WT-iPhone27 `47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`**, iOS **27.0**, then freshly built into `/tmp/codex-c1n9b-r3/dd`. Commands/process evidence: `run.py`, `runner.log`, `runner.pid` in that directory. Progress reused the existing Orca tab; no new terminal opened.

- **Build-for-testing:** exit **0**, `build.log` / `build.status`.
- **Unit plan, serial:** **1,257/1,257 definitions, 1,277 successful executions, 0 failures, 0 skips**, exit **0**. `unit.xcresult`, `unit-summary.json`, `unit.log` / `.status`.
- **HealthNutritionSyncTests separately, serial ×10:** **25 definitions / 250 successful executions, 0 failures, 0 skips**, exit **0**. `health10.xcresult`, `health10-summary.json`, `health10.log` / `.status`.
- **UI evidence inspected, not rerun**, as the round-3 brief directs: no view or UI test changed. The author's `r2-ui.xcresult` reports **20/20 passed, 0 failures/skips**. The reviewer's `/tmp/codex-c1n9b-r2/ui-serial.xcresult` reports **16/16 passed** (routine **15/15**, warm-up **1/1**), no failures/skips, with actual saved process status **0**. The prior round's AppleHealth **4/4** result and initial parallel navigation failure remain documented in [round 2](codex-review-c1-n9b-b.md). These are reused UI results from the preceding code, not newly executed UI tests at `f0736d7`.
- **Author round-3 evidence inspected:** `r3-health10.xcresult` reports **25 definitions / 250 executions**; `r3-unit.xcresult` **1,257 definitions / 1,277 executions**; both passed with no failures/skips. Saved inspected summaries as `author-r3-*-summary.json`; inspected UI summaries are `author-r2-ui-summary.json` and `reviewer-r2-ui-serial-summary.json`.
- **Consistency:** `git diff --check 4605b1b..f0736d7` passed. HEAD and product/test source stayed unchanged throughout verification. No server, schema, copy or test-plan mapping changes required additional checks.

Verified: fresh build **exit 0**; Unit **1,257/1,257 definitions / 1,277 executions**, **exit 0**, `/tmp/codex-c1n9b-r3/unit.xcresult`; Health suite **250/250 executions**, **exit 0**, `/tmp/codex-c1n9b-r3/health10.xcresult`; direct/setting-path ordering and cancellation/off probes, all **exit 0**; prior UI bundles/status inspected per the approved round-3 scope. R2-S1 is resolved in the rebuilt/tested code.

Not verified: a new UI run at this tip; real HealthKit authorization/denial, persistent-store quantity/date round trips, real replacement/delete or competing-version behavior, physical-device query timing, phone installation, live server requests, human VoiceOver or runtime Reduce Motion. Earlier device/network integration limits remain applicable; this review does not claim release/device acceptance.

Known flaky: no failure in this round's fresh checks. The historical `FloodlightAIRoutineUITests.testBackKeepsInputsAndLeavingTheWeekAsksFirst` Train-navigation failure remains recorded in round 2; its full serial class rerun passed unchanged. UI was not rerun this round, and no new claim about that flake's cause is made.

Verdict: clear
