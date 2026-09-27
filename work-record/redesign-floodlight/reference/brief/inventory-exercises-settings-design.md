# Inventory: Exercises, Settings and the design system

Repo: `/Users/ericlee06/orca/projects/Health App`, branch `ericlee4992/redesign-visual-proposal`, HEAD `a0364f2`
(clean). Read-only fact-finding: nothing was edited, built or run. Paths below are relative to
`WorkoutTracker/` unless they say otherwise. "Judgement:" marks UX opinion. Everything else comes
from source.

Covered: `Features/Exercises/*` (4 files), `Features/Settings/*` (5 files), `Features/Design/*`
(12 files), `Assets.xcassets`, `Resources/`. I also covered three views outside those folders
because screens in scope open them: `ExerciseRow` (`Features/ActiveWorkout/ExercisePickerSheet.swift:90`),
`MaxHeartRateSheet` (`Features/ActiveWorkout/MaxHeartRateSheet.swift`) and `ExerciseProgressView`
(`Features/History/ExerciseProgressView.swift`, which is also opened from History). `BrowseMenuOption`
(`Features/BrowseMenuOption.swift`) is covered too.

A preview of the five muscle maps, tinted as they are in the app, is at
`/private/tmp/claude-501/-Users-ericlee06-orca-projects-Health-App/9b9c73f6-8c92-4288-afac-39aaab9c7e79/scratchpad/brief/musclemaps-preview.png`.

Existing screenshots of these screens (older builds):
`work-record/ui-redesign/screenshots/11/07-exercises.png`, `.../11/07-exercises-axl.png` and
`.../05/05-settings.png`. The Settings capture predates `AppUnitSystem`: its picker shows "lb"
where current code shows "Metric" / "U.S. customary".

---

## 0. Constraints a redesign must reckon with

- **App shell** (`App/RootView.swift:38-58`): a `TabView` with 4 tabs. The tabs are "Workout"
  (`figure.strengthtraining.traditional`), "History" (`clock.arrow.circlepath`), "Gyms"
  (`building.2`) and "Exercises" (`list.bullet.rectangle`), in that order. `.tint(Theme.accent)` is
  set on the TabView. On iOS 26 it renders as the floating Liquid Glass tab bar (see the screenshot).
- **Dark only**: `App/WorkoutTrackerApp.swift:85` applies `.preferredColorScheme(.dark)`. Every
  colour asset has only an "Any" appearance.
- **D54** (`docs/DECISIONS.md:63`) locks in "One visual system, dark only, one warm accent, cards".
  Amber `#FFB45E` was the user's choice on 2026-09-10. D54 also says the redesign "adds shape,
  colour and motion — **never words**": every visible string and accessibility identifier that the
  UI tests read has to stay. The user now says the theme may change completely, so **D54 has to be
  explicitly reopened** (per AGENTS.md) for any change of palette, light mode or copy.
- **D52**: plain numbers on screen. No `≈` on converted weights, no "(estimated)" on a heart-rate
  maximum.
- **D24**: seeded exercises can't be renamed; only user-created ones can. Load type is editable on
  every exercise. **D23**: history is frozen snapshots.
- **UI-test-locked handles in scope** (from grepping `WorkoutTrackerUITests/`):
  - Strings the tests read: tab "Exercises"; the context-menu items "Presets…" and "Progress…"
    (the tests long-press the row, then tap them); "Done" on Presets; nav bar "Settings"; picker
    options "Metric" and "U.S. customary"; "Zones would use" and "Zone 3" on the Heart Rate sheet.
  - Identifiers the tests read: `openSettings`, `appUnitPreference`, `heartRateZonesSettings`,
    `exportSummary`, `exportCSV`, `exportFailure`, `newExerciseName`, `saveNewExercise`,
    `noPresets`, `preset.*`, `newPresetName`, `addPreset`, `presetSuggestion.*`, `askAIKeyField`,
    `maxHeartRateField`, `saveMaxHeartRate`, `progressEmpty`, `progressChart`, `chartSelection`,
    `chartVariationPicker`, `progressSinglePoint`.
  - The search field is found with `app.searchFields.firstMatch`, and rows with
    `staticTexts[exerciseName]`.
- `RedesignScreenshotUITests.swift` asserts that "Add Exercise" is reachable at AccessibilityL
  (line 185). Launch override: `PROTO_SCREEN=exercises` opens the Exercises tab
  (`RootView.swift:102-111`).

---

## 1. Design system (`Features/Design/*`, `Assets.xcassets`)

### 1.1 Colour tokens (`Design/Theme.swift:4-22` → `Assets.xcassets/Colors/*.colorset`, sRGB, Any appearance only)

| Token | Asset | Hex | Uses | Where used |
|---|---|---|---|---|
| `Theme.accent` | `AccentColor` (global accent) | `#FFB45E` amber | 45 | ButtonStyles, Chip, EmptyState, ProgressRing, StatTile default, ZoneColors (zone 4), ExercisesView (filter summary), ExerciseEntryCard, ExercisePickerSheet, ExerciseProgressView (chart line, area and point; the "Change" stat), GymsView, HeartRateSummarySection, HistoryCalendarSheet, RestTimerBar, RootView tint, StartWorkoutView, TemplateDetailView, WorkoutDetailView, WorkoutFinishedSheet |
| `Theme.onAccent` | `OnAccent` | `#15110B` near-black | 7 | ButtonStyles (primary label), selected Chip, ExerciseEntryCard, HistoryCalendarSheet, StartWorkoutView |
| `Theme.background` | `SurfaceBackground` | `#0B0D10` | 23 | every custom `List` background (ExercisesView, SettingsView, ExerciseProgressView, …) |
| `Theme.card` | `SurfaceCard` | `#171B21` | 21 | `.card()`, list row backgrounds (ExercisesView, ExerciseProgressView, GymsView, …) |
| `Theme.elevated` | `SurfaceElevated` | `#222831` | 1 | `.card(.elevated)` only: RestTimerBar, CardioViews:191 |
| `Theme.fill` | `SurfaceFill` | `#2B323C` | 10 | SecondaryButtonStyle background, ExerciseEntryCard fields, HeartRateBar, HistoryView, StartWorkoutView, WorkoutDetailView |
| `Theme.hairline` | `Hairline` | `#FFFFFF` @ 7% | 11 | card border, list separators (ExercisesView, ExerciseProgressView), chart gridlines |
| `Theme.text` | `TextPrimary` | `#F6F3EC` warm white | 17 | SecondaryButtonStyle label, entry cards, … |
| `Theme.secondary` | `TextSecondary` | `#B5B9C2` | 74 | default Chip tint, StatTile label, captions everywhere |
| `Theme.tertiary` | `TextTertiary` | `#7F8793` | 13 | "Custom" tag on the Exercises tab, the warm-up zone colour, footers |
| `Theme.danger` | `Danger` | `#FF6B76` coral red | 15 | zone 5, destructive or failure text (**not** used in Settings or Presets, which use system `.red`) |
| `Theme.warmup` | `Warmup` | `#E9D875` yellow | 1 | ExerciseEntryCard (warm-up set type) |
| `Theme.drop` | `Drop` | `#B8A1EE` lavender | 1 | ExerciseEntryCard (drop set) |
| `Theme.unitKg` | `UnitKg` | `#97C7EE` | 1 | `UnitChip` |
| `Theme.unitLb` | `UnitLb` | `#A8CDBF` | 1 | `UnitChip` |
| `Theme.unitMixed` | `UnitMixed` | `#B8A1EE` (**identical to Drop**) | 1 | HistoryView:247 mixed-unit badge |
| `Theme.muscleBody` | `MuscleBody` | `#5B6472` | 2 | the neutral body layer of `MuscleIcon` |

Hard-coded colours that live outside the tokens:

