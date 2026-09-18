# 02 — Cardio physical-device acceptance

Type: task
Status: open — physical evidence outstanding

Software merged via **b0a8de9**, product03ada3d; build,748 full units,13 final targeted units,
7 focused UI and79 full UI passed. [Implementation and review evidence](01-implementation.md).
These simulator results do not establish AirPods Pro3 distance delivery or locked-screen GPS.
Phone remains source4d70d7d, export schema9; cardio adds schema10. Follow current
[STATE](../../../docs/STATE.md) and [DEVELOPMENT](../../../docs/DEVELOPMENT.md) for fresh export,
raw backup, migration, signing, binary freshness and launch checks before an install.

## Acceptance work

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


Watch companion cardio remains outside this release. If HealthKit supplies no indoor distance,
record that result as unavailable with labelled phone-motion/manual fallback; do not call it
verified AirPods distance support. Record actual device/firmware and results here.
