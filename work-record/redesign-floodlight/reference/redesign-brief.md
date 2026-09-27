# Redesign brief — Workout Tracker (private iPhone gym logger)

Read this first, then `dc-authoring.md` (how to write an artboard). Deeper facts, if you need
them, are in `../brief/` (inventories per area, domain data, constraints, the user's taste
history, visual audits of the current app). Quote the brief files; don't guess.

## The request (2026-09-24, the user's words)

"Currently the layout is clean, but I feel like some places are messy and could be missing
details. Also the app just feels a little boring right now. Redesign the entire app (every
little thing), and make it more interactive, creative, and engaging. … Feel free to completely
change from current theme of the app, just think about how you can make the design better."

## Who uses it and how

One person, iPhone 15 Pro Max (430 × 932 pt), one-handed, mid-set, under gym lighting, glancing
for two seconds. Every screen's job is a glance or a tap, never reading. Units: the user logs in
**lb**. Private app — no accounts, social, leaderboards, backend, Watch app, coaching.

## What this user has shown they like / dislike (from ../brief/user-taste.md)

Likes:
- Seeing real pictures and choosing between side-by-side options; Apple Fitness is their
  recurring reference (rings, big numbers + small labels, clean thin HR graph).
- Bold, graphic, saturated, NOT text-heavy. Chose the characterful option each time.
- **Big pill buttons with an icon disc** — the "Start Lifting" / "Start Cardio" pair: two EQUAL
  capsules, side by side (stack only if labels can't fit), each with its activity icon in a disc.
  They defended this twice. Keep the pattern (restyle it freely).
- Template **grid of tiles** (two columns) with a "New Template…" tile; tapping a template shows
  its exercise list; Delete lives inside the opened template.
- **Accurate muscle maps** (grey body, vivid muscle) — one per muscle FAMILY (Chest, Back,
  Shoulders, Arms, Legs), shown on templates. Assets are provided (below).
- In the live workout: one header line = gym chip · running clock WITH SECONDS (medium-large,
  not a giant hero) · small ring "N/M sets". The rest bar: draining ring with hourglass, "Rest"
  over the time, "+15s", "Skip". Swipe-to-delete sets. Drag to reorder exercises.
- Finish summary: status ring + "View in History" primary + "Save as Template" secondary, then
  paired stat tiles in THIS order: Workout time | Total volume, Active calories | Total calories,
  Avg. heart rate | Max heart rate. Then time in zones directly below the HR graph (no tap).
- Plain words and plain numbers (no ≈, no "estimated", no source captions). "Delete" not
  "Archive". Discoverable direct actions, not hidden menus.
- Cardio: focus on the current activity (a Lifting | Cardio switch in the live workout).

Dislikes (do not reintroduce):
- "boring", "mostly texts", "messy", "mundane", "mild", icons that "don't match".
- A muscle icon beside every exercise row (removed at their request). Family maps only as
  summaries (templates, and — new — weekly/finish summaries).
- Magnifying the current set row; a giant elapsed-time hero.
- Explanatory/helper paragraphs, tutorials, coach marks. One short consequence line at most.
- Long-press menus on template tiles (one deleted the wrong template).
- Auto-added set rows (rows are only ever created deliberately).
- A live map during cardio (routes appear only after Finish / in History).
- Changing the tab-bar icons (Sep 11: "keep the tab-bar icons as they are"): Workout
  (strength-training figure), History (clock with circular arrow), Gyms (building), Exercises
  (bulleted list rectangle). Restyle the bar, keep these four symbols and labels.

**Pattern:** every time they were shown structural rewrites of screens they already use, they
kept the familiar skeleton and asked for precise moves; the SURFACE is what failed ("boring",
"mild", "messy"). So: change the visual language boldly, keep recognisable skeletons, and add
engagement through data, state, motion and celebration rather than new flows or prose.

## Engagement and "missing details" — what the data already supports

All derivable from stored data without new storage (see ../brief/domain-data.md §3):
- **This week**: workouts per day (dots/bars), sets per muscle family this week, time trained.
- **New bests (PRs)**: detect when a completed set beats earlier eligible sets for the same
  machine/equipment + preset (warmups excluded; assisted = lower is better; ties are not PRs;
  the very first time is "First time", not a PR). Show live in the workout, on finish, in history.
- **Last time** for each set (the existing PREVIOUS value, e.g. "105 × 8") and the change vs last.
- **Volume so far** / sets done / current exercise progress during the workout.
- **Rest timer next-set preview** ("Next · Set 3 · 110 × 8").
- **History**: month summary (workouts, sets, hours), calendar with training days, per-workout
  families trained, PR count per workout, cardio route thumbnail.
- **Exercise progress**: chart with PR markers, rep-count bests (1–12 reps), 1RM (weighted only,
  labelled "1RM", never "estimated").
- **Per machine / per gym**: times used, last used, best set on that machine; gym visits.
- **Template stats**: times run, last run, average duration.
- Streaks / weekly goals / badges are NOT in any spec — you MAY propose a week streak, but mark
  it as a new product decision.

Every NEW visible string you add is the user's decision: keep a list of them (you will report
it). Prefer numbers, rings, charts, colour and motion over words.

