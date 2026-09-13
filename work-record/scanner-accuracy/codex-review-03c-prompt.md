Round 3 (T6) of scanner-accuracy ticket 03. Round-2 review:
work-record/scanner-accuracy/codex-review-03b.md. Boundary of the fixes: 4120444..HEAD (one
commit). The response is in issues/03-capture-first.md under "Codex review 03b — response".

Scope: are the three round-2 findings closed exactly — the focus settle + generation guard +
onDisappear cancellation (trace: dismiss during the 150 ms settle, during the poll, and
between capturePhoto and the delegate; what runs, what is dropped, what is reported), the
request identity on both callbacks and captureFinished(request) (trace: a photo for an old
request arriving while a new one is in flight; a configuration failure; the fixture path,
which never calls the camera), and the corrected counts. And whether the fix introduced a
new defect (the `pending` tuple is now cleared in the delegate — can a capture that never
reaches the delegate leave it set, and does that matter?).

If closed, say "clear" in one paragraph. Otherwise report by severity with file:line. Do not
modify source files. Write to work-record/scanner-accuracy/codex-review-03c.md
