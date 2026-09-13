# 04 — The watchOS companion and live streaming

Status: resolved (nothing on this ticket is verified on real hardware)
Blocked by: 02, 03

The half that doubled this milestone, and the only way to get **live** Watch heart rate: the Watch
is not a GATT peripheral to the phone (WWDC25 322), so it must run its own session and stream.

## What to build

- A minimal watchOS app: start/stop mirroring the phone's workout, an `HKWorkoutSession` on the
  wrist, and a single glanceable screen (bpm, zone, elapsed, rest countdown).
- `WCSession` streaming phone ↔ watch: samples up, workout state down. Use `sendMessage` while
  reachable and `transferUserInfo` as the queued fallback, so a wrist out of range degrades to
  late data rather than lost data.
- Source precedence (ticket 01): when both Watch and AirPods samples arrive, the **Watch wins**,
  and the screen names the source.
- The watch app must survive the phone locking, backgrounding, and going out of range.

## Acceptance criteria

- [ ] Samples reach the phone within ~2s while reachable; out of range they queue and arrive.
- [ ] Starting a workout on the phone starts the watch session, and Finish ends it on both.
- [ ] Killing the watch app mid-workout degrades the phone to AirPods (or to "no sensor") and says
      so, rather than freezing the last number forever.
- [ ] The phone never double-counts: two sources, one series.
- [ ] Watch app builds for `watchsimulator` in CI-shaped headless `xcodebuild`.

## Notes

**Cannot be fully proven in the simulator.** Paired watch simulators can run the app and exercise
`WCSession`, but not a real optical sensor. Treat simulator green as "the plumbing works", and put
the real verification in the gym-feedback list like the scanner's.


## Resolution (2026-08-22)

Phone side: `Domain/WatchHeartRateProvider.swift` (the `WCSession` receiver) and
`Domain/CompositeHeartRateProvider.swift` (two sensors, one feed). Watch side:
`WorkoutTrackerWatch/WatchWorkoutModel.swift` (its own `HKWorkoutSession`, streaming) and a
one-screen `WatchRootView`. Shared: `WatchLink.swift`, compiled into **both** targets so the wire
format cannot drift. Tests: `WatchLinkTests` (9). Suite: **427 unit tests green**; both schemes
build.

Decisions worth carrying:

- **The phone never asks for a sample.** The watch pushes when it has one. A request/response
  would add a round trip to a link that is already lossy, and there is nothing useful to do with
  a request that times out.
- **Active energy comes from the phone only** (`WatchHeartRateProvider.activeEnergyKilocalories`
  is always nil). Both sessions accumulate energy for the *same* workout, so carrying both would
  give two different totals for one number on screen. The composite takes the `max` of what is
  reported rather than the sum, so a source that starts late cannot make the total go backwards.
- **State precedence when the two disagree** is ordered by what the user can act on: live beats
  waiting; waiting beats any refusal (one working sensor makes the other's permission
  irrelevant — a user with AirPods reporting must not be told heart rate is off because they
  never authorised the watch); denied beats unavailable, because denied is fixable.
- **`combined` is `nonisolated`** — a pure function of its argument. Requiring the main actor to
  decide which of two states wins would have made the rule untestable without a running app.
- **Unrecognised messages are ignored, never guessed at.** The two apps are signed and installed
  separately and will be out of step eventually; a test covers a message from a "newer" version.

### Follow-up (2026-08-23): the rest mirror was dead code

The watch screen was written to show the phone's rest countdown, and for a day it showed nothing.
`WatchLink` carried a `restEndsAt` field, `WatchRootView` rendered it — and the only two messages
the phone ever sent were start and stop, both passing `restEndsAt: nil`. Every piece existed
except the one that populates it. Found by explaining the feature to the user, not by a test.

Fixed with a narrow `WatchRestBroadcasting` protocol rather than by widening `HeartRateProviding`:
a fixture, a preview and the HealthKit provider have no watch to talk to, and three
implementations carrying a method that means nothing to them is how a protocol rots. The composite
forwards to whichever source can reach a wrist; the coordinator exposes it; and the view mirrors
from a single `onChange(of: restEnd)` — so starting a rest, +15s, skipping, recovering, degrading
and un-completing are all covered without any of them knowing a watch exists.

Tests: `WatchRestMirrorTests` (4), including that the END of a rest is mirrored too — otherwise the
wrist counts down to a rest the phone has already finished.

## What is NOT proven, and cannot be here

Everything that touches hardware. No simulator has an optical sensor, and `WCSession` needs a
real pairing. Specifically unverified:

- that samples reach the phone within ~2s while reachable, or queue and arrive when not;
- that starting a workout on the phone starts the watch session, and Finish ends both;
- that killing the watch app mid-workout degrades the phone to AirPods rather than freezing;
- that the watch app survives the phone locking and going out of range.

The logic either side of that gap is tested; the gap itself needs a wrist. This belongs on the
gym-feedback list beside the scanner's, and it is the single largest untested surface in the
milestone.
