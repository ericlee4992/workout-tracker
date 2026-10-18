# Ticket 16 — Progress tab review

Reviewed `git diff main...HEAD`, with main pinned to `696a395b8ce54164fd7a8a025a2bf854890f40ca` and HEAD
`d6c1f49506c1888243e2ad0fe6e91f2c81156c70`. Reviewed the final implementation, not the superseded prototype designs,
against ticket 16, D63 and the cited history/unit decisions, SPEC, and the iOS design rules.

1. **P2 — Missing distance in one segment produces an unsupported session pace/speed.**
   **Location:** `WorkoutTracker/Domain/CardioProgress.swift:48–55,95–99`.
   `sessions` sums only non-nil distances but sums the active duration of every segment of that activity. For a
   finished workout containing a 2 km / 600-second run followed by a 600-second run with no distance, the resulting
   session has 2 km and 1,200 seconds. Its chart and session row display 10:00/km, although the whole-session pace is
   unknown; the measured segment's pace was 5:00/km. Cycling speed has the same mismatch. These values also feed
   changes and bests. **Fix:** retain total time, but track distance completeness and omit whole-session pace/speed
   when a contributing segment lacks distance, or explicitly pair distance with the duration of the same measured
   segments and identify that narrower statistic. Add mixed known/missing-distance cases for pace and speed; the
   current tests cover complete distances and an entirely distance-less session, not this combination.

2. **P2 — Full-history fetches still occur per panel/row during rendering.**
   **Location:** `WorkoutTracker/Features/Progress/ProgressTabView.swift:156–164`;
   `WorkoutTracker/Features/Progress/AddChartSheet.swift:83–89,141–145`.
   Although set inputs are cached on appear/after sheets, each lifting panel's `liftLabel` fetches every
   `ExerciseEntry`. Add Chart repeats that full-table fetch for each exercise row and for the variation page's
   labels. Scroll-title state changes, pin changes and search typing therefore repeat main-thread history work,
   multiplied by the user's unlimited pins or logged exercises. This violates the explicit fetch-on-refresh
   requirement. **Fix:** fetch entries once alongside the cached history and derive/reuse variation labels from
   that snapshot. Pass those labels into the selection page; refresh at the existing lifecycle points. Use the
   already queried preferences for the tab's display unit rather than another preferences fetch per lifting panel.

3. **P2 — Reordering pins ignores Reduce Motion.**
   **Location:** `WorkoutTracker/Features/Progress/ProgressTabView.swift:25–26`.
   Every pin mutation uses unconditional `withAnimation(.snappy(duration: 0.3))`. Move Up/Down consequently animates
   whole chart panels through space even with Reduce Motion enabled; this view does not read the setting, and its
   parent does not suppress the transaction. The iOS design rules require suppressing spatial motion or replacing
   it with a crossfade. **Fix:** read `accessibilityReduceMotion` and perform these updates without spatial animation
   when enabled. Verify moving/removing pins with that setting on; the current UI flow does not cover it.

The standards and specification reviews otherwise found the intended boundaries intact:

- `ExerciseHistory` preserves the old exercise-ID, deleted-row, finished-workout and snapshot-field filters.
  `LiftProgressValues` preserves plotted/as-entered/callout values, changes, units and metric availability. The
  panel and exercise chart share `ProgressSeriesMath` for the same variation; no pooling of machines/presets was
  introduced. Existing exercise-chart behavior is unchanged by the extraction.
- Fixed pins retain load type, equipment identity and preset; Most used delegates to the existing resolver.
  Unknown activities decode and are hidden; unreadable data yields no pins; nonweighted metrics fall back to Best
  set. Visible moves swap the actual stored positions, leaving hidden pins in place. Pin operations write
  UserDefaults, not SwiftData. No persistent model/schema change was introduced.
- The new fixture seeding requires `-uiTestReset` through `DesignSampleFixture.isEnabled`; keep/no-pins flags are
  consumed only inside reset/fixture paths. Standalone fixture flags do not seed the real store or change its pins.
- Cardio grouping is per finished workout/activity. Rowing uses 500 m pace, cycling uses speed, pace plotting is
  negated, new-best comparisons are strict, bests retain the earliest tie, and session heart rate is sample-weighted.
  The user's removal of indoor approximation marks/estimate notes is accepted, not a finding.
- Inspected final PNGs covering light/dark, Default/AccessibilityL, tab panels, Add Chart, cardio distance/pace,
  bests/sessions and the empty state. The approved equal-panel design is respected; sampled text remains readable.
  Segmented options retain their names, and the Add/Cancel and chart Close flows retain their staged semantics.

Verification personally performed with **Xcode 27.1 (27A9275)** on **WT-Floodlight, iOS 27.0**:

```sh
xcodebuild -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -sdk iphonesimulator \
  -configuration Debug -destination 'platform=iOS Simulator,id=9E822EF6-DC67-4958-AEA2-D53D2D36D674' \
  -derivedDataPath /tmp/wt-review16-dd -resultBundlePath /tmp/wt-review16-20261017/build.xcresult build

xcodebuild test -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -sdk iphonesimulator \
  -configuration Debug -destination 'platform=iOS Simulator,id=9E822EF6-DC67-4958-AEA2-D53D2D36D674' \
  -derivedDataPath /tmp/wt-review16-dd -resultBundlePath /tmp/wt-review16-20261017/unit.xcresult \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  -only-testing:WorkoutTrackerTests/ProgressPinTests \
  -only-testing:WorkoutTrackerTests/CardioProgressMathTests \
  -only-testing:WorkoutTrackerTests/ProgressSeriesTests
```

Build: **exit 0, BUILD SUCCEEDED**. Unit selection: **exit 0, TEST SUCCEEDED; 29 passed / 0 failed / 0 skipped**,
confirmed in the log and `xcresulttool get test-results summary`. Logs and actual exit-status files are
`/tmp/wt-review16-20261017/{build,unit}.{log,status}`. These passing tests do not cover the mixed-distance defect.
Optional UI execution was **skipped**; UI conclusions above use source and the committed captures, not a new UI run.
Only this report was added to the checkout; no commit, push, phone installation or server action.

Verdict: not clear
