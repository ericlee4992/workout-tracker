# 16 — Progress tab: pinned exercise and cardio charts

Type: feature
Status: in progress — design approved, building (2026-10-17)
Blocked by: —
Ships with: [14 In-app "What's New"](14-whats-new.md) — the user wants this feature announced there (D62), so 14 is
built for the same build.
Implementer: Claude (design + build); Reviewer: Codex.
Branch: `ericlee4992/beta-16-progress-tab` off `main` `696a395`.
Spec: [SPEC](../../../docs/SPEC.md) → progress charts (per variation, milestone 9). Decision: D63.

## Request (the user, 2026-10-17)

"In the "Strong" app, you can select what progresses to view on the profile page (like select exercise and it shows
graph of its history). I want to add similar feature." Placement options offered: A History section, B a 5th Progress
tab, C a 5th Profile tab, D a Workout-tab card; Claude recommended A. **The user chose B: "Build a new 5th tab. I should
be able to choose which exercise progresses to display, and I should also be able to choose cardio as well."**

## Decisions (the user, 2026-10-17)

- **A 5th tab, "Progress"**, after Exercises. Settings stays behind the Workout tab's gear.
- **Pinned lifting cards, per variation:** when pinning an exercise done on several machines/weight kinds, the user
  picks one variation or **"Most used"** (follows the most-trained variation, as the full chart opens today). The same
  exercise may be pinned twice for two variations. The card names its machine/kind.
- **Default metrics:** lifting **Best set**; cardio **Distance**. Each card's metric can be changed.
- **Cardio cards per activity** (Outdoor Run, Rowing, …): distance, pace/speed, duration, average heart rate. Indoor or
  estimated distances are labelled as estimates (D9/D25 spirit: no false precision).
