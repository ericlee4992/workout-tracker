# 19 — Create exercises mid-workout

**What to build:** You can already add a *machine* mid-workout (`MachinePickerSheet` and
`AddByMachineSheet` both offer "Add Machine…", which opens `MachineEditorSheet` and can create a
user equipment model inline). You cannot create an *exercise*: `ExercisePickerSheet` only lists
what already exists, and the only creation path is the Exercises tab, which is a tab away from an
active workout. Reported as "can't add exercises/machines mid-session" — machines work, exercises
don't, so this ticket closes the real half.

**Blocked by:** None.

**Status:** resolved

- [x] `ExercisePickerSheet` offers "New Exercise…" inline (name, load type, equipment tags), creates
      it as `isSeeded == false`, and immediately selects it for the entry being added
- [x] Searching for a name with no match offers to create that name directly (don't make the user
      clear the search first)
- [x] The multi-exercise chooser reached from a machine (`AddByMachineSheet`) can also create an
      exercise and link it to that machine's model — a station with an unlisted movement is exactly
      when this is needed
- [x] Newly created exercises appear in the Exercises tab and in later pickers, per D24 user ID space
- [x] UI test: mid-workout, create an exercise that does not exist, log a set against it, finish,
      and see it in History

## Resolution

The Exercises tab's creation form was extracted verbatim into a shared
`Features/Exercises/NewExerciseSheet.swift` (name, load type, equipment tags) with two additions:
an `initialName` prefill and an optional `linkTo` model, plus an `onCreate` callback so a caller
can act on the row the instant it exists. `ExercisesView` now presents that same view — no
duplicated form.

`ExercisePickerSheet` gained a persistent "New Exercise…" row and, when the search matches
nothing, a `Create "<search text>"` row prefilled with what was already typed. Creating selects the
exercise for the entry being added and closes both sheets, so the user lands on a set row.

`AddByMachineSheet`'s chooser (both the restricted multi-exercise list and the model-less full
catalog) offers the same two affordances and passes `choice.machine.model` as the link target, so
an unlisted movement on a known station becomes selectable there next time; a model-less machine
falls back to plain creation.

Creation itself moved into `EquipmentLifecycle.createExercise(name:loadType:equipmentTypeTags:
muscleGroup:linkedTo:)` — one UI-free, unit-tested boundary that validates the name, inserts into
D24's user ID space, and appends the id to the model's `exerciseIDs`.

One decision fell out of item 3: the station is usually a *seeded* model, whose `exerciseIDs` is
an allowlisted seeded field, so the next catalog version bump would have silently unlinked the
user's exercise. `CatalogSeeder` now merges (catalog links + user-added links to `isSeeded ==
false` exercises) instead of overwriting, recorded as **D27** refining D24. Stale seeded links the
catalog dropped are still removed.

Tests: `WorkoutTrackerTests/MidWorkoutExerciseCreationTests.swift` (6 tests — user ID space and
immediate loggability, blank-name refusal, model linking + `exercisesFor(machine:)`, model-less
creation, reconciliation leaving the exercise and its link alone, stale seeded links still
dropped) and `testCreatingAnExerciseMidWorkoutLogsASetAndReachesHistory` in `CoreLoopUITests`.
Full suite green: 178 unit + 8 UI.