- Zone colours (`Design/ZoneColors.swift`): warm = `Theme.tertiary` `#7F8793`, Z1 `#8ABCE5`,
  Z2 `#80CABE`, Z3 `#A5CF9A`, Z4 = accent `#FFB45E`, Z5 = danger `#FF6B76`.
- Muscle family colours (§1.6).
- Calorie tint, which is inconsistent between screens: `#F4939C` in
  `WorkoutFinishedSheet.swift:258` and `#FF5E7A` in `WorkoutDetailView.swift:208,214`.
- Raw system colours in scope: `.red` at `ExportSection.swift:65` and `ExercisePresetsSheet.swift:75`;
  `.secondary` at `AppSettingsSection.swift:50,68,85`, `ExportSection.swift:41` and
  `AskAISettingsSheet.swift:23`; `.tint` at `NewExerciseSheet.swift:64`; `.primary` as a tint at
  `AppSettingsSection.swift:54,72`.

Judgement on colour:

- Several colours collide. `UnitMixed` and `Drop` are the same value. `UnitKg` `#97C7EE` is close to
  Zone 1 `#8ABCE5`. Zone 3 `#A5CF9A` is the old legs colour. Amber means both "accent / primary
  action" and "Zone 4", and it is also the tint for the "Assisted" and "BW + added" load chips.
- The palette is cool graphite plus one amber. Colour carries almost no meaning outside zones,
  muscles and set types.

### 1.2 Typography (`Theme.swift:36-39`)

Everything is system SF and scales with Dynamic Type.

| Token | Definition | Uses |
|---|---|---|
| `Theme.hero` | `.largeTitle`, rounded, **black** | 1: CardioViews only |
| `Theme.stat` | `.title2`, rounded, bold | 8: StatTile value, ExerciseProgressView "Change" %, ActiveWorkoutView, CardioViews, HeartRateBar, HistoryView, RestTimerBar, WorkoutFinishedSheet |
| `Theme.cardTitle` | `.headline` bold | 13: ExerciseRow name, EmptyState title, ZoneTimeCard title, … |
| `Theme.label` | `.caption2` semibold | 8: the "Custom" tag, … |

Everything else sets fonts inline (`.caption`, `.caption.weight(.semibold)`, `.footnote`,
`.subheadline`). Judgement: there is no display face and no numeric style beyond rounded plus
`monospacedDigit()`. Screen titles are system large or inline nav titles.

### 1.3 Spacing and radii (`Theme.swift:24-35`)

- `Radius.card 24`, used by `.card()`, GymsView, HistoryView and StartWorkoutView.
- `Radius.inner 16`, used by the button styles, CardioViews and HistoryView.
- `Radius.field 10`, used by ExerciseEntryCard only.
- `Space.xs 4`, `small 8`, `medium 12`, `inset 16`, `large 24`.
- Magic numbers also appear inside components: Chip padding 10/6; MuscleIcon corner 8 or 14;
  EmptyState spacing 20 with 128/96 circles; ZoneTimeCard bar height 12, gap 2, corner 3; StatTile
  HStack spacing 6; WrapLayout spacing 6/6.

### 1.4 Components

Each entry gives the file, its anatomy, and where it is used.

- **`.card(_ level: CardLevel = .standard)`**, `Design/CardStyle.swift:3-24`
  - Background is `Theme.card`, or `Theme.elevated` for `.elevated`. `RoundedRectangle(24)` with a
    1 pt `Theme.hairline` stroke border. No shadow and no material.
  - Used by StatTile, ZoneTimeCard, WorkoutFinishedSheet:72/304, RestTimerBar (`.elevated`),
    HeartRateBar:46, GymsView:108/336, MachineDeletion:84, ExerciseEntryCard:93, HistoryView:233,
    HistoryCalendarSheet:86, HeartRateSummarySection:93, StartWorkoutView:46/399 and
    CardioViews:191 (`.elevated`)/245.
  - Screens built from `List` (Exercises, Settings, Progress) don't use `.card()`. They get cards
    from `listRowBackground(Theme.card)` or from system inset-grouped rows.
- **`Chip<Content>`**, `Design/Chip.swift:3-16`
  - Params: `tint` (default `Theme.secondary`) and `selected`.
  - Style: `.caption` semibold, padding 10 h / 6 v, capsule. Unselected is tint-coloured text on
    tint at 12%. Selected is `onAccent` text on an accent fill.
  - Used by:
    - ExerciseRow: equipment tags in the default grey tint; the load-type badge in accent.
    - ActiveWorkoutView:424.
    - HeartRateBar:157 (zone chip).
    - ExerciseEntryCard:205 (preset chips, selectable, including "None") and :283 (superset member,
      selected).
    - HistoryView:247 (unit-mixed badge).
    - CardioViews:129 (zone).
    - WorkoutDetailView:143 (load-type badge).
    - GymsView:86 and :322 (model name).
    - TemplateDetailView:135 (superset label).
- **`UnitChip(unit:)`**, `Chip.swift:18-26`: a Chip tinted `unitKg` or `unitLb` showing "kg" or
  "lb". Used once, at StartWorkoutView:409.
- **`StatTile(value:label:symbol:tint:identifier:accessibilityText:)`**, `Design/StatTile.swift`
  - Layout: an HStack with an SF Symbol (caption semibold, tint) and a label (`.caption`, secondary,
    lineLimit 2, minimumScaleFactor 0.85). Under it, the value in `Theme.stat`, `monospacedDigit`,
    lineLimit 1, minimumScaleFactor 0.8. Padding 16, `.card()`, one combined a11y element with a
    custom label and identifier.
  - Used by WorkoutDetailView:197-213 ("Average", "Maximum", "Active calories", "Total calories";
    values like "142 BPM", "380 CAL") and WorkoutFinishedSheet:264.
- **`ProgressRing(progress:tint:lineWidth:)`**, `Design/ProgressRing.swift`
  - A track circle at tint 15% with a trimmed round-cap arc, rotated −90°.
  - Animates `.linear(0.5)` unless Reduce Motion is on. Hidden from accessibility.
  - Used by WorkoutFinishedSheet:52 (saved tick), ActiveWorkoutView:438 (per-exercise completed
    sets) and RestTimerBar:28.
- **`EmptyState(title:symbol:)`**, `Design/EmptyState.swift`
  - A 128 pt accent 12% stroke ring and a 96 pt accent 8% disc, with the SF Symbol in
    `.largeTitle` accent and a `sparkle` symbol (`.title3`) offset to (+46, −42). Title below in
    `Theme.cardTitle`. Spacing 20, padding 24.
  - The illustration sizes are fixed and don't scale with Dynamic Type. The title has no
    `multilineTextAlignment`, so a multi-line title is left-aligned under a centred graphic.
  - Used by:
    - ExercisePresetsSheet:40 ("No presets yet. Without any, this exercise is logged as one thing.",
      `slider.horizontal.3`).
    - GymsView:189, MachinePickerSheet:31 and AddByMachineSheet:55 ("No machines yet", `dumbbell`).
    - MachineDeletion:91 ("Nothing deleted", `trash`).
    - HistoryView:57 ("No workouts yet", `clock.arrow.circlepath`).
    - ExerciseProgressView:66 ("No sets logged yet" / "Nothing to chart here",
      `chart.xyaxis.line`).
    - CardioViews:71 ("Add cardio to this workout", `figure.run`).
