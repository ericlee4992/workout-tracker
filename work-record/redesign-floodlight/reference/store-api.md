# Store API — what screen authors code against

Sources: `RedesignPrototype/Sources/Model/{Models,SampleData,Format,Derived,Simulators,Store}.swift`,
`Prototype/ScreenID.swift`. Everything is main-actor (default isolation), plain value types
plus one `@Observable final class Store`. Read it with `@Environment(Store.self) private var store`
(use `@Bindable var store = store` only for `settings` / `isSessionPresented` bindings).

Rules of thumb
- **Mutate only through Store methods** (most state is `private(set)`). Build text-field
  bindings as `Binding(get: { … }, set: { store.updateWeight($0, entryID:, setID:) })`.
- **Time:** always use `store.now` (never `Date()`). It starts **Thu Sep 24 2026 18:30** and ticks
  at 1 Hz; `store.freezeClock = true` stops it (captures). Views that read `now`,
  `sessionElapsed`, `rest…(at: store.now)`, `currentBPM`, `hrFeed` re-render every second.
- **Units:** app unit is lb (`store.displayUnit`), distance mi (`store.distanceUnit`). History
  shows weights **as entered** (`SetValue.unit`); derived kg figures (volume, 1RM) convert
  plainly with `Format.volume(kilograms:in:)` / `Format.weight(kilograms:in:)`.
- **Missing ≠ zero:** every HR / calorie value is optional; omit the element when nil.
- **History = frozen snapshots:** show `WorkoutEntry.exerciseName / machineLabel / modelName /
  presetName / equipmentLabel`, never live catalog names. `Workout.isEdited` → "Edited" mark.
- Stable sample ids: `SampleData.exerciseID("Seated Chest Press")`, `SampleData.templateID("Push Day")`,
  `SampleData.gymID("Iron Temple")` / `SampleData.ironTempleID`,
  `SampleData.machineID("Iron Temple", "Chest Press 2")`, `SampleData.workoutID("2026-09-17")`.

---

## 1. Value types (Models.swift)

### Units and enums (display strings are the real app's)
| Type | Cases / members |
|---|---|
| `WeightUnit` | `.kg .lb`; `label`, `toggled`, `toKg(_:)`, `fromKg(_:)` |
| `DistanceUnit` | `.km .mi`; `label`, `metersPerUnit` |
| `UnitSystem` | `.metric` "Metric" / `.usCustomary` "U.S. customary"; `weight`, `distance` |
| `SetType` | `.warmup .working .failure .drop`; `marker` ("W"/nil/"F"/"D"), `displayName`, `startsRestTimer` (drop = false), `countsTowardRecords` (warmup = false) |
| `LoadType` | `.weighted .bodyweight .bodyweightPlus .assisted`; `badge` ("Weighted", "Bodyweight", "BW + added", "Assisted"), `higherIsBetter` (assisted false), `takesWeight`, `weightColumn` ("WEIGHT"/"ASSIST"; bar mode shows "PER SIDE"), `axisLabel` (chart y-axis: "Weight", "Reps", "Added weight", "Assistance (less is better)") |
| `EquipmentTag` | `.machine .barbell .dumbbell .cable .smith .bodyweight`; `label`, `symbol`, `offersBar` |
| `EquipmentCategory` | Selectorized, Plate-loaded, Cable & functional, Rack, Smith & bench, Bodyweight station (`label`) |
| `MuscleGroup` | 14 values head→toe (`label`, `family`); Neck/Core/Full Body → no family |
| `MuscleFamily` | `.chest .back .shoulders .arms .legs` (head→toe); `label`, `bodyAsset`/`muscleAsset` ("MuscleMaps/chest-body"…), `ordered(_:)` |
| `CardioActivity` | 9 activities; `name`, `symbol`, `isOutdoor`, `usesSpeed` (cycles), `section` ("Gym"/"Outdoors") |
| `HeartRateZone` | `.warm(0)…five`; `label` ("Warm-up", "Zone 1"…), `descriptionText`, `lowerFraction` (55/65/75/85/95 %) |
| `HeartRateSource` | "AirPods", "Apple Watch", "Heart rate monitor" |

### Catalog, gyms, templates
- `Gym { id, name, city?, defaultUnit? (nil = app unit), isDeleted }`
- `EquipmentModel { id, manufacturer, modelName, category?, exerciseIDs, isSeeded; displayName }`
- `Machine { id, gymID, label ("Chest Press 2"), modelID?, recognizedExerciseIDs, defaultUnit?, defaultPresetID?, isDeleted, deletedAt? }`
  — effective exercises via `store.exerciseIDs(of:)`; model name via `store.modelName(of:)`.
- `Exercise { id, name, loadType, muscleGroup?, tags, presets: [ExercisePreset], isSeeded; family, isMachineExercise }`
- `ExercisePreset { id, name }`
- `Template { id, name, items, cardio: [PlannedCardio], generatedForGymID?; isAI, setCount }`
- `TemplateItem { id, exerciseID, targetReps: [Int] (count = sets), restSeconds?, supersetGroup?, equipmentTag?; setCount }`
  — row text: `Format.targets(item.targetReps)` → "4 sets · 12, 10, 8, 8 reps". Superset letters:
  `store.supersetLabels(ofTemplate:)` → `[itemID: "A"/"B"]` (Push Day: Lateral Raise A, Triceps Pushdown B).
- `PlannedCardio { id, activity, minutes, distance?, unit }`

### A set's value
- `SetValue { weight? (TOTAL, bar included), unit, reps, bar?; kg, perSide }` — used for previous
  values, bests, records, progress points. Text: `Format.set(v)` "110 lb × 8",
  `Format.setShort(v)` "110 × 8", `Format.barBreakdown(v)` "45 + 45 × 2 = 135 lb".

