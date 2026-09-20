# 02 — Verification scope proportional to change risk

Type: task
Status: resolved — checked and independently reviewed; merged with this checkpoint

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

## Verification evidence

Implemented/pushed **ad519c3**. Checked modified Markdown relative links, verification-scope
heading, CLAUDE import and ios-design symlink. `git diff --check` passes. App/test/config
trees and `docs/archive/` unchanged; STATE's entire Live phone and backup + Open work sections
are byte-identical to the base. Current cardio/redesign gates now point to the policy.
Policy cases checked: a one-screen cosmetic edit uses targeted UI/captures; unit logic adds
relevant unit/integration checks; shared persistence adds migration/impact coverage and escalates
when risk cannot be bounded; docs-only uses links/consistency; reinstall alone adds no full UI run.
Imported implement skill remains unchanged, with AGENTS precedence explicit. No app build,
test run, device operation or CI/scheduler edit performed. Independent [Claude docs review](../verification-policy-review.md) is **CLEAR**, authored at
7d2ad77 against ad519c3. No required fixes; result/status notes completed here, prose wrapping
clarified. The older lock-screen ticket's full-suite request remains tied to its concrete
new-target regression risk, governed by the new policy when resumed.

Final changes are documentation only. Branch `ericlee4992/verification-policy` is
fast-forwarded to main and pushed with this checkpoint; reviewed policy **ad519c3**.
Final whitespace, link/anchor and preservation checks passed. No app tests/build/install.
