# N7 independent review — round 4

Reviewed by Codex on 2026-11-10, continuing the same reviewer session. Checkout started clean on `ericlee4992/nutrition-07-scan-food` at `16482c36d55d11a01a9e414f1dc713d677d15bed`. Reviewed `d217517..16482c3`, the affected rendering/query paths and regression test. Rechecked the round-4 brief, current STATE and N7 ticket; the project rules, decisions and applicable skills remain unchanged. Separate standards and spec passes completed. Reviewer edits only this report; no commit, push, deployment, phone install or live inference request. No key inspected, printed or copied.

## Findings

**R3-S1 — fixed.** `WorkoutTracker/Features/Today/TodayView.swift:263,274` now uses `visibleScans` both for card rendering and for the empty-state condition. The helper at `:309–312` preserves the live-query UUID lookup: pending/failed scans remain visible; a completion whose entry was deleted is hidden and no longer suppresses “Nothing logged yet today.” Undo makes the restored entry visible again, and Open still receives the current queried object (`:265`).

`WorkoutTrackerUITests/ScanFoodUITests.swift:159–179` covers the actual empty-store scenario: yesterday's completed result suppresses the empty state; Delete shows the message and hides the card; Undo restores the card and hides the message. The new `samples:` parameter defaults to `true` (`:25–29`), preserving the existing tests' launch configuration. This regression does not depend on sample workouts or food concealing the empty state.

**Standards: no new findings. Spec: no new findings.** The prior P2 fixes remain unchanged and were cleared in [round 3](codex-review-n7c.md). No remaining P1/P2/P3 finding from these review rounds is identified in this tip.

## Verification

Fresh `build-for-testing` into `/tmp/codex-n7d/dd`; subsequent tests use those unchanged binaries. Ran `scripts/prepare-test-simulator.sh` first on **WT-iPhone27 `47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`**, iOS 27.0, Xcode 27.2 (27B52). Commands/process evidence: `/tmp/codex-n7d/run.py`, `runner.log`, `runner.pid`. Progress displayed in the existing requested Orca tab; no new terminal opened.

- **Build:** exit **0**, `build.log` / `build.status`.
- **Unit plan, serial:** **1,232/1,232 definitions, 1,252 successful executions, 0 failures, 0 skips**, exit **0**. `unit.xcresult`, `unit-summary.json`, `unit.log` / `.status`.
- **Focused UI from Full, two workers:** **21/21 passed, 0 failures, 0 skips**, exit **0**: ScanFood **13/13**, TodayFood **7/7**, warm-up **1/1**. `ui.xcresult`, `ui-summary.json`, `ui.log` / `.status`. The new empty-state regression, earlier-day Delete/Undo/edit regression, delayed-shutter Cancel regression and description flow all passed. No serial rerun was needed.
- **Captures:** fresh ScanFood PNGs and manifest exported to `/tmp/codex-n7d/attachments/`; inspected light/default and dark/AccessibilityL logged-entry captures. The latter frame leaves the bottom calorie line partly behind the floating Log food control; these existing-layout captures are not evidence for the newly tested empty state. The regression test directly asserts that state's appearance/disappearance.
- **Author evidence:** independently inspected `v4.xcresult`: **20/20 passed, 0 failures, 0 skips**; saved summary at `/tmp/codex-n7d/author-v4-summary.json`.
- **Consistency:** `git diff --check d217517..16482c3` passed. HEAD remained `16482c3` and the checkout stayed clean through verification. No server, schema or test-plan mapping changes; their passing earlier-round checks were not unnecessarily repeated.

Verified: **`16482c3`** fresh build **exit 0**; Unit **1,232/1,232 definitions / 1,252 executions**, **exit 0**, `/tmp/codex-n7d/unit.xcresult`; warm-up + ScanFood + TodayFood **21/21**, **exit 0**, `/tmp/codex-n7d/ui.xcresult`; new empty-state/Delete/Undo regression and preserved earlier regression coverage. R3-S1 is resolved in the actual rebuilt/tested code.

Not verified: physical-camera timing/crop/focus/restart, delayed iCloud transfer, OS background expiration, runtime Reduce Motion, real authentication/retry, live notifications, CloudKit synchronization, app-to-live-server integration or a phone install. These device/network limits remain as documented in earlier rounds. This was the requested focused UI selection, not the full UI suite; no separate AccessibilityL empty-state regression was run.

Known flaky: **none observed this round**. The bounded retry in the description-navigation test remains; the historical failure's underlying cause has not been established, and its previous failed bundles remain relevant.

R3-S1 is fixed. No new findings; N7's outstanding independent-review findings are resolved within the recorded verification scope.

Verdict: clear
