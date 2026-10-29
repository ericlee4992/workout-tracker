# Making Stacked's exercise animations ourselves

Independent advice — 2026-10-29. **[F]** = published fact/source; **[I]** = recommendation or estimate;
**[U]** = unresolved or untested. I read the requested project documents and the 90 seeded exercise records, but
**did not read fable-diy-animation.md**. No third-party assets, code packages, model weights or datasets were
downloaded or run. This is a source/licence assessment and proposed experiment, not a tested animation pipeline.

## Recommendation

**[I] Start with Blender + MPFB's core CC0 human assets + our own simple machines, and render video first.**
Author three movements—leg extension, pec deck and barbell bench press—with the same figure, camera and materials.
Agents can generate the geometry, constraints, keyframe infrastructure and export scripts. A person still has to
judge the silhouette, skin deformation, motion and equipment contact. Hire a few hours of animation/form review
if necessary; do not equate a script running successfully with a correct demonstration.

**[I] Yes, I would still buy the pilot at the stated $18.10 cart total**, as a human-viewed quality benchmark and a
usable fallback. It is inexpensive compared with even one failed day of original animation work. Do not trace it,
extract its motion or feed its frames into an AI/pose-estimation pipeline. No purchase is made by this advice.

The free route is real, but “free assets” removes neither authoring work nor licensing distinctions. Our catalog
remains machine-heavy: 61 of 90 exercises have machine/cable/Smith tags. Rigging a person does not rig a leg-extension
lever, pec-deck arms or pendulum squat. Also define vague entries such as Neck Machine, Rotator Cuff and Multi-Hip
before assigning a demo: a name alone is not a motion specification.

The own-drawn flat muscle maps remain decided. A 3D mannequin can have separately authored target-region masks;
we do not need a complete anatomical atlas to tint its chest, quads or shoulders.

## Five routes, ranked for this user

**[I] Hours below are planning ranges for a novice working with coding agents, not quotes or measured throughput.**
They include learning, inspecting generated scripts, manual adjustments and review; unattended rendering time is
additional. The earlier 200–500-hour 3D estimate assumed a more established authoring workflow. For a novice, I would
budget more, then replace the estimate with measured pilot throughput. Cash ranges exclude the existing Mac/phone
and ordinary development costs. No route promises safe automatic animation of arbitrary custom exercise names.

| Rank | Route | First useful experiment | Plausible full-90 effort | Cash and principal tradeoff |
|---|---|---|---|---|
| 1 | Blender-authored 3D, rendered to MP4 | 40–80 hours for three reviewed loops and a basic player | 300–700 hours | $0 software/core-asset fees; optional $250–$1,000 pilot review allowance. Closest DIY route to the requested look |
| 2 | Original SwiftUI Canvas/Path motion diagrams | 24–50 hours for three diagrams | 160–360 hours | $0 asset fees; review still needed. Less anatomical/depth detail, simpler delivery |
| 3 | The same authored 3D assets, played in RealityKit | 60–120 hours including a working rig/export/playback experiment | 380–900 hours | $0 additional Apple-framework licence fee; substantially more engineering and device QA |
| 4 | Private capture → pose cleanup → our rig | An additional 20–45 hours after a rig exists | Roughly 300–1,000 hours including capture/cleanup and common rig work | Existing phone may suffice for a trial; extra cameras/performer/gym access unquoted. Conditional on acceptable footage |
| 5 | Text-to-motion generators | 20–60 hours just for rights/technical feasibility | Not responsibly estimable before a cleared model and pilot | Hypothetical $50–$300 authorized GPU trial allowance, not a production budget. Current common checkpoints are not cleared for this app |

The optional review allowance is a budgeting choice, not a claim about prevailing freelancer rates. At an assumed
$60/hour, 300 hours of purchased labor alone is $18,000. Agents may save coding hours; they do not make the remaining
visual and biomechanical work disappear.

### 1. Blender: key poses plus machine-constrained IK, then render

