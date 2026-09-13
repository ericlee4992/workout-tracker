# 12 — Muscle-family icons as muscle maps

Status: resolved — Codex clear after 2 rounds (codex-review-12, 12b); unit 11/11 gates (718-suite unchanged); full UI suite **66/66** on `efdaaef`; merged to main 2026-09-11

Skill: `.claude/skills/ios-design/`. The user, after ticket 11 on the phone: "The family icons
look inaccurate and mild. Can you design it better to actually reflect the families? Ask Codex
to design it as well with its new Image 2.5 and you design as well. Show me the designs." Then,
with two references: "how about making it more realistic like this and highlighting the muscle,
like these. I think it will be easier to see this way." Then: "Let's stick with codex's."

The design record is `work-record/ui-redesign/icons/brief.md` (the brief, both rounds, both
designers' files) and the canvas
https://claude.ai/code/artifact/0abc8068-6d95-497e-8cb8-1907790411b5 (Round 2 · muscle maps;
Round 1 · silhouettes). **Chosen: Codex's round-2 muscle maps** — a neutral body with the
family's muscle highlighted: pecs on a front torso, lats + traps on a back torso, the deltoid
caps, the bicep on a flexed arm, the quads on a pair of legs. Colours, Codex's (measured in its
README, all ≥ 5.4:1 on a 14 % tint over card): chest `#FF70B6`, back `#4EB9FF`,
shoulders `#4DE0D4`, arms `#B891FF`, legs `#84D65A`.

## Step 1 — job, state, bold element

Unchanged from tickets 10/11: on Start the eye lands on Start Empty Workout; on the template
detail the list is the eye's landing and Start the thumb's. The icons are decoration that says
which families a template trains; they are not the bold element on either screen.

## Step 2 — composition

Unchanged — ticket 10's Start wireframe (direction C's grid) and ticket 11's detail wireframe
are inherited as they stand: the tile's strip at 24 pt, the detail's strip at 40 pt, each icon
a rounded tile of the family colour at 16 % with the map filling 86 % of it (the proportion on
the board).

## Step 3 — mockups

The comparison canvas above — two rounds, two designers, on the tile and the detail; the user
chose. (Round 1: hand-drawn silhouettes vs image-model silhouettes; round 2: muscle maps.)

## Step 4 — tells

- Colour carries meaning: **deliberate** — the five family colours are fixed per family and
  appear nowhere else; the body is a sixth, neutral token (`MuscleBody`, `#5B6472`) that means
  "the rest of the body"; no amber.
- The accent on too many things: **absent**.
- Same container on everything: **absent** — the icon tile is the one shape the map sits in.
- Survives only the default size: **absent** — `@ScaledMetric` tiles as before;
  `04-template-detail-fixture-axl.png` wraps the strip 4 + 1 with the maps whole.
- Every other tell (containers, chips, all-caps, middle dots, equal blocks, dead space, above the
  fold, a control dressed as the command): **inherited unchanged from tickets 10 and 11** — this
  ticket changes the glyph inside the icon tile and nothing else on either screen.

## Build

- `Assets.xcassets/MuscleMaps/` (namespaced): `<family>-body` and `<family>-muscle` image sets,
  512 px single-scale PNG **template** images made from Codex's grey-body/red-muscle renders
  (`work-record/ui-redesign/icons/codex2/*.png`) by `work-record/ui-redesign/icons/make-muscle-map-assets.py`
  (codex-review-12: the recipe is the script — body alpha from luminance 18→70, muscle alpha
  from redness 25→90 inside the body, crop to the body's bbox at alpha > 0.5, square, 8 %
  margin, LANCZOS to 512; re-running it reproduces the committed PNGs byte for byte).
- `Colors/MuscleBody` `#5B6472`; `Theme.muscleBody`.
- `MuscleGroupStyle` keeps one colour per family and names the two layers; `MuscleIcon`
  stacks them, tinted, in the tile.
- `ThemeTests`: both layers of every family exist and are template images; the body colour exists.

## Gate tests — results (2026-09-11)

Unit: `ThemeTests` 2/2, `MuscleFamilyTests` 6/6, `TemplateFixtureTests` 3/3 — **11/11**. UI
captures 4/4: `test04_templateFixture` → `screenshots/12/04-start-fixture.png`,
`04-template-detail-fixture.png`; `test04_templateFixtureLargeText` → `04-start-fixture-axl.png`,
`04-template-detail-fixture-axl.png`, `-axl-2.png`; `test04_startTemplates` →
`04-start-templates.png`, `04-template-detail.png`; `test04_startLargeText` → `04-start-axl.png`,
`-axl-2.png`, `04-template-detail-axl.png`, `-axl-2.png`. Full UI suite on `efdaaef`: **66 tests, 0 failures** (65 + `test02_activeWorkoutLargeText`).

## Codex review 12 — response (2026-09-11)

`codex-review-12.md`: "no source or rendered-asset defect found"; items 1, 5, 9, 11 pass; the ten
muscle-on-tile pairs measured 5.3:1–8.8:1 at the 16 % tint; the body grey is decoration and needs
no floor (recorded as such — it is `accessibilityHidden` and the strip carries the family names);
single-scale 512 px template PNGs accepted; the flexed arm's lighter optical weight is the pose,
accepted. Two P3s, both record: the mask recipe is now the committed script above; the counts,
captures and inherited wireframes/tells are recorded above.
