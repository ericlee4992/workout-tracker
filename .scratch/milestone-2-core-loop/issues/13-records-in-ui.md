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