**[I] Pipeline:** choose a documented CC0 core figure → create a simple material and muscle-region masks → build
unbranded equipment from primitives → define contact targets and a handful of reviewed key poses → constrain and
bake the motion → inspect the entire loop → render 4–8 seconds of video plus a poster. Use one scene template and
batch-render only after the first three clips are convincing.

Use forward-kinematic controls for pelvis/torso posture and deliberate joint rotations; use inverse kinematics
(IK) to keep a hand or foot at a defined contact target. For a lever machine, animate the lever around its actual
pivot and let the relevant contact follow that path. For a bench press, the bar and two grips share a controlled
path. A two-bone IK solution keeps an endpoint attached; it does not decide safe shoulder mechanics, grip or range.
Do not drive every exercise with one generic sine wave or interpolate only two unreviewed endpoints.

**Look and coverage [I]:** a restrained 3D mannequin with tinted regions, simple shaded equipment and a fixed
three-quarter view can be consistent and clear. Lyfta-level anatomical surface detail is a later art problem,
not a consequence of installing a free rig. All 90 are authorable in principle after movement definitions are
resolved. Reuse machine families, but give hack, pendulum and belt squats different mechanisms and tracks.

**Custom exercises [I]:** explicitly select a reviewed matching movement/variant, or author a new sequence. A new
name must not silently inherit a plausible-looking but different exercise. New authored clips use the same rig and
render template, so consistency survives library growth.

**Risk/offline [I]:** skin weights can collapse elbows; IK can flip knees; pads can intersect limbs; a loop seam can
jump. Review slow playback and intermediate frames, not just start/end screenshots. Rendered local files play offline
through Apple's AVFoundation; Blender, MPFB and their Python dependencies stay on the authoring machine.

### 2. SwiftUI Canvas/Path: original 2D/2.5D diagrams

**[I] Pipeline:** an original articulated silhouette and equipment shapes → explicit joint-angle/keyframe data →
contact and layering rules → a native drawing view. Choose side/front/limited three-quarter projections per movement;
use a second view when depth matters. The result is a moving instruction diagram, not a realistic anatomical figure.
Agent-written geometry and interpolation are useful here, but the pose data still needs human review.

Machine coverage is possible through original schematic levers, rails, pads and cables. Pec deck and torso rotation
are the test: a simplified projection must not conceal the critical movement. It is easier to make a clean static
figure than to make ninety readable moving ones. Do not assume that a flat muscle-map polygon automatically becomes
a correct deforming muscle overlay on every pose.

