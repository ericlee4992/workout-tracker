# 10 — Equipment lifecycle & model correction

**What to build:** Rename, archive, and model-correction flows with historical honesty. Renaming a gym/machine/model changes future displays only (history reads snapshots). Deleting archives: hidden from pickers, history intact. Correcting a machine's model triggers the locked prompt (D10): "apply to past workouts too, or future only?" — future-only leaves old snapshots untouched; apply-to-past rewrites the snapshot model UUID+strings on that machine's past entries.

**Blocked by:** 09.

**Status:** ready-for-agent

- [ ] Tests, each asserting both the history display AND the snapshot IDs: gym rename, machine rename, model rename, machine archive, gym archive
- [ ] Future-only correction: old entries keep the old model UUID in snapshots (and thus stay in the old model's history layer)
- [ ] Apply-to-past correction: chosen scope's snapshots rewritten; entries on other machines of the old model untouched
- [ ] Archived machines/gyms excluded from pickers and from GymExerciseMemory resolution
- [ ] Rename applies only to user-created models/exercises; seeded rows are read-only (D24)
