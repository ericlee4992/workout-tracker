# Ticket 05 — independent Codex review

**Verdict: not clear.** One high, five medium and three low findings; no critical findings.

Reviewed 2026-09-27 in `/tmp/wt-floodlight/history`, branch
`ericlee4992/redesign-floodlight-history`, HEAD
`458797796dbb496eaea4671857c4e05a130283b3`, against
`ericlee4992/redesign-floodlight-finish` (`1c3fc99af019e8a0de85fa0ab117d57576b3db0b`).
Claude implemented; Codex reviewed. Findings below are from source and capture inspection,
not fresh simulator reproductions. No `xcodebuild` or `simctl` was run. Only this report was
written; the pre-existing untracked `opencode.json` was left alone.

## High

### 1. Cancelled Add Set can remain as a completed, empty set

**Spec / persistence:** `WorkoutTracker/Features/History/WorkoutDetailView.swift:121`,
`:483`, `:491–494`; `WorkoutTracker/Domain/HistoryEditing.swift:217–221`.

The new set is assigned `completedAt` and saved before its editor opens. The sheet uses
`$pendingNewSet` as its presentation item, but its `onDismiss` cleanup reads that same item.
SwiftUI clears the presentation binding on dismissal, so the cleanup guard can return without
calling `pruneAbandonedSet`. Choose **Add Set**, then Cancel or swipe down without saving:
the empty completed row survives, contributing to the row/month/calendar counts and detail
ring. Add Exercise shares this dismissal flaw, inherited from the old screen. Ticket 05
explicitly requires both abandoned additions to leave nothing.

Keep the cleanup identity independently of the presentation binding, or give the sheet an
explicit completion/cancellation path with interactive-dismiss cleanup. The domain test calls
`pruneAbandonedSet` directly and cannot catch this wiring defect. Test both dismissal methods
for Add Set and Add Exercise, including persisted counts after reopening History.

## Medium

### 2. Chart record markers ignore improvements in reps at the same load

**Spec / calculations:** `WorkoutTracker/Domain/ProgressSeries.swift:290–300`.

`recordDays` compares only `bestKg`. For one variation, Monday **100 kg × 5**, then Tuesday
**100 kg × 8**, Tuesday is a new best under `RecordsMath.outranks` and the receipt/detail
badge logic, but gets no chart burst or Sessions badge. The same error applies to assisted
sets at equal assistance with more reps. The domain brief requires the established best-set
ranking, including reps; the new tests vary loads and miss this case. Compare the complete
best-set rank, preserving first-time and tie rules, and test agreement with receipt marks.

### 3. A Sessions row can open a different workout from its displayed best

**Spec / navigation:** `WorkoutTracker/Features/History/ExerciseProgressView.swift:545–550`
and `:387–410`.

The series selects the day's best set, while the destination map independently selects that
day's **latest workout**. With **100 kg × 5 at 09:00** and **80 kg × 5 at 18:00** in the same
variation, the Sessions row displays 100 kg × 5 and opens the evening workout containing
80 kg × 5. Ticket 05 says tapping a session opens “that workout.” Preserve the contributing
workout identity with the displayed achievement, or list actual sessions separately. Cover
two workouts in one day with the earlier one supplying the best.

### 4. The metric hero invents zero for missing 1RM and discards valid decimals

**Spec / calculations:** `WorkoutTracker/Features/History/ExerciseProgressView.swift:265–269`
(selection at `:210`; accessible text at `:452–460`).

An earlier eligible day followed by a day containing only **15-rep sets** leaves the latest
day's `e1rmKg` nil. Selecting 1RM displays **0 kg**, although that day is omitted from the
plot and the accessible selection says “—”. Separately, the unconditional `.rounded()` makes
a valid **7.5 kg** volume display as **8 kg**, while the plotted value and accessible label
retain 7.5. The old callout preserved missing values and D25 precision; ticket 05 only grants
whole-number rounding to History list row volumes. Use the shared metric formatter for both
the visible and spoken value, preserve absence, and select from eligible metric points.

### 5. Overview new-best calculation is quadratic within a common scope

**Spec / performance:** `WorkoutTracker/Domain/SetBadges.swift:143–152`;
`WorkoutTracker/Features/History/HistoryView.swift:64–67`.

For every workout in a scope, the inner loop reconstructs inputs from every other workout,
then removes future sets. This contradicts ticket 05's “whole list is one pass” requirement.
With 1,000 workouts and five sets in one recurring scope, a rebuild constructs approximately
five million historical inputs for that scope alone. It runs synchronously when History
appears and after edits. Grouping by scope reduces unrelated work but does not fix the
quadratic growth. Build inputs once and process chronological history with running incumbents,
retaining the before-workout-start cutoff and first-workout semantics. This is an operation-count
finding; no device latency benchmark was run.

### 6. The adjustable chart does not announce its selected value

**Standards / accessibility:**
`WorkoutTracker/Features/History/ExerciseProgressView.swift:732–741`.

