# 04 — Dumbbell movements as their own exercises

Status: resolved — awaiting Codex review
Blocked by: 03
Covers the catalog half of user ask **4**.

## What to build

**A. Catalog rows** (bump `SeedCatalog.json` version, D24), each tagged `dumbbell`, `weighted`,
correct muscle group: Dumbbell Bench Press, Dumbbell Incline Press, Dumbbell Decline Press,
Dumbbell Shoulder Press, Dumbbell Row, Dumbbell Romanian Deadlift, Dumbbell Lunge, Bulgarian Split
Squat, Dumbbell Shrug, Dumbbell Floor Press, Dumbbell Hip Thrust, Dumbbell Fly, Dumbbell Lateral
Raise, Dumbbell Goblet Squat. The user was shown this list and asked to prune; treat it as
approved unless a comment below says otherwise.

**B. A one-time history move.** The user has real sets logged under a barbell-named exercise
(e.g. Bench Press) with `freeWeightTag == .dumbbell`. Those must land under the new dumbbell
exercise. This is a MIGRATION, not a rename: D23 forbids reinterpreting a snapshot silently, so
it must:
- run once, keyed on the catalog version bump, and be idempotent;
- rewrite BOTH the relationship and the snapshot (`snapshotExerciseID`, `snapshotExerciseName`)
  on affected entries — and only entries whose snapshot tag is `.dumbbell` and whose snapshot
  exercise has a mapped dumbbell counterpart;
- record what it did (`Workout.historyEditedAt`? No — the user did not edit; use a migration log
  line in the seeder and a count surfaced once in Settings), so the move is visible, not silent;
- leave presets attached (a grip preset is a property of the movement and travels — D37).

**C. The equipment sheet** should stop offering Dumbbell under an exercise whose counterpart
exists, and instead offer "Log as Dumbbell Bench Press instead" — otherwise the split re-grows.

## Acceptance criteria

- `LegacyStoreMigrationTests` opens the fixture AND a test proves the move: a fixture entry under
  Bench Press + dumbbell tag ends under Dumbbell Bench Press with records/chart following it.
- The move never touches barbell-tagged or machined entries; a test pins it.
- Running the seeder twice moves nothing the second time.
- The mapping table (barbell exercise → dumbbell exercise) is data in `Domain/`, unit-tested for
  no duplicate targets.
- **Before installing:** a fresh export of the real history is on iCloud Drive.


## Resolution (2026-09-04)

**A. Catalog v5** — 14 dumbbell rows added in `scripts/generate_seed_catalog.py` (ids 77–90,
allocated by the generator; `--check` passes). 90 exercises, 15 tagged dumbbell.

**B. The move** — `Domain/DumbbellCounterparts.swift` is the mapping, by catalog UUID (names are
mutable seeded fields): Bench Press, Incline/Decline Bench Press, Chest Fly (Pec Deck), Overhead
Press, Lateral Raise, Bent-Over Row, Shrug, Lunge, Hip Thrust → their dumbbell rows. **Deadlift,
Squat and Preacher Curl are deliberately unmapped**: a dumbbell-tagged Deadlift is not necessarily a
Romanian deadlift, and guessing is the fabricated context D23 forbids; those sets stay where they
are, still tagged Dumbbell. `Domain/DumbbellHistoryMove.swift` rewrites the relationship AND the
snapshot identity on qualifying entries — finished workouts, frozen snapshot, snapshot tag
Dumbbell, mapped source — and nothing else (numbers, tag, preset + its snapshot, `historyEditedAt`
untouched). Idempotent by construction. `CatalogSeeder.reconcile` runs it once when the stored
version crosses below 5 → ≥5, and records sets/date on `AppPreferences`
(`dumbbellHistoryMovedSets/At`); `AppSettingsSection` shows "History update: N sets moved to
dumbbell exercises · date". The ticket's "migration log line" became this record — a log nobody
reads is not visibility.

**C. The equipment sheet** — for an exercise with a counterpart, the Dumbbell row becomes "Log as
Dumbbell Bench Press instead" (`logAsCounterpart`), calling `WorkoutSession.switchExercise`: a
draft entry is re-filed in place (preset dropped, D37); a frozen one splits into a new entry for the
counterpart with the draft rows, like `chooseEquipment` (D19).

**Tests.** `DumbbellExercisesTests` (10): every pair points at real catalog rows with the right
tags and equal load types; no duplicate sources/targets and no chaining; catalog is v5 with the
rows; the move moves only the dumbbell-tagged mapped finished entry (barbell, machined, running,
unmapped untouched; `historyEditedAt` nil); second run moves nothing; records and chart follow
(group keys under the new id, none under the old); the seeder crossing v4→v5 moves once and records
it, and a re-run at 5 leaves the record alone and does not move later dumbbell-tagged sets; a fresh
store records nothing; draft switch in place; frozen switch splits. `LegacyStoreMigrationTests`
gains the nil-record gate. `DumbbellCounterpartUITests` (1): Bench Press offers the counterpart and
not the tag; tapping it re-files the entry. **617 unit green; UI: counterpart (1), barbell (2),
core loop (9), presets (2) green.** Screenshot `equipment-counterpart`.

**XCUITest note worth keeping:** tapping the identified picker ROW for "Bench Press" did not
register with the keyboard up (the picker stayed open; diagnosed by screenshot) while tapping the
row's static text did. STATE already records this quirk for a second exercise; it bites the first
one too when the search has several matches.

