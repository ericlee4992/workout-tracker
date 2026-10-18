# 17 — Cardio-only workouts: pausing pauses the workout's time; no "paused for" timer

Type: bug / change
Status: in progress — decided, not built (2026-10-18)
Blocked by: —
Implementer: Claude; Reviewer: Codex.
Branch: `ericlee4992/beta-17-cardio-pause` off `main` `ef11a8e` (build 7's code + notes).
Ships in: **build 8** = build 7 (tickets 16 + 14, uploaded 2026-10-17, never given to testers) + this fix.

## Report (the user, 2026-10-18)

"During workout, when doing cardio, when i pause cardio, the cardio timer stops, but overall workout timer keeps going.
But lets say someone's only doing cardio; when they pause, the overall workout should also pause, right? … Also, i dont
think the pause timer is necessary (like currently it shows how long it's been paused for)."

## Decisions (the user, 2026-10-18)

- **Cardio-only workouts (no exercise logged): one clock — the workout's time IS the cardio's active time** (pauses
  excluded). The separate workout clock is hidden while the workout is cardio-only on the cardio screen (the ring shows
  the same number) and on the Live Activity; History rows, the week card, the month total, template stats and the
  finish summary use the active time. ("Cardio-only pauses (Recommended)".)
- **Workouts with lifting: unchanged** — the workout clock is the whole session (a cardio pause is like rest). Adding an
  exercise to a cardio-only workout brings the workout clock back, showing the whole session.
- **The "Paused M:SS" counter goes**: the pill says "Paused".
- Build 7 is skipped for testers; **build 8** carries 16 + 14 + 17 (What's New is keyed "build 7 or later", so 6 → 8
  still shows it once). Needs a new What to Test note (add a line about the fix) for the user's approval.
- Reopens the cardio spec's "the workout header is whole-workout elapsed time" (`work-record/cardio/spec.md:19-21`)
  for cardio-only workouts → record as **D64**.

## Code map (from an Explore pass, 2026-10-18; verify line numbers before editing)

- Workout clock: `LiveHeaderLine` (`Features/ActiveWorkout/LiveWorkoutPieces.swift:13-83`, `elapsed = now − startedAt`
  in a TimelineView), built at `ActiveWorkoutView.swift:454-461` (`showsSets: !cardioFocus`); Resume capsule
  `WorkoutResumeCapsule` (`Features/Start/WorkoutHomePieces.swift:21-40`, used `StartWorkoutView.swift:165-170`) and
  `TemplateStartCapsule` (`Features/Start/TemplatePieces.swift:21-22`, `TemplateDetailView.swift:291-293`) — both
  `now − startedAt`; Live Activity header `ActivityClock(start: attributes.startedAt)`
  (`WorkoutTrackerWidget/Shared/WorkoutActivityViews.swift:618-630`; state in `WorkoutActivityContent.swift:108-135`,
  attributes `WorkoutActivityAttributes.swift:142`).
- Cardio clock: `CardioSegment.activeDuration(at:)` (`Domain/Cardio.swift:205-207`); live ring `CardioLive.swift:96-121`.
- Paused-for: `CardioReadout.pausedSeconds` (`Domain/CardioReadout.swift:74-82`) → `CardioStatusPill`
  (`CardioLive.swift:342-369`, id `cardioStatus`, label "Paused, for …"); unit test
  `CardioReadoutTests.pauseDurationCountsFromThePause` (`:60-74`); UI tests check only the "Paused" prefix
  (`CardioUITests.swift:60-64`, `FloodlightCardioUITests.swift:115-126`).
- Durations: `Workout.duration = finishedAt − startedAt` (`Domain/HistoryRendering.swift:136-139`) feeds History rows,
  `WeekSummary.swift:91`, `HistoryOverview.swift:94`, `TemplateStats.swift:25`; finish tile `summaryTime` via
  `WorkoutSummary.duration` (`FinishPieces.swift:110-111`, `WorkoutFinishedSheet.swift:218-232`) — **not** cardio-aware.
  `HeartRateSummarySection` also uses `summary.duration` for the heart-rate axis: that must stay WALL time.
  Workout detail already shows active time for cardio-only (`WorkoutDetailView.swift:225-243`). "Cardio-only" today:
  facts `hasLifting = completed sets > 0`, `hasCardio = !recordedCardio.isEmpty` (`HistoryOverview.swift:86-97`).
- HealthKit: pausing cardio already pauses the HKWorkoutSession (`HealthKitHeartRateProvider.swift:124-133`); no change.
- No stored-format change planned (derived display only) → no Gate S.

## Plan

1. Domain (`Cardio.swift` extension on `Workout`): `isCardioOnly` (no live exercise entries, some cardio — live uses
   `orderedCardio`, finished uses `recordedCardio`; align with the facts' rule), `cardioActiveSeconds(at:)`,
   `trainingSeconds(at:)` (cardio-only → active seconds; else wall). `Workout.duration` → cardio-aware (finished).
   Unit tests: cardio-only with a pause, mixed unchanged, empty workout, adding an exercise.
2. Live: `LiveHeaderLine` takes the elapsed rule and a `showsClock` (hidden on the cardio screen when cardio-only);
   Resume/template capsules show `trainingSeconds`; Live Activity: a ContentState flag hides the header clock for
   cardio-only (widget shares the struct — keep Codable-compatible).
3. Finish sheet time tile: cardio-only → active time (heart-rate axis stays wall).
4. Pill: "Paused" only (label "Paused"); drop `pausedSeconds` and its unit test.
5. Captures (Floodlight cardio live paused/recording, finish, Live Activity gallery), targeted cardio UI tests, unit,
   Codex review; README/SPEC/D64; build 8 with the user's go-ahead.

## Comments
