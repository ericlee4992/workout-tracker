Round 4 (T6) of scanner-accuracy ticket 03. Round-3 review:
work-record/scanner-accuracy/codex-review-03c.md. Boundary of the fixes: c744dbd..HEAD (one
commit). The response is in issues/03-capture-first.md under "Codex review 03c — response",
followed by the verification record at this head (672/672 unit, 37/37 UI in four chunks).

Scope: are the four round-3 findings closed exactly — the focus wait now observing a
started-then-settled transition (trace a lens already on target: does it fall through at
300 ms? a lens that starts adjusting at 250 ms and settles at 900 ms? one still hunting at
1 s?), the generation written and read only on the session queue (is every read inside a
queued block? is the snapshot taken after the isRunning guard?), the teardown fold, and the
gate record (is it at THIS head?). And whether the fix introduced anything new.

If closed, say "clear" in one paragraph. Otherwise report by severity with file:line. Do not
modify source files. Write to work-record/scanner-accuracy/codex-review-03d.md
