# 23 — New/Edit Template: Exercises | Machines, with Add Machine and Scan

Type: change
Status: **ready** (2026-10-23)
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

