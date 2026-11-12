# Agent tooling: Paseo (active since 2026-11-11)

Paseo manages the agents, terminals and worktrees. Read the `paseo` skill for tool details. The previous Orca setup
is kept in [tools-orca](tools-orca.md).

## Codex reviewer

- The reviewer is a Paseo Codex agent started from the implementing session (`create_agent`) in the task's
  workspace, so it shows as its own tab: provider `codex/gpt-6-astra`, `settings: { modeId: "full-access",
  thinkingOptionId: "high" }` (the user chose full access, 2026-11-11; the model matches `~/.codex/config.toml`;
  check `list_models` if it is gone). Keep `notifyOnFinish` on.
- Keep **one Codex agent** for every review round and ticket: `list_agents`, then `send_agent_prompt` to the idle
  Codex agent. Start a new one only when it is archived, stuck in an error, near its context limit, or in another
  workspace. Record its agent ID in STATE.
- Completion: the finish notification says when to look; the result is the report file's `Verdict:` line
  (`work-record/<feature>/codex-review-*.md`), read by you. The user must not have to relay results. If a
  permission request still arrives, read it and answer with `respond_to_permission`.

## Test progress tab

One reused Paseo terminal named "Test progress" per workspace (`create_terminal`, then `send_terminal_keys` with
`bash scripts/test-progress.sh <log> <count> "<title>"` and Enter). Check `list_terminals` first; create one only when
none exists or it is busy. Tell the user it is there.

## Worktrees and handoff

- Each task gets a Paseo worktree workspace on a short-lived branch off `main`: `create_workspace` with `isolation:
  "worktree"`, `mode: "branch-off"`, `branchName: "ericlee4992/<task>"`, `baseBranch: "origin/main"`, `projectId` of the
  home checkout, `worktreeSlug: "<task>"`. Paseo places it under `~/.paseo/worktrees/…` and returns the path.
- Once the branch is merged and its record written, `archive_workspace`: Paseo removes the worktree it created; the
  branch stays. The older Orca worktrees under `…/orca/workspaces/Health App/` are removed with `git worktree remove
  <path>` (also keeps the branch) — never `release-build`, the detached TestFlight archive checkout.
- A session in the home checkout given a task creates the task's workspace, starts a Claude agent there with a brief
  (`create_agent`, `notifyOnFinish: false`), tells the user which workspace to open, and stops.
