# 11 — Exercise icons off the rows; muscle-family icons on the template tile; a template detail

Status: in progress (branch `ui-redesign-11-icons-and-template-detail`)

Skill: `.claude/skills/ios-design/`. The user, 2026-09-12, after ticket 10 on the phone:
"Currently there is an icon next to every exercise, but I want them gone. In workout too. They
don't match. But in template it should show an icon but only for muscle group (either chest,
back, arm, shoulder or leg), based on the exercises in the template. And also, when users click
template they should be able to view the list of exercises in the template."

Three asks, one ticket (they touch the same component and the same screen):

1. **No icon beside an exercise anywhere.** `ExerciseRow` (the exercise picker, the Add-by-Machine
   sheet, the Exercises tab), `ExerciseEntryCard` (the active workout), `WorkoutDetailView`
   (History). The body-area CAPTION on the picker rows stays — it is copy, and a filtered list
   still explains itself.
2. **The template tile's icons are muscle FAMILIES, not the 14 seeded groups.** Five families,
   each once, in a fixed head-to-toe order: Chest, Back, Shoulders, Arms, Legs. Mapping of the
   seeded vocabulary (`BodyArea.order`): Chest → Chest; Back → Back; Shoulders → Shoulders;
   Biceps, Triceps, Forearms → Arms; Quads, Hamstrings, Glutes, Hips, Calves → Legs.
   **Core, Neck and Full Body map to no family** (the user named five; a template of only
   crunches shows no icon — flagged for the user, easy to add a sixth).
3. **Tapping a template opens it** — its exercises as a list, with Start as the screen's one
   action. Edit/Delete stay on the tile's long-press menu; Edit is also in the detail's toolbar.

## Step 1 — job, state, bold element

- **Start, idle** (unchanged from ticket 10): the eye lands on **Start Empty Workout**; the
  template tiles are a group the user scans, none bold. A tile now OPENS the template instead of
  starting it — the tile's icons say which families the template trains.
- **Template detail**: this screen exists so the user can see what the template holds and start
  it in one tap; the eye lands on the **exercise list** (the content, top-leading); the bold
  element — the amber **Start** capsule — sits at the **thumb**, pinned above the tab bar so it
  is there however long the list is. Runner-up, demoted: Edit is a toolbar word, no accent fill.
- **Active workout / History / pickers**: the job is unchanged; the rows lose a decoration. The
  bold element of each screen was never the icon.

## Step 2 — compositions (390 × 844, default type)

```
Template tile (in the Start grid)        Template detail (pushed)
┌──────────────┐                         ┌────────────────────────────┐
│ ◐ ◐ ◐        │  family icons, ≤ 5,     │ ‹ Workout            Edit  │  chrome
│ Push Day     │  24 pt, one per family  │ Push Day                   │  large title
│ Bench · Fly… │  (was: one per exercise)│ ◐ ◐ ◐                      │  family icons, 40 pt
└──────────────┘                         │ ┌────────────────────────┐ │
                                         │ │ Seated Chest Press     │ │  L: exercise rows,
                                         │ │ 3 sets · 10, 10, 8 reps│ │  hairline separators,
                                         │ ├────────────────────────┤ │  one container
                                         │ │ Pec Fly                │ │
                                         │ │ 3 sets · 12, 12, 12 reps│ │
                                         │ ├────────────────────────┤ │
                                         │ │ Triceps Pushdown  [A]  │ │  superset chip as in
                                         │ │ 3 sets · 12, 12, 12 reps│ │  the workout
                                         │ └────────────────────────┘ │
                                         │                            │
                                         │   (● Start  ↗)             │  H: capsule, thumb,
                                         │ [tab bar]                  │  pinned (safeAreaInset)
                                         └────────────────────────────┘
Largest: the list. Bold: H at the THUMB. Icons: 40 pt, the row's former tile size.
```

Copy: the one new string is the row's caption, "N sets · r, r, r reps" (a frozen stat line in
the middle-dot pattern; the editor already shows the same numbers as fields). The capsule reads
"Start" (an existing string — the template rows' button before ticket 10) with the subtitle
"<gym> · N exercises" in the resume capsule's pattern. **The user decides the caption.**

## Step 3 — mockups

Skipped: the user specified the change (a one-element restyle of the rows, the tile's icon strip
reduced, and a list-plus-capsule detail in the shapes ticket 10 already chose). Captures at
step 6 are the picture the user reacts to.

## Step 4 — tells

- Same container on everything: **absent** — the detail is a plain list in one container under
  a bare icon strip; the capsule is the one command; no card.
- A chip where a caption would do: **deliberate** — the superset position chip, the same chip
  the workout uses for the same meaning; the set/rep line is a caption.
- All-caps label: **absent**.
- Middle dots: **deliberate** — the caption and the capsule subtitle are frozen stat lines.
- Accent on too many things: **absent** — the capsule only; the family icons wear the muscle
  colours (their meaning), not amber.
- Equal blocks, none leading: **absent** — the list is the largest block; the capsule hugs.
- Phone-sized website / dead space: **absent** — the list starts under the title.
- Too much above the fold: **absent** — title, icons, list.
- A control dressed as the command: **absent** — Edit is a toolbar word.
- Survives only the default size: **absent** — `04-template-detail-axl.png`: the icon strip
  wraps (`WrapLayout`), the caption wraps under the name, the capsule holds its two lines; the
  rows scroll under the pinned capsule and fade beneath it (a background-to-clear gradient
  behind the inset — at AXL the last row otherwise showed through the capsule, first capture).

## Gate tests

Unit: `MuscleFamilyTests` (new). UI: `CoreLoopUITests`, `HeartRateUITests`,
`ExercisePresetUITests`, `BarbellUITests`, `CodexScreenshotUITests`, plus the captures in
`RedesignScreenshotUITests`: `test04_startTemplates` (tile, then the detail: `04-start-templates`,
`04-template-detail`), `test04_startLargeText` (the same at AXL: `04-start-axl`,
`04-template-detail-axl`), `test02_activeWorkoutAndFinish` (the entry card without its icon),
`test05_history`, `test06_gymsAndExercises` (the rows without theirs). Then the full suite.
