# Direction C: "Paper Club"

**Idea:** the app becomes your training notebook, in two finishes of one design. **Carbon
copy** is the dark finish: carbon ground, bone type. **Paper** is the light finish: warm paper,
ink type. In both, one cobalt pen marks the action. A yellow highlighter marks every new best.
Muscle maps keep the user's chosen look: a grey body with the working muscle in its family
colour.

Drafts sit in open boxes. Completing a set inks it and stamps it. Days you train are punched out
of a weekly card. The style is controlled neo-brutalism. Only pressable things get a solid
outline. Only the screen's one primary command gets a hard offset shadow. Each colour has one
meaning. The screens the user knows keep their structure (gear, title, gym, Start pair, template
grid; header line, cards, rest bar; status ring, buttons, paired tiles, graph, exercises). The
surface and the engagement layer change.

Artboards (all generated from one template per screen with two token tables, so the two
finishes cannot drift apart):

| File | Size | Interactive | Note |
|---|---|---|---|
| `canvas/project/DirC-Home-Carbon.dc.html` | 430 × 1304 | no | Carbon copy. The full scroll. The floating tab bar is **pinned at the artboard bottom** (end of scroll). In use it floats over the first viewport at y 850–912. |
| `canvas/project/DirC-Home.dc.html` | 430 × 1304 | no | Paper, the same content. |
| `canvas/project/DirC-Live-Carbon.dc.html` | 430 × 932 | **yes** | Carbon copy. The rest timer, clock and heart all tick. Set 3's check, Skip and +15s work. **The list scrolls** to the end: the rest of Push Day, Add Exercise, Add by Machine, Add Cardio, and **Discard Workout…**, which opens the existing confirmation. |
| `canvas/project/DirC-Live.dc.html` | 430 × 932 | **yes** | Paper, the same behaviour. |
| `canvas/project/DirC-Finish-Carbon.dc.html` | 430 × 2112 | no (load animations play once) | Carbon copy. The sheet at its large detent over the dimmed Workout tab, full scroll. |
| `canvas/project/DirC-Finish.dc.html` | 430 × 2112 | no | Paper. It was 2290. It is shorter because the receipt header, column heads, dotted-leader totals and torn edges are gone. |
| `canvas/project/DirC-Maps.dc.html` | 920 × 952 | no | Map-style comparison board. It shows the drawn style (grey body, vivid muscle) beside the sticker alternative (ink body, white muscle on the family colour), in both finishes. It uses the same tiles, week stickers and Muscle groups as the screens. |

**Recommendation.** If the user keeps D54's dark-only rule, ship **Carbon copy** alone. Paper is
the same system with a second token table. It can follow the system appearance, or it can stay
unbuilt.

---

## 1. Palette: tokens, meanings, measured contrast

Each colour has one meaning. Ground, sheet, text and outlines are structure, not meanings.

