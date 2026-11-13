# 03 — The chart from a live workout, by machine

Type: feature
Status: **in progress — built, captures for the user** (the user, 2026-11-13; ticket 1 of 2, before [N15](../../nutrition/issues/15-save-any-food.md))
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

## Design (ios-design steps 1–4, 2026-11-13)

**Job, state, bold element.** Opened from a live exercise, this screen exists so the user can see what they did last
time on this machine and how it is trending, with one tap to switch machines; the eye lands on the chart's selected-day
figure (the existing hero number). Runner-up, demoted in writing: "Last time" — first in reading order but set in row
type (no hero figure), so the screen keeps one dominant treatment.

**Wireframe (initial viewport, default size; scrolls on to records and sessions):**

```
[x]                                   ← Close (closeProgress)
Seated Chest Press                    ← title (largest text)
Last time               Fri, Nov 6    ← section header + date
┌────────────────────────────────────┐
│ Chest Press 2 · Iron Temple        │ ← panel: where; a fallback adds one note line
│ W 20 lb × 12     1 40 lb × 10      │ ← sets in two columns (one at AX sizes)
│ 2 45 lb × 8                        │
└────────────────────────────────────┘
(▤ Chest Press 2 · Iron Temple · 3 days ⌃⌄)   ← the selector capsule (chartVariationPicker)
[Best set | Volume | 1RM]
┌ 45 lb × 8              ↑ 13%  ──────┐ ← chart panel (largest block, the hero figure)
│ Fri, Nov 6        Since first session│
│ ~~~~~~~~ chart ~~~~~~~~             │
└────────────────────────────────────┘
```

**Decisions taken (the "To work out" list):**

- **What "Last time" shows:** the latest finished session in the entry's own context, by Previous performance's layers
  (`PerformanceHistory.layers`): this machine (or this free-weight tag) first; if none, the same model at another gym,
  noted "Same model at another gym"; then the exercise on any equipment, noted "Not on this machine" (a machine entry)
  or "Other equipment". Nothing anywhere: the section is absent and the chart's empty state speaks. It stays on the
  machine in use while the selector changes the chart — the selector picks what to chart; "Last time" answers what this
  exercise, as set up now, did last. The old sheet's per-layer record tables live on as the chart's records for the
  chosen machine (and its 1RM metric).
- **One control, not two:** the existing variation capsule is the machine selector. Its menu lists the machines first —
  "All machines", then each machine "name · gym · N days" — and the other variations (free weights, nothing recorded)
  after a divider. Presets and load types stay in the same list (a machine with a preset reads "Chest Press 2 · Iron
  Temple · Narrow grip"; All machines has one row per preset/load type).
- **All machines** pools only machine sets, per load type and preset (D36/D47), and is offered only when two or more
  machines have eligible history (with one it is that machine). It is never a ranked variation, so no chart anywhere
  opens on it by default and pins cannot hold it (a pin made from it would fall back to Most used; AddChartSheet never
  offers it). Under All machines each session row names its machine.
- **Machine identity:** machines are keyed by the snapshot machine id and named from the snapshot label and gym (D23), so
  a renamed machine keeps its logged name and a deleted machine's history still lists. The same model at two gyms is two
  machines (D1). History from before machines were recorded is "No equipment recorded", outside All machines.
- **Records** come from `RecordsMath` on the scoped sets: load type respected (assisted lower is better), warmups out.
- **Machine labels everywhere** now include the gym from the start ("Chest Press 2 · Iron Temple"), not only on a
  collision — the Exercises chart, History's chart and the Progress tab's Add chart list too.
- **Previous performance:** `PreviousPerformanceSheet` is removed; prefill and the PREVIOUS column are untouched
  (`PerformanceHistory`). No UI test read the sheet. The live-workout new-best band, which opened the sheet, opens the
  chart.
- Presented as a full-height sheet over the live workout (it keeps running); Close returns to it.

**Tells:** same container on everything — absent (panels for the two groups only; the selector is a capsule). Chip where
a caption would do — absent. All-caps labels — absent. Middle-dot metadata — deliberate: "name · gym" is the identity the
user asked for (D87) and the frozen stat style. Accent everywhere — absent (no new accent). Equal full-width blocks —
absent (the chart panel leads in size). Phone-sized website — absent. Above the fold — Last time + selector + chart fit
the first viewport at default. Control dressed as primary — absent (the capsule is a raised surface, not accent). Default-
size-only layout — Last time goes to one column at accessibility sizes; captures below.

**New or changed strings (the user's decision, ios-design copy policy):**

| Where | String |
|---|---|
| Chart section header | "Last time" |
| Last time fallback notes | "Same model at another gym", "Not on this machine", "Other equipment" |
| Selector row | "All machines" (+ " · N days", as every row) |
| Machine rows | now "Name · Gym · N days" (was "Name · N days" unless two collided) |
| The live card's chart button (VoiceOver) | "Progress" (was "Previous performance") |
| Last time set (VoiceOver) | "Set 1, 40 lb × 10" / "Warmup, 20 lb × 12" |

## Progress

- 2026-11-13 (Claude): implemented on the branch — `ProgressEquipment.anyMachine` and
  `ProgressSeriesMath.pooledMachineVariations` (Domain), machine labels with gym, `ProgressVariationKey.current(for:)`,
  `LastTimeSection`, the chart's grouped selector and pooled session machine names, the live card opening the chart;
  `PreviousPerformanceSheet` removed. Fixture `-uiTestDesignMachines`. Unit tests `ChartByMachineTests`; UI test
  `FloodlightLiveUITests.testLiveChartOpensOnTheMachineInUseAndSwitchesMachines` + captures `testCaptureLiveChart*`.
- Captures: the first UI run failed all four at "Last time leads the chart" — the section loaded in a `.task` on a
  view that is empty until it loads, so it never ran (the snapshot showed the chart on Chest Press 2 and no section).
  Fixed: the chart screen loads it on appear (`LastTimeSection.load`). The first captures then showed the panel's line
  with the catalog model ("Chest Press 2 · Life Fitness Insignia Series Chest Press · Iron Temple"); it now reads
  "Chest Press 2 · Iron Temple" (`PreviousPerformanceSnapshot.shortEquipmentLabel`).
- Captures in [`captures/03/`](../captures/03/): `live-fixes-03-chart-*` (first viewport; `-light-axl-2` scrolled),
  `-machines-*` (the selector open), `-all-machines-*` (All machines' sessions, each naming its machine) — light and
  dark at Default, light at AccessibilityL. Every string whole at both sizes; the hero figure is still the largest.

**Evidence (2026-11-13, Claude):**

```
Verified: Unit plan — 1355/1355 passed, exit 0, build/results/unit-03.xcresult (before the short-label fix);
          after it, PreviousPerformanceTests + ChartByMachineTests + ProgressSeriesTests — 36 passed, exit 0,
          build/results/unit-03b.xcresult
Verified: FloodlightLiveUITests testLiveChartOpensOnTheMachineInUseAndSwitchesMachines + testCaptureLiveChart{Light,
          Dark,LightAccessibility} — 4/4 passed, exit 0, build/results/ui-03.xcresult
Not verified: the Workout / HistoryProgress area plans (pending before merge); on a phone
Known flaky: none seen
```

## Comments
