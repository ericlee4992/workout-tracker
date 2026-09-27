# Direction B: "Anatomy"

**Idea:** a graphite app where the body is the palette. The five muscle families, heart-rate
red and the set kinds are the only colours on screen. Every command is monochrome pearl, so
colour always means data: *what you trained lights up*. Family colour appears only in
**summaries** (Home's week, template tiles, the Finish receipt). The live workout carries no
family colour at all: it is pearl plus heart rate.

Artboards (canvas `canvas/project/`):

| File | Size (w × h) | Interactive | Notes |
|---|---|---|---|
| `DirB-Home.dc.html` | 430 × 1250 | no | Workout tab, idle, Iron Temple, 4 templates, whole scroll. The skeleton is today's: gear, date and title, gym picker, **Start pair directly under the picker**, then This week, then Templates. The floating tab bar is drawn **pinned at the artboard bottom** (the scrolled-to-end position). |
| `DirB-Live.dc.html` | 430 × 932 | **yes** | Push Day mid-session (first viewport), shared scenario: **Seated Chest Press is the first card**, Incline Chest Press follows, both expanded in template order. The clock and the rest countdown tick every second. Tapping set 3's check completes it (animation), restarts rest at 2:00, and moves 7/18 → 8/18 and 4,120 → 5,000 lb. Tapping it again undoes it. **+15s** adds time; **Skip** ends rest. State comes from `setInterval`, which is cleared on unmount. |
| `DirB-Finish.dc.html` | 430 × 2120 | no | Push Day finish sheet (`.large`), full scroll. The kept receipt top (ring at leading, "Workout saved" beside it), the two buttons, "Workout details" with the tiles, then the families trained. |

No artboard size changed in the review round.

---

## 1. Palette (tokens)

The app stays dark only (D54). **Amber is retired.** One colour has one meaning.

### Ground, surfaces, text, action

| Token | Value | The one meaning |
|---|---|---|
| `ink` | `#0A0B0F` | Screen ground. It is also the text and icon colour on pearl. |
| `sheet` | `#101115` | Ground of sheets and modals (the elevated base). |
| `card` | Solid `#191A1E` on ink; solid `#1F2024` on a sheet. 1 pt hairline (white 7 %) and a faint top highlight (white 5 %). | **Content surfaces: cards, tiles, list groups, the gym picker, the gym chip, the vitals strip, secondary buttons in content (Save as Template).** Built natively as plain fills (`RoundedRectangle.fill`), never `.glassEffect`. |
| `glass` | iOS 26 Liquid Glass (`.glassEffect` / system bars). The mock draws it as white 6.25 % with blur 24 / saturation 1.5 and a hairline. | **Only the floating navigation layer:** the tab bar, toolbar buttons (Settings, Minimize, Cancel, Finish, Done), and the floating rest bar with its +15s. Nothing that scrolls with content is glass. |
| `glass-raised` | The rest bar: glass over `#24252A` at 80 % plus a shadow of 0 −6 40 black 55 % (solid ≈ `#222328`) | The one floating bar over content. |
| `well` | white 7 % on card (≈ `#292A2E`) | Editable fields (draft weight and reps). |
| `fill-2` | white 8 % on card | Round icon buttons inside a card (Previous performance, options). |
| `hairline` | white 7–8 % | Separators and borders. It never draws a shape alone. |
| `pearl` | `#F3F1EC` | Primary text **and the one filled command per screen state** (Start pair, Skip, View in History). Also the neutral live figures: the sets ring, the rest ring, completed-set checks and the next-up ring. The selected tab uses pearl as a state, not as a command. |
| `text-2` | `#A7ACB6` | Secondary text, labels, units, last-time values. |
| `text-3` | `#8A8F99` | Tertiary text: untrained family labels, column headers, "+N more", rest-day letters. |

### Data chroma: the only hues in the app

| Token | Hex | Meaning |
|---|---|---|
| `chest` | `#EA43CE` | Chest family (magenta; moved out of the pink-red band) |
| `back` | `#2C76F5` | Back family |
| `shoulders` | `#2BDCC8` | Shoulders family |
| `arms` | `#B194FF` | Arms family (lavender) |
| `legs` | `#B3EE77` | Legs family |
| `pulse` | `#FF5262` | Heart rate: the bpm number and the heart glyph. It equals Z3 and is the only red in the app. |
| Zone ramp (heart-rate intensities) | Warm-up `#77737D` · Z1 `#B54450` · Z2 `#DC4B5A` · Z3 `#FF5262` · Z4 `#FF7D7B` · Z5 `#FFAFA6` | Heart-rate zones. One red hue that **steps in lightness** (L\* 45 · 53 · 60 · 68 · 79), so each zone is told apart by brightness, not only hue. It replaces `ZoneColors.swift`. |
| `warmup` | `#F2D06B` | Warmup set marker "W" |
| `drop` | `#B5E2FF` | Drop set marker "D" (ice; the old lilac collided with Arms) |
| `failure` | `#FF8A2B` | Failure set marker "F" (orange; the old red collided with heart rate) |

**Separation (CIEDE2000, sRGB D65), measured on these hexes:**
- Chest vs pulse **25.7**; chest vs every zone ≥ **24.7** (nearest: Z2). The old pink measured 18.6 and 14.8.
- Chest vs arms 20.5; back vs arms 20.5; failure vs warmup 24.7; failure vs Z4 22.7.
- Z1 vs Z2 **8.7** (L\* 45.0 vs 52.9; it was 46.7 vs 50.7).
- **Families are also ordered by lightness** (relative luminance): back .201 < chest .260 <
  arms .377 < shoulders .559 < legs .721.

- **Destruction has no hue.** Actions are monochrome, so a destructive command is pearl or
  glass with its word or trash glyph and is always confirmed. The swipe-to-delete tile is a
  raised tile with a pearl trash glyph. System confirmation dialogs keep the system red on
  their destructive button (system chrome). This keeps red for heart rate only. **This is a
  new decision for approval** (see Review responses).
- The old unit-chip colours (kg blue, lb mint, mixed lilac) and the calorie pinks are removed.
  Units are plain `text-2`, and calories are pearl.
- **Where family colour is allowed:** muscle maps, family set counts, the week bars, the finish
  status ring. **Where it is never used:** exercise rows, exercise cards, set numbers, checks,
  the rest ring, the sets ring, "New best".

### Measured WCAG contrast (sRGB relative luminance; every pair the artboards use)

Surface values are the solid fills above. "Best pill" = pearl 14 % on card, `#38383B`.
"Medal" = pearl 12 % on sheet card, `#38393C`.

| Text ↓ / ground → | ink | card | sheet | sheet card | well | rest bar | tab bar `#17181C` | selected tab `#333437` | best pill | medal |
|---|---|---|---|---|---|---|---|---|---|---|
| pearl | 17.43 | 15.40 | 16.71 | 14.42 | 12.70 | 13.89 | 15.72 | 11.03 | 10.35 | 10.23 |
| text-2 | 8.64 | 7.63 | 8.28 | 7.15 | 6.29 | 6.89 | 7.79 | — | — | — |
| text-3 | 6.06 | 5.36 | 5.81 | 5.01 | not used | — | — | — | — | — |
| chest | — | 5.13 | — | 4.80 | — | — | — | — | — | — |
| back | — | 4.15 | — | — | — | — | — | — | — | — |
| shoulders | — | 10.08 | — | 9.43 | — | — | — | — | — | — |
| arms | — | 7.08 | — | 6.63 | — | — | — | — | — | — |
| legs | — | 12.76 | — | — | — | — | — | — | — | — |
| pulse | — | 5.49 | — | 5.14 | — | — | — | — | — | — |
| warmup | — | 11.60 | — | — | — | — | — | — | — | — |

- Ink on pearl is 17.43 (Start, Skip, View in History, the check glyph in a completed set).
  Pearl on ink discs is 17.43.
- **Every normal-size text pair clears 4.5:1.** The one exception is back on card, 4.15, used
  only for the 20 pt heavy "8" set count (large text, needs 3:1).
- Non-text (3:1): the zone ramp on sheet card measures Warm-up 3.51, Z1 3.03, Z2 4.03, Z3 5.14,
  Z4 6.57, Z5 9.25. The live zone meter on card measures Z1 3.24 and Z2 4.30.
- An unlit muscle map is deliberately dim (body `#30333A` on card, 1.37). "Not trained" is also
  carried by the `text-3` label and the missing count. A lit body `#4C515C` measures 2.18, and
  its muscle carries the data at 4.15 or more.
- The current exercise card's brighter hairline (pearl 22 %, 1.94 on card) is a supplementary
  cue only; the next-up set's pearl check ring (15.4) is the state cue that meets 3:1.

---

## 2. Type

The mock uses stand-ins: `ui-rounded, "SF Pro Rounded", Nunito`. Safari shows real SF Pro
Rounded; elsewhere Google Fonts Nunito 500–1000 renders. Body text uses
`-apple-system, "SF Pro Text"`. Every style ships as a Dynamic Type text style with
`.fontDesign(.rounded)` where marked. There are no bundled fonts.

| Role | Native (default size) | Mock |
|---|---|---|
| Screen title "Workout" | Large Title 34/41, **Bold**, Rounded | Nunito 800 34/41 |
| Status headline "Workout saved" | Title 1 28/34, **Heavy**, Rounded | Nunito 900 28/34 |
| Big figures: clock, rest time, tile values | Title 1 28, Heavy, Rounded, `monospacedDigit()` | Nunito 900 28 |
| Comparison figure "6%" | Large Title 34, Heavy, Rounded, monospaced digits | Nunito 900 34 |
| Vitals figures (bpm, cal, lb) | Title 2 22, Heavy, Rounded, monospaced digits | Nunito 900 22 |
| Section titles ("Templates" 22; "This week", "Workout details", "New bests", "Heart rate", "Exercises" 20), exercise card title | Title 2 / Title 3, Bold, Rounded | Nunito 800 |
| Family set counts, best values | Title 3 20 / Headline 17, Heavy, Rounded | Nunito 900 |
| Tile names, button labels, set values | Headline 17, Bold, Rounded | Nunito 800 |
| Row titles, "Working sets" | Headline 17 / Subhead 15 Semibold (SF Pro Text) | system 600 |
| Support text (tile exercise names, summary line, Target caption, "Rest", the Next line) | Subhead 15 / Footnote 13, Regular–Semibold | system |
| Labels (tile labels, date, "+N more", last-done date, vitals labels, "Zone 2", column headers, "New best") | Caption 1 12, Semibold/Bold | system 600/700/800 |

Numbers are big and heavy; labels are small. **Nothing on the live screen is below 12 pt.** The
Black weight is not used.

---

## 3. Shape, space, elevation

- **Margins:** 20 pt on every screen, for content and chrome alike (gear, Finish, Done, and the
  tab bar inset). There is one left edge per screen.
- **Spacing scale:** 2 · 4 · 6 · 8 · 10 · 12 · 16 · 20 · 28 · 32. Space between sections is
  28–32; space inside a group is 10–12.
- **Radii:**
  - 28: floating bars (rest bar)
  - 24: content cards, list groups, the status card, This week
  - 20: stat tiles and the vitals strip
  - 14: inner rows, the equipment row and the Add Set slot
  - 12: input wells
  - capsule (height ÷ 2): buttons and chips
- **Elevation:** ink ground → card (solid, grouping) → glass (floating navigation only) → pearl
  (the one command, with a 10 % pearl halo 0 10 28). Sheets sit on `sheet` with `sheet card`s.
- **Dashed hairline** (pearl 18–22 %) means *create something here*: New Template…,
  Ask AI for Templates, Add Set.
- **Hit targets:** at least 44 pt everywhere. Set rows are 48, capsules 44–56, and icon
  buttons have a 44 hit area around a 38 visual.
- **Safe areas:** the rest bar's lower edge sits 42 pt above the screen bottom, 8 pt clear of
  the 34 pt home-indicator zone.

## 4. Iconography

- The native build uses SF Symbols only. The mock draws clean stroke stand-ins (24-unit grid,
  round caps, 1.9–2.4 stroke):
  - `gearshape`, `mappin.and.ellipse`, `chevron.up.chevron.down`
  - `figure.strengthtraining.traditional`, `figure.run`
  - `clock.arrow.circlepath`, `building.2`, `list.bullet.rectangle`
  - `plus`, `sparkles`, `chevron.down`, `chevron.right`, `pencil`
  - `heart.fill`, `flame.fill`, `flame`, `scalemass`, `timer`, `hourglass`
  - `chart.line.uptrend.xyaxis` (Previous performance), `ellipsis`, `checkmark`, `star.fill`,
    `square.on.square`, `arrow.up`
- **Tab bar:** the same four symbols and labels (Workout `figure.strengthtraining.traditional`,
  History `clock.arrow.circlepath`, Gyms `building.2`, Exercises `list.bullet.rectangle`). Only
  the material changes: a glass capsule whose selected tab is a pearl glyph on a white 12 % lozenge.
- **Icon discs:**
  - The Start pair has ink discs holding pearl glyphs.
  - The creation tiles have white 10 % discs.
  - **"New best" is family-independent everywhere:** a pearl star in a pearl 12–14 % pill or
    disc (live pill, finish medals, the star in the Exercises list).
- **One custom symbol is proposed:** "machine" (a seat plus a weight stack) for the equipment
  row. It replaces `gearshape.2`, which reads as settings. It ships as a custom SF Symbol
  template so it scales with Dynamic Type. **Flagged for approval.**
- **Muscle maps** are the user's two-layer assets. The body layer is grey. **Lit = the muscle
  layer filled with the solid family colour on a lighter body (`#4C515C`); there is no glow,
  bloom or shadow.** Unlit = muscle `#3F434C` on body `#30333A`. They appear only as summaries:
  template tiles (32 pt), This week (68 pt) and the Finish families card (62 pt). **They never
  appear on exercise rows or in the live workout.**

## 5. Motion

Every animation answers a user action or a live state. Every one has a Reduce Motion
alternative.

| # | Trigger | Motion | Haptic | Reduce Motion |
|---|---|---|---|---|
| 1 | Home appears | Lit families fill in, in canonical order: the muscle goes from dim to its full colour, 90 ms stagger, 0.7 s. The week bars grow from their baseline. | — | Rendered filled and grown, with no motion |
| 2 | Press any capsule, tile or card | Scale to 0.97 (0.96 for small controls), spring back | Start: `.workoutStart` (heavy) | Opacity dips to 0.8 |
| 3 | Heart rate live and fresh | The heart glyph beats at the live bpm (period = 60 / bpm). When stale, it stops and greys, and "· Ns ago" shows. | — | Static heart |
| 4 | Next-up set (live state) | Its pearl check ring breathes a 2.4 s pearl halo. The row is never enlarged. | — | Static ring |
| 5 | Complete a set | The check fills pearl and pops (0.55 → 1.16 → 1, 520 ms) with a pearl ripple, and the row flashes pearl 12 % → 0 over 1 s. The header sets ring extends (500 ms). The volume figure updates. | `.setComplete` | Instant fill, no ripple or flash; the haptic stays |
| 6 | The set is a new best | The pearl "New best" pill scales in beside last time's value, with a star twinkle | `.success` | Appears instantly |
| 7 | Rest running | The pearl ring drains continuously (1 s linear per tick). +15s eases the ring up. A restart refills it. In the last 10 s the ring throbs (1 s). | End: `.restDone` plus the alarm | Stepwise drain, no throb; the bar crossfades out |
| 8 | Skip / rest ends | The rest bar drops away under the thumb (spring 300 ms) | — | Crossfade |
| 9 | Finish sheet appears | The status ring draws family by family (700 ms, staggered 250 ms), the check lands (spring), and the new-best medals shine once (a pearl halo). The families card's maps fill in when it scrolls into view. | `.success` as the check lands | Everything drawn complete, still |
| 10 | Live workout minimised (Home live state, not drawn) | The Resume capsule's live dot breathes | — | Static dot (as today) |

The earlier "fold finished exercises" motion is **removed**: every exercise stays expanded in
template order, as today.

## 6. Signature engagement devices

1. **Lit anatomy.** One component, used in summaries only: This week on Home (below the Start
   pair) and the families card on Finish (below the tiles). The five family maps sit in
   canonical order: lit = trained, dim = not yet, with working-set counts under each. The same
   picture means the same thing everywhere.
2. **The family ring at Finish.** The kept status ring is segmented by working sets per family
   (Chest 9, Shoulders 7, Arms 4) and draws in as the celebration. It is the one ring that
   carries family colour; the live rings are neutral pearl, like the Codex A ring the user chose.
3. **A calm, neutral workout.** During a set there is no family colour, word or dot. The live
   screen is pearl figures, pearl checks and heart-rate red, so the eye goes to numbers.
4. **Heat, not a rainbow.** Heart rate owns red. Zones are its intensities, stepping in
   lightness, so each finish bar colours itself by the zone its beats reached.
5. **Pearl = do this.** Exactly one filled command per state (Start pair, Skip, View in
   History). Everything else is a solid card or glass chrome.
6. **Progress as data, never coaching.**
   - A live "New best" pill beside last time's value, so the comparison stays visible.
   - The finish "New bests" medals.
   - "6% vs Push Day, Sep 17" with two honest zero-based bars.
   - The "Next · Set 3 · 110 × 8" preview in the rest bar.
   - This week's family-split day bars.
   - Last-done dates on template tiles.

**Screens without families** (cardio live, paused and finish; Gyms; scanning; Settings):
- Cardio's data colour is heart rate. The proposed cardio live screen tints its big timer ring
  by the current zone (the ramp above), and the cardio finish ring is segmented by time in
  zones, the same way the lifting ring is segmented by family. Cardio is therefore not a grey
  screen; it is the red one.
- Gyms, scanning and Settings are pearl on cards; their data (machine counts, last used, best
  set on a machine) uses the same big-number / small-label pattern. They are not drawn in this
  round.

## 7. How the user's likes and dislikes are honoured

**Likes**
- **Real pictures, side by side.** Three artboards sit next to the Current-* boards.
- **Apple Fitness:**
  - rings (a family ring at Finish; small neutral rings in the workout);
  - big heavy-rounded numbers with 12–13 pt labels;
  - a thin floating-range HR graph with 3.4 pt bars, no gridlines and four labels (158 · 90 ·
    6:12 PM · 7:04 PM).
- **Bold, graphic, saturated, not text-heavy.**
  - Saturated family colour is used big, as solid fills: maps and the finish ring.
  - Template tiles list two exercise names and "+N more", not a run-on paragraph.
  - Orphan captions are removed.
  - One visual language replaces three button styles.
- **Big pill buttons with an icon disc.**
  - Start Lifting and Start Cardio are two EQUAL pearl capsules side by side, each with an ink
    activity disc and no arrows, **directly under the gym picker as today**.
  - They stack only when the labels don't fit.
  - Resume stays the same capsule.
- **Template grid.**
  - Two columns, top-aligned rows of equal height.
  - "New Template…" stays a tile.
  - Tapping a tile opens its exercise list; Delete stays inside.
  - No long-press.
- **Accurate muscle maps per family.** The user's assets are used as summaries only
  (templates, This week, Finish).
- **Live screen = today's skeleton.** Nav bar: minimise · Cancel | name | Finish. Header line:
  gym chip · a 28 pt clock with seconds · a small neutral "7/18 sets" ring. Each exercise card
  keeps its Target caption. The rest bar keeps the draining ring with an hourglass, "Rest" over
  the time, "+15s" and "Skip". Swipe-to-delete sets and drag-to-reorder exercises are
  unchanged. Exercises stay expanded in template order.
- **Finish = the kept receipt.** The ring at leading with "Workout saved" and the summary
  beside it; View in History (primary) and Save as Template (secondary); the "Workout details"
  section with paired tiles in the user's order: Workout time | Total volume, Active calories |
  Total calories, Avg. heart rate | Max heart rate; time in zones directly below the HR graph,
  with no tap.
- **Plain words and numbers.**
  - No ≈, no "estimated", "1RM" only.
  - The HR source caption ("AirPods") is moved into VoiceOver.
  - Missing HR or calories: the cell or tile is absent, never 0.
- **Cardio focus.** The Lifting | Cardio switch stays. It is restyled as a segmented control
  (not drawn).

**Dislikes (not reintroduced)**
- **"Boring / mostly texts / messy / mild":** one 20 pt edge; equal-height, top-aligned grid
  rows; no orphan footnote; no equal-weight grey blocks; colour only where it is data; no neon
  glow.
- **A muscle icon on every exercise row:** none, and no substitute either: no family word, dot,
  tint or border on any exercise card or row, live or at Finish.
- **Magnified current set:** none. Next-up is marked only by a breathing ring on its check.
- **Giant elapsed hero:** none. The clock is 28 pt, inside the header line.
- **Helper paragraphs, coach marks, tutorials:** none.
- **Long-press menus on tiles:** none.
- **Auto-added set rows or other unrequested automation:** none. Nothing folds by itself.
- **Live map during cardio:** none.
- **Tab-bar icons changed:** no. The four symbols and labels are kept; only the bar's material
  and the selection tint (pearl, not amber) change.

## 8. AccessibilityL (AX1) adaptations

AX1 sizes are about: Large Title 44, Title 1 38, Title 3 31, Headline and Body 28, Footnote 23,
Caption 1 22, Caption 2 20.

**Home**
- **Order is fixed: gym picker → Start pair → This week → Templates.** Start stays in the
  first viewport at AX1 (estimated to end near y 450 of 932); the family list comes after it.
- **Gym picker:** it becomes a full-width rounded rectangle, with the city and "lb" under the
  name.
- **Start pair:** `ViewThatFits` stacks it into two full-width capsules.
- **This week:**
  - The trailing "2 workouts · 1 h 43 min" moves under the title.
  - The five-column map row becomes a five-row list: a 44 pt map, the family name, and the
    count trailing.
  - The week strip keeps seven columns. Bars scale 1.3× via `@ScaledMetric`, and the letters
    fit.
- **Templates:**
  - One column.
  - The map strip wraps; the two names and "+N more" each take their own line.
  - The creation pair stacks full width.
- **Tab bar:** system behaviour (large-content viewer on long press).

**Live**
- **Nav bar:** Minimize, Cancel and Finish keep their size (large-content viewer on long
  press); the workout name truncates first.
- **Header:** it splits into two lines. Line one holds the clock and the sets ring; line two
  holds the gym chip.
- **Vitals strip:** it becomes three rows, value leading and label trailing, each at least
  44 pt tall.
- **Exercise card:** the Target caption wraps under the title; the title actions drop to their
  own trailing line.
- **Set grid:**
  - The column headers hide.
  - Each set becomes a two-line block, as today. Line one: marker · previous · (New best) ·
    check. Line two: the weight and reps wells, with inline "WEIGHT" / "REPS" labels.
  - The New best pill wraps under the previous value if the line runs out.
- **Rest bar:** it becomes two rows. Row one: ring, "Rest" and the time. Row two: +15s and Skip
  at equal full width, as in the ticket-16 fix. The Next line sits between them and wraps. It
  is capped at about 22 % of the screen.

**Finish**
- **Status card:** the ring stays at leading and scales to 120 pt (`@ScaledMetric`, capped);
  "Workout saved" and the summary wrap beside it. From AX3 the text drops under the ring.
- **Stat tiles:** one column, in pair order.
- **Families card:** the map row becomes five rows, as on Home.
- **New bests and exercise rows:** the value moves under the name.
- **Comparison:** the labels sit above full-width bars.
- **HR chart:**
  - The chart grows 1.25×.
  - Only the first time label shows; both bpm labels stay.
  - The zone rows become two lines: name and time on the first, the bar full width below.

## 9. New visible strings (exact text; each is the user's decision)

**Home**
- Date above the title: "Thursday, Sep 24" (format `EEEE, MMM d`).
- "This week".
- "2 workouts · 1 h 43 min" (format `{n} workout(s) · {h} h {m} min`).
- Under the maps:
  - "0 sets", "8 sets", "3 sets", "14 sets" (format `{n} set(s)`, which already exists in
    summaries; these are working sets);
  - the family names "Chest", "Back", "Shoulders", "Arms", "Legs" (existing domain names, newly
    visible as text).
- Week-strip letters "S M T W T F S" (the locale's very short weekday symbols, in the locale's
  first-weekday order).
- Template tiles: the first two exercise names, then "+2 more", "+3 more", "+4 more" (format
  `+{n} more`; when a template has three or fewer exercises, all names show and there is no
  "+N more").
- Template last-done: "Mon", "Wed", "Sep 17", "Sep 10" (a weekday name within this week, else
  `MMM d`).

**Live**
- "New best".
- "First time": shown instead of "New best" for the first-ever eligible set (not drawn).
- "Next · Set 3 · 110 × 8" (format `Next · Set {n} · {w} × {r}`) and
  "Next · Incline Chest Press" (format `Next · {exercise}`).
- Vitals labels "Active calories" and "Total volume": existing finish strings, newly used in
  the live strip.

**Finish**
- "Working sets" (the families card label; it reconciles the 22 sets in the summary, which
  include 2 warmups, with the 9 + 7 + 4 = 20 working sets per family).
- "New bests".
- "6%" with an up arrow (VoiceOver: "Up 6 percent"), "Total volume", "vs Push Day, Sep 17"
  (format `vs {template}, {MMM d}`), "Today", "Sep 17".
- Map counts "9 sets", "7 sets", "4 sets".
- Exercise sub-lines "Chest Press 2 · 6 sets" (format `{equipment} · {n} sets`) and trailing
  bests such as "110 lb × 8" (the existing best format without the word "best").
- HR chart labels "158", "90", "6:12 PM", "7:04 PM".

**Dropped from the first proposal:** the family word "Chest" on exercise cards, the folded
line "4 sets · best 80 lb × 10", and the "Discard Workout" button.

## 10. Moved or removed strings (for approval)

**Kept where they are today** (restored after review): the live nav "Cancel" beside Minimize
(now a glass capsule without red; its confirmation "Cancel this workout?" is unchanged), the
live "Target: 3 sets · 10, 8, 8 reps" caption, the Home gym picker's "lb" chip, the Finish
inline title "Nice work", and the Finish "Workout details" section header.

**Still moved or removed:**
- **HR bar "· set up zones" / "· edit zones":**
  - The whole heart-rate cell becomes the button that opens the Heart Rate sheet (VoiceOver
    hint "Edits zones").
  - With no zone basis, the zone line reads "Set up zones".
  - The gate keeps its own way in.
- **HR source ("AirPods"):** moved to the VoiceOver label.
- **Per-row "lb" unit chip:** becomes a plain "lb" suffix inside the value. Tapping the suffix
  still toggles the unit.
- **Home "Machines resolve to your last-used at …" footer:** removed (an orphan developer note).
- **Ask AI for Templates:** now a tile beside New Template…, in the grid's last row. With an odd
  number of templates, New Template… fills the gap and Ask AI spans full width below.
- **Finish section order:** status card → View in History / Save as Template → Workout details
  (tiles, then the families card) → New bests → comparison → Heart rate with zones → Exercises
  (in template order).
- **Decisions to reopen explicitly:**
  - D54: "one warm accent". Amber is retired: pearl for actions, data chroma otherwise.
  - D54 copy freeze: sections 9 and 10.
  - The D15/D54 amber icon-disc capsules: the pattern is kept and restyled pearl.
  - Family colours: chest becomes magenta `#EA43CE`, back a deeper blue `#2C76F5`, arms a
    lighter lavender `#B194FF` (shoulders and legs keep their hue).
  - `ZoneColors`: the lightness-stepped red ramp.
  - The set-kind colours: drop becomes ice, failure becomes orange.
  - Destructive: no hue.

## 11. Stored data

**No new stored data is needed.** Everything shown is derived on read:
- **Sets per family (week and finish):**
  - Derived from completed **non-warmup** sets → `entry.exercise?.muscleGroup` →
    `MuscleFamily`. The Finish card says "Working sets" so it does not contradict the summary's
    total, which counts warmups.
  - **Caveat (D\*):** `muscleGroup` is live, not snapshotted. Accepting that is the one D23
    exception this view needs.
  - Minutes come from `Workout.duration`.
- **Template tile names:** the template's first two entries in order, plus the remaining count.
- **Template last-done:** the latest finished workout with the template's `sourceTemplateID`.
- **New bests and "First time":** `RecordsMath` per machine or free-weight tag plus preset.
  Warmups are excluded, assisted is lower-is-better, and ties are not bests. Derived, never
  stored (D47). In the sample, set 3 at 110 × 8 ties set 2, so completing it shows no pill.
- **Comparison:** the previous finished workout from the same template. Weighted volume only.
  It is hidden when there is no previous workout or the baseline is 0.
- **Next-set preview:** the next draft row of the current entry, else the next entry's name.
- **HR bars and zones:** the existing 15 s series and `zoneSeconds`.
- **Not proposed:** no week streak (6 weeks is derivable, but it is left out to keep Home
  quiet). No weekly goal (that one would need a new `AppPreferences` field).

---

## 12. Review responses

Three judges reviewed the first version. Every critical fix is applied; this section says how,
and where I disagree.

**Applied**
- **Home order.** The Start pair sits directly under the gym picker; This week follows as a
  solid card (radius 24, no longer styled as the hero). §8 now fixes the AX order so Start stays
  in the first viewport.
- **Home tiles.** The run-on clamped paragraph is replaced by two names and "+N more", which
  shares the footer line with the last-done date so the tile height and the 1250 artboard stay
  the same. The gym picker's "lb" chip is restored.
- **No glow.** The blur layers on the maps and the drop-shadow glows on the finish ring are
  gone. Lit = solid family colour on a lighter body.
- **Surfaces.** §1 splits `card` (solid fills for all content) from `glass` (tab bar, toolbar
  buttons, rest bar only). The artboards follow it.
- **Palette.** Chest moves to magenta `#EA43CE` (25.7 from pulse, ≥ 24.7 from every zone). The
  zone ramp steps in lightness (Z1 vs Z2 L\* 45 vs 53). Back and arms shift slightly to keep
  them ≥ 20.5 from chest and each other and to keep the lightness order. I chose magenta over
  orange so that orange/amber stays free (see "pearl commands" below) and so B does not share
  Direction A's chest colour.
- **Live, family marking.** The "● Chest" eyebrows, the radial wash and the pink border are
  gone. Set numbers, checks, the next-up ring, the ripple and the row flash are pearl. The sets
  ring is one pearl arc; the rest ring drains in pearl, so heart-rate red is the only warm
  figure in the vitals row.
- **Live, scenario.** The folded Machine Shoulder Press and motion #9 are removed; Seated Chest
  Press is first and Incline Chest Press follows, both expanded. The Target caption and the
  nav "Cancel" are restored.
- **Live, data.** Set 3's PREVIOUS is 105 × 8, so set 2 at 110 × 8 is a real new best and set 3
  would be a tie. The "New best" pill is pearl, family-independent, and sits **beside** "105 × 8"
  (the column widths were rebalanced to 30 / flexible / 78 / 48 / 44 to fit it).
- **Live, legibility.** The rest bar sits at bottom 42 (8 pt clear of the home indicator).
  "Rest" and the Next line are 13 pt, the vitals labels and column headers 12 pt. To fit the
  full "Next · Incline Chest Press" at 13 pt, the Next line now runs under +15s and Skip (the
  bar's parts and order are unchanged).
- **Finish.** The kept top is back: a 96 pt ring at leading in a status card, "Workout saved"
  and the summary beside it, then View in History and Save as Template, then "Workout details"
  and the tiles. "Nice work" is the inline title again. The families row moved below the tiles
  as a card labelled "Working sets", which resolves 22 vs 20. The Exercises rows have no dots and
  follow template order; stars and medals are pearl.

**Where the fixes conflicted.** One fix said to keep the current card's family label and border;
another said to delete the label and the pink border. I followed the stricter one, because the
user's own words were "I want them gone. In workout too." The current card is marked instead by a
brighter neutral hairline (pearl 22 %), and the next-up set by its breathing pearl check.

**Where I disagree, and why**
- **"All commands are pearl; a monochrome Start pair and Skip risk 'mundane'."** I keep pearl.
  The concept is that colour always means data; a coloured command would break that on every
  screen. Pearl is not grey: it is the brightest, highest-contrast object on each screen
  (17.4:1), and the capsule-with-icon-disc shape the user defended is unchanged. If the user
  still misses warmth, the command colour is one token, and chest was deliberately moved away
  from orange so that an amber command could return without a clash.
- **"Destructive actions have no hue, which drops the iOS convention."** I keep no hue in the
  app's own controls, because the brief requires heart rate and destructive to be distinct and
  red is heart rate here. Destructive commands are still unmistakable: they use the words
  Cancel/Delete or a trash glyph, and every one is confirmed by a system dialog whose
  destructive button keeps the system red. This is flagged as a decision for the user.
- **"Colour has nothing to say on screens without families."** Partly agree. Cardio's data
  colour is heart rate, so cardio screens are the red ones (zone-tinted timer ring, zone-
  segmented finish ring; §6). Gyms, scanning and Settings stay pearl on cards, which I think is
  right for utility screens.

**Sample-data notes**
- The header reads 7/18 sets, as the shared scenario says, although only three of Seated Chest
  Press's sets are visible. I kept the scenario number rather than invent where the other four
  came from.
- Set 3's draft stays 110 × 8 (the scenario's draft, carried forward from set 2) while its
  PREVIOUS is 105 × 8.
- The Incline Chest Press target "4 sets · 10, 10, 8, 8 reps" is sample data, consistent with the
  4 sets it shows at Finish.
