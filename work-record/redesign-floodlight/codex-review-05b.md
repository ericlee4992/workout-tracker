# Ticket 05 — Codex review, round 2

**Verdict: not clear — one medium finding.** No critical, high or low findings.

Reviewed `4587977..971f03c7e132713c33e63d9912fb4d79cf7da24d` on
`ericlee4992/redesign-floodlight-history`, in `/tmp/wt-floodlight/history`.
Product fixes are in `33b8986`; `971f03c` adds the review prompt. The working tree was clean
before review. No `xcodebuild` or `simctl` was run; only this report was written.

## Medium

### 1. Abandoning an exercise leaves its muscle family in the open detail's cached receipt

**Standards / spec — derived-state refresh:**
`WorkoutTracker/Features/History/WorkoutDetailView.swift:496–499`.

The new cleanup correctly retains the added set independently of the sheet binding, removes
it and saves. However, it does not rebuild the detail's `receipt`. That cache refreshes only
on appearance or a change to `historyEditedAt` (`:119–120`), and pruning is deliberately
unmarked (`WorkoutTracker/Domain/HistoryEditing.swift:228–233`).

**Concrete case:** open the fixture's Leg Day, choose Add Exercise → Seated Chest Press,
then Cancel or swipe the editor away without saving. Adding the exercise marked the workout
and inserted a completed placeholder; `FinishReceipt.build` therefore included Chest in
`familySets` (`WorkoutTracker/Domain/FinishReceipt.swift:72–79`). After dismissal, the exercise
and its ring segment disappear, but the hero still reads the cached families at
`WorkoutDetailView.swift:228` and shows Chest until the detail is reopened or another marked
edit refreshes it. It falsely reports a trained family after the addition was abandoned.

This is the detail counterpart of the stale-list-facts defect found during verification.
The new `HistoryView.swift:83–85` appearance hook fixes the list when returning to it; it does
not invalidate the open detail. Rebuild the detail's derived state after successful pruning.
Extend `HistoryEditFlowsUITests.testAnAbandonedAddExerciseLeavesNothing` to check the hero's
families before leaving the detail, for Cancel and interactive dismissal. Its current checks
at `:113–117` cover exercise and list counts only. This finding is established by source
tracing; no fresh simulator reproduction is claimed.

## Round-1 findings checked

| Finding | Round-2 assessment |
|---|---|
| 1 — abandoned additions persist | Persistence defect fixed by separate `addedSet` cleanup identity. Saved additions survive; unloggable additions are pruned. Related detail-cache gap above remains. |
| 2 — reps ignored in chart records | Fixed: `RecordsMath.outranks` now supplies the full rank. Equal-load rep improvement and subsequent tie are tested. |
| 3 — Sessions opens wrong workout | Fixed: the destination uses the same scoped, eligible best-set selection as the series, including its tie handling. |
| 4 — false zero / rounded metric hero | Fixed: missing metric days are excluded from selection; displayed metric values retain decimals and no longer coerce nil to zero. |
| 5 — quadratic overview calculation | Fixed: inputs are built once per scope, sorted and swept with a running incumbent. The before-start cutoff remains; the new test compares counts against every fixture receipt. |
| 6 — adjustable chart has no spoken value | Fixed in source: selection date, formatted value and applicable record mark are exposed through `accessibilityValue`. Human VoiceOver verification remains unclaimed. |
| 7 — calendar contrast | Fixed: 0.62 ink over white gives approximately **5.55:1** contrast with white digits, above the 4.5:1 gate. |
| 8 — editor lacks NEW BEST | Fixed: saved mark is passed to the editor and hidden while values differ. The refreshed captures show it. |
| 9 — capture state / AXL gaps | Fixed: deterministic Leg Extension 70 lb × 10 at both sizes, lower editor captures including footer/Delete Set, and empty History in light/dark AXL. |

## Verification inspected

Read the implementer's response, changed source/tests, actual saved exit files and logs, and
`xcresulttool` summaries under `/tmp/wt-floodlight/results/`:

- `history-build-5`: exit 0, build succeeded.
- `history-ui-5`: exit 65; **66 domain tests passed**, including both new named regression
  tests. UI: 16 passed, six failed; capture 8/8, calendar 3/3 and chart tooltip 4/4 passed.
- `history-ui-6`: exit 65; six passed, one notes-field lookup failed. Both abandonment flows,
  both last-set deletion paths and both existing HistoryEditing tests passed.
- `history-ui-7`: exit 0; the corrected notes test passed, 1/1.
- All three result summaries report zero skips. Runs 5/6 retain the existing invalid-frame
  warnings; run 7 reports none. Failed runs are not treated as wholly successful runs.

Confirmed 52 capture files. Inspected refreshed editor default/AXL pages, empty AXL in both
appearances, and the light calendar; the editor's values, badge, footer and deletion control
are whole in the reviewed images. The additional list appearance refresh is supported by the
passing abandonment/list-count assertions in run 6.

The targeted verification scope remains appropriate under DEVELOPMENT. No full-suite rerun is
requested. Resolve the remaining detail-cache finding and verify the hero after abandonment;
the other reviewed fixes need no additional changes on this evidence.
