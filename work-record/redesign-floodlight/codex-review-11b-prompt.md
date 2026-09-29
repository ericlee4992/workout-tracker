Round 2 of the independent review (T6) of ticket 11 (Floodlight system surfaces and cleanup), same branch and
checkout. Range for this round: `18ce421..HEAD` (your round-1 report `codex-review-11.md` reviewed up to
`18ce421`). Read `issues/11-system.md` → "Codex review 11 — response (round 1)" and the round-2 verification,
then check each response against the code and tests:
1. H1: `WorkoutActivityCommands` now owns the coordinator and the card controller (RootView borrows them) and
   attaches the runtime before acting (`attachRuntime` → `coordinator.monitor(for:maxHeartRate:)`). Any path
   where the runtime is attached wrongly (a finished workout, a second workout, a workout already attached),
   any lifecycle change from moving the coordinator's ownership out of RootView (finish, discard, minimise,
   "finish it and start new"), and whether the tests prove the alarm/Watch/recorder side effects.
2. M2–M4: the cache key (superset grouping), `degradedRestSetID` and `lastRestResult` on the coordinator
   (who sets / clears them, across minimise, resume, a new rest, Skip on an expired rest), `refreshRest`
   recording the result before `currentState` clears it.
3. M5–M6: the card's height (type capped at Large, spacing, the gallery's ≤ 160 pt assertion) and the spoken
   marker.
4. L7–L8 and the other notes (the Skip test, the real test's bounds, the stable cardio clock start and
   `Cardio.activeSeconds(at:)`).
5. The cardio controls' new `CardioControlStyle` (the round-1 regression at AX found in `sys-ui-17/18`).
Do NOT run xcodebuild or simctl. Do not modify files other than the report. Report findings by severity with
file:line and a concrete failure case, or say "clear" in one paragraph. Write the report to
`work-record/redesign-floodlight/codex-review-11b.md`.
