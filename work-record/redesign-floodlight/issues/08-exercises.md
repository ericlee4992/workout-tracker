# 08 — Floodlight: Exercises

Type: feature (part of [01](01-implement-redesign.md), area order item 7)
Status: in progress — implemented and verified; Codex review 08 next
Implementer: Claude. Reviewer: Codex.
Branch: `ericlee4992/redesign-floodlight-exercises` (scratch checkout `/tmp/wt-floodlight/exercises`),
stacked on the ticket-07 scan tip `7655aa7` (Codex clear). Nothing merged to `main`; nothing installed.

## User decisions (2026-09-27, asked in session)

1. **Exercise Detail (E02) opens from the Exercises tab AND from a machine page's exercise rows**
   (ticket 06 left those rows as information "pending an exercise detail page"). The rows'
   long-press menus stay as shortcuts (Progress…, Presets…, Load type…, Rename…).
2. **Presets keep reordering.** The prototype's sheet drops it; the real sheet keeps drag to
   reorder (the order is the order presets are offered in a workout). Tap a preset renames it,
   swipe left deletes after a confirmation (both new, from the prototype).
3. **Load Type uses the prototype's shortened copy**: one consequence line per type, and the
   "What this changes" sentences become the two-row ledger (sets from now on → the new type;
   N sets already logged keep the old type). No decision number on screen.
4. **New Exercise gets Body area and refuses a taken name**: body-area chips (custom exercises
   no longer fall into "Uncategorized" unless left unset), and "“<name>” is already an
   exercise." blocks Add when any live exercise has that name (case- and space-insensitive).
   From the Exercises tab, Add opens the new exercise's detail; the mid-workout pickers keep
   acting on it (their `onCreate`).

## Scope

Ticket 01 area 7 in the approved Floodlight design. Reference: prototype captures taken
2026-09-27 into `../reference/prototype-exercises/{dark,light}/` (`LOOKS=final APPEARANCE=dark|light
AXL=1 SETTLE=4 scripts/capture.sh all … E01 E02 E03 E04 E05`, then the variants `E01:empty E01:arms
E02:p2 E02:p3 E02:assisted E02:untrained E02:custom E03:taken E04:empty E04:duplicate E05:changed`;
all four runs exit 0, 64 PNGs).

1. **E01 Exercises (tab root).** Large title "Exercises" with the count ("56 exercises", the
   listed count while searching/filtering), the search field, the **five family maps as a filter
   strip** (the bold element: tap a family and only it stays lit; tap again for all), a filter
   summary line with **Clear**, then the catalog in sections. Toolbar: the filter menu (Group
   by: Body area / Last trained / A–Z; Equipment Type; Clear Filters) and **+** (Add Exercise…).
   - Sections: body area head to toe (`BodyArea.order`, the family's colour bar on the header,
     the section count), then "Uncategorized"; Last trained: This week / Last week / Earlier /
     Not trained yet; A–Z: letters.
   - Row: name; equipment in words (tags, "Bodyweight" dropped when the load badge says it);
     the load badge when not Weighted; "Custom" for user exercises; trailing, the best set by
     load type (the new-best burst when the latest session set it) over when it was last
     trained ("Today", "Yesterday", weekday within 6 days, else "Sep 19"). Tap → E02; long
     press → the menu above.
   - No match: the search glyph, "No exercises match", and **Add “<search>”…** (filled — the
     state's one action) opening New Exercise with the name.
   - "Add Exercise…" also ends the list (dashed make-row).
   - The family is remembered between visits in the existing `exerciseBrowseMuscleGroup`
     preference (its value becomes the family name; an old saved body area such as "Biceps"
     opens on its family, Arms). Equipment type stays in `exerciseBrowseEquipmentTag`. Group by is
     a per-device display preference (`@AppStorage`), like Appearance. D24's rule stays: a row with
     no body area or no tags is never hidden by that filter. Core, Neck and Full Body have no
     family (MuscleFamily): with a family chosen they are hidden like any other family's rows.
2. **E02 Exercise Detail (new, pushed).** Hero: equipment glyph tile, the family bar + body
   area, the name (title), tags (equipment, the load badge with its rank arrow, Custom). The
   stat strip (Workouts · Last trained · Sets) once trained. **Progress (bold element)**: one
   panel — the default variation's label, its best set as the hero figure (burst when the
   latest session set it), 1RM and "Since first session" change, the mini chart; tap → the
   progress chart (the existing `ExerciseProgressView`, presented as the sheet it already is,
   opened on that variation); the other variations as rows (equipment, then preset/gym · N days,
   their best) each opening the chart on that variation. Untrained: "No sets logged yet".
   **Records** of the main variation by load type: "Weight records" / "Least-assistance records ·
   lower is better" / "Added-weight records" / "Bodyweight record" (most reps). **Setup**: Load
   type (value) → E05, Presets (names, count) → E04, Rename… (custom only). **Machines**: live
   machines serving it or logged on, gym, best and workouts on it → the machine page.
   **History**: the last three workouts that trained it (day number + weekday, workout name,
   equipment · preset, the sets with warmup "W" and the new-best burst) → the workout detail.
