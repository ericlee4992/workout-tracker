# Milestone 7 Heart-Rate Cross-Review

**Verdict: do not merge or install.** The diff contains multiple paths that can persist misleading workout summaries, lose backup data, and leave HealthKit sessions running.

## Standards

- **Medium — Divergent Change:** [ActiveWorkoutView.swift:176](</Users/ericlee06/orca/projects/Health App/WorkoutTracker/Features/ActiveWorkout/ActiveWorkoutView.swift:176>) owns UI presentation, HealthKit lifecycle, summary persistence, settings lookup, and the heart-rate rest state machine. The missed templated teardown and background-only rest evaluation are direct consequences. **Implicates D41, D43, D44.**

- **Medium — Primitive Obsession/Data Clump:** [Models.swift:280](</Users/ericlee06/orca/projects/Health App/WorkoutTracker/Domain/Models.swift:280>) stores average, maximum, calories, and an untyped `[Int]` zone array without the maximum-heart-rate provenance that gives the zones meaning. The finish screen consequently cannot comply with D45. **Implicates D44, D45.**

No separate hard coding-standard violation was found beyond the behavioral defects below.

## Spec

### 1. Invented or overconfident numbers

#### Finding 1.1 — Estimated zones become unmarked facts

**Severity: high**

[Models.swift:280](</Users/ericlee06/orca/projects/Health App/WorkoutTracker/Domain/Models.swift:280>) persists zone seconds but not whether the maximum was measured or estimated. [WorkoutFinishedSheet.swift:182](</Users/ericlee06/orca/projects/Health App/WorkoutTracker/Features/ActiveWorkout/WorkoutFinishedSheet.swift:182>) then renders ordinary “Time in zones / Zone 4” rows.

A workout zoned using `220−age` therefore becomes indistinguishable from one zoned against a measured maximum. The user sees estimated boundaries presented as historical fact.

**Implicates D45.**

#### Finding 1.2 — System calories are discarded when HR samples are absent

**Severity: medium**

[WorkoutSummary.swift:138](</Users/ericlee06/orca/projects/Health App/WorkoutTracker/Domain/WorkoutSummary.swift:138>) returns immediately when `vitals.isEmpty`, also discarding a non-nil system-generated `activeEnergyKilocalories`.

A session can show accumulated calories while running, then omit them from the finish summary solely because no heart-rate sample arrived.

**Implicates D44.**

#### Finding 1.3 — Long-workout summaries silently omit early samples

**Severity: medium**

[HeartRateMonitor.swift:80](</Users/ericlee06/orca/projects/Health App/WorkoutTracker/Domain/HeartRateMonitor.swift:80>) limits storage to 5,000 samples and deletes the oldest at [line 135](</Users/ericlee06/orca/projects/Health App/WorkoutTracker/Domain/HeartRateMonitor.swift:135>), but `vitals` at line 108 folds only the remaining array. The claimed separate aggregate does not exist.

For a sufficiently long or high-frequency session, average HR, max HR, and zone time describe only the tail of the workout while the screen presents them as whole-workout totals.

**Implicates D44.**

No production calorie formula was found: production calories originate in HealthKit. The fixture’s synthetic calorie counter is labeled test data.

### 2. The rest rule

#### Finding 2.1 — Missing or dead sensors do not degrade to the standard timer

**Severity: critical**

[RestTimer.swift:149](</Users/ericlee06/orca/projects/Health App/WorkoutTracker/Domain/RestTimer.swift:149>) always persists and schedules the heart-rate cap. When the pure rule returns `.degraded`, [ActiveWorkoutView.swift:273](</Users/ericlee06/orca/projects/Health App/WorkoutTracker/Features/ActiveWorkout/ActiveWorkoutView.swift:273>) deliberately does nothing.

The user therefore waits for the four-minute cap rather than their configured one/two-minute standard rest, and no screen says degradation occurred. This contradicts the promise shown in [ExerciseRestSettingsSheet.swift:73](</Users/ericlee06/orca/projects/Health App/WorkoutTracker/Features/ActiveWorkout/ExerciseRestSettingsSheet.swift:73>).

**Implicates D43, D13, D22.**

#### Finding 2.2 — Recovery cannot fire while the app remains backgrounded

**Severity: high**

Threshold evaluation is driven only by the SwiftUI timer at [ActiveWorkoutView.swift:186](</Users/ericlee06/orca/projects/Health App/WorkoutTracker/Features/ActiveWorkout/ActiveWorkoutView.swift:186>). The entitlement permits background delivery, but nothing evaluates arriving samples except this screen timer.

With the screen off, a valid recovery crossing is ignored and the pre-scheduled cap later tells the user their heart rate did not reach the target.

**Implicates D43.**

#### Finding 2.3 — An in-flight sample can cause contradictory alarms

**Severity: high**

