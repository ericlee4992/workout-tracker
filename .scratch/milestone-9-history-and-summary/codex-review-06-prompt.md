Cross-review (T6) of milestone 9, ticket 06, on branch
milestone-9-history-and-summary. Review boundary: 802c7dc..b0e0004 (one commit).
Read issues/06-remove-helper-copy.md for the scope the user chose (option A)
and docs/DECISIONS.md D9, D25, D44, D45, D47.

This is a copy-removal commit. Attack it on three fronts:
1. Did anything load-bearing go? Grep the diff for every removed string and
   judge whether it stated a CONSEQUENCE (must stay: D9/D25 ≈ markers, D45
   "(estimated)", delete-impact confirmations, D47 edited marker) or
   explained a screen (may go). Is any remaining ≈ now unexplained anywhere a
   converted number is shown without one?
2. Structure: removing `footer:` clauses can leave `Section { }` empty or
   change a Section's trailing-closure shape. Check every touched Section
   still compiles to the intended rows (it does compile; check intent), and
   that no `if` inside a removed footer carried logic beyond the text.
3. Uncalled leftovers: helpers/state used only by removed text. The commit
   removed `footer(days:)` and `isFrozen`; find any others (e.g. bindings,
   computed vars, `canSaveAsTemplate` usages, localization).
Report by severity with file:line. Write to
.scratch/milestone-9-history-and-summary/codex-review-06.md
