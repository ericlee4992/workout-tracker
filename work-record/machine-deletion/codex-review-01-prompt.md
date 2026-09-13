Round 1 (T6) of machine-deletion ticket 01 — delete a machine from a gym, on the Gyms tab and
mid-workout. Ticket: work-record/machine-deletion/issues/01-delete-machines.md (what to build,
acceptance criteria, resolution). Boundary: cc4aaa5..HEAD on branch delete-machines (one commit).

Files: WorkoutTracker/Features/Gyms/MachineDeletion.swift (new), Domain/EquipmentLifecycle.swift
(restore, archivedMachines), Features/Gyms/GymsView.swift, Features/ActiveWorkout/AddByMachineSheet.swift,
WorkoutTrackerTests/EquipmentLifecycleTests.swift, WorkoutTrackerUITests/MachineDeletionUITests.swift.

Scope, by what could hurt the user:
1. D10 — is "Delete" archival everywhere, never a SwiftData delete? Can any path drop a
   MachineInstance row, its entries' relationship, or a snapshot? Does an entry logged THIS
   workout on the deleted machine stay on the workout screen and in history?
2. Restore — does it bring back exactly the same machine (id, model, label, defaultPresetID,
   defaultUnit)? Can a restored machine collide with anything (a machine added since with the
   same label)? Is `Gym.archivedMachines` shown for an archived gym anywhere it should not be?
3. The alert — one binding shared by swipe and context menu; can a stale `pending` fire on the
   wrong machine (row reuse, a second swipe while the alert is up, the sheet dismissed mid-alert)?
   `allowsFullSwipe: false` — does the swipe really never delete without the alert?
4. Mid-workout: the `AddByMachineSheet` archives through a fresh `EquipmentLifecycle(context:)`
   — same context as `WorkoutSession`? Does the list refresh (it reads `gym?.activeMachines`)?
   Anything that could leave the sheet on a deleted machine (the `chooser` navigation)?
5. Tests: do they pin the claims (Cancel changes nothing; the same machine returns; history
   untouched)? The UI tests dismiss the alert by tapping "Cancel" — any brittleness?

Do NOT run xcodebuild or simctl (the simulator is running the full UI suite); review by
inspection. Report by severity with file:line, or say "clear" in one paragraph. Do not modify
source files. Write to work-record/machine-deletion/codex-review-01.md
