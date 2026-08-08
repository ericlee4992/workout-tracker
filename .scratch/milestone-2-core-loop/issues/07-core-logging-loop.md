# 07 — Core logging loop (empty workouts only)

**What to build:** Start Empty Workout creates a persisted Workout (startedAt set, finishedAt nil) at the current gym or **no gym**; the active-workout screen operates on real records. Every accepted edit persists via explicit `ModelContext.save()` at defined boundaries: set completion toggle, set add/delete, entry add/delete, equipment choice, unit toggle, and text-field commit (end-editing); in-progress keystrokes are not durability-guaranteed. Snapshot UUIDs + display strings are captured on the entry when its first set completes (D19/D23), and the entry's equipment freezes from then on — the UI offers "switch machine → new entry" instead. Completing a set stamps `completedAt` and upserts GymExerciseMemory. Finish sets finishedAt; Cancel confirms then deletes the graph. Template starts are ticket 15 — explicitly out of scope here.

**Blocked by:** 03, 06.

**Status:** ready-for-agent

- [ ] Recovery test (disk-backed container, torn down and reopened, per ticket 02's pattern) covering every mutation: add/delete/reorder entry, add/delete set, weight/reps commit, unit toggle, set-type cycle, completion, equipment choice, notes
- [ ] Exactly-one-active-workout invariant: relaunch resumes the newest active workout and auto-finishes older strays (stamping finishedAt); "Start Workout" while one is active offers Resume or Finish-and-start-new
- [ ] Finish cleanup: uncompleted draft set rows and entries with zero completed sets are deleted; only completed data reaches history
- [ ] Switch-machine draft handling per D19: uncompleted rows move to the new entry, completed sets stay; freeze survives un-completing the first set
- [ ] Equipment freeze: after one completed set, changing equipment creates a new entry; the old entry and its snapshot are untouched — covered by a test
- [ ] Set units default per precedence chain (ticket 05 function) and persist per set as entered
- [ ] GymExerciseMemory upsert test: duplicate rows in store → latest updatedAt wins, no new duplicates created
- [ ] Cancel deletes the workout and all children; Finish moves it to history
