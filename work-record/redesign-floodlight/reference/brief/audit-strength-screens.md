# Visual audit: current strength-side screens

Repo `/Users/ericlee06/orca/projects/Health App`, branch `ericlee4992/redesign-visual-proposal`, HEAD `a0364f2`
(2026-09-24). This is a fact-gathering pass only. No repo files were edited and nothing was built or run.
Every capture below was opened and looked at as an image. Source was read to confirm stale captures
and to find states that have no capture.

Coordinates are in **points**. Captures are @3x at 402 pt wide (1206 px, 920 px displayed) or 430 pt
wide (1290 px). Hex values come from the asset catalog, and I sampled some directly from the PNGs.

---

## 0. Capture freshness: which image stands for which screen

| Screen | Capture(s) used (newest first) | Capture date | UI source last changed | Stale? |
|---|---|---|---|---|
| Start, empty (no templates) | `ai-gym/screenshots/followup/followup-start-default.png`, `…-axl.png`; `cardio/screenshots/compact-start-outdoor/start-iphone15promax.png` | Sep 22 / Sep 19 | `StartWorkoutView.swift` Sep 22 (9f733a2) | Current |
| Start with templates | `ai-gym/screenshots/followup/ai-immediate-template-1-default.png`, `…-1-axl.png` | Sep 22 | Sep 22 | Current |
| Start with a live workout (Resume capsule) | `ui-redesign/screenshots/10/04-start-live-axl.png` (AXL only) | Sep 11 | Resume capsule code unchanged since ticket 10/11 | Layout still valid. The gym card has lost its "Home / no location" line for gyms without a city (see §2.2). No default-size capture exists |
| Template detail | `ai-gym/screenshots/ai-template-detail-default.png` (Sep 20); `ui-redesign/screenshots/15/04-template-detail-fixture.png` + `-axl.png` (Sep 13) | Sep 20 / Sep 13 | Sep 20 (added "Created for another gym", "No matching machine") | Current |
| Template editor | `ai-gym/screenshots/ai-template-editor-default.png`, `…-axl.png`, `ai-template-default-rest-*.png` | Sep 20 | — | Current |
| Active lifting workout | `cardio/screenshots/regression/redesign-02-active-workout.png`, `…-axl.png`, `…-axl-2.png`, `…-axl-3.png` | Sep 18 | `ActiveWorkoutView`/`ExerciseEntryCard` Sep 20 (planned-cardio rows only) | Current for lifting |
| Active workout with cardio running (Lifting segment) | `cardio/screenshots/final/cardio-built-lifting-banner-default.png`, `…-axl.png` | Sep 18 | — | Current |
| Bar mode (PER SIDE, "= 135 lb") | `ui-redesign/screenshots/codex/codex-02-bar-mode.png` | Sep 10 | Header, muscle icon and "0 min" layout changed later | **Stale chrome**. Only the bar row and PER SIDE caption still match the source |
| Heart-rate zone chip | `ui-redesign/screenshots/claude/redesign-02-heart-rate-zone.png` | Sep 10 | `HeartRateBar.swift` has the same chip | Stale chrome. The chip itself is still accurate |
| Finish summary | `ui-redesign/screenshots/17/selected/redesign-03-finish-summary*.png` (default, scroll-1, axl, axl-scroll-1/2) | Sep 17 | `WorkoutFinishedSheet` Sep 18 (cardio section only) | Current |
| History list | `ui-redesign/screenshots/11/05-history.png`, `05-history-axl.png`; empty `09/08-empty-history.png` | Sep 11 | HistoryView Sep 18 (delete-dialog copy only) | Current |
| Calendar | `ui-redesign/screenshots/11/05-calendar.png` | Sep 11 | Sep 11 | Current |
| Workout detail | `history-templates-and-zones/screenshots/14-05-detail-heart-rate*.png`, `history-13-*.png` (Sep 12); mixed `cardio/screenshots/final/cardio-built-mixed-history.png` (Sep 18), `units-and-indoor/cardio-built-mixed-history.png` (Sep 20) | Sep 12–20 | Sep 18 | Current |
| Exercise progress chart | `ui-redesign/screenshots/11/05-chart.png` | Sep 11 | Sep 11 | Current |
| Gyms list / empty | `ui-redesign/screenshots/11/06-gyms.png`; `09/08-empty-gyms.png` | Sep 11 | GymsView Sep 22 (AI and scan sheets only) | Current |
| Gym detail | `ui-redesign/screenshots/11/06-gym-detail.png`; `07/06-gym-detail-axl.png`; `09/07-delete-machine-confirmation.png` | Sep 11 | Detail layout unchanged | Current |
| Machine editor / scan / AI proposal | `ai-gym/screenshots/followup/followup-machine-editor-default.png`, `followup-capture-default.png`, `followup-proposal-default.png` | Sep 22 | Sep 22 | Current |
| Exercises | `ui-redesign/screenshots/11/07-exercises.png`, `07-exercises-axl.png` | Sep 11 | Sep 11 | Current |
| Settings | `cardio/screenshots/units-and-indoor/unit-settings-us-default.png`, `…-us-axl.png`; `ai-gym/screenshots/ai-key-settings-overview-default.png` | Sep 20 | Sep 19 | Current |

**No capture exists** for these screens. They were audited from source only: Exercise picker (Add Exercise), Add by
Machine, Equipment picker (MachinePickerSheet), Bar picker, Rest-durations sheet, Max-heart-rate sheet,
Previous-performance sheet, Edit Logged Set, New Exercise, Presets, Load Type, Gym editor, Deleted machines,
"workout already in progress" dialog, template drift dialog, cancel-workout dialog, and rest-timer AXL at default size.

---

## 1. Global design-system facts that a redesign replaces

- **Dark only.** The window forces `.preferredColorScheme(.dark)` (`WorkoutTrackerApp.swift:85`) and D54 set dark-only.
  The only accent is amber `#FFB45E` (`AccentColor`), with ink text `#150F0B` on it (`OnAccent`).
- **Surfaces** (`Assets.xcassets/Colors`): background `#0B0D10`, card `#171B21`, elevated `#222831`, fill `#2B323C`.
  Hairline is white at 7 %. Text colors: `#F6F3EC`, `#B5B9C2`, `#7F8793`.
