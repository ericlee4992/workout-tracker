# Milestone 7 — Heart rate, calories, and the workout summary

Written 2026-08-22. Requested by the user as **a core feature**: live heart rate during a
workout from AirPods Pro 3 or Apple Watch, calories and zones on the workout screen, a rest timer
that ends on heart-rate recovery, and a summary screen when the workout finishes.

## This reopens a locked decision. Deliberately.

`docs/SPEC.md` — Technical direction — says: *"No backend, accounts, **HealthKit**, **Watch**, or
third-party runtime dependencies."* Every part of this milestone comes through HealthKit, and the
user chose to build the watchOS companion as well. Both halves of that sentence are being
reopened, at the owner's explicit request, and recorded as **D41**. `DECISIONS.md`'s preamble
requires exactly this: surface the conflict, don't drift from it.

What is *not* reopened: no backend, no accounts, no third-party runtime dependencies. The app
still runs offline and talks to nothing but the device it is on.

## What was verified before any of this was designed

Facts, established on 2026-08-22 rather than assumed — this is the part a later session should
not have to rediscover:

| Question | Answer | How it was established |
|---|---|---|
| Can the **free** Apple account sign HealthKit? | **Yes** — the auto-provisioned profile carries `com.apple.developer.healthkit`, `.access` **and** `.background-delivery` | Built the app against a probe entitlements file with a command-line `CODE_SIGN_ENTITLEMENTS` override and decoded `embedded.mobileprovision` |
| Does live HR on **iPhone** need iOS 26? | **Yes.** `HKWorkoutSession`'s iPhone initialiser, `HKLiveWorkoutBuilder` and `HKLiveWorkoutDataSource` are all `API_AVAILABLE(ios(26.0))` | Read the annotations in the iPhoneOS 26.5 SDK headers on this Mac |
| Is the user's phone on 26? | **26.6** (iPhone 15 Pro Max) | `devicectl` |
| Where does AirPods HR come from? | A workout session on the phone; HR arrives from a paired device speaking the **heart-rate GATT profile** | WWDC25 session 322, "Track workouts with HealthKit on iOS and iPadOS" |
| Who computes calories? | **The system does**, during the session — active energy and distance are "generated types" | Same session |
| Is Apple Watch a GATT HR peripheral to the phone? | **No.** Live Watch HR requires a watchOS app running its own session and streaming over `WCSession` | Same session (it names wearable monitors and Powerbeats Pro 2, never the Watch) |

The last row is why "add Apple Watch support" is a second app target rather than a checkbox.

## Shape

### Where heart rate comes from

Two independent sources, one screen:

1. **AirPods Pro 3 (or any GATT HR wearable)** — the phone runs the `HKWorkoutSession`. The
   session is what turns the sensor on; without it, AirPods do not measure.
2. **Apple Watch** — the companion watchOS app runs the session on the wrist and streams samples
   to the phone over `WCSession`. The phone shows them the same way.

Only one source is live at a time. When both are present the **Watch wins** — it is a
chest-adjacent optical sensor worn under load, and it is the one the user is more likely to
trust. The screen always says which source it is showing; an unattributed number invites the user
to trust a reading they cannot check.

### On the workout screen

A heart-rate bar above the exercise cards, live while a session runs:

```
♥ 138 bpm   Zone 3   ▮▮▮▯▯     282 cal      ⌚︎ Apple Watch
```

- **BPM** — the latest sample, with its age if it is stale (a number frozen at 138 while your
  heart is at 90 is worse than no number).
- **Zone** — 1–5, from max HR (below).
- **Calories** — active energy from the session's own accumulation, never computed by us.
- **Source** — AirPods, Watch, or "no sensor".

### Zones and max HR (the honesty rule)

