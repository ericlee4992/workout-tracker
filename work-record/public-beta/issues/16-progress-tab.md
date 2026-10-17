# 16 — Progress tab: pinned exercise and cardio charts

Type: feature
Status: in progress — design first (2026-10-17)
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

- [ ] The user approves the design from captures/prototype.
- [ ] Pin, unpin, reorder, change metric/variation; pins survive relaunch; a deleted exercise's pin disappears quietly.
- [ ] Lifting cards match `ExerciseProgressView` for the same variation and metric; cardio maths unit-tested.
- [ ] Targeted UI tests for the tab and the add flow; affected suites; Codex review clear.
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