3. **E03 New Exercise (sheet, shared with the mid-workout pickers).** Custom header: Cancel ·
   "New Exercise" · **Add** (filled; off while the name is blank or taken). Name field (error
   edge + line when taken), **Load type** as four tiles with the selected type's consequence line,
   **Body area** chips (the family bar on each), **Equipment** chips with glyphs.
4. **E04 Presets (sheet).** Header: "Presets" over the exercise name, **Done**. The presets as a
   list: name, "N workouts" / "Not used yet", the preset's best; tap → rename alert ("Logged sets
   keep the old name."), swipe → Delete → confirmation "Delete “<name>”?" / "Logged sets keep it."
   / Delete Preset; reorder handles (decision 2). Empty: one compact panel "No presets yet" +
   "Without any, this exercise is logged as one thing." The add field + **Add**, the duplicate line
   "<name> is already a preset here.", **Common** suggestions as + chips.
5. **E05 Load Type (sheet).** Header: Cancel · "Load Type" over the exercise name · **Save**
   (filled, on only after a change). The four tiles, the consequence line (decision 3), and once a
   different type is chosen the ledger: "Sets you log from now on" [new badge] / "N sets already
   logged" [old badge] (only when N > 0).
6. **Machine page exercise rows** → E02 (decision 1), with a chevron.

Not in this ticket: the prototype's demo variants and paging helpers; a rename-duplicate rule
(renaming keeps today's behaviour — decision 4 covers New Exercise only); per-exercise muscle
icons (removed by the user, ticket 01).

## Prototype features the real app lacked (approved with the prototype; each can be vetoed)

- E02 as a destination (was: long-press menu only) and its readouts: stats, best + 1RM + change
  + mini chart, variations, rep records, setup, machines, recent history.
- E01: family filter strip (replaces the Body Area submenu), body-area sections (was one A–Z
  list), Group by (Body area / Last trained / A–Z), per-row best and last trained, the no-match
  Add “…”, the toolbar +.
- E03: body area (decision 4), taken-name refusal (decision 4), opening the new exercise.
- E04: per-preset usage and best, tap to rename, delete confirmation.
- E05: tiles with rank arrows, shortened copy and the ledger (decision 3).

## Domain (derived on read, unit-tested)

`Domain/ExerciseOverview.swift` — pure functions over `RecordSetInput`-style inputs plus a
SwiftData bridge; all history in SNAPSHOT terms (D23), finished workouts only, completed sets only.
- `catalogStats` — per exercise: workouts, last trained, working sets (non-warmup), the best
  eligible set among sets logged under the exercise's CURRENT load type (a re-typed exercise never
  mixes rankings, D23), and `lastWasNewBest` (the best was set in the latest workout that trained
  it AND an earlier workout had an eligible set — never a tie, never a first time).
- `recentSessions` — the newest N workouts' sets for the exercise, their equipment words, and
  which sets were new bests (`SetBadgeMath`, per snapshot scope).
