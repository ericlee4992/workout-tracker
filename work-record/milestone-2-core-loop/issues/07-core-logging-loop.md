# 07 — Core logging loop (empty workouts only)

**What to build:** Start Empty Workout creates a persisted Workout (startedAt set, finishedAt nil) at the current gym or **no gym**; the active-workout screen operates on real records. Every accepted edit persists via explicit `ModelContext.save()` at defined boundaries: set completion toggle, set add/delete, entry add/delete, equipment choice, unit toggle, and text-field commit (end-editing); in-progress keystrokes are not durability-guaranteed. Snapshot UUIDs + display strings are captured on the entry when its first set completes (D19/D23), and the entry's equipment freezes from then on — the UI offers "switch machine → new entry" instead. Completing a set stamps `completedAt` and upserts GymExerciseMemory. Finish sets finishedAt; Cancel confirms then deletes the graph. Template starts are ticket 15 — explicitly out of scope here.

**Blocked by:** 03, 06.

**Status:** resolved

- [x] Recovery test (disk-backed container, torn down and reopened, per ticket 02's pattern) covering every mutation: add/delete/reorder entry, add/delete set, weight/reps commit, unit toggle, set-type cycle, completion, equipment choice, notes
- [x] Exactly-one-active-workout invariant: relaunch resumes the newest active workout and auto-finishes older strays (stamping finishedAt); "Start Workout" while one is active offers Resume or Finish-and-start-new
- [x] Finish cleanup: uncompleted draft set rows and entries with zero completed sets are deleted; only completed data reaches history
- [x] Switch-machine draft handling per D19: uncompleted rows move to the new entry, completed sets stay; freeze survives un-completing the first set
- [x] Equipment freeze: after one completed set, changing equipment creates a new entry; the old entry and its snapshot are untouched — covered by a test
- [x] Set units default per precedence chain (ticket 05 function) and persist per set as entered
- [x] GymExerciseMemory upsert test: duplicate rows in store → latest updatedAt wins, no new duplicates created
- [x] Cancel deletes the workout and all children; Finish moves it to history

---

**Comment (2026-08-08, agent):** Implemented. All UI-behavior logic lives in a UI-free service,
`WorkoutTracker/Domain/WorkoutSession.swift`, wrapping a ModelContext: every mutation
(start/finish/cancel, entry add/delete/move, equipment choice, set add/delete, type cycle,
weight/reps commit, unit toggle, completion toggle, notes commit) ends in an explicit
`context.save()` at the SPEC durability boundary — views hold in-progress keystrokes in local
state and commit on end-editing (FocusState change / completion tap). Snapshot capture (D23:
UUIDs + loadType + freeWeightTag + display strings) happens on the entry's first-ever set
completion; the freeze marker is a new `ExerciseEntry.snapshotCapturedAt: Date?` (additive,
CloudKit-safe, noted in ticket 02) which is never reset, so the freeze survives un-completing
(D19). `chooseEquipment` edits draft entries in place and, once frozen, splits: new entry ordered
right after the old one, uncompleted draft rows moved with values intact, completed sets and the
old snapshot untouched. Completion also upserts GymExerciseMemory (canonical row = latest
updatedAt then id; updated in place, never duplicated; skipped for no-gym workouts).
`resumableWorkout()` implements newest-active-wins recovery with auto-finish (+ finish cleanup)
of strays; `startWorkout` finishes lingering actives so the invariant holds at the service
boundary, and StartWorkoutView offers Resume / Finish-and-start-new when one is active. UI
rewired onto SwiftData keeping the milestone-1 visual design: RootView (recovery + fullScreenCover
on the real Workout), StartWorkoutView (real gyms + No-gym, unit footer via precedence),
ActiveWorkoutView, ExerciseEntryCard/SetRowView (adds delete affordances via menus; PREVIOUS
column is an em-dash placeholder until ticket 11), MachinePickerSheet (real non-archived machines
at the workout's gym, reuses ticket 06's AddMachineSheet, freeze notice), ExercisePickerSheet
(real catalog), PreviousPerformanceSheet (layer scaffold with empty states until ticket 11).
Rest timer stays UI-state-only with global-default durations (ticket 14 persists it). History and
templates remain on SampleStore (tickets 09/15); the PROTO_SCREEN=active deep link was removed
with the prototype screen. Tests: `WorkoutTrackerTests/WorkoutSessionTests.swift` — 12 new,
disk-backed reopen pattern (structure + field/completion/equipment/notes recovery, newest-active
recovery + stray auto-finish persisted across a second reopen, start-while-active invariant,
freeze split + draft moves, freeze survives un-completing, draft in-place equipment edit, memory
upsert dedupe + insert/no-gym, unit precedence + as-entered persistence, finish cleanup, cancel
cascade). Full suite: 47 tests green on WT-iPhone; plain `xcodebuild build` green.
