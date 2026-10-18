# Codex — proposals: how should Stacked get consistent exercise animations?

You are an independent adviser here (not reviewing code). Branch `ericlee4992/beta-18-exercise-media`. Read first:
`work-record/exercise-media/spec.md`, `issues/01-reference-ux-study.md` (Lyfta's screens), `issues/02-media-licensing.md`
and `research/media-licensing.md` (licences, rounds 1–2), and the 90 seeded exercises in
`WorkoutTracker/Resources/SeedCatalog.json` (many are machines: leg extension, pec deck, pendulum/belt/hack squat,
Viking press, neck machine, seated row …).

## The problem

The user wants every exercise (90 seeded, plus custom ones) to show a **consistent looping form animation** on the
exercise page and in a pop-up during workouts, like Lyfta (3D figure, target muscles tinted, ~6 s loop). Constraints
established so far:
- Licensed/owned media only. ExerciseDB V1 is non-commercial; V2 forbids any storage, caps cache at 1 h and requires
  discontinuing the app on cancellation — ruled out. No reverse-engineering or tracing of others' media; no
  extracting motion from YouTube (its terms forbid download/modification).
- The user **will not film** their own lifts and has no footage.
- Free sources are thin and inconsistent: wger (stills for ~⅓ of ours, few videos), Everkinetic (two-pose line
  drawings, ~half), ~20 Wikimedia clips, Mixamo motions (no machines, no deadlift/bench/row).
- Gym visual sells the Lyfta-style clips per item (~$0.90/GIF from 10 → ~$81 for 90), perpetual, iOS apps allowed,
  files must stay out of the public repo.
- AI video (Runway/Seedance/ElevenLabs via Veo/Kling) is commercially usable on paid plans but risks wrong form
  (a safety issue), struggles with machines, needs per-clip review.
- Muscle maps are decided: **our own simple drawings** (flat silhouettes in Stacked's style).
- App facts: SwiftUI, iOS 26+, no third-party runtime code, offline-first, public GitHub repo, a Cloudflare Worker +
  R2 we own, the Floodlight design system (`.claude/skills/ios-design/`).

## What I want from you

Propose **3–6 concrete, legally clean approaches** — including ones not listed above (be creative: procedural or
code-drawn animation, different visual styles, partnerships, commissioning, hybrid pipelines, anything). For each:
how it works end to end, the look, coverage of our 90 (machines especially), cost ($ and effort), accuracy/safety
risk, licence position, offline behaviour, how custom exercises get media, and the first small experiment that would
prove or kill it. Then rank them and give your recommendation with reasons. Be specific to this codebase where it
helps (e.g. where pose data or assets would live, how `SeedCatalog.json` would reference media).

Write `work-record/exercise-media/research/codex-proposals.md`. Do not modify other files; do not commit or push.
End the file with a line `Done.`
