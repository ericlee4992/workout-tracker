# 08 — Machine-first logging & free-weight context

**What to build:** The equipment-aware speed interaction (D7): adding by machine. Picking a single-exercise machine auto-selects its exercise; picking a multi-exercise station (model linked to several exercises) prompts for which; free-weight logging attaches the equipment-type tag (barbell/dumbbell/cable/smith/bodyweight) persisted on the entry. Entry point: an "Add by machine" path in the active workout alongside the exercise-first path.

**Blocked by:** 07.

**Status:** resolved

- [x] Single-exercise machine → entry created with exercise auto-filled, zero extra prompts
- [x] Multi-exercise station → exercise chooser listing only that model's linked exercises
- [x] Free-weight tag persists on the entry and is captured in the snapshot (history rendering of tags belongs to ticket 09)
- [x] Model-less machines open the full exercise picker (per ticket 06) instead of auto-fill
- [x] Exercise-first path still works: pick exercise → optionally pick machine (remembered per gym via memory)

---

**Comment (2026-08-08, agent):** Implemented in `WorkoutSession` +
`AddByMachineSheet`. Service: `exercisesFor(machine:)` resolves the machine's
model `exerciseIDs` to exercises in link order (empty for model-less machines
or dangling ids), and `addEntry(machine:exercise:to:)` creates the entry with
the machine set (delegates to the ticket-07 `addEntry`, so unit precedence,
draft set, and provisional snapshot behave identically). UI: "Add by Machine"
button next to Add Exercise in the active workout (hidden for no-gym
workouts) opens `AddByMachineSheet` — non-archived machines at the workout's
gym; one linked exercise auto-fills with zero prompts, several push a chooser
restricted to the model's links, model-less pushes the full searchable
exercise picker; the created entry always carries the machine. Free-weight
exercise-first path untouched; snapshot tag capture (D23) verified by test.
Service tests in `WorkoutTrackerTests/MachineFirstLoggingTests.swift`; full
suite green on WT-iPhone (79 tests).
