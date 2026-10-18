# 20 — History: delete one cardio activity from a workout

Type: bug / change
Status: **ready** (2026-10-18)
Blocked by: —
Implementer: Claude; Reviewer: Codex.
Branch: `ericlee4992/beta-19-bug-fixes` off `main` `1f0e040` (tickets 19–22 together).
Ships in: **build 9**.

## Report (the user, 2026-10-18)

"From history, I want to be able to also remove cardio session."

## Decision (the user, 2026-10-18)

- **One cardio inside a workout**: in a finished workout's detail page, a single recorded cardio activity can be
  deleted (swipe and a menu, as an exercise can be today), keeping the rest of the workout. Whole-workout delete
  (swipe in History, Delete Workout… in the detail) already exists and is unchanged.
- Confirms first, like every History delete (the only copy of the history): "Delete this cardio?" with what goes
  (its time, distance, route). Marks the workout edited (D50) and saves explicitly.
- Default (Claude, to confirm in review): when the cardio is the workout's only content (no completed sets, no other
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

