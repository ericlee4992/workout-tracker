# Brief — build our own exercise animations, open-source assets, reverse engineering (2026-10-29)

You are an independent adviser (not reviewing code). Repo: the Stacked iPhone gym log, branch
`ericlee4992/beta-18-exercise-media`. Read first: `work-record/exercise-media/spec.md`,
`research/proposals-summary.md`, and skim `research/claude-proposals.md`, `research/codex-proposals.md`,
`research/media-licensing.md` (licences already checked) and the 90 seeded exercises in
`WorkoutTracker/Resources/SeedCatalog.json` (many machines: leg extension, pec deck, pendulum/belt/hack squat, Viking
press, neck machine, seated row …). Don't repeat that research; build on it.

## The change

The user is reconsidering buying stock clips (a 10-item Gym visual pilot, $18.10, is in a cart but not bought). They
want to know, concretely, how they could **make the animations themselves**, **use open-source assets**, or use
**reverse engineering**. Goal unchanged: a consistent looping form demo (~4–8 s) for each exercise on the exercise
page and in a workout pop-up, target muscles tinted, Lyfta-like quality if possible. The user has no animation
experience but works with AI coding agents (Claude, Codex) that can write scripts, Blender Python, Swift, etc. They
will not film form footage of themselves for display (whether a private, never-shown motion-capture take is
acceptable is an open question to raise, not assume).

App facts: SwiftUI, iOS 26+, no third-party runtime code, offline-first, public GitHub repo (anything committed is
public), a Cloudflare Worker + R2 we own.

## What to research (use the web; cite URLs and quote licence lines)

1. **Build it ourselves — concrete pipelines.** E.g. Blender (+ Python scripted by an agent) with a free human rig
   (MPFB/MakeHuman, Blender's Human Base Meshes, Quaternius, etc.) and simple machine models; keyframes vs. IK
   driven by machine geometry; rendering to video vs. **real-time 3D in the app** (RealityKit/SceneKit with one rigged
   figure + per-exercise pose tracks as tiny data files — tintable muscles, any angle); 2D/vector (Rive is a runtime
   dependency — note it; SwiftUI Canvas/Path); markerless motion capture from a phone video (MediaPipe, Apple Vision
   3D body pose, open tools such as FreeMoCap) used only as motion data; AI motion generators (text-to-motion
   models) and their licences. For each: look, effort in realistic hours for this user + agents, cost, machine
   coverage, accuracy/safety risk, how custom exercises get media.
2. **Open-source / free assets with commercial-use licences**, checked line by line: human models and rigs, motion
   capture datasets (CMU, Mixamo, AMASS, HumanML3D, Bandai-Namco, etc. — many are non-commercial; say which are
   usable in a paid/free App Store app and which are not), gym-equipment 3D models, exercise media sets (wger,
   free-exercise-db, Everkinetic, Wikimedia), muscle/anatomy models (e.g. OpenSim, Z-Anatomy, BodyParts3D) for the
   muscle tint. Note attribution and share-alike duties, and whether they conflict with bundling in an app.
3. **Reverse engineering — what is lawful and useful.** Learning how competitors render (formats, frame rates, loop
   lengths, file sizes, player behaviour, camera angles) to set our own spec is fine and partly done (ticket 01 REA
   study of Lyfta). Extracting, tracing or rotoscoping another company's animations or 3D assets is not acceptable
   (copyright and the stores' terms) — say so plainly where relevant, and list RE uses that are both lawful and
   valuable (e.g. studying open-source apps' pipelines, interoperable formats).
4. **Recommendation:** rank 3–5 routes; for the top one give the first small experiment (e.g. 3 exercises: leg
   extension, pec deck, barbell bench press) with steps, hours and what result would prove or kill it; and say
   whether the user should still buy the $18 pilot as a quality benchmark.

Mark facts (with source), inferences and unknowns. Write only `work-record/exercise-media/research/<your-name>-diy-animation.md`
(name given in your instructions). Do not modify other files; do not commit or push. End the file with a line `Done.`
