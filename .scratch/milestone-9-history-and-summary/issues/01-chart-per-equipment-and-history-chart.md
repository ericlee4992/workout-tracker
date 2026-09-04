# 01 — Chart per equipment tag, and a chart button in History

Status: resolved — awaiting Codex review
Covers user asks **3** and the bug half of **4**.

## What to build

**A. The chart's variation must include the free-weight tag.** `ProgressVariationKey` becomes
`(loadType, freeWeightTag, presetID)`. Records already group this way (`RecordGroupKey.freeWeight`,
D7/D23); the chart was the one surface that pooled barbell and dumbbell into a single line.

- A machined set carries a nil tag (`WorkoutSession.chooseEquipment` clears it), so machine history
  stays one group per exercise exactly as before. This ticket does not put the MACHINE on the chart
  axis — that has never been there and is not asked for.
- The picker names the variation with the tag when it has one: "Dumbbell", "Barbell · Wide grip".
  Snapshot values only (D23).
- `defaultVariation`'s tie-break (prefer no preset) extends naturally; document the order.

**B. A chart button per exercise in `WorkoutDetailView`.** In each entry's section header, next
to the load-type badge. It opens `ExerciseProgressView` **on the variation that session used** —
snapshot load type, tag and preset — not on the most-trained one. That needs an optional initial
variation on the chart view.

## Acceptance criteria

- `ChartPresetScopingTests` gains tests proving: a dumbbell set never appears in the barbell line;
  nil tag is its own group, not a wildcard; two tags with the same preset are two variations.
- All existing chart tests updated to the new key, none weakened.
- `ChartFixture` seeds at least one dumbbell-tagged session so the picker shows a tag-named
  variation; the existing tooltip test is unaffected (plain series stays the default).
- UI test: from a History session, tap the chart button and assert the chart opens on that
  session's variation (the picker label names it).
- Full unit suite + the chart and history UI tests green; screenshot attached.

## Notes

Change the `series(for:loadType:presetID:)` signature to take the key rather than adding a
defaulted parameter. A default `freeWeightTag: nil` is exactly how the D36 pooling happened: a
caller silently getting a group it did not ask for.


## Resolution (2026-09-03)

**A.** `ProgressVariationKey` is now `(loadType, freeWeightTag, presetID)`, every field required.
`ProgressSeriesMath.series` takes the key (`series(for:variation:)`) — the old
`loadType:presetID:` signature is gone rather than defaulted, per the note above. `variations`
and `defaultVariation` carry the tag; the tie-break is now fully ordered (plain first, then tag
name, then preset id) so the chart opens on the same variation every launch instead of dictionary
order. The picker names a variation "Dumbbell", "Barbell · Wide grip", or "No variation", from
snapshot values.

**B.** `WorkoutDetailView` has a chart button in each exercise header (`historyEntryChart`) that
presents `ExerciseProgressView` with a new optional `initialVariation`, built from the entry's
snapshot type, tag and preset. The sheet hangs off the List, not the Section.

**Tests.** 4 new in `ChartPresetScopingTests` (dumbbell never in the barbell line; nil tag is its
own group; one preset under two tags is two variations; tie-break is stable). All 19 existing
chart call sites updated mechanically — none weakened, and the one mis-rewrite the compiler caught
was fixed by hand. `ChartFixture` seeds two dumbbell sessions. New UI test
`testHistoryOpensTheChartOnThatSessionsVariation` opens the 4th History row (the dumbbell day) and
asserts the picker says Dumbbell.

**572 unit green; chart (3) + history-editing (2) UI tests green.** Screenshot:
`history-chart-dumbbell` attachment on the chart test — chart opens on "Dumbbell · 2 days".

**Not done, deliberately:** the machine is still not a chart axis (two machines for one exercise
chart together, as records' exercise-wide group does). Not asked for; noted so it is not
rediscovered as a bug.


## Codex review 01 — response (2026-09-03)

`codex-review-01.md`: verdict "do not merge yet", 2 high, 2 medium. All four acted on.

- **High — nil tag pooled machined sets with unrecorded-equipment sets.** Correct, and the
  "machined" test row never had a `machineID`, so it proved nothing. Fixed by making equipment an
  explicit axis: `ProgressEquipment` = `.machine(UUID)` / `.freeWeight(tag)` / `.unrecorded`,
  built from the snapshot's `(machineID, freeWeightTag)` and mirroring `RecordGroupKey`. This also
  resolves the medium "hybrid group matching none of RecordsMath": the chart now keys on the EXACT
  machine, as layer one of prefill and `.machine` records do, so Machine A and Machine B are two
  lines (D1/D8). New tests: machined vs unrecorded are different groups; two machines are two
  variations. **The ticket's original claim — "records already group this way, the chart was the
  one surface pooling" — was wrong as written**: records group by exact machine / model / tag /
  exercise-wide, and my first key matched none of them. Corrected here rather than rewritten
  above, so the error stays visible.
- **High — History could dead-end.** The picker rendered only under a drawn series. Now it sits
  above the state switch whenever more than one variation exists, and the variation on screen is
  always IN the list — a warmup-only variation shows as "Barbell · nothing eligible" with the empty
  state naming it ("Nothing to chart here … Pick another variation above"). Fixture gained a
  warmup-only barbell session; `testHistoryOpensASparseVariationWithAWayOut` opens it from History
  and asserts both the empty state and the picker, on Barbell.
- **Medium — ranking duplicated in the view.** `ProgressSeriesMath.rankedVariations(in:)` is the
  one comparator; `defaultVariation` is its first element and the view lists it verbatim.
  `rankedVariationsIsTotalAndStable` pins the order.
- Naming learned the hard way: prefixing "No equipment recorded ·" onto every preset row buried the
  grip names, so unrecorded equipment is named only when no preset names the row.

573 unit green; chart (4) + history-editing (2) UI green. Screenshot `history-chart-sparse`.


## Codex review 01b — response (2026-09-03)

`codex-review-01b.md`: both round-1 highs confirmed closed; 3 mediums (two are one defect).

- **Rank omitted `loadType`** — so "fully ordered" was false and the test named "total and
  stable" could not show it. `loadType.rawValue` is now in the tuple, after preset presence and
  before equipment; `rankedVariationsSeparatesLoadTypesDeterministically` pins a same-days /
  same-equipment / same-preset pair under two load types and checks the order is identical when
  the input is reversed.
- **Two rows could render the same label.** Naming is no longer a view rule.
  `ProgressSeriesMath.labels(for:)` takes each variation's snapshot words and returns distinct
  labels: terse by default; where labels collide it adds, in order, the equipment word (so a preset
  called "Dumbbell" reads "No equipment recorded · Dumbbell" beside the tag's "Dumbbell"), the load
  type badge, the machine's gym, and finally an ordinal. Five tests, including the exact
  preset-named-like-a-tag case, two same-label machines, and the hopeless case.
- Codex could not execute tests this round (simulator `-308`, then a stalled runner — the same
  gotcha STATE records). **My runs are the evidence: 579 unit, chart UI 4/4.**
