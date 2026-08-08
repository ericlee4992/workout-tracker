# 07 — PR computation (Brzycki, load-type direction)

**What to build:** Records become real: best weight per rep count (capped at 12 reps) and estimated 1RM via Brzycki, computed at all three layers (machine instance, equipment model, exercise). Load-type direction is respected — for assisted exercises the best is the *lowest* assistance — and warmup sets are excluded from all records and volume. Results appear in the previous-performance sheet.

**Blocked by:** 06.

**Status:** ready-for-agent

- [ ] Pure functions in Domain/, unit-tested: rep-count bests, Brzycki e1RM (`weight / (1.0278 − 0.0278 × reps)`), 12-rep cap
- [ ] Assisted exercises invert comparison (lower normalizedKg wins); bodyweight+added compares added weight
- [ ] Warmup sets never contribute to records or volume
- [ ] Mixed-unit history compares via normalizedKg but displays each record as entered
- [ ] Tests cover: mixed units, assisted inversion, warmup exclusion, reps > 12 ignored for records
