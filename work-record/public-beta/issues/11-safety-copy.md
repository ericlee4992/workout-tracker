# 11 — Automatic safety copy before an update changes stored data

Type: task
Status: **deferred** (the user, 2026-10-14) — build together with the first update that changes the stored data format
Blocked by: —
Implementer: Claude; Reviewer: Codex (visible Orca terminal), to "clear".
Branch (when built): `ericlee4992/beta-11-safety-copy` off `main`. The guard: `ericlee4992/beta-11-schema-guard`.
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

## Decision — 2026-10-14: deferred; a format guard now

Asked the four design questions (location, copies kept, in-app restore/share, a recovery screen instead of the launch
crash), the user asked "is that really necessary?". Claude's assessment, accepted ("yes, go ahead"):

- No stored-format change is planned (spec → *Data safety*: account, session and training profile live on the server and
  in the Keychain / `@AppStorage`).
- The copy needs nothing on testers' phones in advance: the store-changing build itself copies the store before its
  first open. So it can be built in that same release.
- The real risk is an *accidental* format change. **`WorkoutTrackerTests/StoreFormatGuardTests`** pins the fingerprint
  of the shipped format — SHA-256 over Core Data's per-entity version hashes from
  `NSManagedObjectModel.makeManagedObjectModel(for: WorkoutTrackerStore.modelTypes)`, the hashes that decide whether
  SwiftData migrates — and fails with instructions to build this ticket first. A second test shows one more model changes
  the fingerprint. The pinned value `9569f6fd…` is every TestFlight build's format: no production `@Model` file changed since build 1
  (`936b18f`; `git diff --stat 936b18f..HEAD` on Models.swift, Cardio.swift and WorkoutSensorSample.swift — the three
  production model files — is empty; equal source, not a measurement of each shipped binary).

Facts for when it is built (found 2026-10-14): no `VersionedSchema`/migration plan (SwiftData's automatic migration);
no Import (the JSON export cannot be restored in the app), so the copy that matters is the store files; restoring an old
copy under the same build re-runs the same migration, so restore is for a fixed build or sending to the developer;
`WorkoutTrackerApp.init` `fatalError`s when the store will not open (a crash on every launch) — the recovery screen
question. The exact "would this open migrate?" check: the store's metadata vs the model
(`NSPersistentStoreCoordinator.metadataForPersistentStore` + `isConfiguration(withName:compatibleWithStoreMetadata:)`).

**Verification:** StoreFormatGuardTests + SchemaTests 5/5 (`/tmp/wt-floodlight/results/11/guard2.xcresult`); with a
placeholder value the guard failed with the current fingerprint in its message (`guard1.log`). Note: `xcodebuild`
did not exit after a run with failures (both times today) — the result is in the log; kill it after the verdict line.

**Codex round 1 (`codex-review-11.md`): not clear — fixed.** #1 (P2): the structure fingerprint alone missed stored
data that is not table structure. The guard now has three layers: the structure fingerprint (plus indexes, which Core
Data's hash excludes; none exist, so the pin is unchanged); every stored enum's raw values pinned (12 types — renaming or
removing one strands old rows; adding one is unreadable by an older build; round 2 adds RoutineEquipment and MuscleFamily → 14); fixed JSON samples of the five `Data`
payloads (`intervalsData`, `routeData`, `distanceSpansData`, both `cardioPlanData`) that must decode, and today's encoder
must still write their shape. First-launch row rewrites remain outside any test (DEVELOPMENT says so). The failure
message no longer claims a migration "will" happen; the probe goes through the same fingerprint function. #2 (P3):
STATE's stale "design questions first" lines updated.
Verification: StoreFormatGuardTests 4/4 (`guard3.xcresult`). Mutation check (`mut.log`, reverted): `WeightUnit.kg` stored
as "KG" and `CardioInterval.start` encoded as "begin" → the enum and payload tests failed, the structure test passed (the
gap the review found).

**Codex round 2 (`codex-review-11b.md`): not clear — fixed.** #1 (P2) two enums stored through plain String columns were
missing: `RoutineEquipment` (`WorkoutTemplate.confirmedEquipment`) and `MuscleFamily`
(`AppPreferences.exerciseBrowseMuscleGroup`) — added (14 types; `AppPreferences.modelBrowseMuscleGroup` holds a catalog
body-area name, D24, and is documented as not pinned). #2 (P2) the payload checks now read and write through the app's
own paths (`CardioSegment.intervals`/`route`/`distanceSpans`, `plannedCardio` on both `WorkoutTemplate` and `Workout`) in
an in-memory store, with samples that omit optional keys (a span without a selected source, a plan without distance or
segment). #3 (P2) `CardioDistanceSource` is now `CaseIterable` (production, no behaviour change) so an added source is
seen. #4 (P3) the spec no longer says "any format change". #5 (P3) STATE's ticket-04 lines updated to merged.
Verification: StoreFormatGuardTests 4/4 (`guard4.xcresult`). Mutation (`mut3.log`, reverted): the `intervals` getter
decoding dates as seconds since 1970 → the payload test failed at the production read. An added `CardioDistanceSource`
case does not compile without handling (`mut2.log`: an exhaustive `switch` at Cardio.swift:37), and `CaseIterable` lists
it for the enum test.

## Comments
