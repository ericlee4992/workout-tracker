# Look API: tokens and components for screen authors

Source: `RedesignPrototype/Sources/Look/` (`Look.swift`, `Components/*.swift`). Every component takes
plain values and closures. None of them reads the Store. They all read `@Environment(\.look)`, so one
screen renders correctly in all four looks. Do not hard-code a hex value, font or radius; if a token is
missing, add an area-prefixed helper in your `<Area>Support.swift` and report it.

To see every component in every look, launch with
`-galleryPage 0…7 -look floodlight|anatomy|paper|carbon`. Add `-axl YES` for AX1 or
`-galleryComplete YES` for the Live page after set 3. The source is `Prototype/ComponentGallery.swift`,
and its compositions are correct to copy.

## 1. Environment and identity

```swift
@Environment(\.look) private var look          // the current Look (tokens below)
@Environment(\.lookOnSheet) private var onSheet // true inside a sheet (B uses lighter sheet cards)
@Environment(\.lookOnSlab) private var onSlab   // true inside C's ink slab (rest bar, HR plate)
@Environment(\.dynamicTypeSize) private var typeSize   // AX layouts: typeSize.isAccessibilitySize
```

- `LookID`: `.floodlight` (A), `.anatomy` (B), `.paper` (C light), `.carbon` (C dark). It also has
  `.isPaperClub` (C, either finish), `.displayName`, `init?(argument:)` (accepts `paperClub` and
  `carbonCopy`), and `.preferredColorScheme` (only Paper is light).
- Switch on `look.id` only for signature differences the SPECs define. Use `look.id.isPaperClub` for
  both C finishes.
- The app root already injects the look with `.look(look)`. Screens never set it.

## 2. Tokens (`Look`)

**Grounds and surfaces:**
- `ground`: the screen.
- `groundSheet`: the base of a sheet.
- `surface`: cards, tiles and panels on the ground.
- `surfaceSheet`: cards on a sheet. B uses #1F2024; the others match `surface`.
- `surfaceRaised`: cells, the machine row, the secondary button.
- `field`: editable wells.
- `pressedFill`: C's pressed fill and C's selected tab.
- `hairline`: separators and information edges.
- `innerHighlight`: B only.
- `dash`: dashed "make one" edges and draft boxes.
- `outline`: C's "you can press this" ink or bone outline; clear in A and B.

**Text:** `textPrimary`, `textSecondary`, `textTertiary`. In A, `textTertiary` is never used on `field` or
`surfaceRaised` (4.13:1 there).

**Meanings (one colour, one meaning):**
- **Action and selection:**
  - `action`: the one filled command. A Ultra, B pearl, C cobalt.
  - `onAction`: text and glyphs on `action`.
  - `actionText`: the action colour as text, rings and marks. Carbon uses a lighter cobalt.
  - `live`: a live instrument, such as the rest ring.
  - `selection`: the glyph or label of a selected item.
  - `selectionFill`: the lozenge behind a selected tab.
  - `segmentFill`: the selected chip or segment.
- **Done:** `done` and `onDone`. Done means lit or inked: a completed set, a trained day, the stamp.
- **New best:** `positive` and `onPositive`. A and B use a flood/pearl outline or pill; C uses the yellow
  highlighter.
- **Heart rate and destruction:**
  - `heartRate`.
  - `destructive`: A danger red-orange. B and C have no hue; they use the text colour plus a mark.
- **Set kinds:** `warmup`, `drop`, `failure`, `warmupMarker`. B uses hues; A and C use shape and
  treatment.
- **Instruments:** `slab`, `slabEdge`, `onSlab`, `onSlabSecondary`. These cover C's ink slab and the A/B
  bar tints.
- **Charts and glass:**
  - `ringTrack`.
  - `comparisonLast`: the last-time bar.
  - `shadowInk`: C's hard offset, used only by the primary.
  - `glassTint`, `glassEdge`.
- **Control fills (never hard-code these):**
  - `controlFill`: icon discs, stepper tracks. B uses white 8 %.
  - `chipFill`: the gym chip.
  - `pillFill` and `pillEdge`: the quiet +15s pill.
  - `dayDotPast` and `dayDotFuture`: B's week strip.
- **Units:** `unit(_ WeightUnit)`. It is plain in every look.
- **Families and zones:**
  - `family(_ MuscleFamily)`: the vivid colour.
  - `familyTint(_:)`: C's washes and the tint elsewhere.
  - `mapBody`, `mapBodyUnlit`, `mapMuscleUnlit`.
  - `zone(_ HeartRateZone)`: the zone ramp. `zoneRamp[0…5]` also exists.

