# Claude independent review — Graft setup and fresh-session checkpoint

Reviewer: Claude (T6 independent review). Date: 2026-09-17.
Scope: exactly `f89dcde..e8e5282` on `ericlee4992/session-handoff` (docs/config only), reviewed
from the separate checkout `ericlee4992/review-session-handoff`. Ticket:
[01-graft-handoff](issues/01-graft-handoff.md). No app build, UI suite, deep summary, or
configuration change was run for this review. Main checkout was read, not modified.

## Verdict: CLEAR

The checkpoint may be fast-forwarded to `main` and pushed. No findings require changes before
merge. Advisory notes below are optional follow-ups, not clearance conditions.

## What was verified

| Check | Method | Result |
|---|---|---|
| Range contains only docs/config | `git diff --stat f89dcde..e8e5282`; grep for `.swift`, `xcodeproj`, test folders | 8 files, all under `.gitignore`, `.ignore`, `AGENTS.md`, `docs/`, `work-record/`; zero app or test files |
| Archive is byte-exact | SHA-256 of `f89dcde:docs/STATE.md` vs committed and on-disk `docs/archive/STATE-2026-09-17-before-graft-handoff.md` | All three `1f572b1b…950ae`; identical |
| Archive index entry | `docs/archive/README.md` diff | One new row, provenance names `f89dcde`, existing rows untouched |
| User's three uncommitted changes preserved | `cmp` of main working `.gitignore` and `.ignore` against `e8e5282`; `diff` of main working `AGENTS.md` against committed | `.gitignore` and `.ignore` identical; `AGENTS.md` differs only by the added project-precedence paragraph; generated `graft:start`/`graft:end` fence identical |
| Precedence paragraph outside the fence | Read `AGENTS.md` | Paragraph sits before `<!-- graft:start -->`; `graft init` rewriting the fence would not remove it |
| Unresolved-work tail retained | `diff` of `## Open work retained…` to EOF, old vs new STATE | Identical, every row and link kept |
| Live phone/backup section retained | `diff` of `## Live phone and backup` section | Identical: installed source `4d70d7d` built from `39b4c8d`, install 21:43 / launch 21:44 EDT, PID 15231, profile expiry 2026-09-24 07:16:18/20 UTC, backup path `~/WorkoutTracker-Backups/2026-09-17-before-ticket17`, UDID, bundle/team |
| Source vs merged vs installed kept distinct | Read new STATE bullets; `git diff --name-only 39b4c8d..f89dcde` | Source `4d70d7d`, merge `39b4c8d`, later commits through `f89dcde` touch no `.swift`/project files; installed = `4d70d7d` via `39b4c8d` build |
| Referenced commits exist | `git cat-file -t` | `5a4c1b2`, `dea20f4`, `4d70d7d`, `0b6515f`, `9b9feef` all present |
| Links and anchors | Script over every `](…)` in STATE, DEVELOPMENT, archive README, AGENTS, CLAUDE, ticket | All targets exist. `DECISIONS.md#deferred--open` matches heading "Deferred / open" under GitHub slug rules; `#ci-scanner-tooling-and-time-based-behavior` and `#graft-code-navigation` match their headings |
| Branch pushed | `git log origin/ericlee4992/session-handoff` | Tip `e8e5282`; `main` and `origin/main` at `f89dcde` |
| Graft CLI | `which graft`, `graft --version` | `~/.local/bin/graft`, 0.18.0 |
| Graft graph in main | `graft check "<main>"` (read-only, exit 0) | "wiring graph is in sync"; deep layer not built, 2,639 nodes pending (221 files + 2,418 symbols) — matches STATE/ticket and DEVELOPMENT's statement that this is not a failure |
| `.ignore` behaviour | `rg --files <main>` with and without `--hidden` | 222 Graft card files searchable; zero `graft/.graph/` or `graft/.cache/` entries even with `--hidden`; `git status` in main still ignores `graft/` |
| Codex MCP configured | `~/.codex/config.toml` `[mcp_servers.graft]` (command `graft`, args `["mcp"]`); `codex mcp list` | Entry present, Status `enabled`. Direct six-tool handshake was Codex's evidence and is consistent with the ticket; not re-run here |
| Codex hooks configured | Parse `~/.codex/hooks.json`; `ls` hook script | Exactly four Graft entries (SessionStart, UserPromptSubmit, PostToolUse, Stop), each added beside a pre-existing entry; `~/.codex/hooks/graft/graft-hooks.cjs` present, executable |
| Configured vs runtime-proven | Read STATE and ticket wording | Both say MCP/hook *configuration* and a direct server handshake are verified and that a fresh Codex client loading the tools and live hook execution are *not yet observed*. Accurate |
| No false Claude MCP/hook claim | Checked project `.claude/settings.json`, `.mcp.json`, `.claude/skills/graft/SKILL.md`, `~/.claude/skills/graft/SKILL.md`, grep `graft` in `~/.claude/settings.json` | All absent / zero matches, matching the ticket's "Claude scope" section; STATE says "do not claim those are installed" |
| Original preferences retained | Read STATE | Sidebar tidy / Hide sleeping, dismissed design prompt, current finish design kept, Codex 872,000 / 780,000 / footer, next product action unchosen, rejected A/B/C historical only |
| Ticket claims spot-checked | `ls` of npm log and `/tmp/graft-install-retry.*`; `graft init --help`; `graft build --help` | Logs present, retry exit file reads `0`; `--agents`, `--dry-run`, `--deep` flags exist as DEVELOPMENT describes; `~/.codex/config.toml` model line matches the ticket |
| Ticket status vocabulary | `docs/agents/issue-tracker.md` | `Status: claimed` is the documented pre-resolution state; sibling tickets likewise omit `Type:` |

## Advisory notes (not blocking)

1. **Duplication between AGENTS fence and DEVELOPMENT.** The DEVELOPMENT Graft section repeats
   the command list (`graft map`, `ask --source`, `skeleton`, `callers`) the generated fence
   already carries. Per the writing-for-agents guidance, that is a cache of `--help` output and
   of the fence; a later trim could keep only the project-specific parts in DEVELOPMENT
   (fallback rule, check/build, fence-rewrite warning, hook/MCP scope). Harmless now.
2. **`codex mcp list` prints `Unsupported` in its Auth column** for the graft entry. That column
   is OAuth support for the server, not a health status. Worth knowing so the next session does
   not read it as a failure.
3. **Per-checkout graph.** This review checkout has no `graft/` build ("No graft/ graph found");
   DEVELOPMENT already states each checkout may need its own `graft build`. No action needed.
4. **Commit message is a single line.** Acceptable for this repo; the ticket carries the detail.

## Not verified by this review

- A fresh Codex client actually loading the six Graft MCP tools, and Graft hooks firing in that
  client. STATE correctly lists this as the next session's first verification.
- The direct stdio MCP handshake and the scratch three-file parse were not re-executed; the
  configuration they depend on was inspected and matches the ticket.

## Next action after merge

Fast-forward `main` to `e8e5282`, push, confirm the remote tip, then start the new Codex
session in the main checkout. Sleep this review workspace.
