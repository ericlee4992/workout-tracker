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
