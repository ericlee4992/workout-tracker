# 11 — Same-machine prefill & layered previous performance

**What to build:** Real history queries (grouping by snapshot UUIDs, D23) replace sample data. Prefill: when an entry gets its machine, each set row's input fields arrive populated from the matching set of the most recent **finished** workout containing this exercise on this **machine instance** — completed sets only, matched per set-type in order (nth working set ↔ nth previous working set, warmups likewise). The row's completion stays false: **one tap on the checkmark logs a repeat set**. A user-edited (dirty) row is never overwritten by a late query. Fallback layers are reference-only in the previous-performance sheet: layer 2 = same equipment model elsewhere (via snapshot model UUIDs), layer 3 = exercise anywhere, labeled not-comparable; neither ever prefills.

**Blocked by:** 07.

**Status:** resolved

- [x] Layer-selection + prefill logic in `Domain/`, no UI imports, tested against fixture stores
- [x] One-tap test: machine with history → row prefilled (value, unit, reps as entered), completed == false, single completion tap persists it
- [x] No-history machine prefills nothing; fallback layers still display
- [x] Type-aware index matching test: previous session W,1,2,3 vs today 1,2 → today's set 1 gets previous working set 1, not the warmup
- [x] Dirty-row test: user types a weight → async prefill result discarded for that row
- [x] Travel-case test: same model UUID at another gym appears in layer 2 with its own as-entered units
- [x] Free-weight context: prefill/layer-1 key for machineless entries is (exercise UUID, freeWeightTag) — barbell history never prefills a dumbbell entry
- [x] Determinism: if the source workout has multiple matching entries, the last by entry order wins

## Comments

Resolved 2026-08-08. `Domain/PreviousPerformance.swift` selects only completed sets
from finished workouts and groups exclusively by D23 snapshot UUIDs/tags. Prefill picks
the most recent finished workout, the last matching entry by scalar order within that
workout, then the nth set of the same exact set type. `applyPrefill` preserves the original
value/unit/reps/normalized kg while leaving completion nil and accepts a last-moment dirty
guard. Machine contexts key on (exercise snapshot UUID, machine snapshot UUID);
machineless contexts key on (exercise snapshot UUID, free-weight snapshot tag). The service
also exposes latest reference snapshots and all completed values at exact-equipment,
same-model-other-gym, and exercise-wide layers for ticket 13.

SetRowView now loads its PREVIOUS label and untouched input values whenever equipment,
type, or type-relative position changes; focused edits mark the row dirty so a delayed
refresh cannot overwrite typing. PreviousPerformanceSheet renders real snapshot equipment,
gym/date, completed sets, and as-entered units with explicit prefill/reference footers and
labeled empty states. Seven focused tests cover one-tap completion, no-history fallback,
type-aware matching, dirty rejection, travel units, barbell/dumbbell isolation, and duplicate
entry determinism.

Post-review fixes 2026-08-08 (cross-review, records layer keys). Two layer definitions in
`recordSummary` did not match this ticket. Layer 3 keyed machineless entries by
`(exercise, freeWeightTag)`, byte-identical to layer 1, so a barbell entry's "Any equipment"
records were just its barbell records and exercise-wide history never appeared; it now always
keys `.exercise(exerciseID)` ("exercise anywhere"). Layer 1 keeps the tag-specific key, so
barbell and dumbbell still never merge. Layer 2 keyed `.model(modelID)`, which includes the
current gym's own sets — contradicting both its "Same model elsewhere" header and the
snapshot list beside it; the model group is now filtered by the current gym id, mirroring the
snapshot list's `snapshotGymID != gymID`. `RecordSetInput` gained a snapshot `gymID`
(populated in `recordInputs`) to make that possible; it is deliberately not a group key,
since a model group legitimately spans gyms. The live-catalog reads in `currentExerciseID`,
`layerOneMatch`, and `layers` are unchanged: they answer "which exercise/equipment is the
user on right now" for the draft entry, which is identity, not history classification.