**Fonts (`look.font.*`).** All are Dynamic Type text styles.

| Role | Use |
|---|---|
| `largeTitle` | Tab titles ("Workout") |
| `title` | Status headline ("Workout saved") |
| `title2`, `title3` | Headings |
| `headline`, `body`, `callout`, `subhead`, `footnote`, `caption`, `caption2` | Text |
| `heroNumber` (34) | B's "6%" |
| `bigNumber` (28) | Tiles, rest time |
| `statNumber` (22) | Week footer |
| `smallNumber` (20) | Counts |
| `fieldNumber` (17) | Numbers in fields |
| `timer` | The live clock |
| `button` | Bold 17 (Rounded in B) |
| `tabLabel`, `navTitle` | Chrome |
| `sectionTitle` | 20-class sections |
| `pageSectionTitle` | The top-level section of a tab page, such as Home "Templates". B steps up to 22. |
| `cardTitle` | Exercise cards |
| `tileTitle` | Template tiles |
| `columnHeader` | Apply `.tracking(look.columnTracking)` |
| `badge` | Badges |

The faces differ by look: A uses SF Expanded Black/Heavy, B uses SF Rounded, and C uses New York for
names with SF Expanded for numbers.

**Geometry and motion:**
- `look.radius.{panel, tile, stat, row, field, bar, badge, marker, sheet}`.
- `look.space.{margin (20), section, group, header, panelPadding, grid}`.
- `look.stroke.{hairline, pressable, primary, dashed}`. The pressable and primary strokes are 0 outside C.
- `look.motion.{pressScale, pressSink, reducedPressOpacity, segmentedRings, stampScale, stampRotation, mapLightDuration}`.

**Per-look words and symbols.** Use these instead of switching on `look.id` yourself.

| Helper | Returns |
|---|---|
| `look.previousLabel(SetValue, rowUnit:, loadType:)` | A "105 lb × 8"; B and C "105 × 8", but they keep the unit when it differs from the row. |
| `look.nextSetLabel(number:value:rowUnit:loadType:)` | "Next · Set 3 · 110 lb × 8" (A) or "Next · Set 3 · 110 × 8" (B, C) |
| `look.nextExerciseLabel("Incline Chest Press")` | "Next · Incline Chest Press" |
| `look.lastDoneLabel(date, now:)` | A "Sep 23". B "Wed" within this week, otherwise "Sep 17". C "Today", "Yesterday", "3 days ago". |
| `look.tileSymbol(FinishTileKind)` | The finish/history tile glyph. Total volume becomes outline `scalemass`. |
| `look.gymSymbol` | `mappin.and.ellipse` in every look |
| `look.previousPerformanceSymbol` | A `chart.bar.xaxis`; B and C `chart.line.uptrend.xyaxis` |

## 3. Surfaces and structure

- `.lookSurface(_ role: SurfaceRole, radius: CGFloat? = nil)`. The roles:
  - `.panel` / `.card`: groups of information. A is a flat stand panel, B a solid card with a hairline
    and top highlight, C a sheet with a 1.5 pt soft rule.
  - `.tile`: pressable content. C adds its 2 pt ink outline.
  - `.stat`: stat tiles.
  - `.raised`: inner cells and the machine row. C adds its 1.5 pt outline.
  - `.field`.
  - `.sheet`.
  - `.glassChrome`: floating chrome only.

  The role picks `surfaceSheet` automatically inside a sheet.
- `.lookScreenBackground()` paints the screen ground edge to edge.
- `.lookSheetGround()` goes on a sheet's root once. It paints `groundSheet` and sets `lookOnSheet`.
- `.lookSheetContext()` only sets `lookOnSheet`, with no painting. Use it for content hosted in a sheet
  whose background is already drawn.
- `LookPanel(role: .panel, padding: nil) { … }` is a padded surface. `LookDivider(vertical: false)`
  draws a hairline, and uses the slab colour on a slab.
- `.dashedOutline(color, radius:, lineWidth: 1.5, dash: [5, 4])`.

## 4. Motion helpers (every one has a Reduce Motion alternative)

- `.buttonStyle(.lookPressable)` is the default for cards, tiles and rows. A and B scale to 0.97; C
  darkens. Under Reduce Motion it dips opacity instead.
- `.pressFeedback(isPressed, .scale | .sink | .darken | .none)` is for custom `ButtonStyle`s.
- `CountUpText(value: Double, duration:, countsFromZero:, format:)` and `CountUpText(Int)` (grouped)
  count up on appear and on change. Style them with `.font` and `.foregroundStyle`.