### History
- `Workout { id, name?, templateID?, templateName?, startedAt, durationSeconds, gymID?, gymName?, entries, cardio, heartRate?, activeCalories?, basalCalories?, editedAt?, notes }`
  computed: `finishedAt`, `isEdited`, `totalCalories` (only when both parts exist), `title`
  (typed → template → "First Exercise +N" → "Workout"), `allSets`, `setCount` (warmups included),
  `hasLifting`, `hasCardio`, `unitBadge` ("kg"/"lb"/"Mixed"/nil).
- `WorkoutEntry { id, exerciseID, exerciseName, loadType, machineID?, machineLabel?, modelName?, freeWeightTag?, presetID?, presetName?, supersetGroup?, sets, reclassifiedAt?, reclassifiedFromExerciseName? }`;
  `equipmentLabel` ("Chest Press 2 · Life Fitness Insignia Series Chest Press · Narrow grip"),
  `countedSets` (no warmups), `bestCounted: SetValue?`, `scope`, `isReclassified`,
  `reclassifiedLine` ("Reclassified from Bench Press · Sep 4, 2026" — D51 provenance, NOT an Edited mark).
  Superset letters: `store.supersetLabels(ofWorkout:)` → `[entryID: "A"/"B"]`. Chart button:
  `store.progressVariationID(for: entry)` → pass to `progressSeries(exerciseID:variationID:)`.
- `LoggedSet { id, type, weight? (total), unit, reps?, barWeight?, completedAt; normalizedKg, value }`
- `CardioSegment { id, activity, startedAt, activeSeconds, measuredMeters?, manualDistance?, unit, averageHeartRate?, maxHeartRate?, activeCalories?, route: [RoutePoint], plannedID? }`;
  `distanceMeters` (manual wins), `paceSecondsPerUnit`, `speedPerHour`, `hasRoute`.
- `RoutePoint { latitude, longitude, offset (s), portion }` — never join a line across portions.
- `HeartRateSummary { average, maximum, zoneSeconds [6] (empty = no max HR), series?, source; zoneTimes }`
  — `zoneSeconds` is index-based and keeps zeros; list rows with `zoneTimes: [ZoneTime { zone, seconds }]`,
  which **omits zero rows** (F01 has no Zone 5 row, F02 no Warm-up row).
- `HeartRateSeries { mean, low, high (15 s buckets; 0 = gap), intervalSeconds }`

### Live session
- `LiveSession { id, name?, templateID?, templateName?, gymID?, startedAt, entries, cardio, plannedCardio, focus (.lifting/.cardio), activeCalories, heartRate: HeartRateLog }`;
  `unfinishedCardio`, `hasCardio`, `completedSetCount`, `totalSetCount`.
- `LiveEntry { id, exerciseID, machineID?, freeWeightTag?, presetID?, supersetGroup?, barWeight? (non-nil = bar mode), sets, targetReps, plannedRestSeconds?, snapshotLoadType? }`;
  `isBarMode`, `isFrozen` (has a completed set → equipment/preset changes split the entry),
  `completedCount`, `total(of: set)` (bar + 2 × per side in bar mode). `snapshotLoadType` (D23) is captured at
  the first completed set; read the effective one with `store.loadType(entryID:)` (drives WEIGHT/ASSIST).
- `LiveSet { id, type, weight? (the FIELD: total, or PER SIDE in bar mode), unit, reps?, completedAt?, isPrefilled }`;
  `isCompleted`, `state: LiveSetState` = `.empty | .prefilled | .typed | .completed`.
- `LiveCardio { id, activity, startedAt, accumulatedSeconds, runningSince?, endedAt?, measuredMeters, manualDistance?, unit, currentSpeed? (m/s), heartRateSum/Count, maxHeartRate?, activeCalories, route, plannedID?, gps: GPSState, routePortion, gpsWaitFrom }`;
  `isEnded`, `isPaused`, `isRunning`, `activeSeconds(at: now)`, `distanceMeters`, `averageHeartRate`,
  `paceSecondsPerUnit(at: now)` ("Average pace"), `speedPerHour(at: now)` ("Average speed", cycles),
  `currentPaceSecondsPerUnit` / `currentSpeedPerHour` ("Current pace/speed"; nil with a manual distance).
- `GPSState` `.notNeeded | .waiting | .live | .unavailable`; `message` (real copy: "Waiting for GPS…", "Location unavailable.",
  nil otherwise), `recordsDistance`. Unavailable = time keeps recording, distance and route stop (toggle: `setGPSUnavailable`).
- `RestState { entryID, setID, startedAt, endsAt, totalSeconds, mode (.timer/.heartRate), thresholdBpm?, isDegraded }`;
  `remaining(at:)`, `elapsed(at:)`, `progress(at:)` (remaining ÷ total, drains).
  Heart-rate mode: `endsAt` = cap; `isDegraded` → "No heart rate reading — resting by the timer instead."
- `RestSettings { mode, workingSeconds?, warmupSeconds?, thresholdBpm (110), capSeconds (240) }`, `RestMode` (`label` "Timer"/"Heart rate").
- `RestOutcome` `.timerDone | .recovered(bpm) | .cap | .skipped`; `notificationTitle` ("Rest complete"; nil for a skip), `notificationBody` (real copy).
- `HeartRateState { bpm?, lastSampleAt?, source, mode: SensorMode, … }`; `HeartRateFeed` `.live(source) | .stale(lastBpm, secondsAgo) | .waiting`.
  The simulated reading follows the real script one value every 6 s and **eases** toward it (and toward the rest-recovery
  and cardio curves), so bpm moves ≤ ~4 per second and the zone colour does not flicker.
- `SensorMode` `.live | .stale | .none` (prototype sensor toggle).
- `SetCompletion { id, entryID, setID, exerciseName, value, outcome: BestOutcome, restStarted, at }`.
  For "it just happened" use `store.freshCompletion` / `store.freshNewBest` (non-nil for `Store.celebrationWindow` = 4 s).
