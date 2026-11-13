# 03 — The chart from a live workout, by machine

Type: feature
Status: **approved — next** (the user, 2026-11-13; ticket 1 of 2, before [N15](../../nutrition/issues/15-save-any-food.md))
Implementer: Claude; Reviewer: Codex (a Paseo Codex agent in this workspace), to "clear".
Branch: `ericlee4992/workout-chart-machines` off `main` `7dc65b82` (Paseo workspace "Workout chart + save foods",
`~/.paseo/worktrees/1qmeipq9/workout-chart-machines`).
Decision: **D87** (1–2).

## The ask (the user, 2026-11-13)

"During workout if u press chart icon on exercise it takes u to the chart, and if it's machine exercise u can select
different machines for that exercise category to see different progresses."

## Today

The chart icon on a live exercise card (`ExerciseEntryCard.titleActions`, `look.previousPerformanceSymbol`) opens
`PreviousPerformanceSheet` (layers: this machine at this gym / same model at another gym / exercise-wide history, each
with records). The chart itself is `ExerciseProgressView` (Progress tab, an exercise's page, History, a machine's page);
its variation menu (`ProgressVariationKey`: load type, equipment, preset) can switch equipment kinds, not individual
machines.

## The user's choices (2026-11-13, D87)

1. **The chart icon opens the chart** over the workout (the workout keeps running), **with a short "Last time"
   section at the top** so nothing of Previous performance is lost (the user chose this over "chart only" and "keep
   both").
2. **On a machine exercise, a machine selector lists every machine this exercise was logged on (its name and gym)
   plus "All machines"**, opening on the machine in use now.

## To work out (before building — UI-first with captures, ios-design skill)

- What "Last time" shows (Previous performance's first layer: this machine here; then the same model elsewhere?), and
  how the selector combines with the existing variation menu (load type / preset) without two competing controls.
- Machine identity across history: frozen snapshots (D1/D11/D23) — a machine renamed or deleted; the same model at
  two gyms; history from before machines were recorded.
- Records per machine respect load type and exclude warmups (AGENTS data conventions).
- Keep Previous performance's prefill rules and accessibility identifiers the UI tests read, or move the tests with
  them (said here).

## Acceptance

1. During a workout, the exercise's chart icon opens its chart, "Last time" on top; closing returns to the workout.
2. A machine exercise offers each machine it was logged on (name · gym) and All machines; the chart and records follow
   the choice; it opens on the current machine.
3. Unit tests for the per-machine series; UI tests (fixture) for open/close and switching; captures at Default and
   AccessibilityL; Codex clear.

## Progress

Not started.

## Comments
