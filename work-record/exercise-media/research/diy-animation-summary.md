# Making our own exercise animations — Fable + Codex (Astra), combined (2026-10-29)

The user asked (2026-10-29) for ways to build the animations themselves, open-source assets, or reverse engineering,
with ideas from Claude Fable and Codex (GPT-6-Astra). Same brief to both, written independently:
[brief](diy-animation-prompt.md) · [fable-diy-animation.md](fable-diy-animation.md) ·
[codex-diy-animation.md](codex-diy-animation.md). Claude (Opus) re-checked the deciding licence lines at the
source (list at the end).

## Where they agree

- **Best do-it-yourself route: Blender, scripted by agents, rendered to short looping videos.** A free CC0 human
  figure (MPFB2 / MakeHuman, or Blender's Human Base Meshes), simple unbranded machines built from boxes and
  cylinders, key poses plus IK so hands and feet stay on the handles and pads, muscle areas painted on the figure
  and tinted per exercise, rendered to ~6 s loops. The result plays in the same player the bought clips would use.
  $0 in licences; everything we make is ours.
- **First experiment: three exercises** — leg extension, pec deck, barbell bench press (two machine mechanisms plus
  a bar). Kill or continue on what it looks like on the phone next to the Gym visual pilot.
- **Agents write the scripts; a person still judges form.** Neither model can approve technique; a wrong-looking
  demo is a safety issue. Codex suggests budgeting a few paid hours of animation/form review if needed.
- **Open motion-capture libraries and AI text-to-motion are not usable** for a commercial-capable app:
  AMASS / HumanML3D (commercial use prohibited), Bandai-Namco (CC BY-NC), SMPL model (non-commercial; ~€5k/yr
  commercial), MDM/MoMask/T2M-GPT (code is open, the trained weights come from AMASS-derived data), MotionDiffuse
  (non-commercial code), Tencent HY-Motion (its licence excludes the EU, UK and South Korea, including outputs).
- **Muscle tint:** paint a handful of muscle regions ourselves. Avoid Z-Anatomy (share-alike, plus some
  non-commercial parts); BodyParts3D (CC BY 4.0, credit line) is fine as a reference or source.
- **Reverse engineering:** learning from public behaviour (loop length, camera, file size, player behaviour) and
  from open-source apps' pipelines is fine and useful. Tracing, rotoscoping, pose-extracting or re-rendering another
  company's animations is not — re-rendering copied motion on our own figure does not remove their rights.
- **Buy the $18.10 pilot anyway** — as the quality benchmark the experiment is judged against and as a fallback.
- Vague catalog names (Neck Machine, Rotator Cuff, Multi-Hip …) need a movement description before anyone animates
  them, whatever the source.

## Where they differ

| | Fable | Codex (Astra) |
|---|---|---|
| Hours, 3-exercise experiment | 20–35 | 40–80 |
| Hours, all 90 | 150–300 | 300–700 (novice + agents; "replace with measured throughput") |
| Route 2 | Real-time 3D in the app (RealityKit) once the look is proven, +40–80 h | Flat 2D figure drawn in SwiftUI (24–50 h for three) |
| Route 3 | Flat SwiftUI figure | RealityKit (most engineering) |
| Open mocap | "every open mocap source is unusable" | **CMU** mocap is usable inside a product (not resale) and **Mixamo** is royalty-free for commercial projects (raw files stay private) — but both are thin on gym lifts and have no machines |
| Extras | Cascadeur Indie ($8–19/mo, <$100k revenue) as an optional tool for natural in-between motion | Blender's policy for published Python scripts (license the authoring scripts separately in our public repo) |

Claude's view: plan on Codex's hours; they include learning and review. The routes rank the same at the top; the
2D-vs-RealityKit order only matters if Blender renders fail.

## Ranked routes

1. **Blender figure + scripted keyframes/IK → rendered loops** (both #1).
2. **Flat 2D figure drawn in SwiftUI** — simplest delivery, weakest on 3D machines.
3. **Real-time 3D in the app (RealityKit)** — any angle, tiny files, but most engineering; only after 1 proves the
   look.
4. **Private, never-shown phone motion capture** (Apple Vision 3D body pose / MediaPipe / FreeMoCap) used only as
   motion data for our figure — open question for the user; machines hide the body, so cleanup is heavy.
5. **AI text-to-motion** — blocked by licences today.

## New finding: Gym visual's licence and AI processing

Re-read on gymvisual.com/content/9-license (2026-10-29). Under "may NOT be used": **"to process, modify, or use for
training by any Artificial Intelligence (AI) systems"** ("applies solely to the modification and development of
visual and media materials") and **"to use as a basis for creating and generating content (images, animations,
videos) using Artificial Intelligence (AI) tools and technologies"**. The earlier research recorded only "AI
training or generation".

Consequence for ticket 03: Claude should **not** open, view or convert the purchased files. Claude can write the
conversion script (ffmpeg, GIF → looping MP4 + poster) and the build step; **the user runs them** on the private
folder, and only the user views the files. Purchased files must not be used as reference for the DIY animations
either. Asking Gym visual whether agent-run format conversion counts is an option.

## First experiment (Codex's steps; Fable's are equivalent)

| Step | Work | Hours (Codex) |
|---|---|---:|
| 1 | Exact variants, camera, contact points, licence inventory | 2–4 |
| 2 | Install Blender + MPFB2, one reusable scene, check knee/elbow/shoulder bending | 6–12 |
| 3 | Agent-scripted bench + bar, leg-extension frame/lever/pad, pec-deck arms | 6–12 |
| 4 | 4–6 key poses per lift, hand/foot targets, bake and inspect | 14–24 |
| 5 | Muscle masks, one material/light, camera, seamless 4–8 s loop | 4–8 |
| 6 | Human form review and corrections | 5–10 |
| 7 | Export MP4 + poster; one player on the exercise page and workout pop-up; offline, Reduce Motion | 3–6 |

**Checkpoints:** ~12 h — the figure bends acceptably; ~40 h — three rough but mechanically sound loops; ~80 h —
all three pass review at phone size, or stop and re-estimate. Reject floating grips, slipping feet, pads passing
through limbs, loop jumps. (Fable's kill line: more than ~6 h of authoring per exercise, or per-frame fixes needed.)

## Decisions for the user

1. Try the DIY route (three-exercise Blender experiment), stay with bought clips, or both in parallel.
2. Buy the $18.10 pilot as the benchmark (both say yes) — with the user, not Claude, converting and viewing it.
3. Is a private, never-shown motion-capture take of yourself acceptable as motion data (route 4)?
4. Is a stylised grey figure enough, or is anatomical realism required?

## Claude's source checks (2026-10-29)

- MPFB2 LICENSE.md: assets "released under CC0 1.0 Universal"; "there is no limitation on what you can do with this
  combined output" (code is GPLv3 — not shipped).
- blender.org demo files: "Human Base Meshes v1.4.1", "49 MB – CC0".
- BodyParts3D licence page: CC BY 4.0; credit "BodyParts3D, © The Database Center for Life Science licensed under CC
  Attribution 4.0 International".
- Quaternius licence: commercial use, "No attribution is required", but may not "extract, repackage, sublicense, sell,
  or otherwise redistribute the Assets".
- CMU mocap: "You may include this data in commercially-sold products, but you may not resell this data directly,
  even in converted form."
- Gym visual licence: the two AI lines quoted above, read in the user's Chrome.

Not re-checked by Claude: the remaining entries in the two reports (each marks its own facts with sources).
