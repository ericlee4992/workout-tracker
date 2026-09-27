# Inventory: live lifting workout and live cardio

Scope: `WorkoutTracker/Features/ActiveWorkout/*` (12 files) and `WorkoutTracker/Features/Cardio/CardioViews.swift`.
I also read the shared components and domain strings these screens render: `Features/Design/*`,
`Templates/TemplateDriftDialog.swift`, `Templates/SaveAsTemplateFlow.swift`, `Gyms/MachineDeletion.swift`,
`History/HeartRateSummarySection.swift`, `App/RootView.swift`, and the Domain label enums.
Repository HEAD was `a0364f2` on branch `ericlee4992/redesign-visual-proposal` with a clean tree. This is a read-only survey.
Line numbers refer to that HEAD.

Conventions:
- **Strings** are quoted verbatim. `{x}` marks an interpolated value.
- **ID** means an `accessibilityIdentifier`.
- **[J]** marks my UX judgement, as opposed to a fact read from the code.

---

## 0. Current visual system and constraints

**Design tokens.** Defined in `Design/Theme.swift` and `Assets.xcassets/Colors`. There is one "Any" appearance only, and `WorkoutTrackerApp.swift:85` forces `.preferredColorScheme(.dark)`.

| Token | Hex | Used for |
|---|---|---|
| accent (AccentColor) | #FFB45E amber | primary buttons, completed set circle, chips selected, rest ring, superset chip, total caption, HR zone 4 |
| onAccent | #15110B | text on amber |
| background | #0B0D10 | screen bg |
| card | #171B21 | `.card()` |
| elevated | #222831 | `.card(.elevated)` — rest bar, cardio controls |
| fill | #2B323C | input fields, machine/bar row pills, secondary buttons |
| hairline | #FFFFFF @7% | card border 1pt |
| text / secondary / tertiary | #F6F3EC / #B5B9C2 / #7F8793 | |
| danger | #FF6B76 | failure marker, HR number, swipe delete |
| warmup | #E9D875 | `W` marker |
| drop | #B8A1EE | `D` marker |
| unitKg / unitLb | #97C7EE / #A8CDBF | kg/lb chips |
| HR zones (`ZoneColors.swift`) | warm=tertiary, Z1 #8ABCE5, Z2 #80CABE, Z3 #A5CF9A, Z4 accent, Z5 danger | |
| calorieTint (hard-coded in `WorkoutFinishedSheet.swift:258`) | #F4939C | calorie tiles |

- **Radii:** card 24, inner 16, field 10.
- **Spacing:** 4, 8, 12, 16 and 24.
- **Fonts:**
  - `hero`: largeTitle, rounded, black
  - `stat`: title2, rounded, bold
  - `cardTitle`: headline, bold
  - `label`: caption2, semibold
- **Buttons (`ButtonStyles.swift`):**
  - `.primary`: amber fill, min height 52, radius 16, bold subheadline. It scales to 0.97 on press unless Reduce Motion is on.
  - `.secondary`: fill #2B323C, min height 44, radius 16. It has no press scale.
- **Other components:**
  - `Chip`: a caption-semibold capsule with a tint at 12% opacity. When selected it is an amber fill.
  - `ProgressRing`: a trimmed circle that animates with linear 0.5 s unless Reduce Motion is on.
  - `StatTile`: symbol and label on one line, with a stat value below, inside a card.
  - `EmptyState`: a 128 pt ring with a 96 pt disc, an SF Symbol and a sparkle, plus a title.
- **Haptics (`Haptics.swift`):**
  - `.setComplete` = impact medium 0.8
  - `.restDone` = `.success`
  - `.workoutStart` = impact heavy 0.8 (used outside this scope)

**Locked decisions the redesign would reopen.** These are in `docs/DECISIONS.md`. Per AGENTS.md, a change must reopen them explicitly.
- **D54**, "One visual system, dark only, one warm accent, cards". It also says the redesign adds "shape, colour and motion — **never words**", and that every visible string and accessibility ID read by UI tests is kept.
- **D52:** plain numbers, with no "≈" and no "(estimated)".
- **D44:** HR tiles are omitted, never zeroed.
- **D19/D36:** a completed set freezes the equipment and preset, and a later change splits the entry.
- **D48:** no rest between superset members.
- **D26:** a drop set starts no rest.

**UI-test coupling.** Counts are the number of files in `WorkoutTrackerUITests` that quote each ID.
- **Heaviest:** `setRow.weight`/`setRow.reps`/`setRow.complete` (13 each), `addExercise` (12), `finishWorkout` (12), `finishedDone` (11), `exerciseOption.*` (10).
- **Moderate:** `addByMachine` and `machineOption.*` (5), `addSet` (4), `minimizeWorkout`, `entryEquipment`, `viewFinishedWorkout` and `cardioTimer` (3).
- **Unused by UI tests** (0 files):
  - `workoutNameField`, `saveWorkoutName`
  - `supersetBadge`, `supersetWithNext`, `breakSuperset`
  - `setRow.setType`
  - `barCustom*`
  - `restModePicker`, `restThreshold`, `restCap`
  - `hrCalories`, `hrZoneEdit`, `hrMessage`
  - `useBirthDate`
  - `summaryTime`, `summaryCalories`
  - `cardioCurrentPace`
  - `entryTitle.*`
- A redesign that renames an ID must update the tests.

**Adjacent surfaces outside this scope that mirror this state.** A redesign that covers every detail should restyle them too.
- The lock-screen Live Activity and Dynamic Island in `WorkoutTrackerWidget/WorkoutActivityView.swift`. It shows the gym, the elapsed timer, the current exercise, the BPM, the zone, "{n} set(s)", and "Rest" with a countdown.
- The watch app in `WorkoutTrackerWatch/WatchRootView.swift`. It shows "Not connected", "Start a workout on your iPhone.", the BPM, the rest countdown and "No reading".
- The rest notifications from `Domain/RestTimer.swift`:
  - Title: "Rest complete".
  - Bodies: "Time for your next set.", "Time is up — your heart rate didn't reach the target." and "Heart rate down to {bpm} bpm — ready for your next set."
- The Workout tab's resume affordance after minimise, in `Start/StartWorkoutView.swift`.

---

## 1. Active workout screen (container)

**Where:**
- **View:** `ActiveWorkoutView` at `ActiveWorkout/ActiveWorkoutView.swift:5`, with `body` at `:89`.
- **Presentation:** a **full-screen cover** from `RootView.swift:60` (`.fullScreenCover(item: $activeWorkout)`).
- **Reached by:**
  - starting a workout on the Workout tab
  - relaunching the app, which auto-resumes the newest active workout (`RootView.recoverActiveWorkout`)
  - the resume affordance after minimise
- **Its job:** logging a lifting workout, with optional mixed cardio, live heart rate and rest timing.

**Structure.** The screen is a `NavigationStack` around a `List(.plain)` whose rows have their chrome stripped: clear backgrounds, hidden separators and zero insets. The comment at `:91` gives the reason: `.onMove` drag-to-reorder of exercises only works in a List. The background is `Theme.background`, and `defaultMinListRowHeight` is 0.

### 1.1 Navigation bar (toolbar, `:233-275`)
| Placement | Control | Visible | Action | ID / a11y |
|---|---|---|---|---|
| topBarLeading #1 | Button | SF `chevron.down` | minimise: dismisses the cover, the workout keeps running (`onMinimize`) | `minimizeWorkout`, label "Minimize workout" |
| topBarLeading #2 | Button role .cancel, `.tint(.red)` | "Cancel" | opens the discard dialog (1.9) | — |
| principal | Button (plain) | `{workout.historyTitle}` in headline, lineLimit 1, then SF `pencil` caption2 secondary | opens the rename alert (1.8) | `workoutTitle`, hint "Edits the workout name" |
| topBarTrailing | Button, headline font | "Finish" | `finishTapped()`, see 1.10 | `finishWorkout` |

- `historyTitle` resolves in this order: the typed name, then the template name, then "{first exercise}" or "{first} +{n-1}", then "Workout" (`HistoryRendering.title`, `:88`). The `.navigationTitle` is set too (`:231`), but the principal item replaces it.
- [J] The bar is crowded: two leading controls, a title with a pencil, and Finish. "Cancel" in red actually means *discard the whole workout*, a destructive act mislabelled with a benign word, and it sits right next to minimise. The title pencil is tiny (caption2).

### 1.2 Header row: gym chip, elapsed clock and set-progress ring (`header`, `:420-453`)
The header is the first List row: an HStack with spacing 12 and padding of 20 horizontal, 4 top and 8 bottom. The top and bottom padding collapse to 0 while the keyboard is visible (`keyboardVisible` at `:23`, set from `keyboardWillShow`/`keyboardWillHide` at `:355-360`).

1. **Gym chip:** `Chip(tint: secondary)` containing Label "{gym.name}" or "No gym", with SF `mappin.and.ellipse`. It is not tappable.
2. **Elapsed clock:** a `TimelineView(.periodic(by: 1))` showing `Format.elapsed`. The format is "m:ss" under one hour and "h:mm:ss" from an hour on. Font `Theme.stat`, monospaced digits, text colour. The a11y label is "Elapsed {spoken}", e.g. "Elapsed 12 minutes 34 seconds". The clock counts wall time from `workout.startedAt`, and a lifting workout has no pause.
3. Spacer.
4. **Set ring and count (lifting focus only):**
   - The ring is a 22×22 `ProgressRing` with secondary tint and lineWidth 3, showing completed ÷ total sets across all entries.
   - The text is "{completed}/{total} sets" in caption semibold, secondary colour, monospaced.
   - The a11y element is combined: "{completed} completed sets, {total} total".
   - The ring and count are hidden when `cardioFocus` is on.
   - Warmup and draft rows count toward the total.
