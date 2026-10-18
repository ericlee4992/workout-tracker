# 19 — Add Chart: logged exercises grouped by body area

Type: bug / change
Status: **ready** (2026-10-18)
Blocked by: —
Implementer: Claude; Reviewer: Codex.
Branch: `ericlee4992/beta-19-bug-fixes` off `main` `1f0e040` (tickets 19–22 together).
Ships in: **build 9**.

## Report (the user, 2026-10-18)

"For adding charts in the progress tab, when you press add chart, it currently just gives list of exercises. I want
them to be organized, so it's easy to navigate."

## Decision (the user, 2026-10-18)

- **Body area** ("Body area (Recommended)"): the Lifting list is split into body-area sections head to toe
  (`BodyArea.order`: Chest, Back, Shoulders, Biceps, …), each with its section label and family icon, the same way
  the in-workout Add Exercise picker does (`ExercisePickerSheet.swift:34-66`). No "Recent" section.
- Groups outside `BodyArea.order` come after it (sorted); exercises with no muscle group come last, under
  "Uncategorized" — the picker's rule.
- Within a section: most recently trained first (today's order), name as tie-break.
- Search still filters across every section; empty sections are hidden. Cardio list unchanged.

## Acceptance

1. Add Chart → Lifting shows the logged exercises under body-area headers, in head-to-toe order.
2. Search narrows the rows and drops empty sections; "No matches" when nothing matches.
3. Picking a row still opens step 2 and Add still pins the chart (existing UI tests stay green).
4. Default and AccessibilityL captures.

## Code map

- `WorkoutTracker/Features/Progress/AddChartSheet.swift:57-87` — `logged` and `liftingList`.
- Grouping rule to mirror: `WorkoutTracker/Features/ActiveWorkout/ExercisePickerSheet.swift:34-66`.
- UI tests: `WorkoutTrackerUITests/FloodlightProgressUITests.swift` (`addChartExercise`).

## Progress

### Build (Claude, 2026-10-18)

- `BodyArea.sections(of:group:)` (`Domain/CatalogBrowsing.swift`): the Add Exercise picker's grouping rule moved into
  Domain unchanged, generic over the row type; `ExercisePickerSheet` now calls it (same output).
- `AddChartSheet.liftingList`: one `LookSectionLabel` (family mark) + `LookList` per section; rows keep today's order
  (most recently trained first) inside each section. The old "Exercises you've logged" header is gone.
- Gotcha: an `accessibilityIdentifier` on the section's `VStack` overwrote every row's `addChartExercise` (3 UI tests
  failed in `19-ui-1`); removed.

### Verification (Claude, 2026-10-18; WT-iPhone27 `47D21838-…`, iOS 27, scratchpad `runs/`)

Scope (DEVELOPMENT → Verification scope, "layout within one screen" + a shared helper): build, unit tests for the
rule and the catalog, the Add Chart flows, one Add Exercise picker flow, default/AccessibilityL captures.

- Unit `19-unit-1`: `BodyAreaSectionsTests` (4, new), `MuscleFamilyTests`, `CatalogBrowsingTests` — **35 tests, 3
  suites passed**, `TEST SUCCEEDED`, exit 0.
- UI `19-ui-1`: warm-up `CardioUITests/testSavedDistanceEditor…` passed; `FloodlightProgressUITests/
  testChangeMoveRemoveAndRelaunch` passed; `HistoryEditFlowsUITests/testAnAbandonedAddExerciseLeavesNothing` (picker
  sections) passed; three Add Chart tests failed on the identifier gotcha above.
- UI `19-ui-2` after the fix: `testAddingLiftingAndCardioFromEmpty`, `testCaptureProgressLightDefault`,
  `testCaptureProgressDarkAccessibility` — **3/3 passed**, `TEST SUCCEEDED`, exit 0.
- Captures (`runs/shots19/19-add-chart-light-default.png`, `19-add-chart-dark-axl.png`): Chest / Back / Shoulders /
  Biceps / Triceps sections with family marks; AccessibilityL wraps names, no clipping.
- Commit for review: `6c9e0ea` (pushed).

### Codex round 1 (2026-10-18): not clear — [codex-review-19.md](../codex-review-19.md)

One finding, **P3**: README not updated for the visible change. No code or spec findings; Codex's build exit 0 and
29/0/0 unit tests on WT-Floodlight.

**Response (Claude):** README's Progress bullet now says Add Chart lists logged exercises by body area. No
screenshot change: none of the seven README captures shows Add Chart (`progress.png` is the tab, unchanged), and
adding an eighth for a picker would outweigh the overview's set of main screens — the rule asks for retakes when a
*shown* screen changes.
