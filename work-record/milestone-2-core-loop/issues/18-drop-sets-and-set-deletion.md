# 18 — Drop sets & discoverable set deletion

**What to build:** Two user-requested changes (2026-08-10).

**Blocked by:** None — 17 is resolved.

**Status:** resolved

## A — Drop set as a fourth set type (D26, amends D12)

`SetType` gains `drop`, marker `D`. Semantics are locked in D26:

- **Records & volume:** a drop set counts exactly like working/failure. Only warmups are excluded. `RecordsMath` eligibility and volume must include it.
- **Rest timer:** completing a drop set does **not** auto-start the timer (a drop set is performed without rest). The other three types are unchanged (D22: warmup duration for warmups, working duration for working and failure).
- **Prefill:** ticket 11's type-aware index matching treats `drop` as its own sequence, exactly as warmup and working already are — the nth drop set matches the previous session's nth drop set.
- **Display:** `D` marker in the active workout and in history detail, visually distinct from `W` (orange) and `F` (red). Pick a colour that doesn't collide.
- The set-type menu (E5) lists all four with the same checkmarked style.

- [x] `SetType.drop` added; marker `D`; menu offers it
- [x] Records/volume include drop sets — unit tests per load type
- [x] Completing a drop set starts no rest timer; the other types still do — unit test
- [x] Prefill matches drop sets to previous drop sets — unit test
- [x] History detail renders the `D` marker

## B — Discoverable set deletion

Deleting a set already works (`WorkoutSession.deleteSet`, exposed via a menu on the row) but is
undiscoverable — the user asked for the capability, not knowing it existed. That *is* the fault.

- [x] Swipe-to-delete on a set row, in addition to the existing menu action
- [x] Deleting a completed set updates the entry's derived state correctly (records/volume recompute; carry-forward now seeds from the new last completed set)
- [x] Deleting the last remaining set of an entry leaves the entry intact and usable (does not orphan or auto-delete it mid-workout)
- [x] UI test covering swipe-to-delete

## Acceptance

- [x] All boxes ticked
- [x] `xcodebuild test` green (unit + UI)
- [x] No regression in ticket 17's guarantees (loggable-set guard, carry-forward, empty-workout discard)