- History (ticket 16): the user asked for this compact status line, which replaced a Large Title hero and an amber count chip (comment `:401-407`, which sits above the wrong property).
- [J] This row is the only "dashboard" element and it is very quiet. The ring is neutral grey and 22 pt. The workout has no sense of momentum: no volume so far, no current exercise, no next-up.

### 1.3 Conditional rows between the header and the exercises (top to bottom)
1. **Unknown planned-cardio notice** (`:102-104`). Shown when `workout.hasUnknownCardioTargets` is true. Text: "Some cardio targets are unavailable in this version." (footnote, secondary). [J] It is a bare List row with no `listRowBackground`, `listRowInsets` or separator styling, so it is unlike every sibling row.
2. **"Planned cardio" section** (`:105-122`). Shown when `workout.plannedCardio` is non-empty, which happens for workouts from templates or AI routines.
   - It is a List `Section("Planned cardio")` with rows on `Theme.card`, in the plain list style, so the rows are full-bleed with a sticky header.
   - Each row shows the activity name, and under it the `target.summary` caption: "{minutes} min" or "{minutes} min · {distance} {km|mi}".
   - Trailing each row: when `workout.canStart(target)`, a **"Start"** button (ID `startPlannedCardio`), disabled while any cardio is unfinished or the HR monitor is not yet resolved. Otherwise the caption "Started".
   - The Start button calls `startPlannedCardio` (`:60`): it starts a cardio segment linked to the plan, switches to cardio focus, and clears the rest.
   - [J] **Likely bug.** `canStart` returns false whenever *any* cardio is unfinished (`Domain/PlannedCardio.swift:63-64`). So while one segment records, every other not-yet-started target reads "Started". A target that was started but ended without recording activity shows "Start" again. A target already completed also says "Started", where "Done" would be accurate.
   - [J] The `.disabled(unfinishedCardio != nil)` is redundant because of that guard.
   - [J] The section's visual language (plain list section, full-bleed rows) is inconsistent with the rest of the screen's rounded cards.
3. **Activity focus switch** (`:123-130`). A segmented `Picker("Activity")` with **"Lifting"** and **"Cardio"** (ID `workoutActivityFocus`). It appears only when the workout has any cardio segment or cardio focus is on. The initial focus is set in `.task` (`:380`): cardio if a segment is unfinished, or if there is cardio and no lifting entries.
4. **If cardio focus:** `CardioWorkoutSection` (section 3.2) replaces everything from here to the add buttons.
5. **If lifting focus:**
   - a. **Unfinished-cardio return row** (`:135-144`). Shown when cardio is recording in the background.
     - Content: Label "{activity name}" with the activity symbol; a Spacer; then "Recording" or "Paused" (subheadline, secondary, min height 44).
     - Tapping it switches to cardio focus.
     - [J] It is low-contrast and looks like static text, although it carries a live background recording.
   - b. **Heart-rate bar** (`HeartRateBar`, section 2.1). Shown when the monitor exists and `workout.sensorConfiguration.recordsActivity` is true. That flag is false for a cardio-only workout that has no unfinished segment (`Cardio.swift:244`).
   - c. **Exercise cards:** `ForEach(entries) { ExerciseEntryCard }` (`:157-170`) with row insets of 7 top and bottom. **`.onMove`** allows long-press drag reordering (`moveEntries`, `:587`). [J] Reordering is invisible: there is no handle, hint or edit mode.

### 1.4 Add block (last List row, `:174-209`)
A VStack with spacing 6, horizontal padding 16 and bottom padding 24.
1. A row of two buttons. It is an HStack, or a VStack at accessibility sizes (`typeSize.isAccessibilitySize` → `AnyLayout`).
   - **"Add Exercise"**, SF `plus`, full width (ID `addExercise`). It is `.primary` in lifting focus and `.secondary` in cardio focus (`:409-418`). It sets `cardioFocus = false` and opens the Exercise picker (section 4.1).
   - **"Add by Machine"**, SF `figure.strengthtraining.traditional`, `.secondary` (ID `addByMachine`). It is disabled when the workout has no gym. It sets `cardioFocus = false` and opens Add by Machine (section 4.2).
2. **"Add Cardio"**, SF `plus`, `.secondary`, full width (ID `addCardio`). It opens the Cardio picker (section 3.1).
3. When there is no gym, the caption "Pick a gym to log by machine" appears (caption, secondary, centred; ID `addByMachineUnavailable`).
- [J] Three full-width buttons stacked at the end of a long list. Two of them share the `plus` icon. There is no quick "add set to current exercise" and nothing sticky; you scroll to the bottom to add anything.

### 1.5 Bottom safe-area inset (`:215-229`), mutually exclusive
- In cardio focus with an unfinished segment: **`CardioControls`** (section 3.5).
- Otherwise, when a rest is running: **`RestTimerBar`** (section 2.3).
- Otherwise: nothing.
- [J] The inset probably sits above the keyboard while a field is focused, where it covers rows. Not verified on a device.

### 1.6 Timers, haptics and lifecycle (ActiveWorkoutView)
- `livenessTick`: a 2 s timer (`:53`, `:391-395`). It refreshes HR liveness, evaluates the heart-rate rest (D43), and pushes Live Activity state.
- `.sensoryFeedback(.restDone /*.success*/, trigger: restExpiryCount)` (`:230`) fires when the rest bar expires.
- `.task` (`:367-381`) resolves the HR monitor (the Start Planned Cardio button stays disabled until then), wires `onSample`, and sets the initial focus.
- `onAppear`, and a return to the `.active` scene phase, both call `refreshRest()`.
- `restEnd` changes are broadcast to the watch and the audio alarm (`:386-390`).
- Rest logic lives in `updateRest` (`:705-737`):
  - Inside a superset, no rest runs until the last member (D48), and a running rest is skipped.
  - Un-completing a set still reaches the timer.
  - Heart-rate rest (`evaluateHeartRateRest`, `:503-547`): the rest ends early when the heart rate "recovers", with its own sound. When the sensor feed degrades, it falls back to the standard duration.

### 1.7 Sheets and alerts hung off the container
| # | Trigger | Presentation | Detents |
|---|---|---|---|
| a | the entry card's equipment row | `.sheet(item: machinePickerEntry)` → MachinePickerSheet (4.4) | medium, large |
| b | the entry card's chart button | `.sheet(item: performanceEntry)` → PreviousPerformanceSheet (4.6) | medium, large |
| c | Add Cardio | `.sheet` → CardioActivityPicker (3.1) | default (large) |
| d | a cardio recorder error | `.alert("Cardio could not be saved")` with message `{errorMessage}` and "OK" | — |
| e | Add Exercise | `.sheet` → ExercisePickerSheet (4.1) | default (large) |
| f | Add by Machine | `.sheet` → AddByMachineSheet (4.2) | medium, large |
| g | HR bar "· set up zones" / "· edit zones" | `.sheet` → MaxHeartRateSheet (2.2); `onDismiss` re-resolves the max HR | default (large) |
| h | title tap | alert "Workout Name" (1.8) | — |
| i | rename refused | alert (1.8) | — |
| j | Cancel | confirmationDialog (1.9) | — |
| k | Finish on a templated workout that drifted | `templateDriftDialog` (1.10) | — |

Row a's picker is presented with `presentationDetents([.medium, .large])`.

Cardio error messages can be "This workout has already finished.", "Enter a distance of zero or more.", "This cardio target has already started or is unavailable." or "Could not save cardio: {error}".

### 1.8 Rename alerts (`:276-299`)
- **"Workout Name"** alert:
  - TextField placeholder = `workout.derivedTitle` (ID `workoutNameField`).
  - Buttons: **"Save"** (ID `saveWorkoutName`) and **"Cancel"** (role cancel).
  - Saving with a blank field clears the name back to the derived title.
- **"This workout has finished"** alert: message "It was not renamed. Rename it from History, where the change is recorded as an edit.", with "OK". It is shown when the domain refuses the rename, which only happens for a stale view.

### 1.9 Discard confirmation (`:300-309`)
- A confirmationDialog titled **"Cancel this workout?"** (title visible).
- **"Discard Workout"** (destructive) calls `session.cancel`, which deletes the workout graph, stops HR and the Live Activity, and dismisses.
- **"Keep Logging"** (cancel).
- Message: "The workout and everything logged in it will be deleted."

### 1.10 Finish
`finishTapped` (`:618`):
- A from-scratch workout finishes immediately, with no confirmation.
- A templated workout checks for drift first (`TemplateDriftService`). If it drifted, the confirmationDialog **"Update workout template?"** appears (`TemplateDriftDialog.swift`):
  - Message: "This workout's completed exercises, set counts, or target reps differ from the template."
  - Buttons: "Update Template", "Update Values Only", "Update Both", "Keep Original", and "Keep Logging" (cancel).