| Token | Carbon copy | Paper | Its one meaning / use |
|---|---|---|---|
| `ground` | `#15130F` | `#F2ECDF` | Screen background. Also the fill of open (draft) fields. |
| `sheet` | `#211E18` | `#FFFBF2` | Cards, tiles, tickets, secondary buttons |
| `text` | `#EDE6D6` bone | `#16140F` ink | Type. Completed ("inked") sets, punched days, and pressable outlines. |
| `text2` | `#B5AE9F` | `#575046` | Secondary text, labels, units; the outlines of missed days and future sets |
| `rule` | bone 16 % | ink 22 % | Hairline edges of **information** (cards, tickets, week card, dividers). It never marks a pressable thing. |
| `dash` | bone 42 % | ink 45 % | The dashed edge of an **open draft field** (a prefilled value not yet logged) |
| `accent` (cobalt) | `#2743F2` fill | `#2743F2` | **The action / the live thing / the selection**: primary fills (Start pair, View in History, Add Exercise, Skip) |
| `accentText` | `#4C8DFF` | `#2743F2` | The same meaning as text, rings and marks: the next set's marker and check, today on the punch card, the selected tab, the draining rest ring (`#4C8DFF` on the slab in both finishes) |
| `onAccent` | `#FFFFFF` | `#FFFFFF` | Labels on cobalt |
| `shadow` | `#756D60` graphite | `#16140F` ink | The hard offset under the one primary command |
| `hl` highlighter | `#FFE14A` | `#FFE14A` | **A new best**: the "New best" sticker and the swipe behind best values. Never decoration. Its text is always ink `#16140F`. |
| `heart` | `#FF453A` | `#E0261E` | **Heart rate**: heart glyphs and filled zone-meter steps. Never used for destruction. |
| `wu` | `#948C7E` | `#6E665A` | The completed warm-up marker "W" (warm-ups don't count) |
| `slab` | `#000000` + bone 24 % edge | `#16140F` | The two live instruments: the rest bar and the heart-rate plate |
| zone ramp (on the slab) | Warm-up `#6F6A62` · Z1 `#9A4E58` · Z2 `#CC3C3C` · Z3 `#F4502C` · Z4 `#FF8A4F` · Z5 `#FFC4A6` | same | Heart-rate intensity. One warm family. **Salience rises with intensity**: each step up is lighter and, up to Z3, more saturated, so the hottest zone is the brightest mark on the dark plate. Adjacent steps are 12.8–23.3 ΔE00 apart. |
| destructive | trash glyph in a solid `text` disc + a **double rule** + an explicit verb | same | Red means heart. Destruction is carried by a mark nothing else uses (the double rule), the glyph, the verb and the existing confirmation. System dialogs keep their own red button: that is system chrome and is not restyled. |

**Why cobalt:** amber and forest/lime are excluded. Tomato collides with heart red. Violet
collides with the arms family (fixed below). Cobalt keeps one cold hue for "act here", which
leaves the warm hues to families, heart rate and the highlighter.

**Measured WCAG 2.x contrast** (relative-luminance formula; translucent tokens composited over
their real background). Text needs 4.5:1. Outlines, glyphs and graph marks need 3:1.

| Foreground / background | Carbon copy | Paper | Where |
|---|---|---|---|
| text / ground | 14.92 | 15.63 | titles, text on the ground |
| text / sheet | 13.37 | 17.82 | card text, set values |
| **draft value (text, bold) / open field** | **14.92** | **15.63** | the prefilled next-set numbers (was pencil 4.81) |
| text / glass (tab bar, toolbar) | 12.72 | 17.20 | tab labels, Finish, Done |
| text2 / ground | 8.41 | 6.75 | subtitle, captions |
| text2 / sheet | 7.53 | 7.70 | card captions, PREVIOUS, units |
| accentText / sheet | 5.19 | 6.41 | next-set numeral, "T" for today |
| accentText / glass | 4.94 | 6.19 | selected tab label |
| onAccent / cobalt | 6.62 | 6.62 | Start capsules, View in History, Add Exercise, Skip |
| ink / highlighter | 14.13 | 14.13 | "New best", highlighted best values |
| slab text / slab | 16.89 | 17.82 | rest time, plate title, zone legend |
| slab text2 / slab | 9.52 | 9.51 | "Rest", "Next · …", chart labels |
| accentText ring / slab | 6.56 | 5.75 | draining rest ring (non-text) |
| +15s outline / slab | 5.98 | 7.31 | non-text |
| heart / sheet | 4.88 | 4.55 | heart glyphs (non-text) |
| label / wu marker | 5.58 | 5.48 | "W" |
| pressable outline / ground | 14.92 | 15.63 | the 2 pt outline that means "you can press this" |
| primary offset / ground | **3.63** (graphite) | 15.63 | the hard shadow; visible in Carbon copy (was `#000` on `#15130F`, 1.1) |
| draft-field dashes / field | 3.55 | 2.89 | decorative. The fill change and the missing check carry "not logged" too. |
| zones / slab (WU, Z1…Z5) | 3.91 · 3.60 · 4.28 · 6.03 · 9.00 · 13.70 | 3.43 · 3.16 · 3.75 · 5.28 · 7.89 · 12.01 | graph bars and swatches (non-text) |
| system red / system sheet | 4.60 | 3.29 | the dialog's "Discard Workout" (system chrome, 20 pt) |

Every text pair passes 4.5:1. No grey caption falls below 6.7:1.

## 2. Muscle-family colours and maps

**Drawn style (all screens): grey body, vivid muscle.** The provided two-layer maps are tinted
with CSS masks: the body is warm grey and the working muscle is its family colour. They sit on
a tile washed with that family colour (16 % in Paper, 22 % in Carbon copy), the rule the shipped
tiles use. This is the look the user locked ("Let's stick with codex's"). It appears on the
template bands, the week card and Finish "Muscle groups". There are **no maps on exercise rows**.

| Family | Hex | Relative luminance | Change |
|---|---|---|---|
| Back | `#0FA0BD` teal | 0.29 (darkest) | moved from sky blue so it stays clear of cobalt |
| Chest | `#FF6AA8` pink | 0.34 | slightly deeper, to open a lightness step from arms |
| **Arms** | **`#C49BFF` lavender** | 0.42 | **was `#7F5BFF`** (12.1 ΔE00 from cobalt) |
| Shoulders | `#FFA83F` tangerine | 0.50 | moved from turquoise (teal now belongs to back) |
| Legs | `#9BE05C` green | 0.61 (lightest) | same hue, lighter |

- Arms is now **32.7 ΔE00 from cobalt** and 21.6 from the Carbon copy accent `#4C8DFF`. Back is
  34.1 and 20.9. The closest family pair (chest–arms) is 22.8.
- Luminance steps of ≥ 0.05 keep families apart in greyscale. The map's shape always names the
  family, so colour is never the only cue.
- Body grey: Paper `#7D766B`, 3.67–4.06:1 against the washed tiles; muscles are 28.1–37.2 ΔE00
  from it. Carbon copy `#7C7569`, 2.12–2.64:1 against the tiles (the shipped dark tiles are
  about 2:1); muscles are 28.4+ ΔE00 from it.
- An unlit family (not trained this week) is a dashed outline with a faint body and no muscle.

**Alternative (comparison board only):** the "sticker". It has an ink body and a white muscle on
a full family-colour block. The ink body on the family colour measures back 5.94 · chest 6.90 ·
arms 8.31 · shoulders 9.57 · legs 11.58, and the white muscle on ink measures 17.82. It is bolder
but inverts the user's chosen look, so it is not used on the screens. `DirC-Maps.dc.html` shows
both side by side.

## 3. Type (native face → web stand-in in the mock)

Three families (the fourth, SF Mono, is gone with the receipt).

| Role | iOS native (Dynamic Type style) | Mock stand-in | Used for |
|---|---|---|---|
| Large Title | **New York Black** 34/41 (`.largeTitle`, `design: .serif`, `.black`) | Source Serif 4, 900 | "Workout" |
| Display | New York Black 30/34 (`.title`, serif) | Source Serif 4, 900 | "Workout saved" |
| Section / card title | New York Heavy 20–22 (`.title2`/`.title3`, serif, `.heavy`) | Source Serif 4, 800 | "Templates", "This week", exercise names, template names (21), "New bests" |
| Inline nav title | New York Heavy 18 (`.headline`, serif) | Source Serif 4, 800 | "Push Day", "Nice work" |
| Headline / Body | SF Pro Text Semibold–Bold 17 | -apple-system | buttons, gym name |
| Subheadline | SF Pro 15 | -apple-system | summary lines, row names |
| Footnote / Caption / Caption 2 | SF Pro 13 / 12 / 11 | -apple-system | captions, column heads (11, +6 % tracking), the "New best" sticker (11) |
| Numbers | **SF Pro Expanded Heavy** (`.fontWidth(.expanded)`, `.heavy`, `.monospacedDigit()`) at Title 2–Title 1 | Archivo wdth 105–115, 700–900 | clock, stats, rest time, set markers, best sets, zone times |

Serif is for names, Expanded is for numbers, and SF Pro is for everything else. Light weights
are never used. Every style scales with Dynamic Type.

**Native cost of the serif titles:** the inline titles are ordinary `Text` with
`.font(.headline.weight(.heavy)).fontDesign(.serif)` in a `.principal` toolbar item. The large
title needs `UINavigationBarAppearance.largeTitleTextAttributes` with a New York descriptor
(`UIFontDescriptor.withDesign(.serif)`) scaled by `UIFontMetrics(forTextStyle: .largeTitle)`.
That is one appearance setup at launch.

## 4. Radii, spacing, elevation

- **Side margins: 20 pt on every screen.** One left edge.
- **Spacing:** 4 · 8 · 12 · 16 · 20 · 24 · 32. Related blocks sit 14–18 apart. A section header
  sits 12–14 above its content. Sections sit 30 apart. Rows are 48 (set rows) or at least 44
  (everything tappable).
- **Radii:** buttons and chips are capsules; cards and tiles 18; tickets 16; fields and pills
  10–12; stickers 6–8; sheet 36; tab bar 31.
- **Elevation says what you can do.** Each level has one look, so hierarchy reads before touch:

| Level | Look | Examples |
|---|---|---|
| 0 ground | flat | the screen |
| 1 **information** | `sheet` + 1.5 pt `rule` hairline, no shadow | week card, live ticket, exercise cards, tiles on Finish, Last time, Exercises list |
| 2 **pressable** | `text` outline (bone / ink), 2 pt on buttons and tiles, 1.5 pt on rows, chips and icon discs; no shadow; the fill darkens while pressed | gym picker, template tiles, machine row, Save as Template, Add by Machine, Add Cardio |
| 3 **primary** | cobalt fill + 2.5 pt outline + a **4 × 4 pt hard offset** (`shadow`); sinks into it while pressed | only the screen state's one primary: the Start pair (Home), Add Exercise (Live list end), View in History (Finish) |
| make one / not yet | 2 pt **dashed** outline, flat | New Template…, Ask AI for Templates (equal peers, both flat), Add Set, today's punch |
| destructive | 2 pt outline + a 1.5 pt inner rule 2.5 pt inside it (a **double rule**) + trash in a solid disc | Discard Workout…, the swipe-delete tile |
| instrument | `slab` | rest bar, heart-rate plate |
| glass | system Liquid Glass | the tab bar **and every toolbar item** (gear, minimise, Finish, Done) |

- **Dark pressable treatment (Carbon copy):** a bone 2 pt outline marks every pressable thing
  (14.92:1 against the ground). The primary's offset is graphite `#756D60` (3.63:1 against
  `#15130F`), so the offset stays visible. A pure `#000` offset (1.1:1) would vanish.
