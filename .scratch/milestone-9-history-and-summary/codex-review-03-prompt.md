Cross-review (T6) of milestone 9, ticket 03, on branch
milestone-9-history-and-summary. Review boundary: efbacb5..9f693fd (one commit,
9f693fd). Read .scratch/milestone-9-history-and-summary/spec.md and
issues/03-history-calendar.md for intent (note the day-rule change recorded
in its resolution), and docs/DECISIONS.md D23.

## What was built

Domain/WorkoutCalendar.swift (pure month grid + workoutToOpen),
Features/History/HistoryCalendarSheet.swift (presentation), a toolbar button
and sheet in HistoryView that pushes the chosen workout from onDismiss.
WorkoutCalendarTests (8), HistoryCalendarUITests (2).

## Specific things to attack

1. **Calendar correctness.** firstWeekday handling for every value 1-7;
   months where day 1 is the first weekday (zero leading blanks); February
   in a leap year; a month spanning a DST change in a NEGATIVE-offset zone
   AND a positive one; calendar.timeZone vs the device's; a locale whose
   veryShortStandaloneWeekdaySymbols are not single letters. Does
   startOfDay on the 25-hour day yield the same Date the mark set used?
2. **The day rule.** The resolution switched from finish day to start day
   for consistency with the list. Is that consistent EVERYWHERE -- the
   list's month grouping (byMonth uses startedAt with a DateFormatter and
   the CURRENT calendar/timezone), the row date, the detail title? Is there
   any surface that uses finishedAt for the date?
3. **Navigation.** Pushing from onDismiss: can calendarPick be stale (the
   workout deleted between tap and dismiss)? Can the sheet be dismissed by
   swipe with a pick pending? Is the `path` state ever set while another
   push is in flight (the C2 "View in History" target)? Do openTarget and
   the calendar pick race?
4. **Performance.** The calendar is rebuilt from the `workouts` query on
   every body evaluation of HistoryView while the sheet is up; months from
   the first workout to today. For a multi-year history, is this a cost,
   and does the 1_200 guard mean anything?
5. **Accessibility identifiers.** Marked and unmarked days share the
   `calendarDay.<key>` identifier scheme but only marked ones are buttons;
   the empty-store test relies on that. Is it robust?
6. **The absence-of-a-caller class.** Anything declared here nothing
   reaches (Month.rows? Day.id?).

Report by severity with file:line, say plainly if a claim in the ticket or
commit message is wrong, do not soften. Write to
.scratch/milestone-9-history-and-summary/codex-review-03.md
