# How other gym apps source exercise media — Claude's part (REA, 2026-10-18)

Method: REA controlled-browser scenarios on **public web exercise pages** (phone viewport, no sign-in): network
requests, DOM (`<video>`/`<img>` sources, alt text, credits), one screenshot each. Boundaries: no decompiling app
binaries (iOS App Store binaries are FairPlay-encrypted and licensed against reverse engineering), no accounts, no
APKs from mirrors, no media downloaded beyond what the pages load to display, and **no bypassing bot checks**
(Fitbod's page served a Cloudflare challenge to the headless browser; the run stopped there). Codex covered other
apps in parallel: [codex-competitor-study.md](codex-competitor-study.md).

| App | What the public page shows | Where it is served from | What it reveals | Evidence |
|---|---|---|---|---|
| **Lyfta** (ticket 01) | 3D render, muscles tinted, 6 s MP4 loop | `lyftaweb.s3…/GymvisualMP4/00251201.mp4` | Gym visual video, product code `002512` (Barbell Bench Press) + `01` | REA `ev_0b4c9bc357cc1f07a001bd077e3f3c00f806e2ecae582d7154224407704d3bd3` |
| **Hevy** | `<video controls>` of the 3D render on its blog-style exercise article | `pump-app.s3.eu-west-2.amazonaws.com/exercise-assets/00301201-Barbell-Close-Grip-Bench-Press_Upper-Arms.mp4` | Gym visual's "Barbell Close-Grip Bench Press" video has SKU **`003012`** (its product page: `<meta … sku content="003012">`, MOV 1920×1080, 6 s) → Hevy's file = that code + `01` | REA `ev_8945fc6af50ced2803a11631988c84c8231acf781b5581eba12ee3a958a1a110`; gymvisual.com/videos/2936 |
| **StrengthLog** | Animated GIF of **a real lifter filmed in StrengthLog's own gym** (its logo on the wall); flat grey body silhouettes with red/pink muscles for "muscles worked" | own WordPress uploads (`/wp-content/uploads/2021/09/bench-press.gif`, `Muscles-worked-in-the-bench-press-exercise-2.jpg`) | Filmed in-house; muscle maps drawn in a flat style (like our chosen own drawings); no vendor credit, footer "© StrengthLog" | REA `ev_848e38d69d2730b67a429dd382e4d857fbe839fcfe5420b2e01e3da71efba36d` + screenshot |
| **JEFIT** | GIF of **a real trainer filmed on a home-gym rack** (a branded all-in-one trainer) | own CDN `cdn.jefit.com/assets/img/exercises/gifs/<id>.gif`, stills `images/exercises/960_590/<id>.jpg` | Filmed footage under its own exercise IDs; no vendor credit, "© 2026 Jefit Inc." [I] the branded rack hints at an equipment-maker tie-in — not established | REA `ev_456afbd8c6e7c2d8a7e436104ecc16d87a2b0d9cfceb0f888a30c1b3258392f2` + screenshot |
| **Fitbod** | (page blocked the headless browser) | — | Its own "Exercise Pages" description: demonstrations by **professionally filmed personal trainers** using 80+ pieces of equipment, 1,600+ exercises | [fitbod.me/about-fitbod-exercises](https://fitbod.me/about-fitbod-exercises) |

**Facts vs. inferences.** The Hevy and Lyfta file names matching Gym visual product codes is an observation; that
they **license** those videos is an inference (consistent with Gym visual's per-item commercial licence and with
ExerciseDB's media lineage in ticket 02), not a statement by either company.

## Terms caveat (found after the visits)

Codex found Boostcamp's terms forbid automated crawling and competitive research and stopped there. Checking the
sites visited here afterwards: **JEFIT's terms** ("not to access … any of the Services through any automated means
(including use of scripts or web crawlers)") and **StrengthLog's app terms** ("use any automated means, software,
script, bot, scraper, agent, AI system … to access … the Service") forbid automated access; REA's headless browser
loads count. Each was visited by a handful of page loads only; no further automated access will be made to sites
whose terms forbid it, and the screenshots stay out of the repository. Hevy's terms forbid reverse engineering its
software (not done) and name no crawling clause; Lyfta's fetched terms text names none. **Rule from here on: read a
site's terms before any automated access; where it is forbidden, use first-party public statements found by ordinary
search instead.**

## What it means for Stacked

- The industry splits into two routes: **license Gym visual's 3D renders** (Lyfta, Hevy — and ExerciseDB's media
  lineage) or **film real trainers** (Fitbod, JEFIT, StrengthLog). Nobody visible here ships AI-generated or
  code-drawn demos.
- The polished 3D look the user liked in Lyfta is, in practice, Gym visual's — two of the best-known loggers buy it
  rather than make it. That supports Proposal 1 (Gym visual, permission first) as the normal, proven route.
- Filming is the other proven route, but the user has ruled out own footage; commissioning a trainer shoot is
  Codex's Proposal 4 (costly).
- StrengthLog's flat silhouette muscle maps are close to our decision (own simple drawings) — a proven, readable
  style.