- `.celebrate(trigger)` bumps once on change: A overshoots, B pops, C thunks.
- `.appearProgress($progress, delay:, duration:)` drives an entry animation once.
- `BeatingHeart(bpm:, isFresh:, font:)` beats at the live bpm (A uses a fixed 1.1 s). When stale it is
  grey and still.

## 5. Buttons and chrome

| Component | Signature | Notes |
|---|---|---|
| `StartPair` | `StartPair(onLifting:, onCardio:)` | Two equal capsules with icon discs. They stack via `ViewThatFits` only when a label can't fit. C adds its hard shadow and sink. |
| `StartCapsule` | `StartCapsule(title:, symbol:, action:)` | One capsule, e.g. the Resume capsule. Heavy haptic. |
| `PrimaryButton` | `PrimaryButton("View in History", symbol: "clock.arrow.circlepath") { }` | The screen state's one filled command. In C the disc is leading and the label centred. |
| `.lookPrimary` / `.lookSecondary` | `Button("Save as Template") {}.buttonStyle(.lookSecondary)` | Full-width capsules, Bold 17. The secondary is quiet. |
| `PillButtonStyle(prominent:)` | `Button("Skip") {}.buttonStyle(PillButtonStyle(prominent: true))` | Rest-bar pills. B's +15s is glass. C's pills change fill when pressed. |
| `GlassIconButton` | `GlassIconButton("gearshape", accessibilityLabel: "Settings") { }` | Toolbar glass disc. Capped at xxxLarge, with the large-content viewer. |
| `GlassCapsuleButton` | `GlassCapsuleButton("Finish")`, `("Cancel", role: .destructive)` | Toolbar text on glass. Same cap. A's Cancel is `.destructive`; B's is `.normal`. |
| `CardIconButton` | `CardIconButton("ellipsis", accessibilityLabel: "Options") { }` | Visual size: A 32 (bare glyph), B 38 (disc), C 36 (outlined). The hit area is 44 but takes no extra layout. |
| `MakeTile` | `MakeTile(title: "New Template…", symbol: "plus") { }` | Dashed "make one" tile, flat peers in the grid. |
| `DestructiveRowButton` | `DestructiveRowButton("Discard Workout…") { }` | A red-orange. B has no hue. C uses a double rule and a solid trash disc. Always confirm the action. |
| `IconDisc` | `IconDisc(symbol:, size:, context: .onAction / .onSurface / .make)` | The icon disc. `symbol` may be `LookIcon.machine`. |

**Toolbars.** Compose your own bar row from the glass buttons, as the gallery's `LiveTopBar` does.
At AX sizes, A and C move the title out of the bar and make it the first content line. B keeps the
title in the bar and truncates it first. Never put `.fixedSize()` on a title between glass buttons.
If you use a native `.toolbar`, pass plain `Button`s: the system supplies the glass.

## 6. Glyphs

- `LookIcon.machine` is a symbol name that draws `WeightStackGlyph`, the machine weight stack. Pass it
  wherever a component takes `symbol:` (`EquipmentRow`, `LookRow`, `Chip`, `IconDisc`, `EmptyStateView`).
  `dumbbell` is reserved for free weights. `LookIcon(name, style: .body, weight: .semibold)` renders
  either an SF Symbol or the machine glyph, and scales with Dynamic Type.

## 7. Lists and controls

- `LookList(header:, footer:, separatorInset: 16) { rows… }` is one surface with hairline separators.
- `LookRow("Title", subtitle:, symbol:, symbolTint:, value: "14", showsChevron: true, action: {})`.
  The variant `LookRow("Title", …) { trailingView }` takes a custom trailing view. Rows are at least 50
  or 60 pt.
- `Chip("Chest", symbol:, isSelected:) { }`: a 34 pt visual with a 44 pt hit area.
- `SegmentedPills(["Lifting", "Cardio"], selection: $index)`: 44 pt segments.
- `LookToggleRow("Title", subtitle:, isOn: $on)`. For any `Toggle`, use `.toggleStyle(.look)`:
  - A: the system switch in Ultra.
  - B: a pearl track with an ink thumb.
  - C: cobalt.
- `NumberStepperPill(value: $secs, range: 0...600, step: 15) { Format.rest($0) }`: − value + with 44 pt
  buttons, adjustable in VoiceOver.
- `SearchFieldView(text: $q, prompt: "Search exercises")`.
- `EmptyStateView(symbol:, title:, message:, actionTitle:) { }`. The message is one short line at most.
- `SheetHeader(cancel: {}, title: "New Gym", commit: {}, commitTitle: "Save", commitEnabled: true)`:
  Cancel on glass, and the commit is the sheet's filled command.
