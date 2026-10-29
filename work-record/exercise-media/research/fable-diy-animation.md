# Fable — make the animations ourselves: pipelines, open assets, reverse engineering (2026-10-29)

Brief: [diy-animation-prompt.md](diy-animation-prompt.md). Builds on [proposals-summary.md](proposals-summary.md),
[claude-proposals.md](claude-proposals.md), [codex-proposals.md](codex-proposals.md) and
[media-licensing.md](media-licensing.md) (wger, Everkinetic, Gym visual, Mixamo, CMU, Fit3D, Fab, Commons: already
checked there and not repeated). Licences below were read at their source today; the deciding lines are quoted.
Written independently of Codex's answer to the same brief.

Legend: **[F]** fact with source · **[I]** my inference · **[?]** unknown / not verified. Hours are estimates for
this user plus coding agents (no animation experience, strong at scripting); treat them as ±50 %.

## 0. Short answer

1. **Rank 1 — Blender mannequin, agent-scripted, rendered to short loops.** A CC0 rigged figure (MPFB2) in Blender,
   schematic machines built from primitives by a Python script, joint-angle keyframes authored from a written
   movement brief, muscle regions painted once and tinted per exercise, rendered to a 6 s seamless HEVC loop plus a
   poster. Output is a video file, so it drops into the *same player* the Gym visual pilot uses — the two routes
   stay interchangeable and comparable. $0 in licences; the cost is 20–35 h for the first three exercises and
   roughly 150–300 h for all 90 (falls as machine families repeat).
2. **Rank 2 — the same rig played live in RealityKit** (first-party; iOS 18+ `AnimationLibraryComponent`): tiny
   per-exercise data, tint-anything, any angle. Only worth it after rank 1 proves the look; adds 40–80 h of
   engineering and a fiddly Blender→USD→Reality Composer Pro step.
3. **Rank 3 — flat code-drawn figure (SwiftUI Canvas)** — unchanged from the earlier proposals; cheapest, but the
   weakest at 3D machines (pec deck, pendulum, Viking press) and furthest from the Lyfta look.
4. **Rank 4 — a private, never-shown motion-capture take as *motion data* for rank 1/2** (ARKit body tracking /
   Vision 3D pose / MediaPipe / FreeMoCap — all usable). Good for natural tempo, poor around machines (occlusion).
   Needs the user's answer to the open question in §4.
5. **Rank 5 — AI text-to-motion: not now.** Every open model I checked is either non-commercial by its training
   data (AMASS/HumanML3D/SMPL) or, for Tencent's HY-Motion 1.0, **forbids using its *Output* in the EU, UK and
   South Korea**, which an App Store app cannot promise.

**Buy the $18.10 pilot: yes**, as the quality benchmark the first experiment is judged against (and as the fallback
library if our renders disappoint). It is the cheapest decision aid available; the written-permission question for
*shipping* Gym visual files (Codex, ticket 02) does not block buying ten items for an internal side-by-side.

**Licence findings most likely to change a decision:** (a) MPFB2 / MakeHuman assets and Blender's Human Base Meshes
are **CC0**, so a fully owned 3D figure is free of attribution and share-alike; (b) Z-Anatomy (the obvious muscle
mesh) is **CC BY-SA 4.0** — using its meshes inside our figure would make the figure and arguably every rendered
loop share-alike; BodyParts3D itself is **CC BY 4.0** (attribution only) — prefer it, or paint muscle regions
ourselves; (c) AMASS/HumanML3D/Bandai-Namco/LaFAN1/Motion-X are all non-commercial — no open mocap library of gym
lifts exists for us beyond CMU (no gym content) and the ~$20 Fab barbell pack; (d) the repository has **no LICENSE
file** (public, all rights reserved by default), so any BY-SA asset committed to it needs its own licence note.

---

## 1. Build it ourselves — concrete pipelines

### 1.1 Pipeline A (rank 1): Blender figure + scripted motion → rendered loops

**Parts, all free of licence fees**

