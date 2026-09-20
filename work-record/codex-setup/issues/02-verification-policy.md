# 02 — Verification scope proportional to change risk

Type: task
Status: claimed

User approved 2026-09-20: replace mandatory full UI runs for every screen change with targeted
verification; reserve full UI for major releases, broad/uncertain impact and periodic regression.
The earlier 85-test UI run took about 51 minutes, disproportionate for small iterative UI edits.

## Acceptance

- AGENTS routes test selection to one maintained policy in DEVELOPMENT.
- Policy distinguishes cosmetic UI, logic, new features, broad/shared changes and docs-only work.
- Full-suite escalation is explicit; routine scope selection needs no extra approval.
- Build, actual exit/result inspection, independent review, migration/data and install checks stay.
- Design skill/review and current cardio/redesign specs agree; CLAUDE imports AGENTS.
- Preserve historical test evidence, archives, installed-build facts and unresolved device acceptance.
- Generic imported skills retain their upstream text; AGENTS explicitly gives this project policy
  precedence over their blanket full-suite wording. No scheduler/CI configuration is introduced.

## Verification

Docs only: diff/whitespace, Markdown links and scope-policy consistency; inspect import/symlink
paths; preserve existing archive bytes. Independent Claude docs review before merge. No app build,
unit/UI run or phone installation is needed for these instruction-only edits.

Base main **4a7cbc1**; branch `ericlee4992/verification-policy`. Implementation in this worktree.
