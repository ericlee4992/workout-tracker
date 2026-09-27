# Direction A: Floodlight

**The idea in one sentence:** the app looks like a night-game scoreboard. The ground is black, numbers and titles are heavy, wide floodlight-white type, and anything you finish lights up like a scoreboard bulb. One hot ultraviolet ("Ultra") marks the single thing to do now, or the thing that is live now.

Artboards (all 430 pt wide, drawn at default text size). Revision 2 applies the three judges' findings; see §13.

| File | Size | Interactive | Notes |
|---|---|---|---|
| `canvas/project/DirA-Home.dc.html` | 430 × 1300 (was 1190) | no | Workout tab, idle, full scroll. Taller because This week now carries a full-width row of five muscle maps and each template tile has a last-done line. The floating tab bar is **pinned to the artboard bottom**, which is the scrolled-to-the-end state. |
| `canvas/project/DirA-Live.dc.html` | 430 × 932 | **yes** | First viewport of the live Push Day workout. The rest countdown ticks, and so does the clock. Tapping set 3's check stamps the set, bumps 7/18 → 8/18, counts the volume up 4,120 → 5,000 lb and restarts rest at 2:00. **Skip** ends rest. **+15s** adds time. The Tweak `set3Weight` = 115 previews a completed set that beats the best (110 is a tie, so no plate). |
| `canvas/project/DirA-Finish.dc.html` | 430 × 1944 (was 1900) | no | Push Day finish sheet (`.large`), full scroll. Taller because "Workout saved" is now drawn at the true Title 28 and wraps to two lines. |

---

## 1. Palette

Dark only. The ground is a neutral near-black. The current screens use blue-graphite #0B0D10 and "Ink/Amber"; this ground is deeper and colder.

| Token | Hex | Its one meaning |
|---|---|---|
| `night` | #060708 | Screen and sheet ground |
| `stand` | **#181A1E** (was #111215) | Panels (groups of content). Raised so a panel reads as a shape by its fill, not by its hairline. |
| `cell` | **#22252A** (was #191B1F) | Editable fields, the machine row, the secondary button, past day cells |
| `rule` | white @ 10 % | Hairlines. It separates; it never draws a shape by itself. |
| `flood` | #F4F6F8 | Text and numbers. As a **fill** it means **done or lit**: a completed set, a trained day, a lit ring segment, a stamp. (The New best mark is no longer a flood fill; see §7.4.) |
| `dim` | #A4A9B1 | Secondary text and neutral glyphs |
| `faint` | #7F858E | Tertiary text: dates, axis labels, "+ N more". Never the only carrier of essential meaning. **Only on night, stand or glass**, never on `cell` (4.13:1 there). |
| **`ultra`** | **#B25CFF** | **The one action or the live thing, and nothing else.** Start pair, View in History, the rest ring and Skip while resting, and the next set's check once rest has ended. |
| `ink` | #060708 | Text and glyphs on `ultra` and `flood` fills |
| `pulse` | #FF4F86 | Heart rate: bpm numbers, heart glyphs, HR zones |
| `danger` | #FF5E3A | Destructive controls only (Cancel in the live nav bar, Delete, swipe-delete tile). Never data. |

**Why ultraviolet.** Heart rate (`pulse`, rose, hue 341°) and destruction (`danger`, red-orange, hue 11°) must stay distinct from each other, and the chest (hue 31°) and arms (hue 49°) families sit right beside them, so the warm half of the wheel is already full. Every warm accent measured (coral, red, orange, tangerine, amber, gold, hot pink, magenta) lands within 6–11 ΔE00 of one of those four. Ultra is the hot end of the spectrum, the colour of a stadium's LED light show. It is 27 ΔE00 from pulse, 43 from danger, and 58 or more from the warm families. It also keeps this direction clear of the other two proposals' lime and cobalt. It is the direction's main taste risk (see §13).

**Ultra follows "now"** (drawn in the Live artboard). While rest runs, the Ultra items are the draining ring and Skip. When rest ends, Ultra moves to the next set's check box. It never appears on more than one role at a time. The audit counted about 9 amber elements on the current workout screen; this screen has at most 2 Ultra elements.

### Surfaces

Stand on night measures 1.16:1 and cell on stand 1.13:1 (was 1.08 and 1.09). Those are fill steps, not text contrast. They are now large enough to see as shapes without the hairline, which stays as a separator.

### Measured contrast (WCAG 2.x, glass values composited over `night`)