- `LookNavTitle("Workout", subtitle: "Thursday, Sep 24")`. B puts the subtitle above the title.
  Home's date format differs by look: A and B use "Thursday, Sep 24"; C uses "Thursday, September 24".
- `SectionHeader("Heart rate")` and `SectionHeader("Templates", level: .page)`. Optional arguments:
  `trailing: String?, trailingAction: (() -> Void)?`. With an action it is a button; without one it is
  a caption.
- `LookTabBar(selection: $tab)` is a custom glass tab bar with the four kept symbols. The app shell uses
  the system `TabView`, so screens rarely need it.

## 8. Home pieces

- `GymPickerButton(name: "Iron Temple", city: "Seoul", unit: .lb) { }`:
  - A is a full-width row.
  - B is a capsule that hugs its content.
  - C is a full-width pressable card with the city under the name.
  - At AX sizes, the city and unit move under the name.
- `WeekWidget(summary: WeekSummary)`. Each look has its own treatment:
  - A: the scoreboard. Maps with counts, lit day cells, and a footer that becomes three rows at AX.
  - B: lit anatomy. Maps become a five-row list at AX, above the day-bar strip.
  - C: the punch card, with stickers.
- `TemplateTile(name:, families:, exercises: [String], lastDone: Date?, now: Date) { }`. Lay tiles out
  in a `Grid` with two per `GridRow`, so a row shares one height. Switch to one column at AX sizes, as
  the gallery does. Put `MakeTile`s in the last row.
- `DurationFigure(minutes:, numberFont:, unitFont:, numberColor:, unitColor:)` renders "1 h 43 min" with
  big numbers and small units.

## 9. Muscle maps (summaries only, never beside an exercise row)

- `MuscleMap(family:, lit: true, size: 48, appearDelay: nil)`. Pass `appearDelay` to light it on entry
  (A 200 ms, B 0.7 s).
- `FamilySticker(family:, lit:, size: 30)`: C's washed tile; the bare map in A and B.
- `FamilyStrip(families:, size: 30, spacing: 2)`: the families head to toe.
- `FamilyBand(families:, height: 76)`: C's tile band; a leading strip in A and B.
- `FamilyTallyGroup(counts: [FamilyCount], mapSize:, showsNames: true, appearDelay:, stagger: 0.08, spacing: 6, hidesZeroCounts: false)`.
  Use this rather than laying out `FamilyTally` yourself. It handles AX: B and C become rows of
  map · name · count; A keeps one row, wrapping 3 + 2. Per-look usage:
  - B Finish passes `hidesZeroCounts: true`.
  - C Finish passes only the trained families.
- `FamilyTally(family:, sets:, lit:, size:, showsName:, appearDelay:, style: .automatic / .column / .row, hidesZeroCount:)`
  is a single tally.

## 10. Live workout pieces

- `LiveHeaderLine(gym: "Iron Temple", elapsed: 1122, done: 7, total: 18, onGym: {})` renders the
  gym chip · clock with seconds · N/M ring. At AX it takes two lines: A puts the chip first; B and C put
  the clock and ring first.
- `GymChip("Iron Temple") { }`, `SetsRing(done:, total:, size:)`, `SetsRingLabel(done:, total:)`.
  A's ring is segmented, with a continuous arc above 24 sets.
- `VitalsStrip(hr: 128, zone: .two, isStale: false, staleSeconds: nil, activeCal: 96, volume: 4120, unit: .lb, onHeartRate: {})`.
  A missing heart rate or calorie cell is left out. The strip stacks at AX. When stale, B shows "12s ago".
  `ZoneMeter(zone:)`.
- `ExerciseCardHeader("Seated Chest Press", subtitle: nil, onPrevious: {}, onOptions: {})`. B passes its
  `"Target: 3 sets · 10, 8, 8 reps"` subtitle; A and C pass nil. The title wraps and never truncates.
- `EquipmentRow(title: "Chest Press 2", subtitle: "Life Fitness Insignia Series Chest Press", symbol: LookIcon.machine) { }`.
  Pass `"dumbbell"` (or a cable symbol) for free-weight equipment.
