# 03 — Bar mode in the entry card

Status: resolved
Blocked by: 02

The screen half: pick a bar, type plates per side, see the total you are about to log.

## Files

- `WorkoutTracker/Features/ActiveWorkout/ExerciseEntryCard.swift` — bar row + `SetRowView`
- `WorkoutTracker/Features/ActiveWorkout/BarPickerSheet.swift` (new) — preset list + Custom…
- `WorkoutTracker/Features/History/WorkoutDetailView.swift` — breakdown in history
- `WorkoutTrackerUITests/BarbellUITests.swift`

## What to build

**Bar row** — under the machine/preset rows, shown only when the entry's equipment is
`.barbell` or `.smith`. A button reading `Bar: 45 lb` or `Bar: none (enter total)`, opening a
sheet listing the presets grouped by unit plus **Custom…** (a value field + kg/lb) and **No bar**.
`accessibilityIdentifier("barPicker")`.

**Set row in bar mode** — the weight column takes plates per side, the column header reads
`PER SIDE`, and the row shows the computed total beneath the fields (`= 135 lb`,
`accessibilityIdentifier("setRow.total")`). The unit badge renders the row's unit and is
**disabled** (D40) with an accessibility hint saying the unit follows the bar. Field text is
seeded from `BarbellMath.platesPerSide` and must round-trip: use `WeightMath.displayNumber`, not
`Format.weight` — the latter renders 1.25 as `1.3`, and committing that text would log a
different set than the one on screen.

**Loggability (A1)** — the checkmark goes live on per-side text that parses (including `0`) plus
reps. Judge it on what is on screen, through `WorkoutSession.isLoggable`, so the button can never
enable on input the store refuses.

**History** — a completed set with a bar renders `45 + 45 × 2 = 135 lb`; every other set is
unchanged.

## Acceptance criteria

- [x] The bar row is absent for selectorized machines, dumbbell, cable and bodyweight entries, and
      for an entry with no equipment chosen — but **present** on a machine whose catalog model is a
      rack or Smith (amended during implementation: a Smith machine is normally a catalog machine,
      not a free-weight tag, and that is where a bar's weight is hardest to guess).
- [ ] Picking `45 lb` on a row typed at `135` in kg: the row switches to lb, the field shows
      plates, and nothing anywhere is marked `≈` (nothing was converted).
- [ ] Typing `45` per side with a 45 lb bar and completing logs a set that reads `135 lb` in
      history and in the PREVIOUS column of the next set.
- [ ] `0` per side is loggable; an empty per-side field is not.
- [ ] The unit badge is not tappable in bar mode and is tappable the moment the bar is cleared.
- [ ] Clearing the bar leaves the field showing the **total** (135), not the plates — the stored
      number never changed, only what the field means.
- [ ] The keyboard `Done` bar still commits (B3), and the total caption updates as the field is
      edited, before commit.
- [ ] XCUITest, from `-uiTestReset`: start a workout → add a barbell exercise → pick the 45 lb bar
      → type 45 × 5 → complete → assert the history row reads 135 lb. Runs on `WT-iPhone`.
- [x] Screenshot of the card in bar mode attached to the resolution (the user reads screens, not
      descriptions).

## Resolution (2026-08-22)

`Features/ActiveWorkout/BarPickerSheet.swift` (new) plus the bar row, `PER SIDE` header, total
caption and disabled unit badge in `ExerciseEntryCard.swift`, and the breakdown line in
`WorkoutDetailView.swift`. `WorkoutTrackerUITests/BarbellUITests.swift` drives the whole path from
an empty store and asserts history reads **135 lb**, not 45; it attaches a screenshot of the card
in bar mode (`bar-mode-card`).

Worth knowing:

- The weight field seeds through `WeightMath.displayNumber`, not `Format.weight`. `Format.weight`
  renders one decimal, and halving an odd total puts a second one there (47.5 → 23.75 a side);
  since the field's text becomes the stored value on completion, seeding it with "23.8" would log
  a set the user never performed. **`Format.weight` still has this rounding hazard on the
  total-entry path** — a prefilled 62.25 kg row commits as 62.3. Pre-existing, untouched here,
  worth its own ticket.
- The card's header follows the *first uncompleted* row, since that is the one being typed into.
  Completed rows keep their own bar and render their own breakdown.
- `machineRow` gained `accessibilityIdentifier("entryEquipment")` so the UI test can reach the
  equipment sheet.
- Two SwiftUI traps re-encountered: a computed property whose body starts with `set` parses as a
  setter clause (already documented at `markerColor`), and a nested `ForEach`/`Section`/`Button`
  chain with string interpolation blew the type checker's budget — hence `presetSection(for:)`.
