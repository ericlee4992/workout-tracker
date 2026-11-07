# Proposal: "Floodlight, daylight" — the gym log gets a kitchen, not a makeover

Independent design proposal (Fable). Answers `BRIEF.md`; images cited by file name.

## 1. The idea

Stacked stays an ink-and-figures app that happens to count food. What the owner liked in the reference
(`ref-5745.png`) is not its styling but its *air*: things float instead of being boxed, the day sits at the top as a strip,
one big number with a small goal beside it, and a "+" always a thumb away. We take exactly those four things and render
each in our own materials: SF Pro Expanded figures, the segmented dial we already own (`today-app-cardio.png`), ink slabs
(the rest timer), hairline receipts (`saved-mono-direction-2.png`), and the muscle figures. The warm page-wide gradient
becomes one soft *floodlight* behind the title (the name we already have). Smooth icon-rings, the white 2×2 menu, plain
SF Pro and lavender tracks are refused. The result reads darker, heavier and more typographic than the reference, and
lighter, more lifted and more "day-shaped" than today. Nutrition arrives as a second palette family — *the kitchen is
quiet, the gym is loud* — so macros and muscle figures share a screen without fighting.

## 2. Keep / borrow / refuse

| Keep (ours) | Borrow (from reference, adapted) | Refuse |
|---|---|---|
| SF Pro Expanded Black/Heavy for every screen title and hero figure (`today-app-workout-tab.png`) | Figure-over-goal: `1,240` Expanded Black + `/2,288` small secondary — in our width, never plain SF | Plain SF Pro titles and figures (`soft-1.png` "Today", "1,240") |
| Near-black ink ground in dark; cool near-white in light | Lifted white cards on a soft wide shadow — **light mode only**, replacing hairlines there | Shadows in dark mode (invisible on #0B0B0D; keep graphite + hairline) |
| Segmented tick dial (`today-app-cardio.png`) — becomes the only ring type | A ring per macro, with figure/goal above it — but ticked, with a letter monogram, never an icon | Smooth rings with lavender track and food icons (`ref-5745.png`) |
| Muscle-family figures as the only pictorial element | Week strip at the top of the day — as our rounded day *tiles* with minutes, not circles | Dashed day circles; flame-streak chip |
| Live set table, rest slab, yellow "New best", red Cancel | Black "+" circle beside a floating capsule tab bar; 4 tabs | Groups/Profile tabs; social and badges (`ref-5746.png`) |
| Mono action: black pill in light, white in dark | Outlined pill secondaries (we already have these) | Blue-E profile avatar accent; any second accent colour |
| Receipt summary (label left, figure right, hairlines) | 2×2 quick-add — as ink slabs rising from the "+", not white tiles | White 2×2 tiles on a blurred page (`ref-5752.png`) |
| Hairline grid stat panels | Faint warm light — as one radial "floodlight" behind the title, not a page wash | Peach gradient covering the top third of every screen (`soft-1.png`) |
| Cool neutral ground | Scan-screen corner brackets and mode chips | Lavender "recently logged" cards (`ref-5756.png`) |

## 3. Tokens

**Colour** (light / dark)

| Token | Light | Dark |
|---|---|---|
| Ground | `#F3F3F5` | `#0B0B0D` |
| Card | `#FFFFFF`, shadow, no border | `#161619`, hairline `#FFFFFF` 8% |
| Inset / field | `#F6F6F8` | `#1F1F23` |
| Ink (text, action fill) | `#0E0E10` | `#F5F5F7` |
| Secondary text | `#6E6E76` | `#9A9AA3` |
| Hairline | `#000000` 6% | `#FFFFFF` 8% |
| Floodlight | radial `#FFD6BA` 36% → 0, 260pt, anchored top-leading behind the title | radial `#FFFFFF` 5% → 0, same geometry |
| Dial track (unlit tick) | `#E2E2E8` | `#2A2A30` |
| Calories | ink | ink |
| Protein | `#C2183D` | `#FF5F7E` |
| Carbs | `#A9742F` | `#D9A55A` |
| Fat | `#566BA8` | `#8EA0E0` |
| Muscle hues | unchanged (chest orange, back blue, shoulders teal, arms yellow, legs green) | unchanged |
| Signals | heart rose, "New best" yellow, Cancel red — unchanged | unchanged |

*How the two families coexist:* muscle hues are **saturated and pictorial** (figure fills); nutrition hues are
**earthy and desaturated** (dial strokes and letter monograms). Calories themselves are ink, the same as the action
colour, so the day's headline number never competes with either family. Rule: a card is either a training card or a
nutrition card; the two families never share a row. Heart rose and Protein crimson are the nearest pair; they never
appear on the same card (heart lives in live workout and Finish, protein in Today/Food/Progress).

**Type roles** (SF Pro only)

| Role | Face |
|---|---|
| Screen title | Expanded Black 34 |
| Hero figure | Expanded Black 36–40, tabular; suffix/goal `/2,288` Expanded Medium 15 secondary |
| Section heading | Expanded Bold 20 |
| Card title / row figure | Expanded Bold 17, tabular figures |
| Body | SF Pro Regular 15, Semibold for the primary line |
| Label | SF Pro Medium 12, uppercase, +0.6 tracking (as SET / PREVIOUS / WEIGHT / REPS) |
| Monogram (P / C / F) | Expanded Black 12 in the macro hue |
| Buttons | Semibold 17 on mono pill; Semibold 15 on outlined pill |

**Shape, edge, spacing**

- Radii: card 20, hero card 24, field 10, day tile 10, pills and set circles fully round. Dial ticks have square ends
  (the reference's rings are round-capped; ours are cut).
- Light edge recipe: `0 1 2 rgba(14,14,16,.04)` + `0 10 28 rgba(14,14,16,.07)`, no stroke. Dark: hairline only.
  Inputs (weight/reps fields) keep their outline in both modes because they are controls, not cards.
- Spacing: 16 gutter, 16 card padding, 12 between cards, 8 between mini cards, 28 above a section heading.
- Action: Mono. Primary = ink pill; secondary = outlined pill; destructive = red text (Cancel) only.

## 4. Signature moves

1. **The dial.** The cardio tick ring becomes Stacked's single ring. Calories: 24 ticks, lit in ink. Macros: 12 ticks,
   lit in the macro hue. Finish: ticks coloured by muscle family worked (already in `saved-mono-direction-2.png`).
   Inside a dial there is only type — a percentage, a time, or a monogram — never an icon.
2. **Figures for the body, letters for the plate.** Training is pictorial (muscle figures); nutrition is typographic
   (P, C, F monograms in Expanded Black, plus a `kg`/`lb` monogram for body weight). Both sit in the same 28pt circle,
   so a day's chips — `[chest][back] · [P][C]` — read as one family of marks.
3. **Day tiles.** Our week strip of rounded tiles (`today-app-workout-tab.png`) is the app's calendar. A tile fills
   ink when a workout was done, shows its minutes, and gains a 4pt underline in Carbs-tan when food was logged. Today is
   dashed. Tap a past tile → that day's journal. This replaces the reference's circle strip everywhere.
4. **The receipt.** The Finish summary's hairline rows (label left, Expanded figure right) are reused for meals on
   Today, the day total in Food, and the Progress stats. Food and workouts therefore look like entries in one ledger.

## 5. Screen by screen

**Today** — the day's ledger; nutrition is all-day, training is one event.
```
 [floodlight]                          (calendar)(gear)
 Today                                 Expanded Black
 Friday, Nov 6
 [S 28][M 12][T 77][W 29][T 55][F ·][S  ]   day tiles, tan underline = food logged
 ┌ Calories ───────────────────────────────┐
 │ 1,240 /2,288      [24-tick dial, "54%"] │  lifted card, ink dial
 │ eaten · 1,048 left                      │
 └─────────────────────────────────────────┘
 ┌ P 102/149g ┐ ┌ C 138/261g ┐ ┌ F 28/72g ┐   three mini cards, 12-tick dial + monogram
 Training
 ┌ [chest][back][arms] Push Day · Up next  ┐
 │ Seated Chest Press · Incline · +2        │
 │ [● Start · Iron Temple · 5 exercises ]   │  mono pill (from saved-mono-direction-1.png)
 └──────────────────────────────────────────┘
 Meals                                  receipt rows
   Breakfast  Oats, 2 eggs            520
   Lunch      —                        [+]
   Snack      Protein shake  4:15 PM  180
 [Today][Train][Food][Progress]   (+)
```
Decision: once the workout is done, the Training card collapses to a single receipt row ("Push Day · 52 min · 2 new
bests") so Today does not duplicate History. The Training card uses muscle figures; the dial row uses monograms; they
never share a row.

**Train** — the saved Mono Workout tab (`saved-mono-direction-1.png`) with lifted cards in light and the floodlight
behind "Train". Order: gym chip → next workout card (mono Start) → Start Lifting / Start Cardio outlined → Other
templates → **Library**: two rows, *Exercises* and *Gyms*. That is where the two removed tabs live.

**Live workout** — table untouched. Chrome: chevron, red Cancel, title, mono Finish pill; stats strip bpm / cal /
volume. Skin: exercise cards lifted in light (shadow, no border), fields keep outlines, rest slab stays ink. **No
floodlight and no nutrition here** — this screen stays the shipped Floodlight dark/ink look (`today-app-live-workout.png`).

**Finish** — `saved-mono-direction-2.png` as is, plus one receipt row "Burned 312 cal · added to today's budget" and an
outlined pill "Log a meal" under "Save as Template". Dial ticks in muscle hues; new bests in yellow.

**Progress** — segmented chip control at top: **Body · Strength · Fuel**.
- Body: hero figure `172.4 lb` (Expanded Black) + mono "Log weight" pill; start→goal as a 20-tick dial-bar; trend chart
  in ink with a tan goal hairline.
- Strength: today's per-exercise cards (`today-app-exercise-progress.png`), unchanged.
- Fuel: seven day tiles whose height is the day's calories against a goal hairline; below, receipt rows for averages.

**Log food**
```
 ‹  Log food                         Expanded title
 [Breakfast][Lunch][Dinner][Snack]   meal chips (ours, not in ref)
 [ Search or describe …            ] outlined field
 All · My foods · Meals · Saved       text tabs with ink underline
 Recent                               receipt rows: name, P/C/F monogram chips, cal figure, ink (+) circle
 ───────────────────────────────────
 [ ● Scan ]   [ Manual ]  [ Voice ]  mono + outlined pills above the keyboard
```
Each food row shows macro monograms with grams, so protein is visible without opening the item.

**Scan food** — full-bleed camera, ink chrome: corner brackets in white, our segmented chip (Food | Barcode | Label)
like Lifting | Cardio, white shutter, X top-left. Result sheet is a receipt: items with monogram chips, calorie
figure in Expanded Black, mono pill "Add to Lunch".

**"+" / quick add** — mono circle beside the capsule (borrowed). Tapping lifts a 2×2 of **ink slabs** (light: black
on dimmed ground; dark: graphite with hairline) with Expanded Bold labels: *Log food*, *Scan food*, *Log weight*,
*Start lifting*. Cardio starts from Train.

**Tabs** — **Today · Train · Food · Progress** + "+". History is reached from Today's day tiles and the calendar button
(full month list as today, `today-app-history.png`); Gyms and Exercises live under Train → Library; Settings is the
gear on Today and Train. Food tab = the diary by day and meal, saved foods and recipes.

## 6. Dark mode and large text

Dark keeps the shipped character: `#0B0B0D` ground, graphite cards with hairlines, no shadows, floodlight at 5%
white so the title still has a stage. Mono inverts (white pill, black text). Unlit ticks `#2A2A30`; nutrition hues
use the lifted dark values above so they clear 4.5:1 on graphite. The live workout does not change between modes
beyond what ships today.

Large text (AX sizes, `today-app-workout-tab.png` right column shows how we already behave): the calories card stacks
figure above dial; the macro trio becomes three full-width rows (monogram · figure/goal · 12-tick bar) because dials
below 56pt stop reading; day tiles drop minutes and keep the letter and fill; receipt rows wrap figure under label;
hero figures cap at 48pt. Expanded Black titles wrap to two lines as they do today; nothing is clipped.

## 7. Risks

- **Slides into a copy** if light mode gets warm wash + round cards + rings + plain type together. Guards: every big
  number is Expanded; every ring is ticked with square ends; nothing lives inside a ring but type; the floodlight is a
  spot of fixed size behind the title, never a page gradient; the ground stays cool; quick-add slabs are ink.
- **Slides into blandness** because Mono removed the violet. Guards: the muscle hues and the three kitchen hues are
  used at full size in dials and figures, not as 12pt dots; the yellow highlighter stays; Finish and Fuel are colourful
  by design.
- **Hue clash** at small sizes between Protein and heart rose, Carbs and arms yellow. Guards: families never share a
  row; monograms carry a letter so hue is never the only cue; AX test the P/C/F chips at 12pt.
- **Today vs Train redundancy.** Guard: Today shows training as one card before the session and one receipt row
  after; Train owns templates and the library.
- **Light-mode lift makes inputs look like cards.** Guard: fields keep outlines and the dashed draft style; only
  cards get shadow.
