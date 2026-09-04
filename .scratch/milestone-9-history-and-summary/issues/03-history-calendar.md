# 03 — History calendar

Status: ready-for-agent
Blocked by: 02
Covers user ask **5**.

## What to build

A **Calendar** toolbar button on the History tab opening a sheet: vertically scrolling month
grids, most recent at the bottom and scrolled into view, weekday order and first weekday from the
user's locale. Days with at least one FINISHED workout are marked; today is highlighted; future
days are dimmed. Tapping a marked day dismisses the sheet and **pushes that session's detail**; if
the day has more than one session, push the most recent and say so in the ticket's notes — do not
build a day-list screen for this milestone.

Month/day maths belongs in `Domain/` (a `WorkoutCalendar` value type from `[Date]`), unit-tested
across month boundaries, DST changes and a Monday-first locale.

## Acceptance criteria

- Pure calendar model with tests: grid rows per month, marked-day set derived from `finishedAt`
  (not `startedAt`) days, locale first-weekday respected.
- Sheet renders from an empty store (no crash, no marks) and from `-uiTestChartHistory` (marks on
  the fixture's days).
- UI test: open the calendar, tap a marked day, assert the pushed detail is that session.
- Screenshot attached.