- **Blender** (GPL). [F] "What you create with Blender is your sole property"; GPL applies to published Python
  scripts/add-ons built on Blender's API, not to the images they render — https://www.blender.org/about/license/.
  [I] Our `bpy` scripts would be GPL *if published*; the renders are ours regardless. Keep the scripts in a separate
  folder with a GPL notice, or private.
- **Figure, option 1 — MPFB2 (MakeHuman for Blender)**: generates a human mesh *already rigged* (default rig, game
  engine rig, Rigify) from sliders. [F] "The MPFB source … is released under GPLv3"; "These assets have been released
  under CC0 1.0 Universal … it is the intention of the MakeHuman team that anyone can do whatever they want with it";
  "As the assets have been released under CC0, there is no limitation on what you can do with this combined output"
  — https://raw.githubusercontent.com/makehumancommunity/mpfb2/master/LICENSE.md (asset text: `LICENSE.ASSETS.md`
  is the CC0 1.0 deed). [F] Rig variants per release notes: default T-pose "for each rig type except rigify"
  (2.0-alpha2), "a new game engine rig variant" (2.0-beta1), MakeHuman BVH poses importable, "initial, and somewhat
  experimental, support for Mixamo" (2.0-alpha3) — https://static.makehumancommunity.org/mpfb/releases/release_20b1.html.
- **Figure, option 2 — Blender Studio Human Base Meshes**: [F] "Human Base Meshes v1.4.1 … 49 MB – CC0 … Requires
  Blender 4.2 LTS or newer" — https://www.blender.org/download/demo-files/. Unrigged sculpting bases → add Rigify
  (ships with Blender). More work than MPFB2, nicer mesh. [I] Use for a second pass if MPFB2's look is too
  "MakeHuman".
- **Figure, option 3 — Quaternius "Universal Base Characters" (rigged, retargetable)**: *not* CC0 any more. [F]
  Quaternius Asset License v1.0: "worldwide, royalty-free, non-exclusive, perpetual license, for personal,
  educational, or commercial purposes … No attribution is required"; but "You may not extract, repackage,
  sublicense, sell, or otherwise redistribute the Assets … regardless of how much the Assets have been modified"
  — https://quaternius.com/license.html. [I] Fine for renders; the raw mesh could not sit in the public repo.
  Low-poly stylised look — probably too game-like for a form demo.
- **Machines**: build schematics from primitives in the script (seat, back pad, pivot arm, shin pad, weight-stack
  box, cable line, sled on rails). [I] This is the honest answer to "gym-equipment 3D models": no free library
  covers lever leg extension, pec deck, pendulum/hack/belt squat, Viking press or a 4-way neck machine (§2.3), and
  schematics read better at 160 pt anyway. Free-weight props (bench, barbell, dumbbell, kettlebell) can be CC0
  (Poly Haven / sharetextures) or primitives.
- **Muscle tint**: paint ~15 vertex groups once (pecs, lats, delts, biceps, triceps, forearms, abs, obliques,
  glutes, quads, hamstrings, calves, traps, erectors, neck) on the mannequin; a per-exercise JSON lists primary /
  secondary groups; the script sets an emissive red / orange material on those groups before rendering. Reference
  anatomy from BodyParts3D (CC BY 4.0) or public-domain Gray's plates — *reference only*, no mesh import (§2.4).
- **Motion**: 3–4 key poses per exercise (setup, mid, end, mid), written as joint angles in a JSON "movement brief"
  the user reviews as a lifter; IK targets pin hands to the bar/handles and shins/feet to pads/platforms; the
  machine's moving part is driven by one angle tied to the limb (a Blender driver), so the pad never leaves the shin.
  Ease-in/out, first frame = last frame, 6 s at 30 fps (180 frames) to match the Lyfta/Gym visual loop length
  (ticket 01: "**6 s** for Bench Press").
- **Render & encode**: EEVEE on the Mac (seconds per frame), PNG sequence → `ffmpeg` → HEVC MP4 at 720×720 (or
  1080) plus a poster PNG; [I] 0.3–1 MB per clip, 90 clips ≈ 30–90 MB → served from our R2 and cached, or bundled
  if small enough. The same manifest keyed by seeded exercise UUID that every earlier proposal assumed.

