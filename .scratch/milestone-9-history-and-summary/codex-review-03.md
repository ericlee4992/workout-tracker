# Codex cross-review 03 — History calendar

Review boundary: `efbacb5..9f693fd` (one commit, `9f693fd`). Verdict: **do not merge yet**. The core calendar arithmetic is sound and the ordinary UI flows pass, but today loses its distinct highlight when marked, and deferred navigation is not protected against stale or competing destinations.

## Standards

### Low — The presentation source comment states the superseded day rule

`WorkoutTracker/Features/History/HistoryCalendarSheet.swift:3-4` says the calendar marks “every day a workout finished.” The authoritative ticket deliberately changed this to the day the workout **started** (`.scratch/milestone-9-history-and-summary/issues/03-history-calendar.md:21`, `.scratch/milestone-9-history-and-summary/issues/03-history-calendar.md:44`). Runtime code follows the start-day rule, but the source comment is false and violates the repository's source-of-truth expectation (`CLAUDE.md:3-8`). Say “every day a finished workout started.”

### Low — Possible Speculative Generality: two new calendar members have no caller

`WorkoutCalendar.Day` declares `Identifiable` and an `id` (`WorkoutTracker/Domain/WorkoutCalendar.swift:13`), but the view iterates enumerated cells by offset and no test reads the id. `WorkoutCalendar.Month.rows` is likewise never read (`WorkoutTracker/Domain/WorkoutCalendar.swift:39`). These declarations do not serve the shipped view or its tests. Remove them until a caller exists, or make the view use the intended identities instead of maintaining parallel offset identity.

### Low — Possible Speculative Generality: the arbitrary 1,200-month escape hatch is both unexplained and harmful

The month loop already advances through `Calendar.date(byAdding:)` and breaks if advancement fails, yet it also stops at 1,200 iterations (`WorkoutTracker/Domain/WorkoutCalendar.swift:61`). The comment says this protects against a pathological future `finishedAt`, but the API receives `startedAt`, and future marks are clamped to today before the loop (`WorkoutTracker/Domain/WorkoutCalendar.swift:57`). The guard therefore does not address its stated case; its only observable effect is truncating sufficiently old input and omitting recent months. Replace it with an explicit input policy or generate backward from today so any cap preserves the current end of the calendar.

## Spec

### Medium — A marked today is not highlighted as today

The ticket separately requires workout days to be marked and today to be highlighted (`.scratch/milestone-9-history-and-summary/issues/03-history-calendar.md:9-12`). `dayCell` branches first on `isMarked`; the marked branch renders the same secondary-fill/check treatment for every marked date and never consults `isToday` (`WorkoutTracker/Features/History/HistoryCalendarSheet.swift:89`). The today fill exists only in the unmarked branch (`WorkoutTracker/Features/History/HistoryCalendarSheet.swift:108`). After the user finishes a workout today—the most natural state—the cell is marked but has no distinct today treatment. Combine the two state axes and add a marked-today rendering test; the existing `todayAndFutureAreFlagged` test uses an empty, unmarked calendar (`WorkoutTrackerTests/WorkoutCalendarTests.swift:81`).

### Medium — Sheet dismissal can push a deleted workout or overwrite another requested destination

The sheet stores a model in `calendarPick`, then its `onDismiss` unconditionally assigns `path = [pick]` (`WorkoutTracker/Features/History/HistoryView.swift:91`). It does not recheck `isDeleted` or `finishedAt`, although `openTarget` correctly applies both guards (`WorkoutTracker/Features/History/HistoryView.swift:134`). If the selected workout disappears while dismissal is pending, History still pushes the stale model. Separately, if the C2 `target` binding arrives while the sheet is presented, `openTarget` can set the path first and the later calendar `onDismiss` silently overwrites it; neither route cancels or arbitrates the other. Validate and clear the pick on dismissal, and give one pending-navigation route precedence instead of allowing last callback wins.

### Low — The 1,200-month cap can remove today from the calendar

The resolution promises months from the first marked month through today, with the newest at the bottom (`.scratch/milestone-9-history-and-summary/issues/03-history-calendar.md:33`). Forward construction stops after 1,200 months regardless of whether it has reached today (`WorkoutTracker/Domain/WorkoutCalendar.swift:65`). An old or corrupt timestamp more than 100 years back therefore produces a calendar ending decades before today, and `scrollTo(months.last)` opens there. The ticket's claim is false for the very pathological data the guard purports to handle. If a bound is retained, clamp the oldest month or build backward so today is never discarded, and test the bound.

### Low — The shipped source still describes finish-day marking

The amended requirement and implementation consistently use `startedAt`, but the presentation header says “a mark on every day a workout finished” (`WorkoutTracker/Features/History/HistoryCalendarSheet.swift:3`). That is not a harmless tense choice: finish-day versus start-day was the ticket's explicit cross-midnight correction (`.scratch/milestone-9-history-and-summary/issues/03-history-calendar.md:44`). Correct the comment so future work does not restore the rejected rule.

## Confirmed behavior and verification

- The first-weekday offset formula works for all values 1–7, including zero leading blanks when day 1 is the first weekday. `Calendar.range` yields 29 days for February 2024. Day-by-day construction preserves every midnight across both Los Angeles and Sydney DST changes. Weekday-symbol rotation operates on strings and does not assume one-character symbols.
- Mark creation and workout selection use the same injected calendar and `startOfDay`, so the 25-hour day compares identically. In production, the grid, identifier formatter, list grouping, row date, and detail title all use the device's current timezone. No History date surface was found using `finishedAt` as its displayed/grouped day.
- A multi-year calendar is modest work and the sheet uses lazy month presentation; rebuilding from the query is not itself a material defect. The 1,200-month correctness failure above is the actual cap problem.
- The `calendarDay.<key>` selector scheme is robust for the empty-store test: marked cells are buttons while unmarked cells are non-button views with the same identifier, so querying the button element type distinguishes marks. All introduced runtime declarations other than `Day.id` and `Month.rows` have callers.
- `git diff --check efbacb5..9f693fd` passed. `WorkoutCalendarTests` passed 8/8 and `HistoryCalendarUITests` passed 2/2. Additional Foundation probes covered first weekdays 1–7, leap February, and DST month iteration in negative- and positive-offset zones.

Standards — 3 findings (worst: low); Spec — 4 findings (worst: medium).