Zones need a maximum heart rate, and 220−age is wrong by ±10–12 bpm at one standard deviation.
So: the user may enter a **measured** max in Settings. Until they do, zones are computed from
220−age and are **marked as estimated** everywhere they appear — the same device the app already
uses for converted weights (D9/D25's `≈`). A zone boundary presented as fact, when it came from a
formula about a population, is the same falseness this app exists to refuse.

Zones follow the standard 5-zone percentages of max HR: 50–60, 60–70, 70–80, 80–90, 90–100.

### Heart-rate rest timer (D43)

Per exercise, the rest timer is either **standard** (D13/D22 durations, unchanged) or
**heart-rate**: rest ends when HR drops below a user-set bpm, **or** when a max-wait cap expires,
whichever comes first.

The cap is not decoration. Without it, one bad sample, a dropped connection, or a genuinely brutal
set leaves the user waiting for an alarm that never comes — and the rest timer's whole job is to
be the thing you do not have to watch. When the cap fires rather than the threshold, the
notification **says so**, because "you recovered" and "time is up" are different facts.

A heart-rate rest with no live source degrades to the standard timer, and says it degraded.

### Workout summary (D44)

Finishing a workout shows a summary — the shape of Apple's, plus the thing Apple's cannot show:
**what you actually lifted**.

```
Thu, Aug 22 · Gold's Gym Gangnam
Workout Time 0:56:56     Active Calories 282 CAL
Total Volume 4,820 kg    Avg. Heart Rate 112 BPM
Max HR 159 BPM           Time in zones ▮▮▮▯▯

Exercises
  Seated Chest Press · Insignia #2      4 sets · 60 kg × 10 best
  Barbell Bench Press · 45 lb bar       3 sets · 135 lb × 5 best
```

It replaces the current `WorkoutFinishedSheet`, and keeps its A2 behaviour: a workout with nothing
logged is still discarded and still says so, rather than showing a summary of nothing.

## What is stored

Heart rate is **not** re-stored as our own sample table. HealthKit owns the samples; the workout
we save references them. What the app persists is the **summary** — average, max, time in zones,
active energy — on `Workout`, because a summary is what History renders and re-querying HealthKit
for a workout from six months ago to redraw one row is both slow and fragile.

This mirrors D23's reasoning one dimension over: the numbers History shows must not change
because a source changed its mind later.

## Testing without a heartbeat

The simulator has no heart rate, no AirPods, and no Watch — the same wall the camera hit (`STATE`
gotchas). So the heart-rate source is an injectable protocol with three implementations: the real
HealthKit one, a **fixture** one driven by a launch argument (`-uiTestHeartRate`) that replays a
scripted bpm series, and a preview one. Every rule in this milestone — zones, the rest threshold,
the cap, source switching, staleness — is pure logic over a sample stream, and is unit-tested
against that stream with no hardware in sight.

## Decisions this proposes

- **D41 — HealthKit and a watchOS companion are in scope**, reopening SPEC's "no HealthKit, no
  Watch". The rest of that sentence stands: no backend, no accounts, no third-party runtime
  dependencies, still fully offline.
- **D42 — Minimum iOS rises to 26.0**, because the iPhone workout-session API requires it and the
  app has exactly one user, on 26.6.
- **D43 — A heart-rate rest ends on threshold OR cap**, and the notification distinguishes them.
  With no live source it degrades to the standard timer and says so.
- **D44 — The finish summary is HealthKit's numbers plus the app's own**: what Apple can tell you
  (time, calories, HR) beside what only this app knows (volume, exercises, sets, PRs).
- **D45 — Estimated max HR is marked as estimated**, everywhere, until the user supplies a
  measured one.

## Sequencing

Each ticket is independently useful and independently testable:

1. `01` — Pure domain: zones, max-HR resolution, the rest rule, summary math. No HealthKit.
2. `02` — Project surgery: iOS 26 target, HealthKit entitlement + usage strings, watchOS target.
3. `03` — The iPhone workout session: start/stop, live HR, active energy, the injectable source.
4. `04` — The watchOS companion and `WCSession` streaming.
5. `05` — Workout-screen UI: the HR bar, zone, calories, source.
6. `06` — The heart-rate rest timer, wired to D43's rule and the existing notification path.
7. `07` — The finish summary screen.
8. `08` — Codex cross-review (T6), then fixes. **Requested explicitly by the user.**

Ticket 01 is the one that can be built and proven today with no hardware, no entitlements and no
new targets; it is also where every rule that can be got *wrong* lives.
