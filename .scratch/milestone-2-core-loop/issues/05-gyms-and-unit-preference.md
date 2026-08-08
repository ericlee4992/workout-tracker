# 05 — Gym creation & app unit preference

**What to build:** "Add Gym…" creates a persisted Gym (name required; city and default unit optional). A persisted, editable app-level unit preference exists (simple settings UI is fine). The unit-precedence chain machine → gym → app preference becomes a pure Domain function, including the no-gym and no-machine cases.

**Blocked by:** 02.

**Status:** resolved

- [x] Created gyms survive relaunch and appear in the Gyms tab and the workout gym picker
- [x] Gym default unit is optional — a gym without one falls through to the app preference
- [x] App unit preference persists and is editable; first-launch default derives from the locale measurement system (US → lb, metric → kg)
- [x] Precedence unit tests: machine set → machine wins; machine nil, gym set → gym; both nil → app preference; no gym at all → app preference

---

**Comment (2026-08-08, agent):** Implemented. "Add Gym…" in the Gyms tab opens a form sheet
(name required; city and default unit optional — unit picker defaults to "App preference" = nil
fall-through) and persists via SwiftData; GymsView/GymDetailView now render `@Query`-backed real
gyms (archived excluded). Machine lists stay prototype-scoped until ticket 06 (detail view shows
the still-empty persisted relationship with a disabled Add Machine button). App unit preference
lives on `AppPreferences.unitPreference`, bootstrapped on first launch from the locale measurement
system via `AppPreferences.ensureUnitPreference(in:measurementSystem:)` (injectable for tests) and
editable from a Settings section in the Gyms tab. Precedence chain is the pure
`UnitPrecedence.defaultUnit` in `Domain/UnitPrecedence.swift` (machine → gym → app preference,
nil-safe at every level, plus a model-graph overload for the no-machine/no-gym cases). Persisted
gyms also appear and are selectable in the Start-workout gym picker (sample gyms remain until
ticket 07 rewires the flow). Tests: `WorkoutTrackerTests/UnitPreferenceTests.swift` — 9 new tests
(precedence incl. all four required cases, first-launch derivation with injected measurement
system, temp-store gym relaunch round-trip). Full suite: 31 tests green.
