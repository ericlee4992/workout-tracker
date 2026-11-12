# Agent tooling: Orca (inactive)

The project ran on Orca until 2026-11-11, then moved to Paseo ([tools-paseo](tools-paseo.md)). This file keeps the
Orca setup so it can be switched back: point AGENTS.md's "Agent tooling" line here and read the version-matched
`orca-cli` skill. The exact AGENTS.md wording before the switch is in commit `97e63f9`.

## Codex reviewer

- Run Codex in a visible Orca terminal and keep **one Codex session** for every review round and ticket: check
  `orca terminal list` and send the next prompt to the idle Codex terminal (`orca terminal send`). Open a new one only
  when that terminal is gone, stuck in an approval/interrupted state, near its context limit, or in another worktree.
- Launch: `orca terminal create --worktree active --title "Codex review — <ticket>" --command 'codex "$(cat <prompt-file>)"'`.
  The model comes from `~/.codex/config.toml`; don't pin one.
- Follow-up rounds: `orca terminal send --terminal <term_id> --text "…" --enter --wait-submit 20`. Read the screen with
  `orca terminal read --terminal <term_id> --screen` (the positional form fails).
- Completion: watch the report file (`work-record/<feature>/codex-review-*.md` exists and is unchanged for ~45 s), not
  `orca terminal wait --for tui-idle`, which never reports idle at Codex's prompt.
- Approvals: scan the terminal for "Would you like to run", "Press enter to confirm", "Allow command", "Do you want to
  allow"; count a prompt as pending only if it comes after the last "You approved" / "You denied" / "Ran ";
  de-duplicate on its `Reason:` line. Answer with `--text "y"` (or `"p"` for a narrow command you invited).

## Test progress tab

One reused Orca terminal titled "Test progress" per worktree: `orca terminal send --terminal <id> --text "bash
scripts/test-progress.sh <log> <count> \"<title>\"" --enter`. Create it (`orca terminal create --title "Test progress"`)
only when none exists or it is busy.

## Worktrees and handoff

- Each task gets its own Orca worktree under `…/orca/workspaces/Health App/` on a short-lived branch off `main`
  (`orca-cli`); once the branch is merged and its record written, remove the worktree with `orca worktree rm`, which
  keeps the branch.
- A session started in the home checkout and given a task creates the task's worktree with an agent and a brief
  (`orca worktree create … --agent claude --prompt`, per `orca-cli`'s handoff steps), tells the user which workspace to
  open, and stops.
- Decline desktop control (`orca computer …`).
