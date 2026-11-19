You are the independent reviewer (AGENTS.md T6) for agent-skills ticket 04: four edits from a prompt audit of the
project's Claude Code configuration. Claude made them. Repository
/Users/ericlee06/.paseo/worktrees/1qmeipq9/machine-settings, branch `ericlee4992/prompt-audit-fixes`; diff
`git diff 8381c795..HEAD`. Agent instructions only, no app code.

Read first: AGENTS.md; work-record/agent-skills/issues/04-prompt-audit-fixes.md; .claude/skills/writing-for-agents/
SKILL.md and SKILL-MECHANICS.md; docs/DEVELOPMENT.md → "CI, scanner tooling, and time-based behavior".

Check: (1) each edit says no less than the project needs — e.g. does dropping the CI history from AGENTS.md lose a rule,
not just history; is the ios-design change consistent with AGENTS.md → Screen design and with Codex reading it through
`.agents/skills/` (frontmatter fields Codex might not understand); (2) the new text is accurate (`CONTEXT.md`,
`docs/adr/`); (3) the vendored `code-review` edit and its note about `skills-lock.json`; (4) the ticket claims no more
than the diff. Docs-only: checks, no build. Modify nothing but the report. Write
work-record/agent-skills/codex-review-04.md: numbered findings (P0–P3, file:line, scenario, fix), what you checked, then
exactly "Verdict: clear" or "Verdict: not clear".
