Yes — this is substantially less complicated than my earlier conclusion implied. The pre-rendered asset is the best first solution.

The narrow statement about “arbitrary playback after suspension” remains true, but it does not describe this problem. You can start playback before suspension and put the deadline on the audio timeline itself.

## 1. Pre-rendered silence + beep

This should work with the screen locked and the app backgrounded:

1. Enable `UIBackgroundModes = audio`.
2. Configure `.playback` with `.mixWithOthers`.
3. Activate the session.
4. Strongly retain an `AVAudioPlayer`.
5. Immediately play one PCM asset containing `[inaudible audio for 120s][beep]`.

Apple explicitly says `.playback` with the audio background mode continues when the screen locks or the app backgrounds. `.mixWithOthers` is fully supported with that category. [Apple’s playback documentation](https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/playback), [mixing documentation](https://developer.apple.com/documentation/avfaudio/avaudiosession/categoryoptions-swift.struct/mixwithothers).

At 120 seconds, no timer fires, no Swift executes, and no new player starts. The already-running audio renderer simply reaches the beep samples. That is the crucial distinction I underweighted.

AirPods are the current media output route, so this audio follows them. Apple describes connected wireless headphones as causing ongoing media playback to continue privately through the new route. [Apple’s route-change documentation](https://developer.apple.com/documentation/avfaudio/responding-to-audio-route-changes).

What can still break it:

- A call, Siri, another nonmixable session, or another audio interruption stops the player.
- AirPods disconnect or change routes.
- The app crashes, is force-quit, or is terminated under memory pressure.
- The installed app’s built `Info.plist` does not actually contain the audio background mode.
- The player is not retained, or `play()` returns `false`.
- System media volume is zero. `player.volume = 1` is only relative to system output volume.
- `.mixWithOthers` does not duck music. A loud beep mixes over it; it does not automatically lower Spotify.

The current working tree already implements the right structure in [RestAlarmSound.swift:187](</Users/ericlee06/orca/projects/Health App/WorkoutTracker/Domain/RestAlarmSound.swift:187>) and [RestAlarmTone.swift:151](</Users/ericlee06/orca/projects/Health App/WorkoutTracker/Domain/RestAlarmTone.swift:151>).

One concrete weakness remains: after an interruption, [RestAlarmSound.swift:161](</Users/ericlee06/orca/projects/Health App/WorkoutTracker/Domain/RestAlarmSound.swift:161>) restarts `keepAlive`, but does not resume or rebuild `scheduled`. A phone call during the rest can therefore lose the queued beep. The handler should resume the scheduled player or regenerate it from the remaining deadline.

Do interval-timer apps do this? Their proprietary implementations are unknowable, but they use this general mechanism: ongoing background audio, an audio-render timeline, or an uninterrupted workout audio track. Seconds explicitly supports audio playing uninterrupted across an entire workout. [Seconds’ first-party audio documentation](https://www.intervaltimer.com/help/editors/audio?platform=ios). They are valid counterexamples to the broad claim that the task is impossible.

## 2. Attempt 3

The concept was sound. The implementation had more moving parts than necessary.

- `volume = 0.01`: There is no documented iOS threshold below which playback stops counting as playback. But ±1 LSB at `0.01` becomes about −130 dBFS and may quantize to digital zero downstream. Using ±1 LSB samples with `volume = 1` is prudent and is the most plausible candidate among those listed, but it is not a proven iOS rule. Apple only documents volume as a 0–1 multiplier. [AVAudioPlayer volume](https://developer.apple.com/documentation/avfaudio/avaudioplayer/volume).

- Two-second loop: Not a problem. Apple explicitly documents any negative `numberOfLoops` as continuous playback until stopped. [AVAudioPlayer loops](https://developer.apple.com/documentation/avfaudio/avaudioplayer/numberofloops).

- Reasserting `setActive(true)` on backgrounding: Not normally required. Activate before playback and leave it active while playback continues. Reactivation is necessary after an interruption or media-services reset—not merely because the scene entered the background.

- Creating a new player while suspended: Yes, that fails in the fundamental sense that none of the creation code executes. Pre-preparing that player does not help if some later code must call `play()`. If the keep-alive is genuinely working, however, the process remains eligible to execute and creating another player can work—it is merely less reliable than putting the beep on the existing timeline.

- `AVAudioPlayer` versus engine/queue: `AVAudioPlayer` is entirely appropriate for one pre-rendered PCM file. `AVAudioEngine` is useful for dynamically scheduled buffers and `AVQueuePlayer` for asset queues, but neither receives stronger background privileges. One `AVAudioPlayer` and one asset is simpler.

Apple does advise developers not to stream silence merely to prevent suspension. That is policy/design guidance, not documentation of an amplitude detector or a statement that silent playback cannot work. [Apple’s audio-session guidance](https://developer.apple.com/library/archive/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/AudioGuidelinesByAppType/AudioGuidelinesByAppType.html). App Review is irrelevant here.

So: a normal-volume, inaudible PCM track is worth using, but the bigger improvement is eliminating all deadline-time application code.

## 3. AlarmKit routing

My previous AlarmKit recommendation was too confident.

AlarmKit supplies system-managed alarm audio. The app chooses a default or custom `AlertSound`; it does not control an `AVAudioSession` or select an output route. AlarmKit alarms break through Silent mode and Focus and survive normal application suspension. [Apple’s AlarmKit session](https://developer.apple.com/videos/play/wwdc2025/230/), [AlarmKit documentation](https://developer.apple.com/documentation/AlarmKit/scheduling-an-alarm-with-alarmkit).

Apple does not publish an AlarmKit-specific AirPods-routing guarantee.

There is encouraging evidence: Apple documents native Clock alarms as playing through both the iPhone speaker and connected wired or wireless headphones. [Apple’s Clock alarm documentation](https://support.apple.com/en-ie/118444). AlarmKit is also explicitly a distinct alarm experience, not merely a time-sensitive notification.

But extending the Clock behavior to AlarmKit is still an inference. By contrast, Apple DTS explicitly says ordinary notification audio has no controllable or guaranteed Bluetooth routing. [Apple DTS on notification routing](https://developer.apple.com/forums/thread/815591).

Therefore:

- AlarmKit probably reaches both AirPods and the phone speaker.
- It is not documented to provide headphones-only playback.
- It should not be treated as solving this requirement until tested on the specific iPhone/AirPods pair.

## 4. Verdict

For this private, single-device iOS 26.6 app:

1. **One pre-rendered `[inaudible PCM][beep]` asset in a retained `AVAudioPlayer`.** Simplest direct solution and deterministic on the media/AirPods route under ordinary uninterrupted conditions.

2. **AlarmKit, after one-device routing verification.** If it reaches that pair of AirPods reliably, it is stronger against app termination and interruptions, but may also sound through the phone.

3. **A continuously running `AVAudioEngine` with pre-scheduled buffers.** Useful if the sequence is dynamic, but unnecessary complexity for one known deadline.

4. **Silent keep-alive plus a separately created beep player at the deadline.** Conceptually viable, but retains the deadline-execution dependency and has more failure points.

5. **Local notification sound.** It already failed the required route and offers no routing control.

So my original conclusion was technically narrow but practically wrong for this case. I treated “beep in 120 seconds” as future application work when it can instead be audio that starts now. The proposed pre-rendered asset is the straightforward mechanism to try first.