- **Button styles**, `Design/ButtonStyles.swift`
  - `.primary`: subheadline bold, minHeight 52, horizontal padding 16, `onAccent` on an accent fill,
    radius 16. Disabled drops to 0.35 opacity. Pressed scales to 0.97 with `.snappy(0.2)`, skipped
    under Reduce Motion. Used by IdentifyEquipmentSheet:157, GymsView:56/196, CardioViews:186,
    WorkoutFinishedSheet:87, ActiveWorkoutView:417, RestTimerBar:43 ("Skip") and BarPickerSheet:61.
  - `.secondary`: subheadline semibold, minHeight 44, padding 12, `Theme.text` on `Theme.fill`,
    radius 16. Pressed drops the fill to 0.65 opacity. There is no scale animation. Used by
    CardioViews:189, WorkoutDetailView:252, MachineDeletion:80, MachinePickerSheet:38,
    WorkoutFinishedSheet:102, GymsView:58/876, ExercisePickerSheet:57, AddByMachineSheet:62/191,
    RestTimerBar:41 ("+15s"), ActiveWorkoutView:190/196/416, **ExercisesView:108 ("Add
    Exercise…")**, ExerciseEntryCard:88 and StartWorkoutView:89.
  - There is no tertiary, destructive or icon-button style.
- **`WrapLayout(spacing: 6, lineSpacing: 6)`**, `Design/WrapLayout.swift`: a flow layout.
  Children keep their ideal size and wrap to a new line instead of truncating. Used by ExerciseRow
  (chips) and MuscleFamilyStrip.
- **`MuscleIcon(family:size:)`** and **`MuscleFamilyStrip(families:size:)`**,
  `Design/MuscleGroupStyle.swift:32-86`
  - The tile is `@ScaledMetric(relativeTo: .title3)`, base 40 or 24.
  - It stacks two template images: the body in `Theme.muscleBody` and the muscle in the family
    colour. The map fills 86% of the tile. The tile background is the family colour at 16%, with
    radius 14, or 8 when size < 32.
  - The strip is a WrapLayout of icons with a single a11y label listing the families (for example
    "Chest, Back").
  - Used by StartWorkoutView:387 (template tile, 24 pt) and TemplateDetailView:39 (40 pt).
  - **They don't appear on the Exercises tab at all.** Ticket 11 removed per-row muscle icons at the
    user's request ("they don't match").
- **`ZoneTimeCard(seconds:)`**, `Design/ZoneTimeCard.swift`
  - Title "Time in zones" (`cardTitle`). A 12 pt stacked bar split per zone (widths from
    `ZoneBarLayout.widths`, gap 2, corner 3; hidden from accessibility). Under it, one row per
    zone: an 8 pt dot, `zone.label` in caption, and a trailing duration from `Format.duration`
    (`m:ss`) in caption semibold, `monospacedDigit`.
  - `.card()`, padding 16. Zones with 0 s are dropped.
  - Used by WorkoutFinishedSheet:250 and WorkoutDetailView:239.
- **Haptics**, `Design/Haptics.swift`
  - `.setComplete` = impact medium at 0.8 (ExerciseEntryCard:626).
  - `.restDone` = `.success` (ActiveWorkoutView:230).
  - `.workoutStart` = impact heavy at 0.8 (StartWorkoutView:171).
  - **Nothing in Exercises or Settings has haptics.**
- **`BrowseMenuOption(title:isSelected:action:)`**, `Features/BrowseMenuOption.swift`: a
  menu-row `Button` that shows `Label(title, systemImage: "checkmark")` when selected and plain
  `Text` otherwise. Used by the Exercises filter menu and GymsView's grouping and filter menus.

### 1.5 Motion and accessibility across the design system

- Reduce Motion is respected by ProgressRing and PrimaryButtonStyle. Nothing else in scope
  animates.
- Dynamic Type adaptations:
  - `@ScaledMetric` on MuscleIcon.
  - `dynamicTypeSize.isAccessibilitySize` in ExerciseRow: the load-type chip moves into the wrap
    flow.
  - StatTile uses `minimumScaleFactor`.
  - WrapLayout means nothing clips.
- There is no `ViewThatFits` in scope.

### 1.6 Muscle families (`Domain/MuscleFamily.swift` plus `Design/MuscleGroupStyle.swift:16-22`)

| Family | Seeded `muscleGroup` values mapped to it | Colour | Asset stem | SF Symbol |
|---|---|---|---|---|
| Chest | Chest | `#FF70B6` pink | `MuscleMaps/chest-*` (pecs) | none now |
| Back | Back | `#4EB9FF` blue | `back-*` (lats and traps, rear view) | none now |
| Shoulders | Shoulders | `#4DE0D4` teal | `shoulders-*` (deltoids) | none now |
| Arms | Biceps, Triceps, Forearms | `#B891FF` violet | `arms-*` (flexed arm, bicep) | none now |
| Legs | Quads, Hamstrings, Glutes, Hips, Calves | `#84D65A` green | `legs-*` (quads, front thighs) | none now |

- Core, Neck and Full Body map to **no family**, so they get no icon and no colour. `resolve()`
  falls back to chest.
- **SF Symbols per family were removed** in ticket 12 (commit `c0f62c2`). The user called them
  "inaccurate and mild". The history had these mappings:
  - Chest `figure.strengthtraining.traditional`
  - Back `figure.rower`
  - Shoulders `figure.arms.open`
  - Arms `dumbbell.fill`
  - Legs `figure.strengthtraining.functional`
- Before that, the old per-body-area set had 12 entries, including Core `figure.core.training`,
  Hamstrings `figure.flexibility`, Glutes `figure.cooldown`, Calves `figure.walk` and Hips
  `figure.pilates`.
- **Body-area vocabulary** (`Domain/CatalogBrowsing.swift:64-68`, head to toe): Chest, Back,
  Shoulders, Biceps, Triceps, Forearms, Neck, Quads, Hamstrings, Glutes, Hips, Calves, Core, Full
  Body.

### 1.7 Assets (`WorkoutTracker/Assets.xcassets`, 42 files)

- **Colours**: 16 colorsets under `Colors/` plus `AccentColor` at the root. Values are in §1.1.
  Only "Any" appearance, with no dark or light variants.
- **MuscleMaps** (a namespace folder, `provides-namespace: true`)
  - 10 imagesets: 5 families × 2 layers (`<family>-body`, `<family>-muscle`).
  - Each is a **single universal PNG, 512×512, with alpha** and `template-rendering-intent:
    template`, so it's a one-colour silhouette tinted in code. They are not PDF or SVG, and there
    are no @2x/@3x variants.
  - The body layer is the full figure outline with muscle definition cut in as transparent lines.
    The muscle layer is only the highlighted muscle shapes.
  - Chest, shoulders and back are torso crops. Arms is a flexed arm with a bicep. Legs is a
    thighs-to-feet front view.
  - Sizes: body 33–47 KB, muscle 6–22 KB.
  - Being raster templates, they cannot carry more than one colour per layer. A multi-muscle or
    heat-map body would need new assets or vector paths.
- **App icon**: `AppIcon.appiconset/AppIcon.png`, a single 1024×1024 universal PNG with no alpha.
  It shows a flat front-on dumbbell: two pairs of rounded plates in amber `#FFB45E` and a darker
  amber bar `#E0933D`, on near-black `#0A0A0C`. There are no dark, tinted or clear iOS 18+ icon
  variants and no Icon Composer `.icon` file.
- **Other assets**: none. There are no illustrations, onboarding art, custom fonts, Lottie files or
  sounds. The watch and widget targets have no asset catalogs of their own. The home-screen display
  name is "Workout" (`INFOPLIST_KEY_CFBundleDisplayName`).
- **`WorkoutTracker/Resources/SeedCatalog.json`** (467 KB, catalog `version 5`):
  - **90 exercises**. The comment in `ExercisesView.swift:23` still says 74, which is stale. Each
    has `id`, `name`, `loadType`, `equipmentTypeTags` and `muscleGroup`.
  - **1877 equipment models** from 23 manufacturers.
  - Exercises by muscle group: Chest 16, Back 16, Quads 14, Shoulders 8, Hamstrings 7, Glutes 5,
    Calves 5, Triceps 4, Core 4, Biceps 3, Hips 3, Forearms 2, Full Body 2, Neck 1.
  - Load types: weighted 80, bodyweightPlus 8, assisted 2, bodyweight 0.
  - Tags: machine 57, dumbbell 15, barbell 8, bodyweight 8, cable 7, smith 2. 83 exercises have one
    tag and 7 have two.
  - The longest name is "Dumbbell Romanian Deadlift" (26 characters). There are no images or
    descriptions per exercise.

### 1.8 Design-system judgements

- **Settings, New Exercise, Presets, Load Type, Ask AI and Heart Rate use no design-system
  components.** They are plain system `Form`/`List` with system inset-grouped rows. They don't set
  `Theme.background` or `Theme.card`; only SettingsView sets the background. So they look like
  stock iOS next to the carded tabs, and they're the most "boring" surfaces.
- The design system has **no** components for:
  - a section header or eyebrow
  - a list row or cell
  - a segmented control
  - a toggle or stepper skin
  - a destructive style
  - toasts or snackbars
  - a skeleton or loading state
  - an error banner
  - sheet headers
  - an icon badge or avatar
  - a chart style
  - a search field
- There is no motion vocabulary beyond press-scale and ring fill. Haptics exist for only three
  events.

---

## 2. Exercises feature

### 2.1 Exercises tab: `ExercisesView` (`Features/Exercises/ExercisesView.swift:7-232`)

- **Presentation**: tab root, the 4th tab "Exercises", inside its own `NavigationStack` (:50).
- **Job**: browse the whole exercise catalog (90 seeded plus user-created) and reach per-exercise
  tools (progress, presets, load type, rename) and exercise creation.
- **Data**: `@Query(sort: \Exercise.name)` gives one flat alphabetical list. It is filtered by
  `CatalogBrowsing.exercises` (:33-35) using search text (name only, token match) plus the
  persisted body-area and equipment-tag filters (`AppPreferences.exerciseBrowseMuscleGroup` and
  `exerciseBrowseEquipmentTag`, remembered between visits; search text is not remembered).
- **D24 filter rule**: a row that *lacks* a body area or tag is never hidden by that filter. A
  custom exercise without a muscle group shows under every body-area filter.

**Blocks, top to bottom:**

1. **Nav bar**
   - Large title "Exercises" (:118).
   - Trailing toolbar: filter menu (§2.2). Its icon is `line.3.horizontal.decrease.circle`, or the
     `.fill` variant when filters are active. Label "Filter", id `exerciseFilterMenu`.
2. **Search field**: `.searchable(text:prompt: "Search exercises")` (:117), system placement (under
   the large title in the capture).
3. **Active-filter summary row**, only when `filter.hasActiveFilters` (:52-65), in its own Section
   on `Theme.card`.
   - `Label(filterSummary, systemImage: "line.3.horizontal.decrease.circle.fill")`, `.caption`,
     accent. The summary is the body area and the equipment label joined with " · ", for example
     "Chest · Machine".
   - Trailing `Button("Clear")`, caption semibold, id `clearExerciseFilters`. Clears both filters.
4. **Exercise section** (:66-113), rows on `Theme.card` with `Theme.hairline` separators. Each row
   is an HStack:
   - `ExerciseRow(exercise:)` (`ExercisePickerSheet.swift:90-148`):
     - Name in `Theme.cardTitle`.
     - Under it, a WrapLayout of:
       - the body area as `.caption` secondary text (for example "Chest")
       - one grey `Chip` per equipment tag: "Machine", "Barbell", "Dumbbell", "Cable", "Smith
         machine" or "Bodyweight"
       - at accessibility sizes, the load-type chip.
     - Trailing, when not at accessibility size and `loadType != .weighted`: an accent `Chip` with
       the load badge ("Bodyweight", "BW + added" or "Assisted"). Weighted shows no badge.
     - `.padding(.vertical, 2)`.
   - For user-created rows, a trailing `Text("Custom")` in `Theme.label`, tertiary (:70-75).
   - **Row tap does nothing.** There is no NavigationLink and no tap gesture. Every per-exercise
     action is behind a long-press `.contextMenu` (§2.3). There are no swipe actions.
5. **No-results row**, when `filtered.isEmpty` (:100-104): `Text("No exercises match")`, secondary,
   id `noExercisesMatch`, a plain row inside the same card. There is no illustration.
6. **"Add Exercise…" button** (`systemImage: "plus"`, `.buttonStyle(.secondary)`, clear row
   background, insets 8/0/8/0; :105-110). It is the **last row of the list**, after all 90+
   exercises. It opens the New Exercise sheet (§2.5).

**States that change the layout:**

- Default: all rows, no summary row.
- Filters active: summary row plus a filled filter icon.
- Search or filter with no match: the "No exercises match" row, then Add.
- Custom exercise row: the "Custom" tag.
- Non-weighted exercise: the load chip.
- Accessibility sizes: the load chip moves into the wrap flow (`07-exercises-axl.png`).
- There is no loading state; `@Query` is synchronous.
- There is no "no exercises at all" state. It can't happen because of the seed.

**Sheets and alerts hung on this screen (:124-156):**

- `.sheet(isPresented: $showingAddExercise)` shows `NewExerciseSheet()`.
- `.sheet(item: $presetsExercise)` shows `ExercisePresetsSheet`.
- `.sheet(item: $loadTypeExercise)` shows `EditExerciseLoadTypeSheet`.
- `.sheet(item: $progressExercise)` shows `NavigationStack { ExerciseProgressView(exerciseID:,
  exerciseName:) }`.
- `.alert("Rename Exercise")` (§2.4).

**Motion and haptics**: none. There's no row animation on filter change and no haptic.

**Accessibility identifiers**: `clearExerciseFilters`, `noExercisesMatch`, `exerciseFilterMenu`,
`exerciseFilter.bodyArea.all`, `exerciseFilter.bodyArea.<Area>`, `exerciseFilter.tag.all` and
`exerciseFilter.tag.<rawValue>` (machine, barbell, dumbbell, cable, smith, bodyweight).

**Judgement:**

- **Discoverability is the biggest problem.** Progress, Presets, Load type and Rename are only
  reachable by long-press, and nothing on screen hints at them. There's no exercise detail screen.
  Tapping a row does nothing, which reads as broken.
- **"Add Exercise…" sits at the bottom of a 90-row list**, so creating an exercise means scrolling
  to the end. It belongs in the toolbar or in a floating button.
- It's a flat 90-row alphabetical list with no section headers, no A–Z index and no grouping by body
  area, although the domain has `BodyArea.order`. Muscle colours and maps exist but aren't used
  here.
- Nothing on a row says anything about the user's own relationship with the exercise: no last
  performed, best set or record, session count, presets count, or sparkline. Each row is catalog
  metadata only.
- The body area is plain grey text inside the same flow as the grey chips, so the hierarchy is
  weak.
- "Bodyweight" appears as both an equipment tag and a load badge ("Bench Crunch" shows a
  "Bodyweight" chip and a "BW + added" chip), which is confusing.
- Amber load chips compete with amber actions.
- "Custom" is a tiny tertiary caption at the trailing edge. On non-weighted rows it sits after the
  load chip.
- The filters are hidden two menus deep (Filter → Body Area → area). Horizontally scrolling filter
  chips would be more direct and more "interactive".
- The filter summary row duplicates what a chip bar would show.
- The empty result is a bare grey sentence with no suggestion. It could offer "Create
  '<query>'", as the mid-workout picker does.

### 2.2 Filter menu (toolbar `Menu`, `ExercisesView.swift:160-197`)

- **Presentation**: a toolbar menu. It's reached by tapping the trailing filter icon.
- **Blocks**:
  - Submenu "Body Area":
    - "All body areas" (checkmark when none is selected; id `exerciseFilter.bodyArea.all`).
    - One option per body area present in the data, in head-to-toe order: Chest, Back,
      Shoulders, Biceps, Triceps, Forearms, Neck, Quads, Hamstrings, Glutes, Hips, Calves, Core,
      Full Body, then any unknown areas alphabetically. Ids are `exerciseFilter.bodyArea.<area>`.
  - Submenu "Equipment Type":
    - "All types" (`exerciseFilter.tag.all`).
    - "Machine", "Barbell", "Dumbbell", "Cable", "Smith machine", "Bodyweight"
      (`exerciseFilter.tag.<raw>`).
  - When filters are active: `Button("Clear Filters", systemImage: "xmark.circle")`.
- **Semantics**: single-select per dimension. Each choice writes `AppPreferences` immediately, so it
  persists.
- **Judgement**: two nested menus, with no counts per option.

### 2.3 Row context menu (`ExercisesView.swift:76-98`)

- **Presentation**: a long-press context menu with a system preview of the row.
- **Items, in order**:
  1. `Button("Progress…", systemImage: "chart.xyaxis.line")` opens the Progress sheet (§2.8).
  2. `Button("Presets…")` opens the Presets sheet (§2.6). No icon.
  3. `Button("Load type…")` opens the Load Type sheet (§2.7). No icon. Offered on seeded exercises
     too (D24 amendment).
  4. `Button("Rename…")` opens the Rename alert (§2.4). No icon. **Only on user-created rows.**
- **Missing**: there's no delete or archive for custom exercises anywhere in the UI, and no way to
  edit equipment tags or the body area after creation.
- **Judgement**: only the first item has an icon, which is inconsistent.

### 2.4 "Rename Exercise" alert (`ExercisesView.swift:145-156`)

- **Presentation**: a system `.alert` with a text field. It's reached from context menu →
  "Rename…" on a custom exercise.
- **Blocks**: title "Rename Exercise"; `TextField("Name", text:)` prefilled with the current name;
  `Button("Save")`; `Button("Cancel", role: .cancel)`.
- **Semantics**:
  - Save trims whitespace. An empty or seeded name is ignored silently. There is no
    duplicate-name check.
  - Errors only `assertionFailure`, so nothing is shown to the user.
  - No message line. No accessibility identifiers.

### 2.5 "New Exercise" sheet: `NewExerciseSheet` (`Features/Exercises/NewExerciseSheet.swift:25-122`)

- **Presentation**: a sheet (large detent by default) containing a `NavigationStack` with a system
  `Form`.
- **Reached from**:
  - the Exercises tab "Add Exercise…" (:124)
  - the mid-workout `ExercisePickerSheet.swift:74`, prefilled with the unmatched search text
  - `AddByMachineSheet.swift:203`, prefilled and linked to an equipment model via `linkTo`.
  The last two pass `onCreate`, which selects the new exercise straight into the workout.
- **Job**: create a user exercise (`isSeeded == false`).

**Blocks:**

1. Nav: inline title "New Exercise".
   - Leading `Button("Cancel")` dismisses without saving.
   - Trailing `Button("Add")`, id `saveNewExercise`, disabled while the trimmed name is empty.
2. Section: `TextField("Name")`, id `newExerciseName`. Prefilled from `initialName` once, on
   appear.
3. Section: `Picker("Load type")`, id `newExerciseLoadType`, in the default Form picker style (a
   trailing menu on iOS 26). Options are "Weighted", "Bodyweight", "BW + added" and "Assisted";
   the default is Weighted. Footer: "Assisted machines count lower weight as harder — pick
   carefully, records depend on it."
4. Section with header "Equipment": 6 plain buttons ("Machine", "Barbell", "Dumbbell", "Cable",
   "Smith machine", "Bodyweight"). Each toggles a trailing `checkmark` in `.tint` (amber).
   Multi-select.

**Semantics**:

- Add creates the exercise through `EquipmentLifecycle.createExercise`, with tags ordered by the
  enum. It then calls `onCreate` and dismisses.
- Errors only `assertionFailure`, with no UI.
- **There's no body-area/muscle field, although `createExercise` accepts `muscleGroup:`
  (`Domain/EquipmentLifecycle.swift:93`).** So custom exercises never get a body area. They show
  no area caption and slip through every body-area filter.
- No duplicate-name warning.

**States**: Add enabled or disabled. Nothing else changes the layout.

**Judgement**:

- The most consequential choice (load type) is a small trailing menu, and its meaning is explained
  only in one generic footer. The Load Type sheet (§2.7) has better per-option explanations.
- Equipment is a long list of checkmark rows where chips would fit.
- There's no preview of the resulting row.

### 2.6 Presets sheet: `ExercisePresetsSheet` (`Features/Exercises/ExercisePresetsSheet.swift:11-175`)

- **Presentation**: a sheet containing a `NavigationStack` with a system `List` (no `Theme`
  background). It's reached from context menu → "Presets…" (seeded or custom exercises).
- **Job**: manage the named variations (grip, stance, single or double) that split an exercise's
  history (D36–D38).
- **Data**: `exercise.presets` sorted by `(order, name)`.

**Blocks:**

1. Nav: inline title = **the exercise name**.
   - Leading `EditButton()` ("Edit"/"Done"; enables reorder and delete handles).
   - Trailing `Button("Done")` dismisses.
2. Section with header "Presets":
   - **Empty state**: `EmptyState(title: "No presets yet. Without any, this exercise is logged as
     one thing.", symbol: "slider.horizontal.3")`. Id `noPresets`, clear background, no separator.
   - Otherwise one `Text(preset.name)` per preset, id `preset.<name>`.
     - Context menu: `Button("Rename…")` opens the Rename Preset alert; `Button("Delete", role:
       .destructive)`.
     - `.onMove` (drag to reorder in edit mode) and `.onDelete` (swipe-to-delete, and the edit
       mode minus button).
3. Section with header "Add":
   - An HStack with `TextField("New preset (e.g. Wide grip)")`, id `newPresetName`. Return key
     submits.
   - `Button("Add")`, id `addPreset`, disabled unless `ExercisePresets.isValid` (non-empty and not
     a duplicate).
   - Duplicate state: a caption in **system `.red`**: "<Name> is already a preset here."
4. Section with header "Common", shown only while unused suggestions remain: one `Button` per
   suggestion, id `presetSuggestion.<s>`. Tapping adds it immediately. The suggestions are "Wide
   grip", "Narrow grip", "Neutral grip", "Reverse grip", "Single arm", "Single leg", "Double leg",
   "High pulley", "Low pulley", "Feet high" and "Feet low".

**"Rename Preset" alert** (:102-114):

- `TextField("Name")` prefilled, `Button("Save")`, `Button("Cancel", role: .cancel)`.
- Message: "Logged sets keep the old name."
- An invalid or duplicate name is ignored silently.

**Semantics**: every change saves immediately; "Done" is just close, and there's no cancel.
Deleting renumbers the order.

**States**:

- Empty: illustration.
- With presets.
- Edit mode: reorder and delete handles.
- Duplicate typed: red warning, Add disabled.
- All suggestions used: the "Common" section disappears.

**Judgement**:

- The empty-state title is a long two-sentence headline, left-aligned under a centred graphic.
- Suggestions are 11 full-width list rows; a tappable chip cloud would be far more compact and fun.
- The raw `.red` isn't the theme's danger colour.
- The title (exercise name) is the only context. There's no "used in N sessions" per preset.
- Having "Edit" and "Done" at the same time is confusing: two different "Done" meanings appear
  when edit mode is on.

### 2.7 Load Type sheet: `EditExerciseLoadTypeSheet` (`Features/Exercises/EditExerciseLoadTypeSheet.swift:13-112`)

- **Presentation**: a sheet containing a `NavigationStack` with a system `Form`. It's reached from
  context menu → "Load type…".
- **Job**: correct an exercise's load type, which changes how future records rank. History isn't
  rewritten.

**Blocks:**

1. Nav: inline title "Load Type".
   - Leading `Button("Cancel")`.
   - Trailing `Button("Save")`, id `saveLoadType`, disabled while the selection equals the
     original.
2. Section:
   - Header: the exercise name, or "" if the exercise was deleted.
   - `Picker("Load type")` in `.inline` style (4 rows with a checkmark): "Weighted",
     "Bodyweight", "BW + added", "Assisted". Id `editLoadTypePicker`.
   - Footer: the explanation for the *selected* type:
     - Weighted: "More weight is harder. Records rank the heaviest set."
     - Bodyweight: "Your body is the load. Log reps alone — no weight needed."
     - BW + added: "Your body plus any weight you add. Enter 0 for a plain set."
     - Assisted: "The machine takes weight off you, so LESS assistance is harder. Records rank the
       least assistance, and 0 means unassisted. This is the setting for supported dips and
       pull-ups."
3. Section "What this changes", **only when the selection differs from the original**:
   - `Label("Sets you log from now on are judged as <Badge>.", systemImage:
     "arrow.forward.circle")`.
   - `Label("<N> set(s) already logged keep the type they were logged under. History is frozen on
     purpose (D23) — this does not rewrite the past.", systemImage: "clock.arrow.circlepath")`, id
     `editLoadTypeHistoryNote`. N counts non-deleted sets on snapshotted entries.

**Semantics**: Save sets `loadType` and `loadTypeUserOverridden = true`, then dismisses. Cancel
discards.

**States**: unchanged (Save disabled, no impact section) and changed (impact section appears). If
the exercise was deleted, the header is empty and Save just dismisses.

**Judgement**:

- **An internal decision-log ID "(D23)" is shown to the user.**
- "LESS" is in all caps.
- The load types are strong candidates for illustrated cards, for example a direction arrow for
  "higher is better" versus "lower is better".

### 2.8 Progress sheet: `ExerciseProgressView` (`Features/History/ExerciseProgressView.swift:15-465`)

- **Presentation**: a sheet containing a `NavigationStack`, from Exercises context menu →
  "Progress…". History pushes the same view (`WorkoutDetailView.swift:299`) with
  `initialVariation`.
- **From Exercises the sheet has no Done or close button.** The view defines no toolbar, so the
  only way out is to swipe down.
- **Job**: chart one exercise's history per variation (load type × equipment × preset, never
  pooled, per D36).
