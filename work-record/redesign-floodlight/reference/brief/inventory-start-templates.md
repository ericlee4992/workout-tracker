# Inventory: app shell, Start (Workout tab), templates, Ask AI

Source: `/Users/ericlee06/orca/projects/Health App`, branch `ericlee4992/redesign-visual-proposal`, HEAD `a0364f2` (clean tree), read 2026-09-24.
Scope: `WorkoutTracker/App/*`, `Features/BrowseMenuOption.swift`, `Features/Start/*`, `Features/Templates/*`.
Neighbouring views reached from this scope (Settings, Cardio picker, Gym/Machine editor, finish sheet, active workout) are listed with enough detail to connect the flows. Their full inventory belongs to the other scopes.

Throughout, **[J]** marks a UX judgement. Everything else is a fact read from code, or from a capture where the capture is named.

Reference captures on disk. They are older than some code, see notes.
- Start, idle, no templates: `work-record/ai-gym/screenshots/ai-start-default.png` (Sep 20; the button then read "Ask AI").
- Start, idle, 4 templates: `work-record/ai-gym/screenshots/followup/ai-immediate-template-1-default.png` (Sep 22).
- Start at AXL: `…/followup/followup-start-axl.png`, `…/followup/followup-start-top-axl.png`.
- Start, live (older ticket 10): `work-record/ui-redesign/screenshots/10/04-start-live-axl.png`.
- Template detail with superset fixture: `work-record/ui-redesign/screenshots/15/04-template-detail-fixture.png` (+ `-axl`, `-axl-2`).
- Template detail from AI with cardio: `work-record/ai-gym/screenshots/ai-template-detail-default.png`.
- Template editor: `work-record/ai-gym/screenshots/ai-template-editor-default.png`, `ai-template-cardio-editor-*.png`, `ai-template-default-rest-*.png`.
- Ask AI inputs: `ai-routine-goals-*.png`, `ai-routine-inputs-*.png`, `ai-routine-cardio-*.png`, `followup/followup-no-gym-*.png`, `followup-empty-gym-*`, `followup-scanned-equipment-*`.
- Your week preview: `ai-week-preview-*.png`.
- Cardio picker: `work-record/cardio/screenshots/…`.

---

## 0. Current visual system and constraints a redesign must know about

### Tokens (`Features/Design/Theme.swift`, `Assets.xcassets/Colors`, Any appearance only; window forced `.preferredColorScheme(.dark)` in `WorkoutTrackerApp.swift:85`)

| Token | Hex | Use |
|---|---|---|
| accent (`AccentColor`) | `#FFB45E` amber | CTA capsules, tint, selected chip, toolbar text |
| onAccent | `#15110B` | text/ink disc on amber |
| background (`SurfaceBackground`) | `#0B0D10` | screen background |
| card (`SurfaceCard`) | `#171B21` | `.card()`, list rows |
| elevated (`SurfaceElevated`) | `#222831` | `.card(.elevated)` |
| fill (`SurfaceFill`) | `#2B323C` | New Template tile, secondary button |
| hairline | white @ 7 % | card border, separators |
| text / secondary / tertiary | `#F6F3EC` / `#B5B9C2` / `#7F8793` | |
| danger | `#FF6B76` | Delete Template |
| warmup / drop | `#E9D875` / `#B8A1EE` | (not used in scope) |
| unitKg / unitLb / unitMixed | `#97C7EE` / `#A8CDBF` / `#B8A1EE` | unit chip tint |
| muscleBody | `#5B6472` | neutral body in muscle-map icon |
| Muscle families (`MuscleGroupStyle`) | chest `#FF70B6`, back `#4EB9FF`, shoulders `#4DE0D4`, arms `#B891FF`, legs `#84D65A` | template tile and detail icons only |

- Radii: card 24, inner 16, field 10. Spacing: xs 4, small 8, medium 12, inset 16, large 24.
- Fonts: `hero` = largeTitle rounded black; `stat` = title2 rounded bold; `cardTitle` = headline bold; `label` = caption2 semibold. Otherwise SF system text styles.
- Components used in scope:
  - `.card()`: card fill, 24 radius, hairline stroke.
  - `Chip`: caption semibold capsule. Tint at 12 %, or amber fill when selected.
  - `UnitChip` / `UnitBadge`: "kg"/"lb" chip.
  - `.secondary` button style: fill, 16 radius, min height 44, subheadline semibold. No press scale, only 0.65 opacity.
  - `MuscleIcon` / `MuscleFamilyStrip`: body-map images in a tinted rounded tile, scaled; `WrapLayout`.
  - `HeroCapsuleLabel`: see §2.3.
- Haptics (`Design/Haptics.swift`): `workoutStart` = heavy impact at 0.8. It is the only haptic in scope.

### Policy and history constraints (from DECISIONS D54/D58 and the ios-design skill)
- D54 copy policy: "the design adds shape, colour and motion — never words". Every visible string and accessibility identifier the UI tests read is kept. A new string is the user's decision. **The user's request to "completely change" may reopen this; it must be reopened explicitly per AGENTS.md.**
- D54: dark only, one warm accent. The user chose "Ink / Amber" over coral on 2026-09-10. Muscle icons are body maps, not SF Symbols ("inaccurate and mild"). Per-exercise muscle icons were removed from rows ("they don't match").
- D54 amendment, 2026-09-19 (cardio ticket 05): the user asked for **side-by-side** amber icon-disc capsules "Start Lifting" / "Start Cardio" without arrows. They stack only when the labels cannot fit. Resume and template Start keep arrows. The user rejected a text-only restyle of Start Lifting.
- D58: Ask AI is "a coordinated editable week, not a calendar or coaching chatbot". No load estimates. Visual guides and automatic coaching are deferred.
- D6: templates are generic and resolve to the last-used machine per gym at start.
- Implementation constraints recorded in code comments:
  - `StartWorkoutView.swift:64-66`: a nested `LazyVGrid` inside the List left the first template row blank after an AI week save on iOS 27. The grid is therefore eager `HStack`/`VStack` rows in ONE List row.
  - `StartWorkoutView.swift:217`: "a context menu in a shared List row can target a peer". Long-press on tiles was removed after it deleted the wrong template (ticket 15).
  - `TemplateDetailView.swift:121-122`: do not put an accessibility identifier on the whole detail screen. It is inherited by the safe-area Start capsule and hides `startTemplate`.
