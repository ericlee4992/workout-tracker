# 11 — Exercise icons off the rows; muscle-family icons on the template tile; a template detail

Status: resolved — Codex clear after 3 rounds (codex-review-11, 11b, 11c); unit 718/718; full UI suite 65/65 on `d9fd491`; merged to main 2026-09-11; the row caption "N sets · r, r, r reps" KEPT — the user, 2026-09-11: "keep it"

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

## Verification (2026-09-11 evening)

Built on `ui-redesign-11-icons-and-template-detail` (`6abc9e2`): `Domain/MuscleFamily.swift`,
`Supersets.memberLabels(groupIDs:)`, `TemplateTargets.summary`, `MuscleGroupStyle` keyed by
family + `MuscleFamilyStrip`, `Features/Start/WorkoutStartFlow.swift` (the start flow as a
modifier, so the pushed detail presents its own dialogs), `Features/Start/TemplateDetailView.swift`,
the tile and the three rows. Unit **715/715** (707 + 8 new: `MuscleFamilyTests` 6,
`TemplateTargetsSummaryTests` 1, `ThemeTests` rewritten to 2).

Gate run: `CoreLoopUITests` 9/9, `HeartRateUITests` 5/5, `ExercisePresetUITests` 2/2,
`BarbellUITests` 2/2, `CodexScreenshotUITests` 3/3, captures 5 — 26 tests, 24 passed; the two
new detail captures failed on `startTemplate`: an `accessibilityIdentifier` on the whole detail
screen was inherited by the capsule in the safe-area inset and replaced its own. Removed; both
captures then passed (2/2). Two more fixes from looking at the AXL capture: the rows showed
through the pinned capsule (a background-to-clear gradient behind the inset now), and the scrolled
capture had not scrolled (a row half under the capsule counts as hittable — scroll
unconditionally, ticket 10's lesson). Retaken: `04-template-detail`, `04-template-detail-axl`,
`04-template-detail-axl-2` (1/1, 1/1).

Screenshots `screenshots/11/`: 04-start-templates (tile: chest, back, legs for the five-exercise
fixture — Abdominal Crunch is Core, no family), 04-template-detail (default), 04-start-axl +
04-start-axl-2, 04-template-detail-axl + -axl-2 (scrolled, the list end clear of the capsule),
02-active-workout, 05-detail, 07-exercises (rows without icons).

## Codex review 11 — response (2026-09-11)

`codex-review-11.md`: two P2s, both review-gate findings; "no demonstrated functional regression".
Items 1–8 and 10 pass; the start-flow refactor verified (heart-rate banking before finish on
both paths; the two modifier instances cannot both fire for one tap); the family tiles measured
6.1:1–9.6:1; "Start" proven existing copy (`e608fa6^`, the template rows' button).

- **P2, the row caption needs the user's recorded decision (item 11).** DECIDED 2026-09-11 — the
  user: "keep it" (asked what it was, then kept it). Was OPEN — the user's call,
  reported with the ticket: "N sets · r, r, r reps" (a slot with no target reads "—"; with no
  targets, "N sets"; no slots, "No sets"). The alternative if declined: the set count alone
  ("3 sets", an existing editor string).
- **P2, the AXL evidence did not exercise the chip stack or the strip wrap, and the changed rows
  had no AXL pairs (items 9/12).** The editor cannot build a superset and five families need six
  exercises, so a launch-argument fixture now seeds one (`Domain/TemplateFixture.swift`,
  `-uiTestTemplate` + `-uiTestReset`; guarded like `ChartFixture`, unit-tested in
  `TemplateFixtureTests` — every name seeded, all five families, A/B on the first two,
  idempotent, never without the throwaway store). New captures `test04_templateFixture` +
  `test04_templateFixtureLargeText`: `04-start-fixture(-axl)`, `04-template-detail-fixture`,
  `-fixture-axl` (the strip wraps 4 + 1, the chip stacks over the name, the capsule holds),
  `-fixture-axl-2` (scrolled). AXL pairs for the rows: `codex-02-accessibility` (the workout
  card, `CodexScreenshotUITests/testAccessibilityWorkout`), `05-detail-axl` + `05-history-axl`
  (`test05_historyLargeText`), `07-exercises-axl` (`test07_exercisesLargeText`) — 5/5.
- Prompt discrepancies Codex caught: `templateDetail` and the spacer section were removed
  before the commit (the identifier hid `startTemplate`; the inset already clears the capsule) —
  the prompt described the working tree before those fixes.
- Judgement noted, not changed: the strip-to-list gap at the default size.

## Codex review 11b — response (2026-09-11)

`codex-review-11b.md`: items 9 (template detail, History, Exercises), 11 and the fixture guard
pass; one P2 left — the active workout's AXL capture came from a different fixture
(`CodexScreenshotUITests/testAccessibilityWorkout`: no gym, no set) than the default one. Added
`test02_activeWorkoutLargeText`: `test02_activeWorkoutAndFinish`'s exact steps at AccessibilityL
(Iron Temple, the Chest Press machine, 60 × 10 completed, a second set, the rest bar) —
`02-active-workout-axl` + `-axl-2` (scrolled to the entry card), 1/1. Pair:
`02-active-workout` ↔ `02-active-workout-axl(-2)`. Observed there, pre-existing and outside this
ticket: the rest bar's "Skip" and "+15s" break mid-word at AXL (ticket 02's bar, unchanged here).

Counts: unit **718/718** (715 + `TemplateFixtureTests` 3); the full UI suite on `d9fd491`:
**65 tests, 0 failures** (63 + the two fixture captures; the active-workout AXL capture test
was added after, 1/1 — the app is unchanged since `d9fd491`, only the test file and captures).