- **Data**:
  - Finished-workout `SetRecord`s whose entry snapshot matches the exercise ID. Everything is
    fetched synchronously in `body`.
  - Series from `ProgressSeriesMath`. Units are the app default via `UnitPrecedence`.

**Blocks:**

1. Nav: inline title = the exercise name. List on `Theme.background`, rows on `Theme.card`.
2. **Variation picker**, only when more than one variation exists (:55-60): `Picker("Variation")`
   in `.menu` style, id `chartVariationPicker`. Options read "<label> · N day(s)" or "<label> ·
   nothing eligible". Example labels: "Machine · Gym", "No equipment recorded", "Dumbbell · Wide
   grip".
3. State switch on `series.confidence`:
   - **Empty** (:62-78): `EmptyState(title: "Nothing to chart here"` when multi-variation, otherwise
     `"No sets logged yet"`, `symbol: "chart.xyaxis.line")`, plus a subheadline secondary centred
     description:
     - Multi-variation: "No eligible sets under <variation>. Warmups do not count. Pick another
       variation above."
     - Otherwise: "Log <Exercise> in a workout and its progress appears here."
     Id `progressEmpty`.
   - **Single** (:79-85): Section with header "One session" and
     `LabeledContent(<date abbreviated>) { "<as-entered>" }`, id `progressSinglePoint`. Example:
     "Sep 3, 2026 — 135 lb × 8"; bodyweight shows "12 reps"; missing values show "—".
   - **Series** (:86-117):
     - `Picker("Metric")` in `.segmented` style. "Best set", "Volume" and "1RM" for weighted;
       only "Best set" otherwise.
     - Swift Chart, 240 pt tall, id `progressChart`: monotone `AreaMark` (accent gradient from 35%
       to 0), `LineMark` (accent, 2.5 pt, round caps) and `PointMark`s.
     - Selection shows a `RuleMark` (secondary at 50%) and an enlarged point (symbolSize 140).
     - Gridlines in hairline, secondary axis labels, X axis about 4 marks.
     - Y-axis label: "Weight (lb)", "Added weight (lb)", "Assistance (less is better) (lb)",
       "Reps", "Volume (lb)" or "1RM (lb)".
     - A drag or tap overlay (`DragGesture(minimumDistance: 0)`) selects the nearest day.
     - Selection row: `LabeledContent(<date>) { value }`, id `chartSelection`. It falls back to
       the last session. Best set shows as entered ("135 lb × 8"); volume and 1RM use
       `WeightMath.displayLabel` ("9740 lb").
     - Footer, only when days < 4: "Only N days logged — read the shape with caution."
     - Section "Change" (when computable): `LabeledContent("Since first session") { "+12%" }` in
       `Theme.stat`, accent when ≥ 0, secondary when negative.

