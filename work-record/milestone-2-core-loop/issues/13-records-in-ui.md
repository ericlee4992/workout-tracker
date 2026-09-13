# 13 — Records surfaced in the UI

**What to build:** The previous-performance sheet shows real records from ticket 12's core at each layer: rep-count bests and (weighted-only) est. 1RM for this machine; same-model and any-equipment layers likewise, labeled per ticket 11's layout. Assisted exercises show "least assistance" records with direction explained; bodyweight shows rep records.

**Blocked by:** 11, 12.

**Status:** resolved

- [x] Sheet shows per-layer records computed from the store, replacing all remaining sample-data strings
- [x] Weighted: rep-count bests + e1RM labeled "(Brzycki, est.)"; assisted: least-assistance bests, no e1RM; bodyweight+added: most-added-weight bests, no e1RM; bodyweight: rep bests, no e1RM
- [x] Free-weight layers keyed by (exercise, tag): barbell and dumbbell records shown separately
- [x] Values display as entered (unit preserved); comparisons via normalizedKg
- [x] Empty layers render their labeled empty states, not blank sections

## Comments

Resolved 2026-08-08. `PerformanceHistory.recordSummary` bridges persisted finished-workout
snapshots into the pure ticket-12 `RecordsMath` inputs. It selects the machine, model,
exercise, or `(exercise, freeWeightTag)` `RecordGroupKey` for each UI layer, so free-weight
records never merge tags; historical load type, context UUIDs, values, units, normalized kg,
set types, and timestamps all come from snapshots/completed sets. `RecordLayerSummary`
exposes only the record forms valid for the current load type.

PreviousPerformanceSheet now renders a records block inside every labeled layer: weighted
per-rep bests plus `e1RM (Brzycki, est.)` with its as-entered source set; assisted
least-assistance direction; bodyweight+added rep tables; plain-bodyweight most reps; and a
labeled empty state. Record achievements show their original value/unit while comparison
continues through normalized kg in RecordsMath. Three focused bridge tests cover distinct
machine/model/exercise winners with mixed as-entered units, strict barbell/dumbbell isolation,
and all non-weighted load-type presentation summaries.

Post-review fixes 2026-08-08 (cross-review, D23 breach + empty-state coverage).
`recordSummary` took its load type from the *live* exercise (`entry.exercise?.loadType`)
while `RecordsMath` filters every input by that input's *snapshot* load type. After a catalog
loadType edit the two disagreed, so every past record at every layer silently rendered the
empty state — exactly what D23 forbids. The summary's load type is now derived from the
layer's own inputs (dominant snapshot load type, ties to the most recently completed set),
falling back to the entry's own snapshot load type when the layer has no history; no
historical classification reads a live relationship. The layer-2/layer-3 key corrections are
recorded in ticket 11. The previously untested criterion "empty layers render their labeled
empty states, not blank sections" is now covered: the two empty-state strings moved out of
`PreviousPerformanceSheet` onto `PerformanceLayerKind`
(`emptyHistoryMessage(hasMachine:)`, `emptyRecordsMessage`) so they are unit-testable, and
`emptyLayersCarryLabeledEmptyStatesNotBlankSections` asserts a history-free machine entry
yields all three layers, each with a nil snapshot, an empty summary, and its own distinct
labeled message. New regression tests in `RecordsSurfaceTests`:
`weightedRecordsSurviveALiveLoadTypeEdit`, `assistedRecordsSurviveALiveLoadTypeEdit`,
`anyEquipmentLayerIsExerciseWideForAFreeWeightEntry`,
`sameModelLayerExcludesTheCurrentGymsOwnSets`. The existing
`freeWeightRecordLayersNeverMergeBarbellAndDumbbell` asserted the layer-3 defect (any-equipment
== barbell-only) and was corrected to expect exercise-wide records.
