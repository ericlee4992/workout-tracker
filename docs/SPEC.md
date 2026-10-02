# Workout Tracker — Product Specification

> Source of truth for product behavior. Agent sessions (Claude Code, Codex) load context from this file, not from chat history. Changes to locked decisions are recorded in `DECISIONS.md`.

## What this is

A private, native iPhone workout logger built by a solo developer for their own use. It matches Strong-style fast logging, with two differentiators no mainstream tracker has:

> **Public beta planned (D60, 2026-10-01):** the app becomes **Stacked** for invited TestFlight testers, with optional accounts (Sign in with Apple and Google), a profile with a saved training profile, AI on the developer's key through the developer's server with per-account limits, onboarding and in-app feedback; workouts stay on the phone. Contract: [public-beta spec](../work-record/public-beta/spec.md). Until those tickets land, this file describes the shipped app.

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
- **AI equipment recognition (D56):** one photo of a label or whole machine goes to GPT-5.6 Terra after explicit photo consent. It proposes an editable identity and exercise IDs; the user confirms, then Add saves the machine at the selected gym. Visible specific manufacturer/model text resolves only to a unique exact catalog identity or a user-created model; generic recognition keeps `model = nil` with instance-local confirmed exercise links. No same-model history is invented. The app reencodes full-frame pixels without metadata, does not retain photos, requests `store=false`, and makes no hidden retries. OpenAI API retention policies still apply. An explicitly selected on-device label reader and manual catalog selection remain available offline. Private-trial OpenAI credentials live in the phone Keychain; a backend is required before shared-key public access. (D60 plans that backend: public-beta ticket 06 moves the key to the server and removes it from the phone.) Manual new-model exercise suggestions also use Terra and retain confirmation.

- Each catalog model links to one or more exercises. Picking a machine auto-fills its exercise; multi-exercise stations (cable, Smith) prompt.
- Free weights are **equipment-type tags** (barbell / dumbbell / cable / smith / bodyweight), not machine instances.
- **Presets** are named variations of a movement — grips, stances, single/double (D36–D38). They belong to the exercise, are chosen when logging (a machine preselects its usual one), and **split records**: a narrow-grip best is not a wide-grip best. The preset is part of the D23 snapshot, so switching it after a set is logged starts a new entry rather than relabelling completed work.
- Exercises carry a **load type**: `weighted | bodyweight | bodyweightPlus | assisted`. PR/prefill/chart logic respects direction — on assisted machines, *lowest* assistance wins.
- **Cardio expansion approved 2026-09-18 (D15):** one workout may contain lifting and separate cardio segments. Direction B focuses the current activity; either kind can start the workout or be added later. Optional device tracking, manual distance fallback, indoor distance/pace from supported sources and outdoor GPS are specified in [cardio spec](../work-record/cardio/spec.md). Implementation is merged; physical acceptance and user-requested presentation refinements are tracked in the cardio tickets. Weight × reps remains the strength-set shape.

## History, PRs, integrity

- **Previous performance** uses layered fallback, each layer clearly labeled:
  1. This machine
  2. Same equipment model at another gym
  3. The exercise on any equipment
- **Prefill comes only from same-machine history.** Fallback layers are reference display, never prefilled into inputs.
- Records, previous performance and prefill are keyed by preset as well as by equipment (D36) — a machine with no preset chosen is its own group, which is what every set logged before 2026-08-12 is.
- **Progress charts are per variation** (milestone 9): the chart's unit is (snapshot load type, equipment — exact machine / free-weight tag / unrecorded — preset), resolved from HISTORY, opening on the most-trained variation with a picker for the rest; a History session's chart button opens on THAT session's variation. Pooling barbell and dumbbell into one line was a defect (D36 one axis over).
- **History has a calendar** (marked days = finished workouts by START day, the same day the list files them under; tap a day to open the session) and a **heart-rate section per session** (average / max / active / total calories, and the 15 s-bucket graph when a series was recorded).
- **The one sanctioned rewrite of frozen snapshots is D51**: dumbbell-tagged sets of a barbell/machine movement are reclassified onto that movement's dumbbell exercise, once per row, with `reclassifiedAt` / `reclassifiedFromExerciseName` on the row, exported, and shown in History. Not a user edit (`historyEditedAt` untouched); Settings shows the running count. Everything else stays frozen (D19/D23/D47).
- **A workout can be named** (D50): during the workout it is just typing; renaming a logged workout is a marked history edit. The name is intent; `sourceTemplateName` stays as provenance.
- **PRs**: best weight per rep count (capped at 12 reps) + estimated 1RM (Brzycki: `weight / (1.0278 − 0.0278 × reps)`), computed at all three layers (machine, model, exercise). Only completed sets count; warmups excluded from PRs and volume. e1RM is weighted-only; assisted = least assistance per rep count, bodyweight+added = most added weight, bodyweight = most reps (D20). Volume = Σ(normalizedKg × reps), weighted exercises only, dumbbells never auto-doubled (D21).
- **Log-time snapshots**: entries denormalize context when their first set completes — stable UUIDs (exercise, machine, model, gym), the exercise's loadType, the free-weight tag, and display strings (D23). Units live per set, not in the snapshot. Deleting a gym/machine archives it; history never orphans. Correcting a machine's model prompts: apply to past workouts or future only.

