# Redesign constraints brief: decisions, test contract, deferred scope, platform

Fact-gathering only. No repo file was edited and nothing was built or run.
Repo `/Users/ericlee06/orca/projects/Health App`, branch `ericlee4992/redesign-visual-proposal`,
HEAD `a0364f2` (clean), read 2026-09-24.

Sources read in full: `docs/SPEC.md`, `docs/DECISIONS.md`, `work-record/ai-gym/spec.md`,
`work-record/deferred-work.md`, `.claude/skills/ios-design/{SKILL,REFERENCE,REVIEW}.md`, and all 20
files in `WorkoutTrackerUITests/`.
Supplementary spot checks: `work-record/cardio/spec.md`, `docs/DEVELOPMENT.md` (verification scope,
simulator pitfalls), `docs/STATE.md` (head), `CONTEXT.md`, milestone-9 ticket 06 (helper copy), ui-redesign
ticket 18, `App/RootView.swift`, `App/WorkoutTrackerApp.swift:85`, and grep results for
animation, Reduce Motion and presentation calls.

---

## 0. Summary

1. **D54 is the theme decision, and the user has now reopened its visual half.** The palette
   (ink + amber `#FFB45E`), dark-only appearance, surfaces, radii, components, icon and Live
   Activity colours can all change. Record the reopening in DECISIONS when the redesign is built.
2. **Some rules inside D54 are product rules, not styling:**
   - "Never words": the copy policy and D52's plain numbers.
   - Every visible string and accessibility identifier the UI tests read must survive.
   - A tile has no long-press menu, because that menu deleted the wrong template.
   - A per-exercise muscle icon was removed at the user's request.
3. **The user's request pulls against the copy policy.** They say some places are "missing
   details". The copy policy forbids explanatory paragraphs, and any new visible string is the
   user's own decision (SKILL.md:19). So new detail should be data, state and visuals (numbers,
   rings, charts, progress, colour), not prose. Show every proposed new string in the mock so the
   user can approve it.
4. **The user has changed the Start Lifting / Start Cardio treatment three times** (D15/D54,
   September 19). The current version is two equal amber icon-disc capsules with no arrows, side
   by side, stacking when a label won't fit. A test checks this layout. Present any change as an
   option. Don't drift into one.
5. **Past taste signals from the user:**
   - Chose Ink/Amber over coral from a side-by-side board (2026-09-10).
   - Rejected SF Symbol muscle icons ("inaccurate and mild").
   - Rejected per-row muscle icons ("they don't match").
   - Rejected a text-only Start restyle.
   - Removed "unnecessary placeholder texts".
   - Original complaint: "boring, mostly texts".
6. **Platform:** iOS 26 is the minimum. The phone now runs **iOS 27.0** on an iPhone 15 Pro Max
   (STATE). Portrait only; Liquid Glass tab bar and toolbars; captures required at Default and
   AccessibilityL; Reduce Motion must be honoured.

---

## 1. Decisions that constrain UI, visuals or interaction

Legend:
- **[VISUAL — reopenable]**: a pure style choice the user may now change.
- **[USER-CHOSEN]**: a composition the user explicitly picked. It can change, but only by
  showing the user options.
- **[KEEP]**: a behavioural or product rule the redesign must preserve.

There is no D55 in DECISIONS: the table jumps from D54 to D56.

### 1.1 Theme and visual system (D54 and its amendments; SPEC §Visual design lines 76–98)

