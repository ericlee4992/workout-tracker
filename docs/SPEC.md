# Workout Tracker — Product Specification

> Source of truth for product behavior. Agent sessions (Claude Code, Codex) and both developers load context from this file, not from chat history. Changes to locked decisions go through both developers and are recorded in `DECISIONS.md`.

## What this is

A private, native iPhone workout logger for two users (the developers). It matches Strong-style fast logging, with two differentiators no mainstream tracker has:

1. **Equipment-aware taxonomy** — the same exercise on different hardware is not comparable, so history and PRs anchor to equipment context.
2. **Honest kg/lb handling** — units chosen per set, defaulted by context, preserved as entered, never silently conflated.

v1 is for the two developers only. Schema decisions (stable UUIDs, export fidelity, CloudKit-compatible models) keep public release and sync open later.

## Taxonomy

Four levels:

| Level | Example | Created by |
|---|---|---|
| Exercise | Seated Chest Press | Seeded list + user additions |
| Equipment model | Life Fitness Insignia Chest Press | Seeded catalog + user additions |
| Machine instance | "Chest Press #2" | User, per gym |
| Gym | Gold's Gym Gangnam | User |

- Seeded equipment catalog ships in-app (major manufacturers: Life Fitness, Hammer Strength, Technogym, Precor, Cybex, Matrix, Nautilus, Hoist, …; popular selectorized/plate-loaded lines; order of a few hundred models). Catalog updates ride app releases. Seeded entries have stable catalog IDs that survive updates; user-created entries live in a separate ID space (dedup deferred).
- Gyms and machine instances are **always user-created**. No gym seeding.
- Each catalog model links to one or more exercises. Picking a machine auto-fills its exercise; multi-exercise stations (cable, Smith) prompt.
- Free weights are **equipment-type tags** (barbell / dumbbell / cable / smith / bodyweight), not machine instances.
- Exercises carry a **load type**: `weighted | bodyweight | bodyweightPlus | assisted`. PR/prefill/chart logic respects direction — on assisted machines, *lowest* assistance wins.
- **Strength-only v1**: one set shape (weight × reps). Cardio machines may exist in the taxonomy but are not loggable.

## History, PRs, integrity

- **Previous performance** uses layered fallback, each layer clearly labeled:
  1. This machine
  2. Same equipment model at another gym
  3. The exercise on any equipment
- **Prefill comes only from same-machine history.** Fallback layers are reference display, never prefilled into inputs.
- **PRs**: best weight per rep count (capped at 12 reps) + estimated 1RM (Brzycki: `weight / (1.0278 − 0.0278 × reps)`), computed at all three layers (machine, model, exercise). Warmups excluded from PRs and volume.
- **Log-time snapshots**: entries denormalize context (gym name, machine label, manufacturer+model, unit) when logged. Deleting a gym/machine archives it; history never orphans. Correcting a machine's model prompts: apply to past workouts or future only.

## Units

- Per-set unit (kg/lb). Default precedence: **machine → gym → app preference** (most specific wins).
- Original `(value, unit)` preserved verbatim; normalized kg stored alongside for analytics.
- Display **as entered**; a whole-view convert toggle renders converted values visibly marked (≈). Charts plot normalized values; tooltips show as-entered.
- Never imply equal displayed weights on different equipment models represent equal resistance.
- Dumbbell volume rule: one consistent rule across the app (decide at milestone 2; no per-platform divergence like Strong's).

## Recording experience

- Machine/gym optional on every set; once chosen, remembered **per gym per exercise** (`GymExerciseMemory`).
- **Templates are generic** exercise lists. Starting a workout at a gym resolves each exercise to the last-used machine there.
- Template drift: on finishing a modified templated workout, prompt — update template / update values only / both / keep original (suppressible).
- Set types: **warmup / working / failure**.
- **Rest timer**: auto-starts on set completion; per-exercise durations (separate warmup vs. working) with a global default (2:00); local notification on finish.
- Speed bar (from Strong): set rows arrive prefilled from same-machine history; confirming an untouched row is **one tap**.
- Active workout **auto-persists every change** — crash/force-quit loses nothing. Non-negotiable.

## Technical direction

- Swift + SwiftUI, **iOS 17+**, iPhone-only, local-first, fully offline.
- **SwiftData** persistence; models simple; snapshots denormalized.
- **CloudKit-compatible schema** (UUID ids, optional relationships, no unique constraints); v1 ships single-device; export is the backup story.
- No backend, accounts, HealthKit, Watch, or third-party runtime dependencies.

## Data model sketch

- `Exercise`: id, name, loadType, equipmentTypeTags, isSeeded, muscle grouping (light)
- `EquipmentModel`: id, manufacturer, modelName, linked exercise ids, isSeeded
- `Gym`: id, name, defaultUnit?, notes
- `MachineInstance`: id, gym, model?, label, defaultUnit?, archived
- `WorkoutTemplate` / `TemplateItem`: ordered exercises, target sets/reps, rest durations
- `Workout`: id, date, gym?, notes
- `ExerciseEntry`: workout, exercise, machine?, **context snapshot**
- `SetRecord`: entry, order, type, reps, weightValue, weightUnit, normalizedKg, completedAt
- `GymExerciseMemory`: (gym, exercise) → last machine
- PRs are derived (computed/cached), never source-of-truth records.

## Strong benchmark facts we build against

- Strong has **no gym/location/machine entity**; equipment is a name suffix ("(Barbell)"). Our thesis is an unserved need.
- Strong CSV (import target, milestone 5): one row per set; columns `Date, Workout Name, Duration, Exercise Name, Set Order, Weight, Reps, Distance, Seconds, [Notes, Workout Notes,] RPE` (10/12-column variants). Hazards: **no unit column** (ask user at import), no workout ID (group by Date+Workout Name), set tags lost, equipment in name suffix (parse to tags), localized headers/semicolon delimiters possible, Duration as "2h 38m". Imported rows populate the exercise layer only and are flagged as imported.
- Our export must include what Strong's lacks: explicit units, stable UUIDs, set types, full equipment context.

## Milestones (v1)

0. Project setup — Xcode project (buildable folders), docs, repo hygiene
1. **UI prototype on sample data** — all key screens, no persistence; ends with explicit user review before anything else is built
2. Core loop on SwiftData — schema, seeding, logging, prefill, PRs, snapshots, rest timer, continuous persistence → dogfooding starts
3. CSV/JSON export (full fidelity; backup + dev-to-dev sharing)
4. Progress charts (Swift Charts; normalized axes, as-entered tooltips)
5. Strong CSV import
6. Plate/stack calculator

Catalog curation runs as a parallel content task, shipped with releases.
