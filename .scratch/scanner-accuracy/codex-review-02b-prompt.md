Round 2 (T6) of scanner-accuracy ticket 02. Round-1 review:
.scratch/scanner-accuracy/codex-review-02.md. Boundary of the fixes: 5ffa3cc..bf77d4d (one
commit, bf77d4d). The response to each finding is in issues/02-brand-repair.md under "Codex
review 02 — response".

Scope: (1) is each round-1 finding closed exactly — re-run your own constructions
(MOIST CHEST PRESS RS-2301, PRICE FITNESS, START TRACK, RECORD, METRIC, the three
furniture-word sibling cases, the compound-word splits, HOISI-RS-2403) against the tip, and
enumerate again: with the brand-line gate + dictionary refusal, which 4–6-char brand
tokens can STILL be manufactured, and from what (a non-word within one edit, alone on a
line — grade how plausible that is on a plate); (2) the new pieces — the two-consecutive-
line brand pass (can it join two unrelated lines into a brand? it requires both lines
unchanged by the single-line pass and the pair to be exactly one brand), the name-line
rule (≥2 name words; find a shipped sibling pair it still lets through, or one it now
wrongly blocks — e.g. a row whose distinguishing word is on its own line by design),
MachineLabelDictionary's MainActor.assumeIsolated (every caller on the main actor? the
harness, the sheet's live path, the still path — trace them), and CatalogMatchIndex
building the name-token pair set (cost, correctness for single-token names); (3) whether
any fix introduced a new defect — the classic trap; (4) the reports/tickets/commit message
claims, including test counts.

If everything is closed, say "clear" in one paragraph. Otherwise report by severity with
file:line. Do not modify source files. Write to
.scratch/scanner-accuracy/codex-review-02b.md