- **Semantic extras** add a lot of hue: danger `#FF6B76`, warm-up yellow `#E9D875`, drop `#B8A1EE`,
  kg chip blue `#97C7EE`, lb chip mint `#A8CDBF`, mixed-unit lilac `#B8A1EE`, calorie pink `#F4939C` and `#FF5E7A`
  (two different pinks on two screens), five muscle-family colors (`#FF70B6 #4EB9FF #4DE0D4 #B891FF #84D65A`),
  and pastel zone colors (`#8ABCE5 #80CABE #A5CF9A`). Zone 4 reuses the amber accent and zone 5 reuses danger.
- **Radii** are 24 for cards, 16 for inner elements and 10 for fields. **Type** is SF Pro. Only `Theme.hero` (unused in the
  audited screens), `Theme.stat` (title2 rounded bold) and the numbers use the rounded design. Everything else is
  plain headline, caption or caption2. There is no display face and no distinctive typographic voice.
- **Components:** `.card()` (flat fill plus 1 pt hairline and no shadow), `Chip` (capsule with a 12 % tint), `StatTile`,
  `ProgressRing`, `EmptyState` (SF Symbol in a circle plus a "sparkle"), `HeroCapsuleLabel` (amber capsule with an ink
  disc), `.primary` (amber, 52 pt) and `.secondary` (fill, 44 pt) buttons, `MuscleIcon` (body-map PNG pairs, templates
  only). Haptics cover set completion, rest done and workout start. Motion covers the set-complete spring, the
  breathing live dot, the ring animation and the heart pulse.
- **There are three surface families, measured from the PNGs:**
  1. Themed screens: `#0B0D10` background with `#171B21` cards (Start, History, Gyms, Exercises, active workout).
  2. The Settings screen: `#0B0D10` background with **`#1C1C1E`** system rows. `AppSettingsSection` never sets
     `listRowBackground`, so its card is visibly a different gray from every other card.
  3. Every `Form` sheet (Template editor, Machine editor, Gym editor, Rest, Max HR, New Exercise, Load Type, Ask AI,
     AI proposal, Scan): system `#1C1C1E` background with `#2C2C2E` rows, which reads as neutral gray.
     `PreviousPerformanceSheet` also uses the default List style.
  Moving from a themed screen into a sheet visibly changes the palette from blue-graphite to neutral gray.
- **Nav chrome** uses iOS 26 glass circles and capsules. Their icons are amber in several places (the gear, the History
  calendar, the Exercises filter, the Gym ⋯ button, the detail kettlebell) and plain in others. System context menus
  show their icons in **system blue**, for example Save as Template and Delete Workout in the workout-detail menu
  (`history-13-menu.png`).
- **Three different duration formats:** `Format.duration` is always `m:ss` (a 75-minute workout would show "75:00" on the
  finish tile, and "0:15" means 15 s). The History row and detail use "45 min" or "39s". The template detail uses
  "Rest: 60s" and Settings uses "Working rest · 2:00".
- **Internal decision IDs leak into visible copy:**
  `ExerciseRestSettingsSheet.swift:75` "Drop sets never start a rest **(D26)**."
  `EditExerciseLoadTypeSheet.swift:46` "History is frozen on purpose **(D23)**".
- **No personal-record surfacing anywhere in the UI.** A grep of `Features/` finds no PR, record or badge view.
  Records appear only as a text list in the Previous Performance sheet, and the chart shows only "+26 %".
  Nothing celebrates, compares or streaks anywhere in the app.

---

## 2. Screen by screen

### 2.1 Tab bar and global navigation
- There are four tabs: Workout (`figure.strengthtraining.traditional`), History (`clock.arrow.circlepath`),
  Gyms (`building.2`) and Exercises (`list.bullet.rectangle`). It is the stock floating glass bar. Only the selected tab
  is amber, over a gray pill.
- Settings sits behind a gear on the **Workout tab only**. It cannot be reached from any other tab.
- **Boring:** the icons are stock SF Symbols (Exercises is a generic list glyph). Nothing changes when a workout is live:
  no badge, no timer and no live dot on the tab bar.

### 2.2 Start / Workout tab
Captures: `followup-start-default.png` (Sep 22, 430 pt) and `ai-immediate-template-1-default.png` (Sep 22).

**What works:** a clear gym context at the top; two big, obviously tappable amber capsules; muscle-map strips on the
template tiles are the most characterful element in the app; the Resume capsule with its breathing dot.

**Messy:**
- **Three left edges.** The gym card, capsules and template tiles start at about 20 pt. The "Templates" section header
  and the **Ask AI for Templates** button start at about 40 pt, because they keep default List insets while the grid row
  has zero insets. The "Machines resolve…" caption starts at about 24 pt. All three are visible in
  `followup-start-default.png`.
- **Ragged right edge.** The two capsules hug their content. Their row ends at about 372 pt while the gym card above
  ends at about 409 pt, leaving a 37 pt gap on the right.
- **Equal-weight blocks.** The gym card (83 pt tall), two amber capsules (55 pt), the gray New Template tile (140 pt) and
  the gray Ask AI button all compete. Three of the four actions are gray fills of different shapes (card, rounded-rect
  tile, rounded-rect button).
- **Dead space.** With no templates, about 196 pt of empty background sits between the caption and the tab bar
  (`followup-start-default.png`). The New Template tile sits alone in the left column with an empty right half.
- **Gaps between blocks** run about 40 pt (gym card to capsules) and about 43 pt (capsules to "Templates"), while the
  header-to-tile gap is about 12 pt. The rhythm is uneven.
- **Gym card with no city.** "Template Gym" sits high in the card and is not centered on the pin tile, because an empty
  `Text("")` still reserves the second line (`StartWorkoutView.swift:329`). See `ai-immediate-template-1-default.png`.
- **Template grid rows are not top-aligned.** The row `HStack` uses its default center alignment, so a shorter tile floats
  down. The "Whole Body" tile starts about 16 pt lower than "Day 3 — Fitness" beside it (`ai-immediate-template-1-default.png`).
- **Tile body text is a long paragraph** of exercise names joined with " · ", never truncated. "Dumbbell" repeats six times
  per tile and tiles grow to about 175 pt. Days 1, 2 and 3 of the AI week look identical.
- **Orphan caption.** "Machines resolve to your last-used at your gym" (caption2, tertiary) floats under the Ask AI button,
  far from the templates it describes, and reads like a developer note.
- The unit chip "lb" is mint and the pin tile is amber at 10 %, which adds two unrelated hues to one card.
- The large title "Workout" repeats the tab name.