## Units

- App unit preference is **Metric** (kg/km) or **U.S. customary** (lb/mi). New cardio segments snapshot the selected distance unit, including pace/speed. Existing records retain their units; manual distance entry retains the entered pair.
- Per-set unit (kg/lb). Default precedence: **machine → gym → app preference** (most specific wins; the app preference is a persisted, editable setting).
- Original `(value, unit)` preserved verbatim; normalized kg stored alongside for analytics (exactly 1 lb = 0.45359237 kg, recomputed atomically on edit, full precision — D25).
- Workout summaries derive their unit badge from actual logged sets: kg, lb, or Mixed — never just the gym default.
- Display **as entered**; a whole-view convert toggle renders every weight in the chosen unit, plain (D52 — the toggle is the user's own act, and the stored value stays as entered). Charts plot normalized values; tooltips show as-entered.
- Never imply equal displayed weights on different equipment models represent equal resistance.
- Dumbbell rule (D21): weights logged as labeled (per hand), never auto-doubled — one consistent rule, no per-platform divergence like Strong's.

## Recording experience

- Machine/gym optional on every workout and entry; workouts can start with **no gym** (home/context-free). Once chosen, equipment is remembered **per gym per exercise** (`GymExerciseMemory`). An entry's equipment freezes once its first set completes — switching machines mid-exercise starts a new entry (D19).
- **Templates are generic** exercise lists with optional planned rest and cardio targets (D56). The optional Ask AI for Templates action below Templates drafts an editable weekly set from goals, schedule and confirmed gym equipment; it never estimates starting weights. Its equipment section lets the user select/add a gym and scan machines with the D56 AI flow, preserving preferences and refreshing eligible equipment after each confirmed save. Explicit gym/machine saves survive routine cancellation; templates remain staged until Save templates. Planned cardio is snapshotted into the workout and starts recording only on an explicit Start tap. Starting a workout at a gym resolves each exercise to the last-used machine there. A finished workout can be saved as a template from the finish sheet or, later, from its History detail (the menu's "Save as Template…", offered only when it has completed sets).
- Template drift: on finishing a modified templated workout, prompt — update template / update values only / both / keep original (suppressible).
- Set types: **warmup / working / failure / drop** (D26). Drop sets count toward records and volume like working sets; only warmups are excluded. Completing a drop set does not start the rest timer, since a drop set is performed without rest.
- Any set can be deleted from its row (swipe, plus a menu action).
- **Rest timer**: auto-starts on set completion; per-exercise durations (separate warmup vs. working; failure sets use the working duration) with global defaults (2:00 working / 1:00 warmup); local notification on finish. Per exercise the rest may instead be **heart-rate based** (D43): it ends when the heart rate drops below a threshold the user set, or when a max-wait cap expires, and the alarm says which. With no live reading it falls back to the standard duration and says so.
- Speed bar (from Strong): set rows arrive prefilled from same-machine history; confirming an untouched row is **one tap**. Adding a set inherits the last completed row's weight, unit, reps and bar, so a repeat set is one tap once the row exists. **Rows are only ever created deliberately** — completing a set does not append the next one. That was built and tried on 2026-08-22 and rejected in use; see `work-record/next-set-autofill/`.
- **Barbell bar weight** (D39–D40): an entry doing barbell work — the barbell/Smith free-weight tags, or a machine whose catalog model is a rack or Smith — can name the bar it is loaded on — a fixed list of standard bars in kg and lb, or a custom weight. The weight field then takes the plates on **one** end and the app logs `bar + 2 × plates`; the row shows the total before it is logged and history shows the breakdown. What is stored is always the **total lifted**, so records, volume and e1RM are untouched by the choice; the bar rides along as provenance and travels with prefill and carry-forward, so it is chosen once per movement. The bar carries its own unit and picking one sets the row's unit — a 20 kg bar is not a 45 lb bar, and the kg/lb toggle is disabled while a bar is chosen. Changing bars never splits an entry the way changing equipment (D19) or variation (D36) does.
- **Finish summary** (milestone 9): a two-column tile block ordered by pairs — **workout time / total volume**, **active / total calories**, **average / max heart rate** (ticket 17, 2026-09-17). Total calories are active + system basal, shown only when both exist; missing metrics are omitted and the grid compacts. Accessibility sizes use one column in the same order. Then time in zones and a **heart-rate graph** in Apple Fitness's shape: one thin floating bar per display slot spanning that slot's low to high bpm (15 s buckets, merged to at most ~110 bars; 0 = a gap, never 0 BPM, drawn as a hole), the axis labelled only at the series' own low and high, clock times at the start and thirds, the average under the plot; older mean-only series draw from the range of their means. Shared with History detail, which also shows time in zones under the graph (the same card as the receipt) whenever the workout recorded any. The series is folded once at finish from the dominant sensor's readings bounded to the workout, the other sensor filling only genuine outages or sustained terminal handoffs; the same readings feed the aggregates, so chart and numbers never disagree.
- **Dumbbell movements are their own exercises** (catalog v5, 14 rows). Where a movement has a dumbbell counterpart, the equipment sheet offers "Log as Dumbbell X instead" rather than the bare Dumbbell tag — a draft entry is re-filed in place, a frozen one continues in a new entry (D19) — so the old shape (dumbbell sets under a barbell-named exercise) cannot re-grow.
- **Copy policy** (milestone 9, ticket 06): no explanatory paragraphs. A screen may carry one short line where an action has a non-obvious CONSEQUENCE — what a delete destroys, what a template omits, "only completed sets are kept" — and nothing that merely explains the screen.
- Active workout **auto-persists every committed change** (set completion, add/delete, equipment choice, unit toggle, field commit on end-editing) — crash/force-quit loses at most in-progress keystrokes in the currently focused field. Non-negotiable.

## Visual design (D59, replacing D54)

Floodlight, in light and dark (Settings → Appearance: System / Light / Dark, per device). The
tokens and components live in `Features/Design/Look/` (`Look.floodlight`, `Look.floodlightLight`;
the measured contrast pairs are in `FinalLook.swift`): ink or near-white grounds, graphite or white
panels with hairlines, violet "Ultra" as the one action colour (`#B25CFF` dark / `#7A2EE0` light),
SF Pro Expanded Black/Heavy for titles and figures, segmented rings, heart rate in its own pink-red,
and the five muscle FAMILIES — chest, back, shoulders, arms, legs (`MuscleFamily`) — as muscle maps
(`Assets.xcassets/MuscleMaps/`: a neutral body with the family's muscle lit in the family colour),
shown on templates, the week card and History, never as a per-exercise row icon. The live lifting
workout keeps Paper Club's structure in Floodlight's type and violet (`Look.live(dark:)`): round set
markers, dashed draft fields, stamp check circles, the yellow "New best" highlighter, the inverse
rest slab and "Discard Workout…" at the end of the list. Cardio and every sheet stay plain
Floodlight; native Forms and lists keep the system controls in Floodlight colours. A template tile
opens the template; it has no long-press menu (ticket 15). Motion answers the user (a set
completed, a workout started, a rest ending, a new best) and steps down under Reduce Motion. The
copy policy stands; the redesign's new strings were approved as shown in the prototype and are
listed per area in `work-record/redesign-floodlight/issues/`. Layouts adapt to Dynamic Type (rows
stack at accessibility sizes, chips wrap, tiles scale); each area has light and dark Default and
AccessibilityL captures in `work-record/redesign-floodlight/captures/`.

The app icon is the dumbbell in violet on ink, with Dark and Tinted appearances
(`scripts/render-app-icon.py`). The Live Activity follows the system appearance and carries the
Floodlight tokens as literals (`WorkoutTrackerWidget/Shared/WorkoutActivityViews.swift`): resting
(the draining ring, the countdown, +15s / Skip, the next set, heart and sets), ready (the next set
to load beside last time's value, and how the last rest ended) and cardio (the target ring, the
segment's clock, Pause / Resume, distance and pace). The buttons are App Intents that run in the
app (`WorkoutActivityCommands`); every countdown and clock is ticked by the system (D46).

## Technical direction

- Swift + SwiftUI, **iOS 26+** (D42 — the iPhone workout-session API requires it), iPhone **plus a watchOS companion** (D41), local-first; AI photo identification and routine generation require a connection and explicit consent (D56).
- **SwiftData** persistence; models simple; snapshots denormalized.
- **CloudKit-compatible schema** (UUID ids, optional relationships, no unique constraints); v1 ships single-device; export is the backup story.
- No backend, accounts, or third-party runtime dependencies. **HealthKit and a watchOS companion are in scope from 2026-08-22 (D41)**, reopened deliberately for heart rate; everything else in this line still holds, and the app still talks to nothing but the device it is on — except consented OpenAI requests (D56: developer’s own key for the private trial; a proxy is a prerequisite before shared-key use by other users). **Reopened 2026-10-01 by D60** (planned, public-beta tickets 03–07): a Cloudflare Worker backend and optional accounts; the app still has no third-party runtime code and works offline and signed out except for AI.

## Data model sketch

- `Exercise`: id, name, loadType, equipmentTypeTags, isSeeded, muscle grouping (light)
- `EquipmentModel`: id, manufacturer, modelName, linked exercise ids, equipmentType? (selectorized / plate-loaded / cable / rack-or-Smith / bodyweight station — browsing metadata only, nil = uncategorized), isSeeded (seeded rows keyed by fixed catalog UUIDs; seeding is versioned idempotent reconciliation — D24)
- `Gym`: id, name, city?, defaultUnit?, notes, archived
- `MachineInstance`: id, gym, model?, recognizedExerciseIDs (used when model is unknown), label, defaultUnit?, defaultPresetID? (the preset it usually is — scalar, degrades to none), archived
- `WorkoutTemplate` / `TemplateItem`: ordered exercises (scalar `order` field), target sets/reps. No rest durations in v1 (D22)
- `Workout`: id, gym?, notes, sourceTemplateID?, restEndsAt? (persisted rest-timer end), heart-rate summary captured at finish (averageHeartRate?, maxHeartRate?, activeEnergyKilocalories?, basalEnergyKilocalories?, zoneSeconds, zonesFromEstimatedMax?, heartRateSeries + heartRateSeriesLow + heartRateSeriesHigh + heartRateSeriesIntervalSeconds? — the 15 s-bucket mean/low/high behind the graph, 0 = gap; low/high empty on workouts folded before they existed — D44/D45; all absent when no sensor ran), **lifecycle**: startedAt, finishedAt? (nil = active; cancel deletes; Finish deletes uncompleted draft rows and zero-completed-set entries). At most one active workout — on conflict the newest keeps running and older strays are auto-finished
- `ExercisePreset`: id, name, scalar `order`, exercise — user-created variations (D36–D38)
- `ExerciseEntry`: workout, exercise, machine?, preset?, freeWeightTag?, scalar `order`, per-exercise rest overrides live in preferences, **context snapshot** = stable UUIDs (exercise, machine?, model?, gym?) + loadType + freeWeightTag + display strings (D23). Equipment freezes once the first set completes; changing equipment starts a new entry (D19)
- `SetRecord`: entry, scalar `order`, type, reps?, weightValue? (optional while draft — the **total** lifted, bar included), weightUnit, normalizedKg?, completedAt? (nil = not completed; only completed sets feed records/volume/prefill), barWeightValue? + barNormalizedKg? (D39: the bar this set was loaded on, as entered in the row's own unit plus normalized; nil = entered as a total. Provenance only — never subtract it from `weightValue`)
- `GymExerciseMemory`: scalar gymID/exerciseID/machineID + updatedAt; app-level upsert, duplicates resolved by latest updatedAt then id (no unique constraints allowed)
- App-level preferences: unit preference (default from locale measurement system on first launch), drift-prompt suppression, global + per-exercise rest defaults, measured maximum heart rate? and birth date? (D45/D52 — zones come from 220−age until a measured max exists, unmarked on screen since D52; hidden entirely without either), seeded-catalog version, notification-permission-requested marker, remembered catalog browsing state (grouping mode + active filters per surface — display only, D23)
- All relationships optional with explicit inverses; deliberate delete rules (no `deny` — unsupported by CloudKit); ordering always via scalar fields, never implicit to-many order
- PRs are derived (computed/cached), never source-of-truth records.

## Export (milestone 3, D28–D32)

Two files, shared from Settings (the gear on the Workout tab) through the system share sheet — "Save to Files → iCloud Drive" is the intended backup. Both carry everything the user created; neither carries derived data (PRs, e1RM, volume) or the shipped catalog beyond the rows the user's data references (D28).

- **CSV** — one row per set, 37 columns (`supersetGroupID` was added by milestone 8; `workoutTypedName` and `reclassifiedFrom` by milestone 9 — column 4 `workoutName` still means the template it came from), fully denormalized: workout, gym, exercise, machine, model display name and manufacturer, set type, reps, `weight` + `unit` + `weightKg`, completion, the preset performed, and `barWeight` + `barWeightKg` (D39 — empty when the weight was entered as a total; `weight` is the total either way, so adding them counts the bar twice). Context columns come from the entry's D23 snapshot once it has one (a draft entry reports its live equipment), so renaming a gym never rewrites old rows. RFC 4180, CRLF, UTF-8 BOM, user text verbatim (D32). It is a complete ledger of *sets*: an object holding no set at all appears only in the JSON.
- **JSON** — the object graph and the complete backup: `schemaVersion` **9** (9 added `heartRateSeriesLow`/`High`, the per-bucket range beside the mean — both or neither, each the mean's length; 8 added the per-workout heart-rate series and basal energy; 7 added the D51 reclassification provenance on entries and its record in preferences; 6 added `workouts[].name`, the user's typed title, beside `sourceTemplateName`; 5 added `supersetGroupID`; 2 added `presetID`/`presetName` per entry; 3 added `barWeight`/`barWeightKg` per set; 4 added the per-workout heart-rate summary, the measured-max/birth-date preferences, and the per-exercise rest mode), sorted keys, nil properties omitted (nil *array positions* stay `null` so set targets keep their index). Written to be re-importable; reading it back is not in v1's export milestone.
- Timestamps are ISO 8601 with the device's UTC offset and fractional seconds (D31). Draft sets and the in-progress workout export, flagged (D30). Column layout and the JSON shape: `work-record/milestone-3-export/spec.md`.

## Strong benchmark facts we build against

- Strong has **no gym/location/machine entity**; equipment is a name suffix ("(Barbell)"). Our thesis is an unserved need.
- Strong CSV (**import DROPPED 2026-08-29, D49** — kept only as a record of the format): one row per set; columns `Date, Workout Name, Duration, Exercise Name, Set Order, Weight, Reps, Distance, Seconds, [Notes, Workout Notes,] RPE` (10/12-column variants). Hazards: **no unit column** (ask user at import), no workout ID (group by Date+Workout Name), set tags lost, equipment in name suffix (parse to tags), localized headers/semicolon delimiters possible, Duration as "2h 38m". Imported rows populate the exercise layer only and are flagged as imported.
- Our export must include what Strong's lacks: explicit units, stable UUIDs, set types, full equipment context.

## Milestones (v1)

0. Project setup — Xcode project (buildable folders), docs, repo hygiene
1. **UI prototype on sample data** — all key screens, no persistence; ends with explicit user review before anything else is built
2. Core loop on SwiftData — schema, seeding, logging, prefill, PRs, snapshots, rest timer, continuous persistence → dogfooding starts
3. CSV/JSON export (full fidelity; backup and data ownership — the only copy of your history is on one device until sync exists)
4. Progress charts (Swift Charts; normalized axes, as-entered tooltips) — **shipped inside milestone 8** (ticket 01, 2026-08-26); the as-entered tooltip landed 2026-08-29
5. ~~Strong CSV import~~ — **DROPPED 2026-08-29** at the user's request: there is no Strong history to import. The format analysis above stays for the record
6. Plate/stack calculator — **the bar half shipped early** (D39–D40, 2026-08-22): naming the bar and entering plates per side. What remains is computing *which plates* to load for a target weight, and selectorized stack increments.

7. Heart rate (D41–D45) — live bpm from AirPods/Watch, zones, calories, HR rest timer, finish summary; **merged 2026-08-25**. The watch companion target is a sketch, never run.
8. History and charts — load-type correction (D47), history editing, progress charts, supersets (D48), lock-screen Live Activity; **merged 2026-08-29**.
9. History and summary — chart per equipment + History chart button, workout name (D50), History calendar, dumbbell exercises with the D51 reclassification, finish summary with total calories and a heart-rate graph, helper copy removed; **merged 2026-09-04** (`97b656b`), six tickets, 25 Codex rounds.

Catalog curation runs as a parallel content task, shipped with releases.