- `BestOutcome` `.none | .firstTime | .newBest(previous: SetValue?)`; `isNewBest`.
- `NextSetPreview { entryID, setID, exerciseName, setLabel ("Set 3"/"Warmup"/"Drop"), value?, loadType, isNewExercise }`.
- `PlannedCardioStatus` `.notStarted | .recording | .paused | .done`.
- `PendingStart { templateID?, activity? }` (`activity` is always nil, as in the real app: Start is hidden while live),
  `StartResult` `.started | .needsConfirmation`.
- `LiveActivitySnapshot { title, gymName?, startedAt, elapsedSeconds, isCardio, exerciseName?, completedSets, totalSets, bpm?, zone?, restEndsAt?, restRemaining?, restTotal?, activity?, cardioSeconds?, distanceMeters?, distanceUnit, paceSecondsPerUnit?, isCardioPaused }`
  — Z01: `store.liveActivity` (lifting, rest 1:24) and `Store.liveActivitySample(.c02)` (Indoor Run 12:48, 1.47 mi, 8:43 /mi).

### Records, progress, summaries
- `RecordScope { exerciseID, machineID?, freeWeightTag?, presetID? }` (machine OR tag, + preset).
- `PreviousPerformance { exerciseName, loadType, presetName?, layers: [PerformanceLayer] }`
- `PerformanceLayer { kind (.thisEquipment/.sameModelElsewhere/.anyEquipment), title ("This machine"/"This equipment"/"Same model elsewhere"/"Any equipment"), sessions (≤5, newest first), best?, repBests (1–12), oneRepMaxKg? (weighted only), mostReps? (bodyweight), emptyMessage? (real copy) }`
  — `sameModelElsewhere` exists only when the machine has a model and the workout has a gym.
- `PerformanceSession { workoutID, date, gymName?, equipmentLabel, sets: [SetValue], types }`, `RepBest { reps, value, date }`.
- `ProgressMetric` `.bestSet "Best set" | .volume "Volume" | .oneRepMax "1RM"`.
- `ProgressVariation { id (key), label ("Chest Press 2", "Chest Press 2 · Narrow grip"…), machineID?, freeWeightTag?, presetID?, loadType, trainingDays }`.
- `ProgressSeries { exerciseID, variation, points; confidence (.empty / .single → point, no line / .series(days)) }`.
- `ProgressPoint { date, workoutID, best, bestKg?, volumeKg, oneRepMaxKg?, isRecord (PR marker) }`.
- `WeekSummary { days: [WeekDaySummary] Mon…Sun, workoutCount, trainingDayCount, setsByFamily: [FamilyCount] (all 5, head→toe), minutes, lastWeekWorkoutCount }`
  — this week: 3 workouts on 2 days (Mon Pull Day + Indoor Run, Wed Leg Day); `trainingDayCount` matches the brief's "2".
- `WeekDaySummary { date, letter "M", isToday, isFuture, workouts: [DayWorkout] }`
- `DayWorkout { workoutID, title, kind (.lifting / .cardio(activity) / .mixed), families, minutes, sets }`
- `MonthSummary { month, workouts, sets, hours }` (`Format.hours` → "7.9 h")
- `WeekStreak { completedWeeks, thisWeekActive }` — **PROPOSED feature** (not in SPEC).
- `TemplateStats { timesRun, lastRun?, averageDurationSeconds? }`, `GymStats { visits, lastVisit?, machineCount, deletedMachineCount }`,
  `MachineStats { timesUsed, lastUsed?, bests: [MachineBest], setCount; best }` — one best per record scope
  (exercise + preset), most used first: `MachineBest { id, exerciseID, exerciseName, presetID?, presetName?, loadType, value, timesUsed; label }`
  ("Seated Chest Press", "Seated Chest Press · Narrow grip").
- `CalendarMonth { month, title "Sep 2026", weekdaySymbols (Mon-first), weeks [[CalendarDay?]], selectedDate?, selectedWorkouts, hasPrevious, hasNext }`;
  `CalendarDay { date, dayNumber, isToday, isFuture, sets, intensity 0…4, workoutIDs, isSelected }`.
- `HRSlot { index, startSeconds, endSeconds, low, high }` (≤ 110 bars, gaps are missing slots),
  `ZoneRow { zone, lowerBound, upperBound? }`, `CardioSplit { index, distance, seconds }`.

### Finish and drift
- `FinishSummary { id, saved, workoutID?, title, date, gymName?, durationSeconds, volumeKg, setCount, exerciseCount, tiles, averageHeartRate?, maxHeartRate?, zoneSeconds, hrSlots, newBests, comparison?, families, exercises, cardio, summaryLine; zoneTimes }`
  - `zoneTimes` lists zones with time only (omit zero rows).
  - `tiles: [FinishTile]` **in the user's order** time | volume, active | total cal, avg | max HR; missing facts omitted.
    `FinishTile { kind, label ("Workout time"…), value ("52:10", "18,450"), unit ("", "lb", "cal", "bpm") }`, `FinishTileKind.symbol`.
  - `newBests: [NewBestLine { setID, exerciseID, exerciseName, value, previous? }]` (one per exercise).
  - `comparison: TemplateComparison { templateName, lastDate, lastVolumeKg, volumeKg, lastDurationSeconds, durationSeconds, volumeChangePercent? }` (last run of the same template).
  - `exercises: [FinishExerciseLine { entryID, exerciseID, name, equipmentLabel, family?, setCount, best?, loadType, hasNewBest }]`.
  - `saved == false` → the "Nothing logged" state; `summaryLine` = "No sets were completed, so this workout wasn't saved."
- `TemplateDrift { templateID, templateName, workoutID, changes: [DriftChange] }`;
  `DriftChange { exerciseID, exerciseName, kind (.added(sets)/.removed/.setCount(from,to)/.reps(from,to)), bestValue?, badge ("+1 set", "−1 set", "New", "Removed", "12, 12, 10, 10 → 12, 12, 8, 10") }`.
- `DriftResolution` `.updateTemplate .updateValuesOnly .updateBoth .keepOriginal`; `title` (real), `consequence` (**PROPOSED** one-liners).