- `machineUses` — live machines serving the exercise or logged on with it; workouts and best.
- `presetUsage` / `presetBests`.
- `loggedSetCount` (moved from the Load Type sheet), `ExerciseNames.isTaken`.
- `ExercisesGrouping` sections (body area / last trained buckets by the app calendar's week / A–Z)
  and the family filter (`MuscleFamily` from a stored value, D24's no-hide rule).
Rules kept: D23 frozen history, D24 (seeded names read-only; filters never hide untagged rows),
D36–D38 presets split history and are user data on seeded exercises, D47 load-type corrections
(`loadTypeUserOverridden`), D52 plain numbers (unit shown only when it differs from the user's
unit), records rules (warmups excluded, assisted lower is better, ties not PRs, first time not a PR).

## Screen jobs, bold element, wireframes (ios-design steps 1–2)

- **E01:** exists to find one exercise; the eye lands on the family maps (top), the thumb on a row.
  Runner-up (the search field) is plain chrome. No-match state: the eye lands on Add “…”.
- **E02 (trained):** exists to see how this exercise is going; the eye lands on the best-set
  figure in the Progress panel. Setup rows are quiet list rows. Untrained: the empty Progress
  panel, then Setup.
- **E03:** exists to name and type a new exercise; the eye lands on the name field, the thumb
  on Add (the one filled command).
- **E04:** exists to name the variations; the eye lands on the preset list; Done is chrome, Add is
  the one filled command once text is typed.
- **E05:** exists to fix how records rank; the eye lands on the selected tile; Save is filled only
  after a change.

```
E01                          E02                           E05
┌──────────────────────┐    ┌──────────────────────┐     ┌──────────────────────┐
│             (≡) (+)  │    │ <                    │     │(Cancel) Load Type (Save)
│ Exercises            │    │[▣] ▌Chest            │     │         Dip          │
│ 56 exercises         │    │    Seated Chest Press│     │┌────────┐┌────────┐  │
│ [🔍 Search exercises] │    │    [Machine][↑Wtd]   │     ││Weighted││Bodywt  │  │
│ [Ch][Bk][Sh][Ar][Lg] │    │[9 Wkts|Sat|27 Sets]  │     │└────────┘└────────┘  │
│ ▌Chest            10 │    │ Progress             │     │┌────────┐┌────────┐  │
│┌────────────────────┐│    │┌────────────────────┐│     ││BW+add ✓││Assisted│  │
││Bench Press  ✸145×6 ││    ││Chest Press 2      >││     │└────────┘└────────┘  │
││Barbell         Sat ││    ││✸ 105 lb × 8  (hero)││     │ ↑ Your body plus…    │
│├────────────────────┤│    ││133 1RM  +17%       ││     │┌────────────────────┐│
││Dip          ✸+15×8 ││    ││ ~~~~ chart ~~~~    ││     ││→ Sets from now [BW]││
││[BW + added] Sep 12 ││    │├────────────────────┤│     ││↺ 6 sets logged [W] ││
│└────────────────────┘│    ││Chest Press · 45kg×8││     │└────────────────────┘│
└──────────────────────┘    └──────────────────────┘     └──────────────────────┘
```

Relative sizes: E01 title `largeTitle`-style nav title, family tiles equal; E02 name `title`, the
best figure `heroNumber` (the one hero), stats `statNumber`; record tiles `statNumber`.

## Rules and identifiers kept

Kept: `exerciseFilterMenu`, `exerciseFilter.tag.<raw>`, `exerciseFilter.tag.all`,
`clearExerciseFilters`, `noExercisesMatch`, "Search exercises", "Add Exercise…", the menu items
"Progress…", "Presets…", "Load type…", "Rename…"; `newExerciseName`, `newExerciseLoadType`
(now the tile group), `saveNewExercise`; `noPresets`, `preset.<name>`, `newPresetName`,
`addPreset`, `presetSuggestion.<name>`; `editLoadTypePicker` (tile group), `saveLoadType`,
`editLoadTypeHistoryNote` (the ledger's logged row).
Changed: `exerciseFilter.bodyArea.*` (the submenu) → `exerciseFamily.<Family>` tiles.
New: `exerciseRow.<name>`, `exerciseDetail`, `exerciseProgressPanel`, `exerciseVariation.<n>`,
`exerciseRecords`, `exerciseSetupLoadType`, `exerciseSetupPresets`, `exerciseRename`,
`exerciseMachine.<label>`, `exerciseSession.<n>`, `exerciseGrouping.<raw>`, `addExerciseToolbar`,
`addTypedExercise`, `newExerciseBodyArea.<area>`, `newExerciseTag.<raw>`, `newExerciseTaken`,
`loadType.<raw>`, `presetDelete`, `machineExercise.<name>`.

## New / changed visible strings

New: "N exercises", "Group by", "Body area", "Last trained", "A–Z", "This week", "Last week",
"Earlier", "Not trained yet", "Uncategorized", "Add “<name>”…", "Today", "Yesterday",
"Workouts", "Sets", "Progress", "1RM", "Since first session", "N days", "Weight records",
"Least-assistance records" + "lower is better", "Added-weight records", "Bodyweight record",
"Most reps", "N reps", "Load type", "Presets", "No presets yet", "Machines", "History", "N workouts",
"Not used yet", "“<name>” is already an exercise.", "Equipment", "Delete “<name>”?", "Logged
sets keep it.", "Delete Preset", "Sets you log from now on", "N sets already logged".
Changed (decision 3): the four load-type explanations → "More weight is harder. Records rank
the heaviest set." / "Your body is the load. Log reps alone." / "Your body plus any weight you
add." / "Less assistance is harder. Records rank the least."; the "What this changes" section →
the ledger. "Presets" header / "Add" header of the presets sheet → the list and field; the sheet
title moves to "Presets" with the exercise name under it.
Removed: the Body Area filter submenu; "Common" stays as the suggestions' title.

## Tells (ios-design step 4)

- Same container on everything: absent — lists for rows (catalog sections, variations, setup,
  machines, history, presets), one panel for Progress, tiles only for choices and record figures;
  titles, fields and section headers sit on the ground.
- Chips: deliberate — equipment/load/Custom tags are information (a row wears at most two);
  body-area, equipment and suggestion chips are choices.
- All-caps labels: absent.
- Middle-dot metadata: deliberate for equipment lines ("Chest Press 2 · Narrow grip") and
  variation details ("Narrow grip · 2 days").
- Accent everywhere: absent — violet fills only the state's one command (Add / Save / Add “…”);
  the new-best burst uses the positive colour as a state.
- Equal full-width blocks: absent — E02 leads with the Progress panel; the family tiles and load
  tiles are deliberate equal choices.
- Phone-sized website: absent; E02's first viewport = identity, stats, the best figure.
- Control dressed as primary: absent — the filter menu is a glyph; Done/Cancel are glass capsules.
- Only survives default size: answered by AXL captures (family tiles 2-column, rows stack their
  trailing values, stat strip becomes rows, sheet titles leave the bar).

## Tests (planned)

- Unit `ExerciseOverviewTests`: stats (warmups excluded, load-type filter, assisted lower wins,
  tie not a new best, first time not a new best, unfinished workouts ignored), recent sessions
  and new-best set ids, machine uses (archived excluded, served-but-unused included), preset
  usage/bests, grouping sections and buckets, family filter (no-hide rule, old body-area value),
  name taken.
- UI: new `FloodlightExercisesUITests` — captures E01 (default, family chosen, no match), E02
  (trained top/records/bottom, assisted, untrained, custom), E03 (empty, taken), E04 (list,
  empty, duplicate), E05 (unchanged, changed) light/dark × Default/AXL; flows: row → E02 →
  Load type save; E02 → Presets add/rename/delete-with-confirm; New Exercise from the tab opens
  E02 and refuses a taken name; machine page exercise row → E02.
- Updated neighbours: `ExercisePresetUITests`, `ProgressChartUITests`, `ProgressChartTooltipUITests`,
  `CoreLoopUITests` (mid-workout creation), `RedesignScreenshotUITests` test06/test07.

## Verification

Runner `/tmp/wt-floodlight/ex-run.sh <name> build|test …` (NEW derived data `/tmp/wt-floodlight/dd-exercises`,
`-collect-test-diagnostics never`); logs, `.exit` files and result bundles `/tmp/wt-floodlight/results/exercises-*`.

- `exercises-unit-1` (exit 65): the two SwiftData tests released their in-memory container right
  after taking its context (SwiftData traps; every later test in the process reported "crashed").
  `exercises-unit-2` isolated it. Fixed by keeping the container alive.
- `exercises-unit-3`: **exit 0 — 15/15** `ExerciseOverviewTests`.
- `exercises-build-1`: exit 0 (build-for-testing, the five screens; no warnings in the changed files).
- `exercises-ui-1` (exit 65, **6/7**): the light-default capture pass and five flows passed (load
  type save with the "3 sets already logged" ledger, New Exercise refusing "  seated chest PRESS "
  then opening Zercher Squat with its body area, no-match prefill, family filter remembered, machine
  page → exercise). The captures showed a catalog row wrapping "Machine / Assisted" onto two lines:
  the row's details now take one line whenever they fit (`ViewThatFits`). The presets flow failed on
  test mechanics (the edit menu's Select All vanished before the tap).
- `exercises-ui-2` (exit 65): dark default and light default passed (the light pass took 415 s
  against 167 s before — a slow simulator, no failure); both AXL passes failed at the same step:
  after the Presets sheet closed, the Load type row sat under the navigation bar and the tap missed.
  The test brings it clear first. The presets flow failed again: `exercises-ui-3` (diagnostic shots)
  showed the keyboard still rising when Save was tapped — the alert moved up and the tap landed where
  Save had been. Not a product fault; the test lets the alert settle.
- `exercises-ui-4`: **exit 0** — presets: add from a suggestion, rename by tap, swipe → the
  confirmation (nothing deleted before it) → deleted, back to the empty panel.
- `exercises-ui-5`: **exit 0** — both AXL capture passes. Their captures showed layout faults, fixed:
  a catalog row's wrapped "Fri" overlapping the next row (the shared `WrapLayout` measured one line,
  then placed two when handed back its own width rounded to pixels — it now has 0.5 pt of slack,
  which changes other screens only in that edge case); "Shoulders" truncated on its family tile (the
  map is capped at AX sizes); "Load type · Weight-ed" squeezed (the type is the row's subtitle at AX
  sizes). Also: the "Common" heading's first letter was clipped by its zero-inset list row (padded);
  the no-match capture now dismisses the keyboard first.
- `exercises-ui-6`: **exit 0** — the four capture passes after the AX fixes.
- `exercises-ui-7` (exit 65, **20/22**): the neighbours — ProgressChart 2/2, ProgressChartTooltip 4/4,
  GymsFlows 4/4 (the machine page's changed rows), CoreLoop mid-workout exercise creation (the shared
  New Exercise sheet), RedesignScreenshot test05–07 — and the six new flows on the final product code.
  ExercisePreset 0/2: `app.buttons["Done"]` matched the sheet's Done AND the keyboard's return key
  ("Done", the field's submit label). The sheet's Done is now `sheetDone`.
- `exercises-ui-8` (exit 65): the four capture passes **passed** (the no-match shot now ends editing
  and asserts Add “…” is on screen); ExercisePreset failed after the sheet closed: `exercises-ui-9`
  showed the search field regaining focus when the sheet closed (iOS restores focus), its keyboard
  covering the tab bar, so the Gyms tab tap was lost. The shared helper `exercisesTabRow` now ends
  editing with Search after typing. `exercises-ui-10`: the Add tap then landed while the sheet rose
  with the keyboard (the test settles first). Test mechanics throughout; no product change.
- `exercises-ui-11`: **exit 0** — ExercisePreset 2/2. `exercises-ui-12`: **exit 0 — 8/8**, every other
  user of the changed helper (ProgressChart, ProgressChartTooltip, CoreLoop creation, RedesignScreenshot
  test05).
- **Every targeted test has passed in its final form**: unit 15/15 (`exercises-unit-3`); the four
  capture passes (`exercises-ui-8`); the six flows (`exercises-ui-7`, after which only the Done
  identifier and test code changed); the neighbours (`-ui-7`, `-ui-11`, `-ui-12`).
- Captures: `../captures/08/` (80 PNGs, from `exercises-ui-8`): E01 (list ×2, a family chosen, no
  match), E02 (trained, paged to History; assisted; user-made; untrained), E03 (empty, taken name), E04
  (list, duplicate, empty), E05 (unchanged, changed with the ledger) — light/dark × Default/AXL.
  Contact sheets beside the prototype: `/tmp/wt-floodlight/results/exercises-sheets/compare-*.png`,
  `states-light-default.png`. The prototype's light E01–E04 captures had come out blank (the variant
  capture overlapped them); retaken, all 64 prototype PNGs now have content.
- Not exercised: VoiceOver by a person, Reduce Motion by a test (gates read in code: the family strip's
  entry light-up, chip and tile selection, the ledger's entrance, the preset list's insertions), the
  drag-to-reorder gesture itself (Edit shows the handles; the move writes the same renumbering the
  old sheet did), a real device.

Scope (DEVELOPMENT: a whole area restyled plus a new screen and shared sheets — New Exercise opens
from the mid-workout pickers; the machine page links in): build; unit tests for the new Domain
readouts; every Exercises flow above; the neighbours that walk the tab, the progress chart, presets
and mid-workout creation; captures light/dark × Default/AXL. Full UI suite deferred to the
whole-redesign release candidate (ticket 01 step 4). Simulator WT-Floodlight (iOS 27.0).

## Progress

- 2026-09-27: resumed in a fresh session; verified branches (exercises = scan tip `7655aa7`,
  pushed, clean; nothing merged or installed). Read ticket 01/07, the prototype Exercises area and
  the real Exercises code; prototype captured into `../reference/prototype-exercises/`. User
  decisions 1–4 recorded. Ticket written.
- 2026-09-27: `Domain/ExerciseOverview.swift` + `ExerciseOverviewTests` (`0112885`); the screens
  (`efd60fe`): `ExercisesPieces`, E01 `ExercisesView`, E02 `ExerciseDetailView` (new), E03
  `NewExerciseSheet`, E04 `ExercisePresetsSheet`, E05 `EditExerciseLoadTypeSheet`; machine page
  exercise rows → E02; `SearchFieldView` takes an identifier; `ExerciseProgressView.words(for:)` now
  uses the shared `ExerciseOverview.variationWords`. Fixture: `-uiTestDesignExercises` (presets and a
  Narrow-grip variation on the chest press, assisted pull-up and dip history, a user-made Landmine
  Press). New `FloodlightExercisesUITests` (4 captures + 6 flows); neighbours moved to the tab's own
  search field (`app.exercisesTabRow`): ExercisePreset, ProgressChart, ProgressChartTooltip,
  RedesignScreenshot test05–07, CoreLoop mid-workout creation.
- Implementation notes: the progress chart opens from E02 as the sheet it already is (both older
  callers present it that way; a pushed copy would carry a Close button); the 1RM figure is in the
  display unit (D52 plain number); the mini chart is the machine page's `MachineBestChart`.
  `exerciseBrowseMuscleGroup` now holds a family name: only the Exercises tab reads that field
  (checked: no other reader; export does not include it).

## Codex review 08 — response (round 1)

Report: [codex-review-08.md](../codex-review-08.md) — not clear; five medium, two low. All accepted.

1. **Recent sessions used the first entry's context for every set.** `ExerciseOverview.Session` now
   holds `groups` — one per entry context (equipment · preset, snapshot load type), adjacent entries
   with the same context merged — and E02 shows each group's words over its own sets, formatted by
   its own load type. Unit test `sessionsKeepEachEntrysOwnContext` (narrow grip assisted, then wide
   grip re-typed Weighted).
2. **The hero's new-best mark was judged by chart day.** `ExerciseOverview.variationStat` scopes the
   sets to the variation and reuses `stat`'s workout rule; the hero's best and mark come from it (the
   chart keeps its days). Unit tests: two workouts on one day (evening best is marked), a first
   workout across midnight (not marked), a later lighter workout (not marked).
3. **The Load Type ledger badged old sets with the current type.** `loggedSetCounts` counts by each
   entry's snapshot load type; the ledger shows one row per type logged. Unit test
   `theLedgerCountsSetsByTheTypeTheyWereLoggedUnder` (3 Weighted, corrected to Assisted, 1 Assisted).
4. **Placeholder contrast in dark (4.13:1).** "Name" and "New preset (e.g. Wide grip)" use
   `textSecondary`: 6.51:1 dark, 5.91:1 light on `field`.
5. **Edit bypassed Reduce Motion.** Edit/Done go through `setEditing`, unanimated under Reduce Motion.
6. **`page(to:)` could pass without reaching its target.** It now asserts the element was reached.
7. **AXL sheet captures stopped short.** E03 pages down to the Equipment chips (asserted on screen);
   E05 changed scrolls until the logged-sets row is on screen (asserted), shot as `…-2`.

Verification (round 2): `exercises-build-12` exit 0; `exercises-unit-4` **exit 0 — 20/20**.
