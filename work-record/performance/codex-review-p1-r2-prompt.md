# Codex review — P1 round 2

Same branch `ericlee4992/perf-01-workout-lag`. Your round-1 report: `work-record/performance/codex-review-p1.md`
(clear, one P3: "Recent at <gym>" read in `body`). Review the fix: `git diff 5066a33c..HEAD` —
`ExercisePickerSheet.swift` (`recentAtGym`, loaded in `.onAppear`), `ActiveWorkoutView.swift` (`recentAtGym`,
`loadRecentAtGym`, `.onAppear` + `.onChange(of: gym id)`), the new fixture flag `-uiTestPerfNewGym` in
`PerfFixture.swift`, the new `LiveRecentUITests` (Workout plan), and the ticket's round-1 section with the
measurements.

Check: the list shows wherever it did before (first appearance, a gym change on the live workout, the empty-workout
state reached by deleting the last exercise, minimise/resume, the sheet opened from a workout with or without a
gym); a deleted exercise cannot be offered; nothing can change finished history while either view is up; no
`[DEBUG-p1]`/`P1Probe`/`P1_` left in sources.

Per AGENTS' reviewer rule: build; the Unit plan; UI changed, so rerun `AAAWarmUpUITests`, `LiveRecentUITests`,
`CoreLoopUITests`, `FloodlightTourUITests` (2 workers). You may inspect Claude's `/tmp/p1/focused-r2.xcresult` (those
plus `FloodlightLiveUITests`, `LivePrefillUITests`). Your own paths under `/tmp/codex-p1-r2/`. Claude runs nothing
while you run. Do not modify files other than the report; do not commit or push.

Write `work-record/performance/codex-review-p1-b.md`: findings with file:line, failure scenario and fix; Verified /
Not verified / Known flaky; end with exactly `Verdict: clear` or `Verdict: not clear`.