### Ask AI, scan, settings
- `AIRoutineFlow { step: AIStep (.goals/.equipment/.generating/.preview/.saved/.error), request, days, progress 0…1, progressText, error?, savedTemplateIDs, simulateFailure }`
- `AIRoutineRequest { goals, experience (AIExperience: Beginner/Intermediate/Experienced), daysPerWeek 1…7, minutesPerSession 15…120, heightCm?, weightKg?, gymID?, equipment: Set<RoutineEquipment>, cardio: Set<CardioActivity>, consent; hasGoals }`
- `RoutineEquipment` 8 toggles (real labels). `AIRoutineDay { id, name "Day 1 — Fitness", items, cardio; estimatedMinutes, setCount }`, `AIRoutineItem { exerciseID, sets, reps, restSeconds }`.
- `ScanFlow { step: ScanStep (.camera/.consent/.identifying/.result/.confirmed/.error), gymID?, demoKind, progress, result?, confirmedMachineID?, torchOn, hasPhoto, error?, simulateFailure }`
  — **no photo asset ships**: where the photo shows (S03 thumbnail, S04–S06), draw a placeholder tile (dark look surface,
  SF Symbol `ScanSimulator.photoSymbol`, caption `ScanSimulator.photoCaption` "Hack squat · Iron Temple") when `hasPhoto`.
  `.error` carries real copy in `error` ("Could not reach OpenAI. Check your connection or continue manually."); "Take another photo" → `scanRetake()`.
- `ScanKind` `.specific .ambiguous .newModel .generic`; `ScanResult { kind, label, candidates, selectedCandidateID?, exerciseIDs (≤6), visibleText?; selectedCandidate }`;
  `ScanCandidate { manufacturer, modelName, category?, exerciseIDs, confidence 0…1 (show as visual state), catalogModelID? (nil = new model); displayName }`.
- `CorrectionScope` `.futureOnly "Future Workouts Only" | .applyToPast "Apply to Past Workouts Too"`.
- `AppSettings { unitSystem, workingRestSeconds 120, warmupRestSeconds 60, suppressTemplatePrompts, measuredMaxHeartRate? 185, birthDate?, aiKeySaved, aiKeyHint "sk-…a1b2", photoConsent, routineConsent, modelDetailsConsent, lastExportAt?, lastExportFormat?, historyUpdate?; weightUnit, distanceUnit, consent(_:) }`
  — `historyUpdate: HistoryUpdateNote { setCount, date; text }` → X01 "History update" row: "6 sets moved to dumbbell exercises · Sep 4, 2026" (D51; nil hides the row).
- `AIConsent` `.photos .routine .modelDetails` (`label` = real toggle text). `ExportFormat` `.csv .json`.
  `ExportState` `.idle | .exporting(format) | .done(fileName) | .failed(error)`; `failureLine` → the red row "Export failed: <error>".
- `ModelSuggestState` `.idle | .needsConsent | .asking ("Asking AI…") | .suggested([ModelExerciseSuggestion { exerciseID, reason }]) | .empty | .failed(message)`
  — New Model's "Suggest exercises with AI"; `.empty` copy: `ModelSuggestSimulator.emptyMessage` (real).
- `ScreenTarget { templateID?, workoutID?, gymID?, machineID?, secondaryMachineID?, exerciseID?, entryID?, secondaryEntryID?, setID?, secondarySetID?, aiDayID?, segmentID?, date? }`.

## 2. Store — properties

