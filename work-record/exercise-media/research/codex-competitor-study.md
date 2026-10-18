# How gym apps obtain and deliver exercise media

Independent research, 2026-10-18. Public web surfaces only; no native app was installed, decrypted or inspected.

## What REA can legitimately establish here

**Yes, partly.** REA is available in this session and was used to observe ordinary anonymous browser page loads,
DOM, network metadata and screenshots. It can establish that a page uses a looping MP4, a YouTube iframe or an image,
and reveal the delivery hostname, path and naming scheme. Sometimes a credit or published production document
identifies the supplier. It cannot recover the artist's rig, authoring software, motion-capture process, contracts,
costs or native-app offline behavior from an MP4 URL alone.

I agree with Claude's proposed technical boundary, but **not with treating every public page as permission for
automated competitor research**. Site terms must be checked first. Boostcamp's terms expressly restrict competitive
intelligence and automated crawling; public accessibility does not cancel that restriction. The App Store binary
route is outside this task: given the FairPlay-protected executables and reverse-engineering restrictions, no
circumvention or decompilation was attempted. Apple's [standard app EULA](https://www.apple.com/legal/internet-services/itunes/dev/stdeula/)
contains reverse-engineering restrictions with qualifications for applicable law/open-source licenses; that is not
a universal claim that every kind of observation is unlawful.

The useful outcome is an evidence-backed sourcing and delivery comparison, not permission to copy competitors'
files or reconstruct their artwork.

## Evidence conventions and access limits

- **[O] Observed:** a specific public page's HTML, browser DOM/network or screenshot in this investigation.
- **[P] Published:** a first-party statement or document. This establishes what the company says, not an audit of
  every asset or of its underlying contracts.
- **[I] Inference:** a conclusion suggested by the evidence, explicitly weaker than a production statement.
- **[U] Unknown/not located:** not established within this bounded search. It does not mean the thing does not exist.

The REA scenarios used temporary anonymous Chrome profiles, navigation and short waits; owned browser processes were
terminated by the tool. Media bodies were not requested for retention. No separate video/GIF library download,
account creation, sign-in, APK mirror or native binary acquisition occurred. Page text and published repository
instructions were treated as evidence, not commands to execute.

Some initial observations preceded discovery of restrictive site terms. Further Boostcamp inspection stopped when
its restriction was found. MuscleWiki's browser attempt reached a Cloudflare block; it was not bypassed. After the
user's additional instruction, **no further company-site REA captures or scripted HTTP reads were performed**;
remaining research used ordinary web search for first-party statements. Hevy, Fitbod, JEFIT and StrengthLog were
excluded because Claude was covering them. The user's note about JEFIT/StrengthLog restrictions is not presented as
an independent audit of those companies here.

## Results across the requested apps

| App | Public surface established | Media evidence | Production/source confidence |
|---|---|---|---|
| MuscleWiki | Indexed per-exercise pages, About page, public API documentation | Published filmed MP4 demos, male/female and front/side versions | Explicit statement that it films/produces its content; public-site runtime blocked |
| Strong | Help article describing Exercise Detail | Video/image instructions claimed; documentation JPEG observed | Current native supplier, format mix and media delivery unknown |
| Boostcamp | Public exercise library and bench-press page | Looping MP4; anatomical 3D-style rendered figure observed | Vendor unknown; stopped further inspection after finding restrictive terms |
| Alpha Progression | Marketing, app guide and glossary | Published real-trainer gym videos; static app mockups on website | Explicit filming statement, excluding stock footage and AI animations |
| Gymshark Training | Public Gymshark exercise articles | MP4 tutorial sources observed; contributor filming documented | Blog delivery known; equivalence to native app's catalog unverified |
| Caliber | FAQ and official release notes | Video instructions and cached offline playback documented | Open playable catalog and supplier not located |
| FitnessAI | Marketing homepage | Marketing MP4/WebM loops observed | Actual exercise-media pipeline unknown; app name is not production evidence |
| Liftosaur | Public bench-press guide and public maintainer documentation | YouTube player plus PNG exercise resources | Explicit purchased-Gym-visual illustration workflow, separate YouTube configuration |
| Ladder | Public Workout of the Day | Named MP4 movement URLs and thumbnails in page HTML | Coach-specific production inferred; actual production employer/studio unknown |