| Text | Hex | Background | Hex | Ratio |
|---|---|---|---|---|
| Floodlight text | #F4F6F8 | Night | #060708 | 18.61:1 |
| Floodlight text | #F4F6F8 | Stand (panel) | #181A1E | 16.08:1 |
| Floodlight text | #F4F6F8 | Cell (field) | #22252A | 14.19:1 |
| Floodlight text | #F4F6F8 | Glass (toolbar, tab bar) | #171A1E | 16.11:1 |
| Floodlight text | #F4F6F8 | Rest-bar glass | #141619 | 16.73:1 |
| Floodlight text | #F4F6F8 | Selected tab pill | #313337 | 11.68:1 |
| Floodlight text | #F4F6F8 | Done field (white 4.5 % on stand) | #222428 | 14.35:1 |
| Floodlight text | #F4F6F8 | +15s pill | #222427 | 14.36:1 |
| Dim text | #A4A9B1 | Night / Stand / Cell | | 8.53 / 7.37 / 6.51:1 |
| Dim text | #A4A9B1 | Glass / Rest bar / Done field / Tab pill | | 7.39 / 7.67 / 6.58 / 5.36:1 |
| Faint text | #7F858E | Night / Stand / Glass / Rest bar | | 5.42 / 4.69 / 4.70 / 4.88:1 |
| Ink on Ultra (Start, Skip, View in History) | #060708 | Ultra | #B25CFF | 5.63:1 |
| Ink on Floodlight (lit cells, stamp, "↑ 6%" plate) | #060708 | Floodlight | #F4F6F8 | 18.61:1 |
| Ink 62 % on Floodlight (day letter, "min" at 11 pt) | #606263 | Floodlight | #F4F6F8 | 5.66:1 |
| Pulse numbers | #FF4F86 | Stand / Night | | 5.57 / 6.45:1 |
| Danger text ("Cancel") | #FF5E3A | Glass / Night / Stand | | 5.75 / 6.64 / 5.74:1 |

Flood on Ultra measures only 3.30:1, so Ultra fills always carry **ink** labels.

| Graphic (WCAG 1.4.11 needs 3:1) | Hex | On | Ratio |
|---|---|---|---|
| Ultra ring and Ultra check outline | #B25CFF | Rest bar / Stand | 5.06 / 4.87:1 |
| Neutral open check and draft marker outline (flood 42 %) | #74767A | Stand | 3.83:1 |
| **Draft field border** (flood 45 % over cell) | #808387 | Stand / Cell | 4.57 / 4.04:1 (was 1.78) |
| **Warmup marker dashed outline** (dim 62 %) | #6F7379 | Stand | 3.65:1 (was 2.84) |
| New best outline and burst | #F4F6F8 | Stand | 16.08:1 |
| Muscle families (see §2) | — | Stand | 6.25–13.42:1 |
| HR zones Warm-up, 1, 2, 3, 4, 5 | #7F858E, #9A5270, #C2577F, #E65C8E, #FF77A5, #FFB0CA | Stand | 4.69, 3.16, 4.12, 5.22, 7.00, 10.22:1 |
| Last-time volume bar | #686D76 (was #60656E) | Stand | 3.35:1 |
| Unlit muscle (untrained family) | #737983 | Stand | 3.98:1 |
| Unlit ring segment / unlit zone chip / muscle body layer (lit / unlit) | #34373D / #3A3E45 / #535862 / #464A52 | Night / Stand / Stand / Stand | 1.69 / 1.62 / 2.44 / 1.96:1 (decorative tracks and silhouettes. The adjacent text, "7/18", "Zone 2" and "0 sets", carries the value.) |

### HR zones

Zones use one **pulse ramp** in which lightness rises with intensity: Warm-up #7F858E, Z1 #9A5270, Z2 #C2577F, Z3 #E65C8E, Z4 #FF77A5, Z5 #FFB0CA. The ramp stays inside heart rate's colour, so it adds no hues. The HR chart colours each bar by the zone that part of the bar sits in: one user-space gradient with hard stops at 55/65/75/85 % of max, per D45.

### Set kinds

Set kinds are told apart by **letter and treatment, not hue**. This removes about four of the fifteen small hues the audit counted.
- **W, warmup:** a dashed outline cell (dim at 62 %), a dim value and a dim-grey stamp. Warmups don't count toward records or volume, so they read as "not lit".
- **D, drop / F, failure:** the letter on a solid outline cell, lit white when done.
- **Working sets:** their number.

The per-row mint "lb" chip is gone. The unit is a small `dim` suffix inside the weight field, and tapping it still toggles the unit. Pound and kilogram chip colours are retired.

