# 10 — Start screen, second pass

Status: Codex clear after 2 rounds (codex-review-10, 10b); gates green; full UI suite before merge (result in STATE)

Skill: `.claude/skills/ios-design/`. The user, after the first pass on the phone: "it's ok, but I
still feel like the design is not there", the Start screen "seems a bit off".

## Step 1 — job, state, bold element

- **No live workout**: this screen exists so the user can start a workout in one tap; the eye
  lands on **Start Empty Workout**. Runner-up, demoted: the gym card — it is a picker, it shows a
  value, it reads as a row from now on.
- **Live workout minimised**: this screen exists so the user can get back into the workout in one
  tap; the eye lands on **Resume workout**. Demoted: Start Empty Workout steps down to a
  secondary button — two amber commands is the first pass's mistake.
- **Templates exist**: the job is unchanged; templates are a list the user scans, each row
  startable, none of them bold.

## Step 2 — three compositions (initial viewport, 390 × 844, default type)

Blocks: T = "Workout" title (chrome) · G = gym picker (value + disclosure) · H = Start Empty
Workout hero · R = Resume banner (live state only) · L = templates · N = New Template… · W =
week strip / last workout (NEW COPY — the user decides).

```
A · Hero at the thumb              B · Today at the eye                C · Hero at the eye
┌──────────────────┐               ┌──────────────────┐               ┌──────────────────┐
│ ⚙                │               │ ⚙                │               │ Iron Temple ▾   ⚙│  ← G in the nav bar
│ Workout          │               │ Workout          │               │ Workout          │
│ ⌖ Iron Temple lb ▾│  G, one row   │ M T W T F S S    │  W: 7 dots,   │ ┌──────────────┐ │
│ TEMPLATES         │  (label)      │ ● ● ○ ● ○ ○ ○    │  workouts     │ │ Start Empty  │ │  H, hero, top-leading
│ ┌──────────────┐ │               │ 3 workouts · Tue │  filled       │ │ Workout    ↗ │ │
│ │ ◐◐◐ Push     │ │  L: rows,     │ ┌──────────────┐ │               │ └──────────────┘ │
│ │ Bench · Fly… │ │  icons small, │ │ Start Empty  │ │  H, hero,     │ Templates        │
│ ├──────────────┤ │  tap = start  │ │ Workout    ↗ │ │  mid-screen   │ ┌──────┐┌──────┐ │  L: 2-col grid of
│ │ ◐◐ Legs      │ │               │ └──────────────┘ │               │ │◐◐◐  ││◐◐    │ │  small cards
│ │ Squat · RDL  │ │               │ ⌖ Iron Temple ▾  │  G, one row   │ │Push  ││Legs  │ │
│ └──────────────┘ │               │ Templates        │               │ └──────┘└──────┘ │
│ + New Template…  │  N, secondary │ ┌──────────────┐ │  L: rows      │ ┌──────┐         │
│                  │               │ │ ◐◐◐ Push     │ │               │ │ +New │         │  N as a grid tile
│ ┌──────────────┐ │               │ │ ◐◐ Legs      │ │               │ └──────┘         │
│ │ Start Empty  │ │  H, hero,     │ └──────────────┘ │               │                  │
│ │ Workout    ↗ │ │  thumb zone   │                  │               │                  │
│ └──────────────┘ │               │                  │               │                  │
│ [tab bar]        │               │ [tab bar]        │               │ [tab bar]        │
└──────────────────┘               └──────────────────┘               └──────────────────┘
Largest: H. Equal: L rows.         Largest: H. W is quiet grey.       Largest: H. L tiles equal.
Bold at the THUMB.                 Bold at the EYE (after W).         Bold at the EYE.
Live state: R replaces H at the    Live state: R replaces H; Start    Live state: R replaces H;
thumb; H → secondary above N.      → secondary under it.              H → secondary under R.
```

What each trades: A keeps the thumb on the action and the gym quiet, but the hero sits under a
scrolling list on a phone with many templates (it is pinned, not scrolled). B answers "what did I
do this week" at a glance — the first pass had no sense of today — at the price of two new
strings ("3 workouts · Tue", the day letters are not copy). C is closest to Strong and puts the
gym in the nav bar, which frees the whole screen for templates; the gym picker's value gets
smaller.

## Step 3 — mockups

Canvas: three direction artboards + the live-workout state for A. Static, in the app's tokens.
Canvas: https://claude.ai/code/artifact/bb03a175-d794-4824-8164-944181e30797 (working files in
`.scratch/ui-redesign/canvas/start/`; re-seed from them for any change).

## Round 2 — the user's pick (2026-09-11)

"I like the current format, but the Start Empty Workout button is too big and looks too mundane.
Keep the tab-bar icons as they are. For templates I like C's design." → Main = the current
structure (gear, title, gym card, action, templates) with the templates as C's two-column grid
(New Template… as a tile) and a smaller, sharper Start button — two treatments on the canvas:
an amber capsule with the figure in an ink disc, or an ink card whose only amber is the disc.
Live state: Resume takes the capsule; Start Empty Workout steps down to a grey button.

## Round 3 — the user's pick: the capsule (2026-09-11)