What finishing does:
- `session.finish` **deletes uncompleted draft rows and entries with no completed set** (`WorkoutSession.swift:100-113`). If nothing survives, the workout is deleted, and the finish sheet shows the "Nothing to save" state.
- It ends HR, which banks the summary, and ends the Live Activity.
- It hands the result to `RootView`, which dismisses the cover and presents `WorkoutFinishedSheet` (section 5).

[J] Finishing silently throws away rows the user typed values into but did not tick. There is no warning such as "2 unlogged sets will be discarded".

---

## 2. Heart rate and rest (lifting)

### 2.1 HeartRateBar: inline card state machine
**Where:** `HeartRateBar.swift:10`. It is an inline row in the active workout above the exercises, a `.card()` with padding 14×10 and horizontal padding 16. There is no ID on the container, on purpose (comment `:48-52`).

| Monitor state | Renders (verbatim) | Controls |
|---|---|---|
| `.idle` | **nothing**, no empty card (`:19-20`) | — |
| `.needsAuthorization` | Label "Heart rate needs permission in Health", SF `heart.text.square`, caption secondary (ID `hrMessage`) | none |
| `.denied` | Label "Heart rate is off. Turn it on in Settings › Health › Data Access.", SF `heart.slash` (`hrMessage`) | none |
| `.unavailable` | Label "This device can't measure heart rate", SF `heart.slash` (`hrMessage`) | none |
| `.waitingForSensor` with no reading | SF `heart.fill` in **red, not pulsing** (`isStale` is false when there is no reading, and the pulse needs a reading), then "Looking for a sensor…" subheadline secondary; line 2: "No sensor reporting" | zone link (below) |
| `.waitingForSensor` with an old reading | the last BPM in grey, line 2 "Not reporting · {n}s ago" | zone link |
| `.live(source)` | line 1: `heart.fill` in danger colour with `.symbolEffect(.pulse)`; "{bpm}" in `Theme.stat` plus "bpm" caption, danger colour (ID `hrBpm`); zone chip; Spacer; "{kcal} cal" subheadline medium (ID `hrCalories`, a11y "{n} active calories"). Line 2 (caption2 secondary): "{source}" (ID `hrSource`), i.e. "AirPods", "Apple Watch", "Heart rate monitor" or "Test data" | zone link |

- **Stale:** the latest sample is more than 15 s old (`HeartRateSample.stalenessTolerance`). The BPM and heart turn secondary grey, the pulse stops, and "· {age}s ago" is appended.
- **Zone chip** (`:156-172`, ID `hrZone`): `Chip(tint: zone.color)` containing "{Zone 1…5 | Warm-up}" and a 5-step capsule meter. The filled steps are 4×11 and the empty ones 4×7 in `fill`. The a11y label is "{label}, {description}", e.g. "Zone 3, Moderate — aerobic". The Warm-up zone (raw value 0) fills no steps.
- **Zone link** on line 2, an underlined caption2 button:
  - "· set up zones" (ID `hrZoneSetup`) when there is no max HR.
  - "· edit zones" (ID `hrZoneEdit`) when the max is estimated from age and a zone exists.
  - No link when a measured max exists.
  - Both links open MaxHeartRateSheet.
- **BPM a11y:** "{bpm} beats per minute", or "…, {n} seconds ago" when stale, or "Looking for a sensor".
- [J] The permission states give no button to grant permission or open Settings, only text. The bar mixes three sizes of type on two lines. The zone meter is 4 pt wide, tiny. The underlined "· set up zones" reads like fine print. The HR has no graph or trend. The zone colour is used only in the small chip, not on the big number. Calories sit far right, disconnected.

### 2.2 MaxHeartRateSheet
**Where:** `MaxHeartRateSheet.swift:11`.
- **Presentation:** a sheet from the HR bar. The same view is also used from Settings (`AppSettingsSection.swift:59`).
- **Title:** "Heart Rate" (inline).
- **Toolbar:** "Cancel" (cancellationAction) and "Save" (confirmationAction, ID `saveMaxHeartRate`).
- It uses the system `Form` with **no `Theme.background`**, unlike the list sheets.

Blocks, top to bottom:
1. Section header "Measured maximum": TextField "Maximum heart rate" with a number pad (ID `maxHeartRateField`).
2. Section header "Date of birth":
   - Toggle "Use my date of birth" (ID `useBirthDate`).
   - When on, a `DatePicker("Date of birth")` for the date. It defaults to 1970-01-01 when none is stored.
3. Section "Zones would use", shown only when a max resolves. It is a live preview:
   - LabeledContent "Maximum" → "{bpm} bpm".
   - One row each for "Zone 1" through "Zone 5" → "{lowerBound}+ bpm" (monospaced).

- **Save:**
  - The measured value is stored only if it parses as an integer greater than 0; otherwise it is cleared silently.
  - The birth date is stored if the toggle is on, and `updatedAt` is stamped.
  - The sheet then dismisses.
  - When presented from the active workout, dismissing re-resolves the monitor's max HR.
- [J] Nothing says that a measured value beats the birth date (it does, in `MaxHeartRateResolver`). The zones preview is text rows rather than a visual scale. There are no zone descriptions such as "Light — endurance", and the preview does not show which zone you are in now. An invalid entry is discarded without feedback.

### 2.3 RestTimerBar: bottom inset card
**Where:** `RestTimerBar.swift:3`. It sits in the bottom safe-area inset of the active workout while `restEnd` is set.

Layout: `.card(.elevated)`, padding 16, horizontal inset 16, bottom 8.
1. **Timer group:**
   - A 44×44 ZStack: a `ProgressRing` whose progress is remaining ÷ total, so it **drains**, in the accent tint with lineWidth 5, around an SF `hourglass` in accent.
   - A VStack: "Rest" (caption, secondary), then "{m:ss}" (`Theme.stat`, monospaced).
   - A Spacer.
2. **Buttons:** "+15s" (`.secondary`) adds 15 s through `restTimer.add`; "Skip" (`.primary`) skips the rest.

- **Accessibility sizes:** the layout switches from HStack to VStack, and the buttons get equal full widths (ticket 16 fix for "+15 / s", "Ski / p" wrapping).
- **Tick:** a 0.5 s `Timer.publish`. When `restEnd <= now` it calls `expired()`: the parent increments `restExpiryCount` (success haptic), calls `refreshRest()`, and the bar disappears. The system alarm sound and notification are scheduled separately (D46).
- There are no IDs on this bar.
- **What starts a rest:**
  - A rest starts on set completion, except for drop sets (D26) and non-last superset members (D48).
  - The duration is per exercise (the warmup and working/failure durations from section 4.8) or the global default.
- **Heart-rate rest mode:** the bar counts down the **cap** (default 4:00). The rest can end earlier when the HR falls below the threshold, and then the bar just vanishes and the "recovered" sound plays.
- [J] **Heart-rate mode is not shown:** the bar never says "until < 110 bpm", never shows the live BPM against the target, and never says why it ended early. The bar also lacks the name of the next set or exercise, a −15 s control, and any way to change the default rest. "Skip" as the amber primary makes skipping the most prominent action. The 44 pt ring with a glyph is small for the main at-a-glance element.

---

## 3. Cardio (all in `Cardio/CardioViews.swift`)

Activities (`Domain/Cardio.swift:4-24`):

| Activity | SF symbol | Metric |
|---|---|---|
| Indoor Walk | `figure.walk` | pace |
| Indoor Run | `figure.run` | pace |
| Indoor Cycle | `figure.indoor.cycle` | **speed** |
| Elliptical | `figure.elliptical` | pace |
| Rowing | `figure.rower` | pace |
| Stair Stepper | `figure.stair.stepper` | pace |
| Outdoor Walk | `figure.walk` | pace, outdoor (GPS) |
| Outdoor Run | `figure.run` | pace, outdoor (GPS) |
| Outdoor Cycle | `figure.outdoor.cycle` | **speed**, outdoor (GPS) |

The distance unit is km or mi, snapshotted from app preferences when the segment starts.

### 3.1 CardioActivityPicker (sheet)
**Where:** `:19`.
- **Presentation:** a sheet from "Add Cardio" (section 1.7c), with no detents, so it opens large.
- **Title:** "Choose Cardio". The **display mode is not set, so it is a large title**, unlike the other sheets, which are inline.
- **Search:** `.searchable` with the prompt "Search activities", a case-insensitive substring match on the name.
- **Toolbar:** "Cancel".

Blocks:
1. When a segment is unfinished: "Starting another activity ends the current cardio segment." (footnote, secondary; a bare row).
2. Section **"Gym"**: the 6 indoor activities.
3. Section **"Outdoors"**: the 3 outdoor activities.
   - Rows: the symbol (title2, secondary, min width 32), then the name in text colour, a Spacer and a `chevron.right` caption. Min height 44, row background `Theme.card`.
   - ID `cardioActivity.{rawValue}`, e.g. `cardioActivity.indoorRun`.

- **Tapping a row** calls `select(activity)` and dismisses. The parent starts the segment, which ends any unfinished one and **skips any running rest**. It then switches to cardio focus and clears the rest broadcast.
- [J] A search with no match shows empty sections, with no empty state. There are no recents, no favourites and no last-used. The picker is a plain list of 9 items where a grid of big tiles would be faster and more expressive. Starting is one tap with no preparation or countdown.

