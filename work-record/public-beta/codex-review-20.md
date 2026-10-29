# Codex review — ticket 20

Reviewed 2026-10-18 as Claude's independent reviewer. Scope: `git diff 0e22935..33db769`.
Branch: `ericlee4992/beta-19-bug-fixes`; HEAD: `19438e7a192add06b21cdbfc12738d2ba4a8e7ab`.
The later commit changes only the ticket's review status/SHA; application, tests and build
configuration match `33db769`. Read the ticket, review prompt, D47/D50/D64, relevant SPEC,
AGENTS.md and the design/verification rules. The working tree was clean.

## Standards

1. **P3 — Document individual cardio deletion before merge.** `README.md:46` still describes
   History generically, and this ticket leaves it unchanged. AGENTS.md requires updating the
   public overview on the same branch when a ticket changes app behavior. **Failure scenario:**
   merging this revision omits the required documentation of the new History operation.
   **Fix:** mention that a recorded cardio activity can be removed while retaining the workout's
   other content. No expansion of the screenshot gallery is required.

No code-level standards violations found. Domain logic stays UI-free, the caller explicitly
saves, and the destructive action confirms first. No stored fields, relationships, schema,
serialization format or dependencies changed; no stored-format change or Gate S is involved.

## Spec and acceptance

2. **P2 — The required route/split deletion regression is missing.**
   `WorkoutTrackerTests/CardioHistoryDeleteTests.swift:60` deletes a segment with no route or
   distance data. None of the four new domain tests supplies a nonempty route or split-producing
   data, despite acceptance criterion 4: “Domain unit test for the deletion (route points and
   splits go with the segment).” **Uncovered scenario:** deleting a recorded GPS activity with
   splits while another activity remains; the current tests can pass without checking that
   its route/splits disappear from the saved workout and downstream output. The UI test at
   `WorkoutTrackerUITests/CardioHistoryDeleteUITests.swift:99` deletes the secondary cycle and
   retains the route-bearing run, so it does not close this gap.
   **Fix:** extend the two-activity domain regression with a nonempty route and data producing
   multiple splits; assert those preconditions, delete that activity, save and refetch through
   a fresh context, then verify the deleted activity/data are absent from the workout/export
   and the remaining activity's data are intact. This is an unmet verification requirement,
   not evidence that the current implementation leaves orphaned data. No full UI suite is needed.

No demonstrated functional defect found in the implementation:

- `HistoryEditing.swift:274` rejects running workouts and only-content deletion, then deletes
  the segment and stamps `historyEditedAt`. `isOnlyContent` counts completed sets and recorded
  cardio, so incomplete exercise entries and unrecorded segments do not keep an empty workout.
  Multiple recorded activities correctly allow individual deletion. The operation does not
  modify heart-rate samples, exercise entries or planned cardio. Route, interval and distance
  payloads are fields of the deleted segment itself.
- `WorkoutDetailView.swift:240` derives the hero/cards from remaining relationships; splits
  follow the selected hero. The workout-time tile remains for multiple segments and disappears
  when one hero represents the whole cardio-only duration. D64 duration recomputes from the
  remaining recorded cardio.
- History facts rebuild on `historyEditedAt` and on return to the list; row/month/week figures
  use those facts. Progress cardio panels and sessions compute from current recorded segments;
  export maps current `orderedCardio`. No persistent cache retaining the deleted segment was
  found. The pending confirmation reference clears synchronously after save; no demonstrated
  post-save deleted-object access was found. Hero replacement itself lacks runtime UI coverage.
- `CardioDeleteMenu` is outside the combined header element and uses the existing 44-point
  icon control, an accessibility label and identifiers. Both hero variants receive the action;
  `WorkoutFinishedSheet.swift:86` passes none. Only-content deletion opens the existing
  Delete Workout confirmation. The new confirmation names the activity/time/distance and
  conditionally mentions routes/splits; Cancel clears the pending deletion.

## Independent verification

Both commands used `WorkoutTracker.xcodeproj`, scheme `WorkoutTracker`, SDK `iphonesimulator`,
destination `platform=iOS Simulator,id=9E822EF6-DC67-4958-AEA2-D53D2D36D674`, and
`-derivedDataPath /tmp/codex-20/DerivedData`.

| Check | Result | Evidence |
|---|---|---|
| `xcodebuild … build` | **Exit 0; BUILD SUCCEEDED** | `/tmp/codex-20/build.log`, `build.status`, `build.xcresult` |
| `xcodebuild test … -parallel-testing-enabled NO -collect-test-diagnostics never -only-testing:WorkoutTrackerTests/CardioHistoryDeleteTests -only-testing:WorkoutTrackerTests/CardioOnlyTimeTests -only-testing:WorkoutTrackerTests/ReorderAndHistoryStructureTests` | **Exit 0; 21 passed, 0 failed, 0 skipped; TEST SUCCEEDED** | `/tmp/codex-20/unit.log`, `unit.status`, `unit.xcresult` |
| `git diff --check 0e22935..33db769` | **Exit 0** | No whitespace errors |

Inspected actual process exits, status files, log success markers and the xcresult summary,
which confirms WT-Floodlight, iOS **27.0**. The selected tests cover the basic mixed-workout,
two-cardio, only-content and running-workout cases; they do not close finding 2.

**Independent UI tests skipped.** Inspected Claude's actual `20-final.xcresult` (23 passed:
21 unit tests plus the final mixed-workout UI flow and warm-up) and `20-ui-2.xcresult`
(3 passed: cardio-only flow, AccessibilityL receipt regression and warm-up). Both logs end
`TEST SUCCEEDED`, recorded exit **0**. The `20-ui-1` log confirms the mixed-workout default
and AccessibilityL flows passed; its two failing cases passed in `20-ui-2`.

Author evidence root:
`/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-beta-19-bug-fixes/5c90b802-2d0b-4541-a832-afac14d838e8/scratchpad/runs/`.
Opened `shots20/20-mixed-card-default.png`, `20-mixed-card-axl.png`,
`20-mixed-confirm-axl.png`, `20-only-content-confirm-default.png`, and
`shots20f/20-mixed-confirm-final.png`. The visible menu/header layout and confirmation controls
remain readable at AccessibilityL. The large-text confirmation capture predates the final
copy correction; the final default capture has the corrected copy. Live VoiceOver traversal,
every below-viewport row and hero replacement were not independently exercised.

Only this report was written. No commit or push.
Standards: **1 finding (P3)**. Spec/acceptance: **1 verification finding (P2)**.

Verdict: not clear
