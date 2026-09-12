# 12 — Muscle-family icons as muscle maps

Status: in progress (branch `ui-redesign-12-muscle-maps`)

Skill: `.claude/skills/ios-design/`. The user, after ticket 11 on the phone: "The family icons
look inaccurate and mild. Can you design it better to actually reflect the families? Ask Codex
to design it as well with its new Image 2.5 and you design as well. Show me the designs." Then,
with two references: "how about making it more realistic like this and highlighting the muscle,
like these. I think it will be easier to see this way." Then: "Let's stick with codex's."

The design record is `.scratch/ui-redesign/icons/brief.md` (the brief, both rounds, both
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

Unchanged: the tile's strip at 24 pt, the detail's strip at 40 pt, each icon a rounded tile of
the family colour at 16 % with the map filling 86 % of it (the proportion on the board).

## Step 3 — mockups

The comparison canvas above — two rounds, two designers, on the tile and the detail; the user
chose. (Round 1: hand-drawn silhouettes vs image-model silhouettes; round 2: muscle maps.)

## Step 4 — tells

- Colour carries meaning: **deliberate** — the five family colours are fixed per family and
  appear nowhere else; the body is a sixth, neutral token (`MuscleBody`, `#5B6472`) that means
  "the rest of the body"; no amber.
- The accent on too many things: **absent**.
- Same container on everything: **absent** — the icon tile is the one shape the map sits in.
- Survives only the default size: `@ScaledMetric` tiles as before; captures at AXL.

## Build

- `Assets.xcassets/MuscleMaps/` (namespaced): `<family>-body` and `<family>-muscle` image sets,
  512 px single-scale PNG **template** images made from Codex's grey-body/red-muscle renders
  (`.scratch/ui-redesign/icons/codex2/*.png`) by a soft luminance / redness split, each cropped
  to its body's bounding box and padded to a square (8 % margin) so the five share a scale.
- `Colors/MuscleBody` `#5B6472`; `Theme.muscleBody`.
- `MuscleGroupStyle` keeps one colour per family and names the two layers; `MuscleIcon`
  stacks them, tinted, in the tile.
- `ThemeTests`: both layers of every family exist and are template images; the body colour exists.

## Gate tests

Unit: `ThemeTests`, `MuscleFamilyTests`, `TemplateFixtureTests`. UI: the captures
`test04_templateFixture` + `test04_templateFixtureLargeText` (the tile and the detail at both
sizes, five families), `test04_startTemplates`, `test04_startLargeText`; then the full suite.
