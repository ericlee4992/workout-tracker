Round 2 (T6) of finish-graph ticket 01. Round-1 review:
work-record/finish-graph-and-plain-numbers/codex-review-01.md. Boundary of the
fixes: 32dad6f..cb6559f (one commit, cb6559f). The response to each finding
is in issues/01-apple-shaped-heart-rate-graph.md under "Codex review 01 —
response".

Scope: (1) is each of the four findings closed, exactly — the fixture guard
(both fixtures, pure `isEnabled(arguments:)`, and whether any launch path or
test still relies on the flag alone), the export pair rule
(`HeartRateSeriesMath.exportableRange`, and whether `ExportCollector` could
still write one array without the other on any path), the duration horizon
in `displaySlots` (slots at/after a positive duration dropped, kept ones
clamped, non-positive duration unclipped — check the view's `xEnd` still
feeds it something sensible), and the schema-9 statements in STATE/SPEC;
(2) whether any fix introduced a new defect — the classic trap here is the
fix itself (see DECISIONS "Reviews"); (3) the three new regression tests
actually fail against 32dad6f's code (reason from the diff; do not rewrite
history to check).

If everything is closed, say "clear" in one paragraph. Otherwise report by
severity with file:line. Do not modify source files. Write to
work-record/finish-graph-and-plain-numbers/codex-review-01b.md
