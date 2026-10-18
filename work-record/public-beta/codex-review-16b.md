# Ticket 16 — review, round 2

Reviewed `git diff d6c1f49..399e1ad` against the three prior P2 findings and the ticket's response.
HEAD: `399e1adf6a6b2bc96d3b762fea631f3025bf5cdb`.

1. **P2 — Prior #1 is partially fixed: measured-segment pace is still presented as the session's pace.**
   **Location:** `WorkoutTracker/Domain/CardioProgress.swift:105–110`;
   `WorkoutTracker/Features/Progress/CardioProgressView.swift:111–118,153–162`;
   `WorkoutTracker/Features/Progress/ProgressPanel.swift:82–118`.
   `measuredSeconds` correctly pairs the measured distance with its corresponding duration. However, none of the
   presentation paths identifies that narrower statistic, as the round-1 correction required. The regression
   example now renders `2.0 km · 20 min · 5:00 /km`: the time covers both segments, while the pace covers only ten
   minutes. It also enters the ordinary Pace/Speed chart, change and Fastest/Fastest average displays without a
   distinction from completely measured sessions. The whole-session pace remains unknown, so the arithmetic fix
   alone does not resolve the misleading presentation. **Fix:** either omit pace/speed for incomplete-distance
   sessions, or preserve coverage information through the chart/readout/bests paths and clearly identify the rate
   as applying only to measured segments. Add a presentation/eligibility regression for the mixed-distance case.
   This concerns missing measurements, not the user-approved omission of indoor estimate marks or notes.

**Prior #2 — resolved.** Entry fetches now occur in `ProgressTabView.refresh` and `AddChartSheet.load`, not panel or
search rendering. Add Chart caches summaries and hands entries to the variation page, which computes ranking and
labels on appearance. The tab uses its existing preferences query; the new `displayUnit(preferences:)` overload
preserves the original canonical-preferences and unit-precedence calculation.

**Prior #3 — resolved in code.** `ProgressTabView.save` now passes a nil animation when Reduce Motion is enabled.
This covers add, metric change, move and removal. No new cache, selection, pin persistence or schema regression was
identified. Runtime Reduce Motion remains unverified; the optional UI run was skipped in this review.

Verification personally performed with **Xcode 27.1 (27A9275)** on **WT-Floodlight, iOS 27.0**:

```sh
xcodebuild -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -sdk iphonesimulator \
  -configuration Debug -destination 'platform=iOS Simulator,id=9E822EF6-DC67-4958-AEA2-D53D2D36D674' \
  -derivedDataPath /tmp/wt-review16-dd -resultBundlePath /tmp/wt-review16-20261017-r2/build.xcresult build

xcodebuild test -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -sdk iphonesimulator \
  -configuration Debug -destination 'platform=iOS Simulator,id=9E822EF6-DC67-4958-AEA2-D53D2D36D674' \
  -derivedDataPath /tmp/wt-review16-dd -resultBundlePath /tmp/wt-review16-20261017-r2/unit.xcresult \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  -only-testing:WorkoutTrackerTests/ProgressPinTests \
  -only-testing:WorkoutTrackerTests/CardioProgressMathTests \
  -only-testing:WorkoutTrackerTests/ProgressSeriesTests
```

Build: **exit 0, BUILD SUCCEEDED**. Unit selection: **exit 0, TEST SUCCEEDED; 30 passed / 0 failed / 0 skipped**,
confirmed from the log, actual exit-status files and `xcresulttool get test-results summary`. Artifacts:
`/tmp/wt-review16-20261017-r2/{build,unit}.{log,status,xcresult}`. The new run/cycling regression proves the corrected
paired arithmetic and retention of total time; it does not check the unresolved presentation above.

The supplied captures and layout code are unchanged from round 1. No new UI or device acceptance is claimed.
`git diff --check` passed. Only this report was written; no commit or push.

Verdict: not clear