[HeartRateRest.swift:84](</Users/ericlee06/orca/projects/Health App/WorkoutTracker/Domain/HeartRateRest.swift:84>) gives any sample timestamped before the deadline precedence over the cap, even if it is delivered after the cap notification has already fired. [RestTimer.swift:215](</Users/ericlee06/orca/projects/Health App/WorkoutTracker/Domain/RestTimer.swift:215>) then schedules a second recovery notification.

The user can receive “time is up—you did not recover” followed by “heart rate down—ready.”

**Implicates D43.**

No defect was found in the never-reaching-threshold cap path, exact-set un-completion cancellation, or the drop-set exclusion.

### 3. Source switching

#### Finding 3.1 — The Watch target cannot supply heart rate as configured

**Severity: critical**

The Watch build settings at [project.pbxproj:639](</Users/ericlee06/orca/projects/Health App/WorkoutTracker.xcodeproj/project.pbxproj:639>) contain Health usage strings but no HealthKit entitlements. The phone target has `CODE_SIGN_ENTITLEMENTS` at line 508; the Watch target does not. The phone target also has no Watch dependency or embed phase at [project.pbxproj:179](</Users/ericlee06/orca/projects/Health App/WorkoutTracker.xcodeproj/project.pbxproj:179>).

Consequently, the companion is not included by the normal phone build/install, and a separately installed Watch build lacks the entitlement needed to open its HealthKit session.

**Implicates D41.**

#### Finding 3.2 — Both sensors are included in summaries and rest decisions

**Severity: high**

[CompositeHeartRateProvider.swift:42](</Users/ericlee06/orca/projects/Health App/WorkoutTracker/Domain/CompositeHeartRateProvider.swift:42>) forwards every sample from both providers. [HeartRateMonitor.swift:108](</Users/ericlee06/orca/projects/Health App/WorkoutTracker/Domain/HeartRateMonitor.swift:108>) folds that raw interleaving into vitals, and [ActiveWorkoutView.swift:264](</Users/ericlee06/orca/projects/Health App/WorkoutTracker/Features/ActiveWorkout/ActiveWorkoutView.swift:264>) gives the same mixed array to the rest rule.

A lower-precedence AirPods reading can end rest while the Watch says the user is still above threshold, and both devices alter average HR and zone time. This is not “two sensors, one series.”

**Implicates D41, D43, D44.**

#### Finding 3.3 — The displayed BPM can be labeled as the wrong device

**Severity: high**

`current` selects by precedence at [HeartRateMonitor.swift:90](</Users/ericlee06/orca/projects/Health App/WorkoutTracker/Domain/HeartRateMonitor.swift:90>), but `ingest` sets state to whichever source arrived last at [line 133](</Users/ericlee06/orca/projects/Health App/WorkoutTracker/Domain/HeartRateMonitor.swift:133>). [HeartRateBar.swift:174](</Users/ericlee06/orca/projects/Health App/WorkoutTracker/Features/ActiveWorkout/HeartRateBar.swift:174>) labels the number from state rather than from `current.source`.

A Watch BPM can therefore be displayed beside “AirPods.” Separately, [HealthKitHeartRateProvider.swift:31](</Users/ericlee06/orca/projects/Health App/WorkoutTracker/Domain/HealthKitHeartRateProvider.swift:31>) hardcodes every phone-session GATT sample as AirPods, including chest straps or other monitors.

**Implicates D41.**

#### Finding 3.4 — Queued Watch samples can contaminate a later workout

**Severity: high**

[WatchLink.swift:34](</Users/ericlee06/orca/projects/Health App/WorkoutTrackerWatch/Shared/WatchLink.swift:34>) sends BPM and timestamp but no workout/session identifier. [WatchHeartRateProvider.swift:100](</Users/ericlee06/orca/projects/Health App/WorkoutTracker/Domain/WatchHeartRateProvider.swift:100>) accepts every delayed message into whichever monitor currently owns the delegate.

An out-of-range sample from workout A can arrive during workout B and be persisted in B’s average or maximum.

**Implicates D41, D44.**

#### Finding 3.5 — When every source is stale, precedence beats recency

**Severity: medium**

[HeartRate.swift:100](</Users/ericlee06/orca/projects/Health App/WorkoutTracker/Domain/HeartRate.swift:100>) falls back to all samples when none are fresh, then still chooses by source precedence.

A five-minute-old Watch value is displayed instead of a twenty-second-old AirPods value, despite the milestone specification calling for the latest stale sample with its age.

**Implicates D41.**

### 4. Lifecycle

#### Finding 4.1 — Templated finish never stops either workout session

**Severity: critical**

The ordinary finish calls `stopHeartRate()` at [ActiveWorkoutView.swift:331](</Users/ericlee06/orca/projects/Health App/WorkoutTracker/Features/ActiveWorkout/ActiveWorkoutView.swift:331>). The templated finish path at [line 335](</Users/ericlee06/orca/projects/Health App/WorkoutTracker/Features/ActiveWorkout/ActiveWorkoutView.swift:335>) finishes and dismisses without calling it.

