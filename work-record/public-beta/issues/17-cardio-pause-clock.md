# 17 — Cardio-only workouts: pausing pauses the workout's time; no "paused for" timer

Type: bug / change
Status: **done** — merged (`main` `7c81e28`); build 8 in Developer and Friends (Testing), 2026-10-18
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

## Build notes (Claude, 2026-10-18)

- **Rule** (`Domain/Cardio.swift`): `Workout.isCardioOnly` — live: some cardio segment and no exercise entry (adding
  an exercise brings the whole-session clock back before any set); finished: recorded cardio and no completed set
  (finish deletes set-less entries and unrecorded segments, so this agrees with History's facts).
  `cardioActiveSeconds(at:)` sums every segment's active time; `trainingSeconds(at:)` = that for cardio-only, else
  wall time (capped at `finishedAt`). Time before the first segment and between segments does not count.
- `Workout.duration` = `trainingSeconds(at: finishedAt)` → History rows/stats line, week card, month total, template
  stats. `WorkoutSummary.cardioOnlyTime`/`workoutTime` → the finish and History time tile; `summary.duration` stays
  wall time for the heart-rate chart's axis.
- Live: `LiveHeaderLine(elapsedAt:showsClock:)` — the clock is hidden in cardio focus when the workout is cardio-only
  **with one segment** (the ring is then the same number; with two or more the ring is only the current segment, so
  the clock stays, showing the total active time); the clock got the identifier `workoutClock`. The Resume capsules
  (Workout tab, template detail) show `trainingSeconds`.
- Live Activity: `ContentState.workoutClock` (`WorkoutClock`: `.hidden` / `.stopped(seconds:)` /
  `.running(since:)`, optional so an older payload decodes) built by `WorkoutActivityContent.workoutClock`; `since` is
  fixed while recording (every segment's active time before the current stretch), so the 2-second tick pushes no new
  card. nil = the whole session from `startedAt` as before.
- Pill: "Paused" only (label "Paused"); `CardioReadout.pausedSeconds` removed; its unit test became
  `activeTimeExcludesThePause`.
- No stored-format change (derived display only; one optional Codable field on the Live Activity state) → no Gate S.
- Judgement call to tell the user: hiding the header clock only with a single segment (above).

## Verification

- Unit (WT-Floodlight, iOS 27): `CardioOnlyTimeTests` (new, 5), `CardioReadoutTests`, `CardioTests`,
  `WorkoutActivityContentTests`, `WorkoutSummaryTests`, `WeekSummaryTests` — **60 tests in 6 suites passed**,
  `TEST SUCCEEDED`, exit 0 (log `scratchpad/t17/unit1.log` of session d9b843b3).
- UI (WT-Floodlight, 3 parallel workers): `FloodlightCardioUITests` (now 9: + `testCardioOnlyPauseStopsTheWorkoutClock`;
  live asserts the pill reads exactly "Paused", no header clock for one-segment cardio-only, a lifting workout's clock
  keeps ticking through a cardio pause; finished asserts the cardio-only time tile "20:00" = 1,080 s run + 120 s
  cycle) and `CardioUITests` (9). Run 1 (`ui1`): 16/18 passed; the 2 failures were `kAXErrorServerNotFound` (the
  automation session took 60 s to start, then lost the app), reproduced once on the same simulator (`ui2`); after
  rebooting WT-Floodlight both passed (`ui3`: 2/2, `TEST SUCCEEDED`, exit 0). So 18/18 passed.
- Captures inspected (dark default): C02 (cardio-only recording: no header clock), C03 (lifting + paused cardio:
  "Paused" pill, whole-session clock), L-cardio-only-paused (Lifting view: clock frozen at the active time).
- Not run: full UI suite (not warranted: change is cardio/time display); Live Activity on a device.

## Build 8 What to Test note — approved by the user 2026-10-18 ("use the note as drafted")

"Build 8 adds a Progress tab. Tap + or Add Chart to pin any lift or cardio activity — each chart shows your latest
best and how far you've come. Long-press a chart to change what it shows, move it or remove it; tap it for the full
chart. A short What's New page introduces it once after updating (Settings → What's New shows it again). Also fixed:
in a workout that is only cardio, pausing the cardio now pauses the workout's time too, and the Paused label no
longer counts the pause. Otherwise as before: send anything odd from Settings → Send Feedback."

## Comments

**Checkpoint 2026-10-18:** implementation committed `fde78f0` and pushed; Codex review round 1 sent to the "Codex
review" terminal (`term_be05cca0-…`), prompt `codex-review-17-prompt.md`, report → `codex-review-17.md`.


**Codex round 1 — response (Claude, 2026-10-18).** [codex-review-17.md](../codex-review-17.md), not clear; all three
accepted and fixed:
1. *Cached card kept a stale workout clock through pause/resume.* The live screen's refresh moved into
   `WorkoutActivityContent.refreshed(_:for:heart:now:)` (heart, cardio and now `workoutClock`), called by
   `ActiveWorkoutView.activityState()`. Test `aCachedCardFollowsPauseAndResume` drives a cached base through pause
   and resume and checks unchanged ticks still compare equal.
2. *Multi-segment History detail lost the total.* `WorkoutDetailView` drops the time tile only when the hero is the
   workout's single recorded segment. `FloodlightCardioUITests.finished` now asserts History's `historyWorkoutTime`
   reads 20:00 for the run + cycle.
3. *Header stayed hidden after End Cardio.* One rule, `Workout.cardioClockIsWorkoutTime` (cardio-only, one segment,
   still open), now drives both the header and the Live Activity's `.hidden`. Test
   `endingTheOnlySegmentBringsTheWorkoutClockBack`; the UI test ends the segment and checks the clock is back, stopped.
Unit: 62/62 in 6 suites, exit 0 (`unit2.log`). UI: `testFinishedLightAccessibility` passed; the other two hit the
known `kAXErrorServerNotFound` on a fresh clone and are re-run serially on a rebooted WT-Floodlight (`ui5`).
`ui5` (serial, rebooted) failed the same way again; a manual launch with the same arguments rendered correctly (no
hang — the failure is XCTest's 60-second automation-session set-up, before the test touches the app, on the first
tests a runner executes). `ui6` with a short warm-up test first (`CardioUITests/testSavedDistanceEditor…`): **3/3
passed**, `TEST SUCCEEDED`, exit 0 — `testCardioOnlyPauseStopsTheWorkoutClock` (incl. the End Cardio check) and
`testFinishedDark` (incl. History's 20:00 total).

**Codex round 2 (2026-10-18): clear** — [codex-review-17b.md](../codex-review-17b.md), reviewed `fabde33`; its build
exit 0 and five unit suites 56/0/0. Next: the user's go-ahead to merge into `main`, approval of the build 8 What to
Test note above, then build 8 (number 8, archive from `release-build`, upload, Developer group first).

**Build 8 (2026-10-18, the user: "once codex clears, merge it and make build 8. Upload to developer group only
first").** Build number 8 (10 occurrences), simulator `xcodebuild build` **BUILD SUCCEEDED**; `main` fast-forwarded
`ef11a8e..7c81e28` and pushed (remote confirmed). No Gate S: no stored property changed since build 6/7 (ticket 17 adds
computed properties and an optional Live Activity field only). Archive from `release-build` detached at `7c81e28`:
**ARCHIVE SUCCEEDED**; app and widget build 8, version 0.1.0, production `WTServerURL`, `WTGoogleClientID` present,
team X68M8SR6NA (`scratchpad/tf/Stacked-0.1.0-8-7c81e28.xcarchive` of session d9b843b3). Upload: **"Upload
succeeded" 02:05 EDT**, EXPORT SUCCEEDED. Next: App Store Connect processing → **Developer group only**; Friends later
with the approved note.

**Build 8 delivered (2026-10-18).** Developer: the user clicked Add; the phone has **Stacked 0.1.0 (8)** (`devicectl`);
the user: What's New appears. Friends (the user: "let's upload it to Friends now"): Claude selected build 8, pasted the
approved What to Test note (checked in full), "Automatically notify testers" on; the user clicked Submit for Review;
Friends showed build 8 **Testing** at once. Friends then had 3 testers: 2 anonymous public-link (iPhone 15 iOS 26.6.1
and iPhone 17 Pro Max iOS 27.0.1, both on build 6) and the user. Not checked on a device: the Live Activity's
cardio-only clock.