- Visible strings and identifiers in scope that UI tests query:
  - Strings: "Workout" nav bar, tab buttons "Workout"/"History"/"Gyms"/"Exercises", "New Template…", "Template name" text field, "Save", "Edit", "Delete", alert "Delete Template", switch "Use exercise rest default", "Add exercise", "Remove exercise", "Add cardio", "Add cardio target", "Choose or add a gym to save scanned machines.", "No gym", "Cancel", "Done", navigation bar "Choose Cardio".
  - Template names: "templateTile.<name>" (e.g. "templateTile.Whole Body", "templateTile.Day 1 — Fitness").
  - Identifiers are listed per screen below.

---

## 1. App entry and shell

### 1.1 `WorkoutTrackerApp` (`App/WorkoutTrackerApp.swift:4-89`)
- `WindowGroup { RootView().preferredColorScheme(.dark) }` with a SwiftData container. There is no light mode.
- Launch work: UI-test reset of the 3 OpenAI consent flags, catalog seeding, fixtures under launch args, and a unit-preference bootstrap.
  - Fixtures: `ChartFixture`, `TemplateFixture` = one six-exercise "Whole Body" template with a superset, `HeartRateHistoryFixture`, `CardioRouteFixture`, `CardioIndoorFixture`.
- No launch screen, onboarding or first-run experience. **[J]** A first-time user lands directly on Workout with "No gym" and an empty template area.

### 1.2 `RootView` (`App/RootView.swift:4-112`): tab root
- `TabView(selection:)` with 4 tabs, in order (lines 38-54):
  1. "Workout", `figure.strengthtraining.traditional` → `StartWorkoutView` (default selection `.workout`)
  2. "History", `clock.arrow.circlepath` → `HistoryView(target:)`
  3. "Gyms", `building.2` → `GymsView`
  4. "Exercises", `list.bullet.rectangle` → `ExercisesView`
- `.tint(Theme.accent)`. On iOS 26 this renders as the Liquid Glass floating capsule tab bar with the selected tab in amber (seen in captures).
- Settings is **not** a tab. It is a gear on the Workout tab (§2.6).
- **Full-screen cover** `fullScreenCover(item: $activeWorkout)` → `ActiveWorkoutView(workout:onMinimize:onFinished:)` (lines 60-72). It is presented:
  - after any start (from Start, template detail or cardio picker);
  - after Resume;
  - on launch by `recoverActiveWorkout()` (line 93: the newest active workout auto-reopens full screen).
- Minimise sets `activeWorkout = nil`. The workout keeps running and Start shows Resume.
- **Sheet** `sheet(item: $finishConfirmation)` → `WorkoutFinishedSheet` after a finish (lines 73-86). It sizes itself `.large`.
  - "View in History" switches to the History tab and sets `historyTarget`. "Done" dismisses.
  - Content, from `ActiveWorkout/WorkoutFinishedSheet.swift`, for cross-reference:
    - Title "Nice work" / "Nothing logged". Status ring with check or tray.
    - "Workout saved" / "Nothing to save". Summary line such as "3 exercises · 9 sets · Gym". Discarded case: "No sets were completed, so this workout wasn't saved."
    - "View in History" (primary). "Save as Template" (secondary) → §7, or "Saved as template “X”".
    - Stats, HR graph, exercises, "Cardio". Toolbar "Done".
- Heart-rate coordinator and Live Activity controller are owned here so they survive minimise.
- Launch override for screenshots: env `PROTO_SCREEN=gyms|exercises` selects that tab (lines 102-111).
- States: normal / active workout presented / finish sheet presented. There is no badge or indicator on the tab bar while a workout is minimised.
- **[J]**
  - A minimised live workout is visible only on the Workout tab (Resume capsule). On History/Gyms/Exercises nothing shows it is running. iOS 26 `tabViewBottomAccessory` or a mini-player would fix this.
  - Tab symbols are generic. "Exercises" uses a list icon.

---

## 2. Start screen, Workout tab (`Features/Start/StartWorkoutView.swift:4-314`)

**Presentation:** tab root inside its own `NavigationStack`. Large nav title "Workout" (line 104).
**Job:** pick the gym, then start lifting, start cardio, resume a live workout, or open or create a template. Ask AI also lives here.
**Background:** `List` with `.scrollContentBackground(.hidden)` on `Theme.background`. Rows are clear, with separators hidden.

Blocks, top to bottom:

### 2.1 Toolbar
- Trailing gear `gearshape`, `NavigationLink` → pushes `SettingsView` (title "Settings", out of scope).
- accessibilityLabel "Settings", identifier `openSettings` (lines 107-117).

### 2.2 Gym card, a Menu (lines 255-313; row at 43-49)
- The card: `.padding(20).card()`, full width.
- Label, left to right:
  - Pin tile: `mappin.and.ellipse` title2 amber on amber @ 10 % in a 14-radius square, `@ScaledMetric` 44 relative to title2.
  - Text stack: gym name headline (`Theme.text`), or "No gym". Subtitle subheadline secondary: the gym's city, or "" if the gym has no city, or "Home / no location" when no gym.
  - Spacer, then `UnitBadge` (kg/lb chip) and `chevron.up.chevron.down` caption secondary.
- Unit shown = gym default unit → app preference (`UnitPrecedence.defaultUnit`, lines 204-209).
- Menu items: "No gym" (checkmark `Label` when selected, else `Text`), then each non-archived gym sorted by name as "Name · City" or "Name", with a checkmark on the current one.
  - Selection is remembered (`GymSelection.remember`) and restored once per screen lifetime (`restoreSelectedGym`, D1).
- Identifier `gymPicker`.
- Dynamic Type: at accessibility sizes the unit chip and chevron stack under the text, pushed trailing (`AnyLayout` V/H, lines 282-310).
- **[J]**
  - A gym without a city renders an empty subtitle line. The capture `followup/ai-immediate-template-1-default.png` shows the name sitting high with no second line.
  - The menu has no "Add Gym…" or "Manage Gyms". You must go to the Gyms tab, or into Ask AI.
  - The gym card is the largest block above the fold, yet it is a setting, not the job.
  - The unit chip is shown here but nothing on this screen uses a unit.

