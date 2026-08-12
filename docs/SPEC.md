# Workout Tracker — Product Specification

> Source of truth for product behavior. Agent sessions (Claude Code, Codex) load context from this file, not from chat history. Changes to locked decisions are recorded in `DECISIONS.md`.

## What this is

A private, native iPhone workout logger built by a solo developer for their own use. It matches Strong-style fast logging, with two differentiators no mainstream tracker has:

1. **Equipment-aware taxonomy** — the same exercise on different hardware is not comparable, so history and PRs anchor to equipment context.
2. **Honest kg/lb handling** — units chosen per set, defaulted by context, preserved as entered, never silently conflated.

v1 is for the developer's own use only. Schema decisions (stable UUIDs, export fidelity, CloudKit-compatible models) keep public release and sync open later.

## Taxonomy

Four levels:

| Level | Example | Created by |
|---|---|---|
| Exercise | Seated Chest Press | Seeded list + user additions |
| Preset | Wide grip / Single leg | User, per exercise (D36–D38) |
| Equipment model | Life Fitness Insignia Chest Press | Seeded catalog + user additions |
| Machine instance | "Chest Press #2" | User, per gym |
| Gym | Gold's Gym Gangnam | User |

- Seeded equipment catalog ships in-app: **1877 models across 23 manufacturers** (ticket 20; 1887 minus the ten duplicate identities merged by codex-review-4), every name verified against a manufacturer or authorised-dealer listing, save six version-1 fixture names disclosed row by row — sources in `docs/catalog-sources/`. One real machine has exactly one catalog UUID; the generator fails on near-duplicate identities. Catalog updates ride app releases as a version bump through the D24 reconciler. Seeded entries have stable catalog IDs that survive updates; user-created entries live in a separate ID space (dedup deferred).
- Gyms and machine instances are **always user-created**. No gym seeding.
- Adding a machine can **photograph its name plate** (D33–D35): Vision reads the text on device, the app ranks catalog models against it and offers the candidates with scores, and the user confirms one — or creates a user-space model prefilled from the reading. The photo is discarded after reading; nothing leaves the phone. A scan identifies the *model*, never which of the gym's three chest presses this is — that is the machine's label, which the user writes.
- Each catalog model links to one or more exercises. Picking a machine auto-fills its exercise; multi-exercise stations (cable, Smith) prompt.
- Free weights are **equipment-type tags** (barbell / dumbbell / cable / smith / bodyweight), not machine instances.
- **Presets** are named variations of a movement — grips, stances, single/double (D36–D38). They belong to the exercise, are chosen when logging (a machine preselects its usual one), and **split records**: a narrow-grip best is not a wide-grip best. The preset is part of the D23 snapshot, so switching it after a set is logged starts a new entry rather than relabelling completed work.
- Exercises carry a **load type**: `weighted | bodyweight | bodyweightPlus | assisted`. PR/prefill/chart logic respects direction — on assisted machines, *lowest* assistance wins.
- **Strength-only v1**: one set shape (weight × reps). Cardio machines may exist in the taxonomy but are not loggable.

## History, PRs, integrity

- **Previous performance** uses layered fallback, each layer clearly labeled:
  1. This machine
  2. Same equipment model at another gym
  3. The exercise on any equipment
- **Prefill comes only from same-machine history.** Fallback layers are reference display, never prefilled into inputs.
- Records, previous performance and prefill are keyed by preset as well as by equipment (D36) — a machine with no preset chosen is its own group, which is what every set logged before 2026-08-12 is.
- **PRs**: best weight per rep count (capped at 12 reps) + estimated 1RM (Brzycki: `weight / (1.0278 − 0.0278 × reps)`), computed at all three layers (machine, model, exercise). Only completed sets count; warmups excluded from PRs and volume. e1RM is weighted-only; assisted = least assistance per rep count, bodyweight+added = most added weight, bodyweight = most reps (D20). Volume = Σ(normalizedKg × reps), weighted exercises only, dumbbells never auto-doubled (D21).
- **Log-time snapshots**: entries denormalize context when their first set completes — stable UUIDs (exercise, machine, model, gym), the exercise's loadType, the free-weight tag, and display strings (D23). Units live per set, not in the snapshot. Deleting a gym/machine archives it; history never orphans. Correcting a machine's model prompts: apply to past workouts or future only.

