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

