# Codex fix re-review — barbell bar weight

Reviewed 2026-08-24. Boundary: `c73cf5e...4bbe3e8` plus the final ticket wording
correction. Commits: `b817db4` and `4bbe3e8`. Standards and Spec were reviewed by separate,
independent agents after the first review's fixes.

## Standards

No findings.

Both prior findings are closed:

- `WorkoutTrackerStore.makeContainer` runs the idempotent `BarWeightStoreRepair` on store open,
  persists missing normalization, and clears invalid partial provenance.
- `PreviousSetValue` carries `BarWeight?`; it decomposes into SwiftData fields only at the write
  boundary.

The diff follows `CLAUDE.md`: stored bar weights retain `(value, unit, normalizedKg)`, migration
fields remain optional and CloudKit-compatible, no conversion is silent, and pure bar logic stays
in `Domain/`. No baseline smells were introduced.

## Spec

No findings.

The final review verified:

- Equal-valued cross-unit bar changes refresh the plate input.
- Preset switches clear stale inherited inputs.
- Carry-forward takes bar, unit, total, and reps from one source row.
- Variable-weight EZ/trap/Smith bars route through Custom.
- Choosing a bar after all rows are complete creates a draft, as documented.
- Missing bar normalization is persisted and idempotently backfilled at store open.
- `PreviousSetValue` carries one validated `BarWeight`.

The first Spec pass found one low documentation-only contradiction: a stale checklist line said a
preset switch cleared the bar, while the amended contract and implementation keep the physical
bar. The checklist was corrected and the Spec agent re-reviewed the final wording before issuing
the zero-finding report above.

Summary: Standards — 0 findings, no worst issue; Spec — 0 findings, no worst issue.

## Verification

- Complete unit suite: 451 tests across 42 suites passed.
- Complete affected UI classes: 4 tests (`BarbellUITests` + `ExercisePresetUITests`) passed.
- `git diff --check` passed before both implementation commits.