- **Liquid Glass:** toolbar items **accept** the system glass. They are drawn that way: a
  translucent sheet, blur and a hairline, with no custom outline or shadow. No
  `.sharedBackgroundVisibility(.hidden)` is needed. Finish is a plain trailing `ToolbarItem`
  (not `.confirmationAction`), so it stays neutral glass rather than taking the cobalt tint.
- **Native build:** three `ButtonStyle`s (`PressableStyle`, `PrimaryStyle` with
  `.shadow(color: look.shadow, radius: 0, x: 4, y: 4)` and a 4 pt offset while `isPressed`,
  `DestructiveStyle` with two `strokeBorder`s) and one `CardBackground` modifier. Both finishes
  use the same styles with different `Look` tokens.
- **System controls:** Menus, pickers, alerts and confirmation dialogs stay system chrome. Forms
  use `.scrollContentBackground(.hidden)` over `ground`, with `.listRowBackground(sheet)`. The Live
  artboards draw the discard dialog as the system draws it.

## 5. Iconography

- The shipped app uses SF Symbols; the mock draws matching 24-unit stroke SVGs. Glyphs are
  monochrome at semibold weight. The only coloured glyph is the heart.
- **Tab bar: the same four symbols and labels.** Workout `figure.strengthtraining.traditional`,
  History `clock.arrow.circlepath`, Gyms `building.2`, Exercises `list.bullet.rectangle`.
  Only the glass tint and the cobalt selection change.