### 3.2 CardioWorkoutSection: the cardio focus content
**Where:** `:62`. It replaces the lifting rows when `cardioFocus` is on (section 1.3.4). Row insets are 12/20, with clear backgrounds and no separators.
1. When a segment is unfinished: **CardioLiveView** (section 3.3).
2. Otherwise, when the workout has no cardio: `EmptyState(title: "Add cardio to this workout", symbol: "figure.run")`. The empty state has no button of its own; the add buttons are further down.
3. Every **ended** segment as a `CardioSummaryCard(showsRoute: false)` (section 3.6). Maps are hidden while the workout is in progress.

### 3.3 CardioLiveView: live cardio metrics
**Where:** `:82`. It is an inline VStack with spacing 24, and it is **not** a card, which is unlike the lifting cards.
1. **Title:** Label "{activity name}" with the activity symbol, `.title2.bold()`.
2. **Timer block:** a `TimelineView` ticking every 1 s, centred.
   - Caption: **"Time"** while running, **"Paused"** while paused (subheadline, secondary).
   - `Format.elapsed(activeDuration)` in **`Theme.hero`** (largeTitle, rounded, black), ID `cardioTimer`. The duration excludes paused intervals, so the clock freezes while paused.
3. **Metric grid:** a `LazyVGrid` with 2 flexible columns, or 1 at accessibility sizes, spacing 20. Each cell is a `CardioMetric`, section 3.7.
   - "Distance" → "{%.2f}" or "—", unit "km"/"mi" (ID `cardioDistanceMetric`).
   - For speed activities: "Average speed" → "{%.1f}", unit "{km|mi}/h".
   - Otherwise: "Average pace" → "{m:ss}" or "—", unit "/{km|mi}".
   - Only while a fresh HR sample exists: "Heart rate" → "{bpm}", unit "bpm", **danger tint**.
   - Only when present: "Active calories" → "{n}", unit "cal".
4. **Current pace or speed.** Shown when there is no manual distance and a speed reading is under 15 s old.
   - Text: "Current speed: {x} {u}/h" or "Current pace: {m:ss} /{u}" (footnote, secondary).
   - ID: `cardioCurrentPace`.
5. "Waiting for heart-rate data" (footnote) while the segment runs and no fresh HR exists.
6. When there is HR and a max HR: an HStack with the zone `Chip` ("Zone n") and, at the trailing edge, the source label caption, e.g. "Apple Watch".
7. **Location or motion message** (footnote, secondary), one of the following from `CardioRecorder.swift:243-293`:
   - "Allow location to record distance and your route."
   - "Precise Location is off. Route accuracy is limited."
   - "Waiting for GPS…"
   - "Location unavailable."
   - "GPS unavailable. Recording time continues."
   - "Motion data unavailable."
8. **Manual distance button**, indoor only, shown when no measured distance exists or a manual distance is set (ID `cardioEditDistance`).
   - An optional caption: "Entered distance", or the source label ("HealthKit estimate", "Phone motion estimate", "GPS", "Mixed distance sources").
   - The value: "Enter distance" or "{x} {u}", in headline. A `pencil` icon; min height 44.
   - It opens CardioDistanceSheet (section 3.8).

- **Paused state:** only the caption word changes ("Time" → "Paused") and the clock stops. The bottom control flips to Resume.
- [J] Paused is barely distinguishable: no colour change, no dimming, no pulsing. An **outdoor session shows no live map or route**: the map appears only in the finished summary. There is no zone colouring on the big timer, no HR trend, no splits or laps, and no goal progress, even when a planned target has minutes or distance. The source label, current pace and messages are all the same grey footnote style.

### 3.4 Lifting and cardio in one workout: behaviour summary
- The focus switch (section 1.3.3), a segmented control labelled "Lifting | Cardio", appears once any cardio exists.
- In lifting focus with background cardio, a return row shows "Recording"/"Paused" (section 1.3.5a).
- In cardio focus, the header ring is hidden, the HR bar is hidden (the cardio view has its own HR), "Add Exercise" becomes secondary, and the bottom inset shows CardioControls instead of the rest bar.
- Add Exercise and Add by Machine switch focus back to lifting. Starting cardio skips any running rest.
- The HR monitor reconfigures its HealthKit activity type per segment (`sensorConfiguration`).
- [J] The two modes share one screen without a shared visual frame. The segmented control is generic. Planned cardio sits above the switch, in lifting focus too.

### 3.5 CardioControls: bottom inset
**Where:** `:174`. It is a `.card(.elevated)` with padding 16, horizontal inset 16 and bottom 8, laid out as an HStack, or a VStack at accessibility sizes.
- **"Pause"** (SF `pause.fill`) or **"Resume"** (SF `play.fill`), `.primary`, full width (ID `cardioPauseResume`).
- **"End Cardio"**, `.secondary`, full width (ID `endCardio`). It ends the segment immediately, **with no confirmation**. The segment then becomes a summary card, and the empty state or summaries show.
- [J] Pause and End are the same size, and End has no confirmation or long-press guard. There is no lock-screen-style swipe guard. End Cardio does not offer "finish the whole workout".

### 3.6 CardioSummaryCard: a finished segment
**Where:** `:212`.
- **Used in:**
  - the active workout's cardio focus, with `showsRoute: false`
  - WorkoutFinishedSheet's "Cardio" section, with the route
  - History's workout detail (`WorkoutDetailView.swift:178`)
- **Layout:** `.card()` with padding 16, spacing 16.

Blocks:
1. Label "{activity}" with the symbol, headline (ID `cardioSummary.{rawValue}`, combined).
2. A grid of 2 columns, or 1 at accessibility sizes:
   - "Time" → `Format.elapsed(active)`
   - when there is a distance, "Distance" → "{%.2f}" with the unit
   - "Average pace" (/u) or "Average speed" (u/h)
   - "Avg. heart rate" → "{bpm}" "bpm"
   - "Active calories" → "{n}" "cal"
3. The route map `CardioRouteMap` at 180 pt tall, shown when `showsRoute` is on and a route exists (section 3.9).
4. An edit-distance row: "Enter distance", or "{source caption}" / "Distance" when a distance exists, plus a `pencil`. Caption, secondary, min height 44 (ID `cardioSummaryEditDistance`). It opens CardioDistanceSheet.

- [J] The edit row's label is a *source caption* ("GPS", "Entered distance"), not an action, so "GPS ✎" reads oddly as a button. The card has no zone breakdown, splits or elevation. Its style differs from `StatTile` (no symbols) and from the finish sheet tiles, and the HR value is not tinted here, while in the live view it is.

### 3.7 CardioMetric (cell component)
**Where:** `:196`. The label is caption and secondary. The value is `Theme.stat` with monospaced digits and a tint (text colour by default). The unit is subheadline and secondary. It is aligned leading.

### 3.8 CardioDistanceSheet
**Where:** `:251`. A sheet from the live view or a summary card, with no detents, so it opens large.
- **Title:** "Distance", with no display mode set, so a large title.
- **Background:** the system `Form`, not `Theme.background`.
- **Toolbar:** "Cancel", and "Save" (ID `saveCardioDistance`). Save is disabled until the text or unit changes.

Blocks:
1. TextField "Distance" with a decimal pad (ID `cardioDistanceField`).
2. A segmented `Picker("Unit")` with "km" and "mi" (ID `cardioDistanceUnit`).
3. When an automatic measurement exists: "Measured: {%.2f} {u}" (subheadline, secondary).
4. "Enter the machine’s distance. Clear it to use the measured distance." (footnote).
5. On an error, the error text in danger red, e.g. "Enter a distance of zero or more."

- **Save:** `CardioSession.enterDistance`. A blank field clears the manual value. On a finished workout, a change stamps `historyEditedAt`.

### 3.9 CardioRouteMap
**Where:** `:298`.
- MapKit `Map(interactionModes: [])`, i.e. **non-interactive**.
- The route is drawn as polylines per portion, split across pauses or GPS gaps of more than 20 s, stroked in AccentColor at 4 pt.
- Style: standard, flat, with no points of interest.
- Corner radius 16.
- a11y label "Recorded cardio route", ID `cardioRoute`.
- [J] There are no start/end markers, no pace colouring, and no tap-to-expand.

---

## 4. Lifting sheets and cards

### 4.0 ExerciseEntryCard: one exercise inside the workout
**Where:** `ExerciseEntryCard.swift:27`, `body` at `:50`. It is a `.card()` with padding 16 and a horizontal inset of 16, with VStack spacing 10.

Blocks, top to bottom:

1. **Title row** (`:276-299`):
   - **Superset chip** "{A|B|C…}". It is `Chip(tint: accent, selected: true)`, amber filled (ID `supersetBadge`, a11y "Superset position {X}"). It shows only when the entry is in a superset of two or more.
   - **Exercise name:** `exercise.name`, or the snapshot name, in `Theme.cardTitle`. It wraps (ID `entryTitle.{name}`).
   - A Spacer.
   - **Title actions** (`:301-336`), an HStack with spacing 12. At accessibility sizes they move to their own right-aligned line.
     - **Menu** labelled SF `ellipsis.circle` in secondary (a11y "Exercise options"). Its items:
       - "Rest Durations…" (`timer`), when the exercise exists. It opens section 4.8.
       - "Superset with next" (`arrow.triangle.merge`), ID `supersetWithNext`. It is **always shown**, even on the last entry, where it does nothing.
       - "Break superset" (`arrow.triangle.branch`), ID `breakSuperset`, only when the entry is grouped.
       - "Delete Exercise" (`trash`, destructive). It deletes **immediately, with no confirmation or undo**.
     - **Button** SF `chart.bar.doc.horizontal` in the tint colour (a11y "Previous performance"). It opens section 4.6.
   - [J] The no-op superset item and the unconfirmed delete are both traps. The previous-performance entry is a cryptic glyph.
