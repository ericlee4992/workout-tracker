# Agent-skills 02 — independent review, round 1

Reviewed `d02d414d..86fda871` on `ericlee4992/workflow-skills`, HEAD `86fda87160d9ce410865e7c76dcf8f7d105c3244`. The working tree was clean before this report. Docs/agent instructions only; the sole script change is a header comment.

## Standards

1. **P2 — Preserve T6's author/reviewer exception.** `.claude/skills/review-round/SKILL.md:57–59` unconditionally selects a Codex agent, and `.claude/skills/testflight-release/SKILL.md:25` requires every ticket to have a Codex verdict. AGENTS.md:62–64 explicitly allows a ticket to name Codex as implementer, in which case Claude reviews. Such a ticket following these skills selects the wrong reviewer, and its valid Claude clearance cannot satisfy the release ready check. Resolve the implementer and independent reviewer from T6 before dispatch; refer to that reviewer rather than hardcoding Codex in dispatch, recording and release clearance. Make clear that the orchestration steps are the author's path, while an already-dispatched reviewer follows its brief.

2. **P2 — Let docs-only rounds satisfy the evidence criterion.** `.claude/skills/review-round/SKILL.md:17–18` makes real test counts and xcresult paths mandatory for every round, and line 15 requires a regression test for every fix. DEVELOPMENT.md:22 explicitly selects consistency/link/archive checks and no app builds/tests for documentation or skill changes. This ticket itself cannot finish the skill's first step with its authorized verification scope; an agent must either run unnecessary tests or claim evidence that does not exist. Tie the completion criterion to DEVELOPMENT's selected scope: record actual check results for docs-only work, and counts/exit codes/xcresult paths when tests were run. Apply the same qualification to the brief's evidence fields and fix-round regression language.

## Spec

3. **P2 — Determine phone Gate S from the installed build, not the last uploaded build.** `.claude/skills/testflight-release/SKILL.md:28–30` checks stored-format changes since the last release and uses that to say whether the user's phone needs Gate S. If the phone skips schema-changing build 17 and later installs build 18 with no further schema change, this procedure says “no Gate S” even though the phone is crossing the build-17 migration. DEVELOPMENT.md:343–344 requires comparison against the installed build's commit; STATE also records pending installations, so uploaded and installed cannot be equated. Keep the release-to-release delta for release contents, but verify the installed build and evaluate phone backup requirements through the candidate commit, carrying forward intervening stored-format changes. Unknown installation state must not become “no Gate S.”

4. **P2 — Return to the release worktree before committing upload evidence.** `.claude/skills/testflight-release/SKILL.md:100–102` follows step 8's explicit move to detached `release-build` and step 9's “same checkout,” then directs edits, commit, push and another fast-forward without a return to the release branch. Following that sequence creates the record/STATE commit on detached HEAD; ordinary push fails, and the release branch has no evidence commit for the home checkout to merge. Explicitly return to the original release worktree, verify its named release branch, update/commit/push there, then fast-forward and push `main` from the home checkout. Keep the archive checkout detached at the shipped commit.

Standards: 2 findings, both P2. Spec: 2 findings, both P2.

## Checks and scope

Read AGENTS.md, current STATE, ticket 02, the project writing-for-agents skill and SKILL-MECHANICS, tools-paseo, both new skills, the old DEVELOPMENT checklist from `git show d02d414d:docs/DEVELOPMENT.md`, the current `scripts/testflight.sh`, release records 16–17, and the machine-settings review briefs/reports already used in this session.

The old checklist's archive/upload mechanics are otherwise preserved: version consistency, embedded widget identity, production server URL, Google client ID, signing team, `ARCHIVE OK`, `UPLOAD OK`, exit-2 sign-in recovery and same-archive retry match the actual script. Fresh export options remain implemented in the script, so removing their duplicated details from the prose is appropriate. Release/version/What's New/note decisions and App Store Connect Add/Submit remain assigned to the user. The old `## TestFlight build checklist` heading survives as a forwarding section, so current references still reach the procedure; historical review prompts referring to its old step numbers remain historical evidence.

Executed read-only/document checks:

- Relative Markdown file links in both skills, AGENTS.md and DEVELOPMENT.md: **30 checked, 0 broken**, exit 0.
- Markdown fragment anchors in those files: **4 checked, 0 unmatched**, exit 0.
- Both `.agents/skills` entries are symlinks resolving to the corresponding `.claude/skills` directories; their SKILL.md bytes match. Frontmatter names match directory names; descriptions are 194 and 221 characters, with no `disable-model-invocation`, matching the intended model-invoked packaging. Exit 0.
- `rg -n 'TestFlight build checklist|testflight-build-checklist' --glob '*.md'`: reviewed the remaining pointers and historical references.
- `git diff --check d02d414d..86fda871`: exit 0.
- `scripts/check-secrets.sh --all`: exit 0, clean.
- Diff inspection confirms no app/test source or executable script behavior changed. The ticket correctly states the intended scope, but the workflow problems above prevent clearance.

Verified: document consistency review, links, anchors, symlinks, frontmatter, script-to-skill comparison, whitespace and secret checks as above.
Not verified: no builds or app tests run, as instructed for docs-only work; neither workflow was executed end to end. No phone, Apple account, backup, deployment or desktop-control access. Only this report was written.
Known flaky: not applicable to this docs-only scope.

Verdict: not clear
