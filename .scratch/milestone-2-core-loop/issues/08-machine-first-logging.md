# 08 — Machine-first logging & free-weight context

**What to build:** The equipment-aware speed interaction (D7): adding by machine. Picking a single-exercise machine auto-selects its exercise; picking a multi-exercise station (model linked to several exercises) prompts for which; free-weight logging attaches the equipment-type tag (barbell/dumbbell/cable/smith/bodyweight) persisted on the entry. Entry point: an "Add by machine" path in the active workout alongside the exercise-first path.

**Blocked by:** 07.

**Status:** ready-for-agent

- [ ] Single-exercise machine → entry created with exercise auto-filled, zero extra prompts
- [ ] Multi-exercise station → exercise chooser listing only that model's linked exercises
- [ ] Free-weight tag persists on the entry and is captured in the snapshot (history rendering of tags belongs to ticket 09)
- [ ] Model-less machines open the full exercise picker (per ticket 06) instead of auto-fill
- [ ] Exercise-first path still works: pick exercise → optionally pick machine (remembered per gym via memory)