### 2.3 Hero actions (lines 52-56, 141-181): state-dependent
- **Idle (no active workout)**: two equal amber `HeroCapsuleLabel`s in a `ViewThatFits(in: .horizontal)`. They sit side by side if both fit with `fixedSize`, else stack vertically, leading aligned.
  - "Start Lifting", symbol `figure.strengthtraining.traditional`, no trailing, identifier `startEmptyWorkout`.
    - Sets `startRequest = WorkoutStartRequest(template: nil)` → §3 flow → `onWorkoutStarted` → full-screen active workout.
    - `.sensoryFeedback(.workoutStart, trigger: activeWorkouts.count)` (line 171).
  - "Start Cardio", symbol `figure.run`, identifier `startCardio` → presents the Cardio picker sheet (§2.7).
- **Live (an unfinished workout exists)**: the Start buttons are replaced by ONE capsule, "Resume workout", identifier `resumeWorkout`.
  - Subtitle from `resumeSubtitle` (lines 183-190): "<gym name> · N exercises", or "In progress · N exercises" when no gym.
  - With 0 exercises the subtitle falls back to the unfinished cardio's name (e.g. "Outdoor Run"), else "N cardio activities".
  - Symbol: the unfinished cardio's symbol, or the strength figure. Trailing `chevron.right`. `live: true` shows the breathing dot.
  - Tap → `resumeActive()` → reopens the full-screen workout with no dialog.
- `HeroCapsuleLabel` (lines 320-373):
  - Layout: HStack of a 40 pt `@ScaledMetric` ink disc (onAccent) holding an amber glyph (body semibold), a title (body bold) with an optional subtitle (caption medium @ 80 % opacity), and an optional trailing symbol (body bold).
  - Colours and size: text in onAccent, amber `Capsule()` background, min height 56, leading padding 8, trailing padding 12 or 20. `accessibilityElement(children: .combine)`.
  - Live dot: a 9 pt `@ScaledMetric` amber circle inside the disc's top-trailing corner. Opacity animates 0.35↔1 with `.easeInOut(duration: 1).repeatForever`. It is static at 1 under **Reduce Motion** and `accessibilityHidden`.
- **[J]**
  - An empty lifting workout that was minimised reads "Gym · 0 cardio activities". The fallback picks the cardio wording whenever the exercise count is 0. This is a copy defect.
  - Resume shows no elapsed time, no live heart rate and no current exercise. The live state is only a breathing dot.
  - The haptic is attached to a button that is removed on the very change that triggers it (count 0→1 swaps the view to Resume). Whether it fires is unverified. Start Cardio, template Start and Resume have no haptic.
  - Buttons use `.plain` style, so there is no press state or scale.

### 2.4 "Templates" section (lines 58-99)
- Section header "Templates", the system inset-grouped header in secondary grey.
- Grid:
  - Two columns, or ONE column when `dynamicTypeSize.isAccessibilitySize`.
  - Cells = all templates sorted **alphabetically by name** (`@Query(sort: \WorkoutTemplate.name)`), then a final "New Template…" cell. A blank filler balances the last row.
  - 10 pt spacing. Eager rows, see the constraint in §0.
- **Template tile** (`TemplateTile`, lines 379-403). The button wraps the tile with `.plain` style, identifier `templateTile.<template.name>`. Tap pushes Template Detail (`navigationDestination(item: $viewingTemplate)`).
  - `MuscleFamilyStrip` at 24 pt base: the families present, each once, in the order chest, back, shoulders, arms, legs. Omitted if none, e.g. abs or core only, or cardio-only.
  - Template name in `Theme.cardTitle`.
  - One caption line in secondary: exercise names, then planned-cardio activity names, joined with " · ". It is never truncated, so the tile grows.
  - Tile shape: min height 118, padding 12, `.card()`, VoiceOver `.contain`.
  - No context menu or swipe (deliberate, ticket 15).
- **New Template tile** (lines 220-234): `plus` title3 semibold over "New Template…" subheadline semibold. Min height 118, `Theme.fill` background, 24 radius, **no** hairline border.
  - Tap → `TemplateEditorSheet(template: nil)` sheet (§5). It has no identifier; tests use the "New Template…" label.
- **Ask AI button** (line 88): `Button("Ask AI for Templates", systemImage: "sparkles")`, `.secondary` style, hugging width and leading. Identifier `askAIRoutine`. Opens the **full-screen cover** `AIRoutineSheet(gym: selectedGym, onSelectGym: select)` (§6).
- **Footer caption** (line 93): "Machines resolve to your last-used at <gym name>", or "…at your gym" when no gym. caption2, tertiary.
- States:
  - No templates: only the New Template tile, left column, with the right column empty. There is no EmptyState or explanation.
  - 1..n templates.
  - AX sizes: one column.
  - Live workout: the grid stays visible and tappable. Starting from a template then goes through the §3 dialog.
- **[J]**
  - Tiles in one row have different heights and are vertically **centred**, not top-aligned: the HStack uses default alignment and the tile has no max height. The capture shows "Whole Body" offset against "Day 3 — Fitness".
  - The exercise line can run six wrapped lines ("Dumbbell Curl · Dumbbell Floor Press · …"), which makes tiles tall and text-heavy.
  - Tiles show no count, estimated duration, last-performed date, or cardio icon.
  - Sorting is alphabetical only. There are no favourites, reordering, search, folders or "recent".
  - The empty state wastes half the row.
  - "New Template…" looks like a different component: fill, no border, centred.
  - The Ask AI button floats small and left, and reads as an afterthought.
  - The footer's tertiary caption2 text is low contrast. With "No gym" it says "at your gym", which is misleading.
  - AI-generated templates have generic names ("Day 1 — Fitness") and the three look identical.
  - A tile has no pressed state.

### 2.5 Modifiers on the Start screen
- `.workoutStartFlow(request:gym:onWorkoutStarted:)` → §3 dialogs.
- `.navigationDestination(item: $viewingTemplate)` → Template Detail. When a workout starts from the detail, the detail pops first, so minimising lands back on Start.
- `.fullScreenCover(isPresented: $showingAIRoutine)` → Ask AI.
- `.sheet(isPresented: $showingCardioPicker)` → Cardio picker.
- `.sheet(isPresented: $showingTemplateEditor)` → New Template editor.
- `.onAppear(restoreSelectedGym)`.

### 2.6 Settings: pushed from the gear
Out of scope. Title "Settings". It holds, among others, "Suppress template update prompts" (which affects §8) and the Ask AI key settings.

