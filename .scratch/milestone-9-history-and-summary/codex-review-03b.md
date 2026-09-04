# Codex cross-review 03b — History calendar, round 2

Review boundary: `9f693fd..18d707b`. Verdict: **do not close yet**. The marked-today rendering, dismissal arbitration, uncapped month span, stale comment, and unused declarations are closed. A marked future date still loses the future treatment, however, and the claimed deleted-pick regression coverage was not added.

## Standards

### Medium — The combined emphasis is not semantically total over its input flags

`WorkoutCalendar.Day.emphasis` collapses `(isMarked: true, isToday: false, isFuture: true)` into ordinary `.marked` (`WorkoutTracker/Domain/WorkoutCalendar.swift:35-38`). That combination is constructible because every supplied `startedAt` becomes a mark (`WorkoutTracker/Domain/WorkoutCalendar.swift:68`), including a corrupt or clock-shifted future timestamp. The presentation consequently gives it marked fill and primary text rather than future dimming (`WorkoutTracker/Features/History/HistoryCalendarSheet.swift:91-100`). The new test covers marked-today, marked-past, plain-past, and unmarked-future, but not marked-future (`WorkoutTrackerTests/WorkoutCalendarTests.swift:110-118`). This leaves fallback-selection logic in `Domain/` without the unit coverage required by `CLAUDE.md:29`.

### Medium — The deleted-pick fallback remains untested despite the test name

`aDeletedOrRunningPickIsDroppedAndAPendingTargetWins` never deletes a workout. It exercises a valid finished pick, a running pick, a nil pick, and pending navigation (`WorkoutTrackerTests/WorkoutCalendarTests.swift:150-158`), but not the `pick.isDeleted` branch in `destinationAfterCalendar` (`WorkoutTracker/Domain/WorkoutCalendar.swift:144-149`). The response's statement that deleted/finished validation is “unit-tested for all four cases” is therefore false (`.scratch/milestone-9-history-and-summary/issues/03-history-calendar.md:68-71`), contrary to the repository's source-of-truth and unit-tested-domain conventions (`CLAUDE.md:3-8`, `CLAUDE.md:29`).

### Low — Possible Repeated Switches: cell presentation is still split across three mappings

`dayCell` maps the same `emphasis` through separate fill and text switches, then separately consults raw `day.isMarked` to choose interactivity and the check (`WorkoutTracker/Features/History/HistoryCalendarSheet.swift:89-107`). One presentation mapping should own fill, text, weight, check/interactivity, and accessibility semantics for each combined state. The split is already hiding the missing marked-future treatment above and makes another partial state fix easy to repeat.

## Spec

### Medium — Marked future days are not dimmed

The ticket requires finished-workout days to be marked and future days to be dimmed (`.scratch/milestone-9-history-and-summary/issues/03-history-calendar.md:9-12`), and this re-review explicitly asks whether the three flags are handled totally. A finished workout with a future `startedAt` produces a day for which `isMarked` and `isFuture` are both true, but `emphasis` maps that state to `.marked` (`WorkoutTracker/Domain/WorkoutCalendar.swift:35-38`). The view then renders primary text instead of the future color (`WorkoutTracker/Features/History/HistoryCalendarSheet.swift:91-100`). Add an explicit marked-future state/treatment and a test for that combination.

### Low — The deleted-workout dismissal regression is not proved

The production guard now rejects `pick.isDeleted` (`WorkoutTracker/Domain/WorkoutCalendar.swift:147-149`), but the regression test whose name says a deleted pick is dropped never transitions its fixture to the deleted state (`WorkoutTrackerTests/WorkoutCalendarTests.swift:150-158`). Thus the round-one runtime defect appears fixed in code, but the response's specific “unit-tested for all four cases” closure claim remains unverified (`.scratch/milestone-9-history-and-summary/issues/03-history-calendar.md:68-71`).

## Confirmed closures and verification

- `.markedToday` receives the today fill and today text color, while the separate marked branch adds the check; its button label is “Workout today” (`WorkoutTracker/Features/History/HistoryCalendarSheet.swift:89-121`).
- The actual calendar sequence starts at the History root: tapping a day stores `calendarPick`, sets `showCalendar = false`, and then `onDismiss` evaluates `target != nil || !path.isEmpty` before pushing (`WorkoutTracker/Features/History/HistoryView.swift:91-107`). The path cannot be benignly non-empty from opening a detail and then presenting this sheet because the Calendar toolbar is inside the root content, not a detail. For a competing C2 request, either `target` is still non-nil or `openTarget` has consumed it and populated `path`, so either callback order preserves the explicit destination.
- The cap removal is sound for supported Foundation calendars: the loop stops after reaching `lastMonth`, breaks if adding one month fails, and each successful month addition advances the cursor (`WorkoutTracker/Domain/WorkoutCalendar.swift:75-88`). Future marks are clamped out of the start-bound calculation. The 1900 test spans 1,521 months, so it would fail the former 1,200-month cap and meaningfully proves that today's month is retained (`WorkoutTrackerTests/WorkoutCalendarTests.swift:121-130`).
- The stale finish-day comment and unused `Day.id` / `Month.rows` declarations are gone. All newly introduced production helpers have callers; no unrelated scope expansion was found.
- `git diff --check 9f693fd..18d707b` passed. `WorkoutCalendarTests` passed 11/11. `HistoryCalendarUITests` passed 2/2 on retry; the first attempt ended while the UI-test runner was bootstrapping, before either test ran.

Standards — 3 findings (worst: medium); Spec — 2 findings (worst: medium).
