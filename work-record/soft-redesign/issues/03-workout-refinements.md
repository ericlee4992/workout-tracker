# S3 — Workout refinements

Type: change
Status: **proposed** (2026-11-07) — awaiting the user's approval
Blocked by: S2
Implementer: Claude; Reviewer: Codex (visible Orca terminal), to "clear".
Branch (when built): `ericlee4992/soft-03-workout` off `main`.
Spec: [soft-redesign](../spec.md); design: [ui-evolution](../../ui-evolution/spec.md) Direction A (carried into Soft).

## Goal

The workout changes the user liked in the Mono round, built in the Soft look.

## Scope

1. **Train → Templates order:** the template done longest ago leads, with one Start; Start Lifting / Start Cardio as a
   quiet pair; "Other templates"; New Template… / Ask AI as plain rows.
2. **Finish screen:** new bests first (the best set large, "was …"), then a receipt-style summary (Time · Exercises
   and sets · Volume · Calories active/total · Heart rate avg/max), then View in History / Save as Template. A
   comparison with last time that shows a drop of more than 25 % is hidden. Absent facts are omitted (D44/D52 rules).
3. **Cardio:** Pause | End as two equal buttons with a gap; the end button reads "End"; after End the slot becomes
   Finish Workout. D64 (cardio-only time) unchanged.
4. **Template detail:** Delete Template… moves into a "…" menu beside Edit; the machine line is hidden when it only
   repeats the exercise name.
5. **Large text:** the rest slab is one row.

Not decided in the prototype, so **not** in scope unless the user decides: Finish Workout at the top vs bottom of the
live workout (stays where it is).

## Acceptance

1. Each item above at default and AccessibilityL, light and dark, captured.
2. Finish: records, volume and calories match today's values for the same workout (FinishReceipt unit tests extended
   for the order and the hidden-drop rule).
3. Cardio Pause/End/Finish: CardioUITests and the D64 tests pass; End does not finish the workout by itself.
4. Delete Template via "…" asks for confirmation as today; TemplateDetail UI tests follow the move.
5. Codex clear.

## Verification scope

New behaviour on existing screens → FinishReceipt / RecordsMath unit tests, Cardio, TemplateDetail, CoreLoop finish UI
flows, captures.

## Code map

- `Features/Start/StartWorkoutView.swift`, `WorkoutHomePieces.swift`, `TemplateDetailView.swift`, `TemplatePieces.swift`.
- `Features/ActiveWorkout/WorkoutFinishedSheet.swift`, `Domain/FinishReceipt.swift`.
- `Features/Cardio/CardioLive.swift`. Prototype: `Screens/Finish`, `Screens/Cardio`, `Screens/Templates`, `Screens/Workout`.

## Progress

Not started.

## Comments
