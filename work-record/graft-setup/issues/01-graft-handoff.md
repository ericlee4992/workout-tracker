# 01 — Graft setup and fresh-session checkpoint

Status: claimed — facts verified; documentation/integration checkpoint awaiting independent review

## User intent

After ticket 17 was installed, the user asked about Graft, chose to install it, then asked how
to add Codex after believing only Claude was selected. The final request is to preserve all
context before starting a new Codex session. No new app feature, deep summary run or additional
agent integration is authorized by this checkpoint.

Implementation branch: `ericlee4992/session-handoff`, base `f89dcde`.
Main checkout: `/Users/ericlee06/orca/projects/Health App`.
At start, the user's setup left exactly three repository changes: `.gitignore` modified to
ignore `/graft/`, `AGENTS.md` with a fenced Graft section, and new `.ignore` allowing cards in
search. Preserve them. Personal configuration is outside Git; no credentials are copied here.

## Verified Graft state (2026-09-17)

- CLI `/Users/ericlee06/.local/bin/graft`, version **0.18.0**, Node **22.23.2**, npm **10.9.8**.
- Initial global install failed with `ETIMEDOUT` while fetching `web-tree-sitter`; npm's Swift
  peer warning was a separate warning. The same package downloaded on inspection and the
  unchanged `npm install -g @nanonets/graft@0.18.0` retry succeeded (44 packages, exit 0).
  Logs: user's `~/.npm/_logs/2026-09-18T02_17_00_955Z-debug-0.log`, retry
  `/tmp/graft-install-retry.log` / `/tmp/graft-install-retry-exit.txt`.
- The installed native Swift parser accepted WorkoutSummary, WeightMath and WorkoutFinishedSheet
  with no parse errors. A scratch Graft build of those three files passed: 32 nodes, 59 links;
  `graft map` worked. This demonstrates that the peer warning did not prevent these operations;
  it is not a proof of complete Swift semantic coverage.
- User subsequently built the actual project graph. `graft check` now exits 0 and reports fresh;
  `graft map --json --no-refresh` reports **221 files, 2,418 symbols, 7,099 links** (Swift/Python).
  `graft/.graph/wiring.json` and `graft/INDEX.md` exist. The deep/meaning layer is **not built**;
  pending summaries are expected in structural-only mode. No API-backed deep build was run.
- `~/.codex/config.toml` has enabled `[mcp_servers.graft]`: command `graft`, args `["mcp"]`.
  `codex mcp list` reports it enabled. Direct stdio initialize/tools-list handshake succeeded:
  server graft 0.18.0, tools `graft_find_code`, `graft_file_api`, `graft_check_freshness`,
  `graft_trace_calls`, `graft_find_all`, `graft_repo_map`.
- `~/.codex/hooks/graft/graft-hooks.cjs` exists; `~/.codex/hooks.json` has one Graft entry each
  for SessionStart, UserPromptSubmit, PostToolUse and Stop. Other hook entries were preserved;
  this checkpoint reads configuration, it does not rewrite it.
- Codex model remains `gpt-6-astra`; configured context 872,000, compaction 780,000; existing
  model/current-dir/thread/context-used/context-remaining/context-window-size footer retained.

**Still to observe:** a new Codex session loading those MCP tools and Graft hooks executing in
that client. Configuration and a direct server handshake are verified; live client behavior is
not yet verified. This older session can use the CLI regardless.

## Claude scope — preserve the distinction

`CLAUDE.md` imports AGENTS, so Claude receives the shared Graft navigation instructions. There
is no `.claude/skills/graft/SKILL.md`, `.claude/settings.json`, `.mcp.json` in this project, nor
`~/.claude/skills/graft/SKILL.md`; global `~/.claude/settings.json` contains no Graft entry.
Do not infer separate Claude MCP/hook installation from the user's initial assumption. Do not
silently add it as part of handoff preparation. Claude may still invoke the installed CLI.

## Documentation changes

- Preserve the generated Graft fence verbatim. Add project precedence immediately before it:
  startup reads first; graph results are navigation candidates; current source, callers and
  tests verify edits; project docs govern product behavior. Keep normal `rg` searches available.
  This resolves generated claims that the top node is the answer or edges are always exact,
  without losing the user's installation output. `graft init` may overwrite its fence later;
  the project-specific paragraph is deliberately outside it.
- Put repeatable navigation/fallback/refresh guidance in DEVELOPMENT.
- STATE is the current restart brief: selected finish design, actual installed phone build,
  backup/profile facts, 72/72 evidence and known warnings, Graft configuration versus pending
  fresh-session validation, sidebar preference, and the unselected next product task.
- Preserve previous STATE byte-for-byte at `docs/archive/STATE-2026-09-17-before-graft-handoff.md`
  from `f89dcde`. Retain every existing unresolved-work row and its links.
- The queued design-choice question was dismissed using the displayed Skip control. It is no
  longer an outstanding user decision. User explicitly preferred the current finish screen;
  A/B/C alternatives are historical only.
- Finished workspaces sleep with Hide sleeping enabled; folders and review/test evidence remain.
  After this checkpoint, return to main and sleep its temporary workspaces too.

## Verification and next action

Docs/config only; no app rebuild, UI suite, schema change or phone reinstall needed. Check
local links, archive bytes, exact preservation of the generated fence/ignore files, and no
app/test diff. Claude independently reviews in a separate checkout before fast-forward/push.
Then start the new Codex session in main, read AGENTS/STATE/this ticket, verify Graft client
loading, and wait for the user's next product choice. Do not re-run completed ticket 17 work.