### 2.7 Cardio picker: a step of the Start flow (`Features/Cardio/CardioViews.swift:19-58`, out of scope)
- Presentation: sheet with no detents (large). Own `NavigationStack`, title "Choose Cardio".
- Search field, prompt "Search activities". Toolbar "Cancel".
- Section "Gym": Indoor Walk, Indoor Run, Indoor Cycle, Elliptical, Rowing, Stair Stepper. Section "Outdoors": Outdoor Walk, Outdoor Run, Outdoor Cycle.
- Each row: an SF symbol (title2, secondary, 32 wide), the name, and `chevron.right`. Card row background, min height 44. Identifier `cardioActivity.<rawValue>`.
- From the active workout the picker shows the note "Starting another activity ends the current cardio segment." The Start flow does not show it.
- Tap starts immediately: `startRequest` with `cardioActivity` → §3 → the workout plus a cardio segment → full-screen workout.
- **[J]** Plain list with grey icons. No recents or targets.

---

## 3. Start flow: dialogs (`Features/Start/WorkoutStartFlow.swift:27-165`)

`ViewModifier` worn by both the Start screen and Template Detail, because a dialog on Start cannot present while a pushed screen covers it. Setting `request` runs the flow, and the modifier clears it.

- **Direct start**, when no resumable workout exists: `startNew()`.
  - Ends any heart-rate session, then creates the workout, from the template at the gym or empty.
  - If `cardioActivity` is set, it starts a cardio segment.
  - Then `onWorkoutStarted`. No UI between the tap and the full-screen cover.
- **Resume dialog**: `confirmationDialog`, shown as an action sheet with a visible title.
  - Title "A workout is already in progress". Message "Completed sets and recorded cardio are kept."
  - Buttons: "Resume Workout" reopens the live workout and drops the pending request. "Finish It & Start New" continues below. "Cancel" (cancel role).
  - Reached from Template Detail's Start while a workout is live. From the Start screen the Start buttons are hidden while live, so it is reached from there only via a template.
- **Replacement drift dialog**: `templateDriftDialog` (§8). Shown when "Finish It & Start New" is chosen and the live workout came from a template it now differs from, unless suppressed in Settings.
  - Message "The active workout differs from the template it started from. Choose how to save that template before starting the next workout."
  - Cancel label "Keep Current Workout".
  - Any other choice banks heart rate, resolves the drift (finishes the old workout) and starts the new one.
- Errors: every failure is `assertionFailure` only. **[J]** In release a failed start silently does nothing; there is no user-facing error.
- **[J]**
  - A confirmation dialog with 3 or 6 buttons at the bottom of the screen.
  - "Finish It & Start New" does not show the finish receipt for the replaced workout.

---

## 4. Template Detail (`Features/Start/TemplateDetailView.swift:10-176`)

**Presentation:** pushed from a Start tile (`navigationDestination`). Large nav title = template name, or "" once deleted. Back chevron.
**Job:** see what the template holds, then start it in one tap. Edit and delete are secondary.
**Background:** List on `Theme.background`, rows on `Theme.card`, separators `Theme.hairline`.

Blocks, top to bottom:
1. **Muscle strip** (lines 37-45): `MuscleFamilyStrip` at 40 pt base in a clear row. Omitted if no families. Identifier `templateFamilies`. The VoiceOver label is the family names joined, e.g. "Chest, Back, Shoulders, Arms, Legs".
2. **Exercise list**: one inset card with hairline separators (lines 46-52). Each row (lines 128-157):
   - Optional superset chip: `Chip(selected: true)`, i.e. amber fill with ink letter "A", "B", …. It is the position inside an adjacent run, from `Supersets.memberLabels`. accessibilityLabel "Superset position A". It sits left of the name, or above it at AX sizes.
   - Name in `cardTitle`, or "Missing exercise".
   - Targets caption: `TemplateTargets.summary`, e.g. "3 sets · 10, 10, 8 reps"; "3 sets" if no reps; "—" for an empty slot; "No sets".
   - "Rest: 60s" caption, only when the template has planned rest.
   - "No matching machine at this gym" caption, only when all three hold: the template is AI-generated (`generatedForGymID != nil`), the item has no preferred equipment tag, and no active machine at the current gym supports the exercise.
   - The row is `.combine` with identifier `templateExercise.<exercise name>`. Rows are not tappable.
3. "Some cardio targets are unavailable in this version." footnote secondary, when the stored cardio JSON has unknown rows.
4. **Section "Planned cardio"**, when there are planned cardio targets: rows with the activity name (headline) and summary caption, e.g. "15 min" or "15 min · 2.5 km".
5. "Created for another gym. Check equipment before starting." footnote. Shown when `generatedForGymID` differs from the current gym, including when no gym is selected.
6. **"Delete Template…"** button: `trash` symbol, destructive role, `Theme.danger`, full width, min height 44, clear row. Identifier `deleteTemplate`.

Other elements:
- **Toolbar:** trailing "Edit", identifier `editTemplate` → sheet `TemplateEditorSheet(template:)` (§5).
- **Bottom safe-area inset (pinned):**
  - `HeroCapsuleLabel` "Start", symbol strength figure, trailing `arrow.up.right`, not live. Subtitle "<gym> · N exercises" or "N exercises", where N = lifting items only.
  - Centred. Top padding 24, bottom 8. A background gradient fades from clear to background so rows fade under it.
  - Identifier `startTemplate`. Disabled when there are no items and no cardio.
  - Tap → §3 flow with `WorkoutStartRequest(template:)`.
- **Alert** "Delete Template": message "Workouts already logged from it are kept." Buttons "Delete" (destructive) and "Cancel".
  - On delete the view marks itself deleted before deleting, renders empty and pops (`dismiss()`). Logged workouts are kept (D23).
- **States:** normal; superset rows; AX sizes (chip above the name); AI template at the same gym / another gym / no gym; unknown cardio; cardio-only; deleted (blank, pops); live workout exists (Start → resume dialog).
- **[J]**
  - A cardio-only template's Start subtitle reads "0 exercises".
  - With no gym selected, AI templates say "No matching machine at this gym" and "Created for another gym".
  - Rest is shown as "Rest: 60s", although `Format.duration` says every rest shows as m:ss (Settings uses "1:30").
  - Rows cannot be tapped: no exercise history, last weights, PRs, or which machine will be used.
  - The preferred equipment tag (e.g. Dumbbell) and the machine the start will resolve to are not shown.
  - No estimated duration, total sets or last performed date.
  - Superset letters restart at "A" for each group, and there is no bracket or connector showing which rows form a group.
  - Delete sits in the content just above the Start capsule, so the destructive and primary actions are close.
  - With a short list, much dead space sits between the content and the pinned Start.
  - A family strip without labels is decorative. Cardio has no icon.

---