| Item | Current rule | Class |
|---|---|---|
| D54 core | "One visual system, dark only, one warm accent, cards." Tokens live in `Features/Design/Theme.swift` and `Assets.xcassets/Colors` ("Any" appearance only). The window forces `.dark` (`App/WorkoutTrackerApp.swift:85`). | **VISUAL — reopenable** (user: "Feel free to completely change from current theme") |
| Accent | Amber `#FFB45E`, with `OnAccent #15110B` text on it (10.7:1). The user chose Codex's Ink/Amber over Claude's coral from a side-by-side board (2026-09-10). | **VISUAL — reopenable** (precedent: the user chooses between side-by-side boards) |
| Surfaces | Four blue-leaning graphites: `SurfaceBackground #0B0D10`, `SurfaceCard #171B21`, `SurfaceElevated #222831`, `SurfaceFill #2B323C`, and `Hairline` (white 7%). | VISUAL |
| Text | `TextPrimary #F6F3EC`, `TextSecondary #B5B9C2`, `TextTertiary #7F8793`. Tertiary is not allowed for essential text on Elevated or Fill. | VISUAL (contrast rule is KEEP) |
| Semantic colours | `Warmup #E9D875` (yellow, "so it never reads as the accent"), `Danger #FF6B76` (heart rate, failure sets, destruction), `Drop #B8A1EE`, `UnitKg #97C7EE`, `UnitLb #A8CDBF`, `UnitMixed #B8A1EE`, plus zone colours (`ZoneColors.swift`). | Hues are VISUAL. **KEEP** the mapping principle: same colour, same meaning everywhere; warmup must never read as the accent; heart rate is red/danger. |
| Shape tokens | Radius: card 24, inner 16, field 10. Space: 4/8/12/16/24. `hero` = Large Title rounded black (once per screen). `stat` = Title 2 rounded bold. `cardTitle` = Headline bold. `label` = Caption 2 semibold. | VISUAL |
| Components | `.card(.standard/.elevated)`, `Chip`, `UnitChip`, `StatTile`, `ProgressRing`, `EmptyState`, `MuscleIcon`/`MuscleFamilyStrip`, `WrapLayout`, `.primary` (amber, 52 pt) / `.secondary` (fill) button styles. | VISUAL (may be replaced; components live in `Features/Design/`) |
| Native Forms | The editors, the Presets sheet and the Previous Performance sheet are native Forms with the system look. | VISUAL |
| Muscle families | There are 5 families: chest `#FF70B6`, back `#4EB9FF`, shoulders `#4DE0D4`, arms `#B891FF`, legs `#84D65A`. Each is a muscle-map image (neutral body `#5B6472`, family muscle tinted). Core, Neck and Full Body map to none. They appear only on a template's tile and detail. | Colours and art are VISUAL. **USER-CHOSEN:** the user rejected SF Symbols ("inaccurate and mild") and per-exercise row icons ("they don't match"), and picked Codex's image-model maps from a canvas. |
| Template detail caption | "N sets · r, r, r reps" (`TemplateTargets.summary`). The user said "keep it" (2026-09-11). | **KEEP** (string) |
| Progress chart line | Stays monotone, because Catmull-Rom invents extrema. | **KEEP** (honesty: never draw values that don't exist) |
| App icon / Live Activity | Amber dumbbell on ink (`scripts/render-app-icon.py`). The Live Activity uses the same two colours as **literals** in `WorkoutTrackerWidget/WorkoutActivityView.swift`. | VISUAL. A theme change must update both; they don't read Theme tokens. |
| Motion and haptics | "Motion and haptics mark the moments that matter (a set completed, a workout started, the rest timer)." Haptics: `.setComplete`, `.workoutStart`, `.restDone`. | Expanding motion is VISUAL. **KEEP:** motion answers the user, plus the live pulse; Reduce Motion is honoured (§4). |
| "Never words" | "The design adds shape, colour and motion, never words." | **KEEP.** This is the copy policy (§1.3) and is bound to the test strings. |
| Dynamic Type layout | Chips wrap, rows stack at accessibility sizes, tiles scale with their glyphs. AccessibilityL captures are required per screen. | **KEEP** |

### 1.2 Composition choices the user explicitly made

| Decision | Rule | Class |
|---|---|---|
| D15 + D54 (Sept 19, cardio tickets 04/05) | Idle Workout screen: **Start Lifting** and **Start Cardio** are equally prominent amber icon-disc capsules (the running icon is `figure.run`) with **no arrows**, side by side, stacking vertically when full labels can't fit. Resume and template arrows remain. This is "the D54 exception": two equal amber choices. | **USER-CHOSEN** (flipped 3 times). The geometry is tested (§2.2). |
| D54, ticket 17 (2026-09-17) | Finish-summary tile order, in pairs: **workout time / total volume**, **active / total calories**, **average / max HR**. One column at accessibility sizes, same order. Absent metrics omit their tile and the grid compacts. | **USER-CHOSEN** order. Tile styling is VISUAL. |
| D54, ticket 15 | A template tile opens the template detail (exercise list + Start, Edit, Delete). **A tile has no long-press menu**: on the phone it deleted the wrong template. Delete is confirmed, and logged workouts are kept. | **KEEP** (safety). Tested. |
| D54, ticket 11 | An exercise row wears no icon. | **USER-CHOSEN** |
| D58 amendment (Sept 22) | The Workout-tab entry is labelled **"Ask AI for Templates"**. It is a *secondary* row **below** the Templates grid. The existing gym picker, start capsules and template tiles stay dominant. | **USER-CHOSEN.** Label is tested. |
| AI spec, UI composition | Workout: existing content → Templates grid/new tile → secondary Ask AI row. The AI routine is a **full-screen staged flow** (preferences/equipment → Generate → editable sessions → Save templates); Cancel saves nothing. Scanner: camera/photo chooser → consent → progress → editable identity/exercise confirmation → back to New Machine → Add. | **KEEP** (flow and commit boundaries). Styling is VISUAL. |
| Cardio spec, design B | Live cardio, top to bottom: header / Lifting–Cardio focus switch / current activity / **segment timer as hero** / measured metric pairs / one primary **Pause** and a secondary **End Cardio**, pinned within the safe area. **No live map.** At AccessibilityL, metrics and controls stack. | Layout is **USER-CHOSEN** (direction B); the no-live-map rule is **KEEP** |
| Ticket 18 (resolved) | The active-workout header has a small neutral sets ring beside its "N/M sets" count. The ring's fraction must equal the count (full ring when all complete, empty when there are no sets). | **KEEP** (the ring must match the number) |

### 1.3 Copy and strings (SPEC line 73; D52; D54; milestone 9 ticket 06)

- **[KEEP] Copy policy:** no explanatory paragraphs. A screen may carry *one short line* where an
  action has a non-obvious **consequence** (what a delete destroys, what a template omits, "only
  completed sets are kept"). Nothing that merely explains the screen. The user asked for this on
  2026-09-04: "get rid of all those unnecessary placeholder texts".
- **[KEEP] A new visible string is the user's decision** (SKILL.md:18–19; REVIEW.md item 11). Every
  string and identifier the UI tests read stays unchanged (§2), or the change is explicit.
- **[KEEP] D52 plain numbers:**
  - No `≈` on converted weights.
  - No "(estimated)" on zones or maximum heart rate.
  - e1RM reads **"1RM"**.
  - Volume reads like "9740 lb", heart rate like "184 bpm".
  - The zone header is "Time in zones".
  - The heart-rate bar's zone tap is "· edit zones".
  - Provenance stays in the data. Bringing the marks back means reopening D52.
- Consequence lines that reviews re-added (ticket 06 record, 2026-09-04). **Check the exact current
  source text before quoting any of these in a mock**; D57 may have changed the template line,
  since templates now carry rest:
  - "Only its completed sets are kept." (the "Finish It & Start New" dialog)
  - "Saves exercises, sets and target reps — not weights or rest times." (the Save as Template alert)
  - "This phone holds the only copy until you export." (Export)
  - "A completed set locks equipment; a change continues in a new entry." (the equipment sheet,
    after a completed set)
  - "Recorded as defined today, without equipment." (History → Add Exercise)
  - "Logged sets keep the old name." (preset rename)
  - "History keeps the captured name." (model rename)
  - "Only N days logged — read the shape with caution." (a chart with fewer than 4 days)
  - The Previous Performance per-layer notes (three different data sources)
  - Functional hints: "Link at least one exercise this model serves", "Can't find the machine's
    model? Add it", the model-correction choice explanation, and "It was not renamed. Rename it
    from History…"
  - Cardio: "Starting another activity ends the current cardio segment." (tested) and
    "Location unavailable."
  - AI: "Choose or add a gym to save scanned machines." (tested) and "Scan a machine or its
    label" (tested). Permission, error and consequence text in the AI flows is "deliberate and
    required by the new sends".
- **[KEEP] Removed captions must not return:** the "HealthKit estimate" and "Phone motion estimate"
  source captions, the "GPS" row, and the duplicate live distance editor once distance is measured
  (D15, D52; negative-tested, §2.5).

### 1.4 Units display (D9, D25, D29, D40, D52, T7; SPEC §Units)

All **[KEEP]**:
- Weight is stored and displayed **as entered** `(value, unit)`. `normalizedKg` sits alongside and
  is never silently rewritten.
- The **per-set unit chip** toggles kg/lb (`setRow.unit`, whose label is exactly "kg" or "lb").
  The default comes from machine → gym → app preference.
- A **whole-view convert toggle** in History detail: the "As entered" button (tested). Converting
  is the user's own act, and converted values show plain.
- Display uses up to 2 decimals, with trailing zeros trimmed and half-up rounding. (Known deferred
  bug: `Format.weight` rounds to 1 decimal.)
- A workout's unit badge comes from the actual sets: **kg, lb or Mixed** (the `UnitMixed` colour),
  never just the gym default.
- Charts plot normalized values; the tooltip/selection shows the **as-entered** value.
- Never imply that equal displayed weights on different equipment models mean equal resistance.
- Dumbbells are logged per hand and never auto-doubled (D21).
- Bar mode (D39/D40):
  - The weight field takes **plates on one end**.
  - The row shows the running total before logging ("= 135 lb").
  - History shows the total plus the breakdown ("135 lb × 5" and "45 + 45 × 2 = 135 lb").
  - The unit chip is **disabled** while a bar is chosen.
  - Bars are listed as distinct kg and lb bars.
  - Switching to a bar in the other unit clears the plate text.
- App unit system (T7): **Metric (kg/km)** or **U.S. customary (lb/mi)**. New cardio segments
  snapshot it, including pace/speed ("km", "mi", "mi/h"). A running segment keeps its unit after
  the preference changes (tested).
- Distance editor: a km/mi segmented control that **never converts the typed number** (tested).

### 1.5 Tabs, navigation, sheets and presentation

- **[KEEP] Four tabs:**
  - Workout (`figure.strengthtraining.traditional`)
  - History (`clock.arrow.circlepath`)
  - Gyms (`building.2`)
  - Exercises (`list.bullet.rectangle`)

  (`App/RootView.swift:38–52`.) Tests address tabs by label. The tab bar navigates and never acts;
  at most five tabs, filled symbols, one-word labels. The symbols are VISUAL. Labels and count are
  tested.
- **[KEEP] Settings** sits behind the gear (`openSettings`) on the Workout tab (ticket 05). It
  holds unit system, heart-rate zones, AI (key and consents), export and the D51 reclassification
  count.
- **[KEEP] The active workout is a full-screen cover** over the tabs (`RootView` `.fullScreenCover`).
  **Minimise** returns to the tabs, which stay hittable (tested), with a **Resume** affordance on the
  Workout tab. The finish receipt is also presented from RootView.
- **[KEEP] Sheet semantics** (SKILL.md "Sheets…"):
  - A sheet with staged edits: **Cancel + commit verb** (Save/Add).
  - A sheet that applies immediately (presets, deleted machines) or only shows: **Close/Done**.
  - **Back** only in a multi-step flow. Never all three.
  - A prolonged flow is a pushed screen or a full-screen cover.
  - One task per sheet.
- **[KEEP] Presentation types the tests depend on:**
  - Rename workout, Save-as-template name, Delete Template, Delete Machine and "Send model
    details to OpenAI?" are **alerts** (`app.alerts`).
  - `workoutActivityFocus` and `cardioDistanceUnit` are **segmented controls**.
  - The routine and AI settings toggles are **switches** (value "1"/"0").
  - `askAIKeyField` is a **secure field**.
  - The exercise picker, model picker, Exercises tab and cardio picker use a real **search field**.
- **[KEEP] Deletion and recovery:**
  - Machine delete **archives** (D10). A "Deleted machines" list offers Restore.
  - The confirmation is an alert with Cancel. A `confirmationDialog` once showed no Cancel.
  - Workout delete names what it destroys before confirming (D47).
  - The template tile has no long-press menu (ticket 15).

### 1.6 Active workout and recording experience (SPEC §Recording; D2, D7, D13, D19, D26, D48, D57)

All **[KEEP]**:
- Auto-persist every committed change (non-negotiable).
- **Finish finishes on the first tap.** A receipt follows, not a blocking question. An empty
  workout is discarded and the receipt says it "wasn't saved" (tested).
- Cancel leads to a **"Discard Workout"** confirmation.
- At most one active workout. "Finish It & Start New" carries its consequence line.
- **Rows are only created deliberately.** Completing a set never appends the next row: this was
  built and rejected 2026-08-22. **Add Set** carries forward the last completed row's weight, unit,
  reps and bar. A prefilled untouched row logs in **one tap** on the check (the Strong-style
  "speed bar").
- Prefill comes **only from same-machine history** (D11). The fallback layers (this machine →
  same model elsewhere → exercise) are reference display, each labelled, never prefilled (D1). A
  "PREVIOUS" column shows last time's set (`setRow.previous`, e.g. "60 lb × 10").
- Set types: warmup / working / failure / drop. Warmup is yellow; drop sets count toward records
  and **do not start the rest timer** (D26).
- A set is deleted by **swipe** plus a row-menu action. Deleting the last set leaves the exercise
  card usable (tested).
- Equipment freezes once the first set completes (D19). Switching machine or preset after that
  **starts a new entry**, visible as a second card with the same name (tested).
- **Add by Machine:**
  - With no gym the button is visible but **disabled**, with a short reason
    (`addByMachineUnavailable`).
  - A single-exercise machine auto-fills its exercise (D7).
  - A multi-exercise station prompts.
- The equipment sheet offers **"Log as Dumbbell X instead"** (`logAsCounterpart`) rather than the
  bare Dumbbell tag for mapped movements (D51/SPEC). The Barbell tag enables the bar picker.
- **Presets:** every preset is a one-tap **chip on the entry card**, "not buried in a menu"
  (tested). The machine's usual preset is preselected (D38). Changing preset clears stale prefill
  and disables Complete until values are entered.
- Workout name: tapping the title opens a rename **alert**. Naming a running workout is unmarked
  (D50).
- Mid-workout exercise creation: an unmatched search offers "create" with the typed name
  prefilled.
- Supersets (D48) are grouped adjacent entries; rest comes after the last member; an interrupted
  group renders as two runs.
- Template drift (D18): on finish, prompt update template / update values only / both / keep
  original (suppressible).
- D57 templates carry authored rest/reps and cardio targets. Target captions appear only when a
  rest prescription exists: the "Target:" prefix is absent otherwise (tested).

### 1.7 Rest alarm (D13, D22, D26, D43, D46, D48, D57)

All **[KEEP]**:
- Auto-starts on set completion, except drop sets and between superset members.
- Durations are per exercise, split warmup/working; failure uses working. Global defaults are
  2:00 working and 1:00 warmup. Template planned rest sits between the explicit override and the
  global default.
- **Heart-rate rest (D43):** rest ends when HR drops below a user threshold **or** a max-wait cap
  expires (default 4:00), and **the alarm says which**. With no live reading it degrades to the
  standard timer **and says it degraded**.
- **D46:** the beep and notification are scheduled in advance with the system. Any "live" rest UI
  must not imply the app runs code at the deadline.
- The pinned **rest bar** shows a "Rest" label, **Skip**, and +15s (ticket 18 wireframe). It is
  pinned at the bottom while resting. At AccessibilityL, Add Exercise must be able to scroll clear
  above it (tested). The `.restDone` haptic fires on expiry.
- Starting cardio clears an outstanding lifting rest timer or alarm.

### 1.8 Heart rate (D41–D45, D52; SPEC finish summary line 71)

All **[KEEP]**:
- Live bpm (`hrBpm`) with the **source always named** (`hrSource`; the fixture reads "Test data").
  "An unattributed number invites trust the user cannot check."
- The heart pulses only while live and not stale: "a pulsing heart beside a number that stopped
  updating is the app performing liveness it does not have" (`HeartRateBar.swift:62–66`). This is a
  rule for any "live" animation.
- A zone shows **only with a basis** (measured max or birth date). With neither, no zone at all.
- **A gate that hides a feature until configured must ship its own way in.** The zone setup
  (`hrZoneSetup`) is reachable from the running workout **and** from Settings
  (`heartRateZonesSettings`). A new zone appears immediately in the running workout.
- Zones sit at 55/65/75/85/95% of max. Their names are app-specific (not Apple's or Polar's).
  They are unmarked on screen (D52).
- **Rows are omitted, never zeroed,** when no sensor ran. A no-sensor cardio finish must not show
  a "Heart rate" heading (tested).
- **Finish/History HR graph** follows Apple Fitness's shape:
  - One thin floating bar per slot, low→high bpm, at most ~110 bars.
  - **0 = gap, drawn as a hole**, never 0 BPM.
  - The axis is labelled only at the series' low and high.
  - Clock times at the start and the thirds.
  - **Average caption under the plot.**
  - Time in zones under the graph (a zone card). In History it shares the receipt's card.
  - The chart and the numbers come from the same readings, so they never disagree.
- Max HR sheet: a field that previews "Zones would use…", then Save and Cancel.

### 1.9 History freezing and editing (D10, D19, D23, D47, D50, D51)

All **[KEEP]**:
- History renders **snapshots**: exercise name, machine, model, gym, load type and preset as
  captured. A redesign may restyle but must not re-resolve live names.
- **Edits are numbers only** (weight, reps, type), plus `snapshotLoadType` retype and the workout
  name. **Every edit is marked** (`historyEditedMark`). Naming a *running* workout is not marked
  (tested).
- Delete confirms with **"Delete Workout"** and names what is destroyed (sets, exercises, volume).
- **D51 reclassification:** a moved session shows **"Reclassified from …"** in History. Settings
  shows the running count. This is not an edit mark.
- **Calendar:** marked days are finished workouts by **start** day, and only marked days are
  tappable. Tapping one opens that session; its nav title is the date (`.abbreviated`). An empty
  store still opens on this month with nothing marked.
- **Save as Template…** sits in the detail's menu only when the workout has completed sets. The
  confirmation appears in place: "Saved as template “…”".
- Correcting a machine's model prompts: apply to past workouts, or future only (D10).

### 1.10 Records and charts (D8, D14, D17, D20, D21, D36; SPEC §PRs, milestone 9)

All **[KEEP]**:
- Records are the best weight per rep count (capped at 12) plus e1RM (Brzycki, shown as "1RM"),
  computed at machine, model and exercise layers.
- **Assisted is lower-is-better.** Bodyweight+ counts most added weight. Plain bodyweight counts
  most reps. e1RM applies to weighted exercises only.
- Warmups are excluded; drop sets are included.
- Volume = Σ(normalizedKg × reps), weighted exercises only, dumbbells not doubled.
- **Presets split records** (D36). The chart is **per variation** (load type, equipment, preset),
  with a variation picker, and opens on the most-trained variation. From History it opens on
  **that session's** variation.
- **One session renders as a point, never a line.** No data shows an empty state that still offers
  the other variations. The line is monotone, with no invented extrema.
- The chart selection (press-and-drag via an explicit overlay gesture) shows the **as-entered**
  value and unit.
- A record display must respect load-type direction. Any "PR!" celebration must use the same
  direction-aware records math (new PR celebration UI does not exist today; see §3.2).

### 1.11 Cardio (D15 amendments; cardio spec)

All **[KEEP]**:
- One workout can hold lifting and separate cardio segments. **A Lifting / Cardio focus switch
  changes the view and never silently ends recording.** Add Exercise and Add Cardio are both
  available mid-workout.
- The cardio picker offers 9 activities: Indoor Walk, Indoor Run, Indoor Cycle, Elliptical, Rowing,
  Stair Stepper, Outdoor Walk, Outdoor Run, Outdoor Cycle. The picker shows the consequence line
  when a segment is already running.
- Pause/Resume and End Cardio. End Cardio saves the segment and keeps the workout open. The timer
  is **active time**; the header shows whole-workout elapsed time. "Paused" and "Recording" states
  are shown.
- Missing HR, calories, distance or pace are **absent or a dash, never 0**.
- Pace/speed comes from active duration and distance. Cycling shows speed. Current pace appears
  only from fresh movement.
- **Route map only after Finish** (in the Summary and History), never live and not on an ended
  segment while the workout is still open.
- Measured distance hides the edit row and source captions. Indoor with no distance gets a manual
  entry. A saved correction goes through a "Distance" button and shows "Entered distance" and a
  "Measured: …" line.
- A cardio-only finish does **not** offer Save as Template.
- **Planned cardio** from a template needs an explicit **Start** (`startPlannedCardio`). The app
  never auto-starts sensor sessions.

### 1.12 AI consent and recognition flows (D53 superseded by D56; D57, D58; AI spec)

All **[KEEP]**:
- **Consent:** each purpose has an explicit, versioned, revocable local consent: equipment photos,
  routine details, and manual-model text suggestions. "Allow is the only commit action" on a
  consent state. Settings holds the toggles (e.g. "Send equipment photos to OpenAI") and the
  OpenAI key field. The missing-key path must be **reachable** (`routineAISettings`).
- **Recognition:** one photo of a label **or** a whole machine. The AI proposal is **editable**;
  the user confirms with **Use**, which is disabled when the result is uncertain. **Add** on New
  Machine is the persistence boundary.
  - Errors keep manual and retry paths.
  - Rescan drops late responses. No hidden retries.
  - The explicit offline on-device label reader and manual catalog selection stay available.
  - Generic recognition stays **model-less** and gym-local. No invented same-model history.
- **Routine generator:**
  - Goals, experience, days, minutes, optional height/weight, equipment checklist, cardio
    availability.
  - A gym picker (with add), and Scan Machine at any machine count.
  - Generate → 1–7 editable day templates → **Save templates** (atomic).
  - **Cancel saves nothing,** except gym and machine saves the user explicitly made, which persist.
  - Preferences survive scan and cancel.
  - **No weight estimates, no explanations or demonstrations, no calendar, no coaching chatbot.**
  - Duplicate template names are allowed.
- The AI screens reuse existing styles: "No new cards around single explanatory sentences, no
  nested cards or decorative chips, no new typography or motion" (AI design record). A full
  redesign restyles these too, but must keep the flows and commit semantics.

### 1.13 Gyms, machines and exercises (D2, D3, D7, D10, D24, D33–D35, D37, D38)

All **[KEEP]**:
- Gyms and machines are always user-created. There is no gym seeding or directory.
- A machine is **labelled by the movement it serves** (model supplies a default label). The row's
  subtitle is the model display name.
- Gym edits: city (optional) and default unit. Machine edits: unit and usual preset.
- A user-created model can be renamed. Seeded rows cannot, except `loadType` (D24 amendment).
- Model picker (1877 models, 23 manufacturers): search manufacturer + model together, with a
  browse menu (grouping, equipment-type filter) and a visible clear-filters action.
- Exercises tab: search. Long-press context menu with **Presets…** and **Progress…** (tested).
  Presets are user-created with suggested names.

### 1.14 Export (D28–D32)

**[KEEP]** Export is reached from Settings. The summary line reads "0 workouts · 0 sets" (tested).
CSV/JSON go through the system share sheet with the filename `workout-tracker-…`. Export carries no
≈ values.

---

## 2. UI-test contract: identifiers and visible strings

Every item below is queried by a UI test. Changing one means editing that test on purpose (and
REVIEW.md item 11 requires the diff). "id" = accessibility identifier; "str" = visible
label/value.

### 2.0 Cross-cutting test mechanics a redesign can break

- **Rendered-pixel OCR checks** (`AskAIUITests.swift:116–131`): the words must actually be drawn
  inside the element's frame, so these can't become icon-only.
  - "Start Lifting" inside `startEmptyWorkout` (:74)
  - "Start Cardio" inside `startCardio` (:75)
  - "Templates" inside `askAIRoutine` (:77)
  - "Day N" inside each `templateTile.*` (:107)
- **Geometry assertions:**
  - `startEmptyWorkout` and `startCardio` have equal height (±1). At default size they are side by
    side (same midY, lifting left of cardio). At AXL they stack (same minX, lifting above).
    `RedesignScreenshotUITests.swift:44–51`.
  - At AXL, Add Exercise scrolls to sit above the pinned rest bar's "Rest" label (:184–186).
  - The last zone row ("Zone 3") sits above the tab bar at AXL (:435–440).
  - Cardio helpers treat `cardioPauseResume` as a pinned bottom control and require content to
    scroll above it (`CardioUITests.swift:19–27`, `RedesignScreenshotUITests.swift:95–98`).
  - The finish receipt's `summaryExercise` must become fully visible by scrolling (:503–515).
  - `AskAIUITests` `reach()` treats the navigation bar bottom as the top edge and
    `app.frame.maxY − 85` as the bottom edge (tab bar) (:13–24).
- **Element order:**
  - `app.navigationBars.buttons.element(boundBy: 0)` is used as Back or dismiss
    (AskAI:111,175,279; MachineDeletion:62; Redesign:67,450,469; TemplateDetail:64
    `.firstMatch`). **The first nav-bar button must stay Back or Cancel.**
  - On the active workout, `app.buttons["Cancel"].firstMatch` must be the workout's Cancel,
    followed by `app.buttons["Discard Workout"]` (CoreLoop:376–377, 502–503; HeartRate:56–57).
- **Element types:**
  - These must stay **buttons**: `historyWorkoutName`, `workoutTitle`, `calendarDay.*`,
    `setRow.unit`, `setRow.complete`.
  - These must stay **static texts**: `setRow.previous`, `setRow.total`, `exportSummary`,
    `finishedSummary`, `scanReadingText`, `hrSource`, `calendarMonth`.
  - These must stay **text fields**: `setRow.weight`, `setRow.reps`.
  - `setRow.complete` has value "Completed" / "Not completed" and is disabled when inputs are
    empty (Barbell:133, Preset:97).
  - Set weight and reps show "" or "–" when cleared (Barbell:131, Preset:94–96).
- **Swipe targets:**
  - The set row is swiped left from the `setRow.previous` text's trailing edge, 140 pt
    (CoreLoop:394–404). The PREVIOUS area must stay a wide non-interactive region.
  - Machine rows are swiped left (MachineDeletion:30,96).
- **Long-press context menus:**
  - Exercise row → "Presets…" / "Progress…" (Preset:113–114; Chart:193–195)
  - Machine row → "Edit Machine…" (CoreLoop:219–220)
  - Model subtitle row → "Rename Model…" (Scan:146–148)
  - Template tile → **nothing** (TemplateDetail:37–39)
- **Fixture launch flags** (useful sample data for mocks): `-uiTestReset`, `-uiTestHeartRate`,
  `-uiTestHeartRateHistory` (an hour-long HR series), `-uiTestChartHistory` (four weeks of Seated
  Chest Press under several variations), `-uiTestTemplate` ("Whole Body", six exercises covering
  five families plus a superset), `-uiTestScanFixture`, `-uiTestCardioRoute`, `-uiTestIndoorDistance`,
  and `-uiTestTerra` / `…Offline` / `…Slow` / `…Specific` / `…NewModel` / `…Ambiguous` / `…Uncertain`
  / `…NeedsConsent` / `…FullRoutine`. The AXL flag is
  `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityL`.

### 2.1 Tab bar and global

| Query | Type | Asserted | Where |
|---|---|---|---|
| "Workout", "History", "Gyms", "Exercises" | tab bar buttons (str) | exist and navigate; hittable after minimise | CoreLoop:586–588, 491; every file |
| `keyboardDone` | button (keyboard toolbar) | dismisses number pad | Barbell:121; CodexScreenshot:106 |
| navigationBars "Workout", "Settings", "Scan Equipment", "New Machine", "New Model", "Choose Cardio" | nav titles (str) | exist, used to scope Cancel | AskAI:101,164–165,384; Cardio:231; Redesign:76 |
| "Cancel", "Save", "Done", "Edit", "Close" | buttons (str) | sheet and nav commit/dismiss verbs | many (e.g. AskAI:176,273,277,287; Export:46; Preset:128) |

### 2.2 Workout tab (Start)

| id / str | Type | Asserted | Where |
|---|---|---|---|
| `startEmptyWorkout` / draws "Start Lifting" | button | starts lifting; OCR; geometry | AskAI:72–74; Redesign:40–51; CoreLoop:118 |
| `startCardio` / draws "Start Cardio" | button | opens cardio picker; OCR; geometry | AskAI:75; Cardio:91; Redesign:41–51 |
| `gymPicker` | any/button | label contains the gym name or "No gym"; options are buttons labelled with gym names and "No gym" | CoreLoop:549–554; AskAI:90–91,179,202,209 |
| `openSettings` | button (gear) | opens Settings | Export:24; HeartRate:186; Redesign:61,349 |
| `resumeWorkout` | any | appears after minimise; reopens workout | CoreLoop:484–496; Cardio:125; Redesign:77,219 |
| `askAIRoutine` / label **"Ask AI for Templates"** / draws "Templates" | button | exact label | AskAI:77,138 |
| "New Template…" | button (str) | opens template editor | TemplateDetail:25; Redesign:229; CodexScreenshot:88 |
| `templateTile.<name>` (e.g. "Whole Body", "Full Session", "Second", "Day N — Fitness", "Workout … From History") | button | exists exactly once; OCR draws its title; tap opens detail; long-press shows no menu | AskAI:104–109,282–284; TemplateDetail:23,32,37–39; HistoryTemplate:69; Redesign:242,303 |
| str beginning "Machines resolve" | static text | reachable at AXL under the grid | Redesign:279–281 |
| "Core Session" | static text | template name visible after save | CodexScreenshot:95 |

### 2.3 Template detail and template editor

| id / str | Type | Asserted | Where |
|---|---|---|---|
| `startTemplate` | any/button | on detail; starts workout | TemplateDetail:63; HistoryTemplate:72; AskAI:110,291 |
| `editTemplate` | button | opens editor | AskAI:286,303 |
| `deleteTemplate` | button | on detail only | TemplateDetail:40–43,58 |
| alert "Delete Template" with "Delete" / "Cancel" | alert | confirm/cancel | TemplateDetail:44–45,61–62 |
| no "Delete" / "Edit…" after tile long-press | negative | no tile context menu | TemplateDetail:38–39 |
| `templateExercise.<name>` (Seated Chest Press, Belt Squat, Abdominal Crunch) | any | exercise rows in detail | HistoryTemplate:73; Redesign:247,293,308,327 |
| textField "Template name" | text field | editor name; Return dismisses keyboard | TemplateDetail:26; Redesign:232 |
| exercise option buttons by name ("Abdominal Crunch", "Assisted Dip", "Assisted Pull-Up", "Back Extension", "Belt Squat") | buttons | multi-select in editor (lazy list) | TemplateDetail:30; Redesign:238 |
| switch "Use exercise rest default" | switch value "1" | default rest state | AskAI:304–305 |
| "Add cardio target" | button | in editor | AskAI:289 |
| no static text beginning "Target:" | negative | no target caption without prescription | AskAI:310 |

### 2.4 Active workout: lifting

| id / str | Type | Asserted | Where |
|---|---|---|---|
| `finishWorkout` | button | finishes on first tap | CoreLoop:119,571 |
| `minimizeWorkout` | button | returns to tabs | CoreLoop:482; Cardio:124 |
| "Cancel" → "Discard Workout" | buttons (str) | cancel and confirm discard | CoreLoop:376–377; HeartRate:56–57 |
| `workoutTitle` | button | label contains typed name; opens alert (text field + "Save") | WorkoutName:20–27,79–85 |
| `addExercise` | button | opens exercise picker | CoreLoop:419; Redesign:182 |
| `addByMachine` | button | enabled at a gym; **disabled** without one | CoreLoop:123–127,559 |
| `addByMachineUnavailable` | any | short reason shown without gym | CoreLoop:129 |
| `addCardio` | button | opens cardio picker mid-workout | Cardio:119; Redesign:82 |
| `entryEquipment` | any | equipment chip on the entry card | Barbell:161; Dumbbell:37–41 |
| "Barbell" | button (str) | equipment option | Barbell:164 |
| `logAsCounterpart` label contains "Dumbbell Bench Press" | button | offered; **no "Dumbbell" button**; afterwards no "Bench Press" text | Dumbbell:43–46,54–56 |
| `presetChip.<name>` ("Wide grip", "Narrow grip") | any | all presets visible as chips; tap switches | Preset:34–45,91 |
| `barPicker` | button | only for barbell/Smith entries | Barbell:27–36,170 |
| `barOption.olympic-45lb`, `barOption.technique-15lb`, `barOption.womens-15kg` | any | bar list | Barbell:38,116,127 |
| `addSet` | button | appends a carried-forward row | CoreLoop:306; Barbell:76 |
| `setRow.weight` | text field | value "60"/"80"/"45"; "" or "–" when cleared | CoreLoop:42,87; Barbell:49,82,131 |
| `setRow.reps` | text field | value | CoreLoop:47,89 |
| `setRow.unit` | button | label exactly "kg" / "lb"; disabled in bar mode | CoreLoop:52–55,92; Barbell:44–47,129 |
| `setRow.complete` | button | value "Completed" / "Not completed"; disabled when empty | CoreLoop:57–59,97–102; Barbell:92–94,133 |
| `setRow.previous` | static text | label "60 lb × 10"; swipe origin | CoreLoop:80–84,397 |
| `setRow.total` | static text | label "= 135 lb" | Barbell:55–59 |
| `setRow.swipeDelete` | button | revealed by swipe; deletes | CoreLoop:353–365 |
| exercise name as static text ("Seated Chest Press", "Bench Press", "Dumbbell Bench Press", created "Landmine Press NNN") | static text | entry title; ≥2 matches after preset switch | CoreLoop:39,369; Preset:47–52 |
| "Rest" (static) or "Skip" (button) | rest bar | appears after completion | Redesign:144,172,183; CodexScreenshot:47 |
| `workoutActivityFocus` segmented, segment "Lifting" | segmented control | focus switch | Cardio:224–225 |

Exercise picker and creation:

| id / str | Type | Asserted | Where |
|---|---|---|---|
| search field (firstMatch) | search field | typing filters | CoreLoop:420; Barbell:148 |
| `exerciseOption.<name>` | any | row; tapping its text works under keyboard | Barbell:152–155; Dumbbell:27–34 |
| `createExerciseFromSearch` | any | offered when nothing matches | CoreLoop:427–431 |
| `newExerciseName` (prefilled), `saveNewExercise` | text field, button | create and select | CoreLoop:433–438 |

Add by Machine sheet:

| id / str | Type | Asserted | Where |
|---|---|---|---|
| `machineOption.<label>` | any | machine row; tap logs; swipe to delete | CoreLoop:565; MachineDeletion:80,96 |
| `deleteMachine.<label>` → alert button "Delete Machine" | button | delete mid-workout | MachineDeletion:97–101 |
| "No machines yet" | static text | empty sheet | MachineDeletion:103 |

Heart-rate bar and zones:

| id / str | Type | Asserted | Where |
|---|---|---|---|
| `hrBpm` | any | appears; label/value changes | HeartRate:28–41 |
| `hrSource` = "Test data" | static text | source named | HeartRate:51–53 |
| `hrZone` | any | absent without a basis; appears after max set | HeartRate:68–70,168–171 |
| `hrZoneSetup` | button | reachable with no max | HeartRate:148–152 |
| `maxHeartRateField`, "Zones would use" (static), `saveMaxHeartRate`, "Cancel" | sheet | preview then save | HeartRate:157–164,191–194 |

### 2.5 Cardio (picker, live, distance editor, summary card)

| id / str | Type | Asserted | Where |
|---|---|---|---|
| nav "Choose Cardio" + "Cancel" | sheet | picker dismiss | Cardio:231 |
| search field + "Indoor Run" / "Indoor Cycle" | search | filter activities | Redesign:69,85 |
| `cardioActivity.<kind>` (indoorRun, indoorCycle) | any | picks activity | Cardio:47; Redesign:70,86 |
| "Starting another activity ends the current cardio segment." | static text | shown when replacing | Cardio:229 |
| `cardioTimer` | any | live timer exists | Cardio:49; AskAI:294–296 |
| `cardioDistanceMetric` | any | main distance metric | Cardio:165,192 |
| "0.67", "1.00", or `\d+\.\d{2}` | static texts | distance value format (2 decimals) | Cardio:52,166,193 |
| "km", "mi", "mi/h" | static texts | unit labels | Redesign:72,80,88,94 |
| `cardioPauseResume` | button | pinned pause/resume | Cardio:122,127; Redesign:98 |
| "Paused", "Recording" | static texts | states | Cardio:123,126,221,226 |
| `endCardio` | button | ends segment, workout stays open | Cardio:96,172 |
| `cardioEditDistance` | button | **absent** when distance is measured; present for manual indoor | Cardio:55,60,168,196 |
| **absent:** "HealthKit estimate", "Phone motion estimate", "GPS", `cardioRoute` (while live or after End Cardio, before Finish) | negatives | no source captions, no live map | Cardio:56–57,169–174,197 |
| `cardioDistanceField` (placeholder "Distance"), `saveCardioDistance` (disabled until typed) | text field / button | distance editor | Cardio:62–71,142–146 |
| `cardioDistanceUnit` segmented "km" / "mi" | segmented control | switching keeps the typed "5" | Cardio:148–151 |
| str beginning "Measured:" | static text | measured value in editor | Cardio:144 |
| "Entered distance" | static text | after saved correction | Cardio:153 |
| `cardioSummary.<kind>` | any | segment summary card (live-ended, receipt, History) | Cardio:97,106,130,236 |
| `cardioSummaryEditDistance` label "Distance" | button | saved-distance correction | Cardio:98–110,201 |
| `cardioRoute` | any | present on receipt and History after Finish (outdoor) | Cardio:178,181 |
| **absent:** "Heart rate" on a no-sensor finish | negative | HR heading omitted | Cardio:132 |
| **absent:** `saveFinishedAsTemplate` on a cardio-only finish | negative | no empty template offer | Cardio:234 |
| `startPlannedCardio` | button | explicit start of planned cardio; timer absent until tapped | AskAI:292–296 |

### 2.6 Finish receipt

| id / str | Type | Asserted | Where |
|---|---|---|---|
| `finishedDone` (label "Done"; `ExercisePresetUITests` taps `buttons["Done"].firstMatch`) | button | closes receipt → tabs | CoreLoop:574–581; Preset:223 |
| `finishedSummary` contains "wasn't saved" | static text | empty-workout outcome | CoreLoop:133–137 |
| `viewFinishedWorkout` | button | pushes that workout's History detail | CoreLoop:166; Cardio:37 |
| `saveAsTemplate` → textField "Template name" (prefilled "Workout …") → "Save" → static "Saved as template “Workout…”" replaces the button | flow | in-place confirmation | HistoryTemplate:101–110 |
| `summaryVolume`, `summaryTotalCalories`, `summaryAvgHR`, `summaryMaxHR` | any | tiles present with sensor fixture | HeartRateSummary:39–45; HeartRate:113 |
| `summaryExercise` | any | exercise line reachable by scrolling | HeartRate:123–127; Redesign:505 |
| `heartRateChart`, `heartRateAverageCaption` | any | chart plus caption under it | HeartRateSummary:49–53 |

### 2.7 History list, calendar and detail

| id / str | Type | Asserted | Where |
|---|---|---|---|
| `historyWorkoutRow` | any | one per workout; tap opens detail; count 0 after delete | HistoryEditing:26,84; HeartRateSummary:85 |
| row title = exercise performed ("Seated Chest Press") or typed name ("Push A") | static text | title rule (ticket 17 E1) | CoreLoop:67–69; WorkoutName:35 |
| label contains **"1 exercise · 1 set"** | static text | count line, nouns agree | CoreLoop:70–74,107–109 |
| "No workouts yet" | static text | empty History | CoreLoop:142; Redesign:489 |
| `historyCalendar` | button | opens calendar | HistoryCalendar:20 |
| `historyCalendarSheet`, `calendarMonth` | any, static text | sheet and month title | HistoryCalendar:24–26 |
| `calendarDay.yyyy-MM-dd` | **button only when marked**; `any` otherwise | tap opens session; no buttons when empty | HistoryCalendar:35,63–65 |
| `closeCalendar` | button | dismiss | Redesign:366 |
| navigation title = date `.abbreviated` | nav bar | detail title | HistoryCalendar:43–44 |
| `historyWorkoutName` | button | label contains name; opens rename alert | WorkoutName:60–69; HistoryCalendar:41 |
| "As entered" | button | unit convert toggle present | CoreLoop:173 |
| "70 kg × 8", "135 lb × 5", "45 + 45 × 2 = 135 lb" | static texts | set line format and bar breakdown | CoreLoop:176; Barbell:104–107 |
| label contains "Wide grip" | static text | preset in the snapshot equipment line | Preset:64–68 |
| `historySetLine` | any | tap opens edit | HistoryEditing:31–34 |
| `editSetWeight`, `saveEditedSet` | text field, button | edit set | HistoryEditing:36–45 |
| `historyEditedMark` | any | shown after an edit or rename; absent after a live rename | HistoryEditing:50; WorkoutName:38,66 |
| `workoutDetailMenu` → `deleteWorkout` → "Delete Workout" | menu, button | confirmed delete | HistoryEditing:71–80 |
| `workoutDetailMenu` → `saveAsTemplate` → alert (text field "Template name" + "Save") → "Saved as template “… From History”" | flow | save from History | HistoryTemplate:45–64 |
| `historyEntryChart` | button | per-entry chart button | Chart:130–132,158–160 |
| `historyHeartRateSection`, `heartRateChart`, `heartRateAverageCaption` | any | HR section; **absent** with no series | HeartRateSummary:65–69,88–93,119–120 |
| `historyZoneCard`, "Time in zones", "Zone 2", "Zone 3" | any, static | zone card under graph | HeartRateSummary:97–100; Redesign:435 |

### 2.8 Exercises tab, presets and progress chart

| id / str | Type | Asserted | Where |
|---|---|---|---|
| search field | search | filters catalog and user exercises | CoreLoop:466; Chart:186 |
| exercise name static text + long-press → "Presets…", "Progress…" | context menu | entry points | Preset:111–114; Chart:191–197 |
| `noPresets` | any | empty presets | Preset:117 |
| `presetSuggestion.Wide grip` | any | suggestion adds preset | Preset:120 |
| `newPresetName`, `addPreset` | text field, button | typed preset | Preset:121–124 |
| `preset.<name>` | any | listed | Preset:126–127 |
| "Done" | button | closes the immediate-apply sheet | Preset:128 |
| `progressChart` | any | multi-day series | Chart:21–25 |
| `progressEmpty` | any | no-history state | ProgressChart:19–22; Chart:162–164 |
| `progressSinglePoint` (and **no** `progressChart`) | any | one session is a point | ProgressChart:31–38 |
| `chartSelection` | any | label contains as-entered "lb", the value (e.g. "120", "95") and date; changes on press-drag from 35% to 60% of width | Chart:34–58,76–84,101–109 |
| `chartVariationPicker` | any/menu | label contains "Dumbbell" / "Barbell"; options begin "Narrow grip" | Chart:70–95,134–139,165–170 |

### 2.9 Gyms tab, gym detail, machine editor, model picker, scanner

| id / str | Type | Asserted | Where |
|---|---|---|---|
| `addGym` | button | new gym (also shown on empty Gyms) | CoreLoop:511; Redesign:492 |
| `gymName`, `gymUnitPicker` (options "kg"/"lb"), `saveGym` | text field, picker, button | gym editor | CoreLoop:513–521 |
| `gymRow.<name>` | any | list row | CoreLoop:523 |
| `editGym`; textField "City (optional)"; "Seoul" static | button, field | edit gym; city shows | CoreLoop:188–199 |
| `addMachine` | button | on gym detail | CoreLoop:529 |
| `machineRow.<label>` | any | machine row; swipe → `deleteMachine.<label>` | MachineDeletion:28–31 |
| machine label and model subtitle as static texts ("Seated Chest Press" / "Life Fitness Insignia Series Chest Press", "Incline Chest Press", "Chest press", "Press by window") | static texts | movement-named machine plus model line | CoreLoop:215,280; Scan:86,93; AskAI:52,327,353–355 |
| long-press → "Edit Machine…"; long-press model → "Rename Model…" | context menus | edit entry points | CoreLoop:219–220; Scan:146–148 |
| alert "Delete Machine" + "Cancel" | alert | confirm; Cancel changes nothing | MachineDeletion:36–39,50 |
| `deletedMachines` (label contains count "1"), `restoreMachine.<label>`, "Nothing deleted" | any, button, static | archive/restore list | MachineDeletion:53–64 |
| `machineLabel`, `catalogModel` (label contains model), `saveMachine` (disabled without label or model), `machinePresetPicker` (option "Wide grip"), `machineUnitPicker` ("kg"), nav "New Machine" + "Cancel" | editor | machine editor | CoreLoop:203–224; Preset:164–169; AskAI:165 |
| `modelBrowseMenu` → "Equipment Type" → `modelFilter.type.plateLoaded`; `clearModelFilters`; `modelOption.<name>` | menu, buttons | model picker filter and search | CoreLoop:243–271 |
| textFields "Manufacturer", "Model"; `newModelExercise.<…>`; `saveNewModel`; `newModelSuggestExercises`; nav "New Model" | New Model sheet | prefilled from scan; link exercise | Scan:111–132; AskAI:378–384 |
| alert "Send model details to OpenAI?" → "Allow and send" | alert | text-suggestion consent | AskAI:379–380 |
| `scanMachineLabel` (AI) and `scanLabelOffline` (on-device) | buttons | the two scan entry points | AskAI:39; Scan:33 |
| nav "Scan Equipment" + "Cancel"; "Scan a machine or its label" | sheet, static | AI capture | AskAI:153,164 |
| `allowAIPhotos` (and **no** `scanShutter` before consent) | button | photo consent gate | AskAI:225–226,363–368 |
| `scanShutter`, `scanFramingBox` | button, any | capture; nothing is read before the tap | Scan:157–164 |
| `scanUseCandidate` (disabled when Uncertain), `scanRescan`, `scanAIError`, `identifiedMachineLabel`, `dismissEquipmentKeyboard` | AI proposal | editable proposal; errors keep the shutter enabled | AskAI:46,56–66,316–323,345 |
| `scanReadingText` (contains "LIFE FITNESS"), `scanCandidate.<model>`, "Scan again", `scanCreateNew` | offline scan results | candidate list and rescan | Scan:36–56,105 |

### 2.10 AI routine (full-screen flow)

| id / str | Type | Asserted | Where |
|---|---|---|---|
| `routineGoals` | text field or text view | typed goals persist across scan/cancel | AskAI:94,169,238 |
| `dismissRoutineKeyboard` | button | hides keyboard | AskAI:96,254–255 |
| `routineEquipment.dumbbells`, `routineCardio.outdoorWalk` | switches | toggled with value "1"; survive scan/cancel | AskAI:97,219,239–240 |
| `allowAIRoutine` | switch | "0" means Generate disabled | AskAI:241–242 |
| `generateAIRoutine` | button | enabled or disabled per consent | AskAI:98,242,262 |
| `routineGym` → gym-name buttons / "No gym" | picker | remembered selection mirrors Workout's `gymPicker` | AskAI:195–209 |
| `routineAddGym`, `routineScanMachine` (hidden with No gym) | buttons | in-flow gym and scan | AskAI:143–147,204 |
| `routineMachineCount` label "N saved machines" ("0 saved machines", "1…", "2…") | any | exact string | AskAI:148,160,167,198 |
| "Choose or add a gym to save scanned machines." | static text | no-gym line | AskAI:205 |
| `routineAISettings` | button | missing-key route to AI Settings | AskAI:393 |
| `routineDay.<index>` | any | generated day rows; tap opens day editor | AskAI:99,172–173,263 |
| day editor: "Add exercise", "Remove exercise", "Add cardio", nav "Edit" / "Done", handles labelled "Reorder…" | buttons | edit day | AskAI:266–277 |
| `saveAIRoutine` | button | saves once even on double tap | AskAI:100,280–283 |
| nav "Cancel" | button | nothing saved except explicit gym/machine | AskAI:176,199 |
| AI Settings: "Done" (settles near top), switch "Send equipment photos to OpenAI", `askAIKeyField` (secure) | sheet | reachable consent and key | AskAI:393–401 |

### 2.11 Settings and export

| id / str | Type | Asserted | Where |
|---|---|---|---|
| nav "Settings" | nav | back to Workout | Redesign:76 |
| `appUnitPreference` (label contains "Metric" / "U.S. customary"; options are buttons with those titles) | menu/picker | unit system | Redesign:111–123 |
| `heartRateZonesSettings` | button | presents the max-HR sheet | HeartRate:187–193; Redesign:352 |
| `exportSummary` = "0 workouts · 0 sets" | static text | exact format | Export:26–32 |
| `exportCSV` | button | presents share sheet (filename beginning "workout-tracker-") | Export:34–43 |
| `exportFailure` | static text | **absent** after success | Export:53–55 |

### 2.12 Screenshot capture names (the review record)

These are not assertions, but the ios-design skill treats them as the record. Default and AXL pairs
exist in `RedesignScreenshotUITests`:
- `redesign-01-root`
- `02-active-workout(-axl…)`
- `03-finish-summary(-axl, -scroll-N)`
- `04-start`, `04-start-templates`, `04-start-axl(-2)`, `04-start-live-axl`,
  `04-template-detail(-axl)(-fixture)`
- `05-settings`, `05-history(-axl)`, `05-calendar`, `05-detail(-axl)`,
  `05-detail-heart-rate(-zones)(-axl)`, `05-chart`
- `06-gym-detail(-axl)`, `06-gyms(-axl)`
- `07-exercises(-axl)`
- `08-empty-history`, `08-empty-gyms`
- `redesign-cardio-start-{default,axl}`, `unit-settings-*`, `unit-cardio-us-*`

`AskAIUITests` (`ai-*`, `followup-*`) and `CardioUITests` (`cardio-built-*`, `indoor-measured-*`)
have their own pairs. Per REFERENCE.md "Captures", these screens are **default-only** today: Settings,
calendar, chart, the pickers and sheets. The redesign must add their AXL pairs ("Touching a screen
means completing its pair").

---

## 3. Deferred scope: do not add silently, versus ideas the docs already considered

### 3.1 Do NOT add without a new user decision (and a reopened decision where named)

| Idea a "more engaging" redesign might reach for | Status and source |
|---|---|
| Apple Watch app UI or a watch-first flow | The watchOS companion is a **sketch, never run** (SPEC milestone 7). Revisit D41 only with evidence (deferred-work "Watch experiment"). |
| Accounts, sign-in, cloud profile, social feed, sharing, leaderboards, friends | **No backend or accounts** (SPEC Technical direction; D5, D41). Public backend, billing and StoreKit are deferred (AI spec §Deferred). |
| iCloud sync status or UI | Post-v1 (DECISIONS Deferred). v1 ships single-device; export is the backup story. |
| Import/restore from JSON; Strong import | JSON restore deferred; **Strong import dropped (D49)**. |
| AI coach, chatbot, adaptive plans, calendar scheduling, AI starting weights, exercise explanations, form videos, visual guides or demonstrations | Excluded by **D58** and the AI spec (twice). |
| Keeping machine photos (a gallery of your gym's machines) | Photos are never retained (**D34/D56**, AI spec §Deferred). |
| Plate-loading calculator ("load these plates"), selectorized stack increments | Milestone 6 remainder, **deferred** (SPEC milestone 6; deferred-work). |
| RPE, duration sets beyond the cardio design | Post-v1 (DECISIONS Deferred). |
| Reordering within a superset group; showing superset grouping in History | Deferred (Supersets ticket in deferred-work). |
| Live route map during cardio | Explicitly removed (D15 amendment; negative-tested). |
| Light mode or a theme switch | D54 records dark-only as a deliberate exception. The user's "change the theme" permits proposing it, but it must be recorded as reopening D54. Test surface doubles. |
| ≈ or "(estimated)" marks, or confidence badges | Needs D52 reopened. |
| Auto-appending the next set row on completion | Built and **rejected** in use (SPEC line 69; `work-record/next-set-autofill/`). |
| Long-press menu on template tiles | Removed for safety (ticket 15; negative-tested). |
| Muscle icon per exercise row; SF-symbol muscle icons | Rejected by the user (D54 tickets 11/12). |
| Onboarding, tutorials, coach marks, explanatory empty-state prose, tips | Copy policy (SPEC line 73; milestone 9 ticket 06). |
| Notification permission prompt at launch | The open decision is "on first completed set, not launch" (DECISIONS Deferred). |
| Gym directory, map or location search | Gyms are always user-created (D3). |
| Streaks, badges, gamified achievements, estimated "calories burned" from lifting | Not in any spec. Adding them is a new product decision. Any record or PR celebration must reuse direction-aware records math (D14/D20) and must never zero or fabricate HR or calorie numbers (D44). |
| Ducking audio for queued alarms | Deliberately absent (deferred-work footer). |
| App Store work, privacy policy | Deferred; "No new feature, public backend or App Store work is requested" (STATE). |

### 3.2 UI ideas the docs already considered or endorse (safe to build on)

- **Reference apps (SKILL.md, from memory):**
  - Apple Fitness Summary: rings, big numbers with small labels, cards only for groups.
  - Hevy: a "Start Empty Workout" hero over routine cards that list their exercises in one line; a
    compact set table under an exercise header.
  - Strong: one big Start over template cards.
  - The lesson drawn: "one hero per screen, numbers big and labels small, lists for lists."
- **Progress rings** (`ProgressRing`): the sets-completion ring in the active header (ticket 18) and
  finish-summary tiles.
- **Muscle-family body maps** on templates (tile + detail), with the family colour strip.
- **Apple-Fitness-shaped HR graph** and **time-in-zones card**, zone colours (`ZoneColors.swift`,
  `ZoneTimeCard.swift`).
- **Live pulse** on heart rate (only while fresh) and a "breathing" live indicator on the Resume
  capsule (`StartWorkoutView.swift:348–349`, gated by Reduce Motion).
- **Haptics:** `.setComplete`, `.workoutStart`, `.restDone`. A spring on set completion
  (`ExerciseEntryCard.swift:626–627`) and a press-scale on buttons (`ButtonStyles.swift:15–16`).
- **Lock-screen Live Activity** (milestone 8; `WorkoutTrackerWidget`).
- **History calendar** with marked days; the chart per variation with a picker; the chart button
  per History entry.
- **EmptyState** illustrations with one action ("Empty is an invitation").
- **Design exploration process precedent:**
  - Side-by-side boards of competing directions built to one brief (Codex vs Claude, 2026-09-10).
  - "Three that differ in structure, not colour" when the user is choosing (SKILL.md step 2).
  - Phone-sized artboards in a design canvas, or `#Preview` screenshots (step 3).
  - Tools and records live in `work-record/ui-redesign/` (`canvas/`, `icons/brief.md`,
    `codex-design-brief.md`, `screenshots/`, `export-shots.py`).
- Pinned bottom controls (rest bar, cardio Pause / End) using `safeAreaInset` with a fade.
- Optional iOS 26 platform idea (**not** in the docs): `tabViewBottomAccessory` / tab-bar minimise
  on scroll, mentioned only generically in REFERENCE.md ("may minimise on scroll with an
  accessory"). Not currently used (grep found no `tabViewBottomAccessory` or
  `tabBarMinimizeBehavior`). It could host a live-workout "now playing" style resume. It would be a
  new composition needing the user's pick, and the `resumeWorkout` identifier must survive.

---

## 4. Platform facts

- **iOS 26.0 minimum** (D42; `HKWorkoutSession`/`HKLiveWorkoutBuilder` on iPhone require it).
  **The user's phone is an iPhone 15 Pro Max on iOS 27.0 (24A437)** (STATE "Last verified
  installation"). Match the simulator runtime to the phone for UI work: an iOS 27-only blank
  first-template-row bug came from a nested lazy grid, and eager rows replaced it (STATE;
  DEVELOPMENT "Simulator and UI-test pitfalls"). A `WT-iPhone27` simulator exists for this.
- **iPhone, portrait only.** Swift 5 / SwiftUI, no third-party runtime dependencies. New files go
  under the existing filesystem-synced folders.
- **Liquid Glass (iOS 26):**
  - The tab bar and toolbars float on glass above content. **Do not paint a solid bar under
    them**; respect the safe area (REFERENCE.md Layout).
  - The tab bar may minimise on scroll with an accessory.
  - Apple asks for light and dark variants of custom colours for glass adaptivity. **D54 is the
    recorded exception** (Any appearance only, forced `.dark`).
  - Root tint is set with `.tint(Theme.accent)` (`RootView.swift`).
  - A `Menu` label inherits the accent tint unless set explicitly (DEVELOPMENT).
- **Dynamic Type:**
  - The project gate is **AccessibilityL (AX1)**, the first accessibility size, not AX5. Every
    changed screen needs **Default + AccessibilityL captures with the same fixture and state**.
  - Rows stack trailing accessories, chips wrap (`WrapLayout`), tiles and icons scale
    (`@ScaledMetric` matched to a text style), the hierarchy order is kept, and **nothing the user
    needs truncates**.
  - Text styles only: no `.system(size:)` (REVIEW item 5). No Light, Thin or Ultralight weights.
    SF, with Rounded where tokens use it. At most one `hero` (Black) per screen.
- **Reduce Motion:**
  - "Under Reduce Motion each animation is suppressed or replaced by a crossfade — reading the
    setting is not honouring it". REVIEW item 10: follow `accessibilityReduceMotion` to the
    modifier it gates.
  - Currently gated: button press scale (`ButtonStyles.swift:15`), `ProgressRing` (:18), the
    set-complete spring (`ExerciseEntryCard.swift:627`), and the Resume breathing
    (`StartWorkoutView.swift:348–349`).
  - **Not explicitly gated:** the heart `symbolEffect(.pulse)` (`HeartRateBar.swift:66`; system
    symbol effects may self-adapt, so verify) and the swipe `withAnimation(.snappy)`
    (`ExerciseEntryCard.swift:601`). Any new motion in the redesign needs an explicit Reduce
    Motion path.
  - **Motion answers the user** (set completed, workout started, rest finished), plus the "live"
    pulse only. Nothing decorative loops.
- **Use context:** one-handed, mid-set, under gym lighting, glancing for about 2 seconds. Every
  screen's job is a glance or a tap (SKILL brief).
- **Hit targets and prominence:**
  - Minimum 44 × 44 pt; `.primary` is 52 pt tall.
  - At most 2 prominent (accent-filled) buttons per view. Equal options get equal size. The primary
    role never destroys.
  - Collapsed pickers (`Menu`) show value + disclosure and never wear the primary style.
- **Contrast:** 4.5:1 minimum, 7:1 target for small text. Measure every new pair; the REFERENCE.md
  table covers only current tokens.
- **Rules from the ios-design skill** (they apply to any new visual language unless the user reopens
  them):
  - One dominant treatment per screen state. State amber (selected tab or chip, completed set)
    doesn't count.
  - Cards group; no card around a single line; no card in a card.
  - More than 3 like items make a list.
  - Numbers big, labels small.
  - The tab bar never acts.
  - Tells to answer: the same container on everything, a chip where a caption would do, all-caps
    labels everywhere, the accent everywhere, equal-weight stacked blocks, a "phone-sized website",
    a half-empty first viewport, a picker dressed as primary, a layout that only survives the
    default size.
- **Rendering pitfalls** (DEVELOPMENT):
  - A sheet attached to a List `Section` silently never presents; attach it to a row or a stable
    ancestor.
  - A pushed screen needs its own presentation flow.
  - Pinned `safeAreaInset` controls may need a background fade.
  - A quantitative-x `BarMark` once drew nothing.
  - `chartXSelection` inside a List lost to scrolling, so an overlay gesture is used.
  - Local-HTTP canvas artboards rendered blank; use plain board HTML with inlined data-URI masks.
- **Process and verification:**
  - ios-design steps: job/state sentence → ASCII wireframe → **mock before code when structure
    changes** (send to the user) → tells → build → Default/AXL capture → cross-review to "clear".
  - Codex reviews if Claude builds (T6).
  - A whole-app redesign is "shared navigation / broad refactoring" under T8, so escalating to
    the **full UI suite** is justified (DEVELOPMENT "When to run the full UI suite").
  - Any theme change must also update `WorkoutTrackerWidget` (literal colours) and the icon
    script.

---

## 5. Screens, sheets and states that must appear in a complete redesign

Built from the docs, the tests and the feature folders under `WorkoutTracker/Features/`. The number
in brackets is the file's count of `.sheet`/`.fullScreenCover`/`.alert`/`.confirmationDialog`/
`navigationDestination` calls.

- **Workout tab (Start):**
  - States: idle with no gym / idle with a gym / live (Resume capsule) / with templates / no
    templates.
  - Gym picker menu; Start Lifting / Start Cardio capsules; Templates grid + New Template tile;
    Ask AI for Templates row; "Machines resolve…" line; gear → Settings.
  - "Finish It & Start New" dialog.
  - `StartWorkoutView` [4], `WorkoutStartFlow` [1].
- **Template detail** (Start / Edit / Delete + confirm) [2], **template editor sheet** (name,
  exercises, targets, rest default, cardio targets), **template drift dialog**.
- **Active workout** (full-screen cover) [10]:
  - Header: Cancel / title (rename alert) / Finish; gym; elapsed time; sets ring + N/M; heart-rate
    bar (bpm, source, zone, zone setup, stale state); calories.
  - Lifting/Cardio focus.
  - Entry cards [2]: title, equipment chip, preset chips, bar picker, set table (type marker,
    PREVIOUS, weight, reps, unit chip, total, complete), swipe delete, Add Set, entry menu.
  - Superset grouping.
  - Add Exercise / Add by Machine (enabled and disabled) / Add Cardio.
  - **Pinned rest bar:** countdown, +15s, Skip, HR-rest variant, degraded note.
  - Minimise.
  - Sheets: exercise picker (search, create) [1], New Exercise [1], Add by Machine [3] (swipe
    delete, "No machines yet"), machine picker [1], equipment sheet (tags, counterpart, frozen
    consequence line), **Bar picker**, **Exercise rest settings**, **Max heart rate** sheet,
    **Previous Performance** sheet (three labelled layers).
  - Planned-cardio row with Start.
- **Cardio** (`CardioViews` [2]):
  - Activity picker (9 activities, replace consequence line).
  - Live view: timer hero, metric pairs, Paused/Recording, pinned Pause + End Cardio, location
    unavailable state, manual distance entry.
  - Distance editor (km/mi segmented, Measured line).
  - Ended-segment summary card.
- **Finish receipt** (`WorkoutFinishedSheet`):
  - Saved and "wasn't saved" states.
  - Tiles (time/volume, active/total cal, avg/max HR).
  - Zones, HR graph, cardio segments + route, exercises and best sets.
  - View in History; Save as Template (alert → in-place confirmation); Done.
- **History** [3]: list (rows titled by name or exercise, "N exercises · N sets", unit badge
  kg/lb/Mixed), **empty state**, **calendar sheet** (marked and unmarked days, empty month).
- **Workout detail** [8]:
  - Name row (rename alert); edited mark; "Reclassified from…"; As entered / convert toggle.
  - Entries with snapshot equipment/preset lines; set lines with bar breakdown; tap → **Edit
    logged set** sheet; per-entry chart button; retype load type.
  - HR section + zones card; cardio summaries + route.
  - Menu: Save as Template…, Delete (confirmation naming what is destroyed); Add Exercise
    (History).
- **Progress chart** (`ExerciseProgressView`): series, selection row, variation picker, single
  point, empty, sparse caveat, and a metric picker with "Best set" / "Volume" / "1RM"
  (`ExerciseProgressView.swift:40–45,88`).
- **Gyms** [12]:
  - List + empty state; New/Edit Gym sheet (name, city, unit).
  - Gym detail: machine rows (movement label + model), swipe delete + alert, Deleted machines list
    (Restore, "Nothing deleted"), long-press Edit Machine / Rename Model.
  - Machine editor (label, catalog model, unit, usual preset, Scan buttons).
  - **Model picker** (search, browse/grouping/filter menu, clear filters).
  - **New Model** sheet (manufacturer, model, exercise links, Suggest with AI + consent alert).
  - **Model correction** sheet (past vs future).
- **Scanner:**
  - AI `IdentifyEquipmentSheet` [2]: consent, camera/photo chooser, progress, proposal (Specific /
    NewModel / Ambiguous / Uncertain), error, rescan.
  - Offline `ScanMachineLabelSheet` [1]: viewfinder + framing box, shutter, reading text,
    candidates, Scan again, create new.
- **Exercises** [5]: searchable list (grouping/filter menu), context menu (Presets…, Progress…,
  load type), **Presets** sheet [1] (suggestions, add, rename, empty), **Edit load type** sheet,
  **New Exercise** [1].
- **AI routine** (`AIRoutineSheet` [3], full screen):
  - Goals/experience/days/minutes/profile.
  - Gym picker/add, machine count, Scan Machine, equipment checklist, cardio availability, consent
    switch, AI settings link.
  - Generating and error states; week preview (day rows).
  - Day editor (add/remove/reorder exercises, add cardio); Save templates / Cancel.
- **Settings** [AppSettingsSection 2, ExportSection 1]. All in one untitled section of
  `AppSettingsSection.swift`:
  - "App unit preference" picker.
  - Working and "Warmup rest · m:ss" steppers (15 s steps).
  - Toggle "Suppress template update prompts".
  - "Heart rate zones" row → max-HR sheet.
  - An AI row still labelled **"Ask AI about plates"** with On/Off, opening the AI settings sheet
    (key, three consents, Done). This is a stale label from D53: the flow now covers
    photos/routines. It is a copy decision for the user, not a silent rename.
  - "History update" line ("N sets moved to dumbbell exercises · date", D51).
  - Then Export (summary, CSV, JSON, share sheet, failure line).
- **Outside the app screens:** Live Activity (lock screen / Dynamic Island) in `WorkoutTrackerWidget`,
  the app icon, and the rest-end local notification copy (D43: "recovered" versus "time is up").
