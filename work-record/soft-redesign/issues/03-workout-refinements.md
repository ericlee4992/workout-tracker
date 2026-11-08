# S3 — Workout refinements

Type: change
Status: **in review** (2026-11-07) — Codex round 1; merge waits for the deferred Phase 1 test run
Blocked by: S2
Implementer: Claude; Reviewer: Codex (visible Orca terminal), to "clear".
Branch: `ericlee4992/soft-03-workout`, stacked on S2 (S1–S2 not yet in `main`).
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

- **2026-11-07 — implemented** (`8d5741c`, `e01f01d`, `4e6e887`):
  1. **Train:** `TemplateStats.dueNext` (done longest ago, never-run first, ties by name then id; shared with Today)
     leads as `TrainUpNextCard` (name, families, exercise line, "Last done … · about N min", one Start capsule
     "<gym> · N exercises"); Start Lifting / Start Cardio as the quiet `TrainQuickStarts` (same ids); "Other
     templates" (grid of the rest, odd last tile alone); New Template… / Ask AI as plain `TrainMakeRow`s; "This
     week" last. No template → the Start pair stays primary. The card's open button carries the tile's id
     (`templateTile.<name>`): a template is shown once, as the card or a tile.
  2. **Finish:** `FinishBestsHero` (the first best big, "was … · equipment", others as `FinishBestRow`s), then the
     receipt `FinishReceiptList` (Time · Exercises and sets · Volume · Calories active / total · Heart rate avg /
     max, from the same `FinishTile`s, so absent facts drop as before; each figure keeps its tile id and label),
     then View in History / Save as Template. `FinishReceipt.Comparison.isShownAtFinish`: shown only when both runs
     have volume and today ≥ −25 %. History's detail is unchanged (S4).
  3. **Cardio:** Pause | End equal (gap 12), "End" seen, "End <activity>" spoken; after End (cardio focus, no
     unfinished cardio) the tray slot is **Finish Workout** (`finishWorkoutBar`, the toolbar Finish's action).
  4. **Template detail:** Delete Template… in a "…" menu beside Edit (`templateMore` → `deleteTemplate`); the
     machine line is hidden when its label equals the exercise name (case/diacritic-insensitive).
  5. **AX rest slab:** one row (ring 40 · time · +15s · Skip), +15s drops below only when it cannot fit.
- **New strings:** "Up next", "Other templates", "Last done … · about N min", "<gym> · N exercises", "New best" /
  "N new bests", "was …", receipt labels Time / Exercises / Volume / Calories / Heart rate with "exercise(s)",
  "set(s)", "active", "total cal", "avg", "max bpm"; "End"; "Finish Workout"; menu "More". Open to veto.
- **Tests:** unit `TemplateDueNextTests` 4, `FinishComparisonRuleTests` 3 (+ `TodayDayBoundaryTests` 3) — 10/10.
  UI TemplateDetail, Cardio, FloodlightFinish, FloodlightWorkoutTab, FloodlightLive, FloodlightCardio (3 workers):
  45/54 — failures: the receipt panel's container identifier overrode its figures' (`summaryTime` missing; fixed)
  and the AX finish captures expected View in History on screen at once (now after the receipt; test scrolls).
  Re-run of the 9 in parallel: 7 hit `kAXErrorServerNotFound` (known cold-runner issue); serial re-run with the
  warm-up `CardioUITests/testSavedDistanceEditor…` first: **all 9 passed** (the warm-up itself timed out, its
  purpose). Captures checked (Train, finish default/AX light/dark, template detail, cardio ended, AX rest slab).
- Not in scope (undecided in the prototype): Finish at the top vs bottom of the live workout.

## Comments