**Motion and haptics**: none. There's no chart draw-in animation and no haptic on scrub.

**Judgement**:

- There's no close button in the Exercises presentation.
- The empty state is text-heavy.
- It shows no records, PR badges, recent sessions list, or set table. It's the natural core of an
  exercise detail screen the app lacks.

---

## 3. Settings feature

### 3.1 Entry point

- There's a gear on the **Workout tab only**: a `NavigationLink { SettingsView() }` with label
  `Image(systemName: "gearshape")`, `accessibilityLabel("Settings")` and id `openSettings`
  (`Features/Start/StartWorkoutView.swift:107-117`, topBarTrailing).
- It's a **push**, not a sheet. There's no other way to reach Settings, from other tabs or anywhere
  else.

### 3.2 Settings screen: `SettingsView` (`Features/Settings/SettingsView.swift:8-19`)

- **Presentation**: pushed onto the Workout tab's stack.
- **Nav**: inline title "Settings", back chevron.
- `List { AppSettingsSection(); ExportSection() }`, with `.scrollContentBackground(.hidden)` on
  `Theme.background`. The rows keep the **system** inset-grouped cell colour. The screenshot shows
  about `#1C1C1E` cells with a large radius, not `Theme.card`.
- **Job**: app-wide preferences and data export.

#### Section 1: `AppSettingsSection` (`AppSettingsSection.swift:9-180`)

