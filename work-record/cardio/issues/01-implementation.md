# 01 — Cardio sessions, direction B

Type: task
Status: claimed — implementation begun

Base main `14982e7`; branch `ericlee4992/cardio-implementation` in
`/Users/ericlee06/orca/workspaces/Health App/cardio-implementation`.

Scope and acceptance: [spec](../spec.md). User approved B, optional devices/manual fallback,
indoor distance/pace with supported connected devices, and requested building on 2026-09-18.
[Primary-source/API research](../research/01-indoor-distance-and-pace.md) (`7284cc0`).
No product code changed at this initial checkpoint; no build/test/install yet.

## Design contract

Live cardio: glance at the current activity and pause it in one tap; the timer leads and
Pause is the primary control. Paused: Resume leads. Lifting retains its current set/rest focus.
Picker: choose one activity in one tap from grouped lists. Receipt/History: one saved workout,
separate lifting and cardio sections; View in History stays primary on receipt.

```
Workout name                                         Finish
Gym / whole-workout time
[ Lifting | Cardio ]
Current cardio activity
                  active timer                       hero
Distance / current pace (or speed)
HR / calories if available
Route (outdoors) or source/entered distance (indoors)
Pause or Resume                      End Cardio
Add Exercise                         Add Cardio
```

Approved structural reference: prototype `48608fb`, direction B; do not merge throwaway code.
Tells: containers deliberate for meaningful groups; chips deliberate for existing zones;
all-caps only existing set labels; middle-dot metadata deliberate for compact session context;
accent deliberate for selected/live state and primary Pause; peer metric pairs deliberate;
website-like layout absent; above-fold focus deliberate for live activity; picker as primary
absent; default-only layout absent once matching real AccessibilityL captures pass.

## Work and evidence

- Research is complete; HealthKit has iOS 26 live APIs. AirPods indoor distance arrival is
  device-dependent and must be physically verified; it cannot be inferred from HR connection.
- Next: preserve a current pre-cardio migration fixture, implement domain/session invariants,
  serial sensor transitions, UI/History/export, then relevant and full UI gates and Claude review.
- Existing legacy fixture is older than the installed schema; do not call it live-store proof.

### Pre-cardio migration fixture

Generated under unchanged production model definitions at base `14982e7` (research branch
`7284cc0` adds only a Markdown note), temporary generator test **1/1 passed**, exit 0.
Generator preserved under `tools/GeneratePreCardioFixtureTests.swift`; synthetic history only.
Copied and SQLite-checkpointed as `WorkoutTrackerTests/Fixtures/PreCardio.store`, integrity
check `ok`. Source hash matches the currently installed product model shape; this is a
synthetic compatibility fixture, not a copy of private phone data or a backup/restore test.
Runner PID 26241 finished; log/result `/tmp/wt-cardio-pre-migration/`; derived
`/tmp/wt-cardio-pre-derived`. Actual migration into new schema remains to be tested.

### Implementation checkpoint

Implemented additive cardio model/session math, sequential phone HealthKit activity provider,
indoor live distance collection and labeled phone-motion fallback, GPS route recording, B
focus UI/start picker, cardio receipt/History and JSON/CSV schema 10. No phone install.
Debug build `build-3.log` passed, exit **0**. Full unit suite **734 tests / 78 suites passed**,
actual exit **0**, `unit-3.xcresult` (2026-09-18). Includes current pre-cardio and legacy
migration tests, domain/source precedence, export and serialized sensor lifecycle tests.
Earlier unit attempts: one test-source syntax error; then three expected version/format
assertions failed after schema extension. Fixed those assertions; no failure erased.

Runner PID **31080**, script `work-record/ui-redesign/results/cardio/verify-3.sh`, derived
`/tmp/wt-cardio-derived`. All build/unit/focused logs, result bundles and exit files are under
that results directory. The four new CardioUITests are running (`focused-ui-1.xcresult`).
A summary-card accessibility-query issue may need adjustment; inspect actual result first.
Full existing UI suite and independent review remain outstanding.

