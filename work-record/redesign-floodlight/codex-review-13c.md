# Ticket 13 — independent Codex review, round 3

Reviewed 2026-09-29 in `/tmp/wt-floodlight/cardio`, branch
`ericlee4992/redesign-floodlight-cardio`, clean starting HEAD
`522c157a64d3b092f4439bbad93b143548bd9205`.
Comparison: `git diff 759aedf HEAD -- WorkoutTracker WorkoutTrackerTests WorkoutTrackerUITests`.
The only code change is `WorkoutTrackerUITests/ProgressChartTooltipUITests.swift`.

**Clear.** Both round-2 findings are resolved; no critical, high, medium or low finding remains in
this change. The drag test captures the existing selection label before acting and waits for it to
change (`ProgressChartTooltipUITests.swift:41–55`). The app supplies an explicit label containing
the historical point's absolute date and as-entered value (`ExerciseProgressView.swift:210–222,461–464`),
so midnight, DST, scrolling and chart animation do not independently change it. The initial
on-appear assignment preserves the already resolved default variation (`:129–130,597–601`), and
repeated fixture weights remain distinguishable by date. The row exists before capture; its explicit
label is not a loading placeholder. A missing row would also fail the subsequent “lb” assertion.
The five-second predicate wait handles the selection update without relying on a second clock.
The launch arguments pin the app to `en_US` and English before launch (`ProgressChartTooltipUITests.swift:17`);
reset creates fresh preferences, and app initialization resolves their unit through
`Locale.current.measurementSystem` (`WorkoutTrackerApp.swift:97–100`, `Models.swift:785–791`,
`AppUnitSystem.swift:12–15`). That reaches the pound preference used by History's “450, lb” selector.
The other three tests retain their checks for the plain/Narrow grip values, the Dumbbell session's
initial variation, and the warmup-only Barbell variation with a usable picker. No concrete new
vacuous pass, date failure or flake was found in the class.

## Recorded verification

Independently read the actual exit files, xcresult summaries and logs under
`/tmp/wt-floodlight/results/`:

- **`rc-fix-3`: exit 0, 4/4 passed, zero failed/skipped.** The log records compilation of the changed
  test file, the real drag at line 365, the new label comparison at line 376, and `TEST SUCCEEDED`.
- **`rc-mutation-1`: exit 65, one failed test, zero skipped.** With the drag omitted, the comparison
  repeatedly sees `Sep 28, 2026, 120 lb × 8` and times out at the new assertion
  (`rc-mutation-1.log:190–217`). The xcresult reports that same failure. This demonstrates that the
  new check rejects the unchanged fallback in the recorded case. The reviewed source contains the
  restored drag, and the checkout was clean at review start.

Both summaries report zero runtime warnings. The four-test class run plus the deliberate mutation
is appropriate under DEVELOPMENT's verification policy for this test-only change; the earlier
calendar/fixture checks remain applicable. This review does not claim a fresh UK-simulator run,
device installation, or hardware verification.

**Standards: clear. Spec: clear.** No `xcodebuild` or `simctl` was run during review; only this report
was written. At the reviewed HEAD, the ticket contains the `rc-fix-3` and `rc-mutation-1` rows but
does not contain the named “Codex review 13b — response (round 2)” heading. The conclusions above
come from the actual diff, callers and recorded results.