There's no header; the code comment says the title already says "Settings". Rows in order:

1. **`Picker("App unit preference")`**, `.menu` style, id `appUnitPreference`.
   - Options "Metric" and "U.S. customary". The selection shows at the trailing edge in amber with
     an up/down chevron.
   - Writes `AppPreferences.unitPreference` (kg or lb). It falls back to the locale.
2. **`Stepper("Working rest · 2:00")`**: range 0…600 s, step 15. The value is formatted `m:ss` by
   `Format.duration`, so 0 shows as "0:00". It writes `globalWorkingRestSeconds` (default 120). No
   id.
3. **`Stepper("Warmup rest · 1:00")`**: same range and step; writes `globalWarmupRestSeconds`
   (default 60). No id.
4. **`Toggle("Suppress template update prompts")`**: writes `driftPromptSuppressed`. No id, and no
   explanation of what the prompts are.
5. **Button → `LabeledContent("Heart rate zones") { "Not set" | "184 bpm" }`**
   - Id `heartRateZonesSettings`, `.tint(.primary)`, value in `.secondary`.
   - The value is the resolved maximum: measured wins over 220−age from the date of birth. It's
     unlabelled per D52.
   - Opens the `MaxHeartRateSheet` sheet (§3.3). The sheet hangs off the row because a sheet on a
     Section never presents.
6. **Button → `LabeledContent("Ask AI about plates") { "On" | "Off" }`**
   - Id `askAISettings`. Opens the `AskAISettingsSheet` sheet (§3.4).
   - On dismiss it re-reads the keychain to refresh On/Off.