**Weights with reps keep the existing order** from `PreviousSetValue.displayLabel`: `110 lb × 8`. The unit stays next to the weight everywhere: Previous column, rest-bar "Next" line, New bests and Exercises rows. It is never a trailing suffix after the reps, where it would read as "8 lb". Previous keeps its unit because it is the as-entered value and can differ from the gym's unit (D25, D52).

## 2. Muscle families

The families use the provided maps: a grey body (#535862) with a vivid muscle. They appear only as summaries: template tiles, "This week", and the finish hero and ring. They are never beside an exercise row.

| Family | Colour | Luminance | Hue | On stand |
|---|---|---|---|---|
| Back | #3D9EFF | 0.33 | 210° | 6.25:1 |
| Chest | **#FFA03C** (was #FF9447) | 0.47 | 31° | 8.58:1 |
| Legs | #84D65A | 0.54 | 100° | 9.75:1 |
| Shoulders | #4DE0D4 | 0.60 | 175° | 10.73:1 |
| Arms | #FFE15C | 0.76 | 49° | 13.42:1 |

- Luminance rises in steps across the five, so they separate in greyscale. The chest-to-legs step narrowed from 0.11 to 0.07; the hue gap (31° vs 100°) carries it.
- **Chest moved toward amber-orange** so it no longer sits next to `danger`. They appear together in template detail (chest map beside Delete) and on the swipe-delete tile.

| Pair (CIEDE2000) | ΔE00 |
|---|---|
| Chest #FFA03C – danger #FF5E3A | **21.6** (was 15.5) |
| Chest – arms #FFE15C | 22.8 |
| Chest – pulse #FF4F86 | 40.7 |
| Danger – pulse | 22.1 (danger unchanged, so heart rate and destruction keep their separation) |
| Pulse – ultra | 27.3 |
| Legs – shoulders / legs – arms | 26.0 / 23.9 |

- Three families keep today's hue: back stays blue (deepened so it separates from chest by lightness), shoulders stay teal, legs stay green.
- Chest moves from pink to amber-orange, because pink now means heart rate.
- Arms move from lavender to yellow, because violet now means Ultra.
- An untrained family renders **unlit in a visible grey**: body #464A52 and muscle #737983 (was #2E3137 / #4D525B, which almost disappeared). For example, Chest this week on Home.

## 3. Type

| Role | Native iOS face (Dynamic Type style) | Mock stand-in |
|---|---|---|
| Large title "Workout" | SF Pro **Expanded Black**, `.largeTitle` 34 pt (`.fontWidth(.expanded)`, `.black`) | Archivo wdth 125, wght 900, 34/41 |
| Hero headline "Workout saved" | SF Pro Expanded Black, `.title` **28**. It wraps to two lines at 430 pt and is never shrunk to fit. | Archivo 125 / 900, 28/32 |
| Scoreboard numbers: tiles, clock, rest time, day minutes, family set counts | SF Pro **Expanded Heavy** + `.monospacedDigit()`, `.title` 28 / `.title2` 22 / `.title3` 20 / `.headline` 17 | Archivo wdth 118–125, wght 800, tabular numbers |
| Section, card and exercise titles ("This week", "Seated Chest Press", template names) | SF Pro Expanded Heavy, `.title3` 20 / `.headline` 17. Titles wrap; they never truncate. | Archivo wdth 112, wght 800 |
| **Button labels** (Start Lifting, Start Cardio, View in History, Save as Template, Finish, Skip) | **SF Pro, standard width**, Bold, `.headline` 17 (`.bold()`). Expanded is kept for numbers and titles only. | system SF, 700, 17/22 |
| Body, row titles, values in controls | SF Pro Text Regular / Semibold, `.body` 17 / `.subheadline` 15 | system SF |
| Labels, captions | SF Pro Text, `.footnote` 13 / `.caption` 12 / `.caption2` 11. Nothing is smaller than 11. | system SF |
| Table header (SET · PREVIOUS · WEIGHT · REPS) | SF Pro Text Semibold `.caption2` 11, +6 % tracking, uppercase | as described |
| **NEW BEST mark** | SF Pro Text **Bold `.caption` 12**, +4 % tracking, uppercase, with a `burst.fill` glyph at the same size | system SF 700 12 |

- There are no bundled fonts; every size is a text style, so Dynamic Type scales all of it.
- Uppercase is limited to the existing column header and the New best mark. Units are lowercase everywhere ("cal", "bpm", "lb"), which fixes the "5 CAL" / "7 cal" mismatch.

## 4. Geometry, spacing, elevation

**Radii** are crisper than today's 24 / 16 / 10:
- panels 16;
- fields, cells and day cells 8–10;
- set marker 8, stamp 9, New best mark 6;
- buttons stay **capsules** (Start pair, View in History, Save as Template, Skip, +15s, Finish, Done);
- the sheet and tab bar use the system shapes.

**Margins and rhythm:**
- The side margin is **20 pt on every screen.** All left edges align at x = 20, which fixes the audit's three left edges.
- Section gap is 28–30.
- Header to content is 12.
- Panel padding is 14–16.
- Grid gap is 10–12.
- Row heights: set rows 48; list rows 60–64; controls ≥ 44 (gym row 56, Start capsules 64, primary 56, secondary 50).

**Start capsule budget (checked with real SF metrics).** Each capsule is 64 tall: 10 leading inset, a **44 pt** ink disc (was 48, so it now sits concentric with a 10 pt ring of Ultra), 8 gap, the label, 12 trailing. Label room: **116 pt at 430** (capsule 190) and **102 pt at the 402 pt simulator** (capsule 176). Measured in SF Pro Bold 17 without iOS's own tracking: "Start Lifting" 97.5 pt, "Start Cardio" 98.7 pt. iOS applies −0.43 pt per glyph at 17 pt, about −5 pt more. So both capsules stay side by side at default size on both phones, with about 8 pt to spare at 402. (SF Expanded Heavy would not fit; that is why labels are standard width.) Both widths were drawn and checked; `ViewThatFits` stacks them only from larger Dynamic Type sizes (§9).

**Scoreboard structure:** grouped numbers sit in ONE panel divided by hairlines (the finish tiles, the week footer and the live strip), not in six separate cards.

**Elevation:** panels are flat. The raised stand fill draws them; the hairline only separates. No shadow. Only floating chrome gets blur, a hairline and a shadow (0 16 40, 60 % black): the toolbar buttons, the tab bar, and the pinned rest bar. Nothing else floats.

## 5. Iconography

- Icons are SF Symbols at semibold weight. The mocks draw them as 24-unit stroke SVGs.
- **The tab bar keeps the four symbols and labels:** `figure.strengthtraining.traditional` Workout, `clock.arrow.circlepath` History, `building.2` Gyms, `list.bullet.rectangle` Exercises. The selected tab is a floodlight glyph and label on a lighter glass pill, not Ultra, because selection is a state, not an action.
- **`clock.arrow.circlepath` also marks "last done"** on each template tile, in `faint`, before the date, so "Sep 23" reads as the last time that template was done. It is the History symbol, so it points to where that date comes from.
- Other symbols:
  - `gearshape` (Settings)
  - `mappin.and.ellipse` (gym)
  - `chevron.up.chevron.down`
  - `figure.run`
  - `plus`, `sparkles`
  - `chevron.down` (minimise), `pencil`
  - `chart.bar.xaxis` (previous performance)
  - `ellipsis`
  - `hourglass`
  - `heart.fill`, `arrow.up.heart`
  - `flame.fill` / `flame`
  - `scalemass`, `timer`
  - `burst.fill` (new best: inside the NEW BEST mark live, in the outlined stamp on Finish, before the value in Exercises)
  - `checkmark`, `square.on.square`
- **Machine glyph:** the audit notes that `gearshape.2` reads as "settings". Floodlight uses a weight-stack glyph. That needs one **custom SF Symbol** template drawn in SF weight. This is flagged; the fallback is `dumbbell`.
- Glyphs are `dim`, `faint` or `flood`. They are Ultra only when they sit inside the action.

## 6. Motion

Every animation answers a user action or a live state. None is ambient decoration.

| Trigger | Motion | Reduce Motion |
|---|---|---|
| Tap Start Lifting / Start Cardio | Capsule presses to 0.97, then a heavy haptic | No scale; haptic only |
| Workout tab appears | This week's lit days light in order (Mon, then Wed, 120 ms stagger), the trained family maps light (muscle fades from unlit grey to its colour, 200 ms), and the week numbers count up | Static final state |
| Tap a set's check (**set-complete stamp**) | The white stamp drops in from 1.55× at −14°, overshoots, settles (340 ms spring). The set marker floods white (250 ms). The next header ring segment lights (300 ms). Volume counts up (600 ms, ease-out). Medium haptic. | Instant state change; numbers jump; haptic kept |
| A completed set beats the best (**new-best flash**) | The row double-strobes white (900 ms) and the outlined NEW BEST mark with its burst lands. Success haptic. | The mark appears; no strobe. The mark alone tells the best from a done set (outline + burst + words vs a white fill). |
| Rest starts | The rest bar rises 24 pt with a fade (320 ms) | Appears in place |
| Rest running | The Ultra ring drains continuously | The ring updates each second with no easing |
| Last 10 s of rest | Ring and hourglass turn Ultra → floodlight, and the ring beats once a second | Colour change only |
| +15s | The ring refills proportionally (1 s linear) | Jump |
| Rest ends (0 or Skip) | The bar leaves, and Ultra passes to the next set's check (300 ms colour cross-fade). Success haptic at 0. | Instant |
| Heart rate live | The heart glyph beats (1.1 s) while samples are fresh; it stops when stale | Static glyph |
| Finish sheet appears | The 22 ring segments light in sequence in their family colours (28 ms stagger), then the check stamps in. Stat tiles count up from 0 (900 ms). New-best stamps flip in. | Final state at once |
| Press on any capsule button | Scale 0.97 | Opacity 0.7 |

The static Home and Finish artboards show end states only, so canvas thumbnails are never caught mid-animation. The Live artboard runs the real stamp, count-up, ring and rest motion. The CSS honours `prefers-reduced-motion`, and the count-up checks it in JavaScript.

## 7. Signature engagement devices

1. **Lit cells.** Done is white. Completed sets, trained days and finished-set ring segments "switch on" like scoreboard bulbs. This single idea carries through all three screens.
2. **Segment ring.** "N/M sets" uses one segment per set: 18 segments live, and 22 segments as the finish status ring. The segments count, where the old grey 22 pt ring only showed a fraction.
   - **Fallback above 24 sets:** with more than 24 planned sets a 34 pt ring would give segments under about 4 pt, so the live ring switches to one **continuous arc** (lit length = done / total) and the `N/M sets` text carries the count. The finish ring follows the same rule, as one arc divided into its family-coloured runs.
   - **The finish ring lights in family colours.** Live, lit segments are white. At the finish the ring re-lights each set in its muscle family's colour, in workout order: 8 chest, 10 shoulders, 4 arms for this Push Day. The three maps beside it are its key. It is the one place a lit segment is not white, because the finish is the celebration.
3. **Set-complete stamp.** The check box stamps white with a spring and a haptic.
4. **NEW BEST mark and flash.** A burst.fill glyph and the words NEW BEST in a **flood outline**, 20 pt tall, caption 12 bold. It deliberately is **not** a white fill, because a white fill means "done". Live it sits under the Previous value on the set row. On Finish the New bests rows use the same outline-and-burst stamp at 40 pt, and Exercises rows put the burst before the best set. Later it appears in History the same way. A PR is derived at read time per RecordsMath rules: warmups excluded; assisted sets, lower is better; **ties are not bests**; a first-ever set is "First time", not a best. In the scenario, set 3 prefilled at 110 × 8 ties today's 110 × 8, so it shows no mark; the `set3Weight` = 115 Tweak shows the mark landing.
5. **This week.** A full-width row of the five family maps at 56 pt, each lit in its colour or unlit grey, with its completed non-warmup **set count** under it (Chest 0, Back 8, Shoulders 3, Arms 3, Legs 14). Under that, seven day cells: lit with minutes on trained days, dashed for today, outlined for the days ahead. A footer holds Workouts 2 · Time 1 h 43 min · Last week 4. (The tally strokes are gone; "Last week 4" already said it.)
6. **Count-up numerals.** Live volume on each set; finish tiles when the sheet appears.
7. **Ultra follows now.** The accent physically moves to whatever the thumb should do next.
8. **Honest comparison.** Last Push Day against today, as two zero-based bars and a "↑ 6%" plate.

## 8. How the brief's likes and dislikes are honoured

| Item | In Floodlight |
|---|---|
| Apple Fitness reference: big numbers with small labels, rings, clean thin HR graph | Expanded-heavy numbers with small labels; segment rings; the HR chart is 52 thin floating range bars with only 4 labels (max, min, 0:00, 52:10) and no gridlines |
| Bold, graphic, saturated, not text-heavy | Black and white type with one hot ultraviolet, vivid family maps at 56 pt in This week, and a family-coloured finish ring. Words become numbers, cells, bars and marks. |
| Start Lifting / Start Cardio: equal capsules side by side with icon discs | Kept: two equal Ultra capsules filling the row (fixes the ragged right edge), each with an ink disc and an Ultra glyph, and no arrows. Standard-width bold labels so the pair stays side by side at 430 and 402 (§4). |
| Template grid, New Template… tile, tap opens the list, Delete inside | Kept. Tiles are top-aligned and equal height: maps, name, last-done line, then 4 lines (3 names + "+ N more"). New Template… and Ask AI for Templates share the last row as dashed "empty slot" tiles, which ends the orphan half-row. Delete stays in the detail. |
| Accurate muscle maps per family | The provided maps, recoloured (§2). Used as summaries only; now the largest graphic on Home. |
| Live header: gym chip · clock with seconds (medium-large) · small ring "N/M sets" | Exactly that line. The clock is 26 pt expanded (not a hero); the ring is a 34 pt segment ring. |
| Rest bar: draining ring with hourglass, "Rest" over the time, +15s, Skip | Kept, with the next set added under the time ("Next · Set 3 · 110 lb × 8"). Skip stays the prominent fill, now Ultra. |
| Swipe to delete sets; drag to reorder exercises | Unchanged gestures |
| Finish: status ring + View in History primary + Save as Template secondary, then paired tiles in order, zones directly below the graph | Kept in that order. Tiles are Workout time \| Total volume, Active \| Total calories, Avg. \| Max heart rate. Time in zones sits inside the heart-rate panel, directly below the chart, with no tap. |
| Plain words and numbers; "Delete" | No ≈, no "estimated", no source caption ("AirPods" / "Test data" removed), "1RM" only where shown |
| Lifting \| Cardio focus switch | Not in this scenario. It would be a two-segment control in the header area when cardio exists. |
| No muscle icon per exercise row | None |
| No magnified current set; no giant elapsed hero | Rows are equal height. The draft row differs only by outlined fields and its check box. |
| No helper paragraphs or coach marks | None. No sentences are added; every new string is a label. |
| No long-press on tiles | None |
| No auto-added set rows | "Add Set" is a deliberate dashed row |
| No live map during cardio | Not applicable here |
| Tab-bar icons unchanged | Same four symbols and labels; only the bar is restyled |
| Messy points from the audit | One 20 pt left edge; top-aligned equal tiles; no orphan caption ("Machines resolve…" is removed from Home); the machine-row chevron is at the trailing edge; one accent role at a time. **Cancel stays beside minimise**, where the user knows it, now in `danger` inside the same glass group. |

## 9. AccessibilityL (described; drawn at default size)

**Home**
- The Start pair stacks through `ViewThatFits` into two full-width capsules, still equal. At the default size it stays side by side on both 430 and 402 pt phones (§4).
- The gym row moves "lb ⌃⌄" under the name.
- This week: the five family maps stay one row at 56 pt; their counts become two lines ("14" over "sets"). If the row cannot fit, it wraps to 3 + 2. The 7 day cells stay; the minutes inside them hide, and the cell shows the day letter plus lit or unlit. The three footer numbers become three rows (number leading, label trailing).
- Templates become one column. Each tile lists every exercise; nothing truncates. Template names and the last-done line wrap.
- The New Template… and Ask AI tiles stack at full width.
- The tab bar is the system's.

**Live workout**
- The header becomes two lines: the gym chip on line 1; the clock and "7/18 sets" on line 2.
- The nav bar keeps minimise + Cancel on the leading side and Finish on the trailing side; the title moves into the list as the first row if it cannot fit between them.
- The live strip becomes three rows.
- **Exercise titles wrap to two lines** (Title 3 Expanded is about 31 pt at AX1, so "Machine Shoulder Press" needs two) and **never truncate**. The chart and ellipsis buttons stay top-aligned beside the first line.
- Set rows use the existing two-line layout: marker · previous · check, then labelled Weight and Reps fields. The column header hides. The NEW BEST mark stays under the previous value and grows with caption.
- The rest bar is capped at about 22 % of the screen. Ring and time share one row, "+15s" and "Skip" share an equal-width row under it, and the "Next · …" line drops to VoiceOver only.

**Finish**
- The ring goes above the text. "Workout saved" wraps as needed (it already takes two lines at default).
- Actions stay full width.
- The scoreboard becomes one column, in the same order.
- The comparison puts each label above its bar.
- The zone legend becomes a 2-column grid.
- Exercise rows put the best set on its own line under the name.

## 10. New visible strings (for the user's approval)

**Home**
- `Thursday, Sep 24`: nav subtitle; the date format is "EEEE, MMM d"
- `This week`
- `M`, `T`, `W`, `T`, `F`, `S`, `S`: locale weekday initials
- `min`: under the day minutes, and in `1 h 43 min`
- `h`: in `1 h 43 min`
- `0 sets`, `8 sets`, `3 sets`, `14 sets` under the family maps: pattern `{n} sets` (the word "sets" already exists in the app)
- `Workouts`
- `Time`
- `Last week`
- `Sep 23`, `Sep 21`, `Sep 17`, `Sep 10`: the date a template was last done, after the History glyph on its tile
- `+ 2 more`, `+ 3 more`: pattern `+ {n} more`
- New accessibility labels (VoiceOver only):
  - "Sets this week: Chest 0, Back 8, Shoulders 3, Arms 3, Legs 14"
  - "Last done Sep 23": pattern `Last done {date}`
  - "Monday, Pull Day, 48 minutes"
  - "Tuesday, no workout"
  - "Today, Thursday"

**Live workout**
- `New best`: rendered uppercase in the NEW BEST mark
- `Next · Set 3 · 110 lb × 8`: pattern `Next · Set {n} · {weight} {unit} × {reps}`
- `Next · Incline Chest Press`: pattern `Next · {exercise}`
- `4,120 lb`: a new live figure, labelled with the **existing** strings `Total volume` and `Active calories` (their first use in the live screen)
- Previous values read `105 lb × 8`: this is the **existing** `PreviousSetValue.displayLabel` format, not a new string
- `Cancel` is the existing string, kept in place

**Finish**
- `Push Day · Iron Temple`: the template name joins the summary. The summary line becomes `5 exercises · 22 sets`.
- `New bests`
- `Last Push Day`: pattern `Last {template name}`
- `Today`
- `Sep 17`: the date of the last run
- `↑ 6%`: pattern `↑ {n}%` / `↓ {n}%`
- HR axis labels `0:00` and `52:10`: elapsed time replaces the three clock-time labels
- `best`: an existing word, now used once as a column caption
- Best sets read `110 lb × 8` (existing displayLabel order)
- New accessibility label: "Workout saved, 22 sets: 8 chest, 10 shoulders, 4 arms"

**Removed from view**
- The HR source caption ("AirPods")
- The underlined "· set up zones" / "· edit zones" link. The whole HR cell opens the zones sheet. With no max HR, its second line reads `Set up zones` instead of "Zone N". That is a **changed string**: the existing "· set up zones", recapitalised and without the dot.
- The "Machines resolve to your last-used at …" footer on Home

(Revision 1 proposed moving Cancel to a "Discard Workout…" button at the end of the list. That is withdrawn; see §13.)

## 11. Stored data

**No new stored data.** Everything drawn derives from what the app already stores (domain-data §3):

| What is drawn | Derived from |
|---|---|
| Day cells, day minutes, "Last week" | Finished workouts bucketed by start day |
| Family set counts this week | Completed non-warmup sets → `exercise.muscleGroup` → family, counted for every load type. This is **live, not snapshotted**, so a later reclassification changes past weeks. Core-only exercises map to no family. |
| Template last-done date | The newest workout with that `sourceTemplateID` |
| New best | RecordsMath at read time; never stored (D47) |
| Finish ring colours | Each completed set's exercise family, in workout order (same live mapping as above) |
| Last Push Day comparison | The previous finished workout with the same `sourceTemplateID` |
| Volume so far | Completed, weighted, non-warmup sets |
| Next-set preview | The draft rows |

The custom machine glyph is an asset, not data. A **week streak was deliberately not added**; it would be a new product decision.

## 12. Decisions this direction reopens (record before building)

- **D54 visual system:**
  - the accent changes from amber to Ultra violet;
  - radii and type change (the expanded width for numbers and titles; button labels stay standard width);
  - heart rate moves to its own pink, and destruction to its own red-orange;
  - families are recoloured (chest amber-orange, arms yellow, back deeper blue);
  - the unit-chip colours are retired;
  - D54's "never words" copy rule is superseded by the string list above.
- **D58 Ask AI placement:** Ask AI moves from a secondary button below the grid to a tile beside New Template…, still below the templates.
- The live nav bar is **not** reopened: Cancel stays beside minimise.

## 13. Review responses

Three judges reviewed revision 1. Every critical fix is applied. Where I agreed with a weakness it is fixed; where I disagree, the reason is given.

**Applied (critical)**

| Finding | What changed |
|---|---|
| Set 3 PREVIOUS showed "—" | Shows last time's value, `105 lb × 8`, like set 2. The NEW BEST mark still needs a set that **beats** 110 × 8; a tie shows nothing. I also added the unit to every Previous value: that is the existing `displayLabel` output, and Previous is an as-entered value whose unit can differ from the gym's. |
| This week: 32 pt family strip; unlit chest nearly invisible; tally strokes | Full-width row of five 56 pt maps with set counts under them; unlit body #464A52 and muscle #737983; the four tally strokes are deleted. |
| Start labels in Expanded would not fit, and ViewThatFits would stack the pair | Labels are SF Pro standard width Bold 17. The disc is 44 pt. Measured fit at 430 and 402 (§4). |
| Cancel was silently moved to an undrawn "Discard Workout…" | Cancel stays beside minimise, in `danger`, grouped in one glass capsule with the minimise button (iOS 26 groups adjacent bar items). Relocation is withdrawn. If the user ever wants it moved, it would be drawn and shown as its own choice. |
| Template date had no meaning | `clock.arrow.circlepath` glyph before the date, on its own line under the name. |
| NEW BEST plate 9.5 px, same white fill as "done", relied on the strobe | Caption 12 bold, 20 pt tall, flood **outline** with a `burst.fill` glyph. It no longer uses the white fill, so it reads without motion. Finish uses the same outline-and-burst stamp. |
| Stand/cell too close to the ground; draft border 1.78:1 | Stand #181A1E, cell #22252A; draft border flood 45 % (4.57:1 on stand). |
| Warmup outline 2.84:1; "min" 10 px | Dim at 62 % (3.65:1); "min" 11 pt. Also: the past-day letter moved from faint to dim, because faint on cell is 4.13:1. |
| Button labels in Expanded; "Workout saved" shrunk to 26 | All button labels are standard-width SF Bold 17. "Workout saved" is drawn at Title 28 and wraps to two lines (Finish grew 44 pt). |
| Exercise titles nowrap | Removed; titles wrap to two lines and never truncate (§9). |
| Chest vs danger 15.5 ΔE00 | Chest → #FFA03C: 21.6 from danger, 40.7 from pulse, 22.8 from arms. Danger is unchanged, so danger–pulse stays 22.1. |
| No ring fallback for long workouts | Continuous arc plus `N/M sets` above 24 sets (§7.2). |
| Finish rows printed "110 × 8 lb" | Now `110 lb × 8`. |
| Whole Body tile overflowed (5 × 32 + gaps) | Tile maps are 30 pt with 2 pt gaps: 158 pt in the 159 pt content box. All tiles use 30 pt, so they match. |
| Ghost tally duplicated "Last week" | Removed. |

**Weaknesses: agreed and addressed**

- *Finish ring all white; least celebratory finish.* Agreed. The ring now lights each set in its family colour (8 chest orange, 10 shoulders teal, 4 arms yellow), with the maps beside it as the key. That puts colour on the moment the user kept the big ring for, without borrowing Ultra (which would make two Ultra roles next to View in History).
- *Colour is thin.* Partly agreed. The fixes add real, data-driven colour where the user looks first: five large family maps in This week and the family-coloured finish ring. I did not add colour that means nothing. The rule stays "white = done, Ultra = now, colour = a family or heart rate".
- *Lit day cells brighter than the Start capsules under glare.* Partly agreed. Day cells are shorter (72 → 64), and the colourful family row now sits between the Start pair and the day cells, so the white cells no longer come straight after the capsules. The capsules are about 4× the area of the two lit cells and fully saturated, so they still win the first look. The cells stay white because "lit = done" is the direction's one idea.
- *New best depends on the strobe; PR looks like every done set.* Agreed; see the NEW BEST row above.

**Weaknesses: where I disagree**

- *Ultraviolet is unproven; the user once chose "one warm accent"; violet reads as generic dark-SaaS or "gamer".* I keep Ultra, and I call it the direction's main risk. The user chose a warm accent in September, before heart rate, destruction, chest and arms each had their own colour. With those four fixed, every warm accent I measured lands within 6–11 ΔE00 of one of them (coral 7.7 from danger, amber 5.6 from chest, gold 7.8 from arms, hot pink 6.6 from pulse), so the screen would carry two near-identical warm colours with different meanings. That is the confusion the audit criticised. Ultra follows the thumb (Start, then the rest ring and Skip, then the next check), and never sits on panels or decoration. That motion is what makes it this app's accent rather than a dashboard's. Directions B and C carry the warm and cool alternatives, so the user can judge this one against them side by side.
- *The Finish sheet is the current screen re-skinned.* Deliberately so for the structure: the user rejected three finish restructures and kept this receipt (taste brief §3 row 7). The engagement is in the parts it adds: the family-coloured segment ring, the New bests stamps, and the Last Push Day comparison.
- *On screens without data (Settings, Gyms, forms, scanning) it reduces to black panels.* Partly. The raised stand and cell now make those panels visible shapes instead of hairline boxes. Each screen still has exactly one Ultra action where the thumb goes ("Add Gym…", "Scan Machine", Save), and live processes such as scanning or AI generation use Ultra's "live now" treatment (the draining or sweeping ring). Counts such as machines per gym use the scoreboard numerals, and Exercises' family filters use the maps. It is still the quietest of the three directions on those screens; that is the trade-off for a calm logger.