2. **Template target** (`:53-56`), caption, secondary. Text: "Target: {n} set(s) · {r}, {r}, {r} reps" (`TemplateTargets.summary`). It shows only when `plannedRestSeconds` is set and `plannedRepsBySet` is non-empty, i.e. for template workouts.
3. **Equipment row** (`machineRow`, `:338-364`, ID `entryEquipment`). It opens MachinePickerSheet (section 4.4).
   - It is a pill: `Theme.fill` background, radius 10, padding 6×10.
   - Contents: an icon (`gearshape.2` when a machine is set, else `dumbbell`, caption); the label "{machine.label}", "{free-weight tag label}" or "Choose equipment" (subheadline medium); an optional model line "{model.displayName}" (caption2, secondary); and a `chevron.right`.
4. **Bar row** (`barRow`, `:112-136`, ID `barPicker`). It shows only when `WorkoutSession.offersBar(entry)`: barbell or Smith tags, or a rack or Smith catalog model. It opens BarPickerSheet (section 4.5).
   - It uses the same pill style, with the icon `figure.strengthtraining.traditional`.
   - The label is "Bar: {20} {kg}" or "No bar — enter total weight".
5. **Assisted notice.** When the load type is assisted, a Label reads "Assisted: lower weight = harder. Records track least assistance." with SF `arrow.down.right.circle`, caption, secondary.
6. **Column headers** (`:366-377`). Hidden at accessibility sizes. Caption2 semibold, tertiary, top padding 8.
   - "SET" (w 34)
   - "PREVIOUS" (flex)
   - "WEIGHT", "PER SIDE" (bar mode) or "ASSIST" (w 88)
   - "REPS" (w 48)
   - an empty 30 pt slot
7. **Set rows:** `SetRowView` for each ordered set (section 4.0.1).
8. **Preset chips** (`presetRow`, `:176-199`). A horizontal ScrollView. It shows when the exercise has presets, which are variations such as grips.
   - One chip per preset name, plus **"None"**. The chips are `Chip(tint: secondary, selected:)`, amber when selected, with min height 44.
   - IDs: `presetChip.{name}` and `presetChip.None`.
   - Tapping a chip calls `session.choosePreset`. After a completed set this **splits the entry** (D36).
   - [J] The chips sit *below* the sets although they determine what the sets mean and which history pre-fills them. They should precede the rows.
9. **"Add Set"** (`:81-90`): SF `plus`, subheadline, `.secondary`, full width (ID `addSet`).
   - It calls `session.addSet`.
   - The new row **inherits the last row's set type** (adding after a warmup gives another warmup).
   - It carries forward reps, weight and bar from the last *completed* row.

Card sheets:
- The Rest Durations sheet (section 4.8). It shows an empty sheet if the exercise is nil.
- `BarPickerSheet` (section 4.5), passed `currentBar` and `initialUnit`.

[J] Overall, every card has the same weight. The card does not show which exercise is "current" or which set is next, and has no per-exercise progress (e.g. 2/4). No PR badge appears when a set beats a record, though the app has the records math. There are no notes, RPE or tempo, and no collapse for finished exercises. The pills and chips form three differently-styled control rows: equipment, bar, presets.

#### 4.0.1 SetRowView: one set row
**Where:** `ExerciseEntryCard.swift:426`, body at `:518`.

**Default layout** (`fieldsRow`, `:672-679`), an HStack with spacing 8, subheadline semibold, monospaced digits, vertical padding 5:
1. **Set-type marker** (`setTypeButton`, `:740-768`, ID `setRow.setType`, a11y "Set type: {working|warmup|failure|drop}"). It is a Menu.
   - Label: a circle at `@ScaledMetric` 34 pt, containing the marker and a tiny `chevron.down` caption2 in tertiary.
   - Marker text: "W" for warmup, "F" for failure, "D" for drop, or the **working index** for working sets. The index counts non-warmup rows, so failure and drop rows still consume a number.
   - Marker colour: warmup `#E9D875`, failure danger, drop `#B8A1EE`, working text colour.
   - Once completed, the circle fills amber and the text is onAccent.
   - Menu items: "Warmup", "Working", "Failure", "Drop". The current type has a `checkmark` Label.
2. **PREVIOUS** (`previousText`, `:641-647`, ID `setRow.previous`). Footnote, tertiary, flexible width.
   - It shows the same-equipment, same-preset, same-set-type ordinal set from the last matching workout: "{w} {kg|lb} × {reps}", "{reps} reps", or "—".
   - It is loaded by a `.task(id: prefillTaskID)` keyed on equipment, preset, type and order.
   - The prefill also **writes those values into the empty fields** of an untouched draft (`applyPrefill`).
   - [J] PREVIOUS is not tappable (there is no "tap to copy"). `prefill(for:)` returns nil for completed rows (`PreviousPerformance.swift:104`), so a completed row that re-appears may show "—". Long values like "102.5 lb × 10" compete for the flexible column.
3. **Weight input** (`weightInput`, `:689-722`), 88 wide, with a `Theme.fill` radius-10 background.
   - A TextField with the placeholder **"–"** (en dash), a decimal pad, centred (ID `setRow.weight`).
   - An inline **unit chip** "kg" or "lb" (`UnitChip`, blue- or green-tinted capsule), ID `setRow.unit`.
     - Tapping it toggles the unit, which **re-labels the number without converting it**.
     - It is **disabled in bar mode**, with the hint "The unit follows the bar. Change the bar to log in the other unit."
   - In bar mode, a caption under the field in caption2 semibold **accent** (ID `setRow.total`): "= {total} {u}", or "{bar} {u} bar" before plates are typed. The field holds the **plates per side**.
4. **Reps input** (`repsInput`, `:724-734`): 48 wide, placeholder "–", number pad, fill background (ID `setRow.reps`).
5. **Complete button** (`completeButton`, `:787-802`), 30 wide.
   - SF `circle`, becoming `checkmark.circle.fill`, at title2 size. It scales from 0.88 to 1 when completed.
   - Tint: amber when completed; secondary when it can complete; quaternaryLabel when disabled.
   - **Disabled until the row is loggable** (`WorkoutSession.isLoggable`, A1).
   - ID `setRow.complete`. a11y: label "Complete set", value "Completed"/"Not completed", and a hint when disabled: "Enter reps to log this set" or "Enter {weight|assistance} and reps to log this set".

**Accessibility layout** (`:651-671`):
- Row 1: [marker] [previous] [complete].
- Row 2: a VStack with the "WEIGHT"/"PER SIDE"/"ASSIST" label (`Theme.label`, secondary) over the weight field, and a VStack with "REPS" over the reps field (max width 100).

**Row states:**
- **Empty draft:** the fields show "–", and the check is disabled.
- **Prefilled draft:** the fields hold last session's values, and the check is enabled.
- **Dirty:** the user typed. Later prefills never overwrite the fields.
- **Completed:** the row background gets an amber 8% wash over `Theme.card`, the marker is filled amber, and the check is filled. `.sensoryFeedback(.setComplete)` fires (impact medium 0.8), with a spring animation (response 0.3, damping 0.65) unless Reduce Motion is on. Completing also dismisses the keyboard.
- **Bar mode:** the header reads PER SIDE, the total caption shows, and the unit chip is disabled.
- **Assisted:** the header reads ASSIST.
- **Bodyweight:** only reps are required.

**Delete gestures:**
- A custom **swipe-left** `DragGesture` (min distance 14, horizontal only) reveals an 88 pt red rounded trash button (ID `setRow.swipeDelete`, a11y "Delete set"). It snaps open past the halfway point with `.snappy`, which is **not gated by Reduce Motion**. The button is only tappable when fully open.
- A **context menu** (long press) offers "Delete Set" (trash, destructive).
- Neither has an undo.

**Keyboard toolbar:** only the focused row contributes one. It holds a Spacer and "Done" (ID `keyboardDone`).
- Commits happen on end-editing, i.e. on focus change, per SPEC's durability boundary.
- Tapping the check commits both fields, then toggles completion.

**Missing affordances [J]:**
- no steppers or ± buttons for weight/reps
- no plate visualisation
- no "next set" highlight
- The check target is 30 pt wide, the unit chip is roughly 26 pt tall, and the marker is 34 pt, all under 44 pt.
- The PREVIOUS column is visually loud relative to its value.

### 4.1 ExercisePickerSheet: "Add Exercise"
**Where:** `ExercisePickerSheet.swift:4`. A sheet from Add Exercise, and also from History's workout-detail editing (`WorkoutDetailView.swift:311`). No detents, so it opens large.
- **Title:** "Add Exercise" (inline). **Toolbar:** "Cancel" (leading).
- **Search:** `.searchable` with the prompt "Search exercises", multi-token matching.