**[F]** Apple provides native [Canvas drawing](https://developer.apple.com/documentation/swiftui/canvas). Rive is
another authoring/playback system, but its [iOS runtime](https://github.com/rive-app/rive-ios) is a separate library
(labelled **“MIT license”**). Its permissive licence does not satisfy Stacked's policy of no third-party runtime
code. Native Canvas avoids that dependency; a future licensed offline video export from an external tool would be a
separate asset workflow, not permission to embed its runtime.

**Custom/offline/risk [I]:** bundle reviewed pose files and geometry; they need no network. Customs can select an
exact reviewed variant or wait for authoring. Rotations and constraints are inspectable, but a deterministic wrong
pose is still wrong. If the user insists on a volumetric Lyfta-like person, this route fails the visual requirement
regardless of how inexpensive it is.

### 3. RealityKit: one rigged figure, reusable pose tracks, native real-time 3D

**[F]** Apple's [JointTransforms](https://developer.apple.com/documentation/realitykit/jointtransforms) supports
animatable skeletal poses. For new work, use RealityKit: Apple's SceneKit page states **“SceneKit is deprecated, use
RealityKit instead.”** [Source](https://developer.apple.com/documentation/scenekit).

**[I] Pipeline:** author/approve the same rig and motions as route 1 → bake Blender constraints into animation data
or explicit joint tracks → export an Apple-compatible skeletal asset → play it in a non-AR RealityKit view, with
our materials, loop controls and bounded camera rotation. Alternatively, use a versioned joint-track format and
build RealityKit animation resources. Prove that import/bone ordering, transforms, skinning, looping and equipment
animation survive a round trip before authoring the library. Blender IK constraints do not automatically become a
working machine-aware IK solver inside the app.

**Look/coverage/custom [I]:** tintable materials and different viewing angles are real advantages. The movement
coverage is still exactly what we authored; real-time playback creates no missing motion. An unrestricted camera
also exposes the back of a model, bad skinning and hidden intersections that a single render angle can hide.
Start with two useful camera presets. Customs reuse approved tracks or get new ones; never solve a novel exercise
from its name at runtime.

**Size/offline [I]:** shared meshes/textures plus sparse curves can be smaller than ninety videos, but “tiny pose
files” is conditional. Sixty joints × four quaternion floats × four bytes × sixty samples/second × six seconds is
about **346 KB per clip for rotations alone**, before translations, equipment tracks and packaging. Sparse keyframes
can be much smaller; meshes/textures may dominate. This is arithmetic, not an asset-size measurement. Benchmark
battery, memory and frame pacing on the actual phone. Bundle approved assets and play one figure at a time; no
third-party runtime is needed. Do not implement both a general runtime IK engine and an offline renderer in v1.

### 4. Private markerless capture, used only as motion data

**Open question [U]: would the user accept a private, never-displayed take, processed locally, with the original
video deleted after validation?** The refusal to film for display does not answer this. Until answered, this route
is conditional. A properly licensed coach/performer could provide the take instead, with its own cost and release.

**[I] Pipeline:** capture a slow, reviewer-approved movement → detect body joints → remove bad frames and smooth
jitter → establish scale/coordinates → retarget to our CC0 skeleton → reconstruct machine contacts and rotations →
hand-correct and bake → render our figure. The app receives the animation, not the person's footage. Obtain rights
and consent to the reference take and derived motion. Do not use downloaded YouTube videos or competitors' demos.

**[F]** [Apple Vision](https://developer.apple.com/documentation/vision/identifying-3d-human-body-poses-in-images)
provides 17 three-dimensional joint locations from images; depth can help. These joints do not supply a full hand,
scapula, anatomical muscle model or machine rig. [MediaPipe Pose Landmarker](https://developers.google.com/edge/mediapipe/solutions/vision/pose_landmarker)
provides 33 landmarks and world-coordinate estimates; use the specifically licensed tracker/model, not a random
wrapper whose dependencies are unchecked. Apple Vision is an Apple-platform framework, not an open redistributable
model-weight grant.

**[F/I]** FreeMoCap offers an external capture pipeline. Its docs allow a [one-camera initial test](https://docs.freemocap.org/start/),
while calibrated multi-camera work is more suitable for recovering 3D geometry. Its
[Blender export](https://docs.freemocap.org/guides/blender-export/) supplies tracked skeleton/keypoint information,
not a polished anatomical athlete. A one-camera estimate should not be treated as metric ground truth.

**Effort/risk [I]:** allow 2–8 cleanup hours per straightforward exercise and 4–12 for machine-occluded movement,
after setup; some will still be quicker to keyframe. A bench, thigh pad or machine arm can obscure precisely the
joint we need. Mocap does not know which movement is safe, nor the machine's pivot/cable geometry. It may help
free-weight motion, but is not an automatic solution to this catalog. New customs require a new acceptable take and
review, or an exact existing motion match. Rendered outputs or approved tracks remain offline-capable.

### 5. Text-to-motion: research candidate, not the initial production source

**[I] Pipeline if rights are cleared:** choose a licensed checkpoint and body representation → generate joint
sequences → retarget onto our rig → add machine/contact constraints → correct poses and loop → review → export.
Outputting a skeleton instead of pixels makes errors more editable; it does not ensure correct form. A generated
press without a bench/pad/handle constraint is still missing the mechanism that defines many of our exercises.

**[F/U]** Common projects differ substantially: MDM code is MIT; T2M-GPT code is Apache-2.0; MotionDiffuse uses a
noncommercial licence. The first two commonly use HumanML3D/KIT checkpoints and sometimes SMPL-dependent tools.
Their permissive code licences do not establish commercial clearance of the whole pretrained pipeline. The audit
below is why I would not promise commercial-safe generated motions from those downloads.

**Cost/custom/risk [I]:** a rights-cleared system could draft custom motions, but every result still needs manual
acceptance. Own-data training is possible in principle, yet collecting a sufficiently varied licensed dataset and
training a model is a larger project than authoring ninety loops. There is no defensible full-library cost or
accepted-output rate from this research. The small feasibility allowance in the ranking is not an authorization to
use noncommercial data for a commercial app's R&D. Keep this fifth, and keep generation out of the shipping app.

## Licence audit: software, source assets and outputs are separate

**[F]** The quotations below are short deciding excerpts from primary sources checked on 2026-10-29. **[I]** The
shipping assessments apply to Stacked as a commercial-capable product whether its download is free or paid; a free
App Store price does not automatically make production noncommercial scientific research. “Conditional” means
specific obligations or rights remain to be resolved. No quoted grant proves the anatomical accuracy of an asset.

### Humans, rigs and equipment

| Candidate and source | Deciding words | Assessment for Stacked |
|---|---|---|
| [MakeHuman core graphics](https://www.makehumancommunity.org/about/license.html) | “All core assets are shared under Creative Commons, CC0.” | **Usable**, including commercial app assets and public-source distribution. Distinguish core graphics from MakeHuman AGPL software and MPFB GPL software. No mandatory attribution/share-alike for CC0 graphics. |
| [MPFB bundled assets/output](https://github.com/makehumancommunity/mpfb2/blob/master/LICENSE.md) | “These assets have been released under CC0 1.0 Universal.” | **Preferred.** The licence explicitly includes meshes, textures, rigs, poses and data; its output section covers scripted graphics, renders, exports and saved models. Third-party add-ons/assets still need their own checks. |
| [MakeHuman third-party extras](https://ww.makehumancommunity.org/mpfb/faq/use_in_closed_source.html) | “if you use a third party asset shared under a different license it is your responsibility to fulfill the obligations of that license.” | **Per-asset only.** Do not silently include community clothes, hair or morphs under the core CC0 label. |
| [Blender Human Base Meshes](https://www.blender.org/download/demo-files/) | “Human Base Meshes v1.4.1”; “49 MB – CC0” | **Usable**, but base geometry is not a ready motion library. Budget rigging, skinning and muscle-region work. No asset file was inspected here. |
| [Blender software and authored scripts](https://www.blender.org/about/license/) | “What you create with Blender is your sole property.” / “such scripts (if published) are being shared under a GPL compliant license.” | Original artwork is not forced under Blender's GPL. Blender's stated policy for published Python scripts matters in our public repo: license authoring scripts appropriately and separately from unrelated Swift. Imported art retains its own terms. |
| [Quaternius Universal Base Characters](https://quaternius.com/packs/universalbasecharacters) versus [current QAL](https://quaternius.com/license.html) | Pack: “Free to use in personal, educational and commercial projects. (CC0 License)” / QAL restriction: “Resell or redistribute the Assets themselves.” | **Conditional; conflicting grants need resolution for the exact release.** Current QAL permits completed commercial products but restricts raw/source asset redistribution. Do not commit a newly obtained model to public Git assuming the pack's CC0 badge settles it. A proven earlier CC0 acquisition is a different case. Stylized characters, not detailed muscle anatomy. |
| [Innerscene elliptical model](https://www.innerscene.com/tools/library/3d-parts/elliptical-gym-equipment-4457b0ef) | “Public domain (CC0). Free to use, modify and redistribute for any purpose, including commercially, with no credit required.” | **Published permission is usable; asset quality/provenance not independently audited.** Concrete free equipment lead, not proof of a rigged or exercise-correct model. An elliptical does not fill our leg-extension/pec-deck gaps. |

**[I] Prefer original primitive equipment for the pilot.** A bench, frame, pad, lever and bar can be made from boxes
and cylinders, with original unbranded geometry. Preserve meaningful pivot/contact locations; omit decorative
covers. General marketplaces are not one licensed asset set: inspect each item's licence, provenance, included
textures, articulation and editorial-use restrictions. A static decorative “gym pack” is not a working exercise rig.

### Motion capture datasets and generators

| Source | Deciding quotation | Paid/free Stacked use |
|---|---|---|
| [Original CMU mocap](https://mocap.cs.cmu.edu/) | “You may include this data in commercially-sold products, but you may not resell this data directly, even in converted form.” | **Usable in a finished product**, not a motion-resale product. Not CC0. Existing research found sparse relevant gym motion and almost no machine work. A CMU subset converted into AMASS is not the same licence route. Use the original source's terms; do not crawl it. |
| [Mixamo official FAQ](https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html) | “You can use both characters and animations royalty free for personal, commercial, and non-profit projects” | **Usable for licensed rendered/embedded projects**, free with an Adobe ID; not an open-source/CC0 asset grant. Earlier coverage research remains thin on bench/deadlift/rows and machines. |
| [Adobe's Mixamo licensing FAQ](https://community.adobe.com/questions-696/mixamo-faq-licensing-royalties-ownership-eula-and-tos-589400?lang=en) | In the prohibited column: “Any type of free distribution of character or animation raw files” | Keep raw Mixamo rigs/motions outside the public repo. Commercial product use does not imply permission to redistribute a source animation pack or use it for ML training. |
| [AMASS](https://amass.is.tue.mpg.de/license.html) | “This license also prohibits the use of the Dataset to train methods/algorithms/neural networks/etc. for commercial use of any kind.” | **Not approved for Stacked without another grant.** The terms also bar commercial products/services/artifacts and redistribution. Rendering a licensed-research motion into MP4 does not remove that restriction. |
| [HumanML3D](https://github.com/EricGuo5513/HumanML3D) | “Due to the distribution policy of AMASS dataset, we are not allowed to distribute the data directly.” | **Data not commercially cleared.** Its MIT software licence does not clear the AMASS/SMPL+H/DMPL reconstruction dependencies or data. |
| [Bandai Namco motion datasets](https://github.com/BandaiNamcoResearchInc/Bandai-Namco-Research-Motiondataset) | Both datasets: “CC BY-NC 4.0”; separately: “Motion visualization on Blender: MIT” | **Dataset motions not approved for this commercial-capable app without permission.** The MIT visualizer does not relicense the motions. Broad action/dance motions are not a machine-exercise library. |
| [MDM code](https://github.com/GuyTevet/motion-diffusion-model/blob/main/LICENSE) and [checkpoint documentation](https://github.com/GuyTevet/motion-diffusion-model) | Code: “MIT License” | **Code usable; pretrained production pipeline not cleared.** HumanML3D/KIT and optional SMPL dependencies require separate scrutiny. A checkpoint's MIT label alone does not answer dataset/output rights. |
| [T2M-GPT licence](https://github.com/Mael-zys/T2M-GPT/blob/main/LICENSE) and [README](https://github.com/Mael-zys/T2M-GPT) | “Apache License”; “Version 2.0, January 2004” | **Code usable; pretrained pipeline/output position unresolved.** The README uses HumanML3D/KIT-ML. Do not infer a clean commercial motion library from the code licence. |
| [MotionDiffuse](https://github.com/MotrixLab/MotionDiffuse/blob/main/LICENSE) | “Redistribution and use for non-commercial purpose in source and binary forms, with or without modification, are permitted” | **Noncommercial code itself.** Not an MIT commercial production-tool shortcut. |
| [SMPL-Body](https://smpl.is.tue.mpg.de/license.html), with [Model FAQ](https://smpl.is.tue.mpg.de/faq.html) | “SMPL-Body is licensed under the Creative Commons Attribution 4.0 International License.” | **Distinguish Body from Model.** A licensed body asset is not the restricted body-generation model/shape space. Commercial Model use needs its own licence; Body's CC BY does not clear AMASS or the generation process. |

**[U] AI outputs require a layered assessment:** code, weights, training-data obligations, body-model dependency,
and output terms. Restrictive training data is not by itself proof that every generated pose infringes copyright;
permissive Python is equally not proof that commercial use is cleared. Resolve the actual pipeline with its
licensor before adopting it. Nothing in this report certifies a pretrained text-to-motion system for Stacked.

### Capture tools and anatomy

| Source | Deciding quotation | What it does—and does not—permit/provide |
|---|---|---|
| [FreeMoCap FAQ](https://docs.freemocap.org/about/faq/) | “FreeMoCap is licensed with the GNU Affero General Public License (v3)” | Commercial use of an AGPL authoring tool is possible under its terms; distributing or hosting modified software has obligations. Keep it external to Stacked. It is not a finished exercise avatar. |
| [GNU output FAQ](https://www.gnu.org/licenses/gpl-faq.en.html#WhatCaseIsOutputGPL) | “The output of a program is not, in general, covered by the copyright on the code of the program.” | **[I]** Processing our own authorized footage does not generally make joint coordinates or renders AGPL. Inputs, copied program material and bundled third-party models retain their rights. |
| [MediaPipe code](https://github.com/google-ai-edge/mediapipe/blob/master/LICENSE) and [linked BlazePose model card](https://storage.googleapis.com/mediapipe-assets/Model%20Card%20BlazePose%20GHUM%203D.pdf) | Code: “Apache License”; model card: “LICENSED UNDER Apache License, Version 2.0” | **Usable for this licensed offline processing path**, with applicable notices. The model card is separate evidence for the linked Pose Landmarker model family; it does not license every model or wrapper on the internet. No MediaPipe runtime need ship in the app. |
| [OpenSim software](https://github.com/opensim-org/opensim-core) | “Licensed under the Apache License, Version 2.0.” | **Software permits commercial use** under its terms. A biomechanical simulator, not a ready anatomical skin/rig or a universal form validator. No reason to embed it in v1. |
| [Specific OpenSim gait model](https://github.com/opensim-org/opensim-models/blob/master/Models/Gait10dof18musc/subject01.osim) | “License: Creative Commons (CCBY 3.0).” | This model has its own attribution licence; accompanying geometry and other SimTK/OpenSim models need their own checks. A reduced gait model is not an upper-body/neck exercise demonstrator. |
| [Current direct BodyParts3D release](https://dbarchive.biosciencedbc.jp/data/bodyparts3d/LATEST/README_e.html) | “Creative Commons Attribution 4.0 International” | **Commercially usable with attribution and other BY conditions.** The official licence was updated in February 2025; do not repeat old BY-SA 2.1 Japan labels as the current direct release's terms. Anatomical meshes still need selection, fitting, simplification and skinning. |
| [Z-Anatomy distributed-model licence](https://github.com/LluisV/Z-Anatomy/blob/PC-Version/Resources/Models/License.txt) | “CC-BY-SA 4.0”; also “Kidney - by lissiecowley - CC-BY-NC 4.0” | **No blanket commercial clearance for the whole atlas.** The inventory also lists NC inner-ear material and other sources requiring verification. A specifically audited muscular subset may be usable with SA/credits; the overall badge is insufficient. Prefer original masks or direct BodyParts3D over inheriting this mixed provenance. |

For BodyParts3D, retain the attribution the official README specifies: **BodyParts3D, © The Database Center for
Life Science licensed under CC Attribution 4.0 International**, plus an appropriate licence link and modification
notice. The newer upstream licence does not automatically relicense independent Z-Anatomy modifications.

**[I] My tint recommendation:** paint/author a small number of superficial muscle-region masks on the approved
mannequin and bind them to its skin. Review primary/secondary selection separately from animation. Do not import
thousands of organ meshes just to color a quad; do not present a static target tint as measured muscle activation.
Full anatomical assets are an optional later art project, not a prerequisite for the three-exercise pilot.

### Existing exercise media: a short recheck, not another source survey

| Source | Deciding published line | Carry-forward conclusion |
|---|---|---|
| [wger](https://github.com/wger-project/wger) | “Exercise/Ingredient Data: Creative Commons (see individual entries)” | **Conditional per item.** Preserve author/source/licence/change notices and applicable BY-SA duties. The app code's AGPL and each media item's licence are different. Earlier thin/mixed animation coverage still makes this supplementary. |
| [Everkinetic licence](https://github.com/everkinetic/data/blob/master/LICENSE.md) | “Attribution-ShareAlike 4.0 International” | Commercial adaptation is possible with credit/SA. Two poses are not verified continuous motion; making intermediate frames remains authoring work. |
| [free-exercise-db](https://github.com/yuhonas/free-exercise-db) | Repository label: “Unlicense” | **Image provenance remains unresolved**, as in prior research. A public-domain repository label only grants rights its publisher possesses. Do not treat the photos as a verified animation/reference pack. |
| [Specific Commons squat video](https://commons.wikimedia.org/wiki/File:Squat_-_exercise_demonstration_video.webm) | “Creative Commons Attribution 3.0” | A per-file commercial licence with credit, not a site-wide grant. Verify creator/source and file-specific terms. Do not download its YouTube source or assume every Commons file shares these terms. |

**Bundling and public-repo duties [F/I].** CC0/core-original assets simplify both. BY requires credit, licence and
change notices; SA additionally governs adapted assets such as modified meshes, textures or clips. Merely collecting
separate licensed art with independent Swift code does not automatically place that Swift code under SA. But do not
add incompatible EULA restrictions or effective DRM to the licensed material. CC's deciding line is **“You may not
apply legal terms or technological measures that legally restrict others from doing anything the license permits.”**
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

This is not a blanket ban on app bundling, nor a promise that a second unrestricted download automatically cures an
App Store/DRM conflict. Check the actual distribution and asset terms; obtain an additional grant if needed.
Keep licences/attributions attached to assets and exclude them from contradictory app-wide terms. Never publish
restricted Mixamo/QAL/Gym visual source files simply because the rest of Stacked is public. No GPL/AGPL authoring
program is included in the iPhone binary under the recommended pipeline.

## Reverse engineering: useful scope and firm boundaries

**[I] Use the previous lawful observations to write an independent media specification:** approximately 4–8 seconds,
one readable repetition, fixed useful camera, stable figure scale, visible contacts, consistent tint, pause/replay
and offline operation. Those observable design choices are enough to guide our original implementation; we do not
need a competitor's mesh or motion file.

Useful further work, when authorized and permitted:

- Read genuinely published open-source rendering/import pipelines under their licences; learn architecture and
  interoperability rather than copying code whose licence we will not meet. A source-code licence does not license
  the separately purchased artwork used by that app.
- Study documented skeletal formats and inspect **our own** exports: axes, rest transforms, bone hierarchy,
  skin weights, timestamps and looping. For example, the [glTF specification](https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html)
  documents skinning/keyframes; an interchange specification is not a finished runtime loop implementation.
- Measure our own or properly licensed benchmark playback: duration, dimensions, frame rate, file size, loop seam,
  device decoding and background pause. A format conversion does not grant rights to an unauthorized source.
- Inspect our Blender-to-RealityKit round trip if we later choose native 3D; resolve exported-pose differences using
  our own rig and test poses.

**Do not extract, trace, rotoscope, pose-extract or reconstruct another company's animation/3D asset as a shortcut
without the specific rights—and this task's boundary excludes that route.** Do not strip watermarks, decrypt App
Store executables, download APK mirrors, scrape blocked catalogs or use YouTube files as mocap. Re-rendering stolen
motion on a new figure does not make the source rights disappear. Site terms must precede any automated observation;
where automation/competitive research is prohibited, use first-party public statements surfaced by ordinary search.
No new competitor inspection or third-party execution was performed for this report.

## A bounded first experiment for route 1

**[I] Objective:** three original 6-second loops—leg extension, pec deck and barbell bench press—using one approved
core body, original simplified equipment and original motion. Two machine mechanisms plus a shared bar test the
pipeline better than a free-standing curl. No muscle-atlas import, general IK engine or AI motion generator in this
first experiment.

| Step | Work and division of responsibility | Human-hours estimate |
|---|---|---:|
| 1 | Define exact variants, camera, contact points and licence inventory; agent records a versioned manifest, human checks the grant | 2–4 |
| 2 | Set up the future Blender/MPFB environment, choose core assets, create one reusable scene and verify knee/elbow/shoulder deformation | 6–12 |
| 3 | Agent scripts original bench/bar, leg-extension frame/lever/pad and pec-deck arms; human checks geometry against authorized factual references | 6–12 |
| 4 | Author 4–6 key poses per lift; add hand/foot targets and pole controls, adjust torso and machine paths, bake and inspect intermediate frames | 14–24 |
| 5 | Create original target masks, one material/light treatment, useful camera and a continuous 4–8-second loop | 4–8 |
| 6 | Human animation/form review, slow playback and corrections; agent can measure drift but cannot approve technique | 5–10 |
| 7 | Export poster/MP4 and prototype one native player reused on exercise detail and workout sheet; test offline and Reduce Motion | 3–6 |
| **Total** | No third-party execution is part of this research; these are future implementation steps | **40–76** |

**Proof/kill criteria [I]:** at roughly 12 hours, the core rig should bend acceptably before detailed equipment work.
By 40 hours there should be three rough but mechanically coherent loops. By 80 hours, either all three have passed
visual/form review at phone size or stop and re-estimate/commission help. Reject floating grips, slipping feet,
intersecting pads, implausible joint motion and discontinuous loop resets; do not hide them with a camera angle.
The reviewer must be able to recognize the intended variation. Confirm original/licensed provenance, consistent
light/dark presentation, pause/Reduce Motion behavior, no interference with rest-alarm audio and offline relaunch.
Then estimate the remaining 87 from observed per-family throughput, including review and exceptions.

**[I] Proposed repository boundary:** read-only media manifest keyed by existing seeded UUIDs; original pose data
with rig-version, equipment parameters, keyframes/contact targets and muscle IDs; a private/original asset-authoring
workspace; rendered media or approved runtime assets loaded by one shared exercise-media view. Public authoring
scripts and assets get their actual licences. Seeded read-only media need not add a SwiftData field. Durable custom
media associations and user clips require their own persistence/export/deletion design; the existing Gate S/ticket
11 obligations must not be avoided by hiding user data in an ad-hoc file or defaults key.

## Keep the $18.10 pilot—but use it correctly

**[I] Yes:** if the stated small cost is acceptable, the ten-item pilot is a useful benchmark and fallback while the
DIY experiment is capped. Compare clarity, framing, muscle-region legibility and loop quality by human viewing.
Judge the DIY clips at the same on-phone size; a beautiful Blender viewport is not the final deliverable.

**[F]** Gym visual's [licence](https://gymvisual.com/content/9-license) explicitly includes **“Android or iOS mobile
application (apps)”** among permitted uses. Its AI restriction includes **“to use as a basis for creating and
generating content”** with **“using Artificial Intelligence (AI) tools and technologies”**. Keep purchased files
private and do not supply them to an agent/model as visual or motion-generation inputs. Bundled delivery is the
project's current agreed route; a later R2/on-demand design needs its own terms check. This recommendation does not
reopen the cart or make a purchase, and no purchased or third-party file was downloaded here.

**[U] Decisions still needed before implementation:** whether private never-shown capture is acceptable; whether a
stylized figure is sufficient or detailed anatomical realism is essential; and whether the user prefers the bounded
DIY learning project over the much shorter licensed-clip path. My recommendation is to learn with the three-clip
Blender experiment, not commit to authoring all ninety until it passes.

Done.
