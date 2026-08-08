# 05 — Gym creation & app unit preference

**What to build:** "Add Gym…" creates a persisted Gym (name required; city and default unit optional). A persisted, editable app-level unit preference exists (simple settings UI is fine). The unit-precedence chain machine → gym → app preference becomes a pure Domain function, including the no-gym and no-machine cases.

**Blocked by:** 02.

**Status:** ready-for-agent

- [ ] Created gyms survive relaunch and appear in the Gyms tab and the workout gym picker
- [ ] Gym default unit is optional — a gym without one falls through to the app preference
- [ ] App unit preference persists and is editable; first-launch default derives from the locale measurement system (US → lb, metric → kg)
- [ ] Precedence unit tests: machine set → machine wins; machine nil, gym set → gym; both nil → app preference; no gym at all → app preference
