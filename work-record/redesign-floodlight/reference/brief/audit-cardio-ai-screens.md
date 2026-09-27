# Visual audit: cardio and AI flows (current look)

Scope: how the cardio and AI (Terra / OpenAI) flows look now, taken from the recorded simulator
captures and checked against current source where a capture might be out of date. Read-only:
nothing was built, run or edited.

Repo root: `/Users/ericlee06/orca/projects/Health App`. Every capture path below is relative to
`work-record/`. Dates are the commit dates of the capture folders. File mtimes are checkout
times, so they do not date the captures.

| Folder | Commit date | Notes |
|---|---|---|
| `cardio/screenshots/final/`, `review-01/`, `regression/` | 2026-09-18 | The oldest set. The picker capture still shows the earlier Start layout. |
| `cardio/screenshots/ui-refinements/` | 2026-09-18 | Ended-outdoor card |
| `cardio/screenshots/start-capsules/`, `compact-start-outdoor/` | 2026-09-19 | Current start capsules; outdoor live view without a map |
| `cardio/screenshots/units-and-indoor/` | 2026-09-20 | Newest cardio set: live, controls, measured distance, summary, mixed history, unit settings |
| `ai-gym/screenshots/*.png` | 2026-09-20 | Routine, identity, consent, key, template and planned-cardio captures |
| `ai-gym/screenshots/followup/` | 2026-09-22 | Newest AI set: start screen with AI templates, gym and scan inside the routine form, capture, proposal, machine editor |

All captures are iPhone 17 Pro/Pro Max class simulators (1206×2622 and 1290×2796), in dark
appearance, at two text sizes: Default and AccessibilityL (AXL).

