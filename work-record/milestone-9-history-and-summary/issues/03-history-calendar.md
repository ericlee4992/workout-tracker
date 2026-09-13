# 03 — History calendar

Status: resolved — Codex clear after 3 rounds (codex-review-03..03c)
Blocked by: 02
Covers user ask **5**.

## What to build

A **Calendar** toolbar button on the History tab opening a sheet: vertically scrolling month
grids, most recent at the bottom and scrolled into view, weekday order and first weekday from the
user's locale. Days on which at least one FINISHED workout started are marked; today is highlighted; future
days are dimmed. Tapping a marked day dismisses the sheet and **pushes that session's detail**; if
the day has more than one session, push the most recent and say so in the ticket's notes — do not
build a day-list screen for this milestone.

Month/day maths belongs in `Domain/` (a `WorkoutCalendar` value type from `[Date]`), unit-tested
across month boundaries, DST changes and a Monday-first locale.

## Acceptance criteria

- Pure calendar model with tests: grid rows per month, marked-day set derived from `startedAt`
  days of FINISHED workouts (~~`finishedAt`~~ — changed during the build: the list, its month
  groups and the detail title all use the start day, and a 23:30 session marked on the next day
  would open into a screen filed under the previous one), locale first-weekday respected.
- Sheet renders from an empty store (no crash, no marks) and from `-uiTestChartHistory` (marks on
  the fixture's days).
- UI test: open the calendar, tap a marked day, assert the pushed detail is that session.
- Screenshot attached.


## Resolution (2026-09-03)

- `Domain/WorkoutCalendar.swift` — pure: `[startedAt]` + today + `Calendar` → months (oldest
  first, first marked month through today's), each `rows × 7` cells with leading/trailing nils,
  `Day{date, dayOfMonth, isMarked, isToday, isFuture}`, and `weekdaySymbols` rotated to the
  locale's `firstWeekday`. Days are built with `date(byAdding: .day)`, never seconds arithmetic
  (DST). `workoutToOpen(on:among:)` picks the latest-started finished workout on that day.
- `Features/History/HistoryCalendarSheet.swift` — presentation only: pinned weekday header,
  `LazyVGrid` months, marked days are buttons (`calendarDay.yyyy-MM-dd`) with a green check, today
  filled, future dimmed, scrolled to the newest month on appear.
- `HistoryView` — a Calendar toolbar button (`historyCalendar`); on pick the sheet dismisses and
  `onDismiss` sets `path = [workout]`. The push is deliberately in `onDismiss`: pushing while the
  sheet is still up lands under it.
- **Day rule changed from the ticket text: START day, not finish day.** Found by the UI test at
  23:30: the fixture's "yesterday" session finished after midnight, so the calendar marked a day
  the list files under a different date and opened a session titled with the previous day. History
  groups, rows and the detail title all use `startedAt`; the calendar now agrees with them.
  Acceptance text above amended and struck.
- Two sessions on one day: the newest opens (ticket's call); no day-list built.

**Tests.** `WorkoutCalendarTests` (8): whole weeks / day-1 under its weekday (Sunday-first),
Monday-first shift + heading order, month span first-mark→today, empty store = this month, start-day
marking across midnight, today/future flags, the LA DST month (30 midnights, mark on the right
day), and which session opens (latest-started, running excluded, other days nil).
`HistoryCalendarUITests` (2): tap yesterday → that session's detail (Name row + date title); empty
store → calendar opens, today shown, no tappable days. **602 unit green; UI: calendar (2), history
editing (2), chart (4), name (2) green.** Screenshots `history-calendar`, `history-calendar-opened`.


## Codex review 03 — response (2026-09-04)

`codex-review-03.md`: arithmetic confirmed (weekdays 1–7, leap February, DST both directions); 2
medium, 5 low. All acted on.

- **A marked today lost its highlight (medium).** True, and it is the commonest state. `Day.emphasis`
  combines the axes in the Domain (`markedToday` is its own case, tested); the view switches on it,
  so a marked today keeps the filled circle and gains the check.
- **Dismissal pushed an unvalidated pick and could overwrite the C2 target (medium).**
  `WorkoutCalendar.destinationAfterCalendar(pick:otherNavigationPending:)` re-checks deleted /
  finished at dismissal and yields to a pending target or non-empty path; ~~unit-tested for all four
  cases~~ (**false when written — the "deleted" case never deleted anything; corrected in round 2**),
  and `HistoryView.onDismiss` uses it.
- **The 1,200-month cap (low ×2).** Removed; the loop terminates by construction. A test with a
  1900 timestamp asserts the calendar still ends on today's month.
- **Stale "finished" comment; `Day.id` / `Month.rows` uncalled (low).** Fixed / removed.


## Codex review 03b — response (2026-09-04)

`codex-review-03b.md`: main fixes confirmed; 2 medium (one defect), 2 low. All acted on.

- **Marked future not dimmed (medium).** A finished workout with a future start (clock shift) is
  constructible and fell through to `.marked`. `Emphasis.markedFuture` is its own case — dimmed,
  still checked, still tappable because the workout exists — and a test builds all six reachable
  flag triples and asserts each maps to its own case.
- **"Deleted pick" test never deleted (medium/low).** True, and my closure claim was false. The
  test now inserts into an in-memory store, deletes, asserts `isDeleted`, and asserts the pick is
  dropped. The false claim above is struck, not rewritten.
- **Three separate mappings (low).** One `CellStyle` per emphasis owns fill, text, weight, check,
  tappability and the accessibility label.
