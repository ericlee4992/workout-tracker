# Problem: rest alarm never sounds unless the app is on screen

iOS 17+ iPhone-only SwiftUI workout tracker. Real device: iPhone 15 Pro Max,
free Apple account, **Debug** configuration installed via `devicectl`.

## Symptom, reported three times by the user after three separate fix attempts

"The alarm only beeps when in the app. It doesn't work with screen off or when
I'm on another app, home screen, etc."

The beep works perfectly while the app is foregrounded and on screen.

## What the app is trying to do

During a workout the app runs an `HKWorkoutSession` + `HKLiveWorkoutBuilder`
(iOS, NOT watchOS) to read live heart rate from AirPods. A rest timer runs
between sets. When a rest ends the app must make an AUDIBLE sound in the user's
AirPods, including when the screen is off or the user is in another app.

A local notification (`UNTimeIntervalNotificationTrigger`, `sound = .default`)
already fires reliably in all states, but its sound plays on the phone's alert
route and the user does NOT hear it in their AirPods. That is why real audio
playback is required.

## Attempt 1 — play audio at alarm time

`AVAudioSession.setCategory(.playback, options: [.duckOthers, .mixWithOthers])`
+ `setActive(true)` + `AVAudioPlayer` at the moment the rest ends, then
deactivate. Result: worked in foreground only.

## Attempt 2 — add background modes

Added `UIBackgroundModes = [audio, workout-processing]` via a partial
`INFOPLIST_FILE` merged with `GENERATE_INFOPLIST_FILE=YES`. VERIFIED present in
the built app's `Info.plist` with `plutil -p`. Also moved alarm ownership off
the SwiftUI view (which is dismissed by a "minimise" feature) onto a long-lived
`@Observable` coordinator owned by the root view. Result: still foreground only.

## Attempt 3 — music-app style keep-alive

Session opened once at workout start and HELD:
`setCategory(.playback, mode: .default, options: [.mixWithOthers])`,
`setActive(true)`, plus an `AVAudioPlayer` looping an inaudible buffer
(`numberOfLoops = -1`, amplitude 1 LSB, `volume = 0.01`) for the whole workout,
intended to keep the process alive the way a music app does. Ducking applied by
swapping category options around the beep only. Interruption and route-change
observers restart the keep-alive. Result: STILL foreground only.

## Evidence gathered

- The app's process is present on device while backgrounded (`devicectl device
  info processes` shows it), but process presence does not prove execution —
  a suspended process still appears.
- The local notification fires with the screen off. This was mistakenly read for
  two days as proof the app was executing in the background. It is not: the
  trigger is registered with the system in advance and fires regardless.
- Live heart rate works correctly in the foreground.

## The specific questions

1. Why would a `.playback` session with an actively looping `AVAudioPlayer` and
   the `audio` background mode NOT keep an iOS app executing in the background?
   Is `.mixWithOthers` the problem — does it make the app a "secondary" audio
   client that iOS declines to grant background execution to?
2. Does `HKWorkoutSession` on **iOS** (not watchOS) actually grant continuous
   background runtime with `workout-processing`, and if so, do
   `HKLiveWorkoutBuilder` delegate callbacks (`workoutBuilder(_:didCollectDataOf:)`)
   keep firing while backgrounded? If they do not, what is the supported way to
   receive heart-rate samples in the background — `HKAnchoredObjectQuery` with
   `enableBackgroundDelivery`? The app HAS the
   `com.apple.developer.healthkit.background-delivery` entitlement, signed in.
3. Is a free (non-paid) Apple developer account restricted in a way that denies
   background audio or background HealthKit delivery on a Debug build installed
   via `devicectl`? Could Xcode's Debug attach/lifecycle differ from a normally
   launched app in a way that changes background behaviour?
4. Given the goal — a sound in Bluetooth headphones at an arbitrary moment while
   the app is backgrounded — what is the approach that ACTUALLY works on iOS 17+?
   Consider: a notification with a custom sound file (does that route to AirPods?),
   a critical alert (needs a special entitlement — is it obtainable on a free
   account?), scheduling the audio ahead of time since the rest end time is known
   in advance, or something else.

Answer concretely with the mechanism and its constraints. Prefer a solution that
does not require a paid developer account. Say plainly if one of the attempts
above is fundamentally unworkable and why. If the right answer is "schedule it in
advance because the end time is known", say so — the rest end IS known the moment
the rest starts, though it can be cut short by heart-rate recovery or extended by
a +15s button.

Read these files for exact current state:
- `WorkoutTracker/Domain/RestAlarmSound.swift`
- `WorkoutTracker/Domain/RestAlarmTone.swift`
- `WorkoutTracker/Domain/WorkoutHeartRateCoordinator.swift`
- `WorkoutTracker/Domain/HealthKitHeartRateProvider.swift`
- `WorkoutTracker/Domain/RestTimer.swift`
- `Config/WorkoutTracker-Info.plist`
