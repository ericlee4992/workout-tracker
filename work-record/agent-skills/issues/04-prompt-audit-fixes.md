# 04 — Prompt audit fixes

Status: **in review** (branch `ericlee4992/prompt-audit-fixes` off `main` `8381c795`).
Type: task (agent instructions only)

## The user's request (2026-11-19)

`/doctor prompt-audit` over the Claude Code configuration that loads here (target: Claude Opus 5.5), then "make those
changes" — the four proposed hunks. The six flagged items were left unedited (see below).

## Change

1. `.claude/skills/ios-design/SKILL.md` — the description told agents to use the skill "before any screen-level UI
   change", contradicting AGENTS.md → Screen design (2026-11-13, newer than the description, 2026-09-11 by blame: the
   skill is outdated, reference only, never cited). Now `disable-model-invocation: true` (only the user starts it) and a
   "Reference only" description. Codex reads it through `.agents/skills/` and sees the same description.
2. `AGENTS.md` (*Local verification is the gate*) — the first-green-run story (run 43588010018, 216 runs, Xcode 26.6,
   Vision) removed from the always-loaded file; DEVELOPMENT → *CI, scanner tooling* already tells it (without the run
   number and count, which stay in `work-record/dev-speed/` and STATE's archive).
3. `AGENTS.md` (*Domain terminology*) — "`CONTEXT.md` and `docs/adr/` are created lazily" was stale: both exist (ADRs
   0001–0002). Now names them.
4. `.agents/skills/code-review/SKILL.md` (the vendored mattpocock skill; `.claude/skills/code-review` links to it) —
   the two reviewer briefs ended "Under 400 words"; now "Findings only, no preamble." **This copy now differs from the
   pinned upstream** (`skills-lock.json`'s `computedHash` for `code-review`): re-apply the edit if the skill is updated
   from upstream.

## Flagged, not changed (the user's decisions)

- The 10 project skill copies that differ from the `mattpocock-skills` plugin's (1.3.1) versions — both sets offered.
- `~/.claude/skills/orchestration` ("Have Codex review this…" = an Orca worker) vs this project's Paseo reviewer.
- The `graft init`-generated AGENTS section's emphasis (overridden by the project paragraph above it).
- `codex/gpt-5.x` examples in the user-level Paseo skills; TypeScript-only skills offered here; `impeccable` overlap.

## Verification (docs-only: consistency and links)

- No other reference to the removed phrases outside `work-record/` and the archive (`rg`, 0 hits).
- Relative links in AGENTS.md and the ios-design skill resolve (0 broken).
