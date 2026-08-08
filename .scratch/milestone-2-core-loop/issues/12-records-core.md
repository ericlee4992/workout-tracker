# 12 — Records computation core

**What to build:** Pure `Domain/` records math per D17/D20/D21, keyed on **snapshotted** loadType and context (never live catalog rows). Eligibility is load-type-specific: completed sets (completedAt != nil), positive reps, warmups excluded, failure sets included; load must be finite and — weighted: > 0; assisted: ≥ 0 (0 = unassisted); bodyweightPlus: ≥ 0 (0 = plain); bodyweight: load ignored. Ties resolve to the earliest achieving set. Per load type: weighted → best weight per rep count (1–12, >12 ignored) + Brzycki e1RM; assisted → least assistance per rep count, no e1RM; bodyweightPlus → most added weight per rep count, no e1RM; bodyweight → most reps (uncapped), no e1RM; the 12-rep cap applies only to weight-keyed tables. Volume = Σ(normalizedKg × reps) over eligible working+failure sets of weighted exercises only. Comparisons use normalizedKg; results carry the as-entered value+unit for display. Grouping keys from snapshots: machine UUID / model UUID / exercise UUID — and for machineless entries, (exercise UUID, freeWeightTag), so barbell and dumbbell records never merge.

**Blocked by:** 03.

**Status:** resolved

- [x] No UI or SwiftData imports; operates on plain set-record values
- [x] Brzycki tests at reps 1, 12 (counted) and 13 (ignored for records); formula exact: `weight / (1.0278 − 0.0278 × reps)`
- [x] Assisted monotonicity test: at equal assistance, more reps never ranks worse; lower assistance beats higher at same reps
- [x] Mixed-unit tie test: 100 lb vs 45.5 kg resolved via normalizedKg; displayed as entered
- [x] Draft/incomplete/invalid sets and warmups contribute nothing; failure sets contribute
- [x] Volume: dumbbell entries not doubled; assisted/bodyweight excluded

**Resolution (2026-08-08):** Implemented in `WorkoutTracker/Domain/RecordsMath.swift` (Foundation-only). `RecordSetInput` mirrors a completed set plus its entry's context snapshot (loadType, exercise/machine/model UUIDs, freeWeightTag, set type, reps, as-entered value+unit, normalizedKg, completedAt). `RecordsMath` provides: `isEligible` (completed, positive reps, warmups out, failure in; weighted > 0, assisted ≥ 0, bodyweightPlus ≥ 0, bodyweight load ignored); `outranks` (normalizedKg with per-load-type direction, then more reps, then earliest completedAt); `repCountBests` (1–12 cap, weight-keyed tables only); `mostRepsRecord` (bodyweight, uncapped); `brzyckiE1RMKg`/`bestE1RM` (weighted only, reps ≤ 12, exact formula); `totalVolumeKg` (Σ normalizedKg × reps, weighted working+failure only — no dumbbell special-casing, so nothing doubles); `groupKeys`/`grouped` (machine/model/exercise UUIDs; machineless → (exercise, freeWeightTag), so barbell and dumbbell never merge). Results (`RecordAchievement`, `E1RMRecord`) carry the as-entered value+unit. TDD: 22 tests in `WorkoutTrackerTests/RecordsMathTests.swift` cover every checkbox (incl. exact mixed-unit tie → earliest wins, zero assistance/zero added eligibility, tag-grouping separation) — full suite 74 tests `** TEST SUCCEEDED **`.
