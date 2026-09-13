# 04 — Start & log a real workout (core loop)

**What to build:** Starting a workout (empty or from template) creates a persisted Workout at the current gym; every set edit, completion toggle, machine choice, and unit change auto-persists immediately. Unit defaults follow machine → gym → app preference. Finishing stores the workout in history. The interruption guarantee from SPEC holds: force-quit mid-workout, relaunch, and the active workout resumes exactly as it was.

**Blocked by:** 01, 02, 03.

**Status:** ready-for-agent

- [ ] Sets persist as entered: value + unit + normalizedKg; per-set unit toggle works against real records
- [ ] Set types (warmup/working/failure) and completion state persist
- [ ] Machine selection persists on the entry and updates GymExerciseMemory for that (gym, exercise)
- [ ] Kill the app mid-workout → relaunch → active workout resumes with identical state
- [ ] Finish moves the workout to history; Cancel discards it after confirmation