## Units

- Per-set unit (kg/lb). Default precedence: **machine → gym → app preference** (most specific wins; the app preference is a persisted, editable setting).
- Original `(value, unit)` preserved verbatim; normalized kg stored alongside for analytics (exactly 1 lb = 0.45359237 kg, recomputed atomically on edit, full precision — D25).
- Workout summaries derive their unit badge from actual logged sets: kg, lb, or Mixed — never just the gym default.
- Display **as entered**; a whole-view convert toggle renders converted values visibly marked (≈). Charts plot normalized values; tooltips show as-entered.
- Never imply equal displayed weights on different equipment models represent equal resistance.
- Dumbbell rule (D21): weights logged as labeled (per hand), never auto-doubled — one consistent rule, no per-platform divergence like Strong's.

## Recording experience

- Machine/gym optional on every workout and entry; workouts can start with **no gym** (home/context-free). Once chosen, equipment is remembered **per gym per exercise** (`GymExerciseMemory`). An entry's equipment freezes once its first set completes — switching machines mid-exercise starts a new entry (D19).
- **Templates are generic** exercise lists. Starting a workout at a gym resolves each exercise to the last-used machine there.
- Template drift: on finishing a modified templated workout, prompt — update template / update values only / both / keep original (suppressible).
- Set types: **warmup / working / failure / drop** (D26). Drop sets count toward records and volume like working sets; only warmups are excluded. Completing a drop set does not start the rest timer, since a drop set is performed without rest.
- Any set can be deleted from its row (swipe, plus a menu action).
- **Rest timer**: auto-starts on set completion; per-exercise durations (separate warmup vs. working; failure sets use the working duration) with global defaults (2:00 working / 1:00 warmup); local notification on finish.
- Speed bar (from Strong): set rows arrive prefilled from same-machine history; confirming an untouched row is **one tap**.
- Active workout **auto-persists every committed change** (set completion, add/delete, equipment choice, unit toggle, field commit on end-editing) — crash/force-quit loses at most in-progress keystrokes in the currently focused field. Non-negotiable.

## Technical direction

- Swift + SwiftUI, **iOS 17+**, iPhone-only, local-first, fully offline.
- **SwiftData** persistence; models simple; snapshots denormalized.
- **CloudKit-compatible schema** (UUID ids, optional relationships, no unique constraints); v1 ships single-device; export is the backup story.
- No backend, accounts, HealthKit, Watch, or third-party runtime dependencies.

## Data model sketch