**Global theme as seen.**
- The background is a near-black navy (#0B0D10), with cards in a lighter navy-grey.
- One accent does almost every job: amber/orange (#FFB45E-ish). It marks primary buttons, links,
  picker values, toggles, the route polyline, icons and even a sheet title.
- Red is used for Cancel and destructive actions, and also for heart-rate numbers.
- A mint "lb" pill marks units.
- Glass capsule toolbar buttons (iOS 26 Liquid Glass) and a floating glass tab bar.
- Numbers use a rounded bold hero face. Everything else is SF.

**Sheets break from the app background.** The system `Form` sheets use a different surface: iOS
grouped grey (#1C1C1E) or pure black (#000). The app screens use the navy-black. So the AI flows
and editors look like a different app from the Workout/History screens.

---

## A. Cardio

### A1. Workout home with cardio entry (Start Lifting / Start Cardio)
**Captures:**
- `cardio/screenshots/compact-start-outdoor/redesign-cardio-start-default.png` and `…-axl.png` (09-19)
- `compact-start-outdoor/start-iphone15promax.png`
- older variants in `start-capsules/`
- `ai-gym/screenshots/followup/followup-start-default.png` and `followup-start-axl.png` (09-22, adds Ask AI)

**What works**
- The large "Workout" title is clear.
- The gym card reads as "where am I" and carries a pin icon tile, the name, "Home / no location",
  a unit pill and a chevron.
- The two start actions are clearly primary.

**Messy**
- **Alignment of the start row.**
  - The two amber capsules together are narrower than the gym card above them. Start Cardio ends
    about 20 pt short of the card's right edge (x≈463 against 485 on a 506-wide image), so the
    right edge is ragged.
  - Each capsule holds a dark circle icon, a label and nothing else. The two have equal weight,
    so nothing suggests which one to tap first.
- **Alignment of the Templates section.**
  - The "Templates" header is indented about 20 pt past the card edge (x=41 against 21).
  - About 50 pt of empty space separates it from the capsules, so the header floats.
- **The New Template tile.**
  - With no templates, the tile is a half-width grey square.
  - Its right half-row is empty, which looks unfinished.
- **Orphan footnote.** "Machines resolve to your last-used at your gym" is a tiny grey line
  hanging under the tile. It is jargon that explains nothing at this point.
- **Three button languages on one screen.** The AI version (`followup-start-default`) adds an
  "Ask AI for Templates" grey pill below the tiles, indented to the header's inset rather than the
  card edge. The screen then has:
  - amber capsules
  - a grey square tile
  - a grey rounded pill
- **Dead space.** The bottom 30–35% of the screen is empty.

**Boring / generic**
- Nothing on the home screen reflects the user: no last workout, no streak or weekly count, no
  week strip, nothing about today's planned session.
- The screen is a menu, not a dashboard.
- Cardio is just a second capsule. Its most recent activity (for example "Outdoor Run 5 km, 2
  days ago") is not shown.

**Missing details**
- The last cardio or lifting session, and this week's volume or minutes.
- Which template is "next" in an AI week (Day 1 / 2 / 3). The home screen does not point to one.
- Gym context: machine count, and when the gym was last visited.

**AXL**
- The capsules stack, but at about 75% of the width instead of full width.
- The unit pill and chevron drop to a second row inside the gym card.
- The footnote slides under the translucent tab bar and shows through the glass as garbled text
  ("Machines resolve to your last-used…" in `redesign-cardio-start-axl.png`).
- `followup-start-axl.png` / `followup-start-top-axl.png`:
  - The large title collapses into an inline title.
  - The gym name hides under the glass nav.
  - "Ask AI for / Templates" wraps, with the second line hanging left of the sparkle icon.
  - The button is clipped by the tab bar.

### A2. Cardio activity picker ("Choose Cardio")
**Captures:**
- `cardio/screenshots/final/cardio-built-picker-default.png` and `…-axl.png` (09-18). These
  predate the 09-19 capsules, so the home screen behind the sheet is the old layout.
- `final/cardio-built-replace-picker-default.png` and `…-axl.png`. This is the "replace
  activity" variant with a banner.

**What works**
- SF Symbols give each activity a figure.
- The sections are clear: "Gym" (Indoor Walk/Run/Cycle, Elliptical, Rowing, Stair Stepper) and
  "Outdoors".
- The search field is a floating glass bar at the bottom.

**Messy**
- **Every row looks the same.** Each row is a grey icon, a white name and a chevron: nine rows of
  identical weight.
- **No recents.** Nothing sets apart the activity the user does most or did last.
- **The replace banner.** "Starting another activity ends the current cardio segment." is a plain
  grey text card. It is a consequence warning, but it has no icon or colour.
- **Search bar overlap.** The floating search bar covers the "Outdoors" header and the first
  outdoor row ("Outdoor Walk" shows through it).
- **Truncated first sheet.** In the first-launch picker, the medium detent cuts the list after
  Elliptical. Outdoor activities are two scrolls away, so an outdoor runner scrolls every time.
- **Chevrons mislead.** A chevron on every row suggests drill-in navigation, but tapping starts
  recording at once.

**Boring**
- A plain `List`. No imagery, no colour per activity type, no hint of which activities record GPS
  or distance and which need manual entry.

**Missing**
- Recent or favourite activities first.
- What each activity will measure (GPS route, distance from sensors, HR).
- Planned cardio from today's template.

**AXL**
- The rows grow well.
- Text is not aligned: names start at slightly different x positions because the icon widths
  vary ("Indoor Walk" at 105, "Indoor Run" at 111, "Indoor Cycle" at 108). This is visible in
  `replace-picker-axl`.
- The replace banner wraps to 3 lines.

### A3. Live cardio: indoor (distance from sensors), measured, automatic
**Captures (newest):** in `cardio/screenshots/units-and-indoor/` (09-20):
- `cardio-built-live-default.png` / `-axl.png`
- `cardio-built-controls-default.png` / `-axl.png`
- `cardio-built-automatic-default.png` / `-axl.png`
- `cardio-built-automatic-distance.png`
- `indoor-measured-default.png` / `-axl.png`
- `indoor-measured-details-default.png` / `-axl.png`
- `unit-cardio-us-default.png` / `-axl.png`

**Layout, top to bottom (Default)**
1. Toolbar: a glass capsule with "⌄ Cancel" (red), the title "Indoor Run ✎", and a "Finish"
   capsule.
2. A row with a "No gym" chip and the workout timer 0:11.
3. A segmented control, Lifting | Cardio.
4. The activity label: a running figure and "Indoor Run" in bold title2.
5. "Time" caption, then a large 0:11 hero.
6. A 2×2 grid: Distance 0.02 mi / Average pace 10:34 /mi / Heart rate 114 bpm (red) / Active
   calories 4 cal.
7. An orphan footnote, "Current pace: 11:08 /mi".
8. Add Exercise (grey), Add by Machine (disabled), full-width Add Cardio, and a "Pick a gym to log
   by machine" caption.
9. A floating control tray: Pause (amber, filled) and End Cardio (grey).

**What works**
- The hero timer is legible.
- Metric labels and units are consistent.
- Controls sit in reach of the thumb.
- Showing the heart-rate number in red gives it meaning.

**Messy**
- **Two timers.** The header shows 0:18 and the hero shows 0:18. When paused they differ (0:30
  against 0:28 in `final/cardio-built-paused-default.png`), with no labels to explain why: one is
  workout time, the other is active segment time.
- **The metrics float.** Unlike the rest of the app, the live metrics sit on the bare background
  with no card. The hero is centred while the grid is left-aligned, so the layout axis switches
  mid-screen.
- **The current pace is buried.** "Current pace: 11:07 /mi" is the most useful live running
  number, but it is a grey footnote under the grid.
- **Lifting buttons in the middle of a run.** Add Exercise, Add by Machine and Add Cardio sit
  between the metrics and the controls. They compete with the recording state, and the disabled
  "Add by Machine" plus its explanatory caption are visual noise during a run.
- **Empty band.** About 90 pt of empty space sits between the caption and the control tray.
- **No recording indicator.** Nothing shows that recording is live: no pulsing dot, no
  "Recording" chip, no animated ring.
- **Indoor without HR.** With no heart rate (`indoor-measured-*`), the grid collapses to 2 cells
  plus the grey line "Waiting for heart-rate data". The screen looks half-empty and static.
- **The segmented control is weak.**
  - Its selected segment is barely lighter grey.
  - It does not show that cardio is recording while the Lifting tab is selected.
  - The only cue is a tiny text row ("Indoor Run … Recording" in
    `final/cardio-built-lifting-banner-default.png`, see A5).
- **Unit mismatch.** In `unit-cardio-us-default` the app is set to U.S. units, but a completed
  Indoor Run card shows "0.04 km" and "6:53 /km" while the live Indoor Cycle shows mi and mi/h.
  This is correct: entered units are preserved (D52). But one screen mixes km and mi with no
  label explaining it.

**Boring**
- The live view is a spreadsheet of five numbers. There is:
  - no progress ring against a target (planned 15 min, or a distance goal)
  - no HR zone colour band (the zone chip exists in source only when max HR is set, and is not
    captured)
  - no pace trend sparkline and no split or lap
  - no motion of any kind
- The run and cycle icons are small grey glyphs. Nothing celebrates distance milestones.

**Missing**
- A target or progress bar when started from a planned cardio (for example 15:00 of 15:00).
- HR zone and a zone-time bar.
- Splits per km/mi and elevation.
- A GPS signal-quality state.
- A clear link from the "Distance" metric to the manual distance editor. In indoor mode the edit
  row appears only when sensors give no distance.
- A lock-screen or Live Activity look. Not captured, so possibly absent.

**AXL**
- The grid becomes one column. Four stacked metrics push Heart rate and Calories under the
  control tray: "Heart rate" is cut off at the tray edge in `cardio-built-live-axl`, and "5 cal"
  peeks out beneath it.
- The toolbar title truncates to "Indoor…".
- The segmented control text does NOT scale ("Lifting / Cardio" stays small), while everything
  around it is huge.
- In `unit-cardio-us-axl`, a completed-segment card ("Indoor Run") collides with the tray.
- Scrolled content shows through the glass nav as ghost text ("Distance 0.03 mi" behind the
  status bar in `cardio-built-controls-axl`).

### A4. Paused
**Captures:**
- `cardio/screenshots/final/cardio-built-paused-default.png` / `-axl.png` (09-18)
- The newer builds have the same structure.

**What works**
- The caption changes to "Paused", and Pause becomes Resume (▶ amber).
- An "Entered distance 0.03 mi ✎" row appears.

**Messy**
- **Paused looks almost identical to running.** Only the 13 pt caption "Time" becomes "Paused".
  The hero keeps full-white weight, and nothing else changes: no dimming, no colour shift, no
  blinking timer, no banner.
- **The header timer keeps running** (0:30 against 0:28), which adds to the two-clock confusion.
- **Heart rate vanishes.** The HR cell disappears when paused, so the grid reflows from 4 cells to
  3 and the layout jumps.
- **The distance row has no container.** "Entered distance 0.03 mi" with a pencil at the far right
  is a loose row, unlike the edit rows on the summary card.

**Boring / missing**
- There is no "paused for 0:12" counter and no "tap to resume" emphasis.
- Paused is a state where the user is standing still, so it could show a mini summary so far.

**AXL**
- Only "Distance" and "Average pace" fit above the tray.
- "Active calories" is cut by the tray, and "Entered distance" peeks out below it (`paused-axl`).

### A5. Controls and the lifting-tab banner
**Captures:**
- `cardio/screenshots/units-and-indoor/cardio-built-controls-*.png` (09-20)
- `final/cardio-built-lifting-banner-default.png` / `-axl.png` (09-18)
- `regression/redesign-02-active-workout*.png` (09-18, for comparing with the lifting-only header)

**What works**
- Pause/Resume and End Cardio stay pinned in an elevated card.
- End Cardio is secondary grey, so it is less likely to be tapped by accident.

**Messy**
- **The tray fights the rest timer.** It sits exactly where the lifting rest-timer bar lives
  (`regression/redesign-02-active-workout.png`: an hourglass circle, "Rest 1:58", +15s, Skip). If
  a rest timer and cardio run at the same time, they compete for the same slot. There is no
  capture of both at once.
- **The End Cardio / Finish / Cancel hierarchy is unclear.**
  - End Cardio ends only the segment. Finish ends the workout. Cancel (red, inside a capsule with
    a ⌄ chevron) discards everything.
  - All three are capsules of similar weight at the top and bottom of the screen.
  - The red "Cancel" beside the minimise chevron in one capsule is an accident waiting to happen.
- **The lifting-tab banner** is a plain row: runner icon, "Indoor Run", and a right-aligned
  "Recording", in grey subheadline with no background. It is easy to miss, and has no live
  elapsed time and no pulse.
- **Lifting-tab layout (`lifting-banner-default`).**
  - A heart-rate card: "♥ 146 bpm", "13 cal", and "Test data · set up zones" in underlined grey
    text.
  - Below it, the add buttons, then about 45% empty screen.
  - With 0 exercises there is no empty state. "0/0 sets" with an empty progress ring is shown
    anyway.

**AXL**
- The tray stacks vertically (Pause above End Cardio) and grows to about 160 pt.
- Header: the "No gym" chip wraps into "No / gym" inside its pill, "0/3 sets" wraps, and the
  title truncates to "Day 1…" (see `ai-planned-cardio-axl`).
- The segmented control stays small.
- The banner row becomes huge with "Recording" pushed to the far edge
  (`lifting-banner-axl`).

### A6. Live outdoor, route map
**Captures:**
- `cardio/screenshots/compact-start-outdoor/cardio-built-outdoor-default.png` / `-axl.png` and
  `cardio-built-outdoor-details-default.png` / `-axl.png` (09-19). **This is the current look.**
- `final/cardio-built-route-default.png` / `-axl.png` (09-18) show a map inline during a live run.
  **Current source (`CardioViews.swift` CardioLiveView) has no map in the live view.** Treat the
  09-18 map-in-live captures as superseded.
- `ui-refinements/cardio-built-ended-outdoor-default.png` / `-axl.png` show a completed segment
  card inside an unfinished workout. The map is hidden by design (`showsRoute: false`), leaving a
  bare "GPS ✎" row.

**What works**
- The same metric grid, now in km with /km pace. The simplified metrics avoid clutter.

**Messy**
- **An outdoor run with no map at all while it is live.** There is no GPS state and no "acquiring
  signal". The screen is indistinguishable from an indoor run apart from the title.
- **The ended-outdoor card.**
  - A bordered card with a 2-column grid, then a bottom row reading only "GPS" with a pencil at
    the far right. It looks like a broken label: GPS what?
  - The pencil edits distance, but the row does not say "Distance".
  - The same row reads "Distance ✎" on indoor cards and "GPS ✎" on outdoor ones. It is a
    provenance caption doubling as an edit button.
- **Map styling in the 09-18 captures.**
  - The map is Apple's standard dark map with green park fills, blue water and street labels.
  - It is visually loud: saturated green, a purple/blue palette, labels crossing the route.
  - The Maps logo and "Legal" overlap the route's corner. "LINCOLN SQUARE" sits under the Maps
    logo.
  - The route is a 4 pt amber line with no start or end markers and no pace colouring.

**Boring / missing**
- A live map with the current position, auto-pause, splits, elevation, GPS accuracy and weather.
- The start and end pins of the route.

**AXL**
- The one-column grid pushes HR under the tray.
- The title truncates to "Outdoo…".
- In the 09-18 `route-axl`, the map is squeezed between the metrics and the add buttons, and the
  tray covers "Add Cardio".

### A7. Finish / workout summary ("Nice work")
**Captures:**
- `cardio/screenshots/final/cardio-built-finish-default.png` / `-axl.png` (09-18)
- `final/cardio-built-manual-finish.png` (lifting + cardio)
- `units-and-indoor/cardio-built-summary-default-1.png`, `-axl-1.png`, `-axl-2.png` (09-20,
  scrolled)
- `compact-start-outdoor/cardio-built-finish-route-default.png` / `-axl.png` (09-19, with route)

**Layout**
1. Sheet with an inline title "Nice work" and a Done capsule.
2. A "Workout saved" card: a large amber ring with a check, and a subtitle such as "1 cardio
   activity".
3. A full-width amber "View in History" button with a history icon.
4. For lifting workouts, a grey "Save as Template" button.
5. "Workout details": stat tiles in a 2-column grid (Workout time, Active calories, Total
   calories, Avg. heart rate, Max heart rate).
6. "Heart rate": a range-bar chart with 3 bars, a 92–153 axis and "124 BPM AVG" in red caps.
7. "Lifting": exercise rows ("Seated Chest Press / 1 set · best 60 lb × 10" in amber).
8. "Cardio": per-segment summary card(s) with the metric grid and a route map.

**What works**
- The success state is explicit.
- The primary next step is clear.
- The HR gradient bars (red to amber) are the only warm "designed" moment in the cardio flow.

**Messy**
- **The celebration is a static checkmark in a card.**
  - The "Nice work" title is tiny and inline, not a headline.
  - The ring is decorative, not a completion ring.
- **Orphan tile.** In the 2-column grid, the 5th tile (Max heart rate) sits alone on the left of
  its row with an empty right half (`finish-default`).
- **Case inconsistency:**
  - "15 CAL" and "124 BPM" are ALL CAPS in the tiles.
  - The same values are lowercase "cal" and "bpm" in the cardio card below.
  - The HR chart footer is caps red "124 BPM AVG".
- **Redundancy.** The average heart rate appears 3 times on one sheet: a tile, the chart footer
  and the cardio card. Calories appear twice.
- **HR chart.**
  - Three fat bars with identical x-axis labels ("11:36 PM / 11:36 PM / 11:36 PM").
  - It reads as a broken chart, not a timeline. The bars float at different heights (min–max
    ranges) without explanation.
  - In the route variant, the chart scrolls under the header and its tallest bar pokes out beside
    the Done button.
- **Awkward wrap.** In `manual-finish` the subtitle wraps as "1 exercise · 1 set · 1 / cardio
  activity", orphaning "1" at the end of line 1.
- **Card widths differ.** The stat tiles span the full inset (x=41–465). The cardio card and HR
  card match, but on the history detail the tiles are wider than the cards (see A8).
- **Buried distance edit.** The same "Distance ✎" / "GPS ✎" edit row appears at the bottom of the
  cardio card in the celebratory sheet.

**Boring**
- No personal-record callouts (longest run, fastest pace), no comparison with last time, no
  streak, no share card, no confetti or animation, no haptic moment in the visuals.
- For a user whose complaint is "boring", this screen is the biggest missed opportunity.

**Missing**
- Pace and HR over time for the cardio segment.
- Splits.
- A comparison against the plan (planned 15 min, actual 5:25).
- Total distance across segments.
- For mixed workouts, time split between lifting and cardio.

**AXL**
- The grid becomes one column of full-width tiles, so the sheet is very long: 5 tiles, then the
  chart, then the cards.
- "Workout / saved" and "1 cardio / activity" wrap in the hero card.
- The View in History button stays readable.
- The route map is pushed far down (`finish-route-axl`).

### A8. Mixed lifting + cardio history (workout detail)
**Captures:**
- `cardio/screenshots/final/cardio-built-mixed-history.png` (09-18, top of the page)
- `units-and-indoor/cardio-built-mixed-history.png` (09-20, scrolled)
- `ui-refinements/cardio-built-mixed-history.png`
- `compact-start-outdoor/cardio-built-history-route-default.png` / `-axl.png` (09-19)

**Layout**
1. Nav with a back chevron, the date "Sep 18, 2026" and a top-right amber **scalemass (weight)
   icon**. Per source this is a menu with the display unit, Save as Template… and Delete
   Workout….
2. A header card: "Name" with "Seated Chest Press +1 ✎"; "No gym" with "39s".
3. A "Lifting" header: white headline weight.
4. The exercise title with "No equipment" and a "Weighted" chip, and a chart button in an amber
   circle.
5. Set rows as separate pills: "① 60 lb × 10".
6. A "Cardio" header: grey section style, **not the same style as "Lifting"**.
7. The cardio card with the metric grid and a map.
8. A 2×2 tile grid: Average 123 BPM, Maximum 151 BPM, Active calories 7 CAL, Total calories
   9 CAL.
9. The Heart rate chart.
10. "Add Exercise…", then the footnote "Recorded as defined today, without equipment."

**What works**
- Everything about the session is on one page.
- The route map is included.

**Messy**
- **Header styles differ.** "Lifting" is a bold white headline, "Cardio" a grey section header.
- **Three container styles:**
  - lifting sets are pill rows
  - cardio is a bordered card
  - HR stats are tiles with a different horizontal inset (tiles x=21–485, cards x=41–465)
- **"Name" row.**
  - "Seated Chest Press +1" is a generated name.
  - It is not a title. The actual title of the page is the date.
  - The duration "39s" floats right with no label.
- **The scalemass icon is misleading.** It hides Save as Template and Delete behind a unit symbol.
- **HR repeated.** "Avg. heart rate 128 bpm" is in the card and "Average 123 BPM" is in the tile,
  with different casing. The capture values differ only because of fixtures, but the duplication
  is structural.
- **Fixture data exposes a real edge case.** "Average pace 0:18 /mi" for a 22-second, 1.25 mi
  entry shows the pace formatting is unguarded against manual distance.
- **Map label clutter.** The Maps logo and "Legal" overlap the route's bottom-left.
- **Tab bar overlap.** The last row ("Entered distance" / "GPS ✎") sits behind the floating tab
  bar.

**Boring**
- A long vertical dump.
- There is no session hero at the top (a big stat line such as "42 min · 3.1 km · 8,200 lb"), no
  timeline showing lifting and cardio in order, and no progress against previous sessions.

**Missing**
- A timeline of when each block happened.
- Per-segment HR.
- The planned-against-actual target from the template.
- The history list row for mixed workouts is not captured in the cardio folders. It is a
  capture gap.

**AXL**
- `history-route-axl` (09-19):
  - The metric grid becomes one column, and the map sits mid-card.
  - The tile titles wrap ("Active / calories", "Total / calories").
  - The bottom tiles collide with the tab bar.
  - The date nav title overlaps scrolled content under the glass.

### A9. Distance editor sheet (cardio)
**Captures:**
- `cardio/screenshots/final/cardio-built-editor-default.png` / `-axl.png` (09-18)

**What works**
- A focused, single-purpose editor: a km|mi segmented control, "Measured: 0.02 mi" as reference,
  and helper text.

**Messy**
- A plain `Form` on the system grey surface, which does not match the navy app.
- The "Distance" field has only a placeholder label.
- The Save capsule is greyed out and reads as missing.
- About 70% of the sheet is empty. A medium detent would suit it better.

**Missing**
- The machine's distance photo (the pattern of scanning a treadmill display fits this app).
- Quick +0.1 / −0.1 buttons.

**AXL**
- Fine. The segmented labels stay small.

### A10. Unit settings (app units, rest defaults, AI entry)
**Captures:**
- `cardio/screenshots/units-and-indoor/unit-settings-us-default.png` / `-axl.png`
- `unit-settings-metric-default.png` / `-axl.png` (09-20)

**Layout**
1. Settings nav with a back button.
2. One card holding six unrelated rows:
   - App unit preference: "U.S. customary ⌃⌄" (amber menu)
   - Working rest · 2:00 (stepper)
   - Warmup rest · 1:00 (stepper)
   - Suppress template update prompts (toggle)
   - Heart rate zones: "Not set"
   - **Ask AI about plates: "Off"**
3. An Export section: "0 workouts · 0 sets", Export CSV and Export JSON as amber icon rows, and a
   footer "This phone holds the only copy until you export."

**What works**
- Compact.
- The export warning is honest.

**Messy**
- **Six unrelated settings in one card:** units, rest timers, prompts, HR, AI.
- **Stale AI label.** "Ask AI about plates" is the entry to the whole Ask AI / OpenAI key sheet
  (A-AI4), which now covers equipment scanning and routines, not plates.
- **Rest values fused into labels.** "Working rest · 2:00" puts the value in the label, so values
  are not right-aligned like "Not set".
- **Status values look like dead text.** "Not set" and "Off" have no chevron, so they do not look
  tappable.
- **Units give no preview.** Changing units shows no example of what changes and does not say
  that existing entries keep their entered units.

**Boring**
- A system form with no grouping headers, icons or colour.

**AXL**
- The value drops below its label ("App unit preference / Metric ⌃⌄").
- "Working rest · / 2:00" wraps mid-token.
- The last row ("Ask AI about plates / Off") sits under the tab bar.

### A11. Cardio states in source with no capture (capture gaps the redesign must still design)
From `WorkoutTracker/Features/Cardio/CardioViews.swift` and `ActiveWorkout/ActiveWorkoutView.swift`:
- The empty cardio tab: `EmptyState("Add cardio to this workout", figure.run)`.
- The HR zone chip with source label, shown when max HR is set.
- A location or permission message (`recorder.locationMessage`) for outdoor runs.
- The "Enter distance" row when sensors give none (indoor).
- A speed-based live layout (Indoor Cycle, "Average speed mi/h", "Current speed"). Captured only
  inside `unit-cardio-us`.
- Planned cardio "Started" state, and disabled "Start" while another segment is live.
- "Some cardio targets are unavailable in this version."
- Search results and the empty-search state in the picker.
- The max-HR sheet (`MaxHeartRateSheet.swift`) and the zone-time card (`Design/ZoneTimeCard.swift`).
- The "Nothing logged" / "Nothing to save" finish variant (`WorkoutFinishedSheet.swift`).

---

## B. AI (Terra / OpenAI)

### B1. Ask AI routine: inputs, goals and cardio (the routine form)
**Captures:**
- `ai-gym/screenshots/ai-routine-goals-default.png` / `-axl.png`, `ai-routine-inputs-*.png` and
  `ai-routine-cardio-*.png` (09-20)
- The equipment section is superseded by the 09-22 follow-up captures:
  - `followup/followup-no-gym-default.png` / `-axl.png`
  - `followup-empty-gym-*.png`
  - `followup-scanned-equipment-*.png`

**Layout, a long `Form` titled "Ask AI" with a Cancel capsule and no top-right action**
1. **Goals.** A multiline goal text field ("Build strength and endurance", 3–6 lines tall), an
   Experience menu (Beginner), a "3 days per week" stepper and a "45 minutes per session" stepper.
2. **Optional profile.** "Height (cm)" and "Weight (kg)".
3. **"Equipment at Routine Gym"** (or "Available equipment"):
   - a Gym picker and "+ Add Gym…"
   - "0 saved machines" / "2 saved machines" as grey text, and "📷 Scan Machine"
   - or, with no gym, "Choose or add a gym to save scanned machines."
   - then 8 equipment toggles (Barbell, plates and rack; Dumbbells; …)
4. **Available cardio.** 9 activity toggles.
5. The consent toggle and paragraph (hidden in captures by the fixture bypass), then **"✨
   Generate week"** as an amber text row at the very bottom.

**What works**
- The inputs are complete.
- Scanning inside the form (09-22) removes a dead end.
- Amber toggles make selections visible.

**Messy**
- **The primary CTA is at the bottom of a ~25-row form, styled as a list row.** It looks like
  every other amber link ("Add Gym…", "Scan Machine"). There is no sticky Generate button.
- **About 20 identical toggle rows:** equipment and cardio are walls of white labels with
  switches. There are no icons, chips or grid.
- **Metric profile fields.** Height (cm) and Weight (kg) are hard-coded in source regardless of
  the U.S./Metric setting.
- **Machine count without the machines.** "2 saved machines" is grey text, not a list, and does
  not look tappable. The user cannot see *which* machines the AI will use.
- **Surface mismatch.** The sheet background is pure black (#000) in routine captures, against
  the app's navy-black. Cards are #1C1C1E, not the app's navy.
- **Section headers wrap** ("Equipment at / Routine Gym" in AXL).

**Boring**
- This should feel like "designing my program with a coach". Instead it reads as a settings
  form.
- There are no preset goal chips (Strength, Hypertrophy, Endurance, Fat loss) and no visual
  schedule (tap the weekdays).
- There is no equipment grid with icons and no "AI" identity (no gradient, no sparkle beyond one
  SF Symbol on the last row).

**Missing**
- A summary of choices before generating.
- An estimate of what gets sent.
- Which weekdays.
- Session length shown as a visual.
- The list of scanned machines with thumbnails or names.

**AXL**
- Labels wrap to 2 lines ("Barbell, plates / and rack").
- Values drop under their labels ("Experience / Beginner").
- "45 minutes / per session".
- The form becomes extremely long. Generate is many screens down.

**Uncaptured states (from `Templates/AIRoutineSheet.swift`)**
- **No key.** A bare Form: "Add your OpenAI API key to create routines with Terra." and an "Open
  AI Settings" button.
- **Busy.** A centred `ProgressView("Building your week…")` and a "Back to preferences" button.
  This is the whole wait state for a multi-second AI call: no animation, no preview skeleton, no
  sense of progress.
- **Error.** Grey text above Generate.
- **Consent block.** A toggle, a paragraph and a link inside the form.

### B2. Week preview ("Your week")
**Captures:**
- `ai-gym/screenshots/ai-week-preview-default.png` / `-axl.png` (09-20)

**Layout**
- Pure-black screen.
- Top bar: a Cancel capsule and a "Save templates" amber text capsule.
- A large title, "Your week".
- One card with three rows, each "Day N — Fitness" over "1 exercise · 1 cardio" with a chevron,
  then a "Change preferences" amber row.

**What works**
- Clear, and the chevrons invite editing.

**Messy**
- **Identical days.** All three days have the same name and summary, so there is no way to tell
  them apart. The real AI may name them differently, but the design has no structure beyond a
  name string.
- **Weak save.** "Save templates" is the key commit, but it is a text-only capsule with the same
  weight as Cancel.
- **Dead space.** About 50% of the screen is empty below the card.

**Boring**
- This is the payoff of the AI flow, and it is a plain list. There is:
  - no weekday strip (Mon–Sun with training and rest days)
  - no muscle-group heat map or icons
  - no estimated duration per day
  - no reveal animation, and nothing that says "your plan is ready"

**Missing**
- Muscle focus per day.
- Total weekly sets and minutes.
- Rest days.
- A cardio minutes total.
- Which gym and equipment the plan assumed.
- The ability to regenerate a single day.

**AXL**
- Scales cleanly. It is still a plain list with a large empty bottom.

### B3. Day edit / day cardio ("Edit session")
**Captures:**
- `ai-gym/screenshots/ai-day-edit-default.png` / `-axl.png` and `ai-day-cardio-default.png` /
  `-axl.png` (09-20). The default captures are identical.

**Layout**
1. Back chevron and an "Edit" capsule. Per source this is `EditButton` for reordering, so it is
   ambiguous next to the title "Edit session".
2. A large title, "Edit session", and a name field "Day 1 — Fitness".
3. **Strength:**
   - Exercise: "Dumbbell Curl ⌃⌄" (amber menu)
   - "3 sets", "10 reps" and "60s rest", each with a −|+ stepper
   - a red "Remove exercise" and an amber "Add exercise"
4. **Cardio:**
   - Activity: "Outdoor Walk ⌃⌄"
   - "15 min" with a stepper
   - a red "Remove cardio" and an amber "Add cardio"

**Messy**
- **Steppers pile up.** Three steppers stack with no row separators. Their pills touch vertically
  and form one tall grey column, so it is hard to see which +/− belongs to which label.
- **Too many red actions.** Red "Remove exercise" inside every exercise block adds a destructive
  action per item. Swipe-to-delete or a trailing icon would suffer less.
- **"Edit" beside "Edit session"** is confusing.
- **Two ways to edit a day.** This day editor uses a different pattern from the template editor
  (B5): single reps against per-set targets, and rest in "60s" against "Rest: 60s". Two editors
  for the same concept look different.

**Boring**
- Plain form controls.
- Not shown: the exercise's muscle icon, the machine or equipment it will use, and the
  estimated session time as items change.

**AXL**
- The exercise picker value drops below the label and indents ("Dumbbell Curl ⌃⌄" at x≈100).
- The Cardio block goes below the fold.
- The nav bar ghosts content behind the glass ("Exercise" visible under "Edit session" in
  `ai-day-cardio-axl`).

### B4. Template detail with AI content (and planned cardio)
**Captures:**
- `ai-gym/screenshots/ai-template-detail-default.png` / `-axl.png` (09-20)

**Layout**
1. Back chevron and an "Edit" capsule.
2. A large title, "Day 1 — Fitness".
3. **A single purple-bicep muscle tile under the title, alone on its row** (orphan).
4. An exercise card: "Dumbbell Curl / 3 sets · 10, 10, 10 reps / Rest: 60s".
5. A "Planned cardio" header, then a card "Outdoor Walk / 15 min".
6. A centred red "🗑 Delete Template…" floating in mid-screen.
7. A floating amber "Start" hero capsule (dark icon disc, "Start / 1 exercise", ↗) above the tab
   bar.

**What works**
- A good hero Start capsule.
- The planned cardio is separated from lifting.

**Messy**
- **Orphan muscle icon.** A 56 pt tile with no label, sitting alone under the title.
- **"Start / 1 exercise" ignores the planned cardio.** The session also has a 15-minute walk.
- **The delete action floats in open space.** It sits about 150 pt above the Start button, and
  there is a large empty gap between.
- **Thin cards.** The exercise card and the cardio card are thin, with no machine, weight or
  last-performance data.
- **Sparse rest line.** "Rest: 60s" is on its own line with no icon.

**Boring**
- A template should preview the session:
  - the muscles worked (body map)
  - estimated duration
  - last time performed
  - progression ("last: 25 lb × 10")
- None of this is shown.

**Missing**
- Estimated time.
- Equipment or machine per exercise.
- Last-session values.
- Which gym the plan was made for.
- The AI provenance (which goals created it, a "Generated by AI" badge).

**Uncaptured states (from `Start/TemplateDetailView.swift`)**
- "Created for another gym. Check equipment before starting."
- "No matching machine at this gym"
- "Some cardio targets are unavailable in this version."
- Superset chips
- The delete confirmation dialog

**AXL**
- **"🗑 Delete Template…" collides with the Start capsule.** They touch or overlap just above the
  tab bar (`ai-template-detail-axl`).
- The muscle tile grows to 160 pt.

### B5. Template editor with AI content ("Edit" sheet)
**Captures:**
- `ai-gym/screenshots/ai-template-editor-default.png` / `-axl.png`
- `ai-template-cardio-editor-default.png` / `-axl.png`
- `ai-template-default-rest-default.png` / `-axl.png` (09-20)

**Layout**
1. A Cancel capsule, the title **"Edit" rendered in amber** (it looks like a button), and a
   "Save" capsule.
2. A Name field.
3. **Exercises card, per exercise:**
   - the bold name with a ⊖ remove button
   - "3 sets" (stepper)
   - "Use exercise rest default" (toggle)
   - "Rest: 60s" (stepper)
   - "Set 1 target · 10 reps", "Set 2 target · 10 reps", "Set 3 target · 10 reps", each with a
     stepper
4. **Cardio targets:**
   - Activity: Outdoor Walk ⌃⌄
   - 15 min (stepper)
   - Distance target (toggle)
   - a red "Remove cardio"
   - "+ Add cardio target"
5. **Add Exercise:** the entire exercise catalog inline as amber ⊕ rows (Abdominal Crunch,
   Assisted Dip, …).

**Messy**
- **A wall of steppers.** Five stacked −|+ pills per exercise touch each other vertically. With 3
  exercises (`default-rest`, Whole Body) that is 15 steppers and 3 toggles in one card, with no
  breathing room.
- **Wasted toggle states.** "Use exercise rest default" ON (amber) hides the Rest stepper; OFF
  shows it. Either way the toggle takes a full row.
- **Redundant per-set rows.** "Set N target · 10 reps" repeats the same values three times.
  There is no "same for all sets" collapse.
- **The inline catalog.** The Add Exercise section lists hundreds of catalog rows in amber, so
  amber is overused.
- **Amber title.** The sheet title "Edit" is amber, unlike every other sheet title (white).

**Boring**
- A form editor for what could be a visual card stack: drag to reorder, set pills to tap and
  edit.

**AXL**
- Each "Set N target · / 10 reps" wraps to 2 lines, so each exercise becomes about 1.5 screens.
- "Use exercise / rest default" wraps.
- The catalog rows become huge amber lines.

### B6. Planned cardio inside an active workout
**Captures:**
- `ai-gym/screenshots/ai-planned-cardio-default.png` / `-axl.png`
- `ai-existing-log-default.png` / `-axl.png` (09-20)

**Layout**
1. Header: "⌄ Cancel" (red), the title "Day 1 — Fitn…" truncated, and "Finish".
2. A "No gym" chip, the timer 0:02, and "0/3 sets" with an empty ring.
3. **The "Planned cardio" section is a full-bleed List row** (edge to edge, unlike every inset
   card on the screen): "Outdoor Walk / 15 min" with a plain white "Start" at the right.
4. An outlined pill: "💔 This device can't measure heart rate".
5. The exercise card:
   - "Dumbbell Curl" with ⋯ and notes icons
   - "Target: 3 sets · 10, 10, 10 reps"
   - a "Dumbbell ›" equipment chip
   - a SET / PREVIOUS / WEIGHT / REPS table
   - rows: set number, "—", a "– lb" field, "–" reps, and a check circle
   - Add Set
6. Add Exercise (amber), Add by Machine (disabled) and Add Cardio.
7. "Pick a gym to log by machine".

In `existing-log`, the exercises get A/B amber circle letters and "Choose equipment ›" chips.

**Messy**
- **The planned-cardio row breaks the card grid.** It is full-bleed and a different shade.
- **"Start" does not look like a button.** It is plain white text, not amber and not a capsule.
- **No progress.** The planned target (15 min) never becomes progress: there is no ring and no
  "0 of 15 min".
- **A permanent HR pill.** "This device can't measure heart rate" is an outlined pill that
  permanently takes a row on devices without HR.
- **Title truncation** hides the day name.

**Missing**
- A combined plan progress: lifting sets done plus cardio minutes against target.
- An upcoming-next indicator.

**AXL**
- "No / gym" and "0/3 / sets" wrap in the header.
- The title truncates to "Day 1…".
- The planned row becomes huge.
- The HR pill wraps with a hanging indent under the icon.
- Exercise header icons drop below the name.
- The set table reflows so WEIGHT and REPS headers sit below the set number.

### B7. Photo consent (Scan Equipment)
**Captures:**
- `ai-gym/screenshots/ai-photo-consent-default.png` / `-axl.png`
- `ai-photo-consent-action-*.png` (09-20; the action variant is identical)

**Layout**
- A sheet with a Cancel capsule and the title "Scan Equipment".
- One card:
  - a bold question, "Send equipment photos to OpenAI?"
  - a 5-line paragraph
  - "OpenAI data policies" as an amber link row
  - "Allow photos and continue" as an amber text row
- The bottom 45% of the sheet is empty.

**Messy**
- **The primary consent action looks the same as the policy link.** Both are amber text rows.
  There is no filled button and no "Not now".
- **Disclosure text is hard to scan.** It is a single paragraph with no icons or bullet points
  (what is sent, what is not saved, who sees it).

**Boring**
- No illustration of the camera, AI and data path.
- Consent could be a friendly, trustworthy card with three icon rows:
  - photo sent
  - not stored
  - billed to your key

**AXL**
- The paragraph runs to 9 lines.
- "Allow photos / and continue" wraps.
- The actions are at the bottom edge.

### B8. Ask AI key settings (overview / permissions / key)
**Captures:**
- `ai-gym/screenshots/ai-key-settings-overview-*.png`, `-permissions-*.png` and `-key-*.png`
  (09-20). The default captures are byte-identical.
- The sheet is reached from Settings → "Ask AI about plates" (A10).

**Layout**
1. An inline title "Ask AI" and a Done capsule.
2. A row: "Ask AI" with "Off" as grey value text (a status, not a toggle).
3. A 5-line footer naming "GPT-5.6 Terra" and describing billing and retention.
4. **Permissions:** 3 toggles (Send equipment photos / routine details / model details to
   OpenAI), all off in the capture, and an amber "OpenAI API data policies" link.
5. **Key:**
   - a SecureField placeholder "OpenAI API key"
   - "Save key" in grey disabled text, which looks like a second placeholder field
   - the footer "Kept in this phone's keychain only. Private trial: use your own OpenAI API key."

**Messy**
- **Status looks like a setting.** The "Ask AI Off" row looks like a setting but is not
  tappable.
- **A disabled Save key looks like another input.**
- **Repetitive toggle labels.** All three start "Send … to OpenAI"; they could be grouped under
  one heading.
- **Key-first order is missing.** The key (the prerequisite) is last, while permissions come
  first.

**Missing**
- A key validity check, "last used" and usage or cost.
- Which features are enabled right now.
- A test-connection action.
- The saved-key state ("Replace the saved key", a red "Remove key") is not captured.

**AXL**
- The toggle labels wrap to 2 lines.
- The footer runs to 9 lines.
- "OpenAI API / data policies" wraps.
- Ghost text shows through the glass nav ("Permissions" behind "Ask AI").

### B9. Scan capture (camera)
**Captures:**
- `ai-gym/screenshots/followup/followup-capture-default.png` / `-axl.png` (09-22). The simulator
  has no camera feed.

**Layout**
- A sheet with a Cancel capsule and the title "Scan Equipment".
- The whole area is dark grey, with one small white viewfinder glyph in the centre.
- Bottom: "Scan a machine or its label", a "📷 Take photo" capsule tinted brown/amber, a disabled
  "⚡ Flash" capsule, and a "Choose a photo instead" amber link.

**Messy**
- **The controls cluster small at the bottom centre.** There is no big shutter button: the
  shutter is a small tinted capsule that reads as secondary.
- **No framing guide** (corner brackets or a label box), even though `LabelFramingBox.swift`
  exists for the label reader.

**Boring**
- No scan animation, no tips carousel (for example "Get the whole machine in frame" or "Include
  the brand plate"), and no AI identity.

**Missing**
- Recent scans.
- How many machines this gym has.
- What happens next: the AI proposal.

**AXL**
- The Take photo and Flash capsules go full width and stack.
- The instruction grows. It stays usable.

**Uncaptured states (from `Gyms/IdentifyEquipmentSheet.swift`)**
- "Identifying equipment…" with a `ProgressView` and a "Take another photo" button. This is the
  whole AI wait state.
- No key: "Add your OpenAI API key to identify equipment with Terra." with "Open AI Settings" and
  "You can also cancel and choose a catalog model manually."
- An error message.
- The "Exercises" chooser sheet (a searchable list with checkmarks).

### B10. AI proposal and identity states (specific / uncertain / ambiguous / new model)
**Captures:** all 09-20 except the follow-up:
- `ai-gym/screenshots/ai-scan-proposal-default.png` / `-axl.png` (generic)
- `followup/followup-proposal-default.png` / `-axl.png` (09-22, generic)
- `ai-identity-specific-*.png`, `ai-identity-action-specific-*.png`
- `ai-identity-uncertain-*.png`, `ai-identity-action-uncertain-*.png`
- `ai-identity-ambiguous-*.png`, `ai-identity-action-ambiguous-*.png`
- `ai-identity-newmodel-*.png`, `ai-identity-action-newmodel-*.png`

**Shared layout ("AI Proposal" sheet, with Cancel)**
1. "Equipment" header, then a card:
   - Name (caption label with the value)
   - Manufacturer and Model (specific, ambiguous and new model only)
   - an unlabeled grey line with the text the AI read off the machine (`visibleText`)
   - an amber "Use generic identity"
2. A grey footer:
   - Generic: "Saved as this gym's machine, with no model claimed."
   - Specific: "Matches catalog: Life Fitness Insignia Series Chest Press"
   - Ambiguous: "Multiple catalog identities match. This will be saved without a model; you can
     choose one later."
   - New model: "Will add new model: Fixture Brand Printed Test Press"
3. "Exercises" header and card: "Seated Chest Press", then "Change exercises ›". The specific
   state has no "Change exercises" row.
4. A separate card with the amber "Use this equipment" button (**left-aligned, about half
   width**), a divider and an amber "Take another photo" text row.
5. Uncertain only: a top card with plain white text, "AI could not identify this equipment. Try a
   clearer angle or choose its exercises below." The Name field is empty (placeholder "Machine
   name") and "Use this equipment" is disabled (muddy brown).

**What works**
- The fields are editable, and all four outcomes are handled.

**Messy**
- **The four states look nearly identical.** The outcome (matched, ambiguous, new, generic) is
  said only in a 13 pt grey footer. There is:
  - no badge or colour
  - no confidence indicator
  - no icon (✓ matched, ⚠ ambiguous, ＋ new, ? uncertain)
- **The name repeats three times.**
  - "Life Fitness" + "Insignia Series Chest Press" in the fields.
  - The unlabeled visible-text line "Life Fitness Insignia Series Chest Press".
  - The footer "Matches catalog: Life Fitness Insignia Series Chest Press".
  - In AXL this fills a whole screen.
- **Ambiguous contradicts itself.** The footer says it "will be saved without a model", but the
  Manufacturer and Model fields above are filled. The candidate matches are not listed, so the
  user cannot choose one.
- **Uncertain is not presented as a warning.** The message is plain body text in a neutral card,
  with no icon or colour, and the empty name is a placeholder.
- **The CTA is half width and left-aligned** inside a card, with the "Take another photo" text
  row below it. It is not a full-width primary button.
- **Inconsistent rows.** "Change exercises" is missing in the specific state but present in all
  others.
- **Dead space.** The generic state leaves the bottom 35–40% of the sheet empty.

**Boring**
- The AI moment ("we recognised your machine!") has no reveal: no scanned-photo thumbnail, no
  catalog product image, no brand logo, no confidence meter, no animation.

**Missing**
- The photo that was scanned.
- The confidence level.
- Candidate list (ambiguous).
- Muscles trained by the suggested exercises.
- Whether the machine already exists at this gym (duplicate warning).

**AXL**
- The specific state puts the CTA 2+ screens down. The first screen is only the Equipment fields
  and the repeated name.
- In the uncertain state, the message runs 4 lines at huge size and the disabled CTA is cut at
  the bottom.
- The ambiguous and new-model action captures show ghosted field text under the glass nav.

### B11. Machine editor with scan (New Machine)
**Captures:**
- `ai-gym/screenshots/followup/followup-machine-editor-default.png` / `-axl.png` (09-22)

**Layout**
1. Cancel, the title "New Machine", and an "Add" amber capsule.
2. An unlabeled name field "Chest press".
3. A card:
   - "Catalog model: None ›"
   - "📷 Scan equipment…" (amber, with icon)
   - "Read label on device" (amber, no icon)
4. "Exercises": Seated Chest Press, then "Choose exercises ›".
5. "Default unit: Gym default ⌃⌄".

**Messy**
- **Misaligned text.** In the scan row the text starts at x≈173 after the camera icon. The next
  row, "Read label on device", has no icon and starts at x≈88.
- **Two similar actions with unclear difference:** "Scan equipment…" (AI) and "Read label on
  device" (on-device OCR). Neither has an explanation.
- **An unlabeled name field** at the top.
- **Wording differs from the proposal.** "Choose exercises" here, "Change exercises" there.
- **Dead space.** The bottom 30% is empty.

**AXL**
- The value drops below "Default unit".
- "Scan equipment…" goes huge amber.

### B12. Scanned equipment inside the routine (gym-scoped)
**Captures:**
- `followup/followup-empty-gym-*.png` and `followup-scanned-equipment-*.png` (09-22); see B1.

The only change after 2 confirmed scans is "0 saved machines" becoming "2 saved machines". Nothing
else acknowledges the scans: no chips of machine names, no thumbnails, no "Chest press ✓ just
added" feedback.

### B13. AI-generated templates on the Workout home
**Captures:**
- `ai-gym/screenshots/followup/ai-immediate-template-1-default.png` and `-axl.png` (plus -2,
  -3), and the `-default-empty.png` variants (09-22)
- `followup/ios27-before-blank-grid.png` (the bug capture from before the fix)

**Layout**
- Gym card: "Template Gym". With no subtitle, the name is top-aligned and the lower half of the
  card is empty.
- The start capsules.
- "Templates" as a 2-column grid of cards. Each card has:
  - a row of 4 small muscle icons (pink chest, teal back, purple bicep, green legs)
  - a bold title
  - a **6-line grey run-on list** ("Dumbbell Curl · Dumbbell Floor Press · Dumbbell Goblet Squat
    · …")
- "New Template…" is half hidden under the tab bar.

**Messy**
- **Unequal card heights.** The Whole Body card starts about 35 pt lower than Day 2, so the grid
  is staggered with misaligned tops.
- **Hard-to-read exercise lists.** Exercise names break mid-name across lines ("Dumbbell /
  Floor Press").
- **Identical AI days.** Three AI days are visually identical: same icons, same names, same
  text.
- **Too many muscle colours.** Four muscle-icon colours per card, times four cards, is 16 small
  coloured tiles, which clashes with the amber accent.
- **No AI badge,** no day order and no "next up" marker.

**AXL**
- `ai-immediate-template-1-axl.png`: very long single-column cards. The template text walls
  dominate.

---

## Cross-cutting findings (both flows)

1. **Amber overuse.** One colour means primary button, link, picker value, toggle-on, route,
   selected tab, icon tint and a sheet title. So the primary action is never visually unique on
   form screens: "Generate week", "Allow photos and continue" and "Use generic identity" all look
   like links.
2. **Two design systems.**
   - Custom screens: navy background, custom cards, hero capsules.
   - System `Form` sheets: #000 or #1C1C1E, grouped rows.
   - Every AI screen and editor is a system form, so the app looks stitched together.
3. **Container inconsistency.** In one history page:
   - pill rows (sets)
   - bordered cards (cardio)
   - tiles with a different inset (HR)
   - full-bleed list rows (planned cardio)
   - outlined pills (HR unavailable)
4. **Grey footnotes carry critical meaning.** The AI identity outcome, the "Waiting for heart-rate
   data" state, "Current pace", the replace-segment warning and the consent disclosure are all
   13 pt grey.
5. **No motion and no celebration.** There is no recording pulse, no scan animation, no AI
   thinking state beyond a system spinner, no finish celebration and no PR badges.
6. **Dead space.** Most sheets leave 30–50% empty at Default: proposal, consent, week preview,
   machine editor, distance editor, template detail.
7. **The AXL failures repeat:**
   - the floating tray and tab bar cover content
   - titles truncate ("Indoor…", "Day 1…")
   - chips wrap inside pills ("No / gym")
   - segmented controls do not scale
   - ghost text shows through the glass nav
   - Start and Delete collide
8. **ALL-CAPS against lowercase units** ("15 CAL", "124 BPM" against "8 cal", "128 bpm").
9. **Labels that no longer match the behaviour:** "Ask AI about plates"; "Edit" as a reorder
   button beside "Edit session"; the scalemass icon hiding Save and Delete; "GPS ✎" hiding
   distance editing.

## Top 10 problems (ranked)

1. **The AI identity outcome is invisible.** Matched, ambiguous, new model and generic look the
   same. The result is a 13 pt grey footer, the name repeats three times, the ambiguous state
   shows filled fields that contradict it, and there is no photo, confidence level or candidate
   list. (B10)
2. **Live cardio is a static spreadsheet with no sense of recording.**
   - Two unlabeled timers (header and hero) that disagree when paused.
   - No recording pulse, and a paused state that differs only by one grey caption.
   - No progress against a planned target, and no map or GPS state for live outdoor runs.
   - (A3, A4, A6)
3. **Every AI flow is a plain system Form with a buried, link-styled primary action.** "Generate
   week" sits ~25 rows down as an amber text row. "Allow photos and continue" looks like the
   policy link. "Save templates" is a text capsule. (B1, B2, B7)
4. **The finish summary wastes the celebration moment.**
   - Tiny inline "Nice work" and a static check.
   - An orphan 5th tile, and average HR repeated 3 times.
   - An HR chart with identical x labels.
   - No PRs, comparison or splits.
   - (A7)
5. **The week preview and template cards give no way to tell sessions apart.** Identical
   "Day N — Fitness" rows, no weekday or rest strip, no muscle or duration summary, and home cards
   with 6-line run-on exercise lists and a staggered, misaligned grid. (B2, B13)
6. **Editors are walls of stacked steppers.** Five touching −|+ pills per exercise, a redundant
   per-set row, a full-row rest toggle, the whole catalog inline in amber, and two different
   editors (day editor and template editor) for the same concept. (B3, B5)
7. **Container and surface inconsistency across one screen.** Pill, card, tile, full-bleed row
   and outlined pill all sit together, alongside navy against #000 against #1C1C1E surfaces and
   mismatched header styles ("Lifting" white bold, "Cardio" grey). (A8, B6, cross-cutting)
8. **AccessibilityL collisions.**
   - The cardio tray covers metrics, and the tab bar covers the last rows.
   - "Delete Template…" collides with Start.
   - "No / gym" wraps inside its chip, the segmented control does not scale, and titles
     truncate.
   - (A3–A8, B4, B6)
9. **The home screen is a menu, not a dashboard.** The start row is misaligned with the gym card,
   the Templates header floats, there is an orphan footnote, an empty half-row and three button
   styles, and no recent activity, streak or next planned session. (A1, B13)
10. **AI scans and settings give no feedback or trust cues.**
    - "2 saved machines" is only a number, and the camera has no framing or tips.
    - The key sheet uses status-as-row ("Ask AI Off") and a disabled "Save key" that looks like a
      field, and has no key validity or usage.
    - The Settings entry is mislabelled "Ask AI about plates".
    - AI wait states are bare spinners ("Building your week…", "Identifying equipment…").
    - (B8, B9, B12, A10)
