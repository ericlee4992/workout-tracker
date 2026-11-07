# N1 — Automatic safety copy before a stored-format change

Type: task
Status: **proposed** (2026-11-07) — awaiting the user's approval; this is [public-beta ticket 11](../../public-beta/issues/11-safety-copy.md), now scheduled
Blocked by: S4 (Phase 1 done first)
Implementer: Claude; Reviewer: Codex (visible Orca terminal), to "clear".
Branch (when built): `ericlee4992/nutrition-01-safety-copy` off `main`.
Spec: [nutrition](../spec.md); [public-beta spec → Data safety](../../public-beta/spec.md). Related: D28, DEVELOPMENT →
*When a backup is required*; `StoreFormatGuardTests` (ticket 11's guard, in `main`).

## Why

N2 is the first update since the beta began that changes what the phone stores. Testers cannot make backups; the
user deferred ticket 11 "until the first stored-format change" (2026-10-14). It must ship with or before N2 — in the
combined release it ships in the same build.

## Goal

Before the app opens its store with a new data format for the first time, it saves a complete copy of the user's data
on the phone, without the user doing anything, and offers a way back.

## To decide with the user when the ticket starts (Claude's proposals)

| Question | Proposal |
|---|---|
| What the copy is | Both: the store files (`.store`, `-wal`, `-shm`, copied before the container opens) for an exact restore, and the D28 JSON export as a portable fallback |
| When | Only when the recorded stored-format version differs from this build's; never on ordinary launches. Also before Import replaces data, if that is not already protected |
| Where | Application Support / `SafetyCopies/` (included in the iPhone's own iCloud or computer backup, not shown in Files) |
| How long | The last 2 copies; older ones deleted after a successful copy |
| Restore | Profile → "Restore data from before the update" (shown only when a copy exists), with a confirmation that names the copy's date; restore replaces the current store and relaunches |
| Space | The user's store is about 27 MB; two copies plus JSON ≈ 80 MB at most today |

## Acceptance

- [ ] A simulated format change on the Simulator makes exactly one copy before the store opens; an ordinary launch
      makes none.
- [ ] Restoring the copy brings back every row (`compare_stores.py` against the pre-update capture).
- [ ] A failed copy (disk full, simulated) does not open the new format silently: the app tells the user and offers to
      continue or quit (wording to approve).
- [ ] The copy never leaves the phone; old copies are pruned as decided.
- [ ] Codex clear.

## Verification scope

Persistence → unit tests for the version check, copy, prune and restore; a Simulator rehearsal with a real old store
(WT-Backup-01, erased after use); the Settings/Profile UI test for the restore row.

## Code map

- Container creation: `WorkoutTracker/App/` (the app's `ModelContainer`); `Domain/ExportJSON.swift`, `ExportSnapshot.swift`.
- `WorkoutTrackerTests/StoreFormatGuardTests.swift`.

## Progress

Not started.

## Comments
