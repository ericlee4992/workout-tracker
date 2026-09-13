# Milestone 3 — CSV / JSON export

Written 2026-08-11. Closes the `docs/DECISIONS.md` open item "Export column layout / JSON
schema versioning — milestone 3".

## Why now

The user's entire training history exists in exactly one place: the SwiftData store on one
iPhone, signed with a certificate that expires every 7 days. There is no sync, no backup, and
no way to read the data off the device. Export is the backup story (SPEC "Technical
direction") and the data-ownership promise (D5: stable IDs + export keep public release open).

## Two exports, two jobs

| | CSV | JSON |
|---|---|---|
| Job | read it, chart it, keep it in a spreadsheet | restore it, re-import it, hand it to another tool |
| Shape | one row per set, fully denormalized | the object graph, versioned |
| Audience | a human with Numbers/Excel | a program (including a future importer) |
| Fidelity | every logged set with its full equipment context | everything the user created |

Neither is lossy in the dimensions SPEC calls out for our export (line 88): **explicit units,
stable UUIDs, set types, full equipment context** — the four things Strong's CSV lacks.

## Decisions this milestone makes

Recorded as **D28–D32** in `docs/DECISIONS.md` (D30 and D31 amended 2026-08-11 after the Codex
cross-review; the amended wording there wins over the summaries below).

- **D28 — Export contains the user's data, not the shipped catalog.** Seeded exercises and
  equipment models appear only where the user's data references them (a machine's model, a
  history snapshot, a template item, a gym-exercise memory, a rest override); the export
  records `seededCatalogVersion` so the rest is reproducible from the app itself. Exporting all
  1877 seeded models would make a personal backup mostly someone else's catalog.
- **D29 — Weights export as entered *and* normalized, never converted for display.** Three
  columns/fields: `weight`, `unit`, `weightKg`. No ≈ values anywhere in an export — the ≈ marker
  is a UI honesty device (D9/D25); a file gets both exact numbers instead.
- **D30 — Nothing is silently dropped.** Uncompleted (draft) sets and the in-progress workout
  export, flagged (`completed`, `finishedAt` empty). A backup that omits rows is not a backup.
  Consumers filter on `completed` exactly as `RecordsMath` does. *Amended:* JSON is the complete
  backup; CSV is a complete ledger of **sets**, so an object holding no set has no row there.
- **D31 — Timestamps are ISO 8601 with the device's UTC offset and fractional seconds**
  (`2026-08-11T18:30:00.123+09:00`), never bare UTC. A workout log is a record of local
  time-of-day; the offset keeps both the instant and the wall clock, and sub-seconds keep
  same-second `updatedAt` tie-breaks (`CanonicalRow`) intact. *Amended:* filenames carry local
  wall time only.
- **D32 — CSV is RFC 4180 with a UTF-8 BOM, and user text is exported verbatim.** CRLF line
  endings, quotes doubled inside quoted fields. The BOM is there because the gym and exercise
  names in this store are not all ASCII and Excel mojibakes UTF-8 without it. Verbatim means no
  formula-injection prefixing: mangling the user's own notes to defend them from themselves is
  the wrong trade for a personal backup.

## CSV format

`workout-tracker-YYYY-MM-DD-HHmm.csv`, one header row, one row per `SetRecord`.

Rows are ordered by workout `startedAt` (ascending, ties broken by workout id), then entry
`order`, then set `order` — deterministic, so two exports of unchanged data are byte-identical.

Context columns read the **entry's D23 snapshot** once it exists, never the live rows: a renamed
gym must not rewrite last month's rows. A draft entry has no snapshot yet and reports live
equipment (see the two limits below the table). Empty fields are empty (no `null`, no `-`).