7. **Conditional `LabeledContent("History update")`**, id `dumbbellMoveNote`. Shown only if the
   one-time dumbbell history migration moved sets. It reads "<N> set(s) moved to dumbbell exercises
   · <Sep 12, 2026>", trailing-aligned.

Rows have no icons and no chevrons: the two buttons look like static value rows.

#### Section 2: `ExportSection` (`ExportSection.swift:9-117`)

- **Header** "Export". **Footer** "This phone holds the only copy until you export." Code comment:
  "The one line this section must keep saying".
- Rows:
  1. **Summary text** (`.footnote`, `.secondary`, id `exportSummary`).
     - While counting: "Counting…".
     - Then, for example, "87 workouts · 1,234 sets", with " (1,200 completed)" appended when the
       completed count differs. It uses singular "workout"/"set" for 1.
     - Refreshed in `.task` on every push and after each export.
  2. **`Label("Export CSV", systemImage: "square.and.arrow.up")`** button, id `exportCSV`.
  3. **`Label("Export JSON", systemImage: "square.and.arrow.up")`** button, id `exportJSON`.
     These two render in amber, from the tint.
  4. **Failure row**, only on error: `Label("Export failed: <error>", systemImage:
     "exclamationmark.triangle")`, footnote, **system `.red`**, id `exportFailure`. A count failure
     shows "Could not count what there is to export: <error>" in the same row.
- **Action**: tapping a format synchronously builds a snapshot, writes a file named
  `workout-tracker-YYYY-MM-DD-HHMM.csv|json` and presents `ShareSheet`.

**`ShareSheet`** (`ShareSheet.swift`) is `UIActivityViewController` presented as a `.sheet(item:)`
hung off the summary row. The system share sheet offers "Save to Files → iCloud Drive" and so on.
The staged file is deleted when the activity finishes (shared, saved or cancelled).

**Settings states:**

- Summary: "Counting…", then the counts.
- Export failure row, and count failure.
- Share sheet up.
- Dumbbell note present or absent.
- Heart-rate value "Not set" or "N bpm".
- Ask AI "On" or "Off".
- There's no progress indicator during export; it's synchronous on the main thread.

**Motion and haptics**: none.

**Judgement**:

- **Settings is the plainest screen in the app.** It's a stock iOS list with no icons, no grouping
  headers (unit, rest, prompts, heart rate and AI are all in one headerless block) and no
  explanatory footers for the toggle or the steppers.
- The label "Ask AI about plates" is stale. Per its own sheet footer, AI now also drafts routines
  and suggests exercises.
- The rest steppers show "m:ss" with no way to type a value, and 0 has no stated meaning.
- The unit row says "App unit preference", which is jargon.
- The backup footer is important safety copy rendered as tiny grey text. Export has no "last
  exported" date. There's no import or restore.
- There is no:
  - HealthKit, notification or Watch permission status or links
  - About or version row
  - gym management link or default gym
  - appearance option (dark is forced)
  - app icon choice.
- Settings is only reachable from one tab.

### 3.3 Heart Rate sheet: `MaxHeartRateSheet` (`Features/ActiveWorkout/MaxHeartRateSheet.swift:11-102`)

- **Presentation**: a sheet containing a `NavigationStack` with a system `Form`.
- **Reached from**: Settings → "Heart rate zones" row, and from the live workout heart-rate bar's
  "· edit zones" / "· set up zones" (`ActiveWorkoutView.swift:353`).
- **Job**: set a measured maximum heart rate and/or a date of birth. Zones derive from the
  maximum.

**Blocks:**

1. Nav: inline title "Heart Rate".
   - Leading `Button("Cancel")`.
   - Trailing `Button("Save")`, id `saveMaxHeartRate`, always enabled.
2. Section with header "Measured maximum": `TextField("Maximum heart rate")`, number pad, id
   `maxHeartRateField`.
3. Section with header "Date of birth": `Toggle("Use my date of birth")`, id `useBirthDate`. When on,
   a `DatePicker("Date of birth", displayedComponents: .date)` appears. It defaults to **Jan 1,
   1970** when no date is stored.
4. Section "Zones would use", only when a maximum resolves:
   - `LabeledContent("Maximum") { "184 bpm" }`.
   - Then "Zone 1" … "Zone 5", each with "<lower bound>+ bpm" in `monospacedDigit`. The lower
     bounds are 55%, 65%, 75%, 85% and 95% of the maximum.

**Semantics**:

- Save writes both fields and dismisses. A non-numeric or non-positive value clears the measured
  field silently. Cancel discards.
- A measured value always wins over the date of birth, but the screen doesn't say which one is in
  effect (per D52).

**States**:

- Nothing set: no preview section.
- Measured only.
- Date of birth only.
- Both.
- Toggle off: the DatePicker is hidden.

**Judgement**:

- The zones preview is a plain text table. It's the obvious place for the zone colours: a coloured
  zone ladder or bar.
- The screen doesn't reveal which source is active.
- The number-pad field has no Done key, although Save sits in the nav bar.

### 3.4 Ask AI sheet: `AskAISettingsSheet` (`Features/Settings/AskAISettingsSheet.swift:8-78`)

- **Presentation**: a sheet containing a `NavigationStack` with a system `Form`.
- **Reached from**: Settings → "Ask AI about plates"; the scanner's "Open AI Settings" button
  (`IdentifyEquipmentSheet.swift:41,63`, id `scannerAISettings`, which re-runs identification on
  dismiss); and the AI routine sheet's "Open AI Settings" (`AIRoutineSheet.swift:48,70`, id
  `routineAISettings`), whose prompt reads "Add your OpenAI API key to create routines with Terra."
- **Job**: consent to what is sent to OpenAI, and store or remove the user's own API key.

**Blocks:**

1. Nav: inline title "Ask AI"; trailing `Button("Done")` only. There's no Cancel, because toggles
   apply immediately.
2. Section:
   - `LabeledContent("Ask AI") { "On" | "Off" }`, id `askAIStatus`.
   - Footer: "GPT-5.6 Terra identifies equipment and drafts weekly routines and suggests exercises
     from model details. Photos and routine details are sent to OpenAI only with your permission.
     API usage is billed to your key. OpenAI may retain data under its API policies."
3. Section "Permissions":
   - `Toggle("Send equipment photos to OpenAI")`, `@AppStorage "openai.photoConsent.v1"`.
   - `Toggle("Send routine details to OpenAI")`, `"openai.routineConsent.v1"`.
   - `Toggle("Send model details to OpenAI")`, `"openai.exerciseConsent.v1"`.
   - `Link("OpenAI API data policies")` to `https://developers.openai.com/api/docs/guides/your-data`
     (opens Safari).
   - No identifiers on the toggles.
4. Section with header "Key":
   - `SecureField`. Its placeholder is "OpenAI API key", or "Replace the saved key" when a key
     exists. No autocapitalisation or autocorrect. Id `askAIKeyField`.
   - `Button("Save key")`, id `askAISaveKey`, disabled while the field is blank.
   - When a key exists: `Button("Remove key", role: .destructive)`, id `askAIRemoveKey`. **It
     deletes immediately, with no confirmation.**
   - Footer: "Kept in this phone’s keychain only. Private trial: use your own OpenAI API key.", or
     the save error's `localizedDescription` if saving failed.

**States**:

- Key absent: Off, "OpenAI API key" placeholder, no Remove.
- Key present: On, "Replace…" placeholder, Remove shown.
- Save failure: the error replaces the footer.
- Consent toggles on or off, in any combination.

**Judgement**:

- The key is never shown back, which is fine, but there's no masked hint like "sk-…a1b2" and no
  "test key" action.
- The long consent footer is a wall of text.
- The status row duplicates the Settings row.
- The error shows in a footer, not as a visible banner.
- The three consent toggles have no icons or examples of what gets sent.