## Hard product rules (keep)

- Plain numbers (D52): "1RM" not "Est. 1RM", no ≈. Missing heart rate/calories are absent,
  never "0". Weights shown as entered (plain conversions only when needed).
- Explicit cardio Start; AI never suggests starting weights; no coaching.
- History shows frozen snapshot names; edited workouts show an "Edited" mark.
- Colour carries meaning consistently (pick your own palette, but keep: one colour = one
  meaning; heart rate/destructive distinct; warmup/drop/failure set kinds distinct; muscle
  families each have a fixed colour).
- Contrast ≥ 4.5:1 for text; hit targets ≥ 44 pt; one primary (filled) command per screen state
  (the Start pair counts as one peer group).
- Must survive Dynamic Type at AccessibilityL (describe how, even if you only draw default size).
- Reduce Motion: every animation has a still alternative.

## Shared sample scenario (use EXACTLY this content so options are comparable)

- Today: **Thursday, Sep 24**. Gym: **Iron Temple** (Seoul), unit **lb**.
- This week so far: Mon — Pull Day (48 min), Wed — Leg Day (55 min), today not yet trained.
  Last week: 4 workouts. Weeks in a row with ≥1 workout: 6 (only if you propose a streak).
- Templates (4): **Whole Body** (Bench Press + Lat Pulldown superset, Machine Shoulder Press,
  Dumbbell Curl, Leg Press, Abdominal Crunch — families: Chest, Back, Shoulders, Arms, Legs),
  **Push Day** (Seated Chest Press, Incline Chest Press, Machine Shoulder Press, Lateral Raise,
  Triceps Pushdown — Chest, Shoulders, Arms), **Pull Day** (Lat Pulldown, Seated Row, Rear Delt
  Fly, Dumbbell Curl — Back, Shoulders, Arms), **Leg Day** (Leg Press, Leg Extension, Seated Leg
  Curl, Calf Raise — Legs). Template tile secondary line format the user kept:
  "N sets · r, r, r reps" appears in template DETAIL rows; tiles list exercises briefly.
- Live workout (for "in progress" screens): started from **Push Day**, elapsed **0:18:42**,
  **7/18 sets**. Heart rate **128 bpm** (Zone 2, via AirPods), active **96 cal**.
  Current exercise **Seated Chest Press** on machine **Chest Press 2** · model **Life Fitness
  Insignia Series Chest Press**. Sets: W 45 × 12 (done) · 1: 100 × 10 (done, last time 100 × 10)
  · 2: 110 × 8 (done — **new best**, last time 105 × 8) · 3: 110 × 8 (draft, prefilled from last
  time). Rest running: **1:24** of 2:00. Next exercise: Incline Chest Press. Volume so far
  **4,120 lb**.
- Finish (Push Day): **52:10**, **18,450 lb**, **22 sets**, **5 exercises**, active **312 cal**,
  total **398 cal**, avg HR **124 bpm**, max **158 bpm**. Zones (max 185): Warm-up 6:40, Zone 1
  14:20, Zone 2 18:05, Zone 3 9:30, Zone 4 3:35. New bests: Seated Chest Press 110 × 8;
  Machine Shoulder Press 80 × 10. vs last Push Day (Sep 17): volume +6% (17,400 lb).