**Not done, deliberately:** "log later dumbbell-tagged sets" — a set logged under Bench Press +
Dumbbell AFTER the move (only reachable by ignoring the counterpart row, e.g. via a template) stays
there. The sheet no longer offers the path, so this should not grow; if it does, the move can be
re-keyed. **Before installing:** a fresh export of the real history to iCloud Drive — this build
rewrites snapshots on the phone's only copy.


## Codex review 04 — response (2026-09-04)

`codex-review-04.md`: 2 critical, 4 high, 4 medium, 1 low. It was right on every structural
point; the first cut of the move was wrong in design, not detail. The corrected design is now
**D51**, and the code follows it:

- **Locked decisions reopened by stealth (critical).** D51 records the reopening of D19/D23/D47 for
  exactly this reclassification and why it is provenance, not an edit; D19, D23 and D47 carry
  pointers. My first response's "leave `historyEditedAt` nil and note it in Settings" was the
  claim without the decision.
- **Presets stranded (critical/high).** The entry's preset is re-homed: a same-named preset on the
  counterpart is found or created (case-insensitive), and BOTH the relationship and
  `snapshotPresetID` move; `snapshotPresetName` is unchanged; the source keeps its own preset for its
  own history. Two moved entries share one preset; an entry whose preset was since deleted is
  matched by its snapshot name. Tested. The ticket's "leave presets attached" line was the error —
  a grip travels by moving WITH the movement, not by staying pinned to the old one.
- **One-shot gate misses late history (critical).** The move now runs on every launch from catalog
  5, including the seeder's fast path, gated by one `fetchCount` over entries whose snapshot still
  names a source. Idempotent because no target is a source. Tested: late-arriving rows move on the
  next reconcile, on the fast path too, and the record accumulates.
- **Audit record dropped from the backup (high) / provenance.** Per-row `reclassifiedAt` +
  `reclassifiedFromExerciseName` on `ExerciseEntry`; exported (JSON schema **7**, CSV column 37
  `reclassifiedFrom`); shown under the exercise in History detail. Preferences record exported too.
- **Settings read `first` (high/medium).** Reads the canonical row.
- **Superset severed by a frozen switch (high).** `split` carries `supersetGroupID` to the new
  entry (for equipment splits too — the same severing applied there) and prunes orphans. Tested.
- **Zero-result run indistinguishable from never-ran (medium).** `dumbbellHistoryCheckedAt` is
  stamped on the first run regardless; `movedSets` is cumulative and nil until something moves.
- **Missing counterpart row fell back to the tag (medium).** The row is disabled and named from the
  mapping (`Pair.targetName`); the tag is never offered for a mapped movement.
- **`switchExercise` overbroad (low).** Now `switchToDumbbellCounterpart(of:)`: resolves the
  counterpart itself, refuses otherwise, tag is `.dumbbell` by definition. Tested refusal.
- Added tests for uncaptured, deleted and relationship-less rows. The commit title "no way back" was
  false as Codex said — the gate was the way back; it no longer exists.

**623 unit green; UI: counterpart (1), history editing (2), export (1) green.**


## Codex review 04b — response (2026-09-04)

`codex-review-04b.md`: round-1 criticals confirmed closed; 2 high (one defect), 3 medium (two are
one defect). All acted on, one only partially and said so.

- **Preset matching weaker than the app's own rule (high).** True. The move now uses
  `ExercisePresets.isDuplicate` (case, diacritics AND spacing) and creates with `cleanedName`; the
  test's orphan is spelled `"  WIDE   GRIP "` and re-homes onto "Wide grip".
- **Gate not cheap once barbell history exists (medium ×2).** Partially closed, honestly: the
  persisted predicate now states every qualifier the store can express (source id, frozen,
  finished workout, not yet reclassified). **The tag cannot be pushed down** — SwiftData refuses a
  captured `EquipmentTag` in a `#Predicate`, optional or not; the first attempt crashed launch —
  so finished barbell rows under a source exercise still pass the count and are rejected in Swift,
  with `propertiesToFetch` limited to the tag and exercise id. That is the honest ceiling without a
  persisted shadow flag, which would be a schema field existing only to speed a no-op; declined.
  The test was renamed to say what it proves (moves nothing) rather than what it cannot (gate zero).
- **Stale singleton group carried through a split (medium).** True, and mine. `split` carries the
  id only when `Supersets.isGrouped` — a genuine run of two or more — and prunes regardless. Test:
  an orphaned one-member id on the source yields nil on both entries.

**625 unit green; UI: counterpart (1), barbell (2) green.**


## Codex review 04c — response (2026-09-04)

`codex-review-04c.md`: dedupe and both superset cases closed; 1 high (a real, order-dependent
defect my full-suite run had passed by luck), 2 medium (one defect).

- **Preset label depended on fetch order (high).** True — Codex's focused runs produced
  "WIDE   GRIP" where mine produced "Wide grip". Candidates are now processed in a total order:
  entries with a LIVE preset first (its current name is the user's label), then earliest capture,
  then id. The re-home test inserts the adverse order; a new test runs four insertion permutations
  and demands one label. Focused suite run three times: 19/19 each.
- **Projection faulted before the tag check (medium ×2).** The tag is now the first and only thing
  read on a projected row; only survivors fetch targets and touch `workout` / `snapshotCapturedAt`.
  Codex verified the platform claim (captured enums refused, optional or not) and that D51's
  "cheap" wording is met at this ceiling — no amendment needed.

**626 unit green.** Domain-only change; the sheet and split are untouched since the last UI runs.
