# 03 — Unit conversion domain core

**What to build:** The pure `Domain/` contract for weights (D25): conversion with exactly 1 lb = 0.45359237 kg, atomic `normalizedKg` recomputation on any value/unit edit, rejection of nonfinite/negative input, full-precision storage with display-time rounding, and the display-unit formatting used by the convert toggle (≈-marked conversions).

**Blocked by:** 01.

**Status:** resolved

- [x] Pure functions, no UI or SwiftData imports
- [x] Tests: kg identity (normalizedKg == value), lb conversion within 1e-9 of exact constant, edit value → recompute, toggle unit → recompute, NaN/∞/negative rejected, display rounding never mutates storage
- [x] Round-trip honesty test: 60 kg → display lb → original storage still exactly 60 kg
- [x] Formatting spec (D25) with exact expectations: `60` (not 60.0), `62.5`, `61.23` (2-decimal cap, half-up, trailing zeros trimmed); conversions marked: 60 kg shown in lb = `≈132.28 lb`; storage locale-independent, display uses locale decimal separator

**Resolution (2026-08-08):** Implemented in `WorkoutTracker/Domain/WeightMath.swift` (Foundation-only): `WeightMath` (exact 0.45359237 constant, `normalizedKg`, `convert`, validation, D25 display/storage formatting) and `StoredWeight` (validated value/unit pair whose every edit helper atomically recomputes `normalizedKg`; unit edits reinterpret the as-entered value, never silently convert). TDD: 11 tests in `WorkoutTrackerTests/WeightMathTests.swift` cover every checkbox incl. the verbatim formatting examples and the 60 kg round-trip honesty test — full suite `** TEST SUCCEEDED **`.
