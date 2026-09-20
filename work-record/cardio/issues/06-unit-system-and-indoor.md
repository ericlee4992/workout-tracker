# 06 — App unit system and clean automatic indoor metrics

Type: task
Status: claimed

User request 2026-09-19: remove the Phone motion estimate section during device-tracked indoor
runs; show no such source/estimate detail. Rename app unit choices to Metric / U.S. customary
and make the preference affect cardio too. Reopens D15/D54 presentation and T7 unit defaults.

## Behavior / decisions

- Automatic indoor readings stay in the main distance/pace metrics. Hide the duplicate live
  distance/source editor once automatic distance arrives. Manual entry remains available
  when there is no automatic distance, and for an explicit manual value; saved-workout
  correction remains available. No technical automatic indoor-source captions in live or
  saved cards. Keep source evidence, sensor priority/fallback and normalized measurements.
- App unit system: Metric → kg/km and pace per km / speed km/h; U.S. customary → lb/mi and
  pace per mi / speed mi/h. Existing kg/lb preference maps directly; no stored field/schema
  change. Machine/gym overrides remain lifting-only, per T7.
- User explicitly chose **new cardio activities only, preserving existing workout units**: apply to newly started cardio segments;
  active/saved segments keep their unit snapshot. No stored entered values rewritten.
- Compatible-device status is established by actual distance arrival, not an HR connection.
  No display claim that a particular hardware device supplied every distance sample.

## Composition / copy

In live automatically measured indoor cardio the user reads progress and pauses in one tap;
the eye lands on timer, with distance/pace underneath and Pause at the thumb. No duplicate
source/estimate row. In manual/no-distance indoor cardio the Enter distance action remains.
In Settings the user chooses one unit system; the App unit preference row keeps its native
menu affordance and selected value. Visible choices Metric / U.S. customary are user-requested.

```
Settings: App unit preference  Metric / U.S. customary >
          existing rest / prompts / zones / scanner / export rows
Indoor:   header / activity / TIMER
          Distance + pace / HR + calories / optional current pace
          Add actions / pinned Pause + End
          (Enter distance only when manual input is needed)
```

Tells: extra containers absent; caption chips absent; all-caps proliferation absent; existing
middle-dot details deliberate; excess accents absent; duplicate equal-weight blocks removed;
website hero absent; unnecessary above-fold detail removed; disguised controls absent;
default-only layout absent (existing AXL stacks, paired captures). Existing tokens and copy
stay except user-requested unit labels, removal of technical source captions and deletion of
obsolete motion-error manual-entry instruction when its live editor may be hidden.

## Verification

Mapping/default persistence tests, existing cardio/recording/export/bootstrap tests; UI flow
changes both unit choices then starts cardio; no-source row for automatic HK and phone-motion
fixtures; manual fallback/editor remains. Real Settings and indoor default/AccessibilityL
captures, build, full local unit/UI gates, independent Claude code/visual review before merge.
No schema migration; data/export semantics remain frozen/as entered.

Base main **e457493**, branch `ericlee4992/cardio-units-and-sources`. Implementation pending.

## Progress

Detached runner PID **74033**, implementation worktree
`/Users/ericlee06/orca/workspaces/Health App/cardio-units-and-sources`; artifacts under
`work-record/ui-redesign/results/cardio-units/`: `run-focused.sh`, build/units/focused
`.log` and `-exit.txt`, unit/focused `.xcresult`. Build, full units (752 expected),
9 focused indoor/Settings UI tests run serially. Full UI gate expected85 after new tests.

## Initial review and tests

Build passed; product **d4de3d8**. Claude code review clear to proceed, no schema/data/new-only
defect. F1 deliberately accept: a real automatic zero is a measurement (not missing data),
so it also hides the duplicate row. Small/zero readings can be corrected after End; no
threshold falsely treats real low movement as absent. Nil distance still offers Enter
distance; manual overrides remain editable live. This follows user's request to omit the
section during automatic tracking. F2 removal of No distance source caption deliberate:
Enter distance itself is sufficient. F3 renamed saved-editor test accurately and restored
Measured-line assertion; manual live clear-and-resume measurement is not newly tested;
existing domain clear-override tests remain. Old editor captures are historical, not current.
F4 D15 now points to D52/T7 and this ticket.

Initial full-unit log: 752 tests, new AppUnitSystemTests passed; known load-sensitive
HeartRateMonitorTests.samplesArriveAndBecomeTheCurrentReading and
CodexReviewRegressionTests.theFeedStateNamesTheSourceOfTheReadingShown failed under the
full run. Follow DEVELOPMENT: rerun affected cases, then full suite serially; preserve
initial log/result. No feature change inferred from these failures.

Initial run printed 752-test failure summary at194 seconds, but xcodebuild remained waiting
without finalizing for over2minutes after the app process exited. Sent INT to exact
xcodebuild PID74706; interrupted result/exit retained (not a pass). Retry runner PID **87396**
waits for that exit, then `timing-rerun` (both affected classes plus new AppUnitSystemTests),
`units-rerun` (full), `focused` (9). Logs/exits/results in same directory.

INT left Xcode's DVTOperation cancellation assertion stuck; exact PID74706 was verified
and sent TERM. This is runner cleanup, not an app-code fix. The retry remains serialized
behind its recorded exit; no simultaneous simulator run.