## 5. Template Editor (`Features/Start/TemplateEditorSheet.swift:4-186`), with the Cardio Plan Editor (`Features/Templates/CardioPlanEditor.swift:4-36`)

**Presentation:** sheet, no detents (large), own `NavigationStack`. Two entries:
- from Start's "New Template…" tile: title "New Template";
- from Detail's "Edit": title "Edit Template".
The title is `.inline`. **But** a `ToolbarItem(placement: .principal) { EditButton() }` occupies the title slot, so the bar centre shows the amber word "Edit"/"Done", not the title. The capture confirms.

**Job:** name the template, pick exercises, set sets, reps and rest per exercise, and set cardio targets. Staged edits, committed with Save.

**Form**, default system grouped styling, NOT `Theme` backgrounds. Top to bottom:
1. **Section "Name"**: `TextField` placeholder "Template name".
2. **Section "Exercises"**: one block per item (lines 81-112):
   - Name (headline), spacer, remove button `minus.circle` (destructive, plain) that removes immediately.
   - `Stepper` "N sets", range 1...12. Adding a set copies the last slot's reps, or 10.
   - `Toggle` "Use exercise rest default": on = no planned rest; turning it off sets 90 s.
   - When off: `Stepper` "Rest: Ns", 0...600, step 15.
   - One `Stepper` per set: "Set N target · R reps", or "Set N target · —" when 0 (0 = no target), range 0...100, subheadline.
   - Rows reorder with `.onMove` via the EditButton edit mode.
   - Empty: "Add at least one exercise below." in secondary.
3. When the template has unknown cardio rows: "Some cardio targets are unavailable in this version. Update the app to edit this template." Save is then disabled.
4. **`CardioPlanEditor`, Section "Cardio targets"**. Per target:
   - `Picker` "Activity", the 9 activities.
   - `Stepper` "N min", 1...180.
   - `Toggle` "Distance target": on sets distance to 1.
   - When on: `TextField` "Distance" (decimalPad, `.number` format) with `Picker` "Unit" [km, mi].
   - `Button` "Remove cardio", destructive.
   - Below the targets: `Button` "Add cardio target" with a `plus` symbol. It adds Indoor Walk, 15 min, in the app's distance unit, and is disabled at 3 targets.
5. Error text in `.red` (system red, not `Theme.danger`), from the service:
   - "Give this template a name."
   - "Add at least one exercise or cardio target."
   - "Check cardio targets: use 1–180 minutes and a positive distance up to 200 in the selected unit."
6. **Section "Add Exercise"**: EVERY exercise in the library, sorted by name (90 seeded plus user-created). Each is a `Label(name, systemImage: "plus.circle")` button. A tap appends the exercise with 3 sets × 10 reps. Duplicates are allowed.

**Toolbar:**
- "Cancel" (cancellationAction) dismisses without saving and without a confirmation.
- principal `EditButton`.
- "Save" (confirmationAction) is disabled when: the name is blank, OR there are no exercises and no cardio, OR any cardio target is invalid, OR unknown cardio exists. Save → `WorkoutTemplateService.create`/`update` → dismiss, or shows the error inline.

Preserved but not editable: superset group, preferred equipment tag, `generatedForGymID`.

**States:** new / edit / empty exercises / reordering / rest overridden / cardio with and without distance / 3-target cap / unknown cardio (locked) / save error.

No accessibility identifiers are set in this file. Tests use the labels "Template name", "Save", "Use exercise rest default", "Add cardio target", "Remove cardio".

**[J]** This is the most cluttered screen in scope.
- The Add Exercise list is a 90+ row wall at the bottom, with no search, muscle filter or grouping. The rest of the app has a proper exercise picker.
- Each exercise expands into 4+N steppers: a 3-set exercise is 6 control rows.
- The title is hidden by the EditButton.
- Swipe-down and Cancel silently discard edits.
- Supersets cannot be created or seen here.
- Uses the system red and system Form colours instead of theme tokens.
- The toggle's double negative, off = custom rest, is confusing.
- Rest is shown in seconds.
- The per-set target stepper is the only way to set reps (no "apply to all").
- Distance jumps to "1" when toggled.

---

## 6. Ask AI (`Features/Templates/AIRoutineSheet.swift:4-239`)

**Presentation:** full-screen cover from Start's "Ask AI for Templates", with its own `NavigationStack`. It is named "Sheet" but is a cover, so it cannot be swiped away.
**Job:** describe goals, schedule and equipment; AI returns a week of 1–7 sessions; edit them; save each as a template.
**Background:** system `Form`/`List` black (`#000`), not `Theme.background`. The captures show pure black.

Toolbar, all states:
- "Cancel" (cancellationAction) cancels the running task and dismisses, with no confirmation even with a generated week unsaved.
- Keyboard toolbar: spacer + "Done", identifier `dismissRoutineKeyboard`.
- In the preview state: "Save templates" (confirmationAction), identifier `saveAIRoutine`, disabled after a save is in flight or done.
- Title: "Ask AI" while there is no routine, "Your week" when there is one. Large titles.

Child sheets:
- `AskAISettingsSheet` (Settings scope, also titled "Ask AI").
- `GymEditorSheet` ("New Gym"). On save it selects that gym here AND on the Start screen.
- `MachineEditorSheet(gym:, startsWithScanner: true)`: the scan flow, Gyms scope.

`.onDisappear` cancels. If the routine consent is revoked while the cover is open, it cancels and clears the routine.

### State A: no API key (lines 45-49)
Shown when `TerraAccess.client == nil` and not the fixture. A Form containing:
- the text "Add your OpenAI API key to create routines with Terra.";
- `Button` "Open AI Settings", identifier `routineAISettings`, which opens `AskAISettingsSheet`.
- **[J]** Three names for one feature: "Terra", "Ask AI" and "OpenAI". "Open AI Settings" reads like "OpenAI Settings". There is no explanation of what the feature does.

### State B: inputs (lines 81-139)
A Form with `.scrollDismissesKeyboard(.interactively)`.
1. **Section "Goals"**:
   - `TextField` placeholder "What would you like to work toward?", vertical, 3–6 lines, identifier `routineGoals`.
   - `Picker` "Experience": "Beginner" / "Intermediate" / "Experienced". Menu style, amber value.
   - `Stepper` "N days per week", 1...7, default 3.
   - `Stepper` "N minutes per session", 15...120, step 5, default 45.