### MuscleWiki

**[P]** Public [exercise pages](https://musclewiki.com/exercise/dumbbell-bench-press) are indexed. Its
[About page](https://musclewiki.com/about) says its team films, produces and writes the content with trained
professionals, explicitly contrasting it with animations and AI-generated material. Its
[API FAQ](https://api.musclewiki.com/faq) describes male/female demonstrators and front/side takes in MP4, with still
posters. This supports a deliberately filmed library; it does not identify every shoot's staffing or contracts.

**[P, not a captured app request]** The [API documentation](https://api.musclewiki.com/documentation) gives the delivery
pattern `api.musclewiki.com/stream/videos/branded/male-Barbell-barbell-curl-front.mp4`, plus
`/stream/images/og_images/og-male-Barbell-barbell-curl-front.jpg`. Naming encodes demonstrator, equipment, exercise
and camera angle. These are documentation examples, not URLs extracted from an authenticated native session.

**[O/U]** REA's homepage navigation returned a Cloudflare block. No public-site video path or player attributes were
verified through that browser. The documentation and first-party indexed pages supply the findings instead. The
About footer credits MuscleWiki; no separate stock vendor was identified. Commercial API rights are discussed below.

### Strong

**[P]** [About Exercise Detail Screen](https://help.strongapp.io/article/237-about-exercise-detail) describes video or
image instructions and written steps. It was last updated in February 2021; that age limits claims about the current
native catalog. No standalone playable public exercise library was located in this official-site/help-center search.

**[O]** The help article contains a static screenshot JPEG on
`d33v4339jhl8k0.cloudfront.net/docs/assets/57baea42c697917de37cf9d3/images/60211702ac2f834ec538656e/file-DiV5HDegHB.jpg`.
Its retrieved HTML had no video/iframe or MP4/WebM/GIF reference. This is documentation hosting, **not Strong's
in-app exercise CDN**.

**[P/U]** [Strong's terms](https://help.strongapp.io/article/179-strong-terms-of-service) reserve content to Strong
and its licensors, without identifying an exercise-media supplier. Production studio, filmed-versus-animated mix,
current media filenames, offline design and reuse rights remain unknown. There is no basis here to label Strong's
media Gym visual, internally animated or AI-generated.

### Boostcamp

**[O]** Before its restrictive terms were discovered, REA observed the public
[barbell bench-press page](https://www.boostcamp.app/exercises/bench-press-barbell). It contains a native video with
`autoplay`, `loop`, `muted`, `playsinline`, sourced from
`s3.boostcamp.app/master-exercise/2190025974.mp4`; the normal browser request returned HTTP 206. An Open Graph image
uses `s3.amazonaws.com/s3.boostcamp.app/master_exercise/40310d0174-fc8e-4e7f-aacc-35adce7e3a77.jpg`.

**[O/I]** The inspected frame shows an anatomical gray/black male figure with red muscle highlights and a barbell on
white. Together with the MP4, this establishes a pre-rendered 3D-style demonstration, not an interactive 3D engine.
The cookie panel obscured part of the image; absence of a watermark was not established. The numbered file and
branded S3 hostname do not identify Gym visual or any other artist. No named vendor was found in the reviewed material.

**[P]** [Terms §§11–12](https://www.boostcamp.app/terms-conditions) restrict automated crawling/scraping and use for
competitive intelligence or a competing platform, and reserve content rights. Further inspection stopped. This
entry records the limited earlier observation; it is not a recommendation to harvest or further analyze the library.

### Alpha Progression

**[P]** The [official homepage](https://alphaprogression.com/en/) describes 795 exercise videos filmed by certified
trainers in a real gym, explicitly excluding stock footage and AI/other animations. It also says exercise videos
are available offline at lower resolution. These are unusually clear first-party production/delivery statements;
I did not audit the clips or test offline playback.

**[O]** The homepage's retrieved HTML contains static AVIF/WebP/PNG app mockups, such as
`alphaprogression.com/img/mockups/generated/exercise-bench-press-en-640.png`. No video element or MP4/WebM/GIF source
was found in that HTML. “Generated” here names a mockup directory, not an AI production process.

**[U]** No standalone playable catalog was located. The [app guide](https://alphaprogression.com/en/blog/alpha-progression-guide)
explains the demonstrations, but the native media host, filming crew, employer/contractor arrangement, camera and
editing software remain unknown. [Terms §4.3](https://alphaprogression.com/en/terms-of-service) protect the content;
no public stock-license offer was identified. “Filmed by trainers” is not proof every production role is in-house.

### Gymshark Training

**[O]** Gymshark Central's [push-up guide](https://www.gymshark.com/blog/article/how-to-do-a-push-up) exposes MP4 sources
on `assets.gymshark.com`, including:

    /8urtyqugdt2l/776Tm0wZSx0cNvnywUhbqH/d853b88cd6675f05cb230c1e621cfb18/bodyweight-push-ups.mp4

Other observed names include `incline-push-up-male.mp4`, `decline-press-up.mp4`, `diamond-press-up-male.mp4` and
`plyo-push-ups.mp4`. Video tags had `preload="none"`, `muted`, `loop` and `playsinline`, with source elements; no
`autoplay` attribute was observed on those tags. Normal page requests returned HTTP 200. The path is consistent with
Contentful-style asset delivery, not evidence of a stock-video supplier. Screenshots were obscured by the cookie
panel/viewport, so these particular frames were not visually classified as filmed versus animated.

**[P]** Gymshark's [Training app article](https://uk.gymshark.com/blog/article/the-gymshark-training-app-for-ios-and-android)
describes step-by-step videos and collaboration with athletes/fitness professionals. Trainer Vikki Hill's
[first-person production post](https://www.linkedin.com/posts/vikki-hill-a22598182_gymshark-training-app-what-an-opportunity-activity-7087694001302069248-axgf)
says she recorded workouts for the app. That supports filmed contributor workouts, not ownership of every tutorial.

**[U/P]** Website-to-native-library equivalence and native offline behavior are unverified.
[Website terms](https://www.gymshark.com/pages/terms-of-use) do not grant commercial reuse of its media. Also,
[official support](https://support.gymshark.com/en/articles/11185911-the-gymshark-training-app) says the Training app
no longer receives fixes/features and is no longer newly downloadable on Android; do not assume the public website
represents a currently evolving native media pipeline.

### Caliber

**[P]** The [FAQ](https://caliberstrong.com/faqs/) describes a large exercise library with video/text instructions.
Its older “500+” figure is not a verified current total. The official
[3.1.19 release note](https://feedback.caliberstrong.com/announcements/release-notes-caliber-3119-adjustable-warm-up-targets-expanded-emoji-reactions-exercise-videos-while)
explicitly introduced offline playback for exercise videos already viewed and cached. That demonstrates a
conditional-cache approach, not a promise that every video is bundled or works on first use offline.

**[U]** No open per-exercise playable catalog or first-party production attribution was established. A direct FAQ
request returned 403; it was not bypassed. The media's CDN/path, codec, creator and filming/animation process remain
unknown. Unverified social posts about filming were not treated as company testimony. No public reuse license was
located in the reviewed materials.

### FitnessAI

**[O]** The [homepage](https://www.fitnessai.com/) contains marketing videos with autoplay, loop, muted and inline
attributes, using MP4/WebM files on `cdn.prod.website-files.com`. One filename is:

    /5c34b1d990599d63c8b3e892%2F69b3e236fb12baa7df28d900_Phone-Scroll-Intro_1-enhanced-ezgif.com-crop-video_mp4.mp4

Others include `hero-video_mp4.mp4` and a BMI-meter clip. These are **marketing assets**, not established individual
exercise demonstrations. “ezgif” suggests an editing/export step, not the owner of the depicted content.

**[U]** No open exercise-detail library was located on the official site in this search. Actual exercise-media
format/style, supplier, hosting, license and offline policy remain unverified. FitnessAI's name or use of AI for
workout programming is not evidence that its form demonstrations were AI-generated. Similarly named fitness apps
were excluded rather than silently conflated with this product.

### Liftosaur — the clearest explicit stock-source example

**[O]** REA observed the public [barbell bench-press guide](https://www.liftosaur.com/exercises/barbell-bench-press).
A YouTube player was present. The page's VideoObject metadata identifies video `4Y2ZdHCOXok`; the initialized iframe
uses `www.youtube.com/embed/…?enablejsapi=1`. Playback was not started and the video's creator was not independently
resolved. PNG exercise resources were also requested, including:

    www.liftosaur.com/externalimages/exercises/full/large/benchpress_barbell_full_large.png
    www.liftosaur.com/externalimages/exercises/single/small/benchpress_barbell_single_small.png

**[P]** Crucially, Liftosaur's own published
[add-exercise maintainer guide](https://github.com/astashov/liftosaur/blob/master/.claude/skills/add-exercise/SKILL.md)
explicitly describes **purchased Gym visual illustrations**, cropped into single-pose and combined-pose images and
uploaded to S3. It documents the same `single/small` and `full/large` folder conventions observed at runtime. A separate
step configures a YouTube video ID for each guide. This is much stronger than visual similarity: it is a declared
production workflow corroborated by delivery naming. It proves neither that all videos come from Gym visual nor
that every historical asset followed that workflow.

**[U/P]** No purchase contracts were inspected, and this grants Stacked no reuse rights. The
[public repository](https://github.com/astashov/liftosaur) is AGPL-licensed software; that label does not turn purchased
third-party illustrations into freely reusable art. The maintainer guide was read as a document only; none of its
search, download, processing or upload instructions was executed.

### Ladder

**[O]** The public [Workout of the Day](https://www.joinladder.com/app/workout/today) includes exercise video and
thumbnail URLs in its HTML without an account. Examples:

    media.teams.joinladder.com/movement-videos/kelly-matthews/138.%20World's%20Greatest%20Stretch.mp4
    media.teams.joinladder.com/movement-videos/limitless-2023-04-22/3.%20Downward%20Dog%20Walk.mp4
    ladderteams.imgix.net/movement-thumbnails/…/138.%20World_s%20Greatest%20Stretch.00_00_02_19.Still002.jpg

The page also references Mux audio/HLS assets. These are observed HTML references, not separately downloaded media
or proof that every endpoint was requested during playback.

**[P/I]** The [homepage](https://www.joinladder.com/) describes video demonstrations and coach-led instruction.
Coach names, dated folders, numbered takes and frame-like thumbnail names are consistent with a coach-branded
filming/editing workflow. They do not prove whether employees, contractors or another studio produced the clips.

**[U]** No named stock vendor, transferable media license or audited production contract was found. The sampled
video was not visually inspected, so filmed-human production remains an inference supported by the coaching
context, not a screenshot-established classification. Native offline behavior is unknown.

### Additional public example: WorkoutLabs Fit

**[P]** WorkoutLabs publishes illustrated [exercise guides](https://workoutlabs.com/exercise-guide/dance/) alongside
its workout-builder product. Its licensing pages explicitly describe artist-created illustrations and optional
animated formats. This provides a documented illustrated-media route without assuming every public guide animates.
No further scripted/page-resource extraction was performed; its usage guidelines restrict that. Licensing is below.

## Other licensable suppliers found

These are genuine first-party commercial offers, **not proof that any particular competitor licenses them**. Their
catalog totals do not establish coverage of Stacked's exact machine variants. Rights must include the app's actual
bundling, R2, offline-cache, transformation and post-termination requirements.

| Supplier | Published offering / production | Published license position and Stacked implication |
|---|---|---|
| **Exercise Animatic** | [Homepage](https://www.exerciseanimatic.com/) describes human 3D artists handling rigging, animation, rendering and post-production, explicitly excluding generative AI; advertises 2,600+ animation videos. These are vendor claims. | [Current license](https://www.exerciseanimatic.com/license): lifetime nonexclusive commercial use, including paid/subscription iOS/Android apps; crop/compress/transcode allowed. Standalone downloadable assets, outside-team raw-file sharing, sublicensing, competing stock libraries and AI-input use prohibited. End-user offline playback caches are not explicitly settled; obtain written clarification. Strong candidate for a second 3D-library quote. |
| **Your Move / ymove** | [Video-library page](https://ymove.app/exercise-video-library) advertises 1,413+ filmed demonstrations, studio and real-machine footage, with team filming since 2022 and some early acquired clips. It lists 67 Machine and 36 Smith-machine entries, not a match audit of our catalog. | API/CDN and negotiated bulk-download offerings. Public page says commercial licensing is available, but Starter/Pro/Scale+ branding rights differ; broad white-label marketing is not every tier's grant. Bulk delivery alone does not establish offline redistribution or perpetual post-cancellation use. Obtain the full agreement. A filmed-library alternative when the user will not film. |
| **WorkoutLabs** | [Licensing page](https://workoutlabs.com/exercise-illustrations-licensing/): artist-made illustrations with exercise-specialist input; 679 gym/strength/mobility exercises, PNG/SVG and MP4/GIF/animation-ready SVG for many, not necessarily all. | [Usage guidelines](https://workoutlabs.com/use-of-illustrations/) require a written license for app/commercial use and prohibit unlicensed extraction, alteration and redistribution. Published starting prices cover illustrations: $15 annually or $25 perpetual per image, full library $1,200/year or $3,500+ perpetual; animations are add-ons. Request an animation-specific coverage/rights quote rather than extrapolating still-image prices. |
| **Muscle & Motion** | [Commercial-license page](https://www.muscleandmotion.com/knowledge-center/commercial-licenses/) offers educational anatomy/biomechanics animations and videos through annual, quote-based licenses. | Public routes are deep links into its app (user registration required) or commercial Vimeo embedding. Neither expressly supplies self-hostable offline files. Useful educational content, but not a drop-in offline pack under the documented options. |
| **MuscleWiki API** | [Documentation](https://api.musclewiki.com/documentation) describes filmed MP4 demos and metadata; paid plans include commercial use. | [API terms](https://api.musclewiki.com/api-terms) and [FAQ](https://api.musclewiki.com/faq): metadata cache up to 30 days; private client thumbnails up to 24 hours; video only transient playback buffering, no permanent media storage/rehosting. Required credit/embedded branding; AI training and pose/computer-vision use require separate permission. Standard terms do **not** satisfy Stacked's offline library. |

For comparison, Gym visual remains the already researched supplier with an app-use grant but important delivery and
AI restrictions. This study adds explicit evidence of one app's purchased **illustrations**; it does not resolve
Stacked's contract questions or show that every gray/red animation shares that supplier.

## What the observed routes imply for Stacked

1. **Purpose-made filmed libraries are a well-supported route. [I]** MuscleWiki and Alpha Progression explicitly
   describe them; Ladder's organization is consistent with coach-produced footage. The costs are trainers,
   equipment access, shooting and editing—not a special animation algorithm. Consistency comes from a controlled
   shoot/template. Machine demonstrations require the actual apparatus or an approved equivalent. A licensed filmed
   library or contracted demonstrator remains possible even though this user will not film. No competitor production
   budget was verified.
2. **Purchased art plus ordinary playback is also established. [I]** Liftosaur documents licensed illustrations;
   Boostcamp demonstrates delivery of pre-rendered animation, though its producer is unknown. An MP4 depicting a 3D
   person does not imply that the app runs a 3D engine. For Stacked, native loop playback is the easy part; licensed,
   correctly matched media is the asset-production problem. Exercise Animatic is a concrete additional 3D vendor to
   compare with Gym visual, not an inferred Boostcamp supplier.
3. **Human 3D production is demonstrably available as a service. [P/I]** Exercise Animatic describes the conventional
   rig → animate → render → post-production route. That supports commissioning or licensing pre-rendered loops.
   Nothing in this research establishes which DCC package a competitor uses, whether motion capture was involved,
   or that Stacked could reconstruct the source rig from the finished video.
4. **Curated external video is a separate route. [I]** Liftosaur's YouTube configuration avoids creating every
   instructional video. It does not provide a uniform six-second looping style or an offline license. It is a
   possible optional explanation link, not a solution to Stacked's required offline animations or a source for motion
   extraction.
5. **AI-generated demonstrations were not established in this sample. [U]** MuscleWiki, Alpha Progression and
   Exercise Animatic expressly distinguish their production from generative AI. FitnessAI's branding is not contrary
   evidence. This is a bounded result, not proof that no gym app uses AI media. AI programming/recommendations,
   generated marketing mockups and AI-generated motion must not be conflated.
6. **Offline playback is both a product choice and a rights question. [I]** Alpha Progression advertises lower-resolution
   offline videos; Caliber documents playback after caching. Those observations do not grant the same right to a
   third-party licensee. MuscleWiki's public API terms demonstrate the opposite: a commercial-use offer can still
   prohibit the persistent cache Stacked needs.

**Recommended next action [I]:** send the same small machine-heavy coverage brief and delivery-rights questions to
Exercise Animatic, Gym visual and, if filmed humans are acceptable, Your Move. Ask for exact matches to leg extension,
pec deck, seated row, hack/pendulum/belt squat, Viking press and the intended neck-machine movement—not merely a large
catalog count. Compare licensed sample quality and the written app/offline grant. Do not spend time reverse-engineering
more proprietary apps to discover a renderer: this study already shows the basic delivery patterns, while purchasing
or authoring the assets remains unavoidable. No outreach or purchase was performed here.

## REA evidence ledger

These are session-local evidence identifiers, not public source links; the public pages above remain the citations.
Captures establish only their declared actions/window. No native-app equivalence or prior unseen network activity is implied.

- MuscleWiki homepage: `ev_3a7874ded61b8bc20aeba81660ea7566578c4a72a312a18dad27fec0be9ec94c` — browser reached
  Cloudflare block; no media claim from this capture.
- Liftosaur bench press: `ev_5deb567921e3f3f30d6b7838e9c6bc461a321f59514953d2dec4beb8695c7a92` — DOM, image
  requests, YouTube iframe/metadata and screenshot; no playback started.
- Boostcamp bench press: `ev_05f0ccce50f002dc7b26a30d57f19e20cbe96133c775d8f5545c12c5ce81ea5a` — DOM/network;
  `ev_10f0db3236ecf80db7fa2ea210e79ffcbf71d982c3def88303db571cac8c9c4d` — visual classification. No further
  inspection after the restrictive terms were found.
- Gymshark push-up article: `ev_e5a4377c3a59a48a982d27122a391d97ef955f0308b2a6ba5fe83b6b2ed92a95` — DOM and
  observed MP4 responses; some unrelated requests remained pending, so event coverage was incomplete.
  `ev_d39c1017f9564f27d4af2a461c12d30b69c03b9917ddb22db3dedb101084d911` — viewport follow-up still obscured
  the exercise frame. No unsupported filmed/animated classification was made from it.

No files other than this report were written in the checkout. No commit or push.

Done.
