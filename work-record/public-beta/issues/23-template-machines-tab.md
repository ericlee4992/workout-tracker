# 23 — New/Edit Template: Exercises | Machines, with Add Machine and Scan

Type: change
Status: **in review** (Codex round 1, 2026-10-23)
Blocked by: 22 (shares its Exercises | Machines switch and the machine list)
Implementer: Claude; Reviewer: Codex.
Branch: `ericlee4992/beta-19-bug-fixes` (tickets 19–23 together).
Ships in: **build 9**.

## Report (the user, 2026-10-23)

"When adding new template on my own, i can't add new machine or scan machine. I want to be able to do that in Add new
template as well. probably also use one exercise button with exercises/machines tabs"

## Decisions (the user, 2026-10-23)

- The template editor's **Add Exercise** gets the same **Exercises | Machines** switch as the live workout (ticket 22).
  Exercises = today's template picker (multi-add, stays open, checks on added rows). Machines = the machines at a gym,
  **Add Machine…** (whose form includes **Scan equipment…**), the station chooser for a multi-exercise machine.
- **Which gym: the Workout tab's selected gym, with a gym menu at the top of the Machines tab to switch**
  ("Selected gym + switch (Recommended)"). No gyms at all: the tab says to add one in Gyms.
- **What a picked machine does: adds its exercise to the template AND records that machine as the user's machine for
  that exercise at that gym** ("Exercise + that machine at that gym (Recommended)") — the existing per-gym memory
  (`GymExerciseMemory`, D6) that a template start resolves from, so starting the template there puts the user on it.
  Other gyms unchanged. No stored-format change. Reopens D6's "last-used machine" → "last used **or chosen**" — record
  as a new decision.

## Acceptance

1. New Template → Add Exercise → Machines lists the selected gym's machines; the gym menu switches gyms.
2. Picking a one-exercise machine adds its exercise (3 × 10, like Exercises); a station asks which exercise; the
   sheet stays open for more, like the Exercises tab.
3. Add Machine… (and its Scan equipment…) creates a machine at that gym; it appears in the list and can be picked.
4. Save the template, start it at that gym: the exercise starts on the picked machine. At another gym: as before.
5. Edit Template works the same. Default and AccessibilityL captures.

## Code map (2026-10-23)

- `WorkoutTracker/Features/Start/TemplateEditorSheet.swift` — `showPicker` → `TemplateExercisePicker` (`:779-862`),
  `addExercise(_:)` `:170`.
- Gym selection: `StartWorkoutView.selectedGym` (`Features/Start/StartWorkoutView.swift:25`).
- Memory: `WorkoutSession.upsertMemory` (`Domain/WorkoutSession.swift:882`), read by
  `EquipmentLifecycle.rememberedMachine` and `WorkoutTemplateService.resolvedMachine` (`Domain/WorkoutTemplates.swift:143`).
- Machine list / station chooser / Add Machine: `AddByMachineSheet` + `MachineExerciseList`, `MachineEditorSheet`
  (has "Scan equipment…").

## Progress

### Build (Claude, 2026-10-23)

- Domain: `WorkoutSession.rememberMachine(_:for:at:)` — the existing per-(gym, exercise) memory upsert
  (`GymExerciseMemory`, same canonical-row rule), now shared with the logged-set path; refuses an archived machine or
  gym; the caller saves.
- Editor (`TemplateEditorSheet`): `EditorItem.machine: MachineChoice?` (machine id + "Pec Deck · Iron Temple"
  caption, shown under the exercise name with the machine glyph); **Save** calls `rememberMachine` for each picked
  machine before writing the template, then saves; Cancel changes nothing. The template itself stores no machine (D6).
- Picker (`TemplateExercisePicker`): `SegmentedPills` Exercises | Machines (id `addExerciseMode`); the Exercises tab
  keeps its `LazyVStack`, the Machines tab sits in a plain `VStack` (its navigation destination must not be inside a
  lazy container).
- `TemplateMachinesTab` (new): the Workout tab's selected gym (`AppPreferences.selectedGymID` via `GymSelection`),
  else the first gym; a gym menu (local to the sheet); the gym's machines (✓ once picked); a station →
  `MachineExerciseList` (now internal, shared with the live sheet); Add Machine… → `MachineEditorSheet` (has Scan
  equipment…); no gyms → "No gyms yet" + where to add one.
- D66 in DECISIONS; README's Templates line.

### Verification (Claude, 2026-10-23; WT-iPhone27, iOS 27, scratchpad `runs/`)