| # | Column | Source | Notes |
|---|---|---|---|
| 1 | `workoutID` | `Workout.id` | groups rows into a session |
| 2 | `workoutStartedAt` | `Workout.startedAt` | D31 |
| 3 | `workoutFinishedAt` | `Workout.finishedAt` | empty = still active (D30) |
| 4 | `workoutName` | `Workout.sourceTemplateName` | empty when not from a template. Unchanged in v6 — the typed name is column 36 |
| 5 | `workoutNotes` | `Workout.notes` | |
| 6 | `gymID` | `ExerciseEntry.snapshotGymID` | empty = no gym |
| 7 | `gymName` | `ExerciseEntry.snapshotGymName` | |
| 8 | `entryID` | `ExerciseEntry.id` | |
| 9 | `entryOrder` | `ExerciseEntry.order` | |
| 10 | `exerciseID` | `snapshotExerciseID` | stable UUID |
| 11 | `exerciseName` | `snapshotExerciseName` | |
| 12 | `loadType` | `snapshotLoadType` | raw value — direction-aware records depend on it |
| 13 | `equipmentTag` | `snapshotFreeWeightTag` | empty when the entry used a machine |
| 14 | `machineID` | `snapshotMachineID` | |
| 15 | `machineLabel` | `snapshotMachineLabel` | |
| 16 | `modelID` | `snapshotModelID` | the catalog UUID history keys on |
| 17 | `manufacturer` | resolved from `modelID` | the one live lookup — the snapshot has no manufacturer field |
| 18 | `modelDisplayName` | `snapshotModelName` | manufacturer **and** model, as the snapshot stores it (`EquipmentModel.displayName`) |
| 19 | `setID` | `SetRecord.id` | |
| 20 | `setOrder` | `SetRecord.order` | |
| 21 | `setType` | `SetRecord.type` | `warmup`/`working`/`failure`/`drop` |
| 22 | `reps` | `SetRecord.reps` | empty while draft |
| 23 | `weight` | `SetRecord.weightValue` | as entered, full precision, `.` separator |
| 24 | `unit` | `SetRecord.weightUnit` | D29 — the column Strong has no answer for |
| 25 | `weightKg` | `SetRecord.normalizedKg` | D29 |
| 26 | `completed` | `completedAt != nil` | `true`/`false` |
| 27 | `completedAt` | `SetRecord.completedAt` | |
| 28 | `presetID` | `snapshotPresetID` | D36 — appended by presets (2026-08-12), empty = no variation recorded |
| 29 | `presetName` | `snapshotPresetName` | |
| 30 | `barWeight` | `SetRecord.barWeightValue` | D39 — appended 2026-08-22, empty = weight entered as a total |
| 31 | `barWeightKg` | normalized `barWeightValue` | D29's rule applied to the bar |
| 32 | `workoutAvgHeartRate` | `Workout.averageHeartRate` | D44 — appended 2026-08-22, empty = no sensor ran |
| 33 | `workoutMaxHeartRate` | `Workout.maxHeartRate` | |
| 34 | `workoutActiveCalories` | `Workout.activeEnergyKilocalories` | system-generated during the session, never computed by the app |
| 35 | `supersetGroupID` | `ExerciseEntry.supersetGroupID` | D48 — appended 2026-08-26, empty = not in a superset |
| 36 | `workoutTypedName` | `Workout.name` | v6 — appended 2026-09-03 (milestone 9, ticket 02), empty = no name typed |
| 37 | `reclassifiedFrom` | `ExerciseEntry.reclassifiedFromExerciseName` | v7 — appended 2026-09-04 (D51), empty = never reclassified |

Columns 32–34 are **workout**-level and repeat on every set row of that workout, the way
`workoutNotes` already does. Empty means *not measured*, never zero (D44). `zoneSeconds` is
JSON-only: it is an array, and a flat ledger of sets has nowhere honest to put one — the same
narrowing D30 makes for objects holding no set.

Columns 30–31 describe **how** column 23 was arrived at, not a component to add to it: `weight` is
the total lifted, bar included, in bar mode exactly as in total mode (D39). A consumer that sums
`weight + barWeight` is counting the bar twice.

Column 17 is the one place the export reads a live row rather than a snapshot: the snapshot
stores `snapshotModelID` and `snapshotModelName` but no manufacturer, so that one is resolved
from the catalog and left empty if the model is gone. Column 18 is the snapshot's own string,
which is `manufacturer + model` — hence `modelDisplayName`, not `modelName` (codex-review).

Two further limits, stated rather than implied:

- **Context columns are the entry's snapshot only once it has one.** A *draft* entry (no set
  completed, D19) has no snapshot yet, so its columns report its live equipment — the machine and
  gym the user just chose. Exporting mid-workout therefore describes the workout in progress.
