# 01 — Delete a machine from a gym: on the Gyms tab and mid-workout

Status: built 2026-09-10 — Codex round 1 answered, awaiting round 2

User, 2026-09-10: "I also want to add a feature to delete added machines from gym (whether mid
workout, or just at gym tab)."

## What exists

- D10: archive instead of delete, so history keeps resolving. `EquipmentLifecycle.archive(machine)`
  exists and the Gyms tab exposes it — but only as "Archive Machine" inside a long-press context
  menu, which is where nobody looks, and the word is not the user's.
- Mid-workout, the "Add by Machine" sheet lists the gym's machines and offers no way to remove one.
- Nothing lists archived machines or brings one back: a slip is permanent from the user's side.

## What to build

- **The user's word is Delete.** On both machine lists — the gym's machine list on the Gyms tab and
  the "Add by Machine" sheet during a workout — a trailing **swipe action "Delete"** (no full-swipe:
  a confirmation always stands between the swipe and the deletion) and a **"Delete Machine…"**
  item in the context menu. One confirmation dialog for both: *"Delete <label>?"* — *"It disappears
  from this gym. Workouts you already logged with it keep it."*
- **Underneath it is still archival (D10, unchanged)**: `archived = true`; the machine leaves every
  picker (`Gym.activeMachines`), history reads snapshots and is untouched. An entry in the CURRENT
  workout that used the machine keeps its snapshot and stays on the workout screen.
- **Restore.** A gym whose machines include archived ones shows a **"Deleted machines (N)"** row
  under Add Machine → a list with a **Restore** button per machine (`EquipmentLifecycle.restore`).
  Restoring puts it back in the pickers as it was — same id, same model, same history.
- One shared component (`Features/Gyms/MachineDeletion.swift`) carries the swipe, the menu item
  and the dialog, so both screens cannot drift.

## Acceptance criteria

- Gyms tab: swipe → Delete → confirm → the row is gone; "Deleted machines (1)" appears; Restore
  brings it back. Cancel in the dialog changes nothing.
- Mid-workout: the same on the Add-by-Machine sheet; the list then says "No machines yet"; the
  Gyms tab agrees.
- `EquipmentLifecycle.restore` unit-tested beside `archive`; the full unit suite green; a new
  `MachineDeletionUITests` class green; `CoreLoopUITests` still green (it archives nothing but
  drives the same rows). Codex clear.

## Resolution (2026-09-10)

- **`Features/Gyms/MachineDeletion.swift`** — `machineDeleteActions(_:ask:)` (trailing swipe,
  no full swipe, "Delete") and `deleteMachineConfirmation(_:onDelete:)` — an **alert** with
  "Delete Machine" (destructive) and "Cancel": the first cut used `confirmationDialog`, and on
  iOS 26 the UI test's accessibility tree showed it rendered as a small centred sheet with the
  destructive action and NO Cancel at all; an alert always shows both. `DeletedMachinesView`:
  the gym's archived machines with a Restore button each.
- **`EquipmentLifecycle.restore(_:)`** and **`Gym.archivedMachines`** (Domain).
- **Gyms tab** (`GymsView`): machine rows carry `machineRow.<label>`, the swipe, and the context
  menu's "Delete Machine…" (was "Archive Machine"); one alert on the list; a
  "Deleted machines (N)" `NavigationLink` under Add Machine, only when N > 0.
- **Mid-workout** (`AddByMachineSheet`): the same swipe, menu item and alert on `machineOption.*`
  rows, archiving through `EquipmentLifecycle`.
- **Tests** — `EquipmentLifecycleTests.deletingIsArchivalAndRestoreBringsTheSameMachineBack`
  (archive hides, restore returns the SAME machine — id, model, live relationship — and the
  entry's snapshot never moves); `MachineDeletionUITests` (2): Gyms tab swipe → Cancel changes
  nothing → Delete → row gone → "Deleted machines (1)" → Restore → row back, list gone; and the
  mid-workout swipe → Delete → "No machines yet" → minimize → the Gyms tab shows the deleted list.

Verification: 698/698 unit; `MachineDeletionUITests` 2/2; `CoreLoopUITests` 9/9.

## Codex review 01 — response (2026-09-10)

`codex-review-01.md`: standards clear; one P3 and two coverage gaps; no user-facing defect.

- **P3, the menu item was not shared.** `DeleteMachineMenuItem` in `MachineDeletion.swift`, used by
  both context menus; the component now carries the swipe, the menu item and the alert, as the
  ticket said.
- **Coverage, the current-workout claim.** The mid-workout UI test now logs a set (80 × 8) on the
  machine first, deletes the machine from the Add-by-Machine sheet, asserts the entry is still on
  the workout screen with its numbers, finishes, and finds the exercise in History — then checks
  the Gyms tab shows the deleted list. (No minimize needed: finishing returns to the tabs.)
- **Coverage, the round trip.** The restore unit test sets `defaultUnit` and `defaultPresetID`
  before archiving and asserts both, the label, the model, the live relationship and the entry's
  `snapshotMachineID` / `snapshotEquipmentLabel` / `snapshotModelID` after restoring.
- The Gyms-tab test's Cancel is scoped to `app.alerts`.

Verification after round 1: 698/698 unit; `MachineDeletionUITests` 2/2 (the machine now sits on a
real catalog model, as the user's do — see the note); the FULL UI suite on `d35e725`: **46 tests,
0 failures**.

**Open question found on the way (NOT this ticket):** tapping a MODEL-LESS machine on the
Add-by-Machine sheet mid-workout did nothing in the Simulator — the sheet stayed on its list and
no exercise picker was pushed (accessibility tree captured in the test log, 2026-09-10). The
one-exercise-model path works (core loop). The user's machines are scanned, so all have models;
verify on the phone before chasing.