- `Exercise`: id, name, loadType, equipmentTypeTags, isSeeded, muscle grouping (light)
- `EquipmentModel`: id, manufacturer, modelName, linked exercise ids, equipmentType? (selectorized / plate-loaded / cable / rack-or-Smith / bodyweight station — browsing metadata only, nil = uncategorized), isSeeded (seeded rows keyed by fixed catalog UUIDs; seeding is versioned idempotent reconciliation — D24)
- `Gym`: id, name, city?, defaultUnit?, notes, archived
- `MachineInstance`: id, gym, model?, label, defaultUnit?, defaultPresetID? (the preset it usually is — scalar, degrades to none), archived
- `WorkoutTemplate` / `TemplateItem`: ordered exercises (scalar `order` field), target sets/reps. No rest durations in v1 (D22)
- `Workout`: id, gym?, notes, sourceTemplateID?, restEndsAt? (persisted rest-timer end), **lifecycle**: startedAt, finishedAt? (nil = active; cancel deletes; Finish deletes uncompleted draft rows and zero-completed-set entries). At most one active workout — on conflict the newest keeps running and older strays are auto-finished
- `ExercisePreset`: id, name, scalar `order`, exercise — user-created variations (D36–D38)
- `ExerciseEntry`: workout, exercise, machine?, preset?, freeWeightTag?, scalar `order`, per-exercise rest overrides live in preferences, **context snapshot** = stable UUIDs (exercise, machine?, model?, gym?) + loadType + freeWeightTag + display strings (D23). Equipment freezes once the first set completes; changing equipment starts a new entry (D19)
- `SetRecord`: entry, scalar `order`, type, reps?, weightValue? (optional while draft), weightUnit, normalizedKg?, completedAt? (nil = not completed; only completed sets feed records/volume/prefill)
- `GymExerciseMemory`: scalar gymID/exerciseID/machineID + updatedAt; app-level upsert, duplicates resolved by latest updatedAt then id (no unique constraints allowed)
- App-level preferences: unit preference (default from locale measurement system on first launch), drift-prompt suppression, global + per-exercise rest defaults, seeded-catalog version, notification-permission-requested marker, remembered catalog browsing state (grouping mode + active filters per surface — display only, D23)
- All relationships optional with explicit inverses; deliberate delete rules (no `deny` — unsupported by CloudKit); ordering always via scalar fields, never implicit to-many order
- PRs are derived (computed/cached), never source-of-truth records.

## Export (milestone 3, D28–D32)

Two files, shared from Settings (Gyms screen) through the system share sheet — "Save to Files → iCloud Drive" is the intended backup. Both carry everything the user created; neither carries derived data (PRs, e1RM, volume) or the shipped catalog beyond the rows the user's data references (D28).

- **CSV** — one row per set, 29 columns, fully denormalized: workout, gym, exercise, machine, model display name and manufacturer, set type, reps, `weight` + `unit` + `weightKg`, completion, and the preset performed. Context columns come from the entry's D23 snapshot once it has one (a draft entry reports its live equipment), so renaming a gym never rewrites old rows. RFC 4180, CRLF, UTF-8 BOM, user text verbatim (D32). It is a complete ledger of *sets*: an object holding no set at all appears only in the JSON.
- **JSON** — the object graph and the complete backup: `schemaVersion` 2 (presets added `presetID`/`presetName` per entry), sorted keys, nil properties omitted (nil *array positions* stay `null` so set targets keep their index). Written to be re-importable; reading it back is not in v1's export milestone.
- Timestamps are ISO 8601 with the device's UTC offset and fractional seconds (D31). Draft sets and the in-progress workout export, flagged (D30). Column layout and the JSON shape: `.scratch/milestone-3-export/spec.md`.

## Strong benchmark facts we build against

- Strong has **no gym/location/machine entity**; equipment is a name suffix ("(Barbell)"). Our thesis is an unserved need.
- Strong CSV (import target, milestone 5): one row per set; columns `Date, Workout Name, Duration, Exercise Name, Set Order, Weight, Reps, Distance, Seconds, [Notes, Workout Notes,] RPE` (10/12-column variants). Hazards: **no unit column** (ask user at import), no workout ID (group by Date+Workout Name), set tags lost, equipment in name suffix (parse to tags), localized headers/semicolon delimiters possible, Duration as "2h 38m". Imported rows populate the exercise layer only and are flagged as imported.
- Our export must include what Strong's lacks: explicit units, stable UUIDs, set types, full equipment context.

## Milestones (v1)

0. Project setup — Xcode project (buildable folders), docs, repo hygiene
1. **UI prototype on sample data** — all key screens, no persistence; ends with explicit user review before anything else is built
2. Core loop on SwiftData — schema, seeding, logging, prefill, PRs, snapshots, rest timer, continuous persistence → dogfooding starts
3. CSV/JSON export (full fidelity; backup and data ownership — the only copy of your history is on one device until sync exists)
4. Progress charts (Swift Charts; normalized axes, as-entered tooltips)
5. Strong CSV import
6. Plate/stack calculator

Catalog curation runs as a parallel content task, shipped with releases.
