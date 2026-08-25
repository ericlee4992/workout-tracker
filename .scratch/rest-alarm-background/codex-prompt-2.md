# Challenge your own conclusion: is this really hard?

You previously analysed why a private iPhone workout app cannot beep through
AirPods when backgrounded, and concluded: "There is no supported iOS API that
guarantees arbitrary app-controlled media playback through AirPods at a future
instant after the app has been suspended," recommending AlarmKit.

The user's reaction: **"I don't think this should be a complicated problem."**

They have a point worth taking seriously. Gym interval-timer apps — Seconds,
Interval Timer, countless Tabata apps — beep through headphones with the screen
off, routinely, and have done for a decade. They are not using AlarmKit (it is
iOS 26). So there IS a mechanism. What is it?

Re-examine with that in mind. Specifically:

## 1. The pre-rendered asset idea

The rest end time is KNOWN the moment the rest starts (e.g. 120s from now).
So: render ONE audio asset that is [silence for 120s][beep at full volume],
start playing it at rest start with `.playback` + `.mixWithOthers` and the
`audio` background mode.

At the deadline, NO app code needs to run — the beep is simply the next part of
a buffer that is already playing. That sidesteps the entire "app must execute at
the deadline" problem you correctly identified.

Does this work while backgrounded with the screen off? What actually breaks it?
Is this what interval-timer apps do?

## 2. Was attempt 3 broken for a mundane reason?

The failed keep-alive was:
- buffer of ±1 LSB samples (~-90 dBFS), about 2 seconds long
- `player.volume = 0.01`
- `numberOfLoops = -1`
- separate `AVAudioPlayer` created and played later for the beep

Candidate mundane explanations, please assess each:
- `volume = 0.01` on an already near-silent buffer — does iOS treat output that
  low as "not playing audio" and decline background runtime?
- Is a 2-second looping buffer too short to sustain background audio?
- Does the session need `setActive(true)` re-asserted after the app backgrounds?
- Does creating a NEW `AVAudioPlayer` while suspended fail, where reusing a
  pre-prepared one would not?
- Is `AVAudioPlayer` the wrong tool versus `AVAudioEngine` / `AVQueuePlayer`?

In other words: was the CONCEPT sound and the implementation wrong? A truly
silent keep-alive at NORMAL volume is the standard technique used by many timer
apps — is that the actual difference?

## 3. AlarmKit routing

Does AlarmKit audio route to Bluetooth headphones, or does it play on the system
alert route like a notification sound? If the latter, it fails for the same
reason the notification already fails, and recommending it would not solve the
user's stated problem. Be precise; do not assume.

## 4. Verdict

Rank the options by "simplest thing that will actually work on a sideloaded
single-user app on iOS 26.6". App Store review guidelines are NOT a constraint
here — this app will never be submitted. Reliability on one device is the only
criterion.

If your original conclusion stands, say so plainly and explain why interval
timer apps are not a counterexample. If it does not, say what you got wrong.