- `SetColumnHeader(weightTitle: "WEIGHT")` shares `SetGridMetrics` with the rows and hides at AX.
- `SetRowView`. Use the typed initializer:

  ```swift
  SetRowView(kind: .working, number: 3, last: SetValue(weight: 105, unit: .lb, reps: 8), loadType: .weighted,
             weight: 110, unit: .lb, reps: 8, state: .prefilled /* .empty .typed .completed */,
             isNextUp: true, isResting: restRunning, badge: nil /* .newBest .firstTime */,
             onCheck: {}, onWeight: {}, onReps: {}, onUnit: {})
  ```

  The PREVIOUS column is formatted per look. The fields draw at 40 pt with a 44 pt hit area; tapping
  the "lb" suffix calls `onUnit`, and VoiceOver gets a "Switch unit" action. The completion effects are
  the look's signature: A a stamp with a strobe on a new best, B a pop with ripple and flash, C a stamp
  with ripple and unbox. They fire when `state` becomes `.completed`. At AX the row becomes a two-line
  block. The old initializer, `previous: String?, weight: String?, reps: String?`, is still available for
  pre-formatted special cases.
- `SetMarker(kind:, number:, done:, isNextUp:, side: nil)` renders W, F and D and the numbers.
- `NewBestBadge(kind: .newBest / .firstTime)` and `AddSetRow { }`, a deliberate dashed row.
- `RestBar(remaining: 84, total: 120, next: look.nextSetLabel(...), onAdd15: {}, onSkip: {})`. Insert it
  with `.transition(RestBar.transition(reduceMotion:))`. Per look:
  - A: a glass bar with Ultra and a final-10-s beat.
  - B: a Liquid Glass bar.
  - C: the ink slab.

  At AX it takes two rows, and A moves the Next line into VoiceOver only. `RestRing(progress:, isFinal:, size:)`.

## 11. Finish, history and progress

- `FinishStatusRing(segments: [FamilyCount] /* workout order */, size: nil)`. The celebration differs
  by look: A family-coloured segments, B family arcs with a check, C a rubber stamp (the ink ring is its
  outer edge).
- `StatPairGrid(tiles: [FinishTile], countsUp: true)` shows the user's pair order. A draws one
  scoreboard, B separate tiles, C one ticket per pair. It stacks at AX.
- `StatFigure(value:, unit:, label:, symbol:, tint:, symbolTint:, countsUp:, numberFont:)` is a big
  number with a small unit and label.
- `ComparisonBars(title: "Total volume", context: "vs Push Day, Sep 17" (B) / "Push Day" (C) / nil (A), lastLabel: "Sep 17", last: 17400, today: 18450, unit: "lb")`.
  At AX the labels move above full-width bars. Section headers above it: A "Last Push Day", C "Last
  time", B none.
- `HeartRatePlate { HeartRateRangeChart(...); ZoneBreakdown(seconds:) }`. A draws a panel with a section
  header, B a card, C the ink slab with the title inside.
- `HeartRateRangeChart(slots: [HRSlot], maxHeartRate: 185, startLabel: "0:00", endLabel: "52:10", height: 150)`.
  B uses clock times ("6:12 PM" / "7:04 PM"). At AX the chart grows 1.25×.
  `ZoneBar(seconds:)` and `ZoneLegend(seconds:)`:
  - A: columns, which become a 2-column grid at AX.
  - B: rows, which become two lines at AX.
  - C: a 2-column grid, which becomes 1 column at AX.
- `ProgressLineChart(points: ProgressChartPoint.bestSet(series, in: .lb), unit: "lb", height: 180)`. The
  y-axis does not start at zero, and new-best markers differ by look.

## 12. Strings baked into components (already reported as new or kept)

- **Week and tallies:**
  - "This week", "Workouts", "Time", "Last week", "workout(s)", "time".
  - "{n} set(s)", "{n} working set(s)".
- **Template tiles:**
  - "+ {n} more" (A), "+{n} more" (B, C).
  - Last-done words: "Today", "Yesterday", "{n} days ago" (C), weekday abbreviations (B).
- **Rest and set rows:**
  - "Rest", "+15s", "Skip".
  - "Next · Set {n} · …", "Next · {exercise}".
  - "Add Set", SET / PREVIOUS / WEIGHT / REPS.
  - "NEW BEST" / "New best", "FIRST TIME" / "First time".
- **Vitals:** "bpm", "cal", "Active calories", "Total volume", "Set up zones".
- **B only, new for approval:** "{n}s ago" when stale.
- **Heart rate and comparison:** "Time in zones", "Heart rate", "Today".
- **Home:** "Start Lifting", "Start Cardio".
- **Defaults:** "Cancel" / "Save" (SheetHeader), "Search".

## 13. Rules the components already enforce (don't undo them)

- Hit targets are at least 44 pt.
- Layouts restack at AX sizes instead of truncating. Only numerals in fixed columns (set fields, vitals,
  stat tiles) may shrink, to no less than 0.7×.
- Chrome is capped at xxxLarge and shows the large-content viewer.
- Only C's primary casts a hard shadow.
- Only floating chrome is glass.
- The muscle maps stay out of exercise rows.
