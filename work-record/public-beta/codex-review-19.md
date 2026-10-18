# Codex review — ticket 19

Reviewed 2026-10-18 as Claude's independent reviewer. Scope: `git diff 37a72d8..6c9e0ea`.
Branch: `ericlee4992/beta-19-bug-fixes`; checkout HEAD: `9db69e70038270d9befcd6599f8c59a1f24511f3`.
The later commit only records the review SHA in the ticket; product and test sources match `6c9e0ea`.
The working tree was clean before review. Only this report was written; no commit or push.

## Standards

1. **P3 — Update the public overview for the visible change before merge.**
   `WorkoutTracker/Features/Progress/AddChartSheet.swift:81` adds body-area sections, but
   `README.md:49` and the README screenshots are unchanged. AGENTS.md's “Where information belongs”
   rule explicitly requires a README update, including screenshots when screens change visibly,
   on the same branch before merging. **Failure scenario:** merging this reviewed revision omits
   that required public-documentation checkpoint. **Fix:** mention body-area browsing in the
   Progress paragraph and add a current Add Chart capture to the README. The existing Progress-tab
   capture can remain if it still accurately depicts that unchanged screen.

No code-level standards violations or actionable code smells found. The helper is pure Domain
logic, introduces no UI dependency, and replaces duplication between its two callers. The selected
verification scope is appropriate under DEVELOPMENT.

## Spec

No actionable spec findings against ticket 19, D63, and SPEC's Progress contract.

- `CatalogBrowsing.swift:73` preserves the old `ExercisePickerSheet` algorithm exactly:
  present known groups in `BodyArea.order`, other nonempty groups using the existing Swift
  string sort, then nil/empty together as “Uncategorized.” Dictionary grouping preserves
  incoming order. The picker changes only its call and tuple-member name; Recent is untouched.
- `AddChartSheet.swift:63` still selects eligible logged exercises, filters names, and sorts
  descending by last completion date with ascending name ties. Grouping happens afterward,
  preserving that order within each section. Only populated sections are emitted; zero results
  still reach “No matches.” No Recent section was added.
- `AddChartSheet.swift:87` retains the navigation destination, arguments, Add callback and
  dismissal. Step 2 and Cardio are unchanged. `addChartExercise` remains on each NavigationLink
  (`:94`), without an ancestor identifier overriding it.
- `NativeLists.swift:57` gives `LookSectionLabel` the header trait. The source hierarchy places
  each header before its rows, with no accessibility combining or sort-priority override on the
  new section container. Live VoiceOver traversal was not exercised.
- The four new `BodyAreaSectionsTests` cover known-order versus alphabetical order, other-group
  sorting, nil/empty merging, incoming-order preservation, and empty input. They do not test
  Add Chart's recency/name comparator or interactive search; those paths were source-reviewed.

## Independent verification

Both commands used `WorkoutTracker.xcodeproj`, scheme `WorkoutTracker`, SDK `iphonesimulator`,
destination `platform=iOS Simulator,id=9E822EF6-DC67-4958-AEA2-D53D2D36D674`, and
`-derivedDataPath /tmp/codex-19/DerivedData`.

| Check | Result | Evidence |
|---|---|---|
| `xcodebuild … build` | **Exit 0; BUILD SUCCEEDED** | `/tmp/codex-19/build-retry.log`, `build-retry.status`, `build-retry.xcresult` |
| `xcodebuild test … -parallel-testing-enabled NO -collect-test-diagnostics never -only-testing:WorkoutTrackerTests/BodyAreaSectionsTests -only-testing:WorkoutTrackerTests/CatalogBrowsingTests` | **Exit 0; 29 passed, 0 failed, 0 skipped; TEST SUCCEEDED** | `/tmp/codex-19/unit.log`, `unit.status`, `unit.xcresult` |
| `git diff --check 37a72d8..6c9e0ea` | **Exit 0** | No whitespace errors |

Inspected actual process exits, status files, log success markers and the unit xcresult summary.
The summary confirms WT-Floodlight, iOS **27.0**. The initial sandboxed build exited **70** because
CoreSimulator was inaccessible (`build.log`, `build.status`, `build.xcresult`); the successful
retry ran with simulator access. This was an environment failure, not a source failure.

**Independent UI tests skipped.** Inspected Claude's actual `19-ui-2.xcresult` and log:
3/3 passed, zero skipped, `TEST SUCCEEDED`, recorded exit 0. These cover
`testAddingLiftingAndCardioFromEmpty`, `testCaptureProgressLightDefault`, and
`testCaptureProgressDarkAccessibility`. The earlier `19-ui-1` log records the Add Exercise
picker flow passing; its three Add Chart failures are the cases that passed in `19-ui-2`.

Author evidence root:
`/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-beta-19-bug-fixes/5c90b802-2d0b-4541-a832-afac14d838e8/scratchpad/runs/`.
Opened and visually inspected `shots19/19-add-chart-light-default.png` and
`shots19/19-add-chart-dark-axl.png`. The visible headers and rows retain their hierarchy;
AccessibilityL names wrap without clipping in the fully visible rows. These are initial-viewport
captures, so they do not establish the layout of every section below the viewport. The capture
tests use the same fixture and explicitly select AccessibilityL for the large-text capture.

Standards: **1 finding (P3)**. Spec: **0 findings**. No functional defect found; the remaining
item is the repository's required documentation checkpoint.

Verdict: not clear
