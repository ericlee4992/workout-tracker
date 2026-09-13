The core issue is iOS suspension, not `.mixWithOthers`, signing, SwiftUI ownership, or the notification trigger.

Your present design is fundamentally unreliable: the audible cap alarm is evaluated only when a heart-rate sample reaches [`fresh.onSample`](/Users/ericlee06/orca/projects/Health%20App/WorkoutTracker/Domain/WorkoutHeartRateCoordinator.swift:71). On iPhone, `HKWorkoutSession` does not grant watchOS-style continuous background execution, and the inaudible audio loop is not a supported way to manufacture that execution.

## 1. Background audio and `.mixWithOthers`

`.mixWithOthers` is not the problem. It only controls whether your playback mixes with other audio; Apple explicitly supports it with `.playback`. It does not classify the app as an ineligible “secondary” client. [Apple’s playback category documentation](https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/playback) and [mixWithOthers documentation](https://developer.apple.com/documentation/avfaudio/avaudiosession/categoryoptions-swift.struct/mixwithothers) say exactly that.

The important distinction is:

- An active audio session alone grants no runtime.
- Legitimate ongoing playback using the `audio` background mode normally continues in the background.
- An inaudible loop used only to keep the process alive is not a supported use of background audio. Apple restricts background services to their intended purposes under [App Review Guideline 2.5.4](https://developer.apple.com/app-store/review/guidelines/), and iOS makes no guarantee that such a loop will keep receiving CPU indefinitely.

Your loop is effectively digital zero: ±1 in 16-bit PCM, multiplied by `player.volume = 0.01`, is approximately −130 dBFS. [`isPlaying == true`](/Users/ericlee06/orca/projects/Health%20App/WorkoutTracker/Domain/RestAlarmSound.swift:105) only describes player state; it is not evidence that iOS granted useful background runtime.

Even if the keep-alive were running, the beep itself is not pre-scheduled. The app must execute this chain at the deadline:

```text
HKLiveWorkoutBuilder callback
→ AsyncStream
→ HeartRateMonitor.onSample
→ soundRestAlarmIfDue()
→ AVAudioPlayer.play()
```

Breaking any link means no beep. The local notification avoids that entire chain because iOS owns its deadline.

So attempt 3 is fundamentally unsuitable for production. It may sometimes work as a private sideloading hack, but it is neither guaranteed nor App-Store-valid.

## 2. `HKWorkoutSession` background behavior on iPhone

`workout-processing` does not grant background execution on iPhone. Apple documents that mode as watchOS-only: “The app uses a workout session to track a user’s activity on Apple Watch.” See [Configuring background execution modes](https://developer.apple.com/documentation/xcode/configuring-background-execution-modes).

Therefore the claim in [`WorkoutTracker-Info.plist`](/Users/ericlee06/orca/projects/Health%20App/Config/WorkoutTracker-Info.plist:27) is incorrect. On an iOS target, that value does not turn an `HKWorkoutSession` into a continuous-execution assertion.

There is also a version mismatch worth making explicit: this repository already raised its deployment target to iOS 26 because iPhone workout sessions arrived there; see [`D42`](/Users/ericlee06/orca/projects/Health%20App/docs/DECISIONS.md:51). This is not an iOS 17 API path.

For iOS 26:

- HealthKit can continue managing the workout and external sensor collection.
- With the one-time locked-device consent, workout data may remain accessible while locked.
- HealthKit supports recovering the session after a crash.
- None of that promises continuous CPU execution for your app.

Apple’s WWDC25 iPhone workout session presentation specifically describes builder metrics as live “while your app is in the foreground,” recommends the builder delegate for foreground UI updates, and separately discusses locked-device access and session recovery. [WWDC25: Track workouts with HealthKit on iOS and iPadOS](https://developer.apple.com/videos/play/wwdc2025/322/).

Consequently, `HKLiveWorkoutBuilderDelegate` callbacks cannot be used as a guaranteed background clock. If your process is suspended, no Swift delegate callback executes.

For background HealthKit ingestion, the supported pattern is:

1. Install an `HKObserverQuery` at application launch.
2. Call `enableBackgroundDelivery(for: heartRateType, frequency: .immediate)`.
3. When HealthKit wakes the app, run an `HKAnchoredObjectQuery` to fetch changes.
4. Always call the observer completion handler promptly.

The anchored query itself cannot be registered for background delivery; the observer query is the wake mechanism. [Apple’s observer-query guidance](https://developer.apple.com/documentation/healthkit/executing-observer-queries) and [HealthKit query comparison](https://developer.apple.com/documentation/healthkit/reading-data-from-healthkit) make that distinction.

However, “immediate” is a requested maximum frequency, not a real-time deadline guarantee. Delivery is system-controlled and can be deferred. It is appropriate for catching up and opportunistic early-recovery detection, but not for guaranteeing a threshold alarm within one second.

## 3. Free account and Debug installation

There is no special free-account restriction that explains this symptom.

- Background audio is controlled through `UIBackgroundModes`, not a paid managed entitlement.
- Your HealthKit and background-delivery entitlements are signed into the binary.
- The repository records that the Personal Team successfully provisioned them.
- A Personal Team’s material constraint here is that the development profile expires after seven days. [Apple’s membership comparison](https://developer.apple.com/support/compare-memberships/) documents that limitation.

`devicectl` installation and Debug optimization do not inherently change suspension rules. The significant test difference is debugger attachment: an attached debugger can prevent normal suspension and produce misleadingly successful background tests. Apple DTS recommends launching from the Home Screen without the debugger when testing suspension. See [Apple’s background timer discussion](https://developer.apple.com/forums/thread/132078).

In this case the device failure without attachment is the behavior that matters.

Critical alerts are different: they require a special managed entitlement approved by Apple. A free Personal Team cannot simply add it; even paid membership only lets you request approval. A workout rest timer is unlikely to qualify as a critical health/safety alert. [Apple’s Critical Alerts documentation](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.usernotifications.critical-alerts/).

## 4. What actually works

There is no supported iOS API that guarantees arbitrary app-controlled media playback through AirPods at a future instant after the app has been suspended.

Use this hierarchy:

1. **For the known cap deadline on iOS 26: use AlarmKit.** Schedule it when rest starts; cancel/reschedule it for skip, recovery, and +15 seconds. AlarmKit is system-owned, survives suspension, supports timers and custom sounds, and bypasses Focus and silent mode after user authorization. It does not require paid membership. [AlarmKit scheduling documentation](https://developer.apple.com/documentation/alarmkit/scheduling-an-alarm-with-alarmkit).

2. **For iOS 17–18: keep the local notification.** Schedule at rest start and replace it on +15, exactly as the code already does in [`RestTimer.swift`](/Users/ericlee06/orca/projects/Health%20App/WorkoutTracker/Domain/RestTimer.swift:49).

3. **A custom notification sound does not fix AirPods routing.** It changes the waveform but still uses the system alert facility. The app cannot control whether the Bluetooth audio channel is opened. Apple DTS states there is no supported way to force notification sounds through Bluetooth headphones. [Apple DTS notification routing explanation](https://developer.apple.com/forums/thread/815591).

4. **Critical alerts do not fix routing either.** They bypass mute and Focus and permit a chosen volume, but remain system notification audio.

5. **Offer Announce Notifications as the no-paid AirPods option.** If the user enables Announce Notifications for this app, Siri can announce the notification through worn AirPods while the phone is locked. This is user-controlled and not guaranteed to be enabled, but it is supported. [Apple’s Announce Notifications guidance](https://support.apple.com/en-ca/guide/iphone/iph838fd6fd4/ios).

If media-route delivery is absolutely mandatory, the only supported AVAudioSession solution is for the app to be genuinely playing audible workout audio—music, coaching, a metronome, or similar—throughout the background interval. Then a cue can be scheduled on that already-running audio timeline. `.mixWithOthers` remains valid.

For a private one-user sideload only, you could start one continuous asset containing silence followed by the beep when the rest begins. That avoids needing app code at the deadline and is more likely to work than firing `AVAudioPlayer` later. But it is still silent-background-audio keep-alive behavior, can fail after interruptions or route changes, and does not solve background heart-rate recovery. `AVAudioPlayer.play(atTime:)` is a synchronization API, not a system alarm registration and does not promise to wake a suspended app.

The practical recommendation is therefore:

- Remove the inaudible keep-alive and the iOS `workout-processing` assumption.
- Schedule AlarmKit at the known cap immediately when rest begins.
- Cancel/reschedule on every user action.
- Treat observer-query heart-rate delivery as opportunistic for early recovery.
- Keep a notification fallback and direct the user to enable Announce Notifications for AirPods.

That is the supported architecture. A guaranteed arbitrary beep over AirPods, with no ongoing legitimate audio and while the iPhone app is suspended, is not an capability iOS exposes.