- **Pins are an app setting, not workout data** (Claude's proposal, stated to the user): stored outside the SwiftData
  store, so no store-format change, no Gate S, ticket 11 stays deferred. Consequence: a reinstall resets the pins; no
  workout data is affected.

## Scope

- Progress tab: pinned cards (a small chart, the latest value, the label), Edit (add, remove, reorder), an empty state
  that invites pinning; tapping a lifting card opens the existing `ExerciseProgressView` on that variation; tapping a
  cardio card opens a cardio progress view (new).
- Add flow: pick an exercise (or a cardio activity), then a variation (or Most used) and a metric.
- Reuses `Domain/ProgressSeries.swift` maths; cardio series maths in `Domain/` with unit tests (units as entered, D52;
  estimates flagged).
- Design per the ios-design skill: real Default and AccessibilityL captures, light and dark; shown to the user with
  sample data **before** wiring persistence (UI-first).
- Onboarding tour / sample world: check whether the tour needs a Progress stop (ticket 02).
- README (5 tabs, screenshots), SPEC, D63, What to Test note; the What's New entry with ticket 14.

## Acceptance

- [x] The user approves the design from captures/prototype ("yes, go ahead and build it", 2026-10-17; rounds 1–4).
- [x] Pin, unpin, reorder, change metric/variation; pins survive relaunch; a deleted exercise's pin disappears quietly (code; not a UI test).
- [x] Lifting cards match `ExerciseProgressView` for the same variation and metric; cardio maths unit-tested.
- [x] Targeted UI tests for the tab and the add flow; affected suites; Codex review clear (round 3, `codex-review-16c.md`).
- [ ] Shipped in a build with ticket 14's What's New announcing it.

## Comments

**Design step 1–3 (2026-10-17, Claude; ios-design skill).** Job: *with pins, this screen exists so the user can see
how their chosen lifts and cardio are trending at a glance and open one in one tap; the eye lands on the latest value
of the first pin. Empty: it exists to start pinning in one tap; the eye lands on Add Chart.* Three structures, built
as a tappable prototype on sample data (`Features/Progress/ProgressTabPrototype.swift`, the 5th tab on this branch;
Layout menu top-left; `PROTO_PROGRESS_LAYOUT`), captures in `work-record/public-beta/captures/16/`:

```
A Featured + list          B Chart cards             C Grid
[Progress          (+)]    [Progress          (+)]   [Progress          (+)]
[ Bench Press         ]    [ Bench Press         ]   [Bench     ][Chest    ]
[ 185 lb×5     ↑16%   ]    [ 185 lb×5      ↑16%  ]   [185 ~~~   ][140 ~~~  ]
[ ~~~~ big chart ~~~~ ]    [ ~~~ chart ~~~       ]   [Leg       ][Run      ]
Pinned                     [ Chest Press         ]   [360 ~~~   ][5.2 ~~~  ]
[▸Bench   ~~  185     ]    [ 140 lb×8      ↑17%  ]   [Rowing    ]
[ Chest   ~~  140     ]    [ ~~~ chart ~~~       ]
[ Leg     ~~  360     ]    ...one card per pin
[ Run     ~~  5.2 km  ]
```
A: one hero (the featured chart, top-leading); the pins are a list (rows, sparkline, latest value); tapping a row
features it; tapping the hero opens the full chart. B: a card per pin with its own chart — no hero; past three pins it
is a stack of equal blocks (the skill's "lists are lists" tell). C: Strong-like tiles; two columns at Default, one at
AccessibilityL; tiles of equal weight. Claude recommends **A**. Add flow (all three): + → sheet "Add Chart": Lifting |
Cardio, your logged exercises/activities → the exercise's machines (Most used first, each with its gym and days) and
Show (Best set / Volume / 1RM; cardio Distance / Pace / Time / Heart) → Add. **New strings for the user to approve:**
tab "Progress"; "Add Chart"; empty "No charts yet" / "Pin an exercise or a cardio activity to follow it here.";
"Pinned"; "Most used"; "Show"; "Exercises you've logged"; "Activities you've recorded"; "Estimated distance".
Prototype rough edges, not design: the featured chart's last date label is clipped; Add only closes the sheet.
Build: simulator `xcodebuild build` **BUILD SUCCEEDED**.

**Design round 2 (2026-10-17).** The user: "I like A's design, but I want it to be possible to pin multiple exercises,
including cardio. It should just display the charts row by row, and you should be able to keep adding. Also, I don't
see how you're designing the cardio progress." Prototype reworked: **every pin is A's chart panel** (title, variation ·
metric, the latest value as `bigNumber`, the change badge, a 132-pt chart with first/last dates), one under another,
lifting and cardio mixed; **+** and an "Add Chart" button under the last panel append; long-press a panel → Show
(change its metric), Move Up/Down, Remove from Progress. A lifting panel opens the existing `ExerciseProgressView`; a
cardio panel opens a **new cardio progress screen**: title + source (GPS / Estimated distance), pills Distance · Pace
(Speed for cycling) · Time · Heart, a panel with the hero value, the change since the first session and the chart,
then Bests (Longest distance, Fastest pace/average, Longest session) and Sessions (date; distance · time · pace · bpm).
Cardio rules in the design: **pace is drawn with faster UP** so every chart reads "up is better", and its badge says
"0:40 faster" rather than a signed percentage; heart rate has no better direction (no badge; the heart-rate colour;
"N of M sessions" when some lack it); estimated distances carry "≈" and one footnote line on the cardio screen. The
"lists are lists" tell is answered as **deliberate: the user's choice** (a chart per pin, unlimited pins). Captures:
`captures/16/round2/` (tab top/bottom, Outdoor Run distance/pace, Rowing light, tab AccessibilityL). Build: **BUILD
SUCCEEDED**. New strings since round 1: "Remove from Progress", "Move Up", "Move Down", "Bests", "Sessions",
"Longest distance", "Fastest pace", "Fastest average", "Longest session", "Longest", "Fastest", "New best" (existing),
"faster"/"slower", "bpm avg", "N of M sessions", "Distances here are estimates from your iPhone's motion sensors."

**Design round 3 (2026-10-17).** The user: "For cardio, just get rid of the "Heart View". i dont think its necessary.
Also, for indoor distances just get rid of estimate notes. And also for the charts, can you vertically shrink them just
a little bit? … But make sure you don't remove anything." Done: cardio metrics are **Distance · Pace (Speed for cycling)
· Time** (the per-session bpm stays in the Sessions rows); the estimate footnote is gone and indoor activities' source
label reads **"Indoor"** instead of "Estimated distance"; the **"≈" on estimated values stays** (the project's no-false-
precision rule; asked the user). Charts: tab panels 132 → **108 pt**, the cardio screen 190 → **160 pt**; every element
kept. AccessibilityL showed the four y-axis labels touching at 108 pt → at accessibility sizes the chart shows two y
labels and grows 1.25× (as `HeartRateRangeChart`). Captures `captures/16/round3/`. Build **BUILD SUCCEEDED**.

**Round 4 (2026-10-17).** The user: "get rid of small "≈" as well." Indoor/estimated cardio values show no "≈" (a
deliberate exception to the no-false-precision convention, the user's decision — record in D63). The lifting **1RM**
metric keeps its existing "≈" (an estimated one-rep max, as `ExerciseProgressView` shows it; not what was asked).
Capture `captures/16/round3/r4-rowing-no-approx.png`. Build **BUILD SUCCEEDED**.

**Approved and build plan (2026-10-17).** The user on keeping cardio and lifting in one list: Claude recommended one list
(the user orders it; a split hides half or adds headers; a filter can come later); the user: "yes, go ahead and build
it". D63 written. Build: `Domain/ProgressPins.swift` (pin model + UserDefaults store), `Domain/CardioProgress.swift`
(per-workout cardio sessions per activity, Distance/Pace/Speed/Time series, bests, change) with unit tests; the exercise
history read and metric formatting shared with `ExerciseProgressView` (no second copy); `Features/Progress/` (tab,
panel, cardio progress sheet, Add Chart sheet) replacing the prototype; `-uiTestDesignProgress` fixture (cardio sessions
+ preset pins; `-uiTestReset` clears pins unless `-uiTestKeepPins`); `FloodlightProgressUITests` (captures light/dark ×
Default/AXL; add/remove/reorder/relaunch flow). Then README/SPEC, Codex review, ticket 14.

**Built (2026-10-17, Claude).** `Domain/ProgressPins.swift` (pin model; JSON in UserDefaults `progressPins.v1`; unknown
activity decodes and is hidden; unreadable data = no pins), `Domain/CardioProgress.swift` (sessions = a finished
workout's segments of one activity combined; distance/pace (rowing per 500 m)/speed/time; new-best and change rules;
bests earliest-on-tie), `Domain/ExerciseHistory.swift` and `Features/History/LiftProgressValues.swift` — the history
read and the metric numbers **moved out of `ExerciseProgressView`** (which now calls them; behaviour unchanged) so a
panel and the exercise chart share one implementation; `Features/Progress/` (`ProgressTabView`, `ProgressPanel` +
`ProgressPanelChart`, `CardioProgressView` sheet, `AddChartSheet`). Prototype removed. Fixture `-uiTestDesignProgress`
(5 runs, 3 rows, 4 pins); `-uiTestReset` clears pins unless `-uiTestKeepPins`; `-uiTestProgressNoPins`.
Changes found while building: the long-press "Show" options render **inline** (one tap) under a "Show" heading; a
`.accessibilityLabel("Metric")` on the cardio metric pills replaced each option's name for VoiceOver — removed (the
same modifier on `ExerciseProgressView`'s pills is pre-existing; noted for review, not changed); a variation label that
only repeats the exercise's name (a machine labelled "Leg Press") is left out of the panel and Add Chart subtitles.
Strings added beyond the approved list: the cardio subtitle "N sessions" (instead of "GPS"/"Indoor": the session count
is always true), "No cardio recorded yet", "No matches", "Machine"/"Equipment" headers, "Now <label>" under Most used,
"1RM · <day>" caption (as the exercise chart).
**Verified so far:** build **BUILD SUCCEEDED**; unit tests ProgressPinTests + CardioProgressMathTests +
ProgressSeriesTests **29 passed**; UI flows `testAddingLiftingAndCardioFromEmpty` and `testChangeMoveRemoveAndRelaunch`
**passed**; captures light/dark × Default/AXL + empty **passed** (`captures/16/final/`, 32 PNGs, looked at). Rerun of
the whole class after the subtitle change and the regression scope (full unit suite; ProgressChartUITests,
ProgressChartTooltipUITests, FloodlightTourUITests on WT-iPhone27 — the exercise chart was refactored and the tab bar
gained a tab) in progress.
**Design tells (ios-design step 4):** same container on everything — deliberate: one panel per pin is the user's
choice (round 2); chip where a caption would do — absent; all-caps labels — absent (NEW BEST is the existing badge);
middle-dot metadata — deliberate, the subtitle "equipment · metric" and session lines; accent overuse — absent (violet
only on the tab and the Add commit); equal-weight stacked blocks — deliberate (the user's choice, ordered by them);
phone-sized website — absent; above-the-fold overload — absent (first panel complete in the first viewport); control
dressed as primary — absent (Add Chart is secondary); default-size-only layout — absent (AXL captures: stacked header,
two y labels, 1.25× plot).

**Codex review round 1 — response.** Report [codex-review-16.md](../codex-review-16.md) (HEAD `d6c1f49`): **not clear**,
3 × P2; the extraction, pins, fixtures, cardio rules, captures and staged sheets confirmed. All taken: (#1) a session
keeps `measuredSeconds` — the active time of only the segments with a distance — and pace/speed divide the distance by
that, so a measured 2 km/10 min plus an unmeasured 10 min reads 5:00 /km (time still 20 min; distance what was
measured); new test `paceAndSpeedUseOnlyTheTimeThatMeasuredTheDistance` (run and cycling). (#2) the tab reads
`ExerciseEntry` once with the history (on appear / after sheets) and takes the display unit from its `AppPreferences`
query (`LiftProgressValues.displayUnit(preferences:)`); Add Chart reads entries once on open, precomputes each row's
summary, and the variation page computes its ranking and labels once from the entries it is handed — no fetch while
rendering or typing. (#3) pin changes animate only without Reduce Motion (`accessibilityReduceMotion` → no
animation). **Not exercised:** Reduce Motion at runtime — no test in the project switches it on (STATE already lists
it as never exercised); the code path is a single `withAnimation(nil)`. Unit: ProgressPinTests + CardioProgressMathTests
+ ProgressSeriesTests **30 passed** (exit 0); FloodlightProgressUITests **7 tests, 0 failures** (exit 0).

**Codex review round 2 — response.** Report [codex-review-16b.md](../codex-review-16b.md) (HEAD `399e1ad`): #2 and #3
resolved; **#1 partly** — the measured-time pace was still presented as the session's ("2.0 km · 20 min · 5:00 /km").
Taken the simpler way Codex offered: `measuredSeconds` replaced by `distanceIsComplete`; when any segment of the
session lacks a distance, its **pace and speed are unknown and not shown** — not in the session line, the Pace/Speed
chart, its change or the Fastest best. Its distance stays what was measured; its time all of it. Test
`aPartlyUnmeasuredSessionHasNoPaceOrSpeed` (run excluded from the pace points/change/bests; cycling speed nil). Unit
three suites **30 passed** (exit 0). No UI code changed; the UI fixture has no partly-unmeasured session, so the UI
class (7/7 at `399e1ad`) is not rerun for this domain-only change.

**Codex review round 3: clear.** [codex-review-16c.md](../codex-review-16c.md) (HEAD `1631714`): #1 resolved, no new
findings; Codex build exit 0, three unit suites 30 passed. Not exercised: Reduce Motion at runtime, the phone.
Remaining: ship with ticket 14 in build 7 (the user's go-ahead to merge and upload).

**Merged, not uploaded (2026-10-17).** The user: "Merge only" — `main` fast-forwarded to the 14 branch tip (16 + 14);
build 7 is not built or uploaded yet. **What to Test note approved for build 7** ("Use this note"): "Build 7 adds a Progress tab. Tap + or Add Chart to pin any lift or cardio activity — each chart shows your latest best and how far you've come. Long-press a chart to change what it shows, move it or remove it; tap it for the full chart. A short What's New page introduces it once after updating (Settings → What's New shows it again). Otherwise as before: send anything odd from Settings → Send Feedback."
