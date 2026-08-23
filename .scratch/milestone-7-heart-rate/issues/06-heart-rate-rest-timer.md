# 06 — The heart-rate rest timer

Status: resolved (background firing still owed on a device)
Blocked by: 01, 03

D43, wired to the rest-timer machinery that already exists (D13/D22, `RestTimerService`).

## What to build

- Per exercise, a rest **mode**: standard (today's durations) or heart-rate. Stored beside the
  existing per-exercise rest overrides, and chosen in the same sheet — one place that owns "how
  this exercise rests".
- Heart-rate mode settings: threshold bpm, and a max-wait cap (default 4:00).
- Completing a set starts the rest; the rule from ticket 01 decides when it ends. The existing
  local notification fires, and **its text says which ended it** — recovered, or cap.
- D26 still holds: a drop set starts no rest, in either mode.
- No live source → degrade to the standard timer, and say so on screen.

## Acceptance criteria

- [ ] A scripted bpm series that recovers fires the alarm at the crossing sample, not at the cap.
- [ ] A series that never recovers fires at the cap, and the notification says the cap ended it.
- [ ] Un-completing the set that started the rest cancels it, including after relaunch (the
      existing `restStartedBySetID` behaviour must not regress).
- [ ] Backgrounded with the screen off, the alarm still fires — this is what
      `healthkit.background-delivery` was provisioned for; assert it rather than assume it.
- [ ] A drop set starts no rest in heart-rate mode either.
- [ ] Switching an exercise from heart-rate to standard mid-workout does not strand a running rest.


## Resolution (2026-08-22)

`ExerciseRestOverride` gained `restMode`, `heartRateThresholdBpm`, `heartRateCapSeconds` (all
optional — nil is `.standard`, which is what every exercise logged before today did).
`RestTimerService` gained `restPlan(for:)` and `finishRecovered(_:bpm:)`;
`ExerciseRestSettingsSheet` gained the mode picker and its two steppers.
Tests: `HeartRateRestTimerTests` (10). Suite: **409 unit tests green**.

The design decision that makes this robust: **a heart-rate rest is persisted as its cap.**
`restEndsAt` is set to now + cap, so the existing countdown, the existing notification, relaunch
recovery and the un-complete cancel all work unchanged. The threshold can only ever end a rest
*early*. That means a dead sensor, a killed app, or a relaunch degrades to exactly the standard
timer the user would otherwise have had — the failure mode is "you got a normal rest", not "no
alarm ever came".

`RestNotificationScheduling` gained `schedule(at:title:body:)` with a default implementation
forwarding to the old form, so existing test doubles kept compiling. The cap alarm says "Time is
up — your heart rate didn't reach the target"; the recovery alarm names the reading that ended it.
A test asserts the cap alarm does **not** claim a recovery it never saw.

**Still owed:** that the alarm fires with the app backgrounded and the screen off. That is what
`healthkit.background-delivery` was provisioned for, and it cannot be proven in the simulator —
it needs the phone, AirPods, and a real rest between real sets.
