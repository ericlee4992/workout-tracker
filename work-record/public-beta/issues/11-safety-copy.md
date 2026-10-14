# 11 — Automatic safety copy before an update changes stored data

Type: task
Status: ready-for-agent — the user's request, 2026-10-13
Blocked by: —
Implementer: Claude; Reviewer: Codex (visible Orca terminal), to "clear".
Branch: `ericlee4992/beta-11-safety-copy` off `main`.
Spec: [spec.md](../spec.md) → *Data safety*. Related: DEVELOPMENT → *When a backup is required*; D28 (export).

## Why (the user, 2026-10-13)

Testers cannot make backups before each TestFlight update. The developer's Gate S covers only the developer's phone;
updates that change what the phone stores (a SwiftData schema or migration change) need protection for everyone.

## Goal

Before the app opens its store with a new data format for the first time, it saves a complete copy of the user's
data on the phone, so a failed or wrong migration can be undone — without the user doing anything.

## To decide in the design (with the user)

- **What the copy is:** the store files themselves (the `.store`, `-wal`, `-shm` copied while closed) and/or the
  app's JSON export (D28: the user's data, readable, restorable with Import). Likely both: the files for an exact
  restore, the JSON as a portable fallback.
- **When:** only when the stored data format version changes (a recorded schema version vs the build's), never on
  ordinary launches; also before Import replaces data, if that is not already protected.
- **Where and how long:** Application Support (included in the iPhone's own iCloud/computer backup) or Documents (visible
  in the Files app); keep the last N copies or the last N days; never sent anywhere.
- **Restore path:** Settings → a "Restore previous data" row shown only when a copy exists, with a confirmation; or
  restore from the Files app via Import.
- **Space:** the user's store is about 27 MB today; copies must not grow without bound.

## Acceptance (draft)

- [ ] A simulated format change on the Simulator makes exactly one copy before the store opens; an ordinary launch
      makes none.
- [ ] Restoring the copy brings back every row (`compare_stores.py` against the pre-update capture).
- [ ] The copy never leaves the phone; old copies are pruned as decided.
- [ ] Codex clear.

## Comments
