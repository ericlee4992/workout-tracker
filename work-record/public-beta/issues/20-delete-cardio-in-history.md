# 20 — History: delete one cardio activity from a workout

Type: bug / change
Status: **in review** (Codex round 1, 2026-10-18)
Blocked by: —
Implementer: Claude; Reviewer: Codex.
Branch: `ericlee4992/beta-19-bug-fixes` off `main` `1f0e040` (tickets 19–22 together).
Ships in: **build 9**.

## Report (the user, 2026-10-18)

"From history, I want to be able to also remove cardio session."

## Decision (the user, 2026-10-18)

- **One cardio inside a workout**: in a finished workout's detail page, a single recorded cardio activity can be
  deleted from its "…" menu (as an exercise is removed from its "…"), keeping the rest of the workout. No swipe:
  exercises have none either (only sets do), and the cardio cards share one list row (the existing
  `historyCardioSection` container), so a per-card swipe would need that section rebuilt. Whole-workout delete
  (swipe in History, Delete Workout… in the detail) already exists and is unchanged.
- Confirms first, like every History delete (the only copy of the history): "Delete this cardio?" with what goes
  (its time, distance, route). Marks the workout edited (D50) and saves explicitly.
- Default (Claude): when the cardio is the workout's only content (no completed sets, no other
  cardio), the action is the existing **Delete Workout** flow instead — a workout with nothing in it is not kept.
- Cardio-only workouts show their first segment as the hero; deleting a segment must leave the hero, tiles, splits
  and the History row's figures (time, totals, Progress cardio charts) consistent.

## Acceptance

1. A workout with lifting + a cardio: delete the cardio → the lifting stays, the cardio card is gone, History row and
   week/month totals update, Progress cardio charts no longer count it.
2. A cardio-only workout with two activities: delete one → the other remains and becomes the hero if needed.
3. The only content: the action deletes the workout (existing confirmation).
4. Domain unit test for the deletion (route points and splits go with the segment).

## Code map

- Detail: `WorkoutTracker/Features/History/WorkoutDetailView.swift:225-340` (hero + "Cardio" cards), entry delete
  pattern at `:391-423`, `:532`.
- Domain: `WorkoutTracker/Domain/HistoryEditing.swift` (`deleteEntry` `:253`, `impact` `:281`), cardio model in
  `WorkoutTracker/Domain/Cardio.swift`.

## Progress

### Build (Claude, 2026-10-18)

- Domain: `HistoryEditing.deleteCardio(_:in:at:)` (refuses a running workout and the only content; marks the
  workout edited, D50; the caller saves) and `HistoryEditing.isOnlyContent(_:)` (no completed set and no other
  recorded cardio). Deleting the `CardioSegment` takes its route, splits, intervals and distance with it; the
  workout's heart-rate samples stay (they belong to the workout).
- UI (`Features/Cardio/CardioCards.swift`): `CardioDeleteAction` + `CardioDeleteMenu` ("…", `HistoryIconFace`, id
  `historyCardioOptions.<activity>`), on `CardioSummaryCard` (header, trailing) and `CardioHistoryHero` (trailing on
  the title row, or top-trailing over the route map on a material circle). The receipt passes none.
- `WorkoutDetailView`: `cardioDelete(_:)` builds the action — the only content → the existing Delete Workout
  confirmation ("Delete Workout…"); otherwise "Delete Cardio…" → a new "Delete this cardio?" confirmation whose
  message (`HistoryDeleteCopy.cardio`) names the activity, its time and distance, and the route if any.
- No stored-format change (no Gate S).
- Confirmation copy: names the activity, its time and distance, and "with its route / splits" only when it has them
  (first draft said "its splits" for a walk with none — seen in the capture, fixed).

### Verification (Claude, 2026-10-18; WT-iPhone27 `47D21838-…`, iOS 27, scratchpad `runs/`)

Scope (new feature in History editing): the domain tests, the new UI flows at default and AccessibilityL, the cardio
History/receipt regression flows (hero, cards, splits).

- Unit `20-unit-1` (scratch checkout) and `20-final` (this checkout, after the copy fix): `CardioHistoryDeleteTests`
  (4, new), `CardioOnlyTimeTests`, `ReorderAndHistoryStructureTests` — **21 tests, 3 suites passed**, exit 0.
- UI `20-ui-1`: `testDeletingTheCardioOfAMixedWorkoutKeepsTheLifting` and `…AtAccessibilitySize` passed;
  `FloodlightCardioUITests/testFinishedDark` passed; two failures — `testCardioOnlyDeletesOneThenOffersDeleteWorkout`
  tapped a Cancel button iOS 27's dialog does not have (now taps outside, as `FloodlightSettingsUITests` does) and
  `testFinishedLightAccessibility` timed out on the receipt's "20:00" while the label already read "Workout time 20:00"
  (a probe build was compiling alongside).
- UI `20-ui-2`: `testCardioOnlyDeletesOneThenOffersDeleteWorkout`, `testFinishedLightAccessibility` — **both passed**
  (plus the warm-up), `TEST SUCCEEDED`, exit 0.
- UI `20-final`: `testDeletingTheCardioOfAMixedWorkoutKeepsTheLifting` passed with the final copy, exit 0.
- Captures: `runs/shots20/20-mixed-{card,menu,confirm,after}-{default,axl}.png`, `20-only-content-confirm-default.png`,
  `runs/shots20f/20-mixed-confirm-final.png`.
- Commit for review: `33db769` (pushed).
