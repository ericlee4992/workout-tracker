# 01 — Reference UX study: Lyfta's exercise detail screen (REA)

Type: research
Status: resolved — web library (REA) and the iOS app incl. the in-workout entry point (the user's screenshots, 2026-10-18)
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

## The iOS app (the user's three screenshots, 2026-10-18 04:38–04:39; kept outside the repo)

Observed by eye from the screenshots (not REA evidence). Dark theme throughout.

1. **Explore → Exercises (browse).** A search field ("Search for exercises"); a top switch Programs / Exercises /
   Coaches; a **"Muscle Groups" grid**, three per row: a large anatomical figure (front or back as fits) with that
   group tinted orange-red, its name below — Chest, Biceps, Triceps, Back, Shoulders, Abs, Quadriceps, Hamstrings,
   Glutes, then more (calves, forearms, neck/traps by their art). Tab bar: Home, Explore, Workout, Library, You.
2. **Library (all exercises).** A close button, "Library", search, filter, +. A horizontal strip of **small body
   silhouettes** as the muscle filter (the selected one framed; a bookmark/favourites chip first). "All Exercises"
   with a list/grid switch. **Two-column cards**: a large still 3D render of the movement on a dark tile (target
   muscle tinted), a bookmark at top-left, a **"?"** at top-right (presumably the quick form view), then the name and
   the muscle group. Rows are stills, not animated.
3. **Exercise detail.** Back, the exercise name as the title, a "•••" menu; **tabs About / History / Progress**. About
   opens with a **large white card playing the animation** (looping, autoplaying; pause at top-right, full-screen at
   bottom-right). Below it a **horizontal row of action chips**: Favorites, **YouTube**, Share, "How to lo…" (cut off —
   likely "How to log"). Then **"Target muscles"**: front and back anatomical figures, **primary muscles orange-red,
   secondary blue**.

4. **During a workout** (screenshots 04:41). The workout list shows each exercise as a row: a **small still
   thumbnail of the render with a "?" badge**, the name, "0/3 Done", and a "•••" menu; above, Duration / Volume /
   Sets. **Tapping the exercise opens its full exercise page** (the same About / History / Progress screen, the clip
   autoplaying) — a push, not a pop-up. "Add exercises" opens the same two-column library grid with the body
   silhouette filter.

**Inputs for ours (added).** The muscle map (front + back, primary vs secondary colour) carries as much as the clip;
it also replaces the web page's text profile. Browse-by-muscle uses body art, not words. YouTube is a separate,
explicit action (a chip), not the default player. Our existing exercise page already holds the History/Progress
content — the media and muscles would become its top section rather than a new screen.

## Gaps

- Offline behaviour (does the clip play without a connection?) was not seen; the iOS screens above came from
  screenshots, which REA cannot drive or verify further.
- Difference to note for our design: the user asked for a **pop-up** over the workout ("a window should pop up that
  shows the form video"), where Lyfta navigates to the full page. Both keep the workout: in Lyfta the back button
  returns to it (the user, 2026-10-18). The choice is about what the user sees — the clip alone, quickly dismissed,
  or the whole exercise page with history — and is left to the design step.
- The in-app web app (`my.lyfta.app`) needs an account; not used.