- Unit (`22-final`, same build): `TemplateMachineChoiceTests` (2, new — a remembered pick is where the template
  starts at that gym and not at another; a later pick replaces the earlier one with one memory row; an archived
  machine is never remembered) + `EquipmentLifecycleTests` — **14 passed**, exit 0.
- UI `23-ui-1`: `TemplateMachinesUITests` default + AccessibilityL (New Template → Add Exercise → Machines on Iron
  Temple → Add Machine… shows Scan equipment… → Pec Deck station → its non-remembered exercise → card caption → Save
  → the detail starts it on the Pec Deck), `TemplateDetailUITests/testDeletingFromTheDetail…` and
  `FloodlightWorkoutTabUITests/testEditorSupersetStartsLinkedInTheWorkout` (template picker regressions), warm-up —
  **5/5 passed**, exit 0.
- After the caption glyph fix (`LookIcon`, as Codex found in ticket 22): `23-ui-2` — `TemplateMachinesUITests` ×2 and
  the 2 unit tests **passed**; the warm-up timed out on runner start (untouched code).
- Captures: `runs/shots23/beta-23-{machines,add-machine,station,editor,detail}-{default,axl}.png`,
  `runs/shots23b/beta-23-editor-{default,axl}.png` (with the glyph).
- Commits for review: `git diff 4ceefc7..74adb88` (pushed).

### Codex round 1 (2026-10-23/24): not clear — [codex-review-23.md](../codex-review-23.md)

Three **P2**, one **P3**: #1 a tab switch reset the Machines tab's gym and ✓ (state lived in the recreated tab); #2
with the same exercise picked from two machines, Save replayed rows in display order, so a drag changed the winner
and left a caption wrong; #3 memory was written into the shared context before the template saved — a failed save
could leave it pending for a later save; #4 the UI test's "Pec Deck" assertion was satisfied by the exercise's own
name, "Chest Fly (Pec Deck)". Codex's build exit 0; `TemplateMachineChoiceTests` alone 2/0/0; its serial runs of
`EquipmentLifecycleTests` stalled in `UserNotificationScheduler.cancel` (XPC) on two simulators.

**Response (Claude):**
- #1: the picker (`TemplateExercisePicker`) owns the Machines tab's gym and picks (`@Binding` into the tab); picks start
  from the editor's current choices.
- #2: `MachineChoice` carries its gym; a newer pick for an exercise at a gym becomes the choice of that exercise's
  earlier rows at that gym (`TemplateEditorSheet.choosing`), so every such row — and its caption — says the same
  machine and order cannot matter; Save takes one pick per (gym, exercise).
- #3: `WorkoutSession.stageMachineMemory(_:)` upserts and returns an undo (an updated row's previous machine and date,
  an inserted row deleted); the editor stages before `WorkoutTemplateService.create/update`, whose own save commits
  template and memory together, and runs the undo on any error.
- #4: the test reads the detail row's combined label (`templateExercise.<name>`) and requires "Pec Deck" as its own
  comma-separated part (the equipment line), not a substring; the test also adds a second gym, switches the tab to it,
  goes to Exercises and back, and checks the gym and the Pec Deck's ✓ are kept.
- The stall: **pre-existing and not a hang** — on `main` (`1f0e040`, none of these tickets, `wt-main`), the same
  serial `EquipmentLifecycleTests` on a freshly booted WT-Floodlight **passed 12/12 in 179 s** (`main-eq-serial`): each
  fixture's finish waits on the simulator's notification service. Warm or parallel it takes under a second.
- Tests: `TemplateMachineChoiceTests` + `undoingStagedPicksRestoresTheGymsMemory` and
  `aNewerPickIsTheChoiceForEveryRowOfThatExerciseAtThatGym`. Run `23-r1` (WT-iPhone27): `TemplateMachineChoiceTests`
  (4) + `EquipmentLifecycleTests` (12) **16/16**, `TemplateMachinesUITests` ×2 (with the round trip and the strict
  equipment check), `TemplateDetailUITests/testDeletingFromTheDetail…`, `FloodlightWorkoutTabUITests/
  testEditorSupersetStartsLinkedInTheWorkout`, warm-up — **21/21 passed**, exit 0.
- #4 negative check (`23-negative`, a scratch copy of `0b00c4e` with the editor's `stageMachineMemory` call removed,
  never committed): `testAPickedStationMachineIsWhereTheTemplateStarts` **fails** at the equipment assertion — the row
  reads "Chest Fly (Pec Deck), 3 sets · 10, 10, 10 reps" with no equipment part. With the write it passes (`23-r1`).