Blocks:
1. A Section with rows on `Theme.card`, one `ExerciseRow` per exercise (sorted by name, **no grouping**), ID `exerciseOption.{name}`.
   - **ExerciseRow** (`:90-148`):
     - The name in `Theme.cardTitle`.
     - A `WrapLayout` holding the body-area caption ("{muscleGroup}", secondary) and equipment tag chips in the default secondary tint: "Machine", "Barbell", "Dumbbell", "Cable", "Smith machine", "Bodyweight".
     - The load-type chip in the amber tint, "Bodyweight", "BW + added" or "Assisted", shown when the load type is not weighted. It sits trailing, or inside the wrap at accessibility sizes.
   - When the search has no match: a row **"Create “{query}”"** with SF `plus` (ID `createExerciseFromSearch`).
2. A Section with **"New Exercise…"** (SF `plus`, `.secondary`, clear row background; ID `newExercise`).
   - It opens `NewExerciseSheet` (in `Exercises/`), titled "New Exercise", with "Name", "Load type", "Equipment", "Cancel" and "Add".

- **Selection:** tapping a row adds an entry with the first non-machine equipment tag and dismisses. Commit is immediate. Cancel adds nothing.
- [J] There are no recents, frequent or "in your last workout" suggestions, and no body-area or equipment filters, although the Exercises tab has them. Multi-select to add several exercises is missing, and so is a "superset these" option. The list gives no hint of what equipment is at this gym.

### 4.2 AddByMachineSheet: "Add by Machine"
**Where:** `AddByMachineSheet.swift:11`. A sheet with detents medium and large. It is enabled only when the workout has a gym.
- **Title:** "Add by Machine" (inline). **Toolbar:** "Cancel" (leading).

Blocks:
1. A section headed "Machines at {gym.name}". Rows use `Theme.card`.
   - **One row per active machine** (ID `machineOption.{label}`):
     - Contents: "{machine.label}" (body medium), then "{model.displayName}" or "No model" (caption, secondary), and a trailing unit chip when the machine has a default unit.
     - Swipe: a trailing **"Delete"** (trash), with no full swipe (ID `deleteMachine.{label}`).
     - Context menu: **"Delete Machine…"** (destructive).
     - Either one opens the alert **"Delete {label}?"**, with "Delete Machine" (destructive) and "Cancel", and the message "It disappears from this gym. Workouts you already logged with it keep it." Confirming archives the machine (D10).
   - When the gym has no machines: `EmptyState(title: "No machines yet", symbol: "dumbbell")`.
   - **"Add Machine…"** (SF `plus`, `.secondary`). It opens `MachineEditorSheet(gym:)` (in `Gyms/GymsView.swift:488`), titled "New Machine", with the label field, catalog model, "Scan equipment…" and so on.
2. **Tapping a machine** (`select`, D7):
   - **1 linked exercise:** the entry is added immediately and the sheet dismisses.
   - **Several linked exercises:** pushes `MachineExerciseList`, titled with the machine label. It has **no search** and lists the linked exercises.
   - **No model:** pushes `MachineExerciseList`, titled "Pick Exercise", with the full catalog and a search ("Search exercises").
   - Either list shows `ExerciseRow`s, "Create “{q}”" on an empty search (full catalog only; it links the new exercise to the model), and "New Exercise…".

- [J] A newly added machine is **not auto-selected**: the user returns to the list and taps it. The machine list has no search or grouping by category or muscle, and no photo or illustration. The medium detent crops the list. The rows look identical to the equipment picker's (section 4.4), though the two sheets have different intents.

### 4.3 MachineExerciseList (pushed)
Documented in section 4.2. **Where:** `AddByMachineSheet.swift:139`. It uses the `Theme.background` list. Its title is inline: the machine label, or "Pick Exercise".

### 4.4 MachinePickerSheet: "Equipment"
**Where:** `MachinePickerSheet.swift:4`. A sheet (detents medium and large) from an entry's equipment row.
- **Title:** "Equipment" (inline).
- **Toolbar:** **"Done"** (trailing). It only dismisses, because a selection commits and dismisses immediately; so "Done" actually means cancel.

Blocks:
1. When the workout has a gym, a section headed "Machines at {gym.name}":
   - Machine rows: the label, the model or "No model", a unit chip, and a **`checkmark`** on the current machine.
   - The EmptyState "No machines yet".
   - "Add Machine…", which opens MachineEditorSheet.
   - There are no swipe-deletes here, unlike section 4.2.
2. A section headed **"Free weights"**, with rows for: Barbell, Dumbbell, Cable, Smith machine and Bodyweight.
   - **Every row uses SF `dumbbell`.** The current row has a `checkmark`.
   - **Dumbbell special case** (D51): when the exercise has a dumbbell counterpart, the Dumbbell row becomes **"Log as {counterpart name} instead"**.
     - It has a trailing `arrow.turn.down.right`, or `exclamationmark.triangle` and is disabled when the counterpart row is missing (ID `logAsCounterpart`).
     - It switches the exercise to the counterpart.
   - Footer, shown only once a set has completed (the entry is frozen, D19): "A completed set locks equipment; a change continues in a new entry."

- **Selection:** `session.chooseEquipment`. It edits the draft in place, or starts a new entry when the entry is frozen. Then the sheet dismisses.
- [J] Every free-weight option uses the same dumbbell icon. The warning about splitting only appears as a footer after you are already frozen; nothing warns at the moment of tapping. "Done" is ambiguous.

### 4.5 BarPickerSheet: "Bar"
**Where:** `BarPickerSheet.swift:11`. A sheet from the bar row, with no detents, so it opens large.
- **Title:** "Bar" (inline). **Toolbar:** "Cancel" (cancellationAction).

Blocks:
1. Row "No bar", subtitle "Enter the total weight", with a checkmark when current (ID `barOption.none`).
2. Section **"Kilogram bars"**: "Olympic barbell" 20 kg, "Women's Olympic barbell" 15 kg, "Technique bar" 10 kg. IDs `barOption.olympic-20kg`, `barOption.womens-15kg`, `barOption.technique-10kg`.
3. Section **"Pound bars"**: "Olympic barbell" 45 lb, "Women's Olympic barbell" 35 lb, "Technique bar" 15 lb. IDs `barOption.olympic-45lb`, `barOption.womens-35lb`, `barOption.technique-15lb`.
   - Rows show the title in body type, the detail "{n} {unit}" in caption secondary, and a checkmark in the tint colour.
4. Section **"Custom bar"**:
   - A HStack of TextField "Weight" with a decimal pad (ID `barCustomValue`) and a segmented Picker "Unit" of kg/lb, 110 wide (ID `barCustomUnit`).
   - **"Use this bar"** (`.primary`), disabled until the value is valid, i.e. positive (ID `barCustomApply`).
   - On appear, a custom current bar pre-fills the custom value.

- **Commit:** tapping any preset row selects it and dismisses. Choosing a bar sets the row's unit (D40).
- [J] A full-height sheet for 7 choices. There are no visuals of the bars. The kg/lb duplication reads as repetition to users unfamiliar with the rule. It could be a compact inline picker.

### 4.6 PreviousPerformanceSheet
**Where:** `PreviousPerformanceSheet.swift:7`. A sheet with detents medium and large, opened from the chart button on the entry card.
- **Title:** the exercise name (inline). **Toolbar:** "Done" (trailing).
- **Background:** the system `List` style, with **no `Theme.background` or cards**.
- **Loading:** `.task(id: machine/model/tag)` loads synchronously. There is no loading or empty state for the list as a whole, so before the load it is blank.

One section per layer. Their order:
1. **This equipment.** Header: Label "This equipment — {equipment label}{ · preset}" with SF `target` in **system `.green`**. Footer: "Only this exact equipment context prefills your sets."
2. **Same model elsewhere.** Present only when the machine has a catalog model. Header: "Same model elsewhere{ · preset}" with SF `gearshape.2` in **system `.orange`**. Footer: "Same hardware at a different gym — shown for reference, never prefilled."
3. **Any equipment.** Header: "Any equipment{ · preset}" with SF `square.stack.3d.up`, secondary. Footer: "Exercise-wide history — equipment may differ, so it is reference only and never prefilled."

The preset suffix is " · {preset name}" or " · No preset" when the exercise has presets.

Each section's body:
- **Last session snapshot:** the equipment label (subheadline medium), with the date trailing in `style: .date` (e.g. "September 17, 2026"); an optional gym name caption; then one line per set.
  - Each set line has a marker and "{w} {u} × {reps}" or "{reps} reps".
  - The marker is "W"/"F"/"D", or **`order + 1`**. This is inconsistent with the card's working index: warmups shift the numbers.
- **Empty history text:**
  - "No completed sets on this machine yet."
  - "No completed sets with this equipment yet."
  - "No other gyms with this model logged yet."
  - "No history for this exercise yet."
- Then a `Divider()`.
- **Records block:**
  - Title: "Weight records", "Least-assistance records · lower is better", "Added-weight records" or "Bodyweight record".
  - Rows: "Most reps" → "{n} reps" (bodyweight), or "{reps} reps" → "{w} {u}" per rep count; "1RM (Brzycki)" → "{e1RM}", followed by the caption "From {w} {u} × {reps}".
  - When empty: "No eligible records at this layer yet."

- [J] This is the richest "history" moment in the workout, and it is a dense grey text list. It has no chart or sparkline, no comparison to today, and no PR highlight. It uses off-palette system green and orange. Three near-identical sections make users parse the fallback rules. Section footers explain the rules at length. There is no "use these numbers" action.

