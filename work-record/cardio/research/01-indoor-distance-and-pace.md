# Cardio distance, pace, session boundaries and routes

Researched 2026-09-18 against Apple primary sources and installed Xcode 27.0 iPhoneOS27.0 SDK.
Base: `14982e7`, branch `ericlee4992/cardio-api-research`. Documentation research only: no app
source changes, build, simulator run, phone test or installation. User selected design B,
optional devices/manual fallback, indoor live distance/pace with supported hardware, and
outdoor runs/rides with GPS. The parent implementation ticket owns acceptance and progress.

## Conclusions

**Implement the public HealthKit distance pipeline now, but do not claim AirPods Pro 3 indoor
accuracy or successful delivery has been verified.** Apple confirms AirPods motion contributes
to distance on iPhone. Its public API documentation does not give a per-accessory/per-activity
matrix guaranteeing indoor distance or instantaneous pace to third-party apps. Actual live
builder samples are the capability signal; a connected heart-rate sensor alone is insufficient.

**One in-app workout can contain sequential lifting/cardio sections; use separate, correctly
typed HealthKit workouts for those sections.** Do not place arbitrary lifting and cardio types
under one `HKWorkoutActivity` hierarchy.

## Confirmed versus conditional capabilities

| Capability | Evidence and implementation consequence |
|---|---|
| iPhone live workout builder at iOS 26 floor | Confirmed by SDK availability and WWDC25. Create `.walking`/`.running` + `.indoor` configuration for treadmill segments, not a strength configuration with a cosmetic cardio screen. |
| AirPods Pro 3 heart rate in third-party apps | Confirmed by Apple support; requires relevant Health access and an active workout. Existing app HR evidence does not prove its new indoor distance path. |
| AirPods Pro 3 motion contributing to distance | Confirmed as an Apple product capability; public docs do not promise which indoor builder types arrive in this app, when phone stays on treadmill console, across firmware/OS versions. Device test required. |
| `distanceWalkingRunning` | Public cumulative quantity, meters; system records on iPhone and Watch. Collect for indoor walk/run and consume actual builder updates. Never sum the same distance again from pedometer/GPS. |
| `.runningSpeed` | Public speed quantity; automatic generation is documented for **outdoor Apple Watch runs**. Request/consume if delivered, but not a guaranteed indoor iPhone pace source. |
| `.walkingSpeed` | Mobility metric for steady flat-ground walking with phone near waist, typically 10–30 samples/day. Unsuitable as the assumed live treadmill pace feed. |
| `CMPedometer` | Public estimated walking/running distance and live pace, subject to availability/permission. A phone-motion fallback, not an API proving AirPods-derived distance. |
| Indoor cycle/row/elliptical/stepper | Correct workout types and HR/calorie collection are implementable. No primary source found guaranteeing automatic machine distance from AirPods or an HR strap. Keep manual distance; automatically accept distance only from an actually supported producer. Do not fabricate distance from HR. |
| Outdoor run/ride routes | Public Core Location + HealthKit route APIs; requires location authorization, appropriate background configuration and quality filtering. No wearable required for phone GPS. |

