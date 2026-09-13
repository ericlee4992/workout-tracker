Round 2 (T6) of finish-graph ticket 02. Round-1 review:
work-record/finish-graph-and-plain-numbers/codex-review-02.md. Boundary of the
fixes: 2262b0f..d198352 (one commit, d198352). The response is in
issues/02-remove-approx-and-estimated.md under "Codex review 02 — response".

Scope: are the seven findings closed exactly — the metric picker, the four
STATE lines and STATE's new head (is every claim in that head true, including
what is and is not merged/installed/pushed/run), the WeightMath header, the
D45 and D52 wording, the CLAUDE index, and the new
`WeightMath.displayLabel(kilograms:in:locale:)` (do all three former sites
call it, is the kg case still exact, is it tested)? Then the general grep
again: any on-screen ≈ / "estimat" / "est." anywhere in the app, widget or
watch targets. And whether any fix introduced a new defect.

If closed, say "clear" in one paragraph. Otherwise report by severity with
file:line. Do not modify source files. Write to
work-record/finish-graph-and-plain-numbers/codex-review-02b.md