"I like the start button of the third artboard. Use that, and when in workout the Start Empty
Workout button should just switch to Resume workout." → ONE capsule (`HeroCapsuleLabel`): the
figure in an ink disc, the title, a trailing symbol; hugging, 56 pt. Idle: "Start Empty Workout"
(`startEmptyWorkout`, arrow). Live: "Resume workout" over the existing subtitle
("<gym> · N exercises"), a pulsing dot on the disc, a chevron (`resumeWorkout`). The separate
resume card is gone; Start does not appear while a workout is live (no test starts a workout
while one is live; a template start while live still meets the "already in progress" dialog).

## Step 1 — final

- Idle: the eye lands on the capsule, top-leading under the gym card; the gym card is a picker
  (value + disclosure, no accent title).
- Live: the same capsule reads Resume; nothing else is amber.

## Step 4 — tells

- Same container on everything: **absent** — the gym card (a picker with a value), the capsule
  (a command), the template tiles (a group: icons + name + exercises) and the New Template tile
  (fill, no border) are four roles with four treatments.
- A chip where a caption would do: **deliberate** — the one chip is the unit badge (`UnitChip`,
  its meaning everywhere).
- All-caps label: **absent** — "Templates" is the List's own section header.
- Middle dots: **deliberate** — the template's exercise line and the resume subtitle are the
  frozen strings.
- Accent on too many things: **absent** — the capsule only; the gym pin tile is amber-tinted at
  10 % as it was (a state of the picker, not a command) — reviewer to confirm.
- Equal blocks, none leading: **absent** — the capsule hugs; the gym card is full width but grey.
- Phone-sized website / dead space: **absent** — the grid fills the viewport; with no templates
  the New Template tile alone remains.
- Too much above the fold: **absent** — title, gym, action, templates.
- A control dressed as the command: **absent** — the gym picker keeps its chevrons, no accent.
- Survives only the default size: **absent** — `04-start-axl.png`: the capsule wraps to two lines
  inside its shape, the grid drops to one column, every string whole (the exercise line keeps
  its two-line limit).

## Verification (2026-09-11)

Built: `HeroCapsuleLabel` + `TemplateTile` + the grid in `StartWorkoutView.swift`; `MuscleIcon`
gains `size:` (24 in a tile). Gates on `ui-redesign-10-start` (first run, before the Codex
fixes): `CoreLoopUITests` 9/9, `HeartRateUITests` 5/5, `ExercisePresetUITests` 2/2,
`BarbellUITests` 2/2, `CodexScreenshotUITests` 3/3, captures test04_start +
test04_startTemplates (new) + test04_startLargeText — 24 tests, 23 passed in the first run (the first template capture failed on the
editor's lazy list with the keyboard up; the test now presses Return and scrolls until an option
exists). Screenshots `screenshots/10/` — sent to the user. Full suite: see STATE.

## Codex review 10 — response (2026-09-11)

`codex-review-10.md`: four P2s, one P3; the composition accepted ("keep the chosen composition
and fix the specific hierarchy, legibility and scaling failures").

- **P2, the gym picker's title stayed amber and its subtitle measured 3.4:1.** A `Menu` tints its
  label with the accent; the texts now carry `Theme.text` / `Theme.secondary` explicitly. The
  pin tile is the picker's context mark (Codex accepts it); it now scales with its glyph
  (`@ScaledMetric` 44 relative to `.title2`). At accessibility sizes the unit badge and chevrons
  stack under the text.
- **P2, the tile's exercise line truncated** ("Assisted P…", "Back…"). The two-line limit is
  gone; a tile grows with its exercises and the grid row takes the tallest tile.
- **P2, the scaled small muscle tile switched text style at AXL and its glyph outgrew the
  background; the capsule's ink disc was fixed at 40.** `MuscleIcon` picks the glyph's text style
  from the BASE size (`small`), never the scaled side; the capsule's disc is a `@ScaledMetric`
  relative to `.body`; the pulse dot is `.caption2`, not a point size (Codex item 5).
- **P2, the capture record**: `test04_startTemplates` no longer creates a gym, so it shows the
  same state as the AXL capture; the AXL test scrolls to New Template for a second shot
  (`04-start-axl-2`); new `test04_startLiveLargeText` captures the live state at AXL with
  `test04_start`'s fixture (`04-start-live-axl`).
- **P3, the counts** — corrected above (ExercisePreset has 2 tests; 24 in the set).
- Not changed: template Edit/Delete on the long-press menu (accepted); the grid (accepted);
  `.plain` buttons' press state (native).
- Also after round 1: the pulse dot is a `Circle` scaled with the disc, breathing by opacity
  unless Reduce Motion (no symbol point size); the AXL scroll capture scrolls unconditionally
  (a tile half under the tab bar counted as hittable).

Gates after the round-1 fixes: `CoreLoopUITests` 9/9, `HeartRateUITests` 5/5,
`ExercisePresetUITests` 2/2, `BarbellUITests` 2/2, `CodexScreenshotUITests` 3/3, the five
captures — 25/25; then the three touched captures again after the dot/scroll fix, 3/3.
Screenshots `screenshots/10/`: 04-start (live, default), 04-start-templates (idle, default),
04-start-axl + 04-start-axl-2 (idle, AXL, scrolled), 04-start-live-axl.

## Codex review 10b — response (2026-09-11)

`codex-review-10b.md`: **clear** — items 1, 6, 9 and 12 pass on the new captures (the gym
subtitle remeasured at 8.8:1); counts reconciled (21 gate tests + 4 capture tests = 25).