The phone session may keep the sensor active, and the Watch never receives its `workoutActive = false` message. This is the exact battery-drain failure called out by the ticket.

**Implicates D41.**

#### Finding 4.2 — Minimize destroys lifecycle ownership and loses measurements

**Severity: high**

The monitor is screen-owned at [ActiveWorkoutView.swift:27](</Users/ericlee06/orca/projects/Health App/WorkoutTracker/Features/ActiveWorkout/ActiveWorkoutView.swift:27>), while minimize dismisses that screen at [line 216](</Users/ericlee06/orca/projects/Health App/WorkoutTracker/Features/ActiveWorkout/ActiveWorkoutView.swift:216>). Resume constructs a new view and provider. There is no `onDisappear` teardown or app-level handoff.

Pre-minimize samples and calories disappear from the eventual summary. Any session retained by HealthKit or the independent Watch becomes orphaned. The “finish current and start new” path in [StartWorkoutView.swift:148](</Users/ericlee06/orca/projects/Health App/WorkoutTracker/Features/Start/StartWorkoutView.swift:148>) auto-finishes the model without access to the old monitor, so it cannot send teardown.

**Implicates D41, D44.**

Plain finish and cancel call teardown. Keeping the session alive while an active workout merely backgrounds is correct; the background defect is the unevaluated D43 threshold, not failure to stop the workout.

### 5. Schema and export

#### Finding 5.1 — JSON silently drops new user configuration

**Severity: critical**

[ExportSnapshot.swift:82](</Users/ericlee06/orca/projects/Health App/WorkoutTracker/Domain/ExportSnapshot.swift:82>) omits `measuredMaxHeartRate` and `birthDate` from preferences. [ExportSnapshot.swift:264](</Users/ericlee06/orca/projects/Health App/WorkoutTracker/Domain/ExportSnapshot.swift:264>) omits rest mode, threshold, and cap. The collector confirms those omissions at [ExportCollector.swift:367](</Users/ericlee06/orca/projects/Health App/WorkoutTracker/Domain/ExportCollector.swift:367>).

Restoring the app’s only backup erases the user’s measured maximum, estimation basis, and every heart-rate rest configuration.

**Implicates D28–D30, D43, D45.**

#### Finding 5.2 — The migration fixture is not from the currently installed schema

**Severity: medium**

[LegacyStoreMigrationTests.swift:12](</Users/ericlee06/orca/projects/Health App/WorkoutTrackerTests/LegacyStoreMigrationTests.swift:12>) says the fixture came from commit `5239ef2`; [STATE.md:41](</Users/ericlee06/orca/projects/Health App/docs/STATE.md:41>) says the installed phone store is now the bar-weight build. The fixture has not changed since commit `33be96d`, despite the milestone acceptance criterion requiring regeneration from the installed commit.

The test opens an older approximation, not the exact store about to be migrated. A failure specific to the phone’s current metadata shape can therefore escape until installation.

**Implicates D39, D44.**

The implemented `schemaVersion == 4` and 34 CSV columns match `.scratch/milestone-3-export/spec.md`. No CSV ordering/count defect was found. The existing fixture does exercise the old `SetRecord.barWeightValue` and new Workout/AppPreferences defaults, but contains zero `ExerciseRestOverride` rows.

### 6. Reopened decision and stale source-of-truth

#### Finding 6.1 — SPEC and DECISIONS still contain false constraints and formats

**Severity: medium**

[SPEC.md:69](</Users/ericlee06/orca/projects/Health App/docs/SPEC.md:69>) still says iOS 17+, iPhone-only, and no HealthKit or Watch. Beyond the deliberately reopened phrase, the following are also false or incomplete:

- [SPEC.md:62](</Users/ericlee06/orca/projects/Health App/docs/SPEC.md:62>) describes only duration-based rest.
- [SPEC.md:81](</Users/ericlee06/orca/projects/Health App/docs/SPEC.md:81>) omits the persisted heart-rate summary.
- [SPEC.md:86](</Users/ericlee06/orca/projects/Health App/docs/SPEC.md:86>) omits birth date and measured max-HR preferences.
- [SPEC.md:94](</Users/ericlee06/orca/projects/Health App/docs/SPEC.md:94>) still specifies 31 CSV columns and schema version 3.
- [DECISIONS.md:75](</Users/ericlee06/orca/projects/Health App/docs/DECISIONS.md:75>) still lists Watch/HealthKit as post-v1.

Future work starting from the declared source of truth will target the wrong OS, architecture, schema, and export shape.

**Implicates D41–D45.**

The remaining guarantees—no backend, no accounts, no third-party runtime dependencies, and fully offline operation—remain true.

**Summary:** Standards axis: 2 medium design findings. Spec axis: 16 findings; worst are critical failures in D43 degradation, Watch target configuration, lifecycle teardown, and backup fidelity.