2. **Section "Optional profile"**: `TextField` "Height (cm)" and `TextField` "Weight (kg)", both decimalPad. Always metric.
3. **Section "Equipment at <gym name>"**, or "Available equipment" when no gym:
   - `Picker` "Gym": "No gym" + gyms by name, identifier `routineGym`. Changing it also changes and remembers the Start screen's gym.
   - `Button` "Add Gym…" with `plus`, identifier `routineAddGym`.
   - If a gym is chosen: text "N saved machines" in secondary (identifier `routineMachineCount`) and `Button` "Scan Machine" with `camera.viewfinder` (identifier `routineScanMachine`). Otherwise the footnote "Choose or add a gym to save scanned machines."
   - 8 `Toggle`s: "Dumbbells", "Flat bench", "Adjustable bench", "Barbell, plates and rack", "Cable station and attachments", "Smith machine", "Pull-up bar", "Dip station". Identifiers `routineEquipment.<rawValue>` (dumbbells, bench, adjustableBench, barbellRack, cable, smith, pullupBar, dipStation).
4. **Section "Available cardio"**: 9 `Toggle`s, one per activity name. Identifiers `routineCardio.<rawValue>`.
5. **Last section:**
   - When consent is not yet given:
     - `Toggle` "Allow sending routine details to OpenAI", identifier `allowAIRoutine`.
     - Footnote "Sends these goals, experience, schedule, optional height/weight, and available exercise list to OpenAI. Your Health data and workout history are not sent. OpenAI’s API data policies apply."
     - `Link` "OpenAI data policies".
   - Error text in secondary (not red), identifier `routineAIError`.
   - `Button` "Generate week" with `sparkles`, identifier `generateAIRoutine`. Disabled when there is no consent, OR the goals are blank, OR there are no eligible exercises and no cardio. Eligibility = machines at the chosen gym + toggled equipment (`RoutineAvailability`).
   - Local validation error: "Use a goal under 1,000 characters and valid optional height/weight." (height 50–250, weight 20–400).

**[J]**
- 17 toggles in two long lists: a settings page, not a creative flow.
- Generate is at the very bottom, and there is no hint why it is disabled. The eligible exercise count is not shown.
- The error appears only at the bottom, above Generate, and may be off-screen after the state swap.
- Metric-only fields ignore the lb preference.
- The gym picker has side effects on the Start screen.
- Black system background, amber system controls: visually a different app.

### State C: generating (lines 50-54)
A centred VStack:
- `ProgressView` "Building your week…";
- `Button` "Back to preferences", which cancels.
The title stays "Ask AI". The fixture delay is 0.2 s, or 4 s with `-uiTestTerraSlow`. The real call time is unbounded.
**[J]** A bare spinner for a potentially long wait. No progress, no preview of what is sent, no animation. There is no transition between states; views swap instantly.

### State D: generation error (back to State B with `error` set)
Error messages the user can see:
- "Check your OpenAI key and model access in Settings."
- "OpenAI usage is limited. Check API credits or try again later."
- "OpenAI is unavailable (NNN). Try again later."
- "OpenAI took too long. Try again."
- "Could not reach OpenAI. Check your connection or continue manually."
- "AI could not help with this request. Change the request or continue manually."
- "AI returned an incomplete or invalid result. Try again or continue manually."
- "The routine must contain 1–7 sessions and match the requested week."
- "AI returned an invalid session. Try generating again."
- "AI returned unavailable equipment or invalid targets. Try generating again."
- "Check <day>: choose an available cardio activity and 1–180 minutes."
- "The suggested routine exceeds your session length. Try again or increase the time."
- "Add an OpenAI key in Settings."

### State E: week preview, title "Your week" (lines 140-155)
A List, default inset-grouped on black:
- An error text row at the top when a save failed.
- One `NavigationLink` row per session: session name (headline), then a caption "N exercise(s) · M cardio". Identifier `routineDay.<index>`.
- `Button` "Change preferences": clears the routine and error and returns to inputs. The generated week is discarded with no confirmation.
- Save failure errors, from `validated(edited: true)`:
  - "Each session needs a name, at least one activity, and no repeated strength exercise (up to 10 exercises and 3 cardio targets)."
  - "Check <day>: choose an available exercise, 1–10 sets, 1–50 reps and 0–600 seconds rest."
  - "Check <day>: …cardio…".
- Successful save: every session becomes a template, atomically, with `generatedForGymID` and `confirmedEquipment`. The cover dismisses. There is no success message, haptic or highlight; the new tiles simply appear alphabetised in the Start grid.

**[J]**
- The preview shows only counts: no exercises, muscles, duration or week rhythm. It is the least "AI-magical" moment and should be the most exciting one.
- "1 cardio" wording.
- No regenerate-one-day option.
- With 3 days the screen is 3 rows and a large void (capture `ai-week-preview-default.png`).

### State F: session editor, pushed `AIRoutineDayEditor` (lines 202-238)
Title "Edit session". Toolbar `EditButton` for reordering. A Form:
- `TextField` "Session name", with no section header.
- **Section "Strength"**. Per item:
  - `Picker` "Exercise": eligible options not already used in the day, names only.
  - `Stepper` "N sets", 1...10.
  - `Stepper` "N reps", 1...50.
  - `Stepper` "Ns rest", 0...600, step 15.
  - `Button` "Remove exercise", destructive.
  - Rows reorder with `onMove`.
  - `Button` "Add exercise" adds the first unused option with 3×10 and 60 s. It is disabled at 10 and hidden when no option is left.
- **Section "Cardio"**. Per item:
  - `Picker` "Activity", from the activities that were sent.
  - `Stepper` "N min", 1...180.
  - `Button` "Remove cardio".
  - `Button` "Add cardio" adds the first activity for 15 min. It is disabled at 3 and hidden when there are no activities.
- Edits bind live to the routine. There is no Save or Cancel; Back keeps the changes.

**[J]**
- Same stepper-heavy pattern as the template editor.
- "Add exercise" picks an arbitrary first option instead of opening a picker.
- The Exercise picker is a flat menu of names.
- Rest is in seconds.

### Consent revoked mid-flow
`onChange(of: consent)` cancels generation and clears the routine, returning to State B with the consent toggle shown again.

---

## 7. Save as Template (`Features/Templates/SaveAsTemplateFlow.swift:10-84`)

A `ViewModifier`, used by:
- `WorkoutFinishedSheet`: button "Save as Template", identifier `saveAsTemplate`;
- History `WorkoutDetailView`: toolbar menu item "Save as Template…" with `square.on.square`, identifier `saveAsTemplate`, shown only if `canSaveAsTemplate`.

