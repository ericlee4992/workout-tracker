# Domain data brief: what the redesign can show

Scope: `WorkoutTracker/Domain/*` (69 files, about 13.8k lines). I read it at branch `ericlee4992/redesign-visual-proposal`, HEAD `a0364f2`, with a clean tree. I also read the shared Live Activity and Watch payloads, the SwiftUI `#Preview` blocks, the UI-test fixtures and the seed catalog JSON so the sample content below is real. I did not edit any repository file.

In the paths below, `M` = `WorkoutTracker/Domain/Models.swift`, and other Domain files are named without their folder.

---

## 0. Key facts for the design (read first)

1. **Weekly schedule: none.** Weekday, calendar-plan and "next session" data do not exist. The AI routine (D58, "not a calendar") saves N ordinary `WorkoutTemplate`s named like `"Day 1 — Fitness"`. Nothing groups them into a week or orders them. The request's `days`/`minutes`/`goals`/`height`/`weight` are transient and are never stored.
2. **PRs and new-record detection: none.** Records are computed on demand for one entry's performance sheet (`PerformanceHistory.summary`). No code marks a set or workout as a new record. Streaks, weekly totals, lifetime totals and per-muscle volume are not implemented anywhere, in Domain or Features. (`rg` for streak/lifetime/PR returns only comments.)
3. **Muscle grouping is thin.** An `Exercise` has one optional `muscleGroup: String?` (14-value vocabulary, `CatalogBrowsing.swift:65`). `MuscleFamily` folds it into 5 families (`MuscleFamily.swift:11`). Secondary muscles do not exist. **`muscleGroup` is not in the entry snapshot.** It is a live catalog field that `CatalogSeeder` can change, so a per-muscle history view reads live data. That is the one D23 exception such a view would have to accept.
4. **Volume counts only `weighted` sets** (D21). Assisted, bodyweight and BW+added sets add 0. A volume-per-muscle chart would under-report back and chest for someone who does pull-ups and dips. The honest metric that works for every load type is **completed non-warmup sets**.
5. **Every heart-rate and calorie field is optional, and missing is not zero** (D44). The design needs an absent state for every HR, zone and calorie element, and must never show "0 bpm". **D52: screens show plain numbers**: no ≈ on converted weights, no "(estimated)" on zones. **"1RM"**, not "Estimated 1RM".
6. **History renders from frozen snapshots** (D23): the exercise, machine, model, gym and preset names captured at first set completion. A redesign must never label past sets with live names. Edited workouts carry `historyEditedAt`, and the UI must show that they were edited (D47).

---

## 1. Models (SwiftData, CloudKit-compatible)

Schema list: `M:847-863`. All relationships are optional. There are no unique constraints, and ordering always uses scalar `order` fields.

### Catalog
| Model | Fields | Relationships |
|---|---|---|
| `Exercise` `M:19` | `id`, `name`, `loadType: LoadType`, `equipmentTypeTags: [EquipmentTag]`, `muscleGroup: String?` (one of 14 or nil), `isSeeded`, `loadTypeUserOverridden: Bool?` | `entries` (nullify), `templateItems` (nullify), `presets` (cascade) |
| `ExercisePreset` `M:76` | `id`, `name` (for example "Wide grip"), `order` | `exercise`, `entries`. User-created only. **Records split per preset** (D36) |
| `EquipmentModel` `M:95` | `id`, `manufacturer`, `modelName`, `exerciseIDs: [UUID]`, `equipmentType: EquipmentCategory?`, `isSeeded`; `displayName = "\(manufacturer) \(modelName)"` | `machines` |

### Gyms and machines
| Model | Fields | Notes |
|---|---|---|
| `Gym` `M:134` | `id`, `name`, `city?`, `defaultUnit: WeightUnit?`, `notes`, `archived` | `machines`, `workouts`. Archived instead of deleted. **No photo, location, color or icon** |
| `MachineInstance` `M:166` | `id`, `label` (for example "Chest Press 2"), `recognizedExerciseIDs`, `defaultUnit?`, `defaultPresetID?`, `archived`; computed `supportedExerciseIDs` `M:172` | `gym`, `model` (optional; a machine can have no model), `entries`. **No photo stored**: scanner photos are cropped, sent to the AI and not kept |
| `GymExerciseMemory` `M:638` | `gymID`, `exerciseID`, `machineID?`, `updatedAt` | "Last machine used for this exercise at this gym." Drives the machine auto-pick |

### Templates
| Model | Fields |
|---|---|
| `WorkoutTemplate` `M:212` | `id`, `name`, `cardioPlanData` (JSON `[PlannedCardio]`), `generatedForGymID?` (set on AI templates), `confirmedEquipment: [String]`, `items`. **No `order`, `createdAt`, color, icon or folder.** Template ordering and customisation would need new fields |
| `TemplateItem` `M:230` | `order`, `targetSets?`, `targetReps?`, `targetRepsBySet: [Int?]` (per-slot reps), `supersetGroupID?`, `plannedRestSeconds?`, `preferredEquipmentTag?`, `exercise` |
| `PlannedCardio` (struct, `PlannedCardio.swift:4`) | `activity`, `minutes` (1–180), `distance?` (≤200), `unit`, `segmentID?` (link once started); `summary` = "20 min · 3 km" `:11` |

