# S4 independent review — Round 3 test fixes

Reviewed 2026-11-08 by Codex; implementation by Claude.

## Scope

Read the updated brief, current state, S4 ticket's Phase 1 results, changed tests, and relevant application/helper
callers. Branch `ericlee4992/soft-04-history-progress`, initial HEAD `aec8928634c824f1341167a3a9ba848ba151ea2e`.
The requested `126713e..b0ecf09 -- WorkoutTrackerUITests` range also includes the previously cleared Round 2
Progress-menu test. The new changes since cleared `12c6219` are only the Scan/Profile test interactions and docs;
there is no new application change. This review assesses those two edits and the unchanged number-pad test.

Only this report was written in the repository. No commit or push. The existing **Test progress (Claude r2)** tab
`term_ac1339dc-202d-4c10-bab3-b528de726cbd` was verified idle and reused; no new terminal was opened.

## Standards

No actionable source findings. Both edits retain their substantive assertions and change only how the test
establishes the state needed for the next action.

## Spec and diagnosis

- **Scan navigation (`FloodlightScanUITests.swift:331–333`):** `historyEquipment()` promises to inspect History and
  return to the retained machine page. `openTrain("Gyms")` intentionally returns to the section root: its second
  Train tap pops a retained push when that page hides the root-only switch. A single Train tap is therefore the
  correct operation here. Switching tabs retains the current Train section and navigation stack; switching Train
  sections is the separate S2 operation that replaces the selected subtree. The test still checks cancellation
  leaves the machine/history unchanged, future-only correction leaves historical snapshots unchanged, and confirmed
  Apply to Past rewrites the expected equipment line. No navigation/product assertion was removed.
- **Decimal weight (`FloodlightProfileUITests.swift:225–234`):** the right-edge tap establishes the insertion point
  needed before issuing backspaces. A center tap is not an end-of-text contract. `TrainingProfileEditor.swift`,
  including its native centered TextField, string binding, decimal keyboard, validation and save path, is unchanged
  from `main`; S1 changes its font through the look. Diagnostics show the same 58 × 44 pt field frame on both builds,
  while Soft's old interaction produced `82.5180`, consistent with typing before the existing `180`. The test still
  asserts exactly `82.5` while typing and `82.5 lb` after Save. This establishes decimal retention rather than
  bypassing it. The evidence does not justify an application caret override as an S1 regression fix.
- **Existing limitation:** inspected focused screenshots show the weight field partly under the keyboard on both
  `main` and Soft. That pre-existing keyboard visibility issue is not fixed or cleared by this test change.
- **Goals number pad:** no assertion or application change was made for the intermittent failure. The test still
  checks a real software keyboard, focused-field visibility relative to Done, dismissal, exact values, and Next
  reachability. Passing diagnostic runs support intermittency but do not establish the failure's root cause.

## Evidence checked

Implementer evidence base:
`/private/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-UI-design/7de0aa3c-5c42-4616-b226-c172ad5bea55/scratchpad/`.

Read actual xcresult metrics/failures and status files, not just the ticket's totals. The initial Phase 1 bundle is
238 passed / 11 failed / 1 skipped (exit 65). Its focused rerun has 8 passed / 4 failed, including the warm-up;
the remaining target failures are the two changed tests and goals number pad. `main3` has all three target tests
passing, with only its warm-up failing (exit 65). The implementer's fix run is 31/32, again only the warm-up failing.
Extracted evidence is retained at `/tmp/codex-s4/round3/phase1-evidence.json`.

Inspected `dbg.log:596,604` and `main-dbg.log:105,123` and the paired PNGs
`cap-dbg/1BA0F3DF-2EBA-46B6-9B88-C0CFE9C89AD7.png` and
`cap-main-dbg/836DDE32-F287-442C-A11B-6E8E5AC04E63.png`. The main diagnostic Profile test passed, exit 0.
`dbg.log:303,466,489` records a passing number-pad run with both fields hittable and above Done.

## Independent verification

Xcode 27.2 (27B52), iOS 27.0, WT-iPhone27 `47D21838-69A6-4BCB-AE90-B0D9C0AAA70B` only.
Artifacts: `/tmp/codex-s4/round3/`; reused `/tmp/codex-s4/DerivedData` after rebuilding the changed tests.

- `build-for-testing`: **exit 0**, `TEST BUILD SUCCEEDED`; xcresult `succeeded`, **0 errors, 0 warnings** in this
  incremental build. Evidence: `build.log`, `build.xcresult`, `build-summary.json`.
- Requested serial UI run: **exit 65**, xcresult **4 passed, 1 failed, 0 skipped**; `ui.log`, `ui.xcresult`.
  All four requested target tests passed: Scan future-only correction, Scan Apply to Past, Profile decimal weight,
  and AI goals number pads. Only the warm-up failed at `CardioUITests.swift:58` waiting for `cardioTimer`, the same
  assertion recorded in the main baseline. Selection used `-parallel-testing-enabled NO` and
  `-collect-test-diagnostics never`; counts were read directly from the completed xcresult summary.
- Isolated warm-up rerun: **exit 65**, xcresult **0 passed, 1 failed, 0 skipped**; `warmup-rerun.log`,
  `warmup-rerun.xcresult`. It failed again at `CardioUITests.swift:58`; the log also records that an app event-loop
  idle notification was not received after starting cardio. The same assertion fails in the recorded main baseline
  and the implementer's fix run. Its root cause is not established here, and it is not counted as a pass or claimed
  fixed. This unchanged baseline failure does not establish a regression in either reviewed test edit.
- The existing progress tab displayed both completed runs and returned to its prompt; no new terminal was opened.
- `git diff --check 126713e..b0ecf09 -- WorkoutTrackerUITests`: **exit 0**.

This is a focused independent review of the test fixes, not a fresh 250-test Phase 1 run, a green five-test suite,
or a claim that the intermittent keyboard issue has been eliminated. The goals number-pad test passed this run;
it remains a watch item. Prior product clearances remain in the earlier reports. The verdict below applies to the
two test-only fixes and their preserved assertions; the baseline cardio warm-up failure remains unresolved.

Standards: **0 new findings**. Spec: **0 new findings**. Both edited tests and both requested adjacent checks passed.

Verdict: clear
