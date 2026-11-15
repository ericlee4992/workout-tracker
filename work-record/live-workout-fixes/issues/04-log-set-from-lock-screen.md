# 04 — Log a set from the Lock Screen (Live Activity)

Status: in progress (Claude implements, Codex reviews — T6); branch `ericlee4992/lock-screen-log-set`
Type: task

## The user's request (2026-11-15)

> next update is being able to log a [set] from live screen widget. build the mock and show me first

Research: [competitor gaps](../../research/2026-11-13-competitor-gaps.md) #3 "Lock Screen set confirm" (Hevy has it).

## Decided from the mock (the user, 2026-11-15)

Mock captures: `captures/04/mock-options-AB.png` (today, A, B), `captures/04/mock-A-now.png` (chosen).
- **Option A, revised:** once rest is over, the card shows the **current** set only — **"Now"** over its value
  (`110 lb × 8`) with a **Done ✓** pill; no PREVIOUS (the user: "just show the current set (not next or previous)").
  The footer keeps the gym, heart rate and sets. The Dynamic Island's expanded view the same ("Now", Done, no
  PREVIOUS). During a rest the card is unchanged (countdown, +15s / Skip, footer "Next · Set 3 · …").
- **Done logs the set as shown and starts the rest** — the same as the set's check in the workout: superset members
  rest only after the last member (D48), heart-rate rests as configured (D43). Changing the numbers stays in the app;
  no Done when the set has no value to log.
- The card keeps following the phone's Light/Dark appearance (the island is always black).

## Acceptance

- Done appears only in the ready phase with a loggable value; VoiceOver: "Log set 3, 110 lb × 8" (warmup / drop /
  failure named).
- Done logs **exactly the set the card showed, with the values it showed**: if the workout moved on (that set is done,
  deleted, no longer next, its values changed, the workout finished) nothing is logged and the card is refreshed.
- The same completion path as the in-app check (snapshot, memory, rest start / superset skip, notification, alarm,
  Watch), working from a minimised workout and a cold background launch.
- The card fits the 160 pt budget at every Dynamic Type size; Light/Dark captures; gallery tests updated.
- Unit tests for the stale/wrong-set guards and the shared completion path; UI: the gallery captures.

## Progress

(implementation next)
