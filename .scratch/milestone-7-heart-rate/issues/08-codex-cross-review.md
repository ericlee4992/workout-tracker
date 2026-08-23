# 08 — Codex cross-review (T6)

Status: resolved — two rounds run, criticals fixed, residue recorded
Blocked by: 01, 03, 05, 06, 07

**Explicitly requested by the user** ("make sure to cross review with Codex where needed"), and
required by T6 regardless: this work is reviewed by a different agent than the one that wrote it.
The `codex` CLI is on this machine (`codex-cli 0.147.0`, confirmed 2026-08-22).

Budget for **two rounds**. The scanner needed two, and both times the worst finding of the second
round was a defect introduced by the first round's fix (STATE, working agreements).

## What the review must attack

1. **Invented numbers.** The app's thesis is that it does not assert precision it lacks. Calories
   must come from the session, never from us; an estimated max HR must be marked everywhere it
   reaches a screen (D45); zones derived from an estimate must not read as measured fact.
2. **The rest rule's failure modes** (D43) — a threshold that never arrives, a sensor that drops
   mid-rest, a cap that fires while a sample is in flight, the app backgrounded throughout.
3. **Source switching.** Two sensors, one series: no double-counting, no frozen number when a
   source dies, and the screen never attributes a sample to the wrong device.
4. **Lifecycle.** A workout session that outlives its workout keeps a sensor running and drains
   the battery — the same class of bug as a rest notification that outlived its workout.
5. **The schema and the export.** New persisted fields must migrate the user's real store and must
   not silently vanish from the backup (D28–D32).
6. **The reopened decision.** D41 gave up a stated guarantee ("no HealthKit, no Watch"). Is
   anything else in SPEC now false as written?

## Acceptance criteria

- [ ] Review written to `.scratch/milestone-7-heart-rate/codex-review.md`, findings triaged
      critical/high/medium with the decision each one implicates.
- [ ] Every critical fixed, or explicitly accepted in writing with a reason.
- [ ] **A second Codex pass over the fixes**, written to `codex-review-2.md`.
- [ ] `docs/DECISIONS.md` Reviews section updated — and this time it records a review that
      happened, unlike the 2026-08-22 bar-weight entry.


## Resolution (2026-08-22)

Two rounds, as budgeted. `codex-review.md` and `codex-review-2.md` are beside this file.
Regression tests: `WorkoutTrackerTests/CodexReviewRegressionTests.swift` (14) — one per finding.
Suite after fixes: **441 unit + 3 heart-rate UI tests green**, both schemes building.

**Round 1 — 16 findings, verdict "do not merge or install".** Four critical, all real, all fixed:

| # | Defect | Fix |
|---|---|---|
| 2.1 | `.degraded` did nothing, on my false comment that the cap "was" the standard timer. A dead sensor silently doubled every rest | `RestTimerService.degradeToStandard` |
| 3.1 | The watch target had Health *usage strings* but no *entitlements* — its session could never open | `Config/WorkoutTrackerWatch.entitlements` |
| 4.1 | The templated finish never stopped the session — sensor left powered | teardown on both finish paths |
| 5.1 | The backup dropped the measured max, birth date, and every heart-rate rest config | exported, with a round-trip test |

**Round 2 — and this is why two rounds were budgeted.** Three criticals and four highs, and
**nearly every one was a regression introduced by round 1's own fix.** The project's stated lesson
(STATE, working agreements) held exactly:

- **#1** — my 2.3 fix still let an old sample report recovery after the cap alarm had fired, *and
  my regression test blessed it.* A test can enshrine a bug as thoroughly as code can.
- **#3** — having just fixed the backup dropping user config (5.1), I added
  `zonesFromEstimatedMax` and forgot to export it. The same defect class, one field later.
- **#6** — filtering vitals by `currentSource` meant whichever sensor was live when Finish was
  tapped owned the whole workout: one late Watch reading after two hours of AirPods produced a
  one-sample average. Now the **dominant** source (most samples) owns the summary; `currentSource`
  is only for the rest rule, which is a question about *now*.
- **#4** — degradation only ever shortened, so a 5:00 standard rest against a 4:00 cap never
  degraded at all; and it could schedule twice.
- **#7** — energy was copied only while ingesting a bpm, so a session that burned calories without
  reporting a heart rate persisted none of them.

## Owed, deliberately not fixed

- **Round 2 #2 — minimise.** The monitor is owned by the workout screen, and C1's minimise
  dismisses that screen. It now banks the vitals and ends the session rather than orphaning it,
  and the retain cycle through `onSample` is broken — but **resuming starts a new session whose
  summary replaces rather than extends what was banked.** The real fix is app-level ownership of
  the monitor, which is a refactor, not a patch.
- **Round 1 5.2 — the migration fixture is stale.** It was generated at `5239ef2`; the phone now
  runs the bar-weight build. Regenerating needs the phone.
- Everything hardware: no optical sensor and no `WCSession` pairing exists in any simulator.
