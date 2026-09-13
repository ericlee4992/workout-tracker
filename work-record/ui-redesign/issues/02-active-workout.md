# 02 — Active workout: cards, set rows, rest ring, motion

Status: DONE by Codex's design (chosen 2026-09-10) — see `01-design-system.md` "Outcome" and `codex-design-report.md`. The text below is Claude's competing implementation, retired with branch `ui-redesign-01`; kept as the record of the alternative.

Spec: `work-record/ui-redesign/spec.md` ticket 02.

## What changed (files: `ActiveWorkoutView.swift`, `ExerciseEntryCard.swift`, `RestTimerBar.swift`, `HeartRateBar.swift`)

- **Header**: the gym as a chip, completed sets as an accent chip (`N sets`, mirroring the
  existing `N min`), elapsed minutes in the `stat` font. Screen background → `SurfaceBackground`.
- **Exercise card** → `.card()` (radius 20, hairline); `MuscleIcon` leads the title; superset A/B →
  `RoundBadge` (ids/labels kept); equipment and bar pills → `.inset()` with an accent glyph;
  column headers in the uppercase `label` role.
- **Preset chips moved below the sets**, directly above Add Set — under the thumb mid-set
  (STATE's open question). Ids unchanged.
- **Set rows**: the set number in a 26 pt circle that turns solid accent when completed
  (`onAccent` digit for a working set; W/F/D keep their marker colour); fields on the fill
  surface, radius 10, semibold monospaced digits; a completed row is washed `accent 10 %` over the
  row's OPAQUE card fill (unchanged — it hides the swipe-delete button); the checkmark is accent
  with a spring and a `.setComplete` haptic. Swipe mechanics untouched (`swipeDeleteWidth` 88,
  threshold 14, `setRow.previous` a single `Text`); delete button `Danger`.
- **Bar mode**: the plates field, the unit chip and the `setRow.total` caption are ONE fill block
  (the field itself darker inside it), so "plates in, total out" reads as one thing beside last
  session's total in PREVIOUS (the second STATE question). Strings unchanged.
- **Footer**: Add Exercise `.primary`, Add by Machine `.secondary` (dimmed when no gym).
- **Rest bar**: elevated surface, top hairline, a 44 pt accent `ProgressRing` draining beside
  `REST` + the time in `stat` (numeric transition), `+15s` secondary compact, `Skip` primary
  compact; `.restDone` haptic at zero. Same `restEnd/restTotal/addFifteen/skip/expired` API.
- **Heart-rate bar** → `.card(padding: 14)`; bpm in `stat` with a numeric transition; heart
  `Danger`; zone meter's empty bars on the fill surface. Ids unchanged.

## Acceptance criteria

- Screenshots `02-active-workout` (with the rest bar) and `03-finish-summary` reviewed by the user.
- Gates green: CoreLoop, Barbell, ExercisePreset, HeartRate, WorkoutName, DumbbellCounterpart;
  unit suite; full UI suite before merge; Codex clear.
