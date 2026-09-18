# 01 — Cardio sessions, direction B

Type: task
Status: resolved — software merged; physical acceptance tracked in 02

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
Add Exercise / Add by Machine / Add Cardio (scrolls)
Pause or Resume                      End Cardio (pinned)
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

### N1 / N2 corrections and measurement

Heartbeat checkpoints now use append-only `WorkoutSensorSample` rows; no growing blob is
assigned at each tick. Domain `finishInPlace` folds checkpoints (including zone provenance)
into the frozen summary and clears them, covering strays without a live coordinator.
`unit-7`: **748 tests / 81 suites passed**, actual exit **0**; `build-8` passed.

Measured one simulated hour at 1 Hz through the real recorder and disk-backed SwiftData:
**3,600 distinct inserted sample rows, 3,600 insert-save notifications**, retained store files
**1,032,192 bytes**, elapsed **73.18 s** on the simulator. The same trace's growing-blob
payload sum would be **641,698,200 bytes**. This is save/insert instrumentation and retained
file size, NOT a physical NAND-write or energy measurement; real device battery remains
unmeasured. Output is `SENSOR_CHECKPOINT_WRITE_PROBE` in `unit-7.log`.

Visual self-review of `focused-ui-5` captures: live controls were below the first viewport at
AccessibilityL and outdoor default, so Pause/Resume + End Cardio are now pinned in the safe
area (stacked at accessibility sizes). The explicit AccentColor asset stabilizes map stroke
colour; fixture-disabled location callbacks can no longer request real location or inject a
misleading permission message. Capture input uses a short plausible distance, not 2.40 mi in
seconds. These UI corrections require recapture and visual follow-up.

Schema 10 remains development-only: no v10 build has been installed or exported by the user.
The reviewed interim JSON-lines blob was replaced by rows before release; no live data format
was silently changed. The former codec and its blob attribute were removed.

### Visual review follow-up

[Claude visual 01](../claude-visual-01.md) assessed the earlier d0bcb54 renders. A1–A3/V1
are corrected in source (pinned controls, fixture sensor guards, explicit amber route asset).
V2 icons now use neutral text colours. V5 add actions stack at accessibility sizes. V7 current
sensor pace is hidden while an entered distance overrides measurements, so two conflicting
pace bases are not displayed. N4 idle lifting focus hides the sensor bar when no activity is
collecting. V6 new captures cover paused, lifting banner, editor and replacement-picker note
at both sizes. Recapture and independent re-review remain required.

V3 recorded exception: native compact navigation chrome may truncate the workout title at
AccessibilityL; the full activity name is in content and workout rename retains the full name.
The whole-workout timer remains in the shared header because mixed sessions need both clocks.
V4 existing History lifting headline and native Cardio section header are retained for this
release; they are semantic peers but not typographically identical. V7 receipt metadata may
wrap at spaces and the existing whole-workout duration format remains unchanged.
N3 (low) remains: switching during HealthKit startup can bank that short phase's energy only
at workout level, not its segment. This is not a distance/pace or whole-workout energy loss.

Earlier 21 native screenshots are preserved under [screenshots/review-01](../screenshots/review-01/)
from `focused-ui-5`, **7/7 passed**, exit 0. They show scripted sensors/manual values and a
synthetic route, not physical-device tracking. New final captures will be linked separately.

### Final gate job (running)

Frozen source **03ada3d**, pushed to origin. Debug `build-10` passed, exit 0.
Detached runner PID **59715**, script `results/cardio/final-03ada3d.sh` under the UI-redesign
record; derived `/tmp/wt-cardio-final-derived`. Runs targeted recorder/checkpoint/provider
units (`unit-targeted-8.xcresult`), then the entire UI target (`full-ui-1.xcresult`, expected
79 methods). Logs and actual exit files share those stems. Do not edit source or use this
simulator until it finishes. Claude follow-up requested against this exact commit.

### Physical acceptance still outstanding

After a separately requested, backed-up phone install, record device OS/AirPods firmware and:

1. Indoor Walk and Indoor Run with AirPods Pro 3: compare distance/average pace to treadmill
   readings, first carrying the phone, then leaving it on the console. Record which source
   label appears and whether HealthKit distance actually arrives; HR alone is not a pass.
2. Pause/resume, lock/unlock, and disconnect/reconnect: active time excludes pauses; cumulative
   distance does not double; old totals survive a quiet stream; fresh pace returns only with
   new measurements. Where distance never arrives, the source must remain unavailable or
   honestly labelled Phone motion, with manual entry available.
3. Indoor cycle/rower: verify HR/calories and any genuinely supplied machine distance; otherwise
   enter machine distance. AirPods are not a universal bike/rower distance sensor.
4. Outdoor walk/run/ride: grant location, record a short route while locked, pause/move/resume,
   then finish and inspect History. No line or distance bridges the pause; stop tracking at End.
5. Lift → cardio → lift → Finish: one app History item, distinct segments and typed Health
   workouts, no overlapping energy totals. Force-quit/relaunch once to check paused recovery.

