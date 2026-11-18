You are the independent reviewer (AGENTS.md T6) for agent-skills ticket 02: two project skills, `review-round` and
`testflight-release`. Claude wrote them. Repository /Users/ericlee06/.paseo/worktrees/1qmeipq9/machine-settings,
branch `ericlee4992/workflow-skills`; diff `git diff d02d414d..HEAD`. Docs and agent instructions only — no app code.

Read first: AGENTS.md; work-record/agent-skills/issues/02-workflow-skills.md; .claude/skills/writing-for-agents/SKILL.md
and SKILL-MECHANICS.md (the project's own rules for agent documents); docs/agents/tools-paseo.md; the old checklist
(`git show d02d414d:docs/DEVELOPMENT.md`, section "TestFlight build checklist"); scripts/testflight.sh; the two latest
release records (work-record/release/0.2.0-build-16.md, 0.2.0-build-17.md) and machine-settings' review prompts and
reports (work-record/machine-settings/codex-review-01*.md) as worked examples of what the skills describe.

Review:
1. Nothing lost: every step, rule and gotcha of the old DEVELOPMENT checklist is in `testflight-release` (or rightly
   left to `scripts/testflight.sh`). Is anything in the skill wrong against the script's actual behaviour (commands,
   output lines `ARCHIVE OK` / `UPLOAD OK`, exit 2, paths, the checks it runs)?
2. Single source of truth: does either skill restate a rule that AGENTS.md, tools-paseo or DEVELOPMENT owns, in a way
   that could drift — or contradict them (one Codex session, what the reviewer reruns, the self-check, Gate S,
   checkout layout, the user's decisions)? Are the remaining pointers to the old checklist (`rg "TestFlight build
   checklist|testflight-build-checklist"`) all valid?
3. Would an agent following each skill step by step do the right thing? Clear completion criteria; the order (e.g.
   merge `main` from the home checkout; Gate S before the phone installs; GitHub Tests after); any step that would
   act on its own where the user must decide (version, What's New, note, App Store Connect Add/Submit).
4. Skill mechanics: frontmatter, model-invoked descriptions (triggers, length), the `.agents/skills` symlinks for Codex.
5. The ticket: does it claim more than the change does?

Run: no build or tests (docs-only, per DEVELOPMENT → Verification scope); check links and the symlinks resolve. Modify
nothing but the report; no phone, Apple account, backups, deploys or desktop control. Write
work-record/agent-skills/codex-review-02.md: numbered findings with severity (P0–P3), file:line, the failure scenario
and a suggested fix; what you checked; then a last line that is exactly "Verdict: clear" or "Verdict: not clear".
