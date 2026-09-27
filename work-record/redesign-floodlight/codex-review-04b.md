# Ticket 04 — independent Codex review, round 2

**Not clear: one medium layout finding. No critical, high or low findings.**

Reviewed `743f609..6d027cd0896c262ed99dd79f540a9b1fbbc20bcf` on
`ericlee4992/redesign-floodlight-finish` in `/tmp/wt-floodlight/finish`, 2026-09-27.
Only this report was written; no `xcodebuild` or `simctl` commands were run.

## Medium — let the restored bar annotation wrap at accessibility sizes

**Location:** `WorkoutTracker/Features/ActiveWorkout/FinishPieces.swift:230–242`;
containing new-best layout at lines 158–180.

The restored `(20 kg bar)` is appended to the same horizontal value row, which still has
`.lineLimit(1).fixedSize()`. At AccessibilityL, finish a workout with a new best of
**102.5 kg × 10 on a 20 kg bar**. The enlarged total, unit, reps and bar annotation must all
occupy one intrinsic-width line inside the new-best text column, whose width is reduced by
the leading 40 pt stamp, 14 pt gap, panel padding and screen margins. This overflows the
column instead of putting the annotation below the load; the right-hand text can extend
beyond the panel/screen. Moving the value block below the exercise name at AX sizes does
not remove those width constraints or allow this inner row to wrap.

Give the bar annotation its own wrapping line (or use a layout that stacks it when needed),
including in exercise rows. Capture a bar-mode new best at Default and AccessibilityL in
both appearances. This finding follows the source layout; no new simulator reproduction
was run. The refreshed captures use a machine set without a bar, and `BarbellUITests`
dismisses the receipt before asserting History's bar breakdown, so those passes do not
exercise this layout.

## Round-1 findings and affected callers

- **1 — ring: resolved.** `ringRuns` includes unmapped sets and merges only adjacent runs;
  `familySets` remains the mapped-family key. Neutral runs use `textTertiary`. The >24-set
  fallback preserves proportional run order and uses index identities, so repeated families
  do not collide. The spoken summary counts every run and aggregates repeated families plus
  “other.” Core-only workouts now take the populated-ring path.
- **2 — locale parsing: resolved for production callers.** `CountUpFormat` reads with the
  formatting locale. Its only production caller is `StatFigure`; the active caller of that
  component is the receipt. `StatPairGrid` has no active screen caller here. Home and History
  do not introduce another parsing path. Explicit-locale tests check parsed values; the
  returned formatting closure still uses the process locale, which matches current
  production usage.
- **3 — volume precision: resolved.** The tile and both visual/spoken `ComparisonBars`
  values use grouped formatting with up to two decimals and half-up rounding. ComparisonBars
  is receipt-only in this checkout. Whole-number counts retain their intended formatting.
- **4 — spoken scope: resolved.** The replacement new-best label includes the equipment/
  preset string. The added UI assertion checks the machine in the spoken label.
- **5 — bar data/wording: resolved; layout finding above remains.** The incumbent preserves
  its bar through `RecordSetInput` and `SetValue`; current and exercise-row values retain it
  too. Every `RecordSetInput` construction and the ranking/grouping/equality consumers were
  traced: the field does not change record rank, eligibility, volume or group identity.
  Other constructors feed calculations and can retain nil. `LookFormat.set` callers in the
  receipt, live best-band labels and previous-value formatting introduce no incorrect bar
  arithmetic or duplicated suffix. Current live callers do not populate the bar field.
- **Performance note: addressed.** Finished history is fetched and flattened once per
  receipt. Per-entry in-memory filtering remains, including repeated scopes, but the change
  preserves workout exclusion, snapshot scope/load matching and the pre-start completion
  cutoff. No benchmark was run. Save as Template still does not mutate the saved workout;
  the previously noted same-ID external-change cache limitation is unchanged.

## Tests and evidence

Independently read `finish-build-6.{log,exit}`, `finish-ui-5.{log,exit}` and its xcresult
summary under `/tmp/wt-floodlight/results/`: build-for-testing **exit 0**, test **exit 0**,
**57 unit + 12 UI tests passed, zero failed/skipped**. Invalid-frame runtime warnings remain
in the result. The ticket says 11 `FinishReceiptTests`; source and logged method names contain
**10**, consistent with the overall 57-test total.

The ring tests discriminate against the former dropped/merged-set behavior; the locale
value assertions catch the old comma-stripping parser; the bar test catches missing
incumbent provenance and missing `LookFormat.set` suffix; the spoken-label assertion catches
omitted equipment. Decimal tests exercise the new formatter, but would not catch a receipt
caller reverting to `grouped`. The bar test does not exercise `FinishSetValueText` layout.
These are static assessments of test effectiveness; no tests were rerun or mutated.
Targeted scope remains appropriate, with the bar-mode receipt capture/check above needed
for this fix.
