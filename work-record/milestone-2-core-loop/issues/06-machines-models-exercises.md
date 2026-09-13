# 06 — Machine, user-model & user-exercise creation

**What to build:** "Add Machine…" creates a persisted MachineInstance at a gym: label (required), catalog model (optional, searchable picker), default unit (optional). When the catalog lacks the model, the user adds one inline (user ID space, distinguishable from seeded, linked to ≥1 exercise). Users can also create custom exercises (name, load type, equipment tags) from the Exercises tab.

**Blocked by:** 04, 05.

**Status:** resolved

- [x] Created machines survive relaunch; machine picker lists the current gym's non-archived machines
- [x] Inline user-model creation: manufacturer + model + linked exercise(s); flagged user-created; only user-created models/exercises are renameable (seeded rows read-only, D24)
- [x] Model-less machines are allowed; in machine-first logging they open the full exercise picker instead of auto-fill
- [x] User-created exercises appear in pickers alongside seeded ones and support all four load types
- [x] Catalog reconciliation rerun (ticket 04 logic) leaves user models/exercises untouched — covered by a test

---

**Comment (2026-08-08, agent):** Implemented. "Add Machine…" in GymDetailView is live: label
required, searchable catalog-model picker (seeded + user models, "None" option), default unit
optional (nil = gym default fall-through); persists a `MachineInstance` linked to the gym via
SwiftData, and the detail list already shows only the gym's non-archived machines. The model
picker offers inline "New Model…" creation — manufacturer + model + ≥1 linked exercise (link
order preserved), inserted with a fresh user UUID and `isSeeded == false`, marked "Custom" in the
picker, and auto-selected for the machine being added. ExercisesView now queries the whole
catalog (seeded + user side by side, user rows marked "Custom"), adds "Add Exercise…" (name, all
four load types, equipment tags → `isSeeded == false`), and gates rename (context menu + alert)
to user-created rows only — seeded rows expose no edit affordance (D24). Model-less machines are
allowed (model optional end-to-end; detail row shows "No model", footer documents the
full-exercise-picker behavior for machine-first logging). Caveat on the first checkbox: the
*active-workout* machine picker intentionally stays on SampleStore until ticket 07 rewires the
logging flow — this ticket satisfies it by making real per-gym machines persist and be available
for that rewiring (GymDetailView already lists them filtered to non-archived). Tests:
`WorkoutTrackerTests/MachineCreationTests.swift` — 4 new (on-disk relaunch round-trip incl.
model-less machine and gym/model links; user exercises across all four load types; user model
with cross-ID-space exercise links; reconciliation rerun + version upgrade leaving user
models/exercises and all machines untouched), extending SeedingTests'
`userCreatedRowsUntouched`. Full suite: 35 tests green.