### Workout history
| Model | Fields |
|---|---|
| `Workout` `M:275` | `startedAt`, `finishedAt?` (nil = active), `notes`, `name?` (typed title), `sourceTemplateID?`, `sourceTemplateName?` (snapshot), `snapshotGymName?`, `historyEditedAt?`, rest-timer persistence `restEndsAt`/`restStartedAt`/`restStartedBySetID`; **HR summary** `averageHeartRate?`, `maxHeartRate?`, `activeEnergyKilocalories?`, `basalEnergyKilocalories?`, `zoneSeconds: [Int]` (index 0…5), `zonesFromEstimatedMax?`, `heartRateSeries: [Int]` + `heartRateSeriesLow/High: [Int]` (15 s buckets, 0 = gap), `heartRateSeriesIntervalSeconds?`; in-flight sensor checkpoint fields `M:374-379`; `cardioPlanData`; relationships `gym`, `entries` (cascade), `cardioSegments` (cascade), `sensorSampleRows`. **No rating, mood, RPE, photos or bodyweight** |
| `ExerciseEntry` `M:436` | `order`, `plannedRestSeconds?`, `plannedRepsBySet`, `freeWeightTag?`, `supersetGroupID?`; live `exercise`/`machine`/`preset`; **frozen snapshot** `snapshotCapturedAt`, `snapshotExerciseID/Name`, `snapshotLoadType`, `snapshotFreeWeightTag`, `snapshotMachineID/Label`, `snapshotModelID/Name`, `snapshotGymID/Name`, `snapshotPresetID/Name`; provenance `reclassifiedAt`, `reclassifiedFromExerciseName` (D51) |
| `SetRecord` `M:548` | `order`, `type: SetType`, `reps?`, `weightValue?` (TOTAL, bar included), `weightUnit`, `normalizedKg?`, `completedAt?` (nil = draft), `barWeightValue?`/`barNormalizedKg?` (bar provenance), `prefilledAt?` (inherited, not typed). **No RPE/RIR, tempo, per-set note or duration** |
| `CardioSegment` (`Cardio.swift:115`) | `order`, `activityRawValue`, `startedAt`, `endedAt?`, `activeStartedAt?`, `accumulatedActiveSeconds`, `intervalsData` (pause intervals), `routeData` (`[CardioRoutePoint]` lat/lon/date/accuracy/**portion**), `distanceSpansData`, `automaticDistanceMeters?`, `distanceSourceRawValue?`, `manualDistanceValue?` + unit, `displayUnitRawValue`, `averageHeartRate?`, `maxHeartRate?`, `heartRateTotal/Count`, `activeEnergyKilocalories?`, `basalEnergyKilocalories?` |
| `WorkoutSensorSample` (`WorkoutSensorSample.swift:7`) | `bpm`, `date`, `source`. **In-flight only**: deleted once the summary is frozen at finish. Raw samples do not survive into history; only the 15 s buckets do |

### Preferences and overrides
| Model | Fields |
|---|---|
| `AppPreferences` `M:664` | `unitPreference?` (kg/lb, also sets km/mi through `AppUnitSystem`), `driftPromptSuppressed`, `globalWorkingRestSeconds = 120`, `globalWarmupRestSeconds = 60`, `measuredMaxHeartRate?`, `birthDate?`, `selectedGymID?`, catalog-browse state, dumbbell-move record, `notificationPermissionRequested` |
| `ExerciseRestOverride` `M:803` | `exerciseID`, `workingRestSeconds?`, `warmupRestSeconds?`, `restMode?` (`.standard` "Timer" / `.heartRate` "Heart rate"), `heartRateThresholdBpm?`, `heartRateCapSeconds?` |

### Enums the UI renders (display strings are in code)
- `SetType` (`SharedEnums.swift:19`): warmup "W", working (no marker), failure "F", drop "D". Display names are "Warmup/Working/Failure/Drop". `countsTowardRecords` excludes warmup only `:58`. `startsRestTimer` is false for drop sets `:48`.
- `LoadType` `:61`: badges "Weighted", "Bodyweight", "BW + added", "Assisted".
- `EquipmentTag` `:77`: Machine, Barbell, Dumbbell, Cable, Smith machine, Bodyweight.
- `EquipmentCategory` `:109`: Selectorized, Plate-loaded, "Cable & functional", "Rack, Smith & bench", "Bodyweight station" (nil = "Uncategorized").
- `CardioActivity` (`Cardio.swift:4`): Indoor Walk/Run/Cycle, Elliptical, Rowing, Stair Stepper, Outdoor Walk/Run/Cycle. Cycling activities show speed (`usesSpeed`).
- `CardioDistanceSource` `:33`: "HealthKit estimate", "Phone motion estimate", "GPS", "Mixed distance sources". D52 hides source captions for automatic indoor distance on screen; the source is still stored.
- `HeartRateSource` (`HeartRate.swift:15`): "AirPods", "Apple Watch", "Heart rate monitor", "Test data". Precedence: Watch > other monitor > AirPods.
- `HeartRateZone` (`HeartRateZones.swift:78`): Warm-up / Zone 1–5 with descriptions ("Below training intensity", "Very light", "Light — endurance", "Moderate — aerobic", "Hard — threshold", "Maximum").
- `RoutineEquipment` (`AIRoutine.swift:4`): Dumbbells, Flat bench, Adjustable bench, "Barbell, plates and rack", "Cable station and attachments", Smith machine, Pull-up bar, Dip station.
- `CatalogGrouping`: Manufacturer / Body area / Equipment type / A–Z. `MachineGrouping`: Exercise / Body area / A–Z.

### Outside Domain but shared (design-relevant)
- **Live Activity** (`WorkoutTrackerWidget/Shared/WorkoutActivityAttributes.swift:15`). Fixed attributes: `workoutID`, `startedAt`, `gymName?`. Content state: `heartRateBpm?`, `zoneLabel?` ("Zone 3"), `restEndsAt?` (the system ticks it down), `completedSets`, `currentExercise?`.
- **Watch link** (`WorkoutTrackerWatch/Shared/WatchLink.swift`): `bpm`, `timestamp`, `workoutActive`, `restEndsAt`, `workoutID`.

---

## 2. Computations that already exist

### Records and PRs: `RecordsMath.swift`
- **Eligibility** `isEligible` `:92`: the set must be completed and have reps > 0, and it must not be a warmup (failure and drop sets count). Load rules: weighted needs kg > 0; assisted and BW+added need kg ≥ 0 (0 = unassisted or plain); bodyweight ignores load.
- **Ranking** `outranks` `:124`: load comes first, compared through `normalizedKg`. **Assisted: lower is better** `:137`. Then more reps, then the earlier date (a tie keeps the earlier set; it is never a new record).
- **Rep-count table** `repCountBests` `:151`: best set per rep count **1–12** (`repRecordCap = 12` `:84`). Weighted = heaviest, assisted = least assistance, BW+added = most added.
- **Bodyweight** `mostRepsRecord` `:165`: most reps, uncapped.
- **1RM (Brzycki)** `brzyckiE1RMKg` `:191`: `w / (1.0278 − 0.0278 × reps)`, for 1–12 reps only. `bestE1RM` `:199` covers **weighted only** (D20).
- **Volume** `totalVolumeKg` `:233`: Σ(normalizedKg × reps) over eligible **weighted** sets. Dumbbells are per hand and never doubled.
- **Grouping** `groupKeys` `:249`: every set goes under `.exercise(id, preset)`, plus `.machine(id, preset)` **or** `.freeWeight(exercise, tag, preset)`, plus `.model(id, preset)` when a model exists. **The preset is always part of the key.**

### Previous performance, fallback layers and prefill: `PreviousPerformance.swift`
- Three layers (D1) `:4`: **thisEquipment** → **sameModelElsewhere** (same model at another gym, only when the machine has a model and the workout has a gym) → **anyEquipment** (the exercise anywhere). All three are scoped to the current preset.
- `summary(for:)` `:168`: layers plus per-layer records in one pass. `RecordLayerSummary` `:68` holds `repCountBests`, `bodyweightBest` and `estimatedOneRepMax`. It uses the dominant snapshot load type `:333`.
- Empty-state copy `:15-29`: "No completed sets on this machine yet." / "No completed sets with this equipment yet." / "No other gyms with this model logged yet." / "No history for this exercise yet." / "No eligible records at this layer yet."
- **Next-set prefill (across workouts)** `prefill(for:)` `:103`: matches by set type and position among sets of that type in the latest finished matching workout (layer 1 only). `applyPrefill` `:126` never overwrites a row the user has touched, carries the bar and stamps `prefilledAt`.
- **Carry-forward within a session** `WorkoutSession.addSet` `WorkoutSession.swift:527`: a new row copies the entry's last completed set (weight, unit, reps, bar). Once a set is completed, this outranks the previous-workout prefill.
- `PreviousSetValue.displayLabel` `:46` → `"60 kg × 10"` or `"12 reps"`.

### Progress charts: `ProgressSeries.swift`
- `series(for:variation:)` `:197`: one point per **calendar day** for one variation key (load type × equipment × preset, `:123`). Each point carries `bestKg` (reps for bodyweight), `bestReps`, as-entered `bestValue/Unit`, `volumeKg`, `e1rmKg` and `enteredUnits`.
- `ProgressConfidence` `:46`: `.empty` / `.single` (draw a point, **never a line**) / `.series(days:)`.
- `change(_:)` `:297`: first→last % change, flipped for assisted. nil for fewer than 2 points or a zero baseline.
- `rankedVariations`/`defaultVariation` `:163/187`: the chart opens on the variation with the most training days. `labels(for:)` `:344` builds unique picker labels (for example "Dumbbell", "Narrow grip", "Chest Press · Wide grip · Assisted · Gym").
- `loadAxisLabel` `:66`: "Assistance (less is better)", "Reps", "Added weight", "Weight". `higherIsBetter` is false for assisted.
- UI today (`Features/History/ExerciseProgressView.swift:40`) has three metrics: **Best set / Volume / 1RM**. You reach it from WorkoutDetail and the Exercises tab.

### Finish and workout summary: `WorkoutSummary.swift`
- `WorkoutSummaryBuilder.summary(for:)` `:87`: date, gym name (snapshot), duration, `totalVolumeKg` (RecordsMath), `completedSets`, per-exercise lines (name, equipment, preset, set count, **best set label** such as "60 kg × 10 (20 kg bar)", warmups excluded `:150`), plus every persisted HR field.
- `totalEnergyKilocalories` `:57`: active + basal, **only when both exist**.
- `hasHeartRate`, `hasHeartRateSeries` `:45/62`.
- `WorkoutFinishOutcome` (`WorkoutSession.swift:16`): `.saved` / `.discardedEmpty`. A finish with nothing logged deletes the workout, and the UI must say so.
- `HistoryEditing.impact(ofDeleting:)` `HistoryEditing.swift:236`: exercises, sets and volume that a delete would destroy (for the confirm dialog).

### History rendering: `HistoryRendering.swift`
- Title `title(...)` `:88`: typed name, else template snapshot, else "First Exercise +N", else "Workout". Cardio activity names count as exercises (`historyTitle` `:166`).
- Duration `durationLabel` `:115`: "<60 s" becomes "45s", otherwise "N min" (whole minutes).
- Stats line `:121` / `historyStatsLine` `:182`: "3 exercises · 12 sets · 52 min · 1 cardio activity".
- `WorkoutUnitBadge` `:8`: "kg" / "lb" / "Mixed" from the units of completed sets.
- `snapshotEquipmentLabel` `:38`: "Chest Press 2 · Life Fitness … · Wide grip", or the tag label, or "No equipment".

### Calendar: `WorkoutCalendar.swift`
- Month grids from the first workout month to today `:73`. The first weekday follows the locale. A day is marked when a finished workout **started** on it.
- Six cell emphasis states `:38`: plain, future, today, marked, markedToday, markedFuture. **No per-day intensity**: it is a boolean mark only.
- `workoutToOpen(on:)` `:163`: opens the latest workout started that day.

### Heart rate, zones and calories
- Max HR `MaxHeartRateResolver.resolve` (`HeartRateZones.swift:49`): the measured value wins, else 220 − age (age at the workout date), else **nil = no zones at all**.
- Zones `:88`: **55/65/75/85/95 % of max**, 5 points above the textbook values (D45). **Not comparable with Apple or Polar zones.** `zone(for:max:)` `:132`.
- Vitals fold `WorkoutVitalsMath.vitals` (`WorkoutVitals.swift:108`): average and max bpm, plus seconds per zone measured between samples. Gaps over 60 s count toward no zone `:40`. The dominant sensor is chosen, and the other sensor fills its outages `:46-101`.
- Series `HeartRateSeriesMath.fold` (`HeartRateSeries.swift:57`): 15 s buckets holding mean, low and high (0 = gap), capped at 5,760 buckets. `displaySlots` `:150` merges buckets to **at most 110 bars**, and gaps stay holes. `range(of:)` `:214` gives the chart's own y-axis.
- `ZoneBarLayout.widths` (`ZoneBarLayout.swift:16`): stacked zone bar with a 4 pt minimum segment and a 2 pt gap.
- Live: `HeartRateMonitor.current` `:121`, `isStale` (>15 s, `HeartRate.swift:87`) `:128`, `currentZone` `:133`, `currentSource` `:140`. **Feed states to design** (`HeartRateMonitor.swift:17`): idle, needsAuthorization, denied, waitingForSensor, live(source), unavailable.
- Calories are **only the system's numbers** (HealthKit active and basal). The app never calculates them.

### Rest timer
- Duration rule (`RestTimer.swift:99`): per-exercise override → template `plannedRestSeconds` (working only) → global (2:00 working, 1:00 warmup; failure uses working). **Drop sets start no timer.**
- `RestTimerState {end, remaining, total}` `:69`: progress fraction = remaining/total. `add(seconds:)` `:292` (+15 s in the UI). `skip` `:315`.
- **Heart-rate rest** (D43) `HeartRateRestRule.evaluate` (`HeartRateRest.swift:76`): defaults are threshold 110 bpm (the rest ends at a reading strictly below it) and cap 4:00 `:58-59`. States: `resting(elapsed)` / `finished(.recovered(at,bpm))` / `finished(.cap)` / `degraded` (no sensor, falls back to the standard timer and says so, `RestTimer.swift:224`).
- Notification copy: "Rest complete" / "Time for your next set." / "Heart rate down to N bpm — ready for your next set." / "Time is up — your heart rate didn't reach the target." / "No heart rate reading — resting by the timer instead."
- Alarm sounds (`RestAlarmTone.swift:41`): **recovered** = two rising tones (880→1175 Hz), **cap** = three flat 880 Hz tones.
- Supersets (`Supersets.swift`): `runs(of:)` `:34`, member labels **A/B/C** `:64`, and rest **only after the last member** `:106`.

### Weights, units and barbell
- `WeightMath` (`WeightMath.swift`): 1 lb = 0.45359237 kg `:13`. `displayNumber` shows up to 2 decimals, trims zeros and rounds half-up `:46`. `displayLabel(for:in:)` gives "60 kg" or a plain converted "132.28 lb" `:61`. `displayLabel(kilograms:in:)` is for derived numbers such as volume and 1RM `:75`.
- `Format.weight` (edit fields) `SharedEnums.swift:133`, `Format.duration` "m:ss" `:141`, `Format.elapsed` "12:34" / "1:02:03" `:159`.
- `UnitPrecedence.defaultUnit` (`UnitPrecedence.swift:12`): machine → gym → app → locale.
- `BarbellMath` (`BarbellMath.swift`): bar presets `:67` (Olympic 20 kg, Women's 15 kg, Technique 10 kg; Olympic 45 lb, Women's 35 lb, Technique 15 lb); `total = bar + 2 × perSide` `:93`; `platesPerSide` `:105`; "= 135 lb" `:114`; history text "45 + 45 × 2 = 135 lb" / "45 lb bar = 45 lb" `:125`. Bar mode applies to barbell and Smith tags, or to a machine whose model is `rackOrSmith` (`WorkoutSession.swift:641`).
- Loggability `isLoggable` (`WorkoutSession.swift:761`): reps > 0 always, plus a weight value for weighted, assisted and BW+added (0 allowed for the last two). The check-mark stays disabled until the row is loggable.

### Cardio: `Cardio.swift`, `CardioRecorder.swift`
- `activeDuration(at:)` `:204` excludes pauses. `distanceMeters` `:156`: a manual entry overrides the automatic value.
- Pace `CardioMath.pace(seconds:meters:unit:)` `:85`, pace from speed `:89`, `paceText` "m:ss" (or "—") `:93`. The UI shows "Average pace" and "Current pace …/km" (`Features/Cardio/CardioViews.swift:107,119`). Speed is recorded but no km/h label exists for cycling in Domain.
- Distance source selection `CardioDistanceSpan.selectSource` `:54`: GPS > HealthKit > phone motion.
- Route: GPS points in **portions**. Never join across a pause or an outage (`:80`). Accuracy ≤ 50 m. Haversine `meters(between:)` `:98`.
- Per-segment HR average and max `record(_:)` `:226`. Per-segment active and basal kcal.
- The recorder publishes `currentSpeedMetersPerSecond`/`freshSpeed` and `locationMessage` ("Allow location to record distance and your route.", "Precise Location is off. Route accuracy is limited.", "Waiting for GPS…", "Location unavailable.", "GPS unavailable. Recording time continues.", "Motion data unavailable.").
- Planned cardio vs actual: a target links a segment through `segmentID`. Targets never become measurements (D57). `canStart` is at `PlannedCardio.swift:63`.

### Templates, drift and AI
- `TemplateTargets.summary` (`WorkoutTemplates.swift:67`): "3 sets · 10, 10, 8 reps" / "3 sets" / "No sets".
- `start(_:at:)` `:140`: creates empty draft rows (targets are never written as performed), restores supersets, and picks the remembered machine (or the only compatible machine for AI templates at their own gym).
- `saveAsTemplate` `:200`: completed structure only. Cardio minutes are rounded.
- Drift (`TemplateDrift.swift`): resolutions `updateTemplate` / `updateValuesOnly` / `updateBoth` / `keepOriginal` `:17`. The prompt is suppressible (`driftPromptSuppressed`).
- `MuscleFamily.families(of:)` (`MuscleFamily.swift:34`): the icon strip on template tiles (Chest, Back, Shoulders, Arms, Legs, in that order).
- AI routine (`AIRoutine.swift`): `RoutineAvailability.exercises` `:30` filters to equipment actually available. `AIRoutine.validated` `:95` allows 1–7 sessions, at most 10 strength items and 3 cardio blocks per day, 1–10 sets, 1–50 reps and 0–600 s rest. A duration estimate of 45 s per set + rest + 60 s per exercise must be ≤ minutes × 75 s `:117`. The prompt forbids weights and load predictions `:89`.
- Equipment AI (`EquipmentIdentification.swift`): identity `specific`/`generic`/`uncertain`, at most 6 exercise IDs. `ExerciseProposalAPI` proposes at most 6 exercises, each with a one-line reason.

### Catalog browsing: `CatalogBrowsing.swift`
- Token search regardless of order `:233`. Filters never hide an uncategorized row (D24) `:243`. Section builders sort by body area in head-to-toe order `:65`.

### History editing: `HistoryEditing.swift`
- Set edit `apply` `:44`, change an entry's load type `retype` `:142`, add an exercise to a past workout `addEntry` `:182` (no equipment guessed), `deleteEntry` `:208`, `rename` `:279`. **Every one stamps `historyEditedAt`.**

---

## 3. Not computed today: derivable vs needs new data

Legend: **D** = derivable from stored data with new pure logic only; **N** = needs new stored data (a schema change needs a migration, an optional field and a backup check per DEVELOPMENT); **D\*** = derivable but bound by a rule the display must respect.

### Training volume, frequency and consistency
| Idea | Status | Source / how | Constraints |
|---|---|---|---|
| Workouts this week / month, weekly frequency bars | **D** | `Workout.finishedAt != nil`, bucket by `startedAt` (the same start-day rule `WorkoutCalendar` uses) with the locale `firstWeekday` | A running workout is not history |
| Streak (consecutive active weeks or days) | **D** | same | Use weeks rather than days if the design wants it forgiving. Nothing stores "rest days" |
| Weekly goal ("3 of 4 sessions") | **N** | no goal field. `AIRoutineRequest.days` is transient | Add e.g. `AppPreferences.weeklySessionGoal: Int?` |
| Calendar intensity heatmap (per-day volume, sets or minutes) | **D** | aggregate per start day. The calendar currently has only a boolean | Volume is weighted-only, so sets or minutes are safer for intensity |
| Weekly **sets per muscle family** (or per the 14 groups) | **D\*** | completed non-warmup sets → `entry.exercise?.muscleGroup` (live) → `MuscleFamily` | muscleGroup is **not snapshotted**. It is nil for many user exercises. Core/Neck/Full Body map to no family. Count every load type |
| Weekly **volume** per muscle family | **D\*** | `RecordsMath.totalVolumeKg` per group | Weighted only: pull-ups, dips and assisted sets show 0. Label it "weighted volume" or prefer sets |
| Days since each muscle was last trained / recovery map | **D\*** | max `completedAt` per muscle group | Same live-muscleGroup caveat. The app cannot assess "recovered"; the honest label is "last trained N days ago" |
| Body heat-map with secondary muscles | **N** | only one primary group exists | New per-exercise secondary-muscle data |
| Time-of-day / weekday habit chart | **D** | `startedAt` hour or weekday | none |
| Average workout duration and trend | **D** | `Workout.duration` | Stray auto-finished workouts can be long |
| Time between sets ("actual rest") | **D\*** | gaps between consecutive `completedAt` in a workout | Only an approximation. Rest start and end are not stored for history (cleared). Supersets alternate. Label it "time between sets" |

### Records and progress
| Idea | Status | Source / how | Constraints |
|---|---|---|---|
| **New-PR badge on a set / "N PRs" per workout** | **D\*** | for each completed set, compare with eligible sets that have an earlier `completedAt` in the **same `RecordGroupKey`** (machine or free-weight tag, plus preset), using `RecordsMath.outranks` / rep-count table / `bestE1RM` | Warmups excluded; assisted lower-is-better; a tie is **not** a PR (earliest wins); rep tables only 1–12; 1RM weighted only; bodyweight = most reps. Pick the scope and state it (machine PR vs exercise PR). **Derive when reading, never store**: D47 edits would make stored flags stale |
| Live "PR!" moment during the workout | **D\*** | `PerformanceHistory.recordSummary(.thisEquipment)` covers only finished history, so compare it with the set just completed plus earlier sets in this workout | Same rules. The first-ever set of an exercise is trivially a record; suppress it or phrase it as "First time" |
| Lifetime bests list (top 1RM per exercise, heaviest set) | **D** | `RecordsMath.grouped` over everything | Show the as-entered value and unit, and convert derived kg with `WeightMath.displayLabel(kilograms:)` (plain, D52) |
| Strength trend across exercises (1RM sparkline per exercise) | **D** | `ProgressSeriesMath.series` per default variation | Never draw a line for fewer than 2 days. Invert "better" for assisted |
| PR count per month / "records this month" | **D** | as for new-PR detection | as above |
| Rep-range / set-type distribution | **D** | `SetRecord.reps`, `type` | none |
| Strength relative to bodyweight | **N** | no bodyweight stored (AI height and weight are transient) | New bodyweight log |
| RPE / RIR / effort | **N** | not stored | New `SetRecord` field |
| Next-load suggestion / progressive overload hint | **N (decision)** | could be derived from history, but no decision allows it, and the AI prompt explicitly forbids load predictions (D58) | Reopen DECISIONS first. A "Last time: 60 kg × 10" reference **already exists** (`PreviousSetValue.displayLabel`) |
| Template target completion ("8/12 sets done", reps vs target) | **D** | `entry.plannedRepsBySet` and draft rows vs completed | Targets are prescriptions, not performance (D57) |

### Lifetime and fun totals
| Idea | Status | Source | Constraints |
|---|---|---|---|
| Total workouts, sets, reps, hours | **D** | finished workouts | none |
| Total weight lifted ("You've moved 184,300 kg") | **D\*** | `RecordsMath.totalVolumeKg` over all | Weighted only. Plain number in the display unit (D52) |
| Total cardio distance / time / longest run per activity | **D\*** | `recordedCardio`, `distanceMeters`, `activeDuration` | Manual distance overrides the automatic value. Distance can be nil |
| Total calories | **D\*** | sum of optional `activeEnergyKilocalories` | Only workouts with a sensor count. Show "from N workouts", **never a 0-filled total**. Total (active + basal) only where both exist |
| Milestones / badges (100th workout, 10 t club) | **D** (thresholds) / **N** (to remember a badge was already celebrated) | counts | A per-viewer "seen" flag needs storage, or accept re-derivation |

### Equipment, gyms and templates
| Idea | Status | Source | Constraints |
|---|---|---|---|
| Per-machine history card (times used, last used, best set, 1RM) | **D** | entries by `snapshotMachineID`, `RecordGroupKey.machine` | Use snapshot labels for past rows. Archived machines still have history |
| "Same model at other gyms" comparison | **D** (already the layer-2 data) | `PerformanceHistory` `.sameModelElsewhere` | Only when the machine has a model |
| Per-gym stats (visits, last visit, favourite machines) | **D** | `Workout.gym`/`snapshotGymName`, entries by `snapshotGymID` | Archived gyms keep history. Use the snapshot name for past rows |
| Template usage (times run, last run, average duration) | **D** | `Workout.sourceTemplateID` | A deleted template leaves `sourceTemplateName` |
| AI week as a plan ("Day 2 of 3 — next up") | **N** | no week/group ID and no day order. Templates are independent | Needs a routine ID + day index (or weekday) on `WorkoutTemplate` |
| Template colour / emoji / custom order / folders | **N** | no fields | New optional fields |
| Machine / gym photos | **N** | not persisted (scanner crops are sent and discarded) | Storage and privacy decision (D53 limits which pixels leave the phone) |

### Heart rate and cardio
| Idea | Status | Source | Constraints |
|---|---|---|---|
| Zone minutes per week / trend | **D\*** | `zoneSeconds` per workout | Empty where no max HR. Zones are +5 points vs textbook. Plain numbers (D52) |
| Average/max HR trend per workout | **D\*** | optional fields | Skip nil, never 0 |
| HR recovery after a set (bpm drop within 60 s) | **D\*** (coarse) | 15 s `heartRateSeries` + set `completedAt` | Coarse resolution. Gaps are holes. Label it as approximate |
| Resting HR, HRV, VO₂max, sleep | **N** | not read from HealthKit | New HealthKit reads and authorization |
| Pace trend per activity / best pace | **D\*** | `CardioMath.pace` per segment | Pace is nil without distance. Mixed sources |
| Route map thumbnail / route history | **D\*** | `CardioSegment.route` | Only outdoor segments with GPS. Draw each `portion` separately |
| Cycling speed display (km/h) | **D** | `CardioMath.pace(speed:)` exists and speed is recorded | No speed text formatter yet |

---

## 4. Sample and fixture content (use this for consistent mockups)

**Gyms**
- `"Gold's Gym Gangnam"`, city `"Seoul"`, default `kg`: every SwiftUI preview (Start, ActiveWorkout, Finished sheet, WorkoutDetail).
- `"Gangnam Fitness"` (Seoul, kg): GymsView preview, CoreLoop and Codex screenshot UI tests.
- `"Hotel Gym"` (no unit): GymsView preview.
- `"Iron Temple"`: RedesignScreenshotUITests. `"Routine Gym"` / `"Template Gym"`: AI UI tests.

**Machines and models**
- Machine `"Chest Press 2"` on model **`"Life Fitness Insignia Series Chest Press"`** (CoreLoop and Codex tests). `"Chest Press"` with the same model (Redesign tests).
- Preview snapshot: machine `"Chest Press #1"`, model `"Life Fitness Insignia Chest Press"`.
- Other search strings in tests: `"Insignia Series Row"`.

**Exercises** (seeded, catalog v5: 90 exercises, 1,877 models, 23 manufacturers)
- Hero exercise everywhere: **`"Seated Chest Press"`** (weighted, machine, Chest).
- User-created: `"Landmine Press"` (weighted, barbell) in the ExercisesView preview.
- By group: **Chest** Seated Chest Press, Bench Press, Incline Chest Press, Chest Fly (Pec Deck), Cable Crossover, Dip (BW+added), Assisted Dip (assisted), Dumbbell Bench Press, Dumbbell Fly… · **Back** Lat Pulldown, Seated Row, Pull-Up (BW+added), Assisted Pull-Up, T-Bar Row, Chest-Supported Row, Bent-Over Row, Deadlift, Dumbbell Row… · **Shoulders** Machine Shoulder Press, Lateral Raise, Rear Delt Fly, Overhead Press, Dumbbell Shoulder Press… · **Biceps** Dumbbell Curl, Machine Biceps Curl, Preacher Curl · **Triceps** Triceps Pushdown, Triceps Extension, Overhead Triceps Extension, Seated Dip · **Quads** Leg Press, Squat, Leg Extension, Hack Squat, Pendulum Squat, Belt Squat, Bulgarian Split Squat… · **Hamstrings** Lying/Seated/Standing Leg Curl, Nordic Hamstring Curl, Glute-Ham Raise… · **Glutes** Hip Thrust, Glute Kickback, Glute Press… · **Calves** Calf Raise, Seated Calf Raise, Tibialis Raise… · **Hips** Leg Abduction, Leg Adduction, Multi-Hip · **Core** Abdominal Crunch, Torso Rotation, Hanging Knee Raise, Bench Crunch · **Forearms** Wrist Curl, Grip Trainer · **Neck** Neck Machine · **Full Body** Jammer Press, Sled Push.
- Group counts: Chest 16, Back 16, Quads 14, Shoulders 8, Hamstrings 7, Glutes 5, Calves 5, Triceps 4, Core 4, Biceps 3, Hips 3, Forearms 2, Full Body 2, Neck 1.
- Manufacturers (by model count): Panatta 246, Gym80 165, Watson 146, Matrix 137, Hoist 107, Nautilus 105, Hammer Strength 100, Precor 95, Life Fitness 92, Technogym 84, BH Fitness 83, Arsenal Strength 74, Atlantis 68, Legend 68, PRIME 65, Rogue 65, Body-Solid 55, Cybex 51, Impulse 29, Eleiko 20, Sorinex 13, Star Trac 8, Titan 1. Types: selectorized 885, plate-loaded 570, rack/Smith 215, cable 163, bodyweight 40, uncategorized 4.

**Presets**: fixture presets `"Narrow grip"`, `"Wide grip"`. Suggestions (`ExercisePresets.swift:16`): Wide grip, Narrow grip, Neutral grip, Reverse grip, Single arm, Single leg, Double leg, High pulley, Low pulley, Feet high, Feet low.

**Set values used in tests and previews**
- Standard logged set: **60 kg × 10** (`logSet(weight: "60", reps: "10")`), plus 70×8, 80×12, 45×6, 65 (history edit), 80×8.
- WorkoutDetail preview: warmup **40 kg × 12** (W), working **60 kg × 10**.
- Barbell tests: 45 (lb bar) with 5 reps, and 10 per side.

**Workout / template names**: typed workout names `"Full Session"`, `"Core Session"`, `"Second"`, and `" From History"` appended. Template fixture **`"Whole Body"`** (`TemplateFixture.swift:19`): Bench Press + Lat Pulldown (**superset A/B**), Machine Shoulder Press, Dumbbell Curl, Leg Press (reps **12, 10, 8, 6**), Abdominal Crunch; the others use **10, 10, 10**. It covers all 5 muscle families plus Core. The "Full Session" template in the UI test has Abdominal Crunch, Assisted Dip, Assisted Pull-Up, Back Extension and Belt Squat. AI fixture sessions are named **`"Day 1 — Fitness"`, `"Day 2 — Fitness"`…**, with 3 × 10 at 60 s rest and one 15-minute cardio block. AI form defaults: Beginner, 3 days/week, 45 min/session (15–120).

**Progress chart history** (`ChartFixture.swift:63`, all **lb**, "Seated Chest Press", days ago → weight × reps)
- Plain: 28→95×8, 25→100×8, 21→105×8, 18→105×6, 14→110×8, 11→110×10, 7→115×8, 4→112.5×8 (the dip), 1→120×8.
- Narrow grip: 26→85×10, 19→90×10, 12→95×10. Wide grip: 23→75×12, 16→80×12.
- Dumbbell tag: 24→40×10, 10→45×10. Barbell warmup-only: 2 days ago, 45×5.

**Heart-rate history workout** (`HeartRateHistoryFixture.swift`)
- Two days ago at **18:29**, **60 min**, Seated Chest Press **60 kg × 10, 8, 8**.
- **282 active kcal**, **85 basal** (total 367). Assumed max **185 bpm**.
- Series ranges **~102–150 bpm**, efforts ~138–151 and rests ~106–115. **Sensor gap 32:00–33:15.**
- Zone times: Zone 1 **32:30**, Zone 2 **15:30**, Zone 3 **10:45**.

**Live HR script** (`HeartRateMonitor.swift:335`, 1 Hz): 92, 104, 118, 131, 142, 148, 151, 146, 138, 129, 121, 114, 108, 103, 99, 112, 127, 139, 147, 153, 149, 141, 132, 123, 115, 109, 104, 100. HeartRateBar preview max is **184 bpm** (estimated). A UI test types a measured max of **180**.

**Cardio fixtures**
- Indoor Run, 5 min, **1,000 m** via phone motion (`CardioIndoorFixture.swift`), which gives a pace of 5:00 /km.
- Outdoor Run, 5 min, 31 GPS points 10 s apart starting at **40.7725, −73.9744** (Central Park, NYC), accuracy 5 m (`CardioRouteFixture.swift`).
- UI tests search "Indoor Run" and "Indoor Cycle", and enter a manual distance of "5".

**Defaults worth showing**: rest 2:00 working / 1:00 warmup. HR rest ends below 110 bpm with a 4:00 cap. Template rest stepper 0–600 s in 15 s steps. Bars 20/15/10 kg or 45/35/15 lb.

---

## 5. States a redesign must cover (from Domain enums and copy)
- Set row: draft / prefilled (inherited) / completed; set types W/F/D; bar mode vs total mode; the check-mark disabled until loggable; the unit toggle disabled in bar mode.
- Entry: draft (equipment editable) vs frozen (changing it splits the entry); superset member A/B/C; dumbbell-counterpart offer ("Log as Dumbbell Bench Press instead").
- Finish: saved vs `discardedEmpty`; template drift prompt with 4 choices; the "Save as template" option only when `canSaveAsTemplate`.
- HR feed: idle, needsAuthorization, denied, waitingForSensor, live(source), unavailable, and stale (>15 s). No zones when there is no max HR.
- Heart-rate rest: resting, recovered, cap, degraded.
- Progress chart: empty, single point (no line), series; variation picker; assisted axis inverted.
- Performance sheet: per-layer empty messages (see §2).
- Calendar cells: six emphasis states.
- History row: edited mark (`historyEditedAt`), reclassified provenance (`reclassifiedFromExerciseName`), Mixed unit badge.
- Cardio: running / paused / ended; no distance source; manual distance; GPS permission and accuracy messages; a planned target that is unstarted / linked / retryable.
- Errors in Domain copy: WorkoutTemplateError, CardioSessionError, TerraError and PlateTranscriptionError messages (see the source files).
