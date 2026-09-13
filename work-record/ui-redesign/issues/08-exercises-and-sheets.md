# 08 — Exercises tab and the pickers/sheets

Status: resolved — Codex clear after 2 rounds (codex-review-08, 08b); unit 707/707 (alone; the heart-rate timing tests flaked once under Codex + a UI build); full UI suite 61/61 on `e2c87bd`; merged to main 2026-09-11

Spec: `work-record/ui-redesign/spec.md` ticket 08, on the chosen Ink / Amber system.

## What changed

- `ExerciseRow` (`Features/ActiveWorkout/ExercisePickerSheet.swift`, shared by the Exercises
  tab, the mid-workout exercise picker and a machine's exercise list): a `MuscleIcon` for the
  body area (glyph and colour; accessibility-hidden), the name in `cardTitle`, the body area
  still SAID as a caption beside the equipment tags, which are now `Chip`s; the load type a
  `Chip` in the accent when it is not the default (was a grey capsule). The strings are the
  same words as before; the " · " joiner is gone (they are separate elements now).
- `ExercisesView`: rows on `Theme.card`, hairline separators, the filter banner on the card
  colour with the summary in the accent, "Custom" in `label`, "Add Exercise…" `.secondary`
  (74 seeded rows are always beside it); filter ids, `clearExerciseFilters`, `noExercisesMatch`
  and the "Search exercises" prompt unchanged.
- `ExercisePickerSheet`, `AddByMachineSheet` (both lists), `MachinePickerSheet`,
  `BarPickerSheet`: lists on `Theme.background`, rows on `Theme.card`; "New Exercise…" and
  "Add Machine…" `.secondary`; "Use this bar" `.primary` (the one in-list primary action —
  every other sheet's Save/Add/Done is a toolbar button and stays one). `exerciseOption.*`,
  `machineOption.*`, `newExercise`, `createExerciseFromSearch`, `barOption.*`,
  `barCustomApply`, `logAsCounterpart` unchanged.
- Untouched: `NewExerciseSheet`, `ExercisePresetsSheet`, `EditExerciseLoadTypeSheet`,
  `PreviousPerformanceSheet`, `ExerciseRestSettingsSheet`, `MaxHeartRateSheet` — stock Forms
  whose primary actions are toolbar buttons; nothing in them needs a token.
- `MuscleIcon` (`Features/Design/MuscleGroupStyle.swift`): the tile is a `@ScaledMetric`
  (40 pt relative to `.title3`), so it grows with its glyph — at AccessibilityL the fixed tile
  was smaller than the symbol. Every host benefits (Start's template cards, History's detail
  header — its AXL capture recaptured).
- At accessibility sizes the row's chips stack under the name and the load-type chip joins that
  column; a chip never breaks mid-word (`fixedSize`). The first AXL capture showed "Ma chi ne".
- New capture `test07_exercisesLargeText` (`07-exercises-axl`).
- No new copy.

## Acceptance criteria

- Screenshots `07-exercises`, `07-exercises-axl` reviewed by the user.
- Gates green: `ExercisePresetUITests`, `DumbbellCounterpartUITests`, `CoreLoopUITests`,
  `BarbellUITests`; unit suite; full UI suite before merge; Codex clear.

## Verification (2026-09-11)

Gates on `ui-redesign-08`: `ExercisePresetUITests` 3/3, `DumbbellCounterpartUITests` 1/1,
`CoreLoopUITests` 9/9, `BarbellUITests` 2/2, captures test06 + test07_exercisesLargeText —
16/16; after the AXL fixes (chip stacking, scaled tile): DumbbellCounterpart, ExercisePreset,
the two captures + `test05_historyLargeText` (MuscleIcon host) — 6/6. Screenshots
`screenshots/08/` — sent to the user. Full suite: see STATE.

## Codex review 08 — response (2026-09-11)

`codex-review-08.md`: two P2s (layout), everything else clear.

- **P2, a four-tag row cannot fit one line at ordinary sizes** (the chips did not wrap or
  compress). New `Features/Design/WrapLayout.swift` — a `Layout` that flows its children left to
  right and wraps when the next would not fit, children at their ideal size. The row's caption +
  chips use it at every size; the AXL-only VStack is gone (the load-type chip still joins the
  flow at accessibility sizes, sits at the trailing edge otherwise).
- **P2, the scaled `MuscleIcon` overflows Start's five-icon template strip at AccessibilityL**
  (five ≈ 70 pt tiles ≈ 374 pt). `TemplateRow`'s strip is a `WrapLayout` too, and at
  accessibility sizes the Start button sits under the text (`AnyLayout`). New capture
  `test04_startLargeText` builds a five-exercise template through the editor at AccessibilityL
  (`04-start-axl`).
- Gates re-run after both: `ExercisePresetUITests` 3/3, `DumbbellCounterpartUITests` 1/1,
  `CoreLoopUITests` 9/9, test04 + test04_startLargeText + test06 + test07_exercisesLargeText —
  16/16. `04-start-axl.png`: the strip wraps 4 + 1, Start under the text.

## Codex review 08b — response (2026-09-11)

`codex-review-08b.md`: **clear** — `WrapLayout`'s arithmetic checked case by case, both P2s
closed, nothing new. (No four-tag exercise exists in the catalog to capture; the layout is the
proof.)