### 4.7 Sheets reached from other sheets, but owned elsewhere
- **`NewExerciseSheet`**, from sections 4.1, 4.2 and 4.3. File: `Exercises/NewExerciseSheet.swift`.
- **`MachineEditorSheet`**, from sections 4.2 and 4.4. File: `Gyms/GymsView.swift:488`.
  - It includes "Scan equipment…" and "Read label on device", which open the camera or scanner flows owned by Gyms.

### 4.8 ExerciseRestSettingsSheet: "Rest"
**Where:** `ExerciseRestSettingsSheet.swift:6`. A sheet from the card menu item "Rest Durations…". No detents, so it opens large.
- **Title:** "Rest" (inline).
- **Toolbar:** "Cancel", and "Save" (confirmationAction). Save writes the override through `RestTimerService.setOverride`, then dismisses.
- It uses the system `Form`, with **no `Theme.background`**.

Blocks:
1. Section "Warmup sets":
   - Toggle "Use global default".
   - When the toggle is off, a Stepper labelled "{m:ss}", range 0–600 s, step 15.
2. Section "Working & failure sets": the same pair of controls.
3. Section, header "How this exercise rests":
   - A segmented Picker "Rest by" with **"Timer"** and **"Heart rate"** (ID `restModePicker`).
   - In heart-rate mode:
     - Stepper "End rest below {110} bpm", range 40–200, step 5 (ID `restThreshold`).
     - Stepper "…or after {4:00} at the latest", range 30–900 s, step 30 (ID `restCap`).
   - Footer:
     - Heart-rate mode: "The cap is a safety net: if a reading never comes down — a hard set, a dropped connection, an earbud out — the alarm still fires and says the time ran out rather than claiming you recovered. With no live heart rate at all, this falls back to the timer above."
     - Timer mode: "Working and failure sets use the durations above. Drop sets never start a rest (D26)."

- [J] **The footer "(D26)" leaks an internal decision ID into the UI.** The toggle never shows *what* the global default is. The stepper labels are bare "m:ss" with no noun. The sheet is a generic Form, off the theme. The feature is reachable only from a three-dot menu.

---

## 5. WorkoutFinishedSheet: post-finish receipt

**Where:** `WorkoutFinishedSheet.swift:14`.
- **Presentation:** a **sheet** from `RootView.swift:73` after the cover dismisses, with `.presentationDetents([.large])`.
- **Title:** "Nice work" when saved, **"Nothing logged"** when discarded (inline).
- **Toolbar:** **"Done"** (trailing, headline, ID `finishedDone`). It dismisses the sheet.
- It uses a List with the `Theme.background`, cards and clear rows.

**States:**
- **saved:** the `workout` was finished and not deleted.
- **discarded:** `workout == nil`, or the workout was deleted.

Blocks, top to bottom:

1. **Status card** (`:49-76`), a `.card()` with padding 16.
   - An 84×84 `ProgressRing` with lineWidth 7:
     - saved: progress 1, amber, with an SF `checkmark` title bold in amber.
     - discarded: progress 0, tertiary grey, with SF `tray`.
   - A VStack:
     - "Workout saved" or **"Nothing to save"** (`Theme.stat`).
     - The summary line (subheadline, secondary, ID `finishedSummary`):
       - saved: "{n} exercise(s) · {n} set(s)[ · {n} cardio activity/activities][ · {gym snapshot name}]". When zero sets were completed but cardio exists, the lifting parts are dropped.
       - discarded: "No sets were completed, so this workout wasn't saved."
   - [J] The ring does not animate. It is static at full, so nothing celebrates.
2. **Actions** (saved only, `:78-110`):
   - **"View in History"** (SF `clock.arrow.circlepath`, `.primary`, ID `viewFinishedWorkout`). It dismisses, switches to the History tab and opens this workout.
   - Then one of:
     - **"Save as Template"** (SF `square.on.square`, `.secondary`, ID `saveAsTemplate`). Shown when `canSaveAsTemplate` is true, i.e. there are completed sets or recorded cardio.
     - **"Saved as template “{name}”"** (SF `checkmark`, subheadline, secondary, min height 44), shown after saving.
   - **Save-as-template flow** (`SaveAsTemplateFlow.swift`):
     - An alert **"Save as Template"**. It has a TextField "Template name", pre-filled "Workout {medium date}", e.g. "Workout Sep 24, 2026". Buttons: "Save", disabled when the name is blank, and "Cancel".
     - The alert message is "Saves exercises, sets and target reps — not weights or rest times.", or with cardio: "Saves lifting exercises, sets and target reps. Cardio, weights and rest times are not included."
     - On failure, the alert **"Couldn't Save Template"** with "OK", and one of these messages: "Give the template a name and try again.", "This workout has no completed sets or recorded cardio to save as a template.", or "The template could not be saved: {error}".
3. **"Workout details" section** (saved only, `statsSection`, `:204-256`).
   - A `LazyVGrid` of `StatTile`s: 2 columns, or 1 at accessibility sizes. Each tile is **omitted, never zeroed**, when its fact is missing (D44).
   - **Tiles:**

     | Label | Value | Symbol | Tint | ID |
     |---|---|---|---|---|
     | "Workout time" | `Format.duration` | `timer` | accent | `summaryTime` |
     | "Total volume" | `WeightMath.displayLabel` in the app unit | `scalemass.fill` | text | `summaryVolume` |
     | "Active calories" | "{n} CAL" | `flame.fill` | #F4939C | `summaryCalories` |
     | "Total calories" | "{n} CAL" | `flame` | #F4939C | `summaryTotalCalories` |
     | "Avg. heart rate" | "{n} BPM" | `heart.fill` | danger | `summaryAvgHR` |
     | "Max heart rate" | "{n} BPM" | `arrow.up.heart.fill` | danger | `summaryMaxHR` |

   - **"Workout time" format:** `Format.duration` gives "{m}:{ss}", so a 75-minute workout reads **"75:00"**, while the live header shows "1:15:00". [J] The format is inconsistent.
   - **Tile a11y:** "{title}, {value} {unit}".
   - **`ZoneTimeCard`**, when any zone has time. A `.card()` titled "Time in zones" (cardTitle). It holds a 12 pt stacked bar of the zone colours, then one row per zone present: a dot, "{Zone n | Warm-up}", and "{m:ss}".
4. **"Heart rate" section** (`HeartRateSummarySection`, in History). Shown when a series exists.
   - A 160 pt Swift Charts plot of floating low–high bars with an amber→danger gradient. The y-axis is labelled only at its low and high values. There are three clock-time separators, and only the first is labelled at accessibility sizes.
   - Under the plot, "{n} BPM AVG" in danger (ID `heartRateAverageCaption`).
   - Chart ID `heartRateChart`, with the a11y summary "Heart rate over {m:ss}, average {n} BPM, maximum {n} BPM".
5. **"Exercises" section**, titled **"Lifting"** when cardio also exists. One `.card()` per exercise:
   - The name (cardTitle).
   - "{equipment}[ · {preset}]" (caption, secondary).
   - "{n} set(s)[ · best {w} {u} × {r}[ ({bar} {u} bar)]]" (caption semibold, **amber**, monospaced).
   - Combined a11y, with ID `summaryExercise`.
6. **"Cardio" section**, when cardio was recorded: a `CardioSummaryCard` per segment, with the route map and an editable distance (section 3.6).

- **Discarded state:** only block 1 and the "Done" button remain.
- [J] **Engagement is missing:**
  - The records math exists, but no PRs or records broken are shown.
  - There is no comparison to the last session and no streak.
  - Nothing is shareable.
  - There is no animation or celebration, only the static ring and "Nice work".
  - "Nice work" (nav title) and "Workout saved" (card) are redundant.
  - The time-in-zones card sits above the HR chart, separated from it by a section header.
  - Cardio comes last, after lifting, even in a cardio-heavy session.

---

## 6. Motion, haptics, timers and adaptivity (all in scope)

**Haptics:**
- set complete: impact medium 0.8
- rest expiry: success
- There are none for: finishing, starting cardio, pause/resume, deleting, PRs, HR recovery.

**Animations:**
- Set completion: a spring, gated by Reduce Motion.
- `ProgressRing`: linear 0.5 s, gated.
- Primary button press: scales to 0.97, gated.
- Swipe snap: `.snappy`, **not gated**.
- HR heart: `.symbolEffect(.pulse)` while live and not stale, **not explicitly gated**.
- There are no transitions on cards appearing or disappearing, the rest bar appearing, focus switching, or sheet content.

**Clocks:**
- header `TimelineView` 1 s
- rest bar `Timer` 0.5 s
- liveness `Timer` 2 s
- cardio `TimelineView` 1 s
- `CardioRecorder` 2 s refresh

**Sounds:** the rest-end and "recovered" alarm is scheduled by the coordinator, not the view. System notifications carry the "Rest complete" copy (section 0).

**Dynamic Type:** no `ViewThatFits` is used in scope. The adaptations all rely on `dynamicTypeSize.isAccessibilitySize`:
- **Active workout:** the add-button row stacks.
- **Exercise card:** the title actions move to their own row, the column headers hide, and the set row stacks into two lines with inline labels.
- **Set marker:** sized with `@ScaledMetric(34)`.
- **Rest bar:** its buttons stack.
- **Cardio:** the metric grid and summary grid drop to 1 column, and the cardio controls stack.
- **Finish sheet:** the tile grid drops to 1 column.
- **HR chart:** only the first time label shows.
- **ExerciseRow:** the load chip wraps.

