Round 2 (T6) of UI-redesign ticket 03 (finish summary). Round-1 review:
work-record/ui-redesign/codex-review-03.md; the response is in
work-record/ui-redesign/issues/03-finish-summary.md under "Codex review 03 — response".
Boundary of the fixes: 48d225c..HEAD on branch ui-redesign-03 (one commit).

Scope: are the two findings closed exactly —
1. `Domain/ZoneBarLayout.widths` (new, pure) + `ZoneBarLayoutTests`: check the arithmetic for
   your own cases ([3599, 1] at 300; [3595, 1, 1, 1, 1, 1]; one zone; an unaffordable minimum),
   that the sum is always width − gaps, that no width can go negative or exceed the width, and
   that the sheet's `zoneCard` indexes `widths` safely (present.count == widths.count).
2. `HeartRateSummaryUITests.testFinishShowsTheChartAndHistoryShowsItAgain`: scrolls until the
   average caption under the chart is hittable, screenshots, scrolls back until View in History
   is hittable, taps it. Bounded? Brittle?
3. The AXL capture `screenshots/03/03-finish-summary-axl.png` (new test
   `RedesignScreenshotUITests.test03_finishSummaryLargeText`) — look at it: does the two-column
   tile grid hold at AccessibilityL without truncation (labels may wrap to two lines now)?
And whether the fixes introduced anything new.

Do NOT run xcodebuild or simctl. Verification is in the ticket (7 unit incl. the 6 new,
HeartRateSummaryUITests 3/3, both screenshot flows). If closed, say "clear" in one paragraph;
otherwise report by severity with file:line. Do not modify source files.
Write to work-record/ui-redesign/codex-review-03b.md
