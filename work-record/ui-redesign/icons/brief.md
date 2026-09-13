# Muscle-family icons — design brief (ticket 12, 2026-09-11)

The user, after ticket 11 on the phone: "The family icons look inaccurate and mild. Can you design
it better to actually reflect the families?" Two designs, one from Codex and one from Claude, shown
side by side; the user picks.

## What the icons are

Five muscle FAMILIES, shown only on a workout template (its tile at 24 pt and its detail at 40 pt),
one icon per family the template trains: **Chest, Back, Shoulders, Arms, Legs**. Today they are SF
Symbols (`figure.strengthtraining.traditional`, `figure.rower`, `figure.arms.open`, `dumbbell.fill`,
`figure.strengthtraining.functional`) in pastel tints (`#F4939C`, `#8ABCE5`, `#E6CF88`, `#C1A9EB`,
`#A5CF9A`) at 14 % on ink — "inaccurate" (a rower is not a back) and "mild" (pastel on dark).

## Constraints (from `.claude/skills/ios-design/SKILL.md` and D54)

- Dark only. Surfaces: background `#0B0D11`-ish ink, card `#151A21`-ish graphite (read the real
  values from `WorkoutTracker/Assets.xcassets/Colors/`). The one accent is amber `#FFB45E` — the
  icons must NOT be amber (amber means the action / the live thing).
- Each family keeps ONE fixed colour used for that meaning everywhere; the colours may be bolder
  than today's pastels, but each glyph-on-tile pair must measure ≥ 4.5:1 and the five must read as
  one set (same weight, same style, same optical size).
- The glyph must be legible at 24 pt (a 24 × 24 tile with ~14 pt of glyph) — a silhouette, not a
  drawing. Flat, single colour, no gradients, no outlines thinner than 2 pt at 40 pt.
- It must READ as the body part: a chest is pecs; a back is lats / a V-taper; shoulders are
  deltoid caps; arms is a flexed bicep; legs is a thigh / quad. A figure doing an exercise is what
  the user rejected.
- Deliverable: five square images at 1024 × 1024 on a transparent background, the glyph in white
  (or a single flat colour — the app tints it), named `chest.png`, `back.png`, `shoulders.png`,
  `arms.png`, `legs.png`, plus a `README.md` stating the proposed five colours (hex) and the
  reasoning in five lines. The app will render them as template images (single-colour masks) —
  so the silhouette's shape is the entire design.

## Delivered (2026-09-11 night)

- Canvas: https://claude.ai/code/artifact/0abc8068-6d95-497e-8cb8-1907790411b5 (working files in
  `work-record/ui-redesign/canvas/icons/`: `build-board.py` builds `Main.dc.html` from
  `icons/claude/*.svg` and `icons/codex/*.png`; `board.html` + `muscle-family-icons-board.png` are
  the same board as a plain page and a PNG via headless Chrome).
- Claude's set: `icons/claude/{chest,back,shoulders,arms,legs}.svg` — a torso with pec cut-lines,
  a back-view torso with spine and shoulder blades, a neck-and-caps block, a flexed arm, a pair of
  legs; one cut-line language across the five. Proposed colours (glyph on an 18 % tint of itself
  over card, all ≥ 4.8:1): chest #FF6B7A, back #4DA8FF, shoulders #2ED3BC, arms #B98CFF,
  legs #7FE06B.
- Codex's set: `icons/codex/*.png` (white on black; README with its colours and contrast) —
  paired pecs, a lat V, paired deltoid caps, a flexed bicep, a single quad; heavier masses, no
  interior lines. Colours: chest #FF70B6, back #4EB9FF, shoulders #4DE0D4, arms #B891FF,
  legs #84D65A.
- Not a build: nothing in the app changed. The user picks a set (or elements of each), then
  ticket 12 turns the chosen five into template-image assets (single-colour masks) and the
  colour table in `MuscleGroupStyle`.

## Round 2 — muscle maps (2026-09-11 night)

The user, with two references (`ref/muscle-map-lines.png`, `ref/muscle-map-flat.png`): "how
about making it more realistic like this and highlighting the muscle, like these. I think it
will be easier to see this way." → each icon is a neutral body (`#5B6472`) with the family's
muscle filled in the family colour: chest = pecs on a front torso; back = lats + traps on a back
torso; shoulders = deltoid caps; arms = the bicep on a flexed arm; legs = the quads on a pair of
legs. Two-layer assets (body mask + muscle mask) so the app tints each layer.
- Claude: `icons/claude2/*.svg` (two paths per icon, `BODY`/`MUSCLE` fill tokens; `build.py`
  regenerates + a sheet). Flat, simplified anatomy; reads at 24 pt.
- Codex: `icons/codex2/*.png` (grey body + red muscle on black, from its image model; README,
  validation.json). Split by colour into `canvas/icons/codex2-<family>-{body,muscle}.png`
  (`build-board2.py`). More detailed — segmented muscles like the flat reference.
- Board: canvas artboard "Round 2 · muscle maps" (round 1 kept as the second artboard);
  `muscle-maps-board.png` via headless Chrome (`board2.html`, masks inlined). Same canvas URL.
