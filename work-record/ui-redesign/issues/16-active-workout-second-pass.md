# 16 — Active workout, second pass

Status: in progress — directions on the canvas, awaiting the user's pick

Skill: `.claude/skills/ios-design/`. The user chose this screen next (2026-09-17). The first pass
(ticket 02, Codex's design) is what is on the phone. Known bug carried in: the rest bar's "Skip"
and "+15s" break mid-word at AccessibilityL (seen in ticket 11's captures).

## Step 1 — job, state, bold element

- **Logging** (exercises on screen, no rest running): this screen exists so the user can log the
  set they just did in one tap; the eye lands on the **current set row** — the first uncompleted
  set — and its complete control is the one amber command. Runners-up, demoted: the elapsed-time
  hero (a number nobody acts on mid-set → a quiet line), "Add Exercise" (an amber filled button
  today, competing with the set → secondary), the completion ring (a state, kept small).
- **Resting** (a rest is running): the job is to know when to lift again; the eye lands on the
  **rest countdown** at the thumb, the one live thing; Skip is its action. The current set row
  steps down (it is done).
- **Empty** (no exercise yet): the job is to add the first exercise; Add Exercise / Add by Machine
  are the bold element, once.
- **Keyboard up**: the fields being typed into must stay above the keyboard; the header collapses
  (kept from ticket 02).

## Step 2 — three compositions (initial viewport, 390 × 844, resting state, default type)

Blocks: N = nav (⌄ Cancel · title ✎ · Finish, chrome) · S = status line (gym · elapsed · sets) · H =
heart rate · E = exercise card(s) · R = the current set row · F = Add Exercise / Add by Machine ·
T = rest timer.

```
A · The set is the hero (keep the structure) B · One exercise at a time (pager)      C · Timeline (collapsed log)
┌──────────────────┐                        ┌──────────────────┐                     ┌──────────────────┐
│⌄ Cancel  Title✎ Finish│ N                 │⌄ Cancel  Title✎ Finish│ N              │⌄ Cancel  Title✎ Finish│ N
│ ⌖ Iron Temple · 12 min   ◔ 3/8 │ S, one   │ [1 Chest ✓][2 Lat…][+]│ exercise strip │ Iron Temple · 12 min · 3/8 │ S
│ ♥ 128 bpm  Zone 3  142 cal    │ H, strip │ ♥ 128 · Z3            │ H, pill        │ ♥ 128 · Zone 3          │ H
│ ┌──────────────┐ │                        │ Seated Chest Press    │ E: ONE card,   │ Seated Chest Press      │ E: sections,
│ │ Seated Chest Press ⋯ │ E, card          │ Chest Press · Insignia│ big            │  ① 60 lb × 10        ✓  │  done rows
│ │ ⚙ Chest Press · Insignia │             │ ① 60 × 10        ✓    │                │  ② [60] lb [10]     (●) │  R: current,
│ │ SET  PREV  WEIGHT REPS │               │ ② [60] lb [10]  (●)   │ R, large       │     ⏳ Rest 1:58  +15s Skip │  T INLINE
│ │ ① 60×10 ✓  (dim)      │                │ ③  —              ○   │                │  ③  — × —            ○  │
│ │ ② —  [60][lb][10] (●) │ R: highlighted │ + Add Set             │                │ Lat Pulldown            │
│ │ ③ —   —   —      ○    │                │                       │                │  ① — × —             ○  │
│ │ + Add Set             │                │                       │                │  ② …                    │
│ └──────────────┘ │                        │                       │                │ + Exercise · by Machine │ F, text
│ ┌ Lat Pulldown … ┐│ E (second card)       │ ◀ 1 of 2   Next ▶     │ pager          │                         │
│ [ Add Exercise ][ by Machine ] │ F, both grey │                    │                │                         │
│ (⏳ Rest 1:58   +15s  Skip)    │ T: amber capsule, thumb │ ⏳ Rest 1:58 +15s Skip │ T: amber band │                    │
└──────────────────┘                        └──────────────────┘                     └──────────────────┘
Largest: E. Bold: T while resting,           Largest: the one card. Bold: T, else R.   Largest: the log. Bold: T inline
else R's complete control. Amber: one.       Strip shows progress; no ring.            under the set just done; no bar.
```

What each trades: **A** keeps everything the user knows (cards, table, footer, pinned bar) and fixes
the hierarchy only — the hero number, the amber Add Exercise and the amber ring all step down so
the set and the rest are the only amber things; the rest capsule is the Start screen's capsule
shape, so it cannot wrap mid-word. **B** shows one exercise at a time with big rows — best
one-handed mid-set, but supersets (A/B alternating) and reordering (drag) lose their natural
home, and the strip is new chrome. **C** collapses done sets to one line so a long workout stays
short and the rest sits exactly where the set was completed — the most glanceable, but the
inline rest moves with the scroll and the columns header goes.

## Step 3 — mockups

Canvas: https://claude.ai/code/artifact/83323a4b-0e91-4830-9b2a-125d9ca3642b — working files in `work-record/ui-redesign/canvas/active/` (`build.py` → A, A without rest, B, C; `active-workout-directions.png` is the board). The user picks.

## Round 2 — the user's reaction, and Codex's directions (2026-09-17)

"Out of those, I just like current design the most. Can you also have Codex design as well, just
so I can compare?" → Codex designed two (`work-record/ui-redesign/canvas/active-codex/`, its
README with the trade-offs; prompt `codex-design-16-prompt.md`): **Codex A — familiar, quieter**
(the current cards and table; the elapsed hero becomes a caption, the ring a small neutral
indicator, Add Exercise/Add by Machine neutral; the current set's completion is the one amber
command; resting: the countdown at the thumb is the hero, Skip and +15s neutral in the timer
group — two rows at accessibility sizes, so no mid-word wrap) and **Codex B — the working row**
(no card walls; one enlarged current row in a continuous ledger). The canvas now has two pages
(Codex, Claude); the board `canvas/active/active-workout-comparison.png` puts the current screen
beside Codex A (logging, resting), Codex B and Claude A. Awaiting the pick.

## Round 3 — the revision (2026-09-17)

The user: "I like the design of Codex A, except for current set magnifying. I like the rest
timer of current. I also think it would be better if Codex A's time display is a bit bigger (but
not as much as current design). Redesign Codex A based on this feedback and show me." →
`canvas/active/CodexA2.dc.html` + `CodexA2Rest.dc.html` (from Codex's files, three edits): the
current row keeps its tint and its one amber tick but its fields are the same size as every
other row; the rest bar is the current one (the draining ring with the hourglass, "Rest" over
the time in `stat`, "+15s" secondary, "Skip" primary amber) in Codex's elevated card, with Codex's
two-row layout at accessibility sizes; the elapsed time is Title 2 bold in primary
(`12 min`), between Codex's caption and the old Large Title hero. Board:
`canvas/active/active-workout-revised.png`. Awaiting the user's yes.

## Round 4 — the user's decision (2026-09-17)

"Actually, lets just keep the current design. but just move the current timer next to gym name
(and also have timer include seconds), and make the total sets completed icon like the one in
Codex A. Redesign and show me." → the current screen stays; the header becomes ONE status
line: the gym chip, the running clock beside it in `stat` with seconds (`Format.elapsed`:
"12:34", "1:02:03" from an hour), and at the trailing end a small neutral ring (22 pt,
`Theme.secondary`) with "N/M sets" in a caption — Codex A's indicator. Gone: the Large Title
elapsed hero and the amber "N/M" chip. Everything else (the amber Add Exercise, the rest bar, the
cards, the ring's amber elsewhere) is untouched by the user's choice. A one-element restyle of
the header — built directly and shown as real captures (skill step 3's exception).

Step 1, restated for what changed — and the accepted exception (codex-review-16): the header's
prominence is reduced (no hero, no amber chip; the clock is a `stat` figure, the ring neutral).
What is bold on this screen is unchanged from the first pass and is NOT one thing: **Add
Exercise** is an amber filled command while logging, and **Skip** a second amber filled command
while resting; the completed set's amber is state. The user chose to keep both ("lets just keep
the current design"); this ticket records that as a deliberate exception to the one-dominant-
treatment rule, not as compliance.
Tells: the accent on too many things — **reduced** (one amber chip gone); a figure without a
glanceable job — the elapsed hero — **gone**; survives only the default size — the AXL capture.

Branch `ui-redesign-16-active-workout`; `FormatElapsedTests` (3); captures
`test02_activeWorkoutAndFinish`, `test02_activeWorkoutLargeText`.

## Built (2026-09-17)

- `ActiveWorkoutView.header`: one line — the gym chip, `Format.elapsed` in `stat` ticking every
  second (`TimelineView(.periodic(by: 1))`), a 22 pt `ProgressRing` in `Theme.secondary` with
  "N/M sets" in a caption. The keyboard-visible compaction is now just less padding.
- `RestTimerBar`: at accessibility sizes the two buttons take a row under the timer, equal
  widths — "+15s" and "Skip" no longer break mid-word (the ticket-02 bug).
- `Format.elapsed(seconds:)` + `FormatElapsedTests` 3/3.
- Captures `screenshots/16/`: `02-active-workout` (default, resting), `02-active-workout-axl`
  (the header at AXL: the chip wraps to two words, the clock whole, "1/2 sets" on two lines
  beside its ring; the stacked rest bar), `-axl-2` (the card), `03-finish-summary`. The user on
  the default capture: "looks good."

## Codex review 16 — response (2026-09-17)

`codex-review-16.md`: three P3s, no source defect; the header as requested, the rest wrap fixed,
item 11 pass, the clock's cost and skew handling fine, the hour format accepted.
- **VoiceOver heard whole minutes**: `Format.spokenElapsed` — "12 minutes 34 seconds",
  "1 hour 2 minutes 3 seconds" — is the clock's accessibility label (`FormatElapsedTests` 4/4).
- **The AXL record stopped at the header**: `test02_activeWorkoutLargeText` now shoots the top,
  the set rows (`-axl-2`) and the footer above the pinned rest bar (`-axl-3`, asserted by frame).
- **The hierarchy exception**: named above — Add Exercise (logging) and Skip (resting) are amber
  filled commands the user chose to keep; the completed set is state.

Gates on the branch: `FormatElapsedTests`, `CoreLoopUITests` 9, `HeartRateUITests` 5,
`BarbellUITests` 2, `WorkoutNameUITests` 2, `ExercisePresetUITests` 2, `DumbbellCounterpartUITests`,
`CodexScreenshotUITests` 3, three captures — **27 UI tests, 0 failures**; after the round-1 fixes,
`FormatElapsedTests` 4/4 and `test02_activeWorkoutLargeText` 1/1.