- History (Sep 2026): Sep 24 Push Day · Sep 22 Pull Day · Sep 21 Indoor Run 3.1 mi 28:40 ·
  Sep 17 Push Day · Sep 16 Leg Day · Sep 15 Pull Day · Sep 10 Whole Body … Month: 9 workouts,
  186 sets, 7.4 h.
- Exercise progress (Seated Chest Press, lb): 28 d ago 95×8, 25 d 100×8, 21 d 105×8, 18 d 105×6,
  14 d 110×8… use the fixture: 95, 100, 105, 105, 110, 110, 115, 112.5, 120 (× 8/10 reps).

## Assets on the canvas (use these URLs verbatim)

Muscle maps: white silhouettes with alpha, 512 × 512, two layers per family: BODY (grey in the
current app, #5B6472) and MUSCLE (the family colour). Tint them with CSS masks in a
`<helmet><style>` rule (url() must live in the helmet stylesheet, never inline style):

```css
.mm{position:relative;width:48px;height:48px}
.mm i{position:absolute;inset:0;-webkit-mask-size:contain;mask-size:contain;-webkit-mask-repeat:no-repeat;mask-repeat:no-repeat;-webkit-mask-position:center;mask-position:center}
.mm-chest .b{-webkit-mask-image:url(/_blob/d467ccdb8c364155213585010d8d2ab3);mask-image:url(/_blob/d467ccdb8c364155213585010d8d2ab3);background:#5B6472}
.mm-chest .m{-webkit-mask-image:url(/_blob/b2520e8795eaafc66a831fa55ac6f072);mask-image:url(/_blob/b2520e8795eaafc66a831fa55ac6f072);background:#FF70B6}
```
markup: `<div class="mm mm-chest"><i class="b"></i><i class="m"></i></div>`

| Family | body layer | muscle layer | current colour |
|---|---|---|---|
| chest | /_blob/d467ccdb8c364155213585010d8d2ab3 | /_blob/b2520e8795eaafc66a831fa55ac6f072 | #FF70B6 |
| back | /_blob/deb9149c367164ac15334e0597548865 | /_blob/5c932a4e456107c7ed860dea7577b7b2 | #4EB9FF |
| shoulders | /_blob/5d0959a29ade26dc7b0c01d741f62399 | /_blob/c7a932a31b014e0c8a507699ae34b192 | #4DE0D4 |
| arms | /_blob/6dc5f65e6b1577bbc22fac956eb310d1 | /_blob/7d9d50e51da9ddf0a5bb6b2809d9e990 | #B891FF |
| legs | /_blob/743b3334d3d9e98fab194dbafac2016a | /_blob/26111df860927e8ea85b6c2d02cb3018 | #84D65A |

You may recolour families to fit your palette (keep them distinct from each other, from the
action colour and from heart-rate red; keep them distinguishable by lightness too).

Current-app screenshots (for "before" boards only): Home `/_blob/f6e64792ca182c34d536d24f7d62171e`,
Live workout `/_blob/07f20f809570dc131e36b32a9a518970`, Finish `/_blob/75a5807415350f10190c9ba2925a005c`,
History `/_blob/5c033a8392ac46d0abb71d5d0cddb475`.

## Type

The shipped app must use iOS type that supports Dynamic Type. Map every face you choose to a
native equivalent and say so: SF Pro (Text/Display), SF Pro **Expanded / Condensed /
Compressed** widths (`.fontWidth`), SF Pro Rounded, SF Mono, New York (serif). A bundled custom
font is possible only with a strong reason (scaled via UIFontMetrics). In the HTML mock, body
text uses `-apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, sans-serif`; width
variants can be stood in by Google Fonts (e.g. `Archivo` has a width axis 62–125 that
approximates SF Expanded/Condensed; `Archivo Narrow`, `Barlow Condensed`). Never Inter, Roboto,
Arial, Fraunces.

## Not allowed on the canvas

Fake status bar / Dynamic Island / keyboard; emoji; lorem ipsum; invented features beyond the
list above without flagging; gradient-wash backgrounds as decoration; left-border accent cards.