- **An icon used as a button sits in an outlined disc** (the user's "icon disc" pattern): Start
  capsules, View in History, Add Exercise, Add by Machine, Add Cardio, the gym picker, previous
  performance (chart), ⋯, New Template…, Ask AI. Outside a cobalt capsule, only the Discard disc is
  solid (filled with `text`).
- One symbol keeps one meaning:
  - `clock.arrow.circlepath` means history (tab, "last done" on tiles, View in History).
  - A weight-stack glyph means a machine (it replaces the settings-like `gearshape.2`).
    Dumbbell and cable glyphs mark free-weight equipment rows.
  - `flame` means calories; `heart` means heart rate; `trash` means destroy.
- **Custom marks:** the rubber-stamp status ring (the only rotated object besides the small
  sticker); the "New best" sticker; set markers that differ by fill and shape rather than hue
  (warm-up is a `wu` disc with "W"; done is a solid `text` disc; the next set is a cobalt ring;
  future sets are thin `text2` rings; failure is an octagon with "F"; drop is a downward tag with
  "D". Failure and drop are not drawn in this scenario).

## 6. Motion

Every animation answers an action or a live state. Each has a still alternative under Reduce
Motion.

| # | Trigger | Motion | Reduce Motion |
|---|---|---|---|
| 1 | Touch-down on the primary | Sinks 4 pt into its hard shadow; springs back on release (0.09 s). Other pressables darken their fill. | The same end state, instant |
| 2 | Tap a set's check (demonstrated on set 3) | Ink stamp: the disc drops in from 1.7× at −16° to 1× (0.38 s); a ring ripples out (0.55 s); the open draft boxes dissolve and the values stand inked (0.45 s); the existing medium haptic fires | Instant; haptic kept |
| 3 | A completed set is a new best | The "New best" sticker lands under PREVIOUS (1.5× → 1×, 0.36 s) with a light haptic | Sticker appears |
| 4 | Rest starts | The rest slab rises 28 pt and fades in (0.3 s) | Appears in place |
| 5 | Rest running | Ring drains continuously; the time ticks each second | Ring steps once per second |
| 6 | +15s | Ring refills to the new fraction (0.3 s) | Jumps |
| 7 | Skip / rest ends | The slab drops away; success haptic at expiry (existing) | Disappears |
| 8 | Set count or volume changes | "7/18 → 8/18" and "4,120 → 5,000" bump (1.25×, 0.35 s); the header ring advances (0.5 s) | Numbers swap, ring jumps |
| 9 | Live heart rate | The heart beats **at the live bpm** (0.47 s at 128). Stale: it stops and greys out. | Static heart |
| 10 | Start Lifting / Start Cardio | Sinks (1); the heavy start haptic (existing) | as 1 |
| 11 | Returning to Workout after finishing today | Today's punch stamps in (0.4 s) | Appears punched |
| 12 | Finish sheet appears | The status ring draws around (0.7 s), the stamp thunks down (1.45× → 1×), the check pops (0.32 s); success haptic | Final stamp |
| 13 | Finish sheet appears | The highlighter swipes left to right across each new-best value (0.4 s, staggered), then the muscle-group tiles land (0.32 s, 0.1 s stagger) | Static |
| 14 | Finish sheet appears | The heart-rate graph is revealed left to right like a pen trace (1 s) | Shown complete |
| 15 | Finish tiles (native only) | Numbers count up once (`.contentTransition(.numericText())`, 0.6 s) | Final values |
| 16 | Discard Workout… | The system confirmation dialog rises (system motion) | System behaviour |

The artboards honour `prefers-reduced-motion` by disabling every keyframe and transition.

## 7. Signature engagement devices

1. **Open box → ink.** A prefilled value sits in an open box (ground fill, dashed edge) in full
   ink bold, so the number you load the machine with is the highest-contrast number on the row
   (14.92 / 15.63:1). Completing the set dissolves the box and stamps the check. The next set is
   the only cobalt thing in the card. The row is not magnified.
2. **New best = yellow.** One term, "New best", and one colour, the highlighter. The rule is
   derived and never stored: warm-ups are excluded, assisted is lower-is-better, ties are not
   bests, and the first time is "First time" (a white sticker), not a new best.
   - Live: a small "New best" sticker under PREVIOUS on the set that earned it.
   - Finish: "New bests" cards with the value swiped in highlighter, and the same highlight on
     those rows in Exercises.
   - Set 3 in the interactive board **ties** set 2 (110 × 8), so by the rule it gets no sticker.
     The demo shows that.
3. **Punch-card week.** Seven punches: trained days are solid with a check, today is a dashed
   cobalt ring, and future days are dotted. Below them are workouts, time, and the week's
   families as lit or unlit map stickers. Chest is still unlit on Thursday, which frames
   today's Push Day without coaching. **No streak** (withdrawn; see Review responses).
4. **Family bands on template tiles.** Each tile's band shows one washed segment per family with
   its map. Leg Day is one green band, and Whole Body has five segments. Tiles are told apart by
   their family mix at a glance. Templates that share families (for example AI-generated days)
   still need their names; the bands do not claim to fix that.
5. **One press, one shadow.** Only the primary command casts a hard shadow and sinks into it. The
   eye finds the one thing to do.
6. **Ink instruments.** The rest bar and the heart-rate plate are the two slabs, the darkest
   objects in Paper and bordered black in Carbon copy. They read in two seconds under gym light.
7. **Honest heart-rate graph.** Thin range bars, one per minute, each split where it crosses
   a zone boundary (55/65/75/85/95 % of 185). The Zone 4 minutes show as the brightest tips
   exactly where they happened, and the chart agrees with the zone table below it.

**The bold element in each screen:**
- **Home:** the cobalt Start pair, the only shadow on the screen.
- **Live, resting:** the rest slab at the thumb, with Skip its one filled command. Outside rest,
  the cobalt next-set check leads.
- **Finish:** the stamped "Workout saved" at top-leading. View in History is the one filled,
  shadowed command.

## 8. How each like and dislike in the brief is honoured

| Brief item | How |
|---|---|
| Real pictures, side-by-side | Both finishes drawn for all three screens; interactive Live in both; a map-style board |
| Dark only (D54, 09-10) | Carbon copy is drawn and recommended as the one to ship |
| Apple Fitness reference | Big numbers and small labels; thin floating range bars with 4 labels (158, 82, 0:00, 52:10), no gridlines; zones directly below |
| Bold, graphic, saturated, not text-heavy | Colour carries families, heart and new bests; tile text cut to 2 names + "+N more"; the receipt's extra words are gone |
| Big pill buttons with an icon disc; equal Start pair | Two equal cobalt capsules with discs, side by side (stacked only at AX sizes). Add Exercise uses the same pill. |
| Template grid, New Template… tile, Delete inside the template | 2-column grid, equal rows, top-aligned. New Template… and Ask AI are equal dashed peers. No long-press. |
| Accurate family maps, grey body with vivid muscle | Exactly that, on tiles, the week card and Finish. None on exercise rows. |
| Live header: gym chip · clock with seconds · small ring N/M | One line: chip, 28 pt clock "18:42", 28 pt ring "7/18 sets" |
| Rest bar: draining ring + hourglass, "Rest" over time, +15s, Skip | All kept on the slab, plus "Next · Set 3 · 110 × 8" (truncates with an ellipsis) |
| Swipe to delete sets; drag to reorder | Unchanged gestures. The delete tile uses the destructive double rule + trash. |
| Finish: status ring, View in History primary, Save as Template secondary, tiles in order | Kept in that order. The ring is a rubber stamp. Tiles are paired: time\|volume, active\|total cal, avg\|max HR. |
| Zones directly below the graph, no tap | Inside the same plate, right under the bars |
| Plain words and numbers | Plain numbers. The HR source caption is off-screen (VoiceOver keeps it). "1RM" stays plain. |
| Dislike: messy, mostly text | Outlines only where you can press; one shadow per screen; two rotated marks in the whole app; three type families |
| Dislike: magnified current set, giant clock | The current set keeps its size (cobalt ring only); the clock is 28 pt |
| Dislike: helper paragraphs, coach marks, auto-added rows, live map | None |
| Keep tab icons | Same four symbols and labels |
| Audit: red "Cancel" beside minimise | Removed from the toolbar. "Discard Workout…" sits at the end of the list with the destructive treatment and the existing confirmation. |
| Audit: finish redundancy | Avg HR appears once. Total volume appears in its tile and once more as today's bar in Last time (the comparison needs it); the receipt total is gone. |

## 9. AccessibilityL

**Workout (Home)**
- The subtitle wraps to two lines. The gym tag moves its "lb" tag and chevron under the name.
- The Start pair stacks into two full-width equal capsules (`ViewThatFits`). Discs scale with
  `@ScaledMetric` (46 → ~60).
- Week card: the seven punches keep one row (they scale to 44 max). "2 workouts" and
  "1 h 43 min" share a line, and the family stickers wrap to their own line.
- Templates become **one column**. Bands grow to 96 so the maps grow. Names wrap.
- New Template… and Ask AI become equal full-width tiles (disc left, label right).

**Live**
- The workout name leaves the toolbar and becomes the first line of content.
- The header becomes two lines: clock and ring on line 1, the gym chip on line 2.
- The live ticket stacks into three rows (value left, label right).
- Each set becomes a two-line block: marker · PREVIOUS · check, then the WEIGHT and REPS
  fields with inline labels. Column headers hide. The "New best" sticker stays under PREVIOUS.
- The rest bar becomes two rows: ring, "Rest", time and "Next …" (wrapping, no truncation) on
  top; +15s and Skip full-width and equal below. The list's bottom inset grows by the bar's
  height.
- Add by Machine and Add Cardio stack; Discard Workout… keeps its own full-width row.

**Finish**
- The stamp stays 100 pt, and the headline block moves under it.
- Each ticket keeps its pair but stacks its halves, with a horizontal rule.
- New-best values drop under the exercise name.
- The "Last time" bars go full width with labels above.
- Muscle-group tiles become one column (tile left, name and working sets right).
- The zone legend becomes one column; the graph keeps its 4 labels.
- In Exercises, each best set drops to its own line under the name.

## 10. NEW visible strings (for the user's approval)

**Workout (Home)**
1. `Thursday, September 24`: the date subtitle (format: weekday, month day)
2. `This week`
3. `workouts` / `workout` under the count
4. `1 h 43 min` (format `{h} h {m} min`) with the label `time`
5. `+2 more`, `+3 more`, `+4 more` (format `+{n} more`)
6. `Yesterday`, `3 days ago`, `7 days ago`, `14 days ago` (format `{n} days ago`; `Today`)
7. Weekday initials `M T W T F S S` (system `veryShortWeekdaySymbols`)

**Live workout**

8. `Next · Set 3 · 110 × 8` (format `Next · Set {n} · {w} × {r}`) and
   `Next · Incline Chest Press` (format `Next · {exercise}`)
9. `New best` (sticker) and `First time` (the white sticker for a first-ever set; not drawn)
10. `Discard Workout…`: the end-of-list button (the dialog's existing "Discard Workout" plus an
    ellipsis, because it opens a confirmation)
11. Reused on this screen: `Total volume` and `Active calories` (existing Finish labels). Units
    `bpm`, `cal` and `lb` are lowercase everywhere.

**Finish**

12. `Push Day`: the workout's title, shown as the eyebrow above `Workout saved`
13. `New bests`
14. `Last time`
15. `Total volume · Push Day` (format `Total volume · {template}`), `Sep 17`, `Today`
16. `+6%` (format `+{n}%` / `−{n}%`)
17. `Muscle groups`; the family names `Chest`, `Shoulders`, `Arms` (today they exist only as
    VoiceOver labels); `7 working sets` (format `{n} working sets`; warm-ups excluded, so
    7 + 8 + 5 = 20 of the 22 sets)
18. Row caption `Chest Press 2 · 4 sets` (format `{equipment} · {n} sets`), recombined from
    today's `{equipment}` line and `{n} sets · best …` caption
19. Chart labels `158`, `82`, `0:00`, `52:10` (numbers only)

**Removed or changed from view (also for approval):**
- the "Machines resolve to your last-used at …" footer;
- the HR source caption ("AirPods") on the live bar (kept in VoiceOver);
- the "{n} BPM AVG" chart caption;
- **"Cancel" in the live toolbar** (discarding moves to "Discard Workout…" at the list end);
- the PREVIOUS column drops the unit when it matches the row's unit ("105 × 8") and shows it
  when the units differ.
- Withdrawn since the first draft: `6 weeks in a row`, `PR`, the receipt header
  `Iron Temple · Sep 24, 2026`, the column heads `Exercise` / `Best set`, the `Sets` and
  receipt `Total volume` rows, and the live label `Volume`.

**Kept verbatim:** "Workout", "Start Lifting", "Start Cardio", "Templates", "New Template…",
"Ask AI for Templates", "Finish", "SET", "PREVIOUS", "WEIGHT", "REPS", "Add Set",
"Add Exercise", "Add by Machine", "Add Cardio", "Cancel this workout?", "Discard Workout",
"Keep Logging", "Rest", "+15s", "Skip", "Zone 2", "Nice work", "Workout saved", "Done",
"View in History", "Save as Template", "Workout time", "Total volume", "Active calories",
"Total calories", "Avg. heart rate", "Max heart rate", "Heart rate", "Time in zones",
"Warm-up", "Zone 1–4", "Exercises". All accessibility identifiers stay.

## 11. New stored data

**None.** Everything is derived from existing records:
- **Week punches, workouts, time:** finished workouts bucketed by `startedAt`.
- **"N days ago":** `sourceTemplateID` usage.
- **Families this week and working sets per family:** the live `muscleGroup`, warm-ups
  excluded. This carries the known D23 caveat (not snapshotted), which the user must accept.
- **Last time:** the previous finished workout with the same `sourceTemplateID`.
- **New best, "First time" and ties:** `RecordsMath` at read time, never stored.
- **Next-set preview:** the draft rows.
- **Heart-rate bar splits:** the stored samples against the existing zone thresholds.

Celebrations play when the finish sheet appears, which happens once, so no "already
celebrated" flag is needed.

**Decisions this direction reopens explicitly:**
- D54: amber → cobalt; the copy freeze, for the strings above. Dark only is **kept** if the
  user ships Carbon copy alone. Paper is an optional light appearance.
- The destructive colour: the double rule + trash + verb rather than red, because red means
  heart. System dialogs keep system red.
- The live toolbar loses "Cancel"; discarding moves to the end of the list.

## 12. Carbon copy (the dark finish, drawn)

The same notebook in carbon paper. It is drawn in all three `*-Carbon` artboards.

- **Surfaces:** ground `#15130F`, sheets `#211E18`, text bone `#EDE6D6`, secondary `#B5AE9F`.
- **Pressable:** bone 2 pt outline. **Primary:** cobalt fill, bone 2.5 pt outline, graphite
  `#756D60` 4 pt offset (3.63:1 against the ground). Pressed, it sinks into the offset. The
  icon disc on cobalt is bone with an ink glyph.
- **Information:** sheet with a bone 16 % hairline.
- **Completed ("inked") marks:** bone discs with ink checks; the warm-up disc `#948C7E`.
- **Cobalt as text or rings:** `#4C8DFF` (5.19:1 on the sheet), which stays 21.6 ΔE00 from arms.
- **Instruments:** pure `#000` slabs with a bone 24 % edge; the zone ramp was designed on dark
  and is shared.
- **Maps:** body `#7C7569`, muscles in family colour, tiles washed 22 %.
- **Unchanged:** highlighter, family hues, heart hue family (`#FF453A`, the system dark red, at
  4.88:1), the stamp, all layouts and motion.

The finish decision is a token swap. Every artboard pair is generated from one template.

## Review responses

Three judges reviewed the first draft. Every critical fix is applied. Where I disagree, or
agree only in part, the reason is below.

- **Light paper reverses the recorded dark-only choice.** Agreed. Carbon copy is now drawn for
  every screen and recommended as the one to ship. Paper remains as a light appearance.
- **Inverted maps.** Agreed. The screens now use the grey body with the vivid muscle. The
  sticker survives only on the comparison board, for the user to reject or pick.
- **Neo-brutalist ornament everywhere.** Partly agreed. Removed: the streak stamp, the rotated
  "+6%" stamp, the rotated muscle stickers, the torn receipt edges, dotted leaders, dashed
  perforations, the skewed highlighter and SF Mono. Outlines on information are demoted to
  hairlines, and shadows are limited to one primary per screen. **Kept:** the 2 pt outline on
  pressable things, the one hard shadow, dashed "make one" tiles, the stamped finish ring and
  the small "New best" sticker (the app's only two rotated marks). Without these the direction
  loses its identity and becomes a copy of A or B.
- **Serif titles and a cold cobalt accent, far from Apple Fitness and the warm accent the user
  picked.** Disagreed, with the trade-off stated. Serif is limited to names (screens, sections,
  exercises, templates); numbers use SF Expanded, which carries the Fitness feel. A warm accent
  would collide with the tangerine shoulders, the heart ramp and the yellow highlighter. Each of
  those warm colours has one meaning here. A and B already cover the dark, Fitness-adjacent
  space. C exists to give the user a clearly different option to judge from pictures.
- **Receipt words, streak, PR vs New bests, Volume vs Total volume, 7 + 8 + 5 vs 22.** Agreed
  and fixed (see §10).
- **Pencil draft values at 4.81:1.** Agreed. Draft values are ink bold (14.92 / 15.63:1). The
  "not logged" signal is now the open box, not grey text.
- **Destructive Cancel beside minimise, plain ink.** Agreed. It is removed from the toolbar.
  "Discard Workout…" sits at the list end with the double rule and a solid trash disc, and it
  opens the existing dialog.
- **Arms 12.1 ΔE00 from cobalt.** Agreed. Arms is `#C49BFF` (32.7).
- **Hard `#000` shadows vanish in dark mode.** Agreed. The dark offset is graphite (3.63:1), and
  a bone outline marks pressability.
- **Glass toolbar feasibility.** Agreed. Toolbar items now take the system glass and are drawn
  that way.
- **Ask AI outranks New Template….** Agreed. Both are dashed, flat and equal.
- **HR bars coloured by bucket mean; inverted salience.** Agreed. The bars are split at the zone
  boundaries, and the ramp now rises in lightness toward Zone 5.
- **Rest bar "Next" overflow.** Agreed. It truncates with an ellipsis (`lineLimit(1)`) and wraps
  only at accessibility sizes.
- **"Family flags fix identical AI days" is false.** Agreed. The claim is withdrawn (§7.4).
- **Native cost of paper-styled Forms, Pickers, Menus and alerts.** Partly agreed. They are not
  restyled. Menus, pickers, alerts and dialogs stay system chrome. Forms only hide their
  background and take `sheet` rows. In Carbon copy the system dark chrome already matches. The
  real remaining cost is the second (Paper) token table and its QA, which is optional.
- **Two brutalist themes to build and QA.** Partly agreed. It is one set of styles with two
  token tables. The artboards are generated that way to show it. If the user wants the smallest
  build, ship Carbon copy only.
