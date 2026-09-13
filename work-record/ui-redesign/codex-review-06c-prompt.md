Round 3 (T6) of UI-redesign ticket 06 (History). Round-2 review:
work-record/ui-redesign/codex-review-06b.md; the response is in
work-record/ui-redesign/issues/06-history.md under "Codex review 06b — response".
Boundary of the fix: ee5b17d..HEAD on branch ui-redesign-06 (one commit, HistoryCalendarSheet only).

Scope: is the P3 closed — the ring is a `strokeBorder` INSIDE the 40 pt cell (no negative
padding), and the filled disc is inset 4 pt when a ring is present (`.padding(style.ring == nil
? 0 : 4)`), keeping a 2 pt card gap between amber and ring. Check `screenshots/06/05-calendar.png`
(today = Sep 11 in this capture). Anything new: the smaller 32 pt amber disc under a marked-today
ring — still an obvious workout mark next to 40 pt discs? Numerals still fit at AccessibilityL
inside 40 pt (unchanged from before the redesign)?

Do NOT run xcodebuild or simctl. If closed, say "clear" in one paragraph; otherwise report by
severity with file:line. Do not modify source files.
Write to work-record/ui-redesign/codex-review-06c.md
