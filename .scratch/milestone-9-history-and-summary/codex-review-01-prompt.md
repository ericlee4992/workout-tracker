Cross-review (T6) of milestone 9, ticket 01, on branch
milestone-9-history-and-summary. Review boundary: 05a83c8..18d76ec (one commit,
18d76ec). Read .scratch/milestone-9-history-and-summary/spec.md and
issues/01-chart-per-equipment-and-history-chart.md for intent, and
docs/DECISIONS.md for D7, D23, D36, D37, D39 and D47.

## What was built

ProgressVariationKey (Domain/ProgressSeries.swift) gained freeWeightTag,
every field required; ProgressSeriesMath.series now takes the key. The
chart in Features/History/ExerciseProgressView.swift names the tag in its
variation picker and accepts an optional initialVariation. WorkoutDetailView
got a per-exercise chart button that opens the chart on that session's
snapshot variation. ChartFixture seeds two dumbbell sessions. 4 unit tests
and 1 UI test added; 19 existing chart call sites were rewritten mechanically.

## Specific things to attack

1. **Is the tag the RIGHT axis, and is nil the right group?** A machined set
   has a nil tag (WorkoutSession.chooseEquipment clears it). Does anything
   else produce a nil tag that this now silently pools with machine history —
   entries created before tags existed, entries added from History's
   "Add Exercise" (which records no equipment), the export/import path? Is
   pooling those with machined sets honest, or is it the D36 bug again under
   a different name?
2. **Parity with RecordsMath.groupKeys.** The chart is exercise-scoped; the
   records have machine/model groups the chart does not. Is there any case
   where the chart now claims a "best" that the records screen would not,
   or vice versa, for the SAME variation?
3. **The mechanical test rewrite.** 19 call sites went through a regex. Did
   any test lose its meaning — a test that meant "any variation" now
   asserting on the nil group, or a test whose fixture sets carry a tag
   the assertion no longer sees?
4. **initialVariation.** It is seeded into @State once. If the sheet is
   re-presented for a different entry, does SwiftUI reuse the view and keep
   the old variation? If the session's variation has NO eligible history
   (all warmups, or the only set was deleted), what does the chart show —
   an empty state under a picker that names a variation with 0 days?
5. **variationName fetches every ExerciseEntry** per picker row. It did
   before too, but the picker now has more rows. Is this a real cost on a
   multi-year history, and does it read live rows anywhere D23 forbids?
6. **The tie-break order** in defaultVariation and availableVariations was
   written twice (Domain and view). Do they agree? Should the view's sort
   derive from the Domain's?
7. **The absence-of-a-caller class.** This repo has shipped it eight times.
   Is every new identifier/parameter actually used? Is anything declared in
   this commit that nothing reaches?

Report findings by severity with file:line, say plainly if a claim in the
ticket or commit message is wrong, and do not soften. Write the review to
.scratch/milestone-9-history-and-summary/codex-review-01.md
