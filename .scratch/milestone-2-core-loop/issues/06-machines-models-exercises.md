# 06 — Machine, user-model & user-exercise creation

**What to build:** "Add Machine…" creates a persisted MachineInstance at a gym: label (required), catalog model (optional, searchable picker), default unit (optional). When the catalog lacks the model, the user adds one inline (user ID space, distinguishable from seeded, linked to ≥1 exercise). Users can also create custom exercises (name, load type, equipment tags) from the Exercises tab.

**Blocked by:** 04, 05.

**Status:** ready-for-agent

- [ ] Created machines survive relaunch; machine picker lists the current gym's non-archived machines
- [ ] Inline user-model creation: manufacturer + model + linked exercise(s); flagged user-created; only user-created models/exercises are renameable (seeded rows read-only, D24)
- [ ] Model-less machines are allowed; in machine-first logging they open the full exercise picker instead of auto-fill
- [ ] User-created exercises appear in pickers alongside seeded ones and support all four load types
- [ ] Catalog reconciliation rerun (ticket 04 logic) leaves user models/exercises untouched — covered by a test
