# 12 — Records computation core

**What to build:** Pure `Domain/` records math per D17/D20/D21, keyed on **snapshotted** loadType and context (never live catalog rows). Eligibility is load-type-specific: completed sets (completedAt != nil), positive reps, warmups excluded, failure sets included; load must be finite and — weighted: > 0; assisted: ≥ 0 (0 = unassisted); bodyweightPlus: ≥ 0 (0 = plain); bodyweight: load ignored. Ties resolve to the earliest achieving set. Per load type: weighted → best weight per rep count (1–12, >12 ignored) + Brzycki e1RM; assisted → least assistance per rep count, no e1RM; bodyweightPlus → most added weight per rep count, no e1RM; bodyweight → most reps (uncapped), no e1RM; the 12-rep cap applies only to weight-keyed tables. Volume = Σ(normalizedKg × reps) over eligible working+failure sets of weighted exercises only. Comparisons use normalizedKg; results carry the as-entered value+unit for display. Grouping keys from snapshots: machine UUID / model UUID / exercise UUID — and for machineless entries, (exercise UUID, freeWeightTag), so barbell and dumbbell records never merge.

**Blocked by:** 03.

**Status:** ready-for-agent

- [ ] No UI or SwiftData imports; operates on plain set-record values
- [ ] Brzycki tests at reps 1, 12 (counted) and 13 (ignored for records); formula exact: `weight / (1.0278 − 0.0278 × reps)`
- [ ] Assisted monotonicity test: at equal assistance, more reps never ranks worse; lower assistance beats higher at same reps
- [ ] Mixed-unit tie test: 100 lb vs 45.5 kg resolved via normalizedKg; displayed as entered
- [ ] Draft/incomplete/invalid sets and warmups contribute nothing; failure sets contribute
- [ ] Volume: dumbbell entries not doubled; assisted/bodyweight excluded