**Keyboard:** a per-row "Done" accessory, and the header tightens while the keyboard is shown.

---

## 7. Cross-cutting UX observations [J]

1. **Sheet chrome is inconsistent.**
   - **Inline title, `Theme.background`:** Exercise picker, Add by Machine, Equipment, Bar, Finished.
   - **Default Form or List, no theme background:** Rest, Heart Rate, Previous Performance, Distance.
   - **Large title:** Choose Cardio, Distance.
   - **Cancel/Done semantics vary:**
     - Equipment "Done" means cancel.
     - Previous Performance "Done" means close.
     - Bar "Cancel" and Exercise "Cancel" really do cancel.
2. **Destructive actions have no undo anywhere.** Unconfirmed: delete set, delete exercise, End Cardio, and Finish, which drops unticked rows. Confirmed: only discarding the workout and deleting a machine.
3. **Discoverability.** Drag-to-reorder, long-press delete, swipe delete and the set-type menu are all hidden. The superset controls are buried in a three-dot menu, with a no-op item on the last card.
4. **Iconography is a reused grab-bag.**
   - `figure.strengthtraining.traditional` stands for both "Add by Machine" and the bar row.
   - `dumbbell` covers all free weights and the no-machine state.
   - `plus` appears on four different adds.
   - System green and orange appear in Previous Performance.
5. **The screen lacks "where am I".** There is no current-exercise or next-set emphasis, and the progress ring is 22 pt and grey. The rest bar does not name what comes next. The Live Activity *does* compute `currentExerciseName` (`:577`), but the screen never shows it.
6. **Data the app already has but never shows during a workout:**
   - PR detection and records
   - e1RM per set
   - volume so far
   - time-in-zone so far
   - planned target progress for cardio (minutes or distance)
   - the heart-rate rest threshold
7. **Cardio live view vs. lifting.** The cardio view is a non-card free layout with a giant hero timer, while lifting uses dense cards. The two feel like different apps. Paused is almost invisible.
8. **Planned cardio.** "Started" is mislabelled during any running segment (section 1.3.2). The plain-list section styling is out of place.
9. **Copy leaks:** "(D26)" in the rest footer. "Test data" as a source label is visible in the fixture only.

---

## 8. Flat checklist: every screen and state in scope

Active workout container (`ActiveWorkoutView`):
- [ ] Full-screen cover with toolbar: minimise, red Cancel, tappable title with pencil, Finish
- [ ] Header: gym chip or "No gym"; elapsed clock m:ss / h:mm:ss; set ring and "{c}/{t} sets"; the ring hidden in cardio focus
- [ ] Header, compact padding while the keyboard is visible
- [ ] Unknown-cardio-targets notice row
- [ ] "Planned cardio" section: row with Start / Started (disabled, and the mislabelled state)
- [ ] Lifting | Cardio segmented focus control (appears once cardio exists)
- [ ] Background-cardio return row ("Recording" / "Paused")
- [ ] Empty workout: no entries, only the header and the add block. There is no dedicated empty state for lifting.
- [ ] Exercise card list with drag-reorder
- [ ] Add block: Add Exercise (primary in lifting, secondary in cardio), Add by Machine (enabled, or disabled with "Pick a gym to log by machine"), Add Cardio; stacked at accessibility sizes
- [ ] Bottom inset: none, RestTimerBar, or CardioControls
- [ ] Alert "Workout Name" (rename)
- [ ] Alert "This workout has finished" (rename refused)
- [ ] Dialog "Cancel this workout?"
- [ ] Dialog "Update workout template?" (drift, 4 options and Keep Logging)
- [ ] Alert "Cardio could not be saved"
- [ ] Rest-expiry success haptic

Heart rate and rest:
- [ ] HeartRateBar idle (hidden)
- [ ] HeartRateBar needs authorization
- [ ] HeartRateBar denied
- [ ] HeartRateBar unavailable
- [ ] HeartRateBar waiting with no reading ("Looking for a sensor…" / "No sensor reporting")
- [ ] HeartRateBar waiting with an old reading ("Not reporting · {n}s ago")
- [ ] HeartRateBar live: BPM, zone chip with meter, calories, source
- [ ] HeartRateBar stale: grey, no pulse, "· {n}s ago"
- [ ] HeartRateBar with no max ("· set up zones"), estimated max ("· edit zones"), or measured max (no link)
- [ ] MaxHeartRateSheet: measured field; DOB toggle off/on with date picker; "Zones would use" preview present/absent
- [ ] RestTimerBar: default and accessibility (stacked) layouts; +15s; Skip; expiry; heart-rate-mode rest (shows the cap only)
- [ ] Rest notifications and alarm copy (system surface)

Exercise card and set rows:
- [ ] Card title row: default, and the accessibility-size actions row; superset chip A/B/C
- [ ] Card menu: Rest Durations…, Superset with next, Break superset, Delete Exercise
- [ ] Template target caption
- [ ] Equipment pill: machine with model, machine without model, free-weight tag, "Choose equipment"
- [ ] Bar pill: "Bar: {n} {u}", or "No bar — enter total weight"
- [ ] Assisted notice
- [ ] Column headers: WEIGHT, PER SIDE, ASSIST (hidden at accessibility sizes)
- [ ] Preset chips row, including None; selected state
- [ ] Add Set
- [ ] Set row: empty draft (check disabled), prefilled draft, dirty, completed (amber wash, filled marker, haptic, spring)
- [ ] Set row types: working number, W, F, D; set-type menu with checkmark
- [ ] Set row bar mode (per-side field, "= total" or "{bar} bar" caption, unit chip disabled)
- [ ] Set row unit chip kg/lb toggle
- [ ] Set row PREVIOUS: value, or "—"
- [ ] Set row swipe-open delete; long-press context menu "Delete Set"
- [ ] Set row accessibility two-line layout
- [ ] Keyboard accessory "Done"

Lifting sheets:
- [ ] ExercisePickerSheet: list; search; no-match "Create “q”"; "New Exercise…" → NewExerciseSheet
- [ ] AddByMachineSheet: machine list; empty "No machines yet"; Add Machine… → MachineEditorSheet; swipe/long-press delete → alert "Delete {label}?"
- [ ] AddByMachineSheet paths: auto-add with 1 linked exercise; pushed linked list (no search); pushed "Pick Exercise" full catalog with search, Create and New Exercise
- [ ] MachinePickerSheet "Equipment": gym machines with checkmark; no-gym variant (free weights only); empty machines; Add Machine…; free weights with checkmark; "Log as {counterpart} instead" (enabled, or disabled with a warning icon); frozen footer
- [ ] BarPickerSheet: No bar; Kilogram bars; Pound bars; Custom bar (invalid/disabled, valid); preselected custom
- [ ] PreviousPerformanceSheet: layer This equipment / Same model elsewhere (conditional) / Any equipment; each with a snapshot or empty text; records block per load type (weighted, assisted, BW+, bodyweight) or empty records; the blank moment before load
- [ ] ExerciseRestSettingsSheet: global toggles on/off with steppers; Timer vs Heart rate mode with threshold and cap steppers; both footers

Cardio:
- [ ] CardioActivityPicker: default; with "ends current segment" notice; search results; search no-match (empty sections)
- [ ] CardioWorkoutSection: empty state "Add cardio to this workout"; live and ended segments; ended summaries only
- [ ] CardioLiveView running: indoor pace activity; indoor speed (cycle); outdoor (GPS messages)
- [ ] CardioLiveView paused ("Paused" caption, frozen clock)
- [ ] CardioLiveView with HR (metric, zone chip and source) vs. without HR ("Waiting for heart-rate data")
- [ ] CardioLiveView with or without current pace/speed; calories present/absent
- [ ] CardioLiveView location messages (6 strings), motion unavailable
- [ ] CardioLiveView indoor manual-distance button (no distance, or manual value with caption)
- [ ] CardioControls: Pause/Resume, End Cardio; stacked at accessibility sizes
- [ ] CardioSummaryCard: with/without distance; pace vs speed; with/without HR and calories; with/without route map; edit-distance row
- [ ] CardioDistanceSheet: empty; pre-filled manual; with a "Measured" line; error; Save disabled until changed
- [ ] CardioRouteMap: multi-portion polyline
- [ ] Mixed session: focus switching; the return row; rest skipped when cardio starts

Finish:
- [ ] WorkoutFinishedSheet saved: status ring, summary line, View in History, Save as Template → saved label
- [ ] WorkoutFinishedSheet discarded: "Nothing logged" / "Nothing to save" / explanation only
- [ ] Alert "Save as Template" (lifting and cardio message variants; Save disabled when blank)
- [ ] Alert "Couldn't Save Template" (3 messages)
- [ ] Workout details tiles: each of the 6 present or omitted; 1-column accessibility layout
- [ ] Time in zones card
- [ ] Heart-rate chart section and avg caption
- [ ] Exercises/Lifting cards with best set (and bar)
- [ ] Cardio section summary cards with route

Adjacent, out of scope but mirrors this state:
- [ ] Live Activity lock screen and Dynamic Island
- [ ] Watch root view
- [ ] Workout-tab resume affordance
