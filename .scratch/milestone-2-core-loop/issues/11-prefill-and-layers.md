# 11 — Same-machine prefill & layered previous performance

**What to build:** Real history queries (grouping by snapshot UUIDs, D23) replace sample data. Prefill: when an entry gets its machine, each set row's input fields arrive populated from the matching set of the most recent **finished** workout containing this exercise on this **machine instance** — completed sets only, matched per set-type in order (nth working set ↔ nth previous working set, warmups likewise). The row's completion stays false: **one tap on the checkmark logs a repeat set**. A user-edited (dirty) row is never overwritten by a late query. Fallback layers are reference-only in the previous-performance sheet: layer 2 = same equipment model elsewhere (via snapshot model UUIDs), layer 3 = exercise anywhere, labeled not-comparable; neither ever prefills.

**Blocked by:** 07.

**Status:** ready-for-agent

- [ ] Layer-selection + prefill logic in `Domain/`, no UI imports, tested against fixture stores
- [ ] One-tap test: machine with history → row prefilled (value, unit, reps as entered), completed == false, single completion tap persists it
- [ ] No-history machine prefills nothing; fallback layers still display
- [ ] Type-aware index matching test: previous session W,1,2,3 vs today 1,2 → today's set 1 gets previous working set 1, not the warmup
- [ ] Dirty-row test: user types a weight → async prefill result discarded for that row
- [ ] Travel-case test: same model UUID at another gym appears in layer 2 with its own as-entered units
- [ ] Free-weight context: prefill/layer-1 key for machineless entries is (exercise UUID, freeWeightTag) — barbell history never prefills a dumbbell entry
- [ ] Determinism: if the source workout has multiple matching entries, the last by entry order wins
