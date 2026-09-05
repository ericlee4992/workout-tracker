Round 3 (T6) of scanner-accuracy ticket 02. Round-2 review:
.scratch/scanner-accuracy/codex-review-02b.md. Boundary of the fixes: bf77d4d..c87ae80 (one
commit, c87ae80). The response is in issues/02-brand-repair.md under "Codex review 02b — response".

Scope: is each round-2 finding closed exactly — the sibling exception removed outright (no
trace left in CatalogMatch, score, or tests beyond the pinning test), digit refusal,
dictionary refusal in split, the spliced two-line pass (re-try HAMMER- / (STRENCTH)), the
amended ticket text vs the code, dead state gone — and whether any fix introduced a new
defect. The amended ticket now lists accepted costs; check they are stated truthfully.

If closed, say "clear" in one paragraph. Otherwise report by severity with file:line. Do not
modify source files. Write to .scratch/scanner-accuracy/codex-review-02c.md
