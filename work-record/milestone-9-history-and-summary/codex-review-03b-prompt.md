Re-review (T6, round 2) of milestone 9, ticket 03, branch
milestone-9-history-and-summary. Round-1 review:
work-record/milestone-9-history-and-summary/codex-review-03.md; response appended
to issues/03-history-calendar.md. Boundary for the fixes: 9f693fd..18d707b.

Verify each round-1 finding is closed, not merely addressed:
1. Day.emphasis: is the combination total over the three flags, and does
   the view actually render markedToday with BOTH the today fill and the
   check? Is the accessibility label right for it?
2. destinationAfterCalendar: is `otherNavigationPending` computed correctly
   in HistoryView (target != nil || !path.isEmpty)? Can path be non-empty
   for a benign reason (the user opened a detail, came back via the sheet?)
   such that a legitimate pick is now dropped? Trace the actual state
   sequence: tap in sheet -> showCalendar = false -> onDismiss.
3. The removed cap: can the month loop fail to terminate for ANY input, and
   is the 1900 test meaningful?
4. Anything the fixes introduced; anything now uncalled.
Report by severity with file:line. Write to
work-record/milestone-9-history-and-summary/codex-review-03b.md