- **A workout or entry holding no set at all has no CSV row.** One row per set has nowhere to put
  it; the JSON export carries it. D30 says this explicitly.

## JSON format

`workout-tracker-YYYY-MM-DD-HHmm.json`, UTF-8, pretty-printed with sorted keys (diffable,
deterministic).

```jsonc
{
  "schemaVersion": 8,             // bumped on any shape change; older files decode
                                  // 2: presets (D36). 3: bar weight (D39)
                                  // 4: heart-rate summary per workout (D44)
                                  // 5: supersetGroupID, loadTypeUserOverridden, historyEditedAt (D47/D48)
                                  // 6: workouts[].name, the typed title (D50)
                                  // 7: entries[].reclassifiedAt/FromExerciseName + the
                                  //    preferences record of the run (D51)
                                  // 8: workouts[].heartRateSeries (+ interval), basalEnergyKilocalories
  "exportedAt": "2026-08-11T18:30:00.123+09:00",
  "appVersion": "1.0 (3)",
  "seededCatalogVersion": 4,      // D28: what the omitted catalog rows came from
  "counts": { "workouts": 87, "sets": 1234, ... },
  "preferences": { ... },         // canonical AppPreferences row
  "gyms": [...],                  // incl. archived
  "machines": [...],              // incl. archived, with gymID + modelID
  "exercises": [...],             // referenced or user-created (D28)
  "equipmentModels": [...],       // referenced or user-created (D28)
  "templates": [...],             // with ordered items
  "workouts": [                   // with nested entries → sets, ordered
    { "id": ..., "entries": [ { "snapshot": {...}, "sets": [...] } ] }
  ],
  "gymExerciseMemory": [...],
  "exerciseRestOverrides": [...]
}
```

Every id is the stable UUID. A nil *object property* is **omitted**; a nil *array position*
(`targetRepsBySet: [8, null, 10]`) stays `null`, because dropping it would shift every later set
target. Set weights carry `weight`, `unit`, `weightKg` (D29), plus `barWeight`/`barWeightKg` on a set
loaded on a bar (D39). Derived data (PRs, volume, e1RM) is **not**
exported — SPEC: PRs are derived, never source-of-truth.

## Out of scope

- Import / restore (JSON is written to be re-importable; reading it back is not this milestone).
- Strong CSV import — milestone 5.
- Automatic/scheduled backup, iCloud Drive sync, encryption.
- Selective export (date ranges, single workout). Everything, every time.

## Tickets

```
01 export-core   — value types, collector, JSON + CSV encoders (pure, unit-tested)
└── 02 export-ui — Settings section, share sheet, file naming, counts summary
    └── 03 export-verification — fidelity tests over a realistic store + UI test
```


### v6 (milestone 9, ticket 02 — workout name)

`workouts[].name` in JSON: the title the user typed, absent when none was. `sourceTemplateName` is
unchanged and still present — one is intent, the other provenance. The CSV appends column 36,
`workoutTypedName`; column 4 `workoutName` keeps meaning the template, so a v1–v5 consumer reading
provenance there is not lied to. (A first cut reused column 4; codex-review 02 caught it.)

### v7 (milestone 9, ticket 04 — D51 reclassification provenance)

`entries[].reclassifiedAt` / `reclassifiedFromExerciseName` (absent unless the dumbbell
reclassification rewrote that entry), and in `preferences`: `dumbbellHistoryMovedSets`,
`dumbbellHistoryMovedAt`, `dumbbellHistoryCheckedAt`. CSV appends column 37 `reclassifiedFrom`. The
rewritten identity without the fact of the rewrite would be a backup claiming an untouched history.

### v8 (milestone 9, ticket 05 — heart-rate series)

`workouts[].heartRateSeries` (`[Int]`, bpm per bucket from `startedAt`, 0 = no sample = a gap),
`heartRateSeriesIntervalSeconds` (the bucket width it was folded at) and `basalEnergyKilocalories`.
All absent when no sensor ran. JSON only — arrays have no honest place in the set ledger, exactly as
`zoneSeconds` (v4). No CSV change.