Presentation: **alert** "Save as Template".
- `TextField` "Template name", prefilled on present with "Workout <medium date>", e.g. "Workout Sep 24, 2026". The date is the workout's start date.
- Buttons: "Save", disabled when the name is blank, and "Cancel".
- Message:
  - if the workout recorded cardio: "Saves lifting exercises, sets and target reps. Cardio, weights and rest times are not included.";
  - otherwise: "Saves exercises, sets and target reps — not weights or rest times."

Success: `onSaved(name)`. The callers then show "Saved as template “<name>”" with a checkmark. There is no navigation to the new template.

Failure: a second **alert** "Couldn't Save Template" with "OK". Messages:
- "Give the template a name and try again."
- "This workout has no completed sets or recorded cardio to save as a template."
- the cardio-targets validation text;
- "The template could not be saved: <error>".

What is actually captured (`WorkoutTemplates.swift:200-233`):
- completed sets become rep targets;
- superset grouping is kept;
- **planned rest (`entry.plannedRestSeconds`) is kept**;
- the free-weight tag is kept;
- **recorded cardio becomes planned cardio targets** (minutes, 1–180).

**[J]**
- The message copy contradicts the code: cardio IS saved as targets, and planned rest IS carried.
- A naming alert with a date default is a weak moment. There is no preview of what becomes the template and no chance to rename exercises.

---

## 8. Template drift dialog (`Features/Templates/TemplateDriftDialog.swift:13-32`)

A `confirmationDialog` with a visible title, "Update workout template?". Buttons, in order:
1. "Update Template" (`.updateTemplate`): the workout's structure wins (exercises, set count, grouping); old rep targets are kept where they match.
2. "Update Values Only" (`.updateValuesOnly`): only rep targets change, for matching rows.
3. "Update Both" (`.updateBoth`): the template becomes exactly what was completed.
4. "Keep Original" (`.keepOriginal`): the template is untouched, and the workout still finishes.
5. The caller's cancel label (cancel role): workout and template both untouched.

Two call sites:
- `WorkoutStartFlow`: message "The active workout differs from the template it started from. Choose how to save that template before starting the next workout.", cancel "Keep Current Workout".
- `ActiveWorkoutView:310` on Finish: message "This workout's completed exercises, set counts, or target reps differ from the template.", cancel "Keep Logging".

It is shown only if drift exists, something was completed, and "Suppress template update prompts" (Settings) is off.

**[J]**
- Five text buttons, where the difference between "Update Template", "Values Only" and "Both" is unexplained. Users cannot see what changed.
- There is no diff preview ("+1 set on Bench, Leg Press removed").
- There is no "don't ask again" in place; it is only in Settings.

---

## 9. Small shared pieces in scope

- **`BrowseMenuOption`** (`Features/BrowseMenuOption.swift:11-25`): a menu `Button` showing `Label(title, systemImage: "checkmark")` when selected, else `Text(title)`. It is deliberately not a `Picker`, so the checkmark and identifier stay controllable.
  - Used in the Gyms tab (machine list "Group Machines By"; model picker "Group By", "Body Area" with "All body areas", "Equipment Type" with "All types") and the Exercises tab ("Body Area", "Equipment Type"). It is not used on Start.
  - **[J]** The Start gym menu re-implements the same checkmark pattern inline.
- **`UnitBadge`** (`StartWorkoutView.swift:405-411`): a thin wrapper over `UnitChip`. It is also used in Gyms, History, the machine picker, the set row and Add by Machine.
- **`HeroCapsuleLabel`** (§2.3): used by Start (Start Lifting, Start Cardio, Resume) and Template Detail (Start).
- **`TemplateTile`** (private, §2.4).
- **`WorkoutStartRequest`** (`WorkoutStartFlow.swift:6-14`): `{ id: UUID, template?, cardioActivity? }`. Equality is by id, so a double tap fires twice.

---

## 10. Motion, haptics, Dynamic Type, Reduce Motion: summary for the scope

- **Motion:** only the Resume capsule's breathing dot, which is disabled under Reduce Motion.
  - No transitions on: Start idle↔live, AI state changes (inputs → spinner → preview), template save, delete, or tile appearance.
  - No press states on the capsules or tiles (`.plain`).
- **Haptics:** only `.workoutStart` on Start Lifting, triggered by the active-workout count; reliability is unverified. None on cardio start, template start, save, AI success or delete.
- **Timers:** none in scope. The AI fixture delay is test-only.
- **Dynamic Type:**
  - `ViewThatFits` for the Start/Cardio capsules (side by side → stacked).
  - One template column at accessibility sizes.
  - Gym card accessories stack.
  - `@ScaledMetric`: pin tile 44 (title2), capsule disc 40 and dot 9 (body), muscle icons 24/40 (title3).
  - The superset chip stacks above the name at AX sizes.
  - Template tile text is never truncated.
  - The Forms (editor, AI) rely on system behaviour.
  - The project gate is AccessibilityL captures.
- **Accessibility labels:**
  - gear "Settings";
  - superset chip "Superset position X";
  - muscle strip = family names;
  - capsules are combined elements;
  - tiles are `.contain`;
  - detail rows are combined.

---

## 11. Cross-cutting opportunities for the redesign **[J]**

1. **Start is a settings card plus two buttons plus a text grid.** Nothing is personal or motivating: no streak, no week at a glance, no "last workout", no suggested next template, no recent PRs. History and summary data exist elsewhere and could feed a hero.
2. **Templates show only names and exercise names.** Duration, set count, last performed, muscle balance and cardio would make them scannable. Tile heights are uneven and centred.
3. **The live state is weak:** a breathing dot on one capsule. There is nothing on the other tabs, and no elapsed time or heart rate.
4. **Editors are raw system Forms:** stepper walls, a 90-row exercise list, a hidden title, silent discard, system red, a black background. They are the least designed surfaces and break the theme.
5. **Ask AI is a long settings page:** 17 toggles, a spinner and a count-only preview. The flow could be conversational or stepped: goals → schedule → equipment chips → animated build → a rich week board with day cards and muscle maps.
6. **Unexplained destructive or complex choices:** the drift dialog (5 buttons, no diff), the resume dialog, and Delete placed next to Start.
7. **Copy defects to fix whatever the visual direction:**
   - "0 cardio activities" on Resume of an empty lifting workout;
   - "0 exercises" on cardio-only Start;
   - "at your gym" and "this gym" with no gym;
   - the Save as Template message contradicts behaviour;
   - rest shown as "60s" versus the m:ss policy;
   - the Terra / Ask AI / OpenAI naming.
