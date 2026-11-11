# N7 independent review — round 3

Reviewed by Codex on 2026-11-10 in the same reviewer session as round 2. Checkout started clean on `ericlee4992/nutrition-07-scan-food`, HEAD `d2175171eb5695b9dd709509265bceb4c4017ea6`; reviewed `18458af..d217517` and affected callers/rendering. Rechecked STATE, N7's ticket, D82/D83, the round-3 brief and round-2 findings. AGENTS, verification policy and previously loaded review/SwiftUI/SwiftData/design skills are unchanged. Separate standards and spec passes completed. Reviewer edits only this report; no commit, push, deployment, phone installation or live inference request. No key inspected, printed or copied.

A concurrent `TodayView.swift` edit appeared at 21:20:53, after the 21:11:24 build completed. It changes rendering and the empty-state check to use `visibleScans`, addressing the P3 below in source. That working-tree edit is **outside the requested `d217517` tip and outside the built/tested binaries**; it was not made or reverted by this reviewer. Saved as `/tmp/codex-n7c/concurrent-working-tree.diff`. File/line references below refer to `d217517`.

## Round-2 findings

- **R2-S1 — fixed.** `FoodScanQueue.swift:40–43,143` retains `loggedEarlierID`, not a deleted model object. `TodayView.swift:263–273` resolves that UUID through the live `foodEntries` query and passes the current object to the card's Open action. Deletion hides the card; Undo restores a new object with the same UUID, which becomes the editor's target. `ScanFoodUITests.testAnEarlierDayCardFollowsItsEntryThroughDeleteAndUndo` checks deletion, hidden card, Undo, card return, item removal, Save and reopening to confirm the edit. This covers the stale-object failure from round 2 rather than merely checking that the editor opens.
- **R2-S2 — fixed.** `FoodScanFlow.swift:400–407` clears both `captureID` and the capture snapshot synchronously. Cancel calls cleanup before dismissal (`:475–477`), and disappearance calls it too (`:222`). A subsequent callback fails its identity guard before `send` can enqueue anything. Valid callbacks still use the shutter-time mode/frame. The slow-shutter fixture (`:385–393`) deliberately delivers through the same `photo(_:)` callback after two seconds. `testCancelDropsAPhotoStillOnItsWay` cancels while pending and then checks that neither a pending card nor a logged meal appears. This is fixture coverage of the application's callback guard, not a physical-camera timing test.

The bounded second tap in `testADescriptionIsLoggedAtOnce` preserves the description submission and logged-entry assertions. It makes the test tolerate the previously observed missed navigation; it does not establish the underlying flake's cause or prove that navigation itself has been fixed.

## New finding

### R3-S1 — P3: Hidden deleted completions suppress Today's empty state

`WorkoutTracker/Features/Today/TodayView.swift:263–277`, particularly the unfiltered check at **line 277**.

On a day with no logged food or finished workouts, scan yesterday's photo, open its result, delete the entry and let Undo expire. The new `ForEach` filter correctly hides the completion because its entry no longer exists. However, the queue deliberately retains that completion for Undo, so `scans.pending.isEmpty` is still false. The empty-state message is therefore also hidden, leaving only the “Today's log” heading. Waiting for the toast to expire does not remove the retained completion. This is a minor display regression, not another stale-entry or data-loss defect; it is source-derived and was not separately reproduced through the UI.

**Fix:** compute the visible pending collection once and use it for both `ForEach` and the empty-state condition. Retain ID resolution and Undo behavior. Cover an otherwise empty Today after deleting an earlier-day result without Undo, then verify that Undo still brings its card back.

**Standards:** no new ownership, persistence or cancellation violation. **Spec/UI:** one P3 display-state regression; no new P1/P2. The two review passes identified the same issue, counted once.

## Verification

Fresh `build-for-testing` into `/tmp/codex-n7c/dd`; tests use those unchanged binaries. Prepared **WT-iPhone27 `47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`** first. Xcode 27.2 (27B52), iOS 27.0 simulator. Runner commands/process evidence: `/tmp/codex-n7c/run.py`, `runner.log`, `runner.pid`. Progress shown in the existing requested Orca tab; no new terminal opened.

- **Build:** exit **0**, `build.log` / `build.status`.
- **Unit plan, serial:** **1,232/1,232 definitions, 1,252 successful executions, 0 failures, 0 skips**, exit **0**. `unit.xcresult`, `unit-summary.json`, `unit.log` / `.status`.
- **Focused UI from Full, two workers:** **20/20 passed, 0 failures, 0 skips**, exit **0**: ScanFood **12/12**, TodayFood **7/7**, warm-up **1/1**. `ui.xcresult`, `ui-summary.json`, `ui.log` / `.status`. Both new regressions passed, as did the description test. No failure required a serial rerun.
- **Captures:** fresh ScanFood PNG attachments and manifest exported to `/tmp/codex-n7c/attachments/`. Opened the light/default and dark/AccessibilityL logged-entry captures; name, thumbnail, time and nutrition remain readable. These captures do not exercise the P3's deleted-entry empty state.
- **Author evidence:** independently read `v3.xcresult`, **19/19 passed, 0 failures, 0 skips**; summary saved as `/tmp/codex-n7c/author-v3-summary.json`.
- **Consistency:** `git diff --check 18458af..d217517` passed. No server, model/schema or test-plan mapping changes in this round; server/typecheck/plan checks were not repeated, and their passing round-2 evidence remains in [codex-review-n7b.md](codex-review-n7b.md).

Verified: **`d217517`** fresh build **exit 0**; Unit **1,232/1,232 definitions / 1,252 executions**, **exit 0**, `/tmp/codex-n7c/unit.xcresult`; warm-up + ScanFood + TodayFood **20/20**, **exit 0**, `/tmp/codex-n7c/ui.xcresult`; both new regression tests and fresh default/AccessibilityL captures. R2-S1 and R2-S2 are resolved at this tip.

Not verified: the concurrent uncommitted `TodayView.swift` fix (not included in these binaries); the P3's empty-state scenario through end-to-end UI; physical-camera timing, crop/focus/restart, delayed iCloud import, OS background expiration, runtime Reduce Motion, live sign-in/retry, notifications or CloudKit behavior. The remaining device/network limitations from round 2 still apply. No full UI suite or phone install was performed.

Known flaky: **none observed this round**. The historical description-navigation failure from rounds 1/2 now has one bounded test retry; its passing result does not establish the underlying cause or prove that production navigation was fixed. Preserve the earlier failure evidence.

Both prior P2 findings are fixed. One P3 remains in the requested and tested `d217517` commit. The later working-tree fix appears to address it in source, but needs fresh verification before clearance; these passing results must not be attributed to that newer code.

Verdict: not clear
