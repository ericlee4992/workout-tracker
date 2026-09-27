# 06 — Floodlight: Gyms

Type: feature (part of [01](01-implement-redesign.md))
Status: implemented and verified (targeted); Codex review 06 next
Implementer: Claude. Reviewer: Codex.
Branch: `ericlee4992/redesign-floodlight-gyms` (scratch checkout `/tmp/wt-floodlight/gyms`),
stacked on the ticket-05 history tip `646187e`.

## User decisions (2026-09-27, asked in session)

1. **Scan is its own ticket 07.** IdentifyEquipmentSheet, ScanMachineLabelSheet,
   LabelCameraView, MachineModelCorrectionSheet (S01–S07) are not restyled here. Every entry
   point to them keeps working unchanged (the gym page's Scan Machine opens the existing flow).
2. **Add Machine… keeps its form, restyled** (not the prototype's catalog-first flow): a
   machine with no model can still be added by typing a label; the scan buttons, exercises for a
   model-less machine, preset and unit stay in the one form. The new machine page (G04) carries
   inline setup for later edits.

## Scope

The Gyms tab in the approved Floodlight design. Reference: `../reference/captures/*/G03-final.png`
and the prototype captures taken 2026-09-27 into `../reference/prototype-gyms/{dark,light}/`
(`LOOKS=final … AXL=1 SETTLE=4 scripts/capture.sh all …`: G01, G01-deleted, G02, G03 + p2/p3/empty,
G04 + p2/p3/unused/nomodel, G05 + new, G06 + search/nomatch/new, G07; default and AXL).

1. **Gyms list (G01).** Large "Gyms" title. One card per gym: monogram tile (the name's
   initials), name, "Seoul · lb" (city · the gym's own unit, each only when set), the **Current**
   badge on the gym Home is set to, then a stat strip — **Visits** (distinct days with a finished
   workout there), **Last visit** ("Today" / "Yesterday" / weekday this week / "Sep 17"),
   **Machines** — and, once visited, **Last 8 weeks**: eight cells, oldest → this week, lit with
   the week's visit count, this week dashed when unvisited. Order: the Current gym, then most
   recently visited, then A–Z. Dashed **Add Gym…** under the cards. **Deleted gyms** (when any):
   one quiet row with the count that expands in place; each gym with **Restore**.
2. **Empty (G02).** The building emblem in a dashed ring, "No gyms yet", and **Add Gym…** as the
   screen's one filled command.
3. **Gym page (G03).** Hero: monogram, name (title), "Seoul · lb"; the stat strip; **Scan
   Machine** as the one filled command (opens the machine form straight into the existing scan
   flow — `MachineEditorSheet(startsWithScanner: true)`, the same path AI routine setup uses).
   **Machines** heading with the grouping as segmented pills (Body area · Exercise · A–Z; a
   compact menu at AX sizes; hidden with fewer than two machines). Groups keep today's
   `CatalogBrowsing.machineSections` rules (D23 display only, remembered in AppPreferences);
   each group is one panel with its title, a family swatch when the body area maps to a family,
   and the count. A machine row: the equipment-type glyph (from the model's equipment type; a
   dashed cell with no model), the label (+ unit tag when the machine overrides the unit), the
   model name without its maker ("No model" otherwise); trailing, its **best** (burst + "105 lb ×
   8", Assisted tag when lower is better) over **last used** (clock glyph + day). Under Exercise
   grouping the numbers are that exercise's on this machine. Never used: no numbers. Tap opens
   the machine page (G04). Swipe → Delete (unchanged confirmation). The long-press menu stays
   (Edit Machine…, Correct Model…, Rename Model…, Delete Machine…). Dashed **Add Machine…**;
   **Deleted machines** row with the count. Toolbar: back and a pencil (**Edit Gym…**). Empty
   gym: "No machines yet" + Add Machine….
4. **Machine page (G04) — new screen.** Hero: glyph tile, label (title), the model's full name
   (or "No model"), tags (equipment type, Custom, unit override). Stat strip (when used): **Times
   used** (workouts), **Last used**, **Sets** (completed sets). **Bests**: one panel, a row per
   record scope on this machine (exercise × preset × load type): the most-used scope first with
   its best as the big figure, "N workouts" and a chart of its best set per session (new bests
   labelled); the others as rows with their best. Each opens the progress chart on that exact
   variation (`ExerciseProgressView(initialVariation:)`). Not used yet: a dashed "Not used yet"
   row. **Setup** (applies immediately, D2): Name (inline field, commits on Done / leaving the
   field; blank restores), Default unit ("Gym (lb)" · kg · lb), **Usually** (preset chips — "Ask
   each time" + the presets — when the machine serves exactly one exercise with presets). 
   **Exercises**: the exercises it serves (information rows: name, muscle group, load-type tag).
   **Model**: model name + manufacturer, Custom tag; **Correct Model…** (or **Choose Model…**
   with no model) opens the existing correction sheet; **Rename Model…** for a user-made model
   (existing alert). **Delete Machine…** (existing confirmation; the page closes).
5. **New / Edit Gym (G05).** A Floodlight sheet: Cancel · "New Gym"/"Edit Gym" · Add/Save.
   A live preview card (monogram, name — "New Gym" placeholder — and city · unit); Name and City
   in one panel; **Default unit** as three pills "App (kg)" · kg · lb; edit only: "Future sets
   only. Logged sets keep their unit." and **Delete Gym…** (confirmed: "Delete Iron Temple?" —
   "Logged workouts keep the gym's name." — Delete Gym / Cancel). Add needs a name; Save needs a
   name and a change. Delete = archive (D10), restorable from the Gyms list.
6. **Machine form (Add / Edit Machine).** The same fields and rules as today (user decision 2),
   as a Floodlight sheet on the native Form (`lookGroupedList`, as the other kept forms): label,
   Catalog model row (pushes the picker), Scan equipment… / Read label on device, Exercises (no
   model), Preset (single-exercise), Default unit.
7. **Model picker (G06).** Kept as the pushed list with the native search field (the UI tests
   and the iOS 27 search drawer rely on it). New: **equipment-type chips** in a row under the
   search (All · Selectorized · Plate-loaded · Cable & functional · Rack, Smith & bench ·
   Bodyweight station, each with its glyph) — replacing the Equipment Type submenu (this also
   fixes the iOS 27 test failure, item 9); a **grouping capsule** menu (Manufacturer · Body area
   · Equipment type · A–Z); **New Model…** pinned at the top as a dashed pill, **prefilled from
   the search** ("life fitness leg press" → Life Fitness / Leg Press; otherwise the whole search
   is the model). Rows: glyph tile, the model (maker omitted under Manufacturer grouping), what it
   serves ("Seated Chest Press, Incline +2"), a pin + label when a machine at this gym already
   uses it, Custom tag, the check on the selection. "None" stays first. No match: "No models
   match" with New Model… showing the name it will start from. Body-area filter stays in the
   toolbar menu.
8. **New Model (G06-new).** A Floodlight sheet: preview (glyph, name, Custom / type / "N
   exercises" tags), Manufacturer and Model fields, **Equipment type** as glyph chips, then
   **Exercises**: "Link at least one." / "N linked", the linked ones as removable chips, Suggest
   exercises with AI (unchanged rules, consent alert and cancellation), an exercise search, and
   the checklist. Add needs both names and ≥ 1 exercise.
9. **Deleted machines (G07).** Title "Deleted Machines" with the gym's name under it; rows with
   the glyph (dimmed), label, model and "N workouts" when it carries history; **Restore** as a
   quiet pill (a check, a success haptic, the row folds away). Empty: "Nothing deleted".
10. **iOS 27 test fix.** `CoreLoopUITests.testModelPickerFiltersAndSearchesDownToOneModel`
    (:252) failed because the type submenu of the browse menu did not open on iOS 27. The type
    filter is now the visible chip row (same identifiers); the test taps the chip.

Not in this ticket: the Scan screens (ticket 07); the prototype's catalog-first Add Machine (user
decision 2); the model picker's in-picker Scan Machine pill and correction-scope alert (the
correction sheet belongs to ticket 07); an exercise detail page (Exercises area) — the machine
page's exercise rows are information only for now.

## Prototype features the real app lacked (approved with the prototype; each can be vetoed)

- Gym cards: visit count, last visit, the 8-week visit rhythm; the **Current** badge; the
  Current-first / recent-first order (was A–Z).
- Deleted gyms with **Restore** on the Gyms list (the app could archive a gym but never bring
  it back; `EquipmentLifecycle.restore(_ gym:)` is new). "Archive Gym" (toolbar menu, no
  confirmation) becomes **Delete Gym…** in Edit Gym, confirmed.
- Scan Machine as the gym page's primary button (was inside the machine form only).
- Machine rows with **best** and **last used**; grouping as visible **pills** (was a toolbar
  menu); equipment-type **glyphs**.
- The **machine page** (bests with a chart, inline setup, exercises, model actions). Tapping a
  machine row opened nothing before; the long-press menu remains.
- Model picker: visible **type chips**, New Model… **prefilled from the search**, "at this gym"
  pin, what each model serves.
- New Model: preview, type chips, linked-exercise chips, exercise search.
- Deleted machines: "N workouts" per row. (The prototype also shows "Deleted Sep 2"; the app
  does not store when a machine was deleted, so that part is left out rather than adding a
  schema field.)

## Domain (derived on read, unit-tested) — `Domain/GymOverview.swift`

- `GymOverviewMath.visits(…)`: per gym, distinct calendar days with a finished workout there,
  the last visit, and the last 8 weeks' visits per week on the phone's calendar (the same weeks as
  Home and History).
- `GymOverviewMath.order(…)`: Current gym first, then most recent visit, then name.
- `MachineUse` / `GymOverviewMath.machineUse(…)`: from finished entries whose SNAPSHOT machine is
  this machine (D23): workouts, last used, completed sets, and one best per record scope
  (exercise × preset × load type) ranked with `RecordsMath.isEligible` / `outranks` (warmups
  out, assisted lower is better, ties to the earliest); scopes ordered by workouts then recency.
  A row's best is the first scope's (or, under Exercise grouping, that exercise's first scope).
- `GymOverviewMath.relativeDay(_:now:)`: "Today" / "Yesterday" / weekday within this week /
  short date.
- `GymOverviewMath.newModelPrefill(query:manufacturers:)`.
- `EquipmentLifecycle.restore(_ gym:)`.
- Rules kept: history reads snapshots only; a renamed or re-modelled machine keeps its history
  because the scope is its id; display conversions plain (D52) — bests show as entered.

## Screen jobs, bold element, wireframes (ios-design steps 1–2)

- **Gyms list:** exists so the user can open a gym in one tap; the eye lands on the first card
  (top-leading). Runner-up: Add Gym… (dashed, quiet).
- **Gyms, empty:** exists to invite the first gym; the eye lands on Add Gym… (filled).
- **Gym page:** exists so the user can find or add a machine in one tap; the eye lands on the
  hero name + Scan Machine (the only filled command). Runner-up: the machine panels.
- **Machine page:** exists to see what this machine holds and fix its setup; the eye lands on the
  top best's figure (the one `heroNumber`). Title is `title`, not larger.
- **New/Edit Gym:** exists to name a gym and its unit; the eye lands on the preview card; Save/Add
  is the one filled command.
- **Model picker:** exists to find one model in seconds; the eye lands on the search field.

```
Gyms                       Iron Temple (gym)            Chest Press 2 (machine)
┌──────────────────────┐   ┌──────────────────────┐    ┌──────────────────────┐
│ Gyms          (large)│   │ <                  ✎ │    │ <                    │
│┌────────────────────┐│   │ [IT] Iron Temple     │    │ [▤] Chest Press 2    │
││[IT] Iron Temple [Cur]│   │      Seoul · lb      │    │  Life Fitness Insig… │
││     Seoul · lb     >││   │ 18   │Yesterday│ 16  │    │  [Selectorized]      │
││ 18  │Yesterday│ 16  ││   │Visits│Last vis.│Mach.│    │ 8   │ Sep 19 │ 28    │
││ Last 8 wk ▮▮▮ ▮▮▮  ││   │[●  Scan Machine    ]│    │Times│Last use│ Sets  │
│└────────────────────┘│   │ Machines             │    │ Bests                │
│┌────────────────────┐│   │ (Body area|Exer|A–Z) │    │┌────────────────────┐│
││[HG] Hotel Gym     > ││   │ ■ Chest  2           │    ││Seated Chest Press >││
││ 1 │ Aug 31 │ 0      ││   │┌────────────────────┐│    ││✸ 105 lb × 8  (hero)││
│└────────────────────┘│   ││[▤] Chest Press 2 ✸105││    ││6 workouts  ╱chart╲ ││
│ [+ Add Gym…  dashed] │   ││    Insignia…   ◷ Sep ││    │├────────────────────┤│
│ 🗑 Deleted gyms   1 ⌄ │   │└────────────────────┘│    ││Narrow grip  ✸90×10 ││
└──────────────────────┘   │ [+ Add Machine…]     │    │└────────────────────┘│
                           │ 🗑 Deleted machines 2 >│    │ Setup / Exercises /  │
                           └──────────────────────┘    │ Model / Delete Mach… │
                                                        └──────────────────────┘
```

Relative sizes: gym card titles `cardTitle`; stat figures `statNumber` (dates a size down,
expanded heavy, on the same baseline); the machine page's top best is the one `heroNumber`.

Structure: the Gyms list is a ScrollView of cards (no swipe needed). The gym page stays a native
`List` (panel rows via `historyPanelRow` / `historyPageRow`, moved to a shared name) so machine
rows keep the native swipe-to-delete, the context menu and VoiceOver actions. The machine page
and Deleted Machines are ScrollViews of panels.

## Rules and identifiers kept

List: `gymRow.<name>` (each card), `addGym`. Gym page: `editGym` (the pencil),
`machineRow.<label>` (row container), `deleteMachine.<label>` (swipe), `addMachine`,
`deletedMachines` (label contains the count), `machineGrouping.<raw>` (now the pills),
the delete confirmation ("Delete <label>?" / Delete Machine / Cancel, its message), the context
menu items. Gym sheet: `gymName`, `gymUnitPicker` (the pills' container; the pills are buttons
"App (kg)", "kg", "lb"), `saveGym`. Machine form: `machineLabel`, `catalogModel`,
`scanMachineLabel`, `scanLabelOffline`, `machinePresetPicker`, `machineUnitPicker`,
`saveMachine`. Picker: `modelOption.<displayName>`, `modelBrowseMenu`,
`modelGrouping.<raw>`, `modelFilter.bodyArea.<area>` / `.all`, `modelFilter.type.<raw>` /
`.all` (now chips), `clearModelFilters`, `noModelsMatch`. New Model: `newModelEquipmentType`
(chip container), `newModelExercise.<name>`, `newModelExerciseReason.<name>`,
`newModelSuggestExercises`, `newModelSuggestStatus`, `newModelSuggestNote`, `saveNewModel`.
Deleted machines: `restoreMachine.<label>`, "Nothing deleted".
Kept behaviour: D2 (gym and machine edits where shown), D3 (a picked model names the machine by
its movement), D10 (delete = archive; correction scope), D23 (grouping is display only), D24
(user models alongside the catalog, ≥ 1 exercise), D35/D53 (scan prefill, AI suggestion rules
and consent), D38 (usual preset preselected, never binding).
New identifiers: `gymCity`, `deleteGym`, `deletedGyms`, `restoreGym.<name>`, `scanMachine`
(gym page), `machineDetail.name`, `machineDetail.unit`, `machineDetail.best.<index>`,
`machineDetail.correctModel`, `machineDetail.renameModel`, `machineDetail.delete`,
`newModelFromSearch`, `newModelType.<raw>`.
Removed: `gymMenu` (Group By → pills; Edit Gym… → pencil; Archive Gym → Delete Gym… in the
sheet).

## New / changed visible strings

New: "Current"; "Visit"/"Visits", "Last visit", "Machine"/"Machines", "Last 8 weeks", "Today",
"Yesterday"; "Deleted gyms", "Restore"; "No gyms yet"; "Scan Machine"; "Machines" (heading);
"Body area", "Exercise", "A–Z" as pills; "Times used", "Last used", "Set"/"Sets"; "Bests",
"N workouts", "Not used yet"; "Setup", "Name", "Default unit", "Gym (lb)", "Usually", "Ask each
time"; "Exercises"; "Model", "Choose Model…"; "Delete Machine…"; Edit Gym "City" + "Required" /
"Optional" prompts, "App (kg)", "Future sets only. Logged sets keep their unit.", "Delete Gym…",
"Delete <gym>?", "Logged workouts keep the gym's name.", "Delete Gym"; picker "All", the type
names on chips, "N models", "Custom" tag, "Link at least one.", "N linked", "Search exercises".
Changed: gym form "City (optional)" → "City" with "Optional"; the long unit footers → the one
short line (edit) / none (new); "Archive Gym" → "Delete Gym…"; "Deleted machines (2)" → "Deleted
machines" + count.
Removed: "app default" caption on gym rows; the gym page's "Default unit" / "City" rows (in the
hero now); footers "The model is optional — …", "A restored machine returns to the pickers as it
was. Your history never left.", "Can't find the machine's model? …".

## Tells (ios-design step 4)

- Same container on everything: absent — cards only for groups (a gym card = identity + stats +
  rhythm; the stat strips; machine groups; the bests panel; the form panels); titles, the
  Machines heading, Scan Machine and the dashed make-rows sit on the ground.
- Chips: deliberate — tags are information (unit override, Custom, type, Assisted), at most two
  on a machine row (unit tag + Assisted); type chips in the picker are filters (visible options).
- All-caps labels: absent (the old uppercase "MACHINES" section header is gone).
- Middle-dot metadata: deliberate for the place line ("Seoul · lb").
- Accent everywhere: absent — violet fills only Scan Machine / Add Gym… (empty) / a sheet's
  commit; selection uses the lozenge; bests use the positive burst.
- Equal full-width blocks: absent — the hero (monogram + title) leads the gym page, the top best
  (hero figure + chart) leads the machine page.
- Phone-sized website: absent. First viewport: list = two gym cards + Add Gym…; gym page =
  hero, stats, Scan Machine, pills and the first group; machine page = hero, stats, the top best.
- Control dressed as primary: absent — grouping menus are quiet capsules with a chevron; the
  unit choices are segmented pills.
- Only survives default size: answered by the AXL captures (stat strips become rows, machine
  numbers drop under the names, grouping pills become a menu, the sheet title moves under its
  buttons, unit choices stack).

## Tests

- New unit tests `GymOverviewTests` (9; `gyms-unit-3` ran the first 8): visits as distinct days and the rhythm ending this week;
  order (Current, recent, name); machine use — workouts, sets (warmups included), one best per
  scope (warmup never a best, more reps at a load wins, an uncompleted draft ignored, a preset its
  own scope, another machine's sets excluded); assisted least-assistance and a tie keeping the
  earliest; a group's row showing its own exercises' best (a station under Chest never shows its
  triceps best); snapshot scope through a rename and a re-model, a running workout not counted (store
  test); relative day words; New Model prefill; restoring a deleted gym.
- New fixture `-uiTestDesignGyms` (with `-uiTestDesignSample`): Iron Temple's Pull/Leg Day
  machines (so their history lands on them), a cable station, a model-less "Biceps Curl", a kg
  override on Calf Raise, a deleted "Old Row"; Hotel Gym (New York, one visit); deleted Gangnam
  Fitness.
- New UI captures `FloodlightGymsUITests` (12): list + deleted gyms, gym page (pills, Exercise
  grouping), Deleted Machines, machine page; Edit Gym, machine form, picker (browse, search, no
  match), New Model prefilled from the search — light/dark × Default/AXL; the empty tab ×4.
- New `GymsFlowsUITests` (2): Delete Gym… confirmed (Cancel first) → the page closes → Restore
  from the list; the machine page's best opens its chart, inline rename (blank restores), kg
  override, Delete Machine… closes the page.
- Updated: `CoreLoopUITests` (the city field by `gymCity`; the unit pills tapped directly; the
  gym's place line "Seoul · lb"; the model-picker test taps the type chip — the iOS 27 fix),
  `CodexScreenshotUITests` (unit pill), `ScanMachineLabelUITests` (the row shows the model name
  without its maker).

## Verification

- `gyms-unit-1`, `gyms-build-1` (exit 65): a clean build failed in `ExerciseProgressView`
  ("'Workout' must conform to 'Hashable'" at `navigationDestination(for: Workout.self)`). The
  **unchanged ticket-05 tip fails the same way from fresh derived data** (`gyms-baseline-build`,
  exit 65, Xcode 27.0 27A266a): ticket 05's builds were incremental and never showed it. Naming
  the closure parameter (`gyms-build-2`) and spelling `WorkoutTracker.Workout` did not help; the
  model's conformance is rejected inside that view only. Fix: the Sessions rows push a small
  explicit `ProgressSessionLink` (Hashable by the workout's id).
- `gyms-unit-3`: **exit 0** — `GymOverviewTests` 8 (then), `EquipmentLifecycleTests`, `RecordsMathTests`:
  50/50 (clean build of app + tests included).

Scope (DEVELOPMENT: new feature + shared screens — the Gyms tab, the machine form also opened
mid-workout and from AI routine setup, the model picker also opened from the correction sheet):
build; unit tests for the new Domain rules and the records neighbours; every Gyms UI flow; the
flows that add a machine from elsewhere (Add by Machine, AI routine setup, scan tests that go
through the form); captures light/dark × Default/AXL. Full UI suite deferred to the
whole-redesign release candidate (ticket 01 step 4). Simulator WT-Floodlight (iOS 27.0); logs,
exits and result bundles `/tmp/wt-floodlight/results/gyms-*`.

- `gyms-cap-1` (exit 65): FloodlightGyms 8/12 — list/gym/machine captures ×4 and empty ×4
  passed; the 4 editor runs failed searching the picker (the lazy top row was scrolled away; the
  test scrolls back first). Captures reviewed: fixed the body-area rows showing another area's
  best (a station is listed under each area it serves; each row now shows that area's
  exercises' best — new unit test) and the cramped Edit Gym title at AX (`SheetHeader`
  `reflowsTitle`, opt-in).
- `gyms-ui-1` (exit 65, `-collect-test-diagnostics never`): unit 95/95 (`GymOverviewTests` 9,
  `EquipmentLifecycleTests`, `CatalogBrowsingTests`, `MachineCreationTests`, `RecordsMathTests`,
  `ProgressSeriesTests`); UI 62/73 — **CoreLoop 9/9 incl. the model-picker test (the pre-existing
  iOS 27 failure is fixed)**, MachineDeletion 2/2, ExercisePreset 2/2, CodexScreenshot 3/3,
  ProgressChart + Tooltip all, FloodlightGyms gyms ×4 + empty ×4, GymsFlows delete/restore,
  AskAI 28/32, RedesignScreenshot 2/3, ScanMachineLabel 1/2. Failures, all test mechanics or
  expectations the redesign changed: AskAI identity ×4 (asserted the row's "Maker Model"; the
  row now names the model), FloodlightGyms editors ×4 (Add Machine… half under the tab bar at
  AXL; the no-match New Model… row's label carries its prefill — now found by identifier),
  GymsFlows rename (cursor at the start of the trailing-aligned field), RedesignScreenshot
  test06 (index-0 bar button is now the Edit Gym pencil), ScanMachineLabel create-new (the
  labelled fields' accessibility label — now set explicitly to "Manufacturer" / "Model").

- `gyms-ui-2` (exit 65): 21/24 — AskAI identity ×4 + Ambiguous + New Model consent 6/6,
  FloodlightGyms 10/12 (all gyms/empty captures, both AXL editor runs), GymsFlows 2/2,
  ScanMachineLabel 2/2, RedesignScreenshot test06 AXL. Failures: the two default-size editor
  runs (the no-match New Model… row sat under the keyboard's search bar — the test submits the
  search first) and test06 default, now past the gym steps and failing at the Exercises tab's
  search field (the pre-existing iOS 27 search drawer; `revealedSearchField()` now).
- `gyms-ui-3`: **exit 0 — 13/13**: FloodlightGyms 12/12 (captures from the final code; the
  first gym page shot now after the regrouping settles — the Chest group shows no numbers on
  the cable station and pec deck, which were never used for a chest exercise) and
  RedesignScreenshot test06. Every test in the targeted scope has now passed in its final form
  (`gyms-ui-1` + reruns `gyms-ui-2`, `gyms-ui-3`).
- Captures: `../captures/06/` (86 files from `gyms-ui-3`): gyms list (+ deleted gyms), gym page
  (pages, Exercise grouping), Deleted Machines, machine page, Edit Gym, machine form, picker
  (browse, search, no match), New Model — light/dark × Default/AXL — and the empty tab.
- Not exercised: Reduce Motion by a test (checked by reading each animation's gate — rolling
  counts, restore, card insert, chart draw-in), VoiceOver by a person, the real camera.

## Progress

- 2026-09-27: resumed in a fresh session; verified branches (gyms = history tip `646187e`,
  pushed, clean; main `a0364f2`; nothing merged or installed). Read the prototype Gyms area and
  the real Gyms code/tests; prototype captured into `../reference/prototype-gyms/` (both
  appearance runs exit 0, 76 PNGs). User decisions 1–2 recorded. Ticket written.
- 2026-09-27: Domain `GymOverview` (visits, order, machine use/bests, relative day, prefill) and
  `EquipmentLifecycle.restore(_ gym:)` with `GymOverviewTests`; clean-build fix in the progress
  view (see Verification). Next: the screens.