8. **Feedback gaps:** no success moment after starting, saving a template, saving an AI week or deleting. Errors in the start flow are silent.
9. **Gym context:** the gym picker cannot add a gym; the gym card has an empty subtitle when there is no city; the unit chip is shown where it is irrelevant.

---

## 12. Flat checklist of every screen and state in scope

- [ ] App launch: no onboarding. Dark forced. Active-workout auto-recovery opens the full-screen workout.
- [ ] Tab bar: Workout / History / Gyms / Exercises. Selected tint amber. No live indicator.
- [ ] RootView full-screen cover: Active Workout (entry and exit paths only; content is another scope).
- [ ] RootView sheet: Workout Finished, saved state ("Nice work").
- [ ] RootView sheet: Workout Finished, discarded state ("Nothing logged").
- [ ] Start: toolbar gear → Settings (push).
- [ ] Start: gym card with a gym that has a city.
- [ ] Start: gym card with a gym without a city (empty subtitle).
- [ ] Start: gym card with "No gym" ("Home / no location").
- [ ] Start: gym card at AX sizes (accessories stacked).
- [ ] Start: gym Menu (No gym + gyms with checkmark). No gyms exist → only "No gym".
- [ ] Start idle: Start Lifting + Start Cardio side by side.
- [ ] Start idle: capsules stacked (labels don't fit / AX sizes).
- [ ] Start live: Resume workout capsule, lifting subtitle "<gym> · N exercises".
- [ ] Start live: Resume capsule, "In progress · …" (no gym).
- [ ] Start live: Resume capsule, cardio in progress (activity symbol and name).
- [ ] Start live: Resume capsule, empty lifting workout ("0 cardio activities" defect).
- [ ] Start live: breathing dot, and static under Reduce Motion.
- [ ] Start: Templates, empty (New Template tile only).
- [ ] Start: Templates, 1..n tiles, 2 columns, uneven heights.
- [ ] Start: Templates, 1 column at AX sizes.
- [ ] Start: template tile with no muscle family (core-only or cardio-only).
- [ ] Start: template tile including planned cardio names.
- [ ] Start: New Template… tile.
- [ ] Start: Ask AI for Templates button.
- [ ] Start: footer caption (with gym / "your gym").
- [ ] Cardio picker sheet: Gym + Outdoors sections, search, Cancel.
- [ ] Cardio picker: search with no results (empty sections).
- [ ] Start flow: direct start (no UI) → full-screen workout.
- [ ] Start flow: resume dialog "A workout is already in progress".
- [ ] Start flow: replacement drift dialog (cancel "Keep Current Workout").
- [ ] Start flow: silent failure (assertion only).
- [ ] Template Detail: muscle strip.
- [ ] Template Detail: exercise rows (targets, rest, superset chip).
- [ ] Template Detail: superset chip stacked at AX sizes.
- [ ] Template Detail: "No matching machine at this gym" row caption.
- [ ] Template Detail: unknown cardio footnote.
- [ ] Template Detail: Planned cardio section.
- [ ] Template Detail: "Created for another gym" footnote.
- [ ] Template Detail: cardio-only template ("0 exercises").
- [ ] Template Detail: pinned Start capsule + gradient.
- [ ] Template Detail: Start disabled (no items, no cardio).
- [ ] Template Detail: Start while a workout is live → resume dialog.
- [ ] Template Detail: Edit → editor sheet.
- [ ] Template Detail: Delete Template… button.
- [ ] Template Detail: Delete alert.
- [ ] Template Detail: deleted (blank, pops).
- [ ] Template Editor: New (empty, "Add at least one exercise below.").
- [ ] Template Editor: Edit existing.
- [ ] Template Editor: title hidden by EditButton; reorder mode ("Done").
- [ ] Template Editor: exercise block (sets, rest toggle, rest stepper, per-set targets, remove).
- [ ] Template Editor: Cardio targets (none / 1–3, distance on/off, cap at 3).
- [ ] Template Editor: unknown cardio lock message.
- [ ] Template Editor: Add Exercise full list.
- [ ] Template Editor: Save disabled states.
- [ ] Template Editor: save error text.
- [ ] Template Editor: Cancel / swipe-dismiss (silent discard).
- [ ] Ask AI A: no API key → "Open AI Settings" → AskAISettingsSheet.
- [ ] Ask AI B: inputs, Goals section (text, experience menu, days, minutes).
- [ ] Ask AI B: Optional profile (height/weight, metric).
- [ ] Ask AI B: Equipment, no gym (footnote).
- [ ] Ask AI B: Equipment, gym chosen (machine count, Scan Machine).
- [ ] Ask AI B: Add Gym… → New Gym sheet.
- [ ] Ask AI B: Scan Machine → Machine editor with scanner.
- [ ] Ask AI B: 8 equipment toggles.
- [ ] Ask AI B: Available cardio (9 toggles).
- [ ] Ask AI B: consent not given (toggle, disclosure text, policy link).
- [ ] Ask AI B: consent given (disclosure hidden).
- [ ] Ask AI B: Generate week disabled / enabled.
- [ ] Ask AI B: local validation error.
- [ ] Ask AI B: keyboard toolbar "Done".
- [ ] Ask AI C: generating ("Building your week…", "Back to preferences").
- [ ] Ask AI D: error returned (all the messages in §6 D).
- [ ] Ask AI E: "Your week" preview (day rows, Change preferences, Save templates).
- [ ] Ask AI E: save error at top of preview.
- [ ] Ask AI E: saving (Save disabled) → dismiss, with no success feedback.
- [ ] Ask AI F: Edit session (name, strength items, cardio items, add/remove, reorder, caps).
- [ ] Ask AI: consent revoked mid-flow → back to inputs.
- [ ] Ask AI: Cancel (no confirmation).
- [ ] Save as Template alert (two message variants), from the finish sheet and from History detail.
- [ ] Save as Template: success confirmation label on the caller.
- [ ] Couldn't Save Template alert.
- [ ] Drift dialog on Finish (cancel "Keep Logging").
- [ ] Drift dialog on replacement start (cancel "Keep Current Workout").
- [ ] Drift suppressed (Settings toggle) → no dialog.
- [ ] BrowseMenuOption, selected (checkmark) and unselected, in the Gyms/Exercises menus.