**Look.** [I] A grey-white mannequin with red muscles on a neutral backdrop — the Gym visual "Basic grey" idiom the
user picked for the pilot (ticket 03) — is achievable with flat lighting and a matcap-like material; it will be
stiffer and less anatomical than Gym visual's artist-made renders. Whether "good enough" is exactly what the first
experiment decides, side by side with the purchased pilot.

**Effort.** Setup + scene template 6–10 h; per machine family 2–4 h (≈12–15 families); per exercise 1–3 h once its
family exists (brief, keyframes, review, render). First three exercises 20–35 h including the pipeline; all 90
roughly 150–300 h. Compare Codex's 200–500 h for a commissioned original library and $81 for 90 Gym visual GIFs.

**Machine coverage.** By construction: everything in `SeedCatalog.json`, including the ambiguous names once the user
writes the brief (Rotator Cuff, Neck Machine, Multi-Hip, Machine Squat, Grip Trainer — Codex's precision point).

**Accuracy / safety.** Deterministic and reviewable: a wrong knee angle is a number. The risk is a *smooth wrong*
movement (depth, bar path, lockout) that looks authoritative — the user's lifter review of each brief is the control,
as with any route.

**Custom exercises.** Pick an already-rendered movement (the shared decision), or — because the pipeline is a script
— render a new one in minutes of compute once a brief exists. A new machine family is the slow case (2–4 h).

### 1.2 Pipeline B (rank 2): the same rig, live in the app with RealityKit

- **Framework status.** [F] "SceneKit is soft-deprecated … For any project with a long-term vision … migrate to
  another native framework like RealityKit" — https://developer.apple.com/documentation/realitykit/bringing-your-scenekit-projects-to-realitykit
  (iOS 26 sample). RealityKit is Apple's, so no third-party runtime code; `RealityView` embeds in SwiftUI.
- **Multiple clips per figure.** [F] `AnimationLibraryComponent` (iOS 18+): "A component that represents a collection
  of animations that an entity can play … You can store animations with an entity by packaging them together into a
  `.reality` file … with Reality Composer Pro or by building a custom tool"; `animations["walk"]` by name —
  https://developer.apple.com/documentation/realitykit/animationlibrarycomponent.md. [F] Apple engineer (Aug 2025):
  "exporting multiple animations from Blender into USD for the same skinned mesh is a bit awkward" — put actions
  sequentially in Blender's NLA, then "cut up" the combined animation in RCP's AnimationLibraryComponent inspector;
  the thread's author instead exported one USDZ per animation (~300 KB each, duplicating the mesh) —
  https://developer.apple.com/forums/thread/797061. [I] 90 clips × 300 KB ≈ 27 MB bundled, or one `.reality` file
  built by a small macOS tool using the documented programmatic path (`availableAnimations` → library → `write(to:)`).
- **Tint.** Material parameters or vertex colours on the muscle groups, set at runtime → primary/secondary colours
  follow the app theme, light/dark, and any custom exercise's muscle choice. Camera angle is free (front/side toggle).
- **Costs / risks.** [I] 40–80 h of engineering beyond Pipeline A (USD export hygiene — set a root prim, no bendy
  bones; RCP packaging; `RealityView` lifecycle; battery and thermal behaviour of a live 3D view on an exercise
  list; Reduce Motion → static pose). Pose data stays the same JSON, so A's work is not wasted. Decide after A's
  renders are judged; don't start here.

### 1.3 Pipeline C (rank 3): flat code-drawn figure

Already specified in [claude-proposals.md](claude-proposals.md) §A and [codex-proposals.md](codex-proposals.md) §3
(100–240 h). New points only: the *same* joint-angle JSON could drive A, B and C, so authoring the briefs once is the
real asset; and Rive/Lottie would both be third-party runtimes ([F] rive-ios is MIT and "distributed both through
Swift Package Manager and Cocoapods" — https://github.com/rive-app/rive-ios), ruled out by the no-third-party-code
rule; SwiftUI `Canvas` is the only first-party vector route.

### 1.4 Motion sources that could feed A/B (instead of hand keyframes)

| Source | Usable commercially? | Fit for gym machines | Notes |
|---|---|---|---|
| Hand keyframes from a written brief (the default) | Yes — ours | Yes | Deterministic; the lifter reviews numbers |
| **ARKit body tracking** on an iPhone | Yes (Apple framework; the recording is ours) | Medium — occlusion by the machine; needs a second person to hold the phone | [F] "tracks human body poses … using the rear-facing camera", iOS 13+, `ARBodyAnchor` skeleton — https://developer.apple.com/documentation/arkit/arbodytrackingconfiguration.md. [?] Chip requirement not stated on the page; a forum report of empty joint transforms on iOS 26.0/26.1 LiDAR devices is unconfirmed |
| **Vision 3D body pose** from a video file | Yes | Medium | [F] iOS 17+, "a 3D skeleton with 17 joints", positions "in meters … with an origin at a root joint", one person per frame — WWDC23 111241 / https://developer.apple.com/documentation/vision/vndetecthumanbodypose3drequest.md. [I] 17 joints is coarse (no spine detail, no feet) |
| **MediaPipe** pose (33 landmarks) | Yes — Apache 2.0 — https://github.com/google-ai-edge/mediapipe/blob/master/LICENSE | Medium | Runs on the Mac over a video; a tool licence, not a data licence |
| **FreeMoCap** (multi-camera markerless) | Tool is AGPL-3.0 ([F] README; "if the AGPL doesn't suit your needs, the maintainers will discuss a different license") — https://github.com/freemocap/freemocap | Medium–good with 2–3 phones | AGPL binds the tool, not our recorded data; nothing of it ships in the app |
| **Rokoko Vision** (web, single camera) | [?] A directory listing claims outputs are "licensed for commercial use"; Rokoko's own terms not read — verify before relying | Medium | Free tier single camera (2023 report) |
| **Cascadeur** (AI-assisted physics keyframing) | Free plan: [F] "Only non-commercial use", ".casc format only"; Indie $8–19/mo: "The revenue must be less than $100k per year"; Pro $33–49/mo "Commercial use with no limits" — https://cascadeur.com/plans | Good — it is a keyframing tool, not a generator | [I] A genuine accelerator for *natural* in-between motion if hand keyframes look robotic; outputs are ours |
| Mixamo / Fab barbell pack / CMU | Yes (media-licensing R2.4) | Free weights only; no machines | Mixamo FAQ: "the only thing you can't do is distribute the raw character and animation files"; "The only research application Mixamo content can't be used in is training machine-learning models" — community copy https://community.adobe.com/t5/mixamo-discussions/mixamo-faq-licensing-royalties-ownership-eula-and-tos/m-p/13234775 (helpx page returned 403 today) |
| **AI text-to-motion** | **No** (see §2.2) | Poor [I] | Models have never seen a pec deck |

[I] Mocap's value is tempo and weight shift; its cost is clean-up (foot slide, jitter, machine occlusion) and the fact
that someone must perform each lift on camera. If the user will not be that person, hand keyframes plus Cascadeur-style
smoothing are the realistic path.

---

## 2. Open-source / free assets — licences read line by line

### 2.1 Human models and rigs

| Asset | Licence (quoted) | App bundling | Public repo | Attribution / SA |
|---|---|---|---|---|
| **MPFB2 / MakeHuman assets** (mesh, targets, rigs) | [F] "These assets have been released under CC0 1.0 Universal … no limitation on what you can do with this combined output" — https://raw.githubusercontent.com/makehumancommunity/mpfb2/master/LICENSE.md | Yes | Yes | None |
| **Blender Studio Human Base Meshes v1.4.1** | [F] "49 MB – CC0" — https://www.blender.org/download/demo-files/ | Yes | Yes | None |
| **Quaternius Universal Base Characters** | [F] QAL v1.0: commercial OK, "No attribution is required", but no redistribution "regardless of how much the Assets have been modified" — https://quaternius.com/license.html | Renders yes; raw mesh no | Raw mesh **no** | None |
| **Mixamo characters** | [F] free for commercial projects; cannot distribute raw files (see §1.4) | Renders yes; raw files no | **No** | None |
| **SMPL / SMPL-X body model** (needed to render AMASS/HumanML3D-style motion) | [F] "for the sole purpose of performing non-commercial scientific research … Any other use, in particular any use for commercial purposes, is prohibited … also available for commercial licensing through Meshcapade.com" — https://smpl.is.tue.mpg.de/modellicense.html. [F] Meshcapade "Mico" tier (≤10 employees, ≤€2M turnover): €5,000/yr commercial — https://meshcapade.notion.site/The-SMPL-Model-Licenses-2144560e54388085af5eff111fcdf266 | **No** without €5k/yr | No | — |

### 2.2 Motion data and motion generators

| Source | Licence (quoted) | Verdict for a free or paid App Store app |
|---|---|---|
| **CMU mocap** | free for all uses incl. commercial products (media-licensing R2.4) | Usable; almost no gym lifts |
| **Mixamo motions** | see §1.4 | Usable in renders; ~20 fitness motions, no bench/deadlift/row/machines |
| **Fab barbell pack** (~$20) | Fab Standard License (media-licensing R2.4; fab.com/eula returned 403 today) | Usable in renders; raw FBX private |
| **AMASS** | [F] "non-commercial scientific research … Any other use, in particular any use for commercial purposes, is prohibited. This includes, without limitation, incorporation in a commercial product, use in a commercial service"; "may not be reproduced, modified and/or made available in any form to any third party"; "prohibits the use of the Dataset to train methods/algorithms/neural networks/etc." (for commercial use) — https://amass.is.tue.mpg.de/license.html | **No** |
| **HumanML3D** | [F] repo LICENSE is MIT (scripts), but "HumanML3D … originates from a combination of HumanAct12 and Amass dataset … Due to the distribution policy of AMASS dataset, we are not allowed to distribute the data directly" — https://github.com/EricGuo5513/HumanML3D | **No** (the data is AMASS) |
| **Bandai-Namco Research Motiondataset** | [F] both datasets "CC BY-NC 4.0"; Blender utilities MIT — https://github.com/BandaiNamcoResearchInc/Bandai-Namco-Research-Motiondataset | **No** |
| **Ubisoft LaFAN1** | [F] "Creative Commons Attribution-NonCommercial-NoDerivatives 4.0" — https://github.com/ubisoft/ubisoft-laforge-animation-dataset | **No** |
| **Motion-X** | [F] paper: "CC BY-NC-SA"; sub-datasets research-only — https://arxiv.org/abs/2307.00818v2 | **No** |
| **Fit3D** | non-commercial (media-licensing R2.4) | **No** |
| **100STYLE** | [?] site blocked for fetching today; not verified | Unknown — assume no until read |
| **MDM / MoMask** (open text-to-motion) | [F] "This code is distributed under an MIT LICENSE … depends on other libraries, including CLIP, SMPL, SMPL-X, PyTorch3D, and uses datasets that each have their own respective licenses that must also be followed" — https://github.com/GuyTevet/motion-diffusion-model, https://github.com/EricGuo5513/momask-codes | **No**: pretrained weights come from HumanML3D/KIT-ML (AMASS-derived, non-commercial) and mesh output needs SMPL [I] |
| **Tencent HY-Motion 1.0** (Dec 2025, 1B params, 26 GB VRAM) | [F] "THIS LICENSE AGREEMENT DOES NOT APPLY IN THE EUROPEAN UNION, UNITED KINGDOM AND SOUTH KOREA"; "You must not use, reproduce, modify, distribute, or display the Tencent HY-MOTION 1.0 Works, **Output or results** … outside the Territory"; >1 million MAU "must request a license"; distributions must carry a "Powered by Tencent HY" encouragement and a Notice file; "Tencent claims no rights in Outputs You generate" — `License.txt` in https://github.com/Tencent-Hunyuan/HY-Motion-1.0 | **No** for a worldwide App Store app: the EU/UK exclusion attaches to the *outputs* we would ship. Also needs a 24–26 GB GPU |

[I] Conclusion: there is no licence-clean open mocap or text-to-motion source for gym machines. Motion must be
authored (keyframes, optionally Cascadeur Indie) or captured ourselves.

### 2.3 Gym-equipment 3D models

- [F] Poly Haven: "Our assets are all licensed as CC0 … You can use our assets for any purpose … You can redistribute
  them" — https://polyhaven.com/license. [?] Its catalogue of gym items was not enumerated; expect generic props at
  most.
- [F] sharetextures lists a dumbbell as a "Free Model" under "CC0" — https://www.sharetextures.com/models/equipments/dumbell_1
  (site-wide terms not read).
- [F] Sketchfab's free CC downloads were slated to end in 2025 and CC0/BY-SA/BY-NC/BY-ND models "could not migrate to
  Fab under those licenses" — https://sketchfab.com/blogs/community/sketchfab-update-what-you-need-to-know-now-that-fabs-live/.
  [?] Current state not confirmed; don't plan on Sketchfab.
- [F] Paid packs exist (DOSCH Fitness Equipment €49, CGAxis Vol. 57 $69–99) — royalty-free, not open; raw files
  private. [I] Not needed: the schematic-from-primitives approach (§1.1) gives consistent, on-brand machines and is
  what a form demo needs (the path of motion), as both earlier proposals argued.

### 2.4 Muscle / anatomy models for the tint

| Asset | Licence (quoted) | Use for us |
|---|---|---|
| **BodyParts3D** (DBCLS) | [F] "Creative Commons Attribution 4.0 International"; required credit "BodyParts3D, © The Database Center for Life Science licensed under CC Attribution 4.0 International" — https://dbarchive.biosciencedbc.jp/en/bodyparts3d/lic.html | Attribution only — the clean choice if we import muscle meshes; also fine as a reference for painting regions ([I] earlier distributions were BY-SA 2.1 JP; the archive page now says BY 4.0 — use the archive download) |
| **Z-Anatomy** (Blender atlas, "more than 5,000" structures, derived from BodyParts3D) | [F] "All the code and content shared by 'Z-Anatomy' is under Creative Commons Attribution-ShareAlike 4.0 … You must distribute any derivative work based on part or whole of the data from this database under the same license" — https://github.com/Z-Anatomy/Models-of-human-anatomy (README) | **Avoid as a mesh source**: SA would attach to our figure and [I] to the rendered loops; the repo has no LICENSE file to host BY-SA material cleanly. Fine as a visual reference |
| **OpenSim models** | [F] software Apache 2.0; "models, examples and plugins retain their own custom licenses. Refer to each individual file" — https://opensimconfluence.atlassian.net/wiki/spaces/OpenSim/pages/53086437/License+for+OpenSim+4.0+and+Later. [?] Rajagopal full-body licence not shown on SimTK | Biomechanics (joint ranges, muscle lines) reference; not a render asset |
| **wger / Termininja SVGs** | CC BY-SA 3.0 (media-licensing §6) | Superseded by the "own drawings" decision |

**Share-alike vs. bundling [I].** CC BY-SA 4.0 does not forbid use in a paid app, but (1) the adapted material (a
mesh, a video rendered from it) must be BY-SA and the app must show the credit; (2) §2(a)(5) forbids "Effective
Technological Measures" that restrict recipients — App Store encryption of a bundled asset is a long-running grey
area, avoided by serving the file plainly from our R2 (which we do anyway); (3) our repo currently carries no licence
at all, so a BY-SA file in it needs a per-folder LICENSE. CC0 and CC BY assets have none of these entanglements.
Recommendation: build the figure from CC0 parts and keep anatomy sources as references, so the whole media set is
ours or CC BY at most.

### 2.5 Exercise media sets (for completeness)

Already judged in media-licensing: wger / Everkinetic (BY-SA, two-pose), free-exercise-db (Unlicense, undocumented
photo provenance), Commons clips. New today: **openGym** (open-source app) — [F] its "exercise stills and animations
are © Aliaksandr Makatserchyk, Gym visual, licensed for use in openGym only and not covered by the AGPL" —
https://newreleases.io/project/github/DuarteSantos8/openGym/release/v1.4.0. **Feeel** (AGPL app) asks contributors to
"turn exercise photos into low-poly versions"; its image licences live in `COPYING.md` on GitLab, which I could not
fetch [?]. Neither gives us a library; both show that open-source gym apps also *buy or hand-make* media.

---

## 3. Reverse engineering — lawful and useful vs. not

**Not acceptable (plainly):**
- Extracting, frame-grabbing, tracing, rotoscoping or running pose estimation over Lyfta's, Hevy's, ExerciseDB's or
  Gym visual's animations or 3D assets to derive our keyframes or meshes. The result is a derivative of their
  copyrighted animation (its timing and expression, not just the exercise idea). The same applies to the ten Gym
  visual files once bought: a benchmark to look at, not a reference to trace.
- Decompiling or instrumenting the iOS apps. [F] Apple's standard Licensed Application EULA: "You may not copy …
  reverse-engineer, disassemble, attempt to derive the source code of, modify, or create derivative works of the
  Licensed Application" — https://www.apple.com/legal/internet-services/itunes/dev/stdeula/. Several apps' own
  terms say the same (claude-competitor-study). App Store binaries are also FairPlay-encrypted.
- Automated access to sites whose terms forbid it (JEFIT, StrengthLog, Boostcamp — rule already recorded).

**Lawful and valuable:**
1. **Spec-setting from public behaviour** (done, ticket 01): 6 s silent loop, poster-then-tap, MP4 from a CDN,
   muscle-tinted grey figure, three-quarter camera. Learning *what good looks like* is ideas, not expression.
2. **Reading open-source apps' code and data models**: wger (muscle/equipment tables, how media is credited),
   openGym (manifest + playback), Liftosaur (how a public repo ingests purchased Gym visual files without committing
   them — directly our ticket 03 problem). Reading AGPL code to learn is fine; copying code into our app is not
   (our repo has no compatible licence).
3. **Interoperable formats and Apple's own documentation**: USD/USDZ, `.reality`, glTF, BVH, FBX; the Blender→USD→RCP
   threads above are RE of a toolchain, with Apple's blessing.
4. **Measuring our own purchased files** (duration, fps, resolution, size, loop seam) to set encoding targets for our
   renders — we own those copies.
5. **Gym visual's public product pages** for naming and camera conventions (Gym visual permitted our browsing,
   ticket 03) — read, don't scrape.

[I] Law differs by country (EU software-directive decompilation exceptions, US DMCA §1201(f)) and none of it licenses
copying an animation; this file is not legal advice.

---

## 4. Open question to raise with the user (not assumed)

Would a **private motion-capture take** — the user (or a friend) performing each lift once, filmed on an iPhone,
never shown, used only to drive the mannequin — be acceptable? It changes rank 4 from "unavailable" to "the fastest
way to natural tempo", and would also give a real bar-path check for the free-weight lifts. Related: filming inside a
commercial gym may need the gym's permission; machines occlude the body, so a second phone (FreeMoCap-style) or
hand-fixing is likely.

---

## 5. Recommendation

### Ranking

| # | Route | Money | Hours (3 ex. / 90 ex.) | Machines | Custom exercises | Look vs. Lyfta | Licence position |
|---|---|---|---|---|---|---|---|
| 1 | **Blender mannequin, scripted, rendered loops** (§1.1) | $0 | 20–35 / 150–300 | All, by construction | Reuse or render new (minutes of compute, hours for a new machine) | Close in idiom (grey figure, red muscles); stiffer | Ours; CC0 inputs |
| 2 | Same rig live in RealityKit (§1.2) | $0 | +40–80 engineering | All | Best (tint/angle at runtime) | As 1 | Ours |
| 3 | Flat SwiftUI Canvas figure (§1.3) | $0 | 100–240 (Codex) | Weak on 3D machines | Good | Different look | Ours |
| 4 | Private mocap as data for 1/2 (§1.4) | $0 | +1–2 h per lift + clean-up | Occlusion | — | Improves motion quality | Ours (user's answer needed) |
| 5 | AI text-to-motion | $0 | — | Poor | — | — | **Blocked** (§2.2) |
| ref | Gym visual library (pilot $18.10; ~$81 GIFs / ~$540 video) | $ | ~10 for ingestion | Specialty machines exist | None | Is the Lyfta look | Written permission needed before shipping (Codex) |

### First experiment for route 1 — leg extension, pec deck, barbell bench press

Goal: three 6 s loops on the phone, next to the Gym visual pilot, judged by the user at the real pop-up size.

| Step | What | Hours |
|---|---|---|
| 1 | Install Blender 4.2 LTS and the MPFB2 add-on; generate one neutral male figure with the *default* rig; export nothing yet. (Agent writes the setup notes; the user clicks.) | 2–3 |
| 2 | Agent-written `bpy` scene template: three-quarter camera (match the pilot's angle), flat 3-point light, neutral backdrop, grey-white skin material, `muscles.json` → emissive red on named vertex groups. Paint pecs, quads, anterior delts, triceps once. | 4–6 |
| 3 | Three machine schematics from primitives, each with one driven pivot: leg extension (seat, back pad, shin-pad arm, stack), pec deck (seat, two arm pads), bench press (bench, uprights, barbell as an IK target). | 5–8 |
| 4 | Movement briefs: the user dictates setup / bottom / top / tempo as a lifter; the agent turns them into 3–4 keyframes of joint angles + IK targets, 180 frames, seamless loop. | 3–5 |
| 5 | Render (EEVEE) → `ffmpeg` HEVC 720×720 + poster; keep sources outside the repo for now. | 1–2 |
| 6 | Put the three MP4s in the same player prototype planned for the Gym visual pilot: exercise page hero and workout pop-up, light/dark, default + AccessibilityL, Reduce Motion → poster. Side by side with the bought leg extension / pec deck / bench press. | 4–6 |
| | **Total** | **20–30** |

**Proves the route** if: the user, at pop-up size, identifies hand/foot placement and the machine's travel without
reading; the tint reads as "these muscles"; and the user would put ours next to Gym visual's without embarrassment.
**Kills it** if: the render is judged clearly worse and lighting/material passes don't close the gap; joints pop or
pads intersect limbs and need per-frame hand fixes; or step 4 exceeds ~6 h per exercise after the template exists
(then 90 exercises is >500 h and buying wins). A partial result — figure good, machines toy-like — points to route 1
for free weights plus bought clips for specialty machines, which the shared player supports.

### Buy the $18.10 pilot?

Yes, now. It is the benchmark the experiment above is scored against, it tests the player and offline path either
way, and if our renders lose it becomes the start of the fallback library. Keep the files out of the repo (ticket 03),
and keep Codex's point: before *shipping* Gym visual media, get the written permission on bundling / R2 delivery /
offline copies / MP4 conversion.

### Unknowns carried forward

- [?] Cascadeur's Indie terms for an app that is free today but may charge later (the $100k/yr cap is on *our*
  revenue — fine for now; recheck before Pro is needed).
- [?] Rokoko Vision output terms (not read at source). [?] 100STYLE licence (site unreachable today).
- [?] ARKit body-tracking chip requirements and the iOS 26.0/26.1 LiDAR report; only matters if route 4 is approved.
- [?] Whether a bundled BY-SA/BY asset conflicts with App Store encryption — moot if the figure is built from CC0
  parts and anatomy sources stay references.
- [?] Blender→USD skinned-mesh export fidelity for the MPFB2 default rig (bendy bones, shape keys) — only for route 2.

Done.
