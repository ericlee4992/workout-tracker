# 02 — Bar weight on SetRecord, and the session API that maintains it

Status: resolved
Blocked by: 01

The storage half. One new attribute, the service calls that write it, and proof the user's real
store still opens.

## Files

- `WorkoutTracker/Domain/Models.swift` — `SetRecord.barWeightValue: Double?`
- `WorkoutTracker/Domain/WorkoutSession.swift` — choose/clear bar, per-side commit, carry-forward
- `WorkoutTracker/Domain/PreviousPerformance.swift` — prefill carries the bar
- `WorkoutTrackerTests/BarbellLoggingTests.swift`, `LegacyStoreMigrationTests.swift`

## What to build

- `SetRecord.barWeightValue: Double?` — the bar's weight **in this row's `weightUnit`**. nil =
  total entry (today's behaviour). Optional so stores written before it existed migrate
  lightweightly. Document at the declaration that `weightValue` remains the total: the field is
  provenance, and a reader that subtracts it from `weightValue` to get "the real weight" has
  misunderstood it.
- `WorkoutSession.chooseBar(_ bar: BarPreset?, for entry: ExerciseEntry)`:
  - applies to the entry's **uncompleted** rows only — completed sets keep the bar they were
    logged under, exactly as they keep their weight;
  - sets each affected row's `weightUnit` to the bar's unit (D40) and clears any weight value that
    was inherited rather than typed (`prefilledAt != nil`), because last session's *total* is not
    this session's *plates* and would otherwise be read as a per-side number;
  - nil clears bar mode, converting the row back to total entry: the row keeps the total it
    already had, since that number was always the total.
- `WorkoutSession.commitPerSide(_ text:for:)` — parses like `commitWeight` (D25 decimal comma),
  computes `BarbellMath.total`, and writes `weightValue` + `normalizedKg` atomically through
  `StoredWeight`. Clears `prefilledAt` — typed, not inherited.
- `addSet` carry-forward (B1) copies `barWeightValue` alongside weight/unit/reps.
- `PerformanceHistory.prefill`/`applyPrefill` carry `barWeightValue` (add it to
  `PreviousSetValue`), so a new session's first row arrives in bar mode with the plates already
  in it.
- `chooseEquipment` (D19): a split entry's moved draft rows already clear inherited values;
  clear the inherited bar with them. A bar is only offered on barbell/Smith entries, so a row
  dragged onto a machine must not keep one. **A preset change keeps the bar** — changing grip does
  not put a different bar in the user's hands, and clearing it would mean re-picking the bar on
  every chip tap. (Amended during implementation; the first draft of this ticket said a preset
  change cleared it too, which is a rule that is simpler to state and wrong in the gym.)

## Acceptance criteria

- [ ] **The invariant**: after `commitPerSide("45")` on a 45 lb bar, `weightValue == 135` and
      `normalizedKg == 135 × 0.45359237`. A test asserts `RecordsMath` sees 135, not 45.
- [ ] Per-side `0` on a 20 kg bar logs a 20 kg set and is loggable (A1) — an empty bar is real work.
- [ ] `chooseBar` on an entry with one completed set and one draft row changes the draft only; the
      completed set's `weightValue` and `barWeightValue` are byte-identical afterwards.
- [ ] `chooseBar` sets the draft row's unit to the bar's unit, and does **not** convert the value.
      A total already entered in that same unit is **kept** (it is re-read as bar + plates); one
      entered in the other unit, or lighter than the bar, is dropped rather than reinterpreted.
- [ ] `chooseBar(nil, …)` leaves `weightValue` untouched (it was always the total) and clears
      `barWeightValue`.
- [ ] Carry-forward: complete a bar-mode set, `addSet`, and the new row has the same
      `barWeightValue`, unit, weight and reps, uncompleted.
- [ ] Cross-session prefill: finish a workout with a bar-mode set, start another, add the same
      exercise with the same free-weight tag — the first row arrives with that bar and that total.
- [ ] Switching preset or equipment on a draft row clears the inherited bar along with the
      inherited numbers (D36's rule, one field wider).
- [ ] `LegacyStoreMigrationTests` opens `Fixtures/LegacyStore.store` under the new schema, the
      existing workout/entry/set survive unchanged, and the legacy set reads `barWeightValue ==
      nil`. **This gate is why the ticket exists** — that fixture is the shape of the only copy of
      the user's training history.
- [ ] `SchemaTests` still passes (CloudKit rules: no unique constraint, optional attribute with
      no default required).

## Resolution (2026-08-22)

`SetRecord.barWeightValue` (optional, in the row's own `weightUnit`), plus on `WorkoutSession`:
`offersBar`, `chooseBar(_:for:)` / `chooseBar(weight:unit:for:)`, `commitPerSide`,
`platesPerSide(of:)`, and a `toggleUnit` guard. `PreviousSetValue` carries the bar so ticket 11's
prefill brings it across workouts. Tests: `WorkoutTrackerTests/BarbellLoggingTests.swift` (17),
plus `theBarWeightArrivesEmptyOnPreBarSets` in `LegacyStoreMigrationTests` — the fixture written
by the installed commit opens under the new schema and its set reads `barWeightValue == nil`.

Three decisions the ticket did not anticipate:

- **A preset change keeps the bar; an equipment change drops it.** One `split` serves both
  (D19/D36), so the difference is read from the arguments rather than assumed.
- **Choosing a bar keeps a total already entered in that same unit** and re-reads it as bar +
  plates, rather than clearing it. It was always the total, so there is nothing to convert. A
  total in the *other* unit, or one lighter than the bar, is dropped — reinterpreting either would
  invent a set.
- **`commitPerSide` falls through to `commitWeight` when the row has no bar**, so the view has one
  commit path and a mode change mid-edit cannot double or halve the user's number.
- **`offersBar` covers rack/Smith *machines*, not just the free-weight tags.** A Smith machine is
  normally a catalog machine (`EquipmentCategory.rackOrSmith`), so a tag-only rule would have
  hidden the bar precisely where its weight is unguessable.

## Notes

`barWeightValue` deliberately does **not** join the D23 snapshot or `RecordGroupKey`. The total is
the whole truth about the load, so two 135 lb sets must share a record table whether one was typed
and the other computed (`../spec.md`, D39). Adding it to the key would split the user's barbell
history the day they switch bars.
