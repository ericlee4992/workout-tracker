# Claude — proposals for consistent exercise animations (written before reading Codex's)

Context and constraints: `codex-proposals-prompt.md` (same brief Codex received), tickets 01–02.

## A. Code-drawn animated figure — "the Stacked figure" (recommended)

**How.** A flat 2D figure drawn by the app itself (SwiftUI `Canvas`), in the same style as the muscle-map silhouettes the
user chose. Each exercise is **data, not a video**: a short list of keyframes giving joint angles (trunk, hip, knee,
ankle, shoulder, elbow, wrist), a view (side or front), the equipment, and what the hands/feet hold. The app
interpolates between keyframes with easing and loops (e.g. 2 s down, 1 s up). The target muscles are tinted on the
figure with the **same muscle region shapes as the muscle map** — one piece of art serving both.

**Equipment.** Schematic line drawings: bench, barbell, dumbbells, kettlebell, cable stack and pulley, and a small set
of **machine archetypes** whose moving part follows the figure — seated lever press, pec deck, leg extension, lying /
seated / standing leg curl, pulldown, seated row, hack/pendulum/belt squat sled, calf raise, hip abduction/adduction,
back extension. Every gym's machine looks different anyway; a schematic shows the path of motion, which is what form
needs.

**Look.** Not Lyfta's photoreal 3D: clean, flat, on-brand (Floodlight colours, light/dark), crisp at any size.
**Coverage.** All 90, machines included, in one style; **custom exercises pick a movement pattern** (press, pull,
squat, hinge, curl, raise, fly, row …) and get a reasonable animation at once — something no media library offers.
**Cost.** $0 in money; engineering (the renderer, ~15 equipment drawings) and authoring 90 short pose files, which I
can do; the user reviews each one (a lifter's eye).
**Accuracy.** Deterministic and inspectable: a wrong elbow angle is a number to fix, never a hallucination.
**Licence.** Entirely ours. (Poses authored from biomechanics, not traced from anyone's drawings.)
**Offline / size.** Fully offline, a few KB per exercise, no downloads, no server, no Gate S (pose data ships with
the seed catalog, like today's `SeedCatalog.json`; user clips remain the only stored-format change).
**Accessibility.** Reduce Motion → a still start/end pair; VoiceOver gets the cues text.
**Where it lives.** `SeedCatalog.json` gains a `motion` key per exercise (pattern + keyframes); a domain type
`ExerciseMotion` (pure, unit-tested: interpolation, loop timing, joint limits); a `FigureView` in
`Features/Exercises/`.
**First experiment.** A tappable Simulator prototype (the user's preferred way to decide) with three exercises —
bench press (free weight), leg extension (machine), lat pulldown (cable) — on the exercise page and in the workout
pop-up, light/dark, default and AccessibilityL. If the machine one reads clearly, the approach holds.

## B. Same pose data, rendered 3D (later upgrade of A)

Feed A's keyframes to a scripted Blender rig (a plain mannequin, simple primitive machines) and render short loops
offline. More "3D", still consistent and ours; much more effort (modelling, rendering pipeline). Only worth it if A's
flat look disappoints. A's data is reused, so A is not wasted.

## C. Buy Gym visual (~$81 for 90 GIFs)

Fastest route to Lyfta's exact look, machines included, made by an anatomy artist with trainers. Files private:
uploaded to our R2, downloaded and cached on the phone (not in the public repo). Custom exercises get nothing (or A's
figure). Coexists with A: A as the universal fallback, Gym visual on top for seeded exercises if wanted.

## D. AI stills, not AI video

Generate only the **start and end poses** of one consistent character with an image model (far more reliable than
video), the user checks two stills per exercise, the app cross-fades them. Consistent look, machines possible, cheap;
but a cross-fade is not real motion, and machine stills can still be wrong. Weaker than A on accuracy and on custom
exercises.

## E. Commission a motion designer

A freelancer builds 90 vector loops to our style guide as work-for-hire (we own them). Probably $5–15 each
(~$450–1,350), weeks of turnaround, and new exercises need another commission. Delivered as video/APNG (no Lottie
runtime: no third-party code).

## F. AI video trial (as discussed)

Runway / Seedance / ElevenLabs-hosted models from one reference image; per-clip review; weak on machines. Keep as a
3-clip experiment only if A and C are both rejected.

## Ranking

1. **A** — the only option that is free, consistent, covers machines and custom exercises, offline, and matches the
   chosen muscle-map style. Risk: the flat look must please the user → prove with the 3-exercise prototype first.
2. **C** — if the user wants photoreal 3D now; cheap and correct; pairs with A.
3. D, E, B, F — viable but each loses on cost, accuracy, effort or coverage.
