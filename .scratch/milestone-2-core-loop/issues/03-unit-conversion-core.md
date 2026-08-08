# 03 — Unit conversion domain core

**What to build:** The pure `Domain/` contract for weights (D25): conversion with exactly 1 lb = 0.45359237 kg, atomic `normalizedKg` recomputation on any value/unit edit, rejection of nonfinite/negative input, full-precision storage with display-time rounding, and the display-unit formatting used by the convert toggle (≈-marked conversions).

**Blocked by:** 01.

**Status:** ready-for-agent

- [ ] Pure functions, no UI or SwiftData imports
- [ ] Tests: kg identity (normalizedKg == value), lb conversion within 1e-9 of exact constant, edit value → recompute, toggle unit → recompute, NaN/∞/negative rejected, display rounding never mutates storage
- [ ] Round-trip honesty test: 60 kg → display lb → original storage still exactly 60 kg
- [ ] Formatting spec (D25) with exact expectations: `60` (not 60.0), `62.5`, `61.23` (2-decimal cap, half-up, trailing zeros trimmed); conversions marked: 60 kg shown in lb = `≈132.28 lb`; storage locale-independent, display uses locale decimal separator