| Property | Meaning |
|---|---|
| `now`, `freezeClock` | Scenario clock (see rules); unfreezing continues from `now` |
| `gyms`, `models`, `machines`, `exercises`, `templates` | Sample data (settable) |
| `workouts` (read-only) / `history` | Finished workouts / newest first |
| `settings` (settable) | App settings — use `setConsent` for consent side effects |
| `restOverrides` | Per-exercise rest overrides |
| `selectedGymID`, `selectedGym` | Home's gym (nil = No gym) |
| `session` | The live workout (nil = none) |
| `isSessionPresented` (settable) | Live cover showing; false = minimised (Home "Resume workout") |
| `rest`, `lastRestOutcome`, `restEndCount`, `restExpiryCount` | Running rest; how the last ended; `restEndCount` counts every end **including Skip**; `restExpiryCount` counts only timer-done / recovered / cap — key the rest-complete haptic and alarm on it |
| `heartRate`, `hrFeed`, `currentBPM`, `currentZone` | Simulated sensor; feed state; fresh bpm or nil; zone |
| `lastCompletion`, `freshCompletion`, `freshNewBest` | Latest `SetCompletion` (key animations on `.id`); the fresh ones are non-nil for 4 s after completion — show the celebration while `freshNewBest != nil` (L03 yes, L01 no) |
| `pendingStart`, `pendingReplacementDrift` | Start requested while live (W05); the replacement drift dialog to show after "Finish It & Start New" |
| `finishSummary`, `pendingDrift` | Receipt to show / drift prompt to show after Finish |
| `ai`, `scan`, `exportState`, `modelSuggest` | Flow states |
| `gpsUnavailable`, `exportSimulateFailure`, `modelSuggestSimulateFailure` | Prototype failure switches (with `ai.simulateFailure`, `scan.simulateFailure`) |
| `liveActivity`, `liveDrift` | Z01 snapshot of the running workout; the live workout's drift vs its template if it finished now |
| `screenTarget`, `currentScreen` | What the last `reset(to:)` points at |
| `exerciseByID`, `activeGyms`, `deletedGyms`, `sortedTemplates` (A–Z) | Lookups |
| `displayUnit`, `distanceUnit`, `maxHeartRate` (measured wins, else 220−age), `ageBasedMaxHeartRate` (220 − age: 188; L12's "age-based" beside measured 185), `maxHeartRateIsEstimated`, `zoneRows` | Units & zones |
| `weekSummary`, `weekStreak` (PROPOSED), `bestOutcomes` | Derived |
| `sessionElapsed`, `sessionTitle`, `sessionVolumeKg`, `currentEntryID`, `nextEntryID`, `nextSet`, `unloggedSetCount` | Live readouts ("18:42", "Push Day", 4,120 lb, current/next exercise, rest preview, typed-not-ticked rows) |
| `aiEligibleExerciseIDs`, `aiMachineCount`, `aiCanGenerate`, `scanResolutionLine`, `exportCounts` | Flow readouts |

## 3. Store — methods

**Lookups:** `exercise(_:)`, `gym(_:)`, `machine(_:)`, `model(_:)`, `template(_:)`, `workout(_:)`,
`liveEntry(_:)`, `activeMachines(gymID:)` (A–Z), `deletedMachines(gymID:)`, `exerciseIDs(of: machine)`,
`machines(for: exerciseID, gymID:)`, `modelName(of:)`, `dumbbellCounterpart(of:)` (D51),
`defaultUnit(machine:gymID:)` (machine → gym → app), `zone(for: bpm)`.

**Derived:** `monthSummary(for:)`, `templateStats(_:)`, `gymStats(_:)`, `machineStats(_:)`,
`calendarMonth(containing:selected:)`, `families(ofTemplate:)`, `families(ofWorkout:)`,
`families(exerciseIDs:)`, `volumeKg(ofWorkout:)`, `bestOutcome(setID:)` (history PR marks),
`newBestCount(workoutID:)` (exercises with a PR), `lastTrained(exerciseID:)`, `hrSlots(workoutID:)`,
`drift(workoutID:)`, `progressVariations(exerciseID:)` (most days first),
`progressSeries(exerciseID:variationID:)` (nil id = default), `progressChange(_:metric:)` (% first→last, flipped for assisted),
`previousPerformance(entryID:)` / `previousPerformance(exerciseID:machineID:tag:presetID:gymID:)`,
`exerciseSections(query:)` (14 groups head→toe + Uncategorized = nil; token search),
`recentExercises(gymID:limit:)`, `searchModels(query:category:)`, `finishSummary(workoutID:)` (re-show a receipt),
`supersetLabels(ofTemplate:)` / `supersetLabels(ofWorkout:)` (id → "A"/"B"), `progressVariationID(for: WorkoutEntry)`.
Pure helpers also callable directly: `Derived.zoneRows(max:)`, `Derived.zoneTimes(_:)`, `Derived.splits(segment)`, `Derived.hrRange(slots)`,
`Derived.supersetLabels(groups: [UUID?]) -> [String?]`, `Derived.variationID(for:)`, `Records.brzyckiKg(kg:reps:)`.

**Live — start/leave:** `startLifting(templateID:)` → `.started` / `.needsConfirmation` (sets `pendingStart`);
`startCardio(activity:plannedID:)` (new cardio workout, or a new segment: ends the unfinished one, skips rest);
`confirmPendingStart()` ("Finish It & Start New": when the live workout differs from its template and prompts are on it only sets
`pendingReplacementDrift` — show the dialog, message "The active workout differs from the template it started from. Choose how to save
that template before starting the next workout." with the four `DriftResolution`s + Don't ask again, cancel "Keep Current Workout";
otherwise it finishes the running workout **without a receipt** and starts the new one),
`resolveReplacementDrift(_:dontAskAgain:)` (finishes, applies the resolution to the old template, starts the pending one),
`keepCurrentWorkout()` (the dialog's cancel: nothing finishes or starts), `resumeInsteadOfPending()`, `cancelPendingStart()`,
`resume()`, `minimise()`, `setFocus(_:)` (Lifting | Cardio), `renameWorkout(_:)` (blank → derived title),
`cancelWorkout()` (Discard Workout), `finish() -> FinishSummary` (drops unticked rows; nothing logged → `saved == false`;
appends to history; sets `finishSummary`, and `pendingDrift` when the template changed and prompts are on), `dismissFinish()`.

**Live — exercises:** `addExercise(_ exerciseID) -> entryID?` (remembered machine at this gym, else first free-weight tag; one draft row, prefilled);
`addByMachine(_ machineID, exerciseID:) -> entryID?` (nil = several exercises: show the machine's list);
`chooseEquipment(machineID:tag:entryID:)`, `choosePreset(_:entryID:)`, `logAsCounterpart(entryID:)` (frozen entries split into a new entry
right after, which stays in the superset and keeps the planned rest; on a frozen split the chosen preset follows, otherwise the new
machine's usual preset is preselected; weights convert through totals when the bar appears/goes — typed 45 bar + 50 per side → 145 total);
`supersetWithNext(entryID:)`, `breakSuperset(entryID:)`, `removeExercise(entryID:)`, `moveEntries(fromOffsets:toOffset:)`.

**Live — sets:** `addSet(entryID:) -> setID?` (inherits last type; carries last completed forward, else prefill);
`completeSet(entryID:setID:) -> SetCompletion?` (nil if not loggable; starts rest unless drop set or a non-last superset member);
`uncompleteSet`, `deleteSet`, `setType(_:entryID:setID:)`, `updateWeight(_:entryID:setID:)` (field value: per side in bar mode),
`updateReps(_:entryID:setID:)`, `toggleUnit(entryID:setID:)` (relabel, no conversion; disabled in bar mode), `setUnit(_:entryID:)`,
`setBar(_ weight?, unit:, entryID:)` (nil = "No bar"; totals preserved), `toggleBarMode(entryID:)`.
Readouts: `setMarker(entryID:setID:)` ("W"/"F"/"D"/"1"…), `supersetLabel(entryID:)` ("A"/"B"/nil),
`previousValue(entryID:setID:)` (last time, same type & position), `isLoggable(entryID:setID:)`, `offersBar(entryID:)`,
`loadType(entryID:)` (the entry's D23 snapshot once a set is completed, else the exercise's).

**Rest:** `addRest(seconds: 15)`, `skipRest()`, `restSettings(for: exerciseID)`, `setRestSettings(_:for:)`,
`restSeconds(entryID:type:)` (override → template → global). Heart-rate mode ends when bpm < threshold
(`lastRestOutcome = .recovered`), at the cap (`.cap`), or degrades to the timer without a reading.
**Sensor toggle:** `setSensor(.live | .stale | .none)` (e.g. L04 degraded variant: `setSensor(.none)`). The mode carries into a newly
started workout (none → no reading, never a made-up 127 bpm).

**Cardio:** `pauseCardio()`, `resumeCardio()` (outdoor: a new route portion, waits for GPS), `endCardio()` (no confirmation), `startPlannedCardio(_ plannedID)`,
`plannedStatus(_:)`, `plannedProgress(_:)` (0…1), `setManualDistance(_:unit:segmentID:)` (live, or history → stamps Edited),
`setGPSUnavailable(_:)` (prototype toggle: "Location unavailable."; back on → waiting, then a new portion).

**Templates:** `newTemplateDraft()`, `newTemplateItem(exerciseID:)` (3 × 10), `saveTemplate(_:)` (insert/replace), `deleteTemplate(_:)`,
`resolveDrift(_:dontAskAgain:)`, `dismissDrift()`, `defaultTemplateName(workoutID:)` ("Workout Sep 24, 2026"),
`canSaveAsTemplate(workoutID:)`, `saveAsTemplate(workoutID:name:) -> templateID?`.

**Gyms & machines:** `selectGym(_:)`, `addGym(name:city:unit:select:)`, `updateGym(_:)`, `deleteGym(_:)`, `restoreGym(_:)`,
`addMachine(gymID:label:modelID:exerciseIDs:unit:presetID:)`, `updateMachine(_:)`, `deleteMachine(_:)`, `restoreMachine(_:)`,
`correctionImpact(machineID:) -> (workouts, sets)`, `correctModel(machineID:to:scope:)`, `addModel(manufacturer:modelName:category:exerciseIDs:)`,
`renameModel(_:manufacturer:modelName:) -> Bool` ("Rename Model", user-made models only; blank refused; history keeps the captured name).
New Model › "Suggest exercises with AI": `suggestModelExercises(manufacturer:modelName:)` (no model-details consent → `.needsConsent`:
show "Send model details to OpenAI?"), `allowModelDetailsAndSuggest(manufacturer:modelName:)` ("Allow and send"), `cancelModelSuggestion()`,
`modelSuggestSetSimulateFailure(_:)`; ≈1.5 s → `.suggested` (e.g. "Rogue" "Monster Hack Squat" → Hack Squat) / `.empty` / `.failed`.
Catalog totals for copy: `SampleData.catalogModelCount` (1,877), `SampleData.catalogManufacturerCount` (23).

**Exercises:** `createExercise(name:loadType:muscleGroup:tags:)`, `renameExercise(_:to:)`, `setLoadType(_:exerciseID:)` (future sets only),
`addPreset(name:exerciseID:) -> id?` (case-insensitive duplicate → nil), `renamePreset(_:to:exerciseID:) -> Bool` (blank or duplicate → false), `deletePreset`.
Suggestions: `SampleData.presetSuggestions`; bars: `SampleData.bars`, `SampleData.defaultBar(for:)`.

**History editing (each stamps Edited):** `updateLoggedSet(_:workoutID:)`, `deleteLoggedSet(_:workoutID:)`,
`addLoggedSet(workoutID:entryID:)`, `addExerciseToWorkout(workoutID:exerciseID:)`, `removeEntry(_:workoutID:)`,
`renameHistoryWorkout(_:to:)`, `setNotes(_:workoutID:)`, `retypeEntry(_:to:workoutID:)` (the entry's load-type menu, D47: re-types the
snapshot, records re-rank); `deleteWorkout(_:)`, `deleteImpact(workoutID:)`.

**Ask AI:** `aiBegin(gymID:)`, `aiUpdateRequest { $0.goals = … }` (routine consent mirrors Settings), `aiNext()`
(goals → equipment → generate), `aiBack()`, `aiGenerate()` (≈3 s; `progressText` stages: "Building your week…" (real)
then PROPOSED "Checking equipment at Iron Temple…", "Balancing muscle families…", "Fitting sessions to your time…"),
`aiCancelGeneration()`, `aiSetSimulateFailure(_:)` (next run → `.error` with real copy), `aiChangePreferences()`,
`aiUpdateDay(_:)`, `aiAddItem(dayID:exerciseID:)`, `aiRemoveItem(dayID:itemID:)`, `aiMoveItem(dayID:fromOffsets:toOffset:)`,
`aiAddCardio(dayID:activity:)`, `aiRemoveCardio(dayID:cardioID:)`, `aiSave() -> [templateID]` (atomic; step `.saved`).

**Scan:** `scanBegin(gymID:)`, `scanSetDemoKind(_:)` (what the next result is), `scanToggleTorch()`, `scanShutter()`
(→ `.consent` if photos not allowed, else identifying ≈2.5 s), `scanAllowPhotos()`, `scanRetake()`,
`scanSelectCandidate(_:)`, `scanSetLabel(_:)`, `scanSetExercises(_:)` (≤ 6), `scanUseGeneric()`,
`scanConfirm() -> machineID?` (adds the machine; new-model kind also adds the model), `scanCancel()`,
`scanSetSimulateFailure(_:)` (the next identification ends `.error`; `scanRetake()` clears it).
Copy: `ScanSimulator.uncertainLine`, `store.scanResolutionLine` (real footer copy).

**Settings & export:** `saveAIKey(_:)`, `removeAIKey()`, `setConsent(_:_:)` (revoking cancels AI / scan like the real app),
`export(_ format)` (≈0.8 s → `.done(fileName:)`, sets `settings.lastExportAt`; with `exportSetSimulateFailure(true)` → `.failed`,
nothing recorded), `resetExportState()`. Revoking model-details consent abandons a suggestion in flight.

**Screens:** `reset(to: ScreenID)` — fresh sample data, clock back to Thu 18:30, then the state below.
`Store(screen:freezeClock:)` does the same at launch. `Store.liveActivitySample(_ screen)` → another state's Live Activity.

## 4. ScreenID (Prototype/ScreenID.swift)

`enum ScreenID: String, CaseIterable` — raw values "W01"…"Z05" (69 cases). `init?(argument:)` accepts
"H03", "h03", "H03-WorkoutDetail". Members: `row` (1–12), `rowName`, `title`, `note`, `tab: AppTab`,
`presentation: ScreenPresentation` (`.tabRoot/.push/.sheet/.cover/.dialog/.system`), `overLiveWorkout`,
`static rows`. `AppTab` (`.workout/.history/.gyms/.exercises`, `label`, `symbol` = the kept tab icons).

## 5. reset(to:) — the state each screen gets

Base (every reset): 3 gyms (Iron Temple lb, Gangnam Fitness kg, Hotel Gym no unit), 22 machines (16 active +
2 deleted at Iron Temple, 4 at Gangnam; Seated Row's usual preset is Narrow grip), 56 exercises (55 seeded + the
user-made Landmine Press, Uncategorized), 4 templates (Leg Day, Pull Day, Push Day — Lateral Raise + Triceps Pushdown
superset, Whole Body — Bench Press + Lat Pulldown superset), 22 workouts Aug 10 – Sep 23, Iron Temple selected, no
session. This week: Mon Pull Day + Indoor Run, Wed Leg Day (3 workouts, `trainingDayCount` 2); last week 4; streak 6
completed weeks + this week. X01 `settings.historyUpdate` = 6 sets on Sep 4 (the Aug 31 hotel session's reclassified
Dumbbell Bench Press / Dumbbell Row).

| ID | State | `screenTarget` |
|---|---|---|
| W01, W04, Z02, Z04 | base | — |
| W02 | L01 session, minimised (`isSessionPresented = false`) | — |
| W03 | no gyms, machines, templates or history; no gym selected | — |
| W05 | L01 session minimised + `pendingStart` Whole Body. `confirmPendingStart()` → `pendingReplacementDrift` (5 changes: Seated Chest Press −1 set, Incline / Lateral / Triceps Removed, shoulder reps) | templateID Whole Body |
| T01, T02 | base (Push Day rows: Lateral Raise A + Triceps Pushdown B via `supersetLabels(ofTemplate:)`) | templateID Push Day |
| T03 | F01 + `pendingDrift` (5 changes: +1 set ×4, shoulder reps) | workoutID today, templateID Push Day |
| T04 | F01 (use `defaultTemplateName`) | workoutID today |
| A01 | `ai.step .goals`, goals text, Intermediate, 3 days, 45 min, 178 cm / 76 kg | — |
| A02 | + `.equipment`: Iron Temple (16 machines), Dumbbells/Adjustable bench/Cable, Indoor Run + Cycle, consent on | — |
| A03 | `.generating` at 35 % "Checking equipment at Iron Temple…" (continues if the clock is not frozen) | — |
| A04 | `.preview`: Day 1–3 — Fitness (4–5 exercises, 3 × 10, 60 s; cardio 15 min on days 1 and 3) | aiDayID Day 1 |
| A05 | as A04 | aiDayID Day 1 |
| L01, Z05, L06, L07, L12 | Push Day live 18:42, 7/18 sets, 4,120 lb, 128 bpm Zone 2, 96 cal, rest 1:24 of 2:00, `lastCompletion` = Seated Chest Press 110 × 8 new best (prev 105 × 8) 36 s ago (`freshNewBest == nil`); set 3 prefilled 110 × 8. Entry order: Machine Shoulder Press (4/4 done, dragged to the top — Chest Press 2 was busy), Seated Chest Press (current), Incline Chest Press (next), Lateral Raise A + Triceps Pushdown B | entryID Seated Chest Press |
| Z01 | L01 with `isSessionPresented = false` (system surface); `store.liveActivity` (Seated Chest Press, 7/18, rest 1:24, 128 bpm Zone 2); cardio variant `Store.liveActivitySample(.c02)` | entryID chest |
| L02, L09 | Whole Body live 14:05: Bench Press (A, 45 lb bar: W 95×10 ✓, 135×8 ✓, F 135×6 ✓, 135×8 prefilled), Lat Pulldown (B: W ✓, 120×10 ✓, 125×10 typed, D 100×12 prefilled), other exercises prefilled, no rest running; HR log seeded (116 / 142) | entryID Bench Press, setID Lat set 3 (swipe row), secondarySetID Bench set 4 (menu row) |
| L03 | L01 at 18:06, the instant set 2 completed: rest 2:00, `freshNewBest` non-nil (its own `lastCompletion.id`) | entryID chest, setID set 2 |
| L04 | L01 at 18:58 with chest rest in heart-rate mode (below 110, cap 4:00; 0:52 in, 124 bpm). Degraded variant: `setSensor(.none)` | entryID chest |
| L05, L08, L10, L11 | L01 | entryID chest (menu / equipment (frozen) / previous performance / rest settings); L08 also secondaryEntryID Lateral Raise (not started: "Log as Dumbbell Lateral Raise instead") |
| L13 | L01 + 2 typed-unticked rows (`unloggedSetCount == 2`) | entryID chest |
| C01 | base (picker from Home; the "ends the current segment" note applies only with a session) | — |
| C02 | Push Day lifting done (22/22) + Indoor Run recording 12:48, 1.47 mi (8:43 /mi avg), 146 bpm, planned 20 min target (64 %), focus cardio; HR log seeded (lifting then run) | segmentID |
| C03 | C02 paused at 12:48 | segmentID |
| C04 | Outdoor Run only, 8:12, 0.94 mi, GPS live, 149 bpm (route recorded but never shown live). GPS-lost variant: `setGPSUnavailable(true)` | segmentID |
| C05 | C02 but the run ended at 20:05, 2.31 mi (target done) — open the distance sheet | segmentID |
| F01 | today's Push Day in history + `finishSummary`: 52:10 · 18,450 lb · 312/398 cal · 124/158 bpm · zones 6:40/14:20/18:05/9:30/3:35 · bests Seated Chest Press 110×8, Machine Shoulder Press 80×10 · vs Sep 17 17,400 lb +6% | workoutID |
| F02 | Push Day + Outdoor Run (19:30, 2.09 mi, Seoul Forest route) receipt: 1:13:10, 131 / 168 bpm; two-phase HR (the run shows as the high last stretch); zones Z1 30:00 · Z2 13:45 · Z3 21:45 · Z4 7:45 | workoutID |
| F03 | `finishSummary.saved == false` | — |
| H01 | base | — |
| H02 | base | date Sep 21 (Pull Day + Indoor Run) |
| H03 | base | workoutID Sep 19 Whole Body (Edited Sep 20; 1:07:00, 23 sets, 2 PRs; Bench Press bar breakdowns "45 lb bar = 45 lb" (W) / "45 + 45 × 2 = 135 lb" / "45 + 50 × 2 = 145 lb", superset A/B with Lat Pulldown, Seated Chest Press · Narrow grip, Dumbbell Curl, Indoor Cycle 15:00, two-phase HR 121 / 153), entryID Bench Press |
| H04 | base | workoutID Aug 29 Outdoor Run (Central Park, 4.1 mi, 36:50, 30 points), segmentID |
| H05 | base | workoutID Sep 17, entryID its Seated Chest Press entry, setID working set 2 (105 × 8, a PR) |
| H06, E02, E04 | base | exerciseID Seated Chest Press (variation labels: "Chest Press 2" (6 days), "Chest Press 2 · Narrow grip" (2), "Chest Press · Gangnam Fitness" (1) — a machine at another gym than the exercise's usual one gets the gym) |
| H07 | no workouts | — |
| G01 | base | — |
| G02 | no gyms / machines, no gym selected | — |
| G03, G05, G06, G07 | base | gymID Iron Temple ("Nothing deleted" variant: Gangnam Fitness) |
| G04 | base | gymID, machineID Chest Press 2 (no usual preset; bests "Seated Chest Press 105 lb × 8" ×6, "· Narrow grip 90 lb × 10" ×2), secondaryMachineID Seated Row (usual preset Narrow grip; best 110 lb × 10) |
| S01 | `scan.step .camera` at Iron Temple | gymID |
| S02 | photo consent off, `.consent` | gymID |
| S03 | `.identifying` at 60 % (continues if not frozen), `hasPhoto`. Failure variant: `scanSetSimulateFailure(true)` before the shutter (or S01 + shutter) → `.error` | gymID |
| S04 / S05 / S06 | `.result` specific (Matrix MG-PL71 Hack Squat, 0.93) / ambiguous (3 Watson candidates) / generic, `hasPhoto` | gymID |
| S07 | base | gymID, machineID Lat Pulldown (8 workouts, 33 sets) |
| E01, E03, X01, X02, X03 | base (AI key saved "sk-…a1b2"; consents photos on, routine on, model details off; last export Sep 12 CSV; X01 history update line; X03 failure variant `exportSetSimulateFailure(true)`) | — |
| E05 | base | exerciseID Dip (BW + added: Aug 26 best 10 lb × 8, Sep 12 15 lb × 8 new best) |
| Z03 | L01 session, not presented, no rest running, `lastRestOutcome = .recovered(bpm: 108)`; titles/bodies from `RestOutcome` for the three variants | — |

Empty variants reachable without a reset: Add by Machine at Hotel Gym (`activeMachines(gymID: SampleData.gymID("Hotel Gym"))` is empty),
previous-performance empty layers (e.g. Leg Extension has no same-model layer), progress `.single` (the Gangnam variation).
Load-type samples: Assisted Pull-Up on Assist Dip/Chin every Pull Day (90, 90, 80, 70 lb assist — lower is better; chart change +22%),
Dip BW + added (above), Hanging Knee Raise BW + added logged as 0 lb (plain) at the hotel.

## 6. Sample-scenario notes and PROPOSED strings

- New strings in the model layer the user has not approved: AI progress stages 2–4, `DriftResolution.consequence`,
  `AppSettings.aiKeyHint` masking, layer titles "This machine"/"This equipment", `WeekStreak` (feature), the model-suggestion
  reason line ("“Hack Squat” is in the model name."), the scan placeholder caption, and the simulated system error after
  "Export failed: " ("The file “…” couldn’t be saved.").
- **L01 decisions (flag to the user):** set 3 shows the brief's 110 × 8. Under the real rule a template draft prefills from last
  time (Sep 17: 105 × 8, which the PREVIOUS column still shows); carry-forward of a just-completed set applies only to Add Set.
  Machine Shoulder Press (third in the template) was done first and sits at the top of the list, so the card order reads
  done → current → next.
- PR badges vary: history workouts carry 0–4 new bests (Sep 12 Push Day is the big day with 4; plateaus elsewhere). Records per
  scope; F01's two new bests (Seated Chest Press 110 × 8, Machine Shoulder Press 80 × 10) and Sep 17's 17,400 lb are unchanged.
- Seated Chest Press on Chest Press 2 (plain): Aug 10 90×8 · Aug 12 95×8 · Aug 26 100×8 · Sep 10 100×10 · Sep 12 100×8 · Sep 17 105×8 → today 110×8.
- Month (Sep, before today): 9 workouts, 155 sets, 7.9 h (derived; the brief's 186 sets / 7.4 h were illustrative).
- Live heart rate eases (≤ ~4 bpm/s); sample sessions that start mid-way (L01, L02, C02–C05) carry a seeded HR log, so finishing
  them yields the HR graph, zones and avg / max tiles.