The chart ignores its accessibility children and exposes the fixed label “Progress, N days”
with an adjustable action, but no `accessibilityValue`. A VoiceOver user incrementing or
decrementing changes a separate hero element; the focused chart provides no updated date,
value or metric. Expose the selected point's date and metric value on the adjustable element,
including the as-entered best-set text, and verify adjustment while focus stays on the chart.
The requested accessible chart interaction is incomplete despite the action being wired.

## Low

### 7. Light calendar's lowest trained intensity misses the contrast gate

**Standards / visual:** `WorkoutTracker/Features/History/HistoryCalendarSheet.swift:275–293`.

A trained day with fewer than 12 sets uses `done` at 55% opacity with white `onDone` digits.
In Floodlight Light, ink `#0B0C0E` over the white panel composites to approximately `#79797A`:
white digits have **4.35:1** contrast, below REVIEW item 6's **4.5:1** minimum. This is visible
on the trained days in `captures/05/floodlight-05-calendar-light-axl.png` and affects default
size too. Adjust the lowest fill or its foreground and measure the composited pair, including
the cardio glyph if present.

### 8. Edit Set omits the promised NEW BEST mark

**Spec / design:** `WorkoutTracker/Features/History/EditLoggedSetSheet.swift:84–110`.

Ticket 05 scope item 4 specifies the set marker/date “and its NEW BEST mark”; the prototype's
`EditSetSheet.swift` renders it for unchanged saved values. The real editor never accepts or
derives a badge. Open the **Leg Extension 70 lb × 10** set: the detail marks it NEW BEST
(`floodlight-05-detail-dark-default-3.png`), but its editor has no mark
(`floodlight-05-editset-dark-default.png`). Supply the saved outcome and suppress it while
staged edits make it inapplicable, as the approved prototype does.

### 9. Edit-set captures do not satisfy the same-state AXL gate

**Standards / verification:** `WorkoutTrackerUITests/FloodlightHistoryUITests.swift:72–80`
and `:98–103`.

The test selects the first currently hittable set after scrolling, rather than a fixed set.
The saved dark default image edits **Leg Extension, Working, 70 lb × 10**; the AXL image edits
**Leg Press, Warmup, 27.5 lb × 12**. Both AXL edit images also stop at Unit, with no scrolled
capture of the footer and Delete Set. Empty History is captured only at default size.
REVIEW item 9 and the design skill require the same fixture/state and every named block at
AXL. Select a deterministic set, capture the editor's lower content, and add the empty-state
AXL pair. These are missing verification artifacts, not a claim that the unseen layout fails.

## Verification and remaining review scope

- Read the supplied decisions, tickets, design review/reference material, relevant old screens
  and prototype source. Compared approved H01/H03 in both appearances and representative real
  list, calendar, detail, editor, progress and empty captures, including AXL and scrolled pages.
  The month-card and detail-hero hierarchy, panel-row grouping and shared heart-rate plate
  follow the chosen composition in those captures.
- Inspected actual saved exits/logs and `xcresulttool` summaries under
  `/tmp/wt-floodlight/results/`: builds 2–4 exit 0; build 1 exit 65. `history-unit-1` reports
  28 passing domain tests. `history-ui-1` reports 64 domain plus 42 UI passes and four UI
  failures; `history-ui-2` has six passing tests and one failed test; `history-ui-3` has eight
  passes and five failures, including the subsequently fixed chart scroll cases. The HR
  finish→History case passed in run 3. `history-ui-4` is exit 0, **13/13**, zero skips.
  The final result still contains an invalid-frame runtime warning; no new cause is asserted.
  The ticket's “build-1..4: build exit 0” wording should acknowledge build 1's actual failure.
- The targeted scope is reasonable under DEVELOPMENT; a full UI rerun is not required simply
  for this ticket. Clearance needs focused coverage for the findings, plus Add Set save/cancel,
  Add Exercise abandonment, notes, and both last-set deletion paths. Existing capture tests
  largely inspect presentation, and the new domain prune test does not exercise dismissal.
  Retake affected captures after fixes. No fresh runtime, VoiceOver or Reduce Motion test was
  performed during this review.
- Source tracing found no additional defect in month/start-day aggregation, first-weekday
  grouping, keeping a cross-month week whole, weighted-only volume, unit-badge selection,
  display-only conversion, snapshot preservation, retype refusal, rename/notes marking,
  deletion confirmations, D51 provenance, C2/calendar push-after-dismiss, or shared tile order.
  Warmups counting in the row/month/calendar but not the detail's **working-set** ring is an
  explicit user-approved distinction. Row new-best counts use the receipt's outcome rules.
- Normal marked edits invalidate list facts and the edited detail's receipt/marks. The empty
  History start request is consumed/reset before entering the usual start flow; no concrete
  double-start was found. Progress still fetches all stored sets on selection renders, entries
  per variation label and preferences per plotted point. Those reads largely predate this
  change and remain a scaling concern; they are not evidence of a measured new slowdown.
- No additional unlisted product feature was found. Notes and empty History changes have
  explicit 2026-09-27 approval. The planned D47/D54 decision-log updates remain a release
  follow-up in the ticket. No merge or installation clearance is supplied by this report.
