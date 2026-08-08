# 09 — History rendering from snapshots

**What to build:** History and workout detail read persisted finished workouts, rendering equipment from **snapshot display strings** (never live relationships). Sets show as entered with W/F markers. The workout summary's unit badge derives from actual sets: kg, lb, or Mixed. The whole-view convert toggle renders every weight in the chosen unit with converted values ≈-marked, using ticket 03's formatting.

**Blocked by:** 07.

**Status:** ready-for-agent

- [ ] History lists only finished workouts (finishedAt != nil), grouped by month, newest first; only completed sets render (Finish already deleted drafts)
- [ ] Free-weight entries render their snapshot tag (e.g. "Barbell") as the equipment label
- [ ] Detail shows snapshot equipment labels; a unit test proves rendering never touches the live MachineInstance/EquipmentModel relationship
- [ ] Unit badge test: all-kg workout → kg; all-lb → lb; mixed → Mixed
- [ ] Convert toggle: original units by default; toggled view marks conversions with ≈; storage unchanged