Sources: [WWDC25 workout API session](https://developer.apple.com/videos/play/wwdc2025/322/),
[AirPods guide](https://support.apple.com/guide/airpods/track-heart-rate-workouts-airpods-pro-3-dev1b40fb47d/web),
[walking/running distance](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/distancewalkingrunning),
[running speed](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/runningspeed),
[walking speed](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/walkingspeed),
[pedometer](https://developer.apple.com/documentation/coremotion/cmpedometer).

Apple's activity names include Indoor Walk, Indoor Run, Indoor Cycle, Indoor Rowing,
Elliptical, Stair Stepper, Mixed Cardio and HIIT. This is a naming reference, not a guarantee
that every activity has a meaningful distance metric.
[Apple workout types](https://support.apple.com/en-us/105089).

## Public API path and metric handling

The installed SDK root is
`/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS27.0.sdk`.
Header paths below are beneath `System/Library/Frameworks/`.

- `HealthKit.framework/Headers/HKWorkoutSession.h`: `init(healthStore:configuration:)` and
  `associatedWorkoutBuilder()` are iOS 26.0. `prepare()`, `startActivity(with:)`,
  `stopActivity(with:)`, `pause()`, `resume()` and `end()` are available at the floor.
- `HealthKit.framework/Headers/HKLiveWorkoutDataSource.h`: class/`typesToCollect` are iOS 26.0;
  configure with `init(healthStore:workoutConfiguration:)` and
  `enableCollection(for:predicate:)`. Membership in `typesToCollect` does **not** establish
  that the system generates that quantity on the connected devices.
- `HealthKit.framework/Headers/HKTypeIdentifiers.h`: `distanceWalkingRunning` and
  `distanceCycling` date to iOS 8, `distanceRowing` to iOS 18, `runningSpeed` to iOS 16,
  `walkingSpeed` to iOS 14. Type availability is not sensor availability.
- In `workoutBuilder(_:didCollectDataOf:)`, use `statistics(for:)`; cumulative distance uses
  `sumQuantity()` in meters. Track timestamp/freshness for live speed; missing is not zero.
  These public APIs are documented by [HKLiveWorkoutDataSource](https://developer.apple.com/documentation/healthkit/hkliveworkoutdatasource)
  and [HKLiveWorkoutBuilder](https://developer.apple.com/documentation/healthkit/hkliveworkoutbuilder).

Recommended app behavior (engineering choices, not Apple guarantees): derive **average pace**
from segment active seconds / positive distance, with min/km or min/mi formatting. For live
pace use fresh valid speed or a suitably smoothed distance delta over active time. Label which
pace is shown. Exclude pauses; reset delta baselines on resume/source switches; never bridge a
paused interval. A stale/missing stream should show unavailable pace while retaining distance.
Manual machine distance replaces the selected total; it is not added to sensor distance.

`CoreMotion.framework/Headers/CMPedometer.h` confirms `isDistanceAvailable()`,
`isPaceAvailable()`, `authorizationStatus()`, `startUpdates(from:withHandler:)`, `stopUpdates()`;
`CMPedometerData.distance` is meters and `currentPace` is seconds/meter, nullable. Data is
cumulative from the requested start. Background delivery may catch up on resume; it is not a
promise of continuous UI callbacks. `NSMotionUsageDescription` is required. Treat the fallback
as a separately identified source and rebase it at segment/pause boundaries. Do not implement
custom distance by integrating raw AirPods acceleration: `CMHeadphoneMotionManager` exposes
motion, not a documented calibrated distance service.
[Core Motion headphone API discussion](https://developer.apple.com/videos/play/wwdc2023/10179/).

## Mixed workouts and HealthKit ownership

Apple permits swim/cycle/run/transition activities under `.swimBikeRun`; other interval
workouts' activities must match their parent workout type. `beginNewActivity` exists and
updates sensor algorithms, but its existence does not remove this documented constraint.
[Dividing a workout](https://developer.apple.com/documentation/healthkit/dividing-a-healthkit-workout-into-activities).

Recommended architecture: one app session ID, ordered non-overlapping section intervals,
separate HealthKit session/builders for each activity run (including strength before/after
cardio), persisted HealthKit UUIDs, and a single combined in-app summary. At transition:
stop activity, wait for stopped, end collection, finish/save, end session, then create the next
configuration. A stopped session cannot restart (`HKWorkoutSession.h`). Serialize transitions,
handle failures without losing the in-app segment, and reject duplicate completion callbacks.
Use each builder's energy once; do not also write a whole-session workout or add both Watch
and iPhone calories. Watch-owned sessions should mirror to iPhone rather than create a second
primary collector. [WWDC25 lifecycle and Watch guidance](https://developer.apple.com/videos/play/wwdc2025/322/).

## Outdoor routes and background requirements

Use `CLLocationManager`, request When In Use with `NSLocationWhenInUseUsageDescription`, and
start updates while foregrounded. The established delegate path needs `UIBackgroundModes`
containing `location` plus `allowsBackgroundLocationUpdates = true`; the SDK explicitly says
setting that property without the mode is fatal. When In Use can continue an explicitly
started session with the visible location indicator; Always is not inherently required for
this flow. Modern async implementations instead use retained `CLBackgroundActivitySession`
and appropriate `CLServiceSession`; do not assume a HealthKit session alone configures GPS.
[Background updates](https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background),
[location manager background property](https://developer.apple.com/documentation/corelocation/cllocationmanager/allowsbackgroundlocationupdates).

Persist accepted route points incrementally. Reject invalid/negative accuracy, stale fixes,
unreasonable jumps; Apple's route guide recommends accuracy within 50 m and intervals of
3 s or less. Break the route across pause or signal loss instead of adding a straight-line
jump to distance. Stop GPS when the outdoor segment ends. If writing routes to HealthKit,
authorize workout/route types, insert points through `HKWorkoutRouteBuilder`, save the matching
workout, then `finishRoute(with:metadata:)`. A route attaches to only one workout. Reconcile
GPS versus builder distance with one selected source, not a sum.
[Creating a workout route](https://developer.apple.com/documentation/healthkit/creating-a-workout-route).

## Required real-device evidence before claiming completion

No real-device claims established in this research. Exercise the production path with AirPods
Pro 3 in indoor walk/run: phone carried and phone stationary on console, permissions accepted,
then denied/missing, pause/resume, screen locked, disconnect/reconnect. Record OS/firmware,
configuration, collected types, timestamped cumulative distance and pace inputs, and machine
comparison. Check Watch ownership separately. Prove transitions do not overlap/double-count,
and outdoor background GPS resumes without joining gaps. Simulator injections verify code,
not AirPods compatibility. If no indoor distance samples arrive, retain manual/phone-motion
fallback honestly and investigate the device/API limitation; do not relabel it as successful
AirPods support.