Route persistence currently rewrites its encoded route as points arrive (review F6, low);
long outdoor-session device energy/IO remains unmeasured. The measured heartbeat-row probe
does not establish GPS power consumption. Watch companion cardio is outside this release.

### Independent code clearance

[Claude review 03](../claude-review-03.md) clears **03ada3d**: N1/N2 resolved, no remaining
High/Medium code findings. Visual and full UI gates still outstanding. The final targeted
recorder/checkpoint/provider run passed **13/13**, exit 0 (`unit-targeted-8.xcresult`).
Built Info.plist inspected: location background mode and motion/location usage strings exist.

Retained low limits R1–R3: a lifting rest timer stays active/alarming but its bar is hidden
while Cardio focus shows recording controls; finishing long workouts removes transient sample
rows in one save (watch phone finish latency); whole-route encoding cost and short explicitly
started lifting phases saved to Health remain as previously recorded.

### Full-run interruption: capture query

`full-ui-1` was interrupted after both new capture methods failed at their added picker Cancel
step. The native hierarchy shows two Cancel buttons, one on covered Indoor Run navigation and
one on Choose Cardio. The test used an unscoped query. No source changes during the run.
SIGINT did not finish teardown (Xcode asserted during cancellation); exact xcodebuild PID
60130 was terminated, exit143, and its partial xcresult has no readable Info.plist. Preserve
its log as failure evidence; it is not a suite result. An early isolated rerun was also stopped
(exit143) because teardown had not ended; its result is excluded. After both processes ended,
`cancel-repro-2` reruns the unchanged default method alone before narrowing the query.

The unchanged isolated `cancel-repro-2` reproduced the same multiple-Cancel query failure,
exit65. Scoped the query to `navigationBars["Choose Cardio"]`; product source is unchanged
from code-cleared **03ada3d**. Commit **306acf4** (pushed) freezes the corrected test.
Runner PID **64009**, `final-306acf4.sh`, runs seven focused cardio tests (`focused-ui-6`)
then full79 UI (`full-ui-2`) only if focused passes. Same derived folder and result root.

### Recapture passed

`focused-ui-6` on **306acf4**: **7/7 passed, 0 failed/skipped**, actual exit0. Exported
**29 native screenshots** under [final captures](../screenshots/final/), browsable in the
[gallery](../gallery.html). Two non-failing invalid-frame runtime warnings remain, matching
the pre-existing warning class. Author inspected default/AXL live, paused, scrolled controls,
outdoor, route, History route, editor, lifting banner and replacement picker. Controls stay
visible; source/distance fields are reachable above them when scrolled; route is amber; no
false location error; new state captures are readable. Independent visual pass requested.
`full-ui-2` has started automatically on the same frozen source.

### Independent visual clearance

[Claude visual 02](../claude-visual-02.md) viewed all29 final PNGs and clears the built UI.
No blocking visual findings. Full UI result remains the merge gate. Retain low W1–W4 for
future polish: scrolling content can peek around the floating control card but every field
is reachable; the lifting-side recording banner is tappable without a chevron; the picker
consequence note uses a single native list row; existing large-text gym/sets header wraps.
Receipt metadata orphaning and mixed duration formats remain the recorded copy exceptions.
These are accepted low items for this release, not silently lost findings.

### Full gate passed

`full-ui-2` on product **03ada3d** / test **306acf4**: **79 passed, 0 failed, 0 skipped**,
actual xcodebuild exit **0**, readable xcresult summary verified. Completed 2026-09-18
03:58 EDT, test duration **2779.194 seconds**. Runner64009 is finished. **24 non-failing
invalid-frame warnings**, all the previously known message class (baseline ticket17 had22);
origin remains uninvestigated. No other runtime-warning class.

Exported and inspected [lifting regression captures](../screenshots/regression/) at default
and AccessibilityL, including scrolled add actions/rest controls. Existing lifting layout
stays usable; the new large-text add buttons are stacked and readable. Final code/visual
reports are already clear; final merge-clearance review requested against these actual results.
No product or test changes after306acf4; later commits contain docs and native captures only.
No phone installation or physical sensor/GPS acceptance is claimed.

### Final independent clearance

[Claude final gate](../claude-final-clearance.md): **clear to merge** the unchanged reviewed
product/test trees once this evidence is committed and pushed. Counts and exit files were
independently read, final test query checked, and four lifting regression captures inspected.
Commit this record/captures/report together, then fast-forward/push main and verify remote tip.
Physical acceptance remains outstanding, with no phone install authorized by this review.

### Merged

Fast-forwarded main from14982e7 to **b0a8de9**, pushed origin/main and independently checked
`git ls-remote`: remote tip b0a8de99a3f10269dc4b3d63445eb053f5f07559. Product tree equals
reviewed03ada3d; test tree equals306acf4. No phone install. [Device acceptance](02-device-acceptance.md)
remains open. No build/test job remains running. Graft refreshed in implementation and main.

Workspace cleanup: attempted Orca Sleep through its UI after all tests; macOS returned
`permission_denied` / no accessibility window, including one restore-window retry, despite
permission inspection showing grants. Completed cards can be marked through CLI but actual
Sleep is unverified and deferred. No workspace, terminal history, or logs were deleted.