Device scope remains explicit: this implements the phone’s supported HealthKit HR devices,
including the AirPods data path. The separate never-installed Watch companion still speaks a
strength-only protocol; its mislabeled cardio data is excluded. Do not claim Watch cardio or
real AirPods indoor distance is device-tested. A real AirPods treadmill run remains required.

### Focused UI diagnosis

First run failed: three default-size flows could not open the distance editor; AXL reached
summary but its query targeted an inherited Image identifier. Unchanged isolated rerun
`distance-repro.xcresult` reproduced the distance failure, exit 65. The native hierarchy
showed a full-width button with a blank center hit region. Adding `contentShape(Rectangle())`
made the distance step pass (`distance-fix.xcresult`), then exposed the independent summary
query issue. Its ID now belongs to the combined title label instead of propagating to every
child. `focused-ui-2.xcresult` is running; default and AXL capture/save methods have passed so
far. New captures will be exported after its actual completion.

Independent Claude reviewing baseline `b359d7c` in `review-cardio-implementation`; report
`work-record/cardio/claude-review-01.md` pending. Author has identified a source-handoff/paused
cumulative-distance overlap case; fix and regression tests are planned before full UI gates.

### Review-fix checkpoint (not yet re-cleared)

Claude code review of `b359d7c` found F1 overlapping pause spans, F2 cumulative-distance
staleness, F3 weak recording ownership, F4 untouched manual overrides; fixes now include
shared sensor epochs across pauses, source timestamps/stale fallback, strong ownership,
blank automatic-distance editor and preserved typed units. Added tests for late readings,
GPS continuation/pause/gaps, source-scoped HR and final segment energy.

`unit-4` passed **742/79**, exit 0. `focused-ui-3`: five indoor/mixed tests passed; two
outdoor fixtures attempted to tap Resume underneath the app’s automatic restore cover.
The fixture driver now waits for the restored cardio screen. The preceding isolated
`outdoor-repro` completed successfully; no outdoor recording failure was established by
those query failures. `build-5` failed an optional HeartRateZone binding introduced while
scoping live HR to the current segment; fixed before the fresh build below.

Additional in-flight persistence work preserves whole-workout HR samples and energy across
relaunch, adds segment energy baselines, and serializes sensor teardown between workouts.
Raw heartbeat checkpoints append JSON lines rather than re-encoding the whole series per
sample. Builds/tests before these edits do not establish their verification.

Next: fresh build in `/tmp/wt-cardio-final-derived`, freeze/commit source, unit + seven
focused UI tests, exported real captures and Claude re-review, then full local UI suite.
AirPods treadmill/background GPS device validation remains outstanding; no phone install.

### Frozen review-fix source

Fresh simulator Debug build **passed**, `build-6-exit.txt` = **0**, with a new derived-data
folder `/tmp/wt-cardio-final-derived`. Commit immediately after this checkpoint is the frozen
source for the next unit/focused run. No code edits during that run.

F1–F4 implementation corrections are complete but re-review remains required. F5 final
segment energy, F7 endAny teardown, F9 resumed focus, F10 motion-error feedback and F12 alert
copy were also addressed. Cardio-only End no longer starts a phantom lifting phase. Very
short explicitly-started lifting phases can still save to Health (F8); hourly route/IO cost
remains unmeasured (F6). Added raw sensor checkpoint/energy baseline persistence and a
cross-workout teardown barrier, with targeted tests for those new paths.

Seven focused UI methods now cover both starts, manual/sensor input, unchanged-editor safety,
normal/AccessibilityL screens, and outdoor route display. `focused-ui-2` passed **4/4** on the
previous UI-only fix. `focused-ui-3` passed five indoor/mixed cases; its outdoor setup query
was corrected to respect automatic restore. Later fresh runs supersede these intermediate
captures. Nothing has been installed or hardware-validated.
