# 01 — BarbellMath: the bar catalog and the arithmetic

Status: resolved
Blocked by: —

Pure logic, `Foundation` only — no UI, no SwiftData. This is the file that owns the invariant in
`../spec.md`: **stored weight is the total, bar included**.

## Files

- `WorkoutTracker/Domain/BarbellMath.swift`
- `WorkoutTrackerTests/BarbellMathTests.swift`

## What to build

- `struct BarPreset: Identifiable, Equatable` — `id: String` (stable, storage-safe), `name`,
  `value: Double`, `unit: WeightUnit`. `BarbellMath.presets` is the fixed list from `../spec.md`
  (Olympic, women's, technique — each in kg and lb as **separate** entries). Maker-dependent EZ
  curl, trap/hex and Smith weights use Custom rather than a guessed preset (D4).
- `BarbellMath.total(barWeight:platesPerSide:) -> Double` — `bar + 2 × perSide`.
- `BarbellMath.platesPerSide(total:barWeight:) -> Double?` — `(total − bar) / 2`, and **nil when
  the total is below the bar**: a negative plate stack is not a thing, and returning one would
  render as `-5` in the input field and log a lighter set than the user performed.
- `BarbellMath.isValidBarWeight(_:)` — finite, `> 0`. A zero-weight bar is not a bar; it is total
  entry, which is what nil means.
- A display helper for the row's caption (`= 135 lb`) and for history's breakdown
  (`45 + 45 × 2 = 135 lb`), formatted through `WeightMath.displayNumber` so it obeys D25.

## Acceptance criteria

- [ ] `total(barWeight: 45, platesPerSide: 45) == 135`; `total(barWeight: 20, platesPerSide: 0)
      == 20` — an empty bar is a legal, loggable set.
- [ ] `platesPerSide(total: 135, barWeight: 45) == 45`, and `platesPerSide(total: 20, barWeight:
      45) == nil`.
- [ ] Round trip: for every preset bar and a spread of plate values including fractional ones
      (1.25, 2.5, 62.5), `platesPerSide(total: total(bar, p), barWeight: bar) == p` exactly.
- [ ] `isValidBarWeight` rejects `0`, negatives, NaN and infinity.
- [ ] Preset ids are stable strings and unique; kg and lb variants of the same bar are distinct
      entries with distinct ids (a 20 kg bar is not a 45 lb bar).
- [ ] No preset weight is a conversion of another — the lb column is the lb-market bar, not
      `kg × 2.2046`. A test asserts the 20 kg and 45 lb bars differ by more than rounding.
- [ ] Display helper renders `45 + 45 × 2 = 135 lb` and trims trailing zeros (`2.5`, not `2.50`).
- [x] The file imports `Foundation` only.

## Resolution (2026-08-22)

`WorkoutTracker/Domain/BarbellMath.swift` + `WorkoutTrackerTests/BarbellMathTests.swift`
(12 tests). The original review found that warning under a selectable EZ/trap guess did not satisfy
D4. The fixed list now contains only standard weights; maker-dependent bars use Custom.

The catalog is a plain `let` array, not a `@Model`. A bar is not user data — what is stored on
  a set is its *weight*, so a user who logs on a bar the list does not have types the number once
  and history carries it from then on (`Custom…`).
