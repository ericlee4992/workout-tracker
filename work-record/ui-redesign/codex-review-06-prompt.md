Round 1 (T6) of UI-redesign ticket 06 — History on the Ink / Amber design system (which YOU
built; Claude built this ticket, so you review). Ticket: work-record/ui-redesign/issues/06-history.md;
the plan: work-record/ui-redesign/spec.md (ticket 06 and the constraints — copy policy, D23
snapshots, D44/D52, ids/strings the tests read). Boundary: 433d468..HEAD on branch
ui-redesign-06 (main = 433d468; two commits, the first is a one-line ticket-05 note).

Files: WorkoutTracker/Features/History/HistoryView.swift, HistoryCalendarSheet.swift,
WorkoutDetailView.swift, ExerciseProgressView.swift.
Screenshots: work-record/ui-redesign/screenshots/06/ (05-history, 05-calendar, 05-detail,
05-detail-heart-rate, 05-chart, 08-empty-history).

Scope:
1. HistoryView: the row is now a `Button` that appends to `path` instead of a `NavigationLink`
   (reason in the ticket). Does every way in still work — the calendar pick (`onDismiss` sets
   `path`), the receipt's "View in History" (`openTarget`), a tap, swipe-delete on a Button row?
   Any accessibility regression (the row used to be a link)?
2. HistoryCalendarSheet: `CellStyle` lost `showsCheck` and gained `ring`. Is every emphasis case
   still distinguishable (plain / future / today / marked / markedToday / markedFuture) for a
   sighted user AND for VoiceOver (labels unchanged)? Is the deviation — today's ring in
   `Theme.secondary`, not `Theme.hairline` — right? Colour-only marking: is amber-on-card enough
   contrast for the day number in `onAccent`?
3. WorkoutDetailView: `MuscleIcon(group: entry.exercise?.muscleGroup)` reads the LIVE exercise
   relationship. D23 says snapshots for display strings; the ticket calls the icon colour
   decoration. Do you accept that, or should the icon be neutral in History? The load-type Menu
   moved into the subtitle row as a `Chip` — same ids `historyEntryLoadType`,
   `removeHistoryExercise`, `historyEntryChart`; the reclassified mark; anything the
   HistoryEditing tests rely on positionally?
4. Heart-rate tiles: D44 — each only when its fact exists; D52 plain numbers; the tiles'
   accessibility text; the Section keeps `historyHeartRateSection` and now has NO header (the
   chart card under it says "Heart rate") — check HeartRateSummaryUITests still finds what it
   asserts.
5. ExerciseProgressView: the `AreaMark` under the same points — does it change what the chart
   CLAIMS (D9/D25 "no picture more confident than the data")? An area under an assisted series
   (lower is better)? The `chartOverlay` drag and the row insets are untouched (the tooltip
   test's normalized drag) — confirm. Axis styling: any label lost?
6. Copy policy: no new `Text("…")` beyond what existed? (`EmptyState` titles + the old
   descriptions kept; "Since first session" now in `stat`, accent when ≥ 0 — the old green.)
7. Anything else the four files break: `listRowBackground` on Sections inside a List with
   `.scrollContentBackground(.hidden)`; Dynamic Type at AccessibilityL for the day tile and the
   entry header (no capture at that size — say if one is needed).

Do NOT run xcodebuild or simctl (the simulator is in use). Review by inspection; verification is
in the ticket. Report by severity with file:line, or say "clear" in one paragraph. Do not modify
source files. Write to work-record/ui-redesign/codex-review-06.md
