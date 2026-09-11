# 10 — Start screen, second pass

Status: in design — three directions mocked for the user; nothing built

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