**Boring / generic:** a page of rounded rectangles on near-black; no greeting, date or sense of "today"; the only color is
amber plus the tiny muscle maps. The New Template tile is a gray box with a "+" in it.

**Missing at a glance:**
- The last workout and when it happened
- This week's count, streak or weekly goal
- The suggested next template (for example "Day 2 is next")
- Per-template last-performed date, estimated duration and set count
- The gym's machine count
- The Resume capsule shows "Iron Temple · 0 exercises" with **no elapsed time** (`resumeSubtitle`), so the live workout's
  most important fact is absent.
- No weekly volume or recovery hint.

**Live-workout state** (`10/04-start-live-axl.png`, AXL only): the Resume capsule replaces both start capsules, so Start
Cardio disappears. It has no progress and no timer. At AXL it wraps to four lines ("Resume / workout / Iron Temple · /
0 exercises") inside a 330 pt-wide capsule that still hugs rather than spanning the full width.

**Dialogs from here:** confirmation "A workout is already in progress" (Resume Workout / Finish It & Start New / Cancel,
message "Completed sets and recorded cardio are kept."); a replacement drift dialog (4 options plus "Keep Current
Workout"); the gym Menu (a system menu listing "No gym" plus gyms with checkmarks); the Cardio activity picker sheet;
the Template editor sheet; the Ask AI full-screen cover; and a Settings push.

**AXL** (`followup-start-axl.png`, `ai-immediate-template-1-axl.png`):
- The capsules stack correctly.
- The gym card pushes "lb ⌃⌄" onto its own right-aligned line, leaving a large empty band.
- The **Ask AI button wraps to "Ask AI for / Templates"** with the sparkle glyph left-top and text flowing under the glyph.
- Tiles go to one column with 40 pt muscle maps. The Start screen becomes 3+ screens of paragraph text.
- The caption wraps to two lines.

### 2.3 Template detail
Captures: `ai-template-detail-default.png` (Sep 20) and `15/04-template-detail-fixture.png` plus `-axl.png` (Sep 13).

**Works:** a big title; a muscle-map strip; clean grouped exercise rows; the Start capsule pinned at the thumb with a fade
behind it; Delete is demoted to red text.

**Messy:**
- The muscle strip floats alone under the title with nothing to its right.
- **Separator insets differ**: superset rows (A/B chips) inset the hairline to the text at about 43 pt, while other rows
  inset at about 17 pt, so the list's left rule jogs.
- The A/B chips are solid amber discs that only label position. Nothing visually binds A to B as a superset.
- "Rest: 60s" is a third line of gray caption.
- "Planned cardio" is a separate section with a different row style (headline plus caption, no icon).
- "Delete Template…" floats mid-page with about 80 pt of empty space above the pinned capsule.
- An amber smear shows through the glass tab bar under the capsule (about y 1808 px in both default captures).
- The capsule subtitle "1 exercise" ignores the planned 15-minute walk (`startSubtitle` counts lifting items only).

**Boring:** the rows are plain text, identical to a Settings list. There are no per-exercise muscle or equipment cues and
no visual difference between a machine exercise and a dumbbell exercise.

**Missing:**
- Last weights used per exercise (the app knows them; see Previous Performance)
- Which machine at this gym each exercise resolves to (the app computes this at start)
- Estimated duration
- Last time this template was done and how often
- A total set count
- A preview of the planned rest

**AXL:** the chip stacks above the name. The pinned capsule (Start / 6 exercises) covers about 30 % of the screen and
overlaps the list mid-row ("Ma… Pr…" clipped behind it). Muscle maps wrap to two rows.

### 2.4 Template editor sheet (`TemplateEditorSheet`, stock `Form`)
Captures: `ai-template-editor-default.png` and `-axl.png` (Sep 20).

**Messy:**
- System gray surfaces, off-theme.
- The **principal toolbar slot holds an `EditButton` ("Edit") where the title should be**, so the sheet reads as "Cancel ·
  Edit · Save" and its real title "Edit Template" is never visible.
- Each exercise is a tall stack of stock controls: name, "3 sets" stepper, "Use exercise rest default" toggle, "Rest: 60s"
  stepper, then one stepper per set ("Set 1 target · 10 reps"). The stepper capsules visually touch or overlap vertically
  (rows are about 30 pt apart with 34 pt-tall steppers).
- The toggle's OFF state (white knob on gray) sits beside a custom rest, which is confusing: "Use exercise rest default"
  OFF means a custom value is in use.
- Delete is a bare "⊖" at the right of the name.
- **"Add Exercise" is a flat list of all 90 catalog exercises** with amber "⊕" rows. It has no search, no muscle
  grouping and no picker.
- Cardio targets use another stock block ("Activity  Outdoor Walk ⌃⌄", "15 min" stepper, "Distance target" toggle,
  red "Remove cardio").

**Boring and missing:** no muscle icons, no weights, no drag handles until Edit is tapped, and no preview of the resulting
tile.

**AXL:** every label wraps ("Use exercise / rest default", "Set 1 target · / 10 reps"). The sheet becomes a long column of
steppers.

### 2.5 Active lifting workout: top bar and header
Captures: `cardio/screenshots/regression/redesign-02-active-workout*.png` (Sep 18).

**Top bar:**
- The glass capsule groups **"⌄" (minimise) and a red "Cancel"** together, putting the safe action next to the
  destructive one.
- The principal title is the derived workout name, which duplicates the first exercise ("Seated Ches…" plus a pencil) and
  truncates to about 13 characters (about 7 at AXL).
- "Finish" is a plain glass capsule with no emphasis, so completion is visually weaker than Cancel's red.

**Header row:** a gray gym chip with a pin, the **elapsed "0:14" in title2 rounded bold**, a spacer, and a gray
`ProgressRing` 22 pt with "1/2 sets". That is three visual languages in one row. The ring is gray (`Theme.secondary`) and
barely visible.

**AXL:** the gym chip wraps "Iron / Temple" with the pin on line one, and "1/2 / sets" wraps. The header becomes about 75 pt
tall.

**Missing:**
- Workout-level volume
- Current exercise and next set
- Estimated finish time
- The template's name or progress when the workout came from a template

### 2.6 Active workout: exercise card and set rows (`ExerciseEntryCard`, `SetRowView`)

**Works:** a familiar Strong/Hevy-style grid (SET · PREVIOUS · WEIGHT · REPS · ✓); prefill from history; a spring and
haptic on completion; swipe-to-delete; a set-type menu; the bar-mode total caption "= 135 lb" in amber.

**Messy:**
- **Title actions are two unrelated glyphs**: `ellipsis.circle` in secondary (it renders as a dim amber-brown) and
  `chart.bar.doc.horizontal` in amber. The chart glyph opens Previous Performance, which is not obvious.
- **The machine row's chevron sits right after the text, not at the trailing edge**, because the `Spacer` comes after the
  chevron (`machineRow`, and the same in `barRow`). In the capture the ">" floats mid-card at about 280 pt while the row
  extends to about 370 pt.
- The machine row's icon is `gearshape.2` for a machine and `dumbbell` for everything else. A gear reads as "settings".
- **The PREVIOUS column is the widest column and usually shows "—"** (a new machine context has no history). The
  numbers are crammed right while a column of empty space sits in the middle.
- **Every weight field carries a "lb" unit chip** (mint), which takes about 40 % of the 88 pt field on every row.
- The **set-type marker "2⌄"** puts a number and a chevron inside a 34 pt circle, which is cramped. When completed, it
  becomes a solid amber disc.
- The **completed row tint is amber at 8 % over the card, which renders muddy brown `#2A2726`**. It does not read as
  success. There are three amber marks per completed row (disc, tint, check).
- The "Add Set" button is full width, 44 pt and gray, and weighs as much as a set row.
- **The preset chip row sits below the sets** (before Add Set), so you pick the variation after logging.
- The "Target: 3 sets · 10, 10, 10 reps" line appears only when `plannedRestSeconds != nil`, which is an arbitrary
  condition.
- The assisted-load warning is an inline gray sentence ("Assisted: lower weight = harder…").
- In bar mode, the Bar row ("Bar: 45 lb >") is a second full-width fill row stacked under the machine row.
- A superset shows only the A/B chip on each card. Nothing connects the cards visually.

**Boring:** every card is identical. There is no exercise imagery (the muscle icon was removed per D54 ticket 11 "they
don't match"). The card does not change when finished (no collapse, no summary, no check on the card), and it gives no
sense of progress within an exercise.

**Missing:**
- Which set is "up next" (no focus or highlight)
- An e1RM/PR hint when you beat last time
- A per-set "↑ vs last" delta
- A plate breakdown (only the total)
- Per-exercise rest remaining
- Machine settings or seat position notes
- Quick weight or rep steppers (keyboard only, decimal pad plus a "Done" toolbar)

**AXL** (`…-axl.png`, `-axl-2`, `-axl-3`):
- The title actions drop to their own right-aligned row.
- Each set becomes a two-row block (marker · "—" · check, then a WEIGHT/REPS label row, then the fields). Two sets
  consume a whole screen.
- The "WEIGHT/REPS" label row of the first set is sliced by the rest bar's top edge (`…-axl.png` about y 1500 px).

### 2.7 Heart-rate bar (`HeartRateBar`)
Captures: the regression captures and `cardio-built-lifting-banner-*.png`; zone chip in `claude/redesign-02-heart-rate-zone.png`.

**Works:** a big red bpm and calories on the right. When zones are known, the "Zone 2 ▮▮▯▯▯" chip is a nice mini meter.

**Messy:**
- A second line of caption2 gray: the source ("Test data" in the simulator; "Apple Watch", "AirPods" or "Heart rate
  monitor" on the device) followed by an **underlined web-style link "· set up zones"** or "· edit zones".
- The pulsing heart symbol spends half its cycle dim maroon, so it looks disabled in captures.
- "5 cal" floats alone at top right.
- The card is a full 64 pt-tall container for one number.
- The permission, denied and unavailable states are plain gray sentences with an icon.

**Boring and missing:**
- No live sparkline or trend
- No zone color on the card itself (the bpm text is always danger red regardless of zone)
- No recovery indicator tied to the rest timer, although heart-rate-based rest exists (D43)
- No max and average so far

### 2.8 Rest timer bar (`RestTimerBar`, bottom `safeAreaInset`)
**Works:** it is always visible at the thumb, with a big m:ss, "+15s", and "Skip" in amber.

**Messy:**
- A 44 pt amber `ProgressRing` around an hourglass. The ring is decorative at that size and competes with Skip.
- The "Rest" caption sits above the time.
- The bar is a floating elevated card that covers content. At default size it takes about 83 pt. **At AXL it grows to
  about 175 pt (about 20 % of the screen)** with the buttons on their own row.
- Skip is amber at the same weight as Add Exercise, so two primary amber buttons are on screen at once.

**Boring:** no full-screen or immersive rest mode, no countdown color change as time runs out, and only one button pair.
The heart-rate "recovered" state has no visual in the bar. The alarm and haptic are the only feedback.

**Missing:**
- The next set preview ("Next: Set 2 · 60 lb × 10")
- A −15s option
- Heart-rate recovery progress when rest-by-heart-rate is on

### 2.9 Bottom actions, planned cardio, Lifting/Cardio switch
- The **three add buttons** are Add Exercise (amber primary, half width), Add by Machine (gray, half width, disabled
  without a gym) and Add Cardio (gray, full width). The caption under them reads "Pick a gym to log by machine".
- At AXL all three become full-width stacked slabs. Add Exercise stays amber. The block is about 250 pt tall.
- A **stock segmented "Lifting | Cardio"** control appears only once cardio exists. It is visually foreign (system gray
  segment).
- **Running cardio while in Lifting** shows as a bare list row: a run icon, "Indoor Run", and a trailing "Recording" in
  gray. There is no card, no live metric and no pulse (`cardio-built-lifting-banner-default.png`).
- The **Planned cardio** section uses default List rows with a plain "Start" text button or "Started".
- The **empty workout** (no exercises) is the header, the heart-rate card and the three buttons, followed by about half a
  screen of black. There is no guidance and no template suggestions.

### 2.10 Active-workout sheets, menus and dialogs (from source; no captures)
| Surface | Current look (source) | Notes |
|---|---|---|
| **Add Exercise** `ExercisePickerSheet` | Themed List of all 90 `ExerciseRow`s (name, body-area text, equipment chips, amber load badge) with `.searchable`, "Create “x”" when there are no matches, and "New Exercise…" after the whole list. Cancel is at top-left. | No recents, favorites, muscle filter or "machines at this gym" hint. No muscle imagery. |
| **Add by Machine** `AddByMachineSheet` → `MachineExerciseList` | "Machines at <gym>" rows (label plus model caption), `EmptyState` "No machines yet", and "Add Machine…". A machine with several exercises pushes a picker. | Rows are text only, with no photo or type icon. |
| **Equipment** `MachinePickerSheet` | Gym machines (label, model, unit chip, ✓), then "Free weights" where **every tag (barbell, dumbbell, cable, smith, bodyweight) uses the same `dumbbell` icon**, plus "Log as … instead", and the footer "A completed set locks equipment…". | Generic icons. |
| **Bar** `BarPickerSheet` | List of preset bars plus a "Custom bar" section with a TextField, unit picker and "Use this bar". | Stock. |
| **Rest** `ExerciseRestSettingsSheet` | `Form`: two duration sections ("Use global default" toggle plus stepper), "How this exercise rests" picker and cap stepper, and a long safety paragraph as the footer. | **"(D26)" in the footer**. System gray. |
| **Heart Rate** `MaxHeartRateSheet` | `Form`: measured max field, a date-of-birth toggle and DatePicker, and "Zones would use" bpm rows. | No zone visual. |
| **Previous performance** `PreviousPerformanceSheet` | **Default List style** (system gray). Three layers with **`.green` target / `.orange` gear / gray** icons in their headers, long footers, set lines, and "1RM (Brzycki)". | Off-palette system colors and jargon. It is the richest data screen in the app and the least designed. |
| **Exercise options** menu (⋯) | Rest Durations…, Superset with next, Break superset, Delete Exercise | — |
| **Set type** menu | Working / Warmup / Failure / Drop, with a check | The marker letters W/F/D are colored yellow, red or lilac. |
| **Workout Name** alert | TextField, Save/Cancel; "This workout has finished" refusal alert | — |
| **Cancel** confirmation | "Cancel this workout?" Discard Workout / Keep Logging | — |
| **Template drift** dialog | "Update workout template?" with 4 buttons plus a cancel. The message is a long sentence. | Heavy for a finish moment. |
| "Cardio could not be saved" alert; Cardio activity picker; keyboard "Done" toolbar; swipe-to-delete (custom red trash tile); long-press "Delete Set" | — | — |

### 2.11 Finish summary (`WorkoutFinishedSheet`, `.large`)
Captures: `17/selected/redesign-03-finish-summary.png`, `-scroll-1.png`, `-axl.png`, and `-axl-scroll-2.png` (Sep 17).

**Works:** a clear confirmation, one primary next step, and stats grouped in tiles.

**Messy:**
- **Redundant headline stack:** the nav title "Nice work", the card headline "Workout saved", and a large static amber
  `ProgressRing` at 100 % with a check. The ring looks like a progress meter but is decorative.
- The summary line mixes counts and a place ("1 exercise · 1 set · Iron Temple").
- **Six equal StatTiles** (time, volume, active cal, total cal, avg HR, max HR) in a 2×3 grid. Nothing is hero.
- Units are uppercase and shouty ("5 CAL", "125 BPM").
- **"0:15"** workout time is ambiguous (seconds).
- Tile icon colors are inconsistent: timer amber, volume white, calories pink `#F4939C`, heart red.
- **The heart-rate chart degenerates on short workouts**: one fat gradient bar and three identical x-labels
  "6:03 PM 6:03 PM 6:03 PM". At AXL a lone orange tick floats by the "92" label.
- The exercise cards give only "1 set · best 60 lb × 10" in amber.
- "Done" lives in the toolbar while "View in History" is the big amber button.

**Boring:** static. There is no animation, confetti, count-up or shareable card. It reads like a receipt.

**Missing:**
- **New PRs / records beaten**
- A comparison with last time or the template (volume ±, sets ±)
- **Muscle families worked** (the muscle maps exist but are used only on templates)
- Weekly progress or streak
- Per-exercise set lists
- A heart-rate zone summary as a hero (zones appear only when present)
- A share or export image
- A rename affordance
- "Nothing to save" empty variant: a gray tray icon in a gray ring. Plain.

**AXL:** the ring stays beside the wrapping headline ("Workout / saved", "1 exercise · 1 / set · Iron / Temple"). The tiles
become six full-width cards, and the chart shows one x-label.

### 2.12 History list
Captures: `11/05-history.png`, `05-history-axl.png`; empty `09/08-empty-history.png`.

**Works:** a date tile (day number over weekday), month headers, and consistent cards.

**Messy:**
- **The rows are indistinguishable.** Five consecutive rows read "Seated Chest Press / No gym / 1 exercise · 1 set · 45 min
  / lb". The title is the derived first-exercise name.
- **The Label icon-to-text gap is huge.** The pin glyph sits about 20 pt left of "No gym", so the text looks detached.
- A "lb" chip on every row carries no information when all your lifting is in lb.
- The chevron is redundant with a full-card tap target.
- The month header is small uppercase caption2 and is visually weaker than the card titles.

**Boring:** a monotone stack of identical cards. No color coding by muscle family or workout type, and no cardio icon.

**Missing:**
- A month or week summary (workouts, volume, time)
- A streak or consistency strip
- Muscle families per workout
- PR badges
- Volume per workout
- A lifting/cardio/mixed distinction
- Search and filter (by exercise or gym)

**Empty state:** the generic `EmptyState` (clock glyph in amber circles plus a sparkle), "No workouts yet", and "Finished
workouts show up here." It has **no Start CTA**. The calendar button stays active even with no data.

**AXL:** the date tile stacks above the title. The title wraps to two lines. The stats wrap, and the "lb" chip floats
mid-right, centered on the wrapped stats. One row is about 300 pt tall.

**Dialog:** swipe → "Delete this workout?" with a long impact sentence.

### 2.13 Calendar sheet (`HistoryCalendarSheet`)
Capture: `11/05-calendar.png`.

**Works:** month cards with a pinned weekday header, solid amber discs on workout days, a gray ring for today, and dimmed
future days. It is easy to scan frequency.

**Messy:**
- **The pinned weekday header clips the top of the first month card** as it scrolls (the card's top corners are cut at
  about y 370 px).
- The close control is an amber ✕ in a glass circle at top-left, where other sheets use "Cancel" or "Done" text.
- Workout-day discs are **identical saturated amber**. A dense month becomes a wall of amber (Aug 2026 has 12 of 31).

**Boring and missing:**
- No intensity or volume encoding, and no lifting vs cardio distinction
- No month totals, streak count or legend
- Only one workout opens per day (the app picks one)
- No "jump to today"
- It is a sheet rather than an integrated History header, so the list and calendar never coexist.

### 2.14 Workout detail (`WorkoutDetailView`)
Captures: `14-05-detail-heart-rate.png`, `-zones.png`, `-axl.png`, `history-13-menu.png`, `history-13-alert.png`
(Sep 12), and the mixed detail `cardio-built-mixed-history.png` (Sep 18/20).

**Works:** exercise sections with set lines ("60 kg × 10"), a per-exercise chart button, heart-rate tiles, a chart, and a
zones card.

**Messy:**
- **No hero.** The nav title is just the date ("Sep 10, 2026"). The first card is a settings-style "Name … Seated Chest
  Press ✎" row plus "📍 No gym … 60 min", so duration is a small gray trailing value.
- **Container widths disagree.** The HR stat tiles span about 17 pt from the edges, while the heart-rate chart card and
  "Time in zones" card are inset to about 33 pt (`14-05-detail-heart-rate-zones.png`). In the mixed detail, the cardio
  card is also inset about 16 pt more than the set-row card.
- Exercise headers sit outside their card: the name, the gray "No equipment" and a "Weighted" chip. **The chip is secretly
  a Menu** holding load-type choices and **"Remove Exercise"**, a destructive action hidden in a chip.
- The chart button is an amber-on-amber-12 % circle.
- Set rows are tappable to edit, but nothing shows that.
- The number bubble "1" is gray-filled and small.
- **The toolbar menu is a `scalemass` (kettlebell) glyph** that also shows the unit. It hides "Save as Template…" and
  "Delete Workout…". The menu's icons render **system blue**, and it mixes actions with a units picker (As entered /
  Show in kg / Show in lb).
- "Add Exercise…" is a left-hugging gray button followed by the cryptic footer "Recorded as defined today, without
  equipment."
- **"Edited <date>"** appears as a small label at the very bottom.
- **The delete dialog always says "… kg of volume"** (`Format.weight(impact.volumeKg)) kg`) even for lb users.
- The heart-rate chart is a min–max range "barcode" of thin pink-to-amber gradient bars. It is noisy.
- The zones card uses pastel bars labeled "Zone 1/2/3" with no meaning words ("Light", "Moderate"), which exist only in
  accessibility text.

**Boring:** the lifting part is a gray settings list. All the color on the screen is in the heart-rate section.

**Missing:**
- A summary hero (duration, volume, sets, exercises, muscle families)
- PRs set in this workout
- Comparison with the previous session of the same template
- Notes
- Machine names per exercise (only "No equipment" or a label)
- Per-exercise volume

**AXL:** the stat tile labels wrap beside their icon ("Active / calories"), the chart shows a single x-label, and the
zones rows clip under the tab bar.

**Sheets and dialogs:** Edit Set (Form: weight, unit, reps, set type; footer); Exercise picker (add a past exercise, then
an Edit Set sheet for the new set); remove-exercise, delete-set and delete-workout confirmations; rename alert; Save as
Template alert ("Saves exercises, sets and target reps — not weights or rest times.") and failure alert; chart sheet.

### 2.15 Exercise progress chart (`ExerciseProgressView`, sheet or push)
Capture: `11/05-chart.png`.

**Works:** a monotone amber area and line with points, a Best set / Volume / 1RM segmented control, a tap-to-select callout
row, and a "+26 %" change stat.

**Messy:**
- **The sheet has no close button.** There is no toolbar in the file, so it can only be dismissed by swiping down.
- The "Variation" card holds just an amber menu line, "No equipment recorded · 9 days ⌃⌄".
- **The Y axis starts at 0**, so a 95→120 lb climb looks nearly flat in the top third while the brown area fill occupies
  60 % of the card.
- The callout is a separate LabeledContent row under the chart rather than on the chart.
- "Change / Since first session +26 %" is one lonely card.
- A stock segmented control.
- A caution line "Only N days logged — read the shape with caution." appears when data is thin.

**Missing:**
- PR markers on the line
- A time-range selector
- The session list or table below
- Rep-range bests
- The current e1RM as a hero number
- Machine or gym comparison
- The "1RM" label has no explanation.

### 2.16 Gyms list
Captures: `11/06-gyms.png`; empty `09/08-empty-gyms.png`.

**Messy:**
- One card, then a **left-hugging "Add Gym…" gray button**, then about 70 % of the screen empty.
- The gym row is an amber pin tile, the name, a gray chip "🏋 1" (an ambiguous count with no noun), and a lowercase
  tertiary **"app default"** orphan when the gym has no unit.
- **Empty state has no EmptyState illustration.** The screen is just the "Gyms" title and one amber "Add Gym…" button at
  top-left over a black void. History and machine lists do use `EmptyState`, so this is inconsistent.

**Boring:** every gym gets the same pin glyph. No photo, map, city skyline or color identity.

**Missing:**
- Last visit
- Workouts logged here
- Machine count with a noun
- Which gym is currently selected on Start
- Location or distance

### 2.17 Gym detail and machine sheets
Captures: `11/06-gym-detail.png`, `07/06-gym-detail-axl.png`, `09/07-delete-machine-confirmation.png`, and Sep 22 `followup-machine-editor-default.png`, `followup-capture-default.png`, `followup-proposal-default.png`.

**Messy:**
- The first card is a settings form ("Default unit … App preference", "City … —", amber "✎ Edit Gym…"). **Edit Gym is
  duplicated** in the ⋯ menu, which also holds "Group Machines By" and red "Archive Gym".
- **Every machine card shows the identical amber `dumbbell.fill` tile** (a chest press and a leg press look the same).
- The model name sits in a gray chip that shrinks rather than truncating (`minimumScaleFactor(0.85)`).
- **Tapping a machine card does nothing.** Edit Machine, Correct Model, Rename Model and Delete are reachable only by
  long-press context menu or swipe.
- "Add Machine…" is an amber button hugging the left, followed by the footer "The model is optional — …".
- "Deleted machines (n)" is a trash-icon row.

**Boring and missing:**
- No machine photos (a scan flow exists)
- No per-machine last-used weight or date and no usage count
- No grouping visuals by muscle
- No hero for the gym (name, city, machine count, workouts here)

**AXL:** **the dumbbell glyph overflows its fixed 40 pt tile** (`machineRow` uses `.frame(width: 40, height: 40)` with a
`.title3` glyph that scales). The GymRow pin tile is also a fixed 44 pt. The value "App / preference" wraps.

**Machine editor** (`MachineEditorSheet`, Form, system gray):
- A label field, then "Catalog model None >", "📷 Scan equipment…", and **"Read label on device" with no icon, so its text
  starts about 29 pt left of "Scan equipment…"**.
- Then an "Exercises" list with "Choose exercises >", a "Default unit  Gym default ⌃⌄" row, and a Preset picker footer.

**Scan Equipment:** a blank gray canvas with a centered camera-viewfinder glyph, "Scan a machine or its label", a brown
"Take photo" capsule, a disabled "Flash", and "Choose a photo instead". It is stock and empty.

**AI Proposal:** a Form with a Name field, a "Saved as this gym's machine, with no model claimed." caption, Exercises, and
**an amber "Use this equipment" button hugging left inside a gray card**, above a plain "Take another photo" row.

**Delete machine:** a system alert, "Delete Old Leg Press?" with a consequence line and red Delete / amber Cancel.
Also: Catalog Model picker (search plus filters plus "New Model…"), New Model sheet (with an OpenAI consent alert), Rename
Model alert, Correct Model sheet, and Deleted Machines list (Restore; `EmptyState` "Nothing deleted").

### 2.18 Exercises
Captures: `11/07-exercises.png`, `07-exercises-axl.png`.

**Works:** a searchable list; equipment chips; load-type badges (Assisted, BW + added) in amber.

**Messy:**
- **All 90 seeded exercises sit in one giant card**, A–Z, with no section headers or index. (The count comes from
  `SeedCatalog.json`: 90 exercises and 1,877 equipment models.)
- **The body-area text ("Core", "Chest") sits higher than the equipment chip beside it.** The plain `Text` and the
  padded `Chip` share a `WrapLayout` line without baseline alignment.
- The load badge floats at the far right at a different vertical position from the chip.
- "Custom" is a tertiary caption2 tag.
- **Rows are not tappable.** Progress…, Presets…, Load type… and Rename… are all long-press only. The tab has no
  exercise detail page.
- "Add Exercise…" sits after all 90 rows.
- Filters live in a toolbar menu with nested menus. The active-filter summary row is an amber caption with "Clear".

**Boring:** a phone-settings-style list with no imagery. (Per-row muscle icons were removed by user decision, D54 ticket 11.
A redesign that reintroduces imagery must use something the user accepts.)

**Missing:**
- Last performed
- Best set / PR
- How often it has been done
- Favorites or recents
- The machines at your gyms that serve it

**AXL:** badges wrap onto the chip line. It is readable but very long.

**Sheets:**
- New Exercise (Form: name; load-type picker; footer warning; equipment toggle buttons)
- Presets (List; `EmptyState` "No presets yet. Without any, this exercise is logged as one thing."; add field; "Common"
  suggestions; EditButton)
- Load Type (Form; picker; "What this changes"; **"(D23)"** copy)
- Progress (the chart sheet above)
- Rename alert

### 2.19 Settings
Captures: `unit-settings-us-default.png`, `-axl.png` (Sep 20); `ai-key-settings-overview-default.png` (Sep 20).

**Messy:**
- **Off-theme card color** (`#1C1C1E` rows on a `#0B0D10` background).
- The first section has no header and mixes unrelated things: unit system, two rest steppers ("Working rest · 2:00",
  "Warmup rest · 1:00"), "Suppress template update prompts" (jargon), "Heart rate zones … Not set", and **"Ask AI about
  plates … Off"**. That label is out of date, because the sheet it opens now governs AI templates and equipment
  photos too.
- A conditional "History update … n sets moved to dumbbell exercises" row.
- Export: a plain "0 workouts · 0 sets" row, amber "Export CSV" and "Export JSON" rows, and the footer "This phone holds
  the only copy until you export."
- The Ask AI sheet is a Form with an "Ask AI … Off" row, **a five-line legal paragraph**, three permission toggles, a
  policies link, and an API-key field plus "Save key" row.

**Boring and missing:**
- No profile (name, bodyweight, birth date summary)
- No app identity, version or about
- No backup status (last export date)
- No iconography on rows
- No grouping (Workout / Heart rate / AI / Data)

**AXL:** the steppers sit beside labels wrapped to two lines, and "U.S. customary ⌃⌄" drops below its label.

---

## 3. Cross-cutting issues
1. **Surface inconsistency:** themed blue-graphite screens against neutral-gray system Forms and Settings (§1).
2. **Amber overload with no hierarchy.** On one active-workout screen amber is used for the completed marker, the
   completed row tint, the check, the chart icon, the ellipsis, Add Exercise, the rest ring, the hourglass and Skip, all at
   once. Amber also marks chrome icons, links, calendar days, the chart line, best-set text and superset chips. It stops
   meaning "primary" or "done".
3. **Too many unrelated hues in small doses:** unit chips (blue kg, mint lb, lilac mixed), warm-up yellow, drop lilac, two
   calorie pinks, danger red, pastel zones, five muscle colors. None is used large enough to create identity.
4. **Card-on-card sameness.** Nearly every screen is title, then 24 pt-radius flat cards, then a left-hugging gray button,
   then a footnote. There are no depth, imagery, gradients or full-bleed moments except the amber capsules and the HR chart.
5. **Hidden actions:** machine rows (long-press only), exercise rows (long-press only), the History "Weighted" chip
   (includes Remove Exercise), the kettlebell menu (Delete/Save as Template), and invisible tap-to-edit on set lines.
6. **Left-hugging secondary buttons** (Add Gym…, Add Machine…, Add Exercise… in History, Use this equipment) float at
   inconsistent widths with dead space to their right.
7. **Orphan footnotes and captions** that read like developer notes: "Machines resolve…", "Recorded as defined today,
   without equipment.", "The model is optional…", "(D26)", "(D23)", "Test data · set up zones".
8. **No celebration, progress or memory layer.** No PRs, streaks, comparisons, weekly rings or share cards anywhere.
9. **Duration and number formats differ between screens** (m:ss vs "45 min" vs "39s"; "5 CAL" vs "7 cal").
10. **AXL:** the layouts do adapt (stacking), but the fixed-size tiles overflow (gym and machine glyphs), the pinned bottom
    elements (rest bar, Start capsule) eat 20–30 % of the screen, and Label or wrapped text runs under icons (Ask AI).

## 4. Coverage checklist: every surface the redesign must restyle (strength side)
Tabs/nav: tab bar; large titles; glass toolbar buttons; system context menus; confirmation dialogs; alerts; keyboard
Done toolbar.

Start: empty; with templates (1–2 columns); live Resume; gym picker menu; no-city gym; AXL stacked; Ask AI entry;
caption; "already in progress" dialog; replacement drift dialog.

Template: detail (supersets, planned cardio, "Created for another gym", "No matching machine at this gym",
"unavailable cardio targets" notes, Delete alert, disabled Start when empty); editor (exercises, per-set steppers, rest
toggle, cardio targets, add list, EditButton reorder, error text); Save-as-Template alert.

Active workout:
- Top bar (minimise, Cancel, title/rename, Finish); header (gym chip, elapsed, sets ring)
- HR bar (live, stale "· Ns ago", waiting "Looking for a sensor…", needs permission, denied, unavailable, zone chip,
  set up / edit zones link)
- Running-cardio row; Lifting/Cardio segment; planned cardio rows
- Exercise card (superset chip, target line, machine row with model, bar row, assisted notice, column headers, set rows,
  set-type menu, unit toggle chip, PER SIDE total caption, disabled/enabled/completed check, swipe delete, preset
  chips, Add Set, options menu, Previous-performance button)
- Add buttons plus the "Pick a gym" caption; rest bar (default and AXL); empty workout
- All sheets in §2.10

Finish: saved; "Nothing to save"; with/without HR, zones, calories, volume; cardio section; "Saved as template" state; AXL.

History: list; empty; month header; row (single unit, mixed unit, cardio); swipe delete dialog; calendar (plain, today,
marked, marked today, marked future); workout detail (name row, gym/duration, exercise sections, load-type chip menu,
reclassified mark, set lines, HR tiles, HR chart, zones, cardio cards, add exercise, footer, edited mark, overflow menu,
all dialogs, Edit Set sheet); progress chart (variation menu, 3 metrics, empty, "One session", caution line, selection,
change card).

Gyms: list; empty; row (with/without city and unit); gym detail (info card, grouped machine sections A–Z/by type,
empty machines, deleted machines row/list, footer, ⋯ menu); gym editor; machine editor; catalog model picker; new model
(AI suggest, consent); scan/capture; AI proposal; correct model; rename model; delete machine alert; machine
context/swipe actions.

Exercises: list; filter active row; no matches; custom tag; context menu; new exercise; presets (empty/list/common);
load type; rename.

Settings: main list; HR zones sheet; Ask AI sheet; export (counting, summary, CSV/JSON, failure); ShareSheet.

## 5. Constraints from recorded decisions a redesign must respect or explicitly reopen
- **D54** (visual system): dark only, a single amber accent, and the rule "shape, colour and motion — never words" (copy
  and UI-test strings and identifiers kept). The user explicitly allowed changing the theme now, so D54 must be
  **reopened and recorded**. The copy freeze also affects any label changes.
- D54 ticket 11/12: the per-exercise muscle icon was removed from every row at the user's request ("they don't match").
  Muscle maps appear only as five families on templates. The user rejected SF-symbol muscle icons as "inaccurate and mild".
- D54 ticket 17: the user kept the finish-summary design and set its tile order.
- D15/D54 (Sep 19): the idle Start capsules are arrowless icon-disc amber capsules side by side, stacking only when they
  don't fit. Resume and template Start keep arrows. The user has flip-flopped here, so present options.
- D52: plain numbers and no estimate or provenance captions. D23: frozen history (edits are marked). D10: delete means
  archive.
- The user's original complaint (D54 rationale, 2026-09-10): "the app seems a bit boring, with mostly texts". The
  requested references were Apple Fitness and Hevy.

---

## 6. Top 10 problems (ranked across this scope)

1. **Nothing rewards progress.** There are no PRs, streaks, comparisons with last time or celebration on the finish sheet,
   History or charts. The finish sheet is a static receipt ("Nice work" / "Workout saved" / six equal tiles). This is the
   core of "boring".
2. **The active set grid is visually noisy yet low on signal.** Every weight field has an "lb" chip, the widest column is
   PREVIOUS showing "—", "2⌄" markers are cramped, completed rows are tinted muddy brown `#2A2726`, the chevrons are
   misplaced mid-row, the title glyphs are ambiguous, and nothing marks the next set.
3. **Amber is everywhere** (about 9 amber elements on one workout screen; also chrome, links and calendar), so the one
   accent carries no hierarchy. Meanwhile about 15 minor hues appear in tiny chips and dots.
4. **Two surface systems.** Themed ink cards sit beside neutral-gray system Forms, the Settings rows, and the default-List
   Previous Performance sheet. Every sheet looks like a different app.
5. **Start screen composition:** three left edges (about 20, 24 and 40 pt), a ragged capsule row, center-aligned template
   rows that don't top-align, paragraph-length tile text, an orphan developer caption, about 196 pt of dead space when
   empty, and no "today" context. The Resume capsule has no elapsed time.
6. **History is a stack of identical text cards** with no summary, streak, type or muscle cues, and a huge icon-to-text gap.
   The workout detail has no hero, mismatched card widths (tiles at about 17 pt vs chart and zones at about 33 pt), and a
   kettlebell glyph as the menu for Delete and Save as Template.
7. **Hidden or undiscoverable actions:** machine rows and exercise rows respond only to long-press, the "Weighted" chip
   hides Remove Exercise, the progress-chart sheet has no close button, and set-line edits have no affordance.
8. **Exercises and Gyms are phone-settings lists:** 90 exercises in one card, baseline-misaligned body-area text, and
   identical dumbbell tiles for every machine. Empty Gyms is one button in a void, and there are left-hugging Add
   buttons.
9. **Rest and heart rate are under-designed:** a small rest card with a decorative ring and no next-set preview (and 20 %
   of the screen at AXL); a heart-rate card with an underlined web link, a maroon-flickering heart, no zone color and no
   trend. The heart-rate chart degenerates on short workouts (three identical x-labels).
10. **Inconsistent copy and format details:** leaked decision IDs "(D26)" and "(D23)"; three duration formats (m:ss /
    "45 min" / "60s"); "CAL" vs "cal"; the stale "Ask AI about plates" label; the delete dialog always in kg; and the
    template-editor title replaced by an "Edit" button.
