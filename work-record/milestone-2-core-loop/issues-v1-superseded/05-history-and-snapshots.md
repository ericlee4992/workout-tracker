# 05 — History & log-time equipment snapshots

**What to build:** History and workout detail read persisted workouts. Each entry displays its log-time context snapshot (machine label, manufacturer + model, gym) rather than live references, so renaming or archiving a machine after the fact never changes what past workouts show. Deleting a gym or machine archives it; archived equipment disappears from pickers but history keeps rendering.

**Blocked by:** 04.

**Status:** ready-for-agent

- [ ] History groups persisted workouts by month with gym + unit badge + stats, as in the prototype
- [ ] Workout detail shows sets as entered (unit per set, W/F markers) and snapshot equipment labels
- [ ] Rename a machine → old workouts still show the old label; new workouts show the new one
- [ ] Delete a machine/gym with history → archived, not destroyed; pickers hide it, history unaffected
