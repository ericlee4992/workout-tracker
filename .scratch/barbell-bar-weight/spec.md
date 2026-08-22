# Barbell bar weight — enter the plates, log the total

Written 2026-08-22. Requested by the user: *"When doing barbell exercises, the user should be
able to either choose a barbell (then the app auto-calculates the weight — e.g. if user selects
regular 45 lb barbell, the user only has to enter the plate weights and the set auto-calculates
total weight), or just manually input the total weight."*

This brings the first half of **milestone 6** (plate/stack calculator, D16) forward. It is the
*bar* half only: which bar you are on and what you hung on it. It does **not** compute a plate
breakdown ("2×45 + 1×10 a side") from a target weight — that is the other half and stays in
milestone 6.

## The problem

A barbell set is the one place where the number on the bar is not a number you can read
anywhere. You load 45 lb a side onto a 45 lb bar and the set is 135 lb, and today the app makes
you do that arithmetic mid-workout, every set, and type the answer. Get it wrong and the error
lands in the record tables, where it is indistinguishable from a real lift.

## Shape

**Bar mode** is an *input mode* on one exercise entry, offered wherever the entry is barbell
work — the `barbell`/`smith` free-weight tags (D7), **or** a machine instance whose catalog model
is a rack or Smith (`EquipmentCategory.rackOrSmith`). The second matters: a Smith carriage's
weight is not written on it, and a squat rack picked from the catalog is a barbell station by any
other name. Off by default; the weight field means the total, exactly as it does today.

Turned on by picking a bar, the weight field means **plates per side** and the row displays the
total it will log:

```
BAR  [ 45 lb ▾ ]

SET  PREVIOUS      PER SIDE      REPS
 1   135 lb × 5    [  45  ] lb   [ 5 ]   ✓
                   = 135 lb
```

Per side, not total-plates, because that is what a lifter is holding when they walk to the rack:
"a plate a side". The arithmetic the app removes is the doubling *and* the bar.

## The invariant everything else depends on

**`SetRecord.weightValue` is always the total lifted, bar included.** Bar mode changes what the
user *types*, never what is stored as the weight. `RecordsMath`, volume (D21), e1RM (D17/D20),
previous-performance labels, the record tables and the export's `weight`/`weightKg` all read
`weightValue`/`normalizedKg` and are not touched by this feature.

State the consequence where it can be broken: if the stored weight ever became plates-only, every
past barbell PR would silently drop by the weight of a bar, and nothing in the app would report an
error — history would simply become wrong. Any code that writes `weightValue` in bar mode goes
through `BarbellMath.total`.

`barWeightValue` is **provenance**, never a second source of truth. It answers "which bar was
this?", and the plates-per-side the row shows is *derived* from it: `(total − bar) / 2`.

## Units

A bar is a `(value, unit)` pair, like every other weight in this app (D9/D25). A 45 lb bar is not
a 20 kg bar and the app never pretends otherwise.

- Picking a bar **sets the row's unit to the bar's unit**. No conversion happens, so nothing is
  ever marked ≈.
- While a row is in bar mode the kg/lb toggle is **disabled** — reinterpreting "45" as 45 kg
  because the user tapped a badge would silently change a 20 kg bar into a 45 kg one. The picker
  lists bars in both units; switching unit means picking a different bar, which is the truth of
  what happens in a gym.
- `barWeightValue` is stored in the row's `weightUnit`, so bar + 2 × plates is exact arithmetic
  in one unit with no rounding step.

## Which bars

Seeded as a fixed list in code (not a `@Model`, not user data), plus **Custom…** for anything
else. D4's rule applies — a made-up number is worse than an absent one — so the list is limited
to bars whose weight is a published standard, and everything variable (Smith carriages run
anywhere from 6 to 32 lb depending on counterweighting) is entered by the user as a custom value
and remembered through the normal history path.

| Bar | kg | lb |
|---|---|---|
| Olympic barbell | 20 kg | 45 lb |
| Women's Olympic barbell | 15 kg | 35 lb |
| Technique / training bar | 10 kg | 15 lb |
| EZ curl bar | 10 kg | 25 lb |
| Trap / hex bar | 25 kg | 55 lb |
| Custom… | user value | user value |

The two columns are **separate bars**, not conversions of each other: 20 kg is 44.09 lb, and the
45 lb bar sold in US gyms is a different object. Listing them side by side and letting the user
pick the one in their hands is the honest version.

## Memory between sessions

There is no new preference and no per-exercise bar setting. The bar rides along the paths that
already carry the numbers:

- **Within a session** — `WorkoutSession.addSet`'s carry-forward (B1) copies the bar with the
  weight and reps, so sets 2–5 stay in bar mode.
- **Across sessions** — ticket 11's prefill copies the bar from the matched historical set. That
  match is already keyed by exercise + equipment + preset (D11/D36), so the bar remembered is the
  one used *for this movement on this equipment*, and a different gym's history never supplies it.

Consequence: bar mode is chosen once per movement, ever, and history maintains it. A user who
never touches a barbell never sees any of this.

## What this changes elsewhere

- **Schema** — one optional attribute on `SetRecord`. Lightweight migration, verified against
  `WorkoutTrackerTests/Fixtures/LegacyStore.store` before anything is installed on the phone.
- **Export** — `barWeight` and `barWeightKg` appended to the CSV (29 → 31 columns) and added to
  each set in the JSON; `schemaVersion` 2 → 3. D29's rule (as entered *and* normalized) applies to
  the bar for the same reason it applies to the weight.
- **History** — a completed bar-mode set renders its breakdown (`45 + 45×2 = 135 lb`) where there
  is room for it; the plain total everywhere else.

## Decisions this proposes

**D39 — A bar is an input aid whose result is the total.** Bar mode changes what the user types
(plates per side) and what the app displays; the stored weight is always the total lifted. The bar
weight is stored alongside as provenance so history can show the breakdown and the next session
can prefill plates rather than a total. Records, volume, e1RM and the export's weight columns are
unchanged. *Why:* two barbell sets of 135 lb are the same lift whether they were typed as a total
or computed from a bar, so they must land in the same record table; and a stored weight that
sometimes excludes the bar would corrupt every barbell record without producing a single error.

**D40 — A bar carries its own unit, and picking one sets the row's unit.** Bars are listed in both
kg and lb as distinct objects (a 20 kg bar is not a 45 lb bar); the kg/lb toggle is disabled in
bar mode. *Why:* D9/D25 forbid silent conversion, and the alternative — reinterpreting the bar's
number in the other unit — turns a 20 kg bar into a 45 kg one on a stray tap.

## Not in scope

- Computing which plates to load for a target weight (milestone 6's other half).
- Per-side asymmetric loading, collar weights, chains/bands.
- Selectorized stack increments (the "stack calculator" half of milestone 6).
- Making the bar part of the D23 snapshot or of the record grouping key: the total is the whole
  truth about the load, so a bar change must **not** split records the way an equipment or preset
  change does (D19/D36). Changing the bar mid-entry is a re-entry of numbers, not a new context.
