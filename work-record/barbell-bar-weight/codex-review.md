# Codex cross-review — barbell bar weight

Reviewed 2026-08-24. Boundary: `a3a6934...ec48ebf` (the exact D39–D40 commit).
Independent Standards and Spec agents reviewed the change separately.

## Standards

1. **High — stored bar provenance omitted normalized kilograms.** `barWeightValue` shared the
   set's unit but did not persist the complete `(value, unit, normalizedKg)` triple required by
   `CLAUDE.md`.
   - Resolution: added validated `BarWeight`, optional `SetRecord.barNormalizedKg`, atomic writes,
     migration coverage, and a compatibility derivation for rows written by the brief old schema.
2. **Judgement call — bar value and unit travelled as a primitive clump.**
   - Resolution: `BarWeight` now owns value, unit, and normalization; the picker passes that value
     as one concept rather than a `(Double?, WeightUnit)` callback. The independent fix review
     found one remaining transport seam in `PreviousSetValue`; that now carries `BarWeight?` too.
3. **High on fix re-review — compatibility normalization was derived but not persisted.** Rows
   written by the brief intermediate schema could keep `barNormalizedKg == nil` indefinitely.
   - Resolution: store open now runs an idempotent repair that validates the provenance, persists
     the derived normalization, and clears invalid partial provenance. A disk-backed reopen test
     proves both persistence and a zero-change second pass.

## Spec

1. **Critical — equal-valued cross-unit switches left stale plate text.** A 15 lb → 15 kg switch
   changed the model unit but not `barWeightValue`, so the view's old observer did not fire.
   - Resolution: the row observes bar value **and unit** as its input context. XCUITest reproduces
     the exact equal-valued switch and asserts the old plates cannot be completed.
2. **Critical — a preset change could recommit the previous preset's prefill.** The model cleared
   inherited values, but local text state and the prefill task identity omitted the preset.
   - Resolution: preset identity participates in the input/task context; untouched local fields
     mirror the cleared model. XCUITest logs Wide grip, verifies next-session prefill, switches to
     Narrow grip, and asserts the fields are empty and completion disabled.
3. **High — `addSet` mixed fields from two source rows.** Weight/unit/reps came from the last
   completed row while bar weight could fall back independently to a differently configured draft.
   - Resolution: every carry-forward field now comes from one source row. A regression covers a
     completed kg total-entry row beside a 45 lb draft.
4. **High — variable-weight bars were selectable guesses.** A warning on EZ/trap presets did not
   satisfy D4's rule against plausible invented facts.
   - Resolution: only standard weights remain presets. EZ curl, trap/hex, Smith and other
     maker-dependent bars are explicitly routed through Custom.
5. **Medium — choosing a bar after all rows were complete auto-created a draft.** This was useful
   deliberate behaviour but absent from the original contract.
   - Resolution: retained and documented in the spec/ticket: the choice describes the next set,
     and a visible picker must not silently do nothing.

## Verification

- Red phase: all three new integrity regressions failed against the reviewed implementation.
- Focused domain/migration/export run after fixes: 53 tests passed.
- Complete unit run after the persisted-backfill follow-up: 451 tests across 42 suites passed.
- Complete affected UI classes: 4 tests (`BarbellUITests` + `ExercisePresetUITests`) passed.
- The independent fix re-review is recorded in `codex-review-2.md`.
