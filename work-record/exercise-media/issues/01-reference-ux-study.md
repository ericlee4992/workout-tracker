# 01 — Reference UX study: Lyfta's exercise detail screen (REA)

Type: research
Status: resolved for the web library; the iOS screen itself not observed (see Gaps)
Blocked by: —

## Question

How does Lyfta ("Lyfta: Gym Workout Tracker Log", App Store id 6443740936) present an exercise's detail and its
form video, as a reference for our own screen? UX only: layout, order, interaction, media behaviour. **Not** their
code, text or media — nothing of theirs is copied into this repo (their screenshots stay in the session scratchpad).

## Method and boundary (2026-10-18)

- Lyfta is not installed on this Mac or the user's phone and has no Mac build ("Designed for iPhone. Not verified for
  macOS" on its App Store listing). Its exercise library is public on the web (`www.lyfta.app/exercises`,
  `/exercise/<slug>`), so the study used REA's controlled browser scenario on those public pages at a phone viewport
  (390 pt wide, Chrome headless): accessibility tree, DOM, screenshot, network events. No sign-in, no account, no
  decompiling of the iOS binary (its licence forbids reverse engineering, and the UX question does not need it).
- REA evidence (session-local ledger): index `ev_ef88da3996f22fa4d2229d81c171f4a4fc68ff8cfa430d4c220aad793d80ce15`;
  detail page `ev_48e5c14f8dd2b49e360bef23025dff74f9487962842fe9982f6943eb33059cc8`; play tapped
  `ev_0b4c9bc357cc1f07a001bd077e3f3c00f806e2ecae582d7154224407704d3bd3`; DOM
  `ev_a22120d9665d7c542028e05da78d2edebef38e39e704deb455ddfedff87dc3d6`.

## Observations (what the evidence shows)

**Library (index).** Title "Free Exercise Library"; a search field; a Favorites filter; horizontally scrolling
body-part chips (Cardio, Chest, Back, Biceps, Triceps, Quadriceps, Hamstrings, Shoulders, Hips, Waist, Upper Arms,
Calves, Forearms, Neck) plus a Filters button. Each exercise is a card: a still "demonstration" image (a 3D-rendered
figure with the target muscle tinted red), the name, the muscles as a subtitle, and a bookmark (favourite) button.

**Detail page, top to bottom.**
1. Breadcrumb: Exercises / body part / equipment / name.
2. **Media hero**: full-width poster (the same 3D render) with a centred round play button. Nothing but the poster
   loads until play is tapped.
3. Name (large title), then two full-width buttons: Save to Favorites (filled), Share Exercise (outlined).
4. **Exercise Profile** card: Body Part, Equipment, Primary Muscles, Secondary Muscles (label/value rows).
5. Related Exercises: a horizontal carousel of variation cards (same card as the library).
6. App download prompt (web-only).
7. Text guide with a table of contents: introduction, a numbered step-by-step, tips (common mistakes), FAQs
   (beginners, variations, complementary exercises), related keywords (SEO).

**Video behaviour.** Tapping play replaces the poster in place with an HTML `<video>`: `autoplay`, `loop`,
`controls`, `playsinline` (inline on iPhone, not forced full-screen), `disablepictureinpicture`, muted. Clip length
**6 s** for Bench Press — a short loop of the movement, not an instructional talk. Controls: pause, time, mute,
full-screen. The MP4 is served from an S3 folder named **`GymvisualMP4/00251201.mp4`** (observed path; the licence
behind it is a question for ticket 02, not established here). A small watermark is drawn on the frame.

## What this suggests for ours (design inputs, not decisions)

- The media is a **short, silent, looping clip** of the movement, shown big at the top of the exercise's page; that
  is what "form video" means in this reference. Our live-workout pop-up can show the same loop at a glance.
- The poster-then-tap pattern saves data; on a phone in a gym a still frame that starts on tap (or autoplays muted)
  both fit. The muscle-highlight render does a lot of work: primary/secondary muscles are visible without reading.
- Their page is organised for search engines (long text, FAQ, keywords); ours should stay a workout tool: media,
  muscles, equipment, our own numbers (the existing `ExerciseDetailView`), short cues at most.
- Library cards with a still frame per exercise are the "animations in the Exercises tab" analogue; animating every
  row at once would be heavy — a still per row and motion on the detail page (or on a long-press/peek) is the norm.

## Gaps

- **The iOS app's own exercise detail screen was not observed** (not installed; no Mac build). The web page shares
  the media and data, but the app's layout, in-workout entry point and offline behaviour are unknown. To close it:
  the user installs Lyfta on the phone and shares screenshots or a screen recording of an exercise's detail and of
  tapping an exercise during a workout; REA cannot drive an iPhone UI.
- The in-app web app (`my.lyfta.app`) needs an account; not used.