---

## 4. Cross-cutting UX judgements, most important first

1. **Exercises has no detail screen and hides every action behind long-press.** A redesign should
   add a tappable exercise detail that merges Progress, Presets, Load type, Rename, records and
   history. Tests currently long-press and tap "Presets…" and "Progress…", so those strings or
   flows must be kept or the tests updated. D54 would need reopening.
2. **The Progress sheet has no close button** when opened from Exercises.
3. **Add Exercise is buried at the end of a 90-row list.**
4. **Settings, Ask AI, Heart Rate, New Exercise, Presets and Load Type are stock system Forms**,
   visually disconnected from the carded app. They use system row colours and system `.red`, and
   no Theme components.
5. **Internal jargon on screen**: "(D23)" in the Load Type note; "App unit preference"; "Suppress
   template update prompts" with no explanation.
6. **Stale or narrow labels**: "Ask AI about plates"; the "74 seeded exercises" comment (it's 90).
7. **Missing data capture**: no body area when creating an exercise. No way to delete or archive a
   custom exercise, or to edit its tags.
8. **Colour-semantics collisions**: amber means accent, Zone 4 and the load chip. Drop equals
   UnitMixed. The calorie tint differs between two screens.
9. **No motion or haptics** anywhere in Exercises or Settings. No chart draw-in, no filter
   transitions, no success feedback on save or export.
10. **Muscle identity is unused where it matters most.** The Exercises catalog shows no muscle
    colour or map. Families cover only 5 of 14 body areas: Core, Neck and Full Body have none.
11. **Empty states** are generic: a symbol, a ring and a sparkle with long copy. "No exercises
    match" has no illustration or "create" suggestion.
12. **No destructive confirmations**: Remove key, and preset Delete from the context menu.

---

## 5. Flat checklist of screens and states in scope

**Exercises tab (`ExercisesView`)**
- [ ] Default list: 90 seeded plus custom exercises, alphabetical, large title "Exercises"
- [ ] Search field, "Search exercises"
- [ ] Search with results
- [ ] Search or filter with no results: "No exercises match"
- [ ] Filters active: summary row "<Area> · <Equipment>" plus "Clear", filled filter icon
- [ ] Row, weighted: no load chip
- [ ] Row, non-weighted: load chip "Bodyweight", "BW + added" or "Assisted"
- [ ] Row, custom: "Custom" tag
- [ ] Row at accessibility sizes: load chip wraps into the flow
- [ ] Row with 2 equipment tags: wrap
- [ ] "Add Exercise…" button at the end of the list

**Exercises: menus and dialogs**
- [ ] Filter menu → "Body Area" submenu: "All body areas" plus up to 14 areas, checkmark on the
      selected one
- [ ] Filter menu → "Equipment Type" submenu: "All types" plus 6 tags
- [ ] Filter menu → "Clear Filters" (only when filters are active)
- [ ] Row context menu, seeded: "Progress…", "Presets…", "Load type…"
- [ ] Row context menu, custom: adds "Rename…"
- [ ] "Rename Exercise" alert: Name field, Save, Cancel

**New Exercise sheet**
- [ ] Empty name: Add disabled
- [ ] Prefilled name (mid-workout callers)
- [ ] Load type menu: 4 options, with the footer copy
- [ ] Equipment multi-select, checkmarks
- [ ] Linked-to-model variant (AddByMachine): no visual difference

**Presets sheet**
- [ ] Empty: EmptyState "No presets yet. Without any, this exercise is logged as one thing."
- [ ] List of presets
- [ ] Edit mode: reorder and delete handles; the Edit/Done button
- [ ] Swipe-to-delete
- [ ] Preset context menu: "Rename…", "Delete"
- [ ] Add row with the field "New preset (e.g. Wide grip)" and Add (disabled or enabled)
- [ ] Duplicate warning: "<Name> is already a preset here."
- [ ] "Common" suggestions: 11 items, shrinking as they're used; hidden when all are used
- [ ] "Rename Preset" alert: Name, Save, Cancel; message "Logged sets keep the old name."

**Load Type sheet**
- [ ] Unchanged: Save disabled; header is the exercise name; footer explains the selected type
- [ ] Each of the 4 footer explanations (Weighted, Bodyweight, BW + added, Assisted)
- [ ] Changed: "What this changes" section with 2 labels, including the N-sets count
- [ ] Deleted-exercise edge case: empty header

**Progress sheet (from Exercises)**
- [ ] Empty, single variation: "No sets logged yet" plus "Log <X> in a workout and its progress
      appears here."
- [ ] Empty, multi-variation: "Nothing to chart here" plus the "No eligible sets under …" copy
- [ ] Variation picker menu: "<label> · N days" / "· nothing eligible"
- [ ] Single session: "One session" row with the as-entered value
- [ ] Series: segmented metric "Best set" / "Volume" / "1RM" (or Best set only)
- [ ] Chart: area, line and points; scrub selection with rule and big point
- [ ] Selection row, falling back to the last session
- [ ] Caution footer when fewer than 4 days: "Only N days logged — read the shape with caution."
- [ ] "Change" section: "Since first session" ±N%, accent or secondary
- [ ] Missing close button (swipe-only dismissal)

**Settings**
- [ ] Gear entry on the Workout tab (`openSettings`)
- [ ] Settings screen, inline title "Settings"
- [ ] Unit menu: "Metric" / "U.S. customary"
- [ ] Working rest stepper "Working rest · m:ss", 0–10 min, step 15 s
- [ ] Warmup rest stepper "Warmup rest · m:ss"
- [ ] Toggle "Suppress template update prompts"
- [ ] "Heart rate zones" row: "Not set" or "N bpm"
- [ ] "Ask AI about plates" row: "On" or "Off"
- [ ] "History update" dumbbell-move note (conditional)
- [ ] Export section: header "Export"; summary "Counting…" then "N workouts · N sets (N completed)"
- [ ] "Export CSV" and "Export JSON" buttons
- [ ] Export failure row / count failure row (red)
- [ ] System share sheet (UIActivityViewController)
- [ ] Footer "This phone holds the only copy until you export."

**Heart Rate sheet (`MaxHeartRateSheet`)**
- [ ] Measured maximum field (number pad)
- [ ] "Use my date of birth" toggle off, then on with the DatePicker
- [ ] "Zones would use" preview: Maximum plus Zones 1–5 lower bounds; hidden when nothing resolves
- [ ] Cancel / Save

**Ask AI sheet**
- [ ] Status "Ask AI" On or Off, with the long GPT-5.6 Terra footer
- [ ] Permissions: 3 toggles plus the "OpenAI API data policies" link
- [ ] Key absent: "OpenAI API key" field, Save key (disabled or enabled)
- [ ] Key present: "Replace the saved key" field, "Remove key" (destructive, no confirmation)
- [ ] Save error shown in the footer
- [ ] Also opened from the scanner and the AI routine sheet ("Open AI Settings")

**Design system and assets to restyle or replace**
- [ ] 17 colour tokens (§1.1), zone colours, muscle-family colours, stray calorie tints
- [ ] 4 font tokens, 3 radii, 5 spacings
- [ ] `.card()` standard and elevated
- [ ] `Chip` (plain and selected), `UnitChip`
- [ ] `StatTile`
- [ ] `ProgressRing`
- [ ] `EmptyState` (8 call sites)
- [ ] Primary and secondary button styles
- [ ] `WrapLayout`
- [ ] `MuscleIcon` / `MuscleFamilyStrip`, and the 10 muscle-map PNG templates (5 families × body
      and muscle)
- [ ] `ZoneTimeCard`
- [ ] 3 haptics
- [ ] `BrowseMenuOption`
- [ ] App icon: 1024 PNG, amber dumbbell on black, with no dark or tinted variants
- [ ] Tab bar items and the global tint
