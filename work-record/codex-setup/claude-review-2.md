# Claude re-review — Codex project setup (ticket 01), round 2

Reviewer: Claude (independent, T6; not the author). 2026-09-17.
Scope: current working tree and index of `ericlee4992/codex-project-setup` against base `9b9feef`
(HEAD still `9b9feef`; the symlink is staged, everything else unstaged/untracked), the round-1
response in `issues/01-codex-workflow.md:79-101`, and the three approved config fields. No
Xcode/device commands, no config or file changes other than this report.

**Verdict: CLEAR. No required changes remain.** F1–F7 are resolved or reasonably declined, and I
found no regression. Two optional observations are at the end.

## Round-1 findings

| # | Status | Evidence |
|---|---|---|
| F1 (P2) launch claim | **Resolved; my finding was partly wrong.** | `git show a49c8d1:docs/STATE.md` line 8: "INSTALLED and launched on the phone at 03:17"; `a49c8d1` is an ancestor of `9b9feef`. Round 1 searched only the base STATE, ticket 16 and commit subjects; the base handoff had dropped "launched" when it was rewritten. `docs/STATE.md:40` now says "installed … launch reported in the prior handoff (`a49c8d1:docs/STATE.md`)", without "remotely", and ticket 16:160-163 records the provenance and disclaims new device verification. That is the installed-vs-launched distinction AGENTS:11-12 asks for. |
| F2 (P2) caller/contract rule | **Resolved.** | `AGENTS.md:61-63`: check internal functions and doc comments against callers before closing a feature; verify gated settings are reachable and mirrored messages are sent; "testing only the gate or receiver misses these defects". All three archived instructions are covered. |
| F3 (P3) dropped open items | **Resolved.** | `docs/STATE.md:66` adds calendar, workout naming and the "Reclassified from …" line. `docs/STATE.md:49-50` restores re-export guidance and says the phone is the only known copy of history newer than the last backup. |
| F4 (P3) lessons missing from DEVELOPMENT | **Resolved.** | `docs/DEVELOPMENT.md:146-155`, "Persistence and export lessons": `#Predicate` enum launch crash, idempotent per-launch gate (cites D51), append-don't-reuse export columns, order-dependent tests. Each matches archive:429-446. |
| F5 (P3) old CLAUDE rules | **Resolved / declined with reason.** | Build rule at `AGENTS.md:61`. `docs/archive/CLAUDE-2026-09-17-before-codex-setup.md` is byte-identical to `9b9feef:CLAUDE.md` (`cmp` clean, 7,382 bytes) and listed in archive README:12. Its filename is not `CLAUDE.md`, so Claude Code will not auto-load it as instructions. Remote URL left to `git remote -v` — acceptable. |
| F6 (P3) ownership | **Resolved / deferred with reason.** | `AGENTS.md:28-29` now puts running-task identity in the ticket, linked from STATE — consistent with DEVELOPMENT:37-38. README:66-67 lists AGENTS/CLAUDE, DEVELOPMENT and the archive. The stale `CLAUDE.md` citations in `tests.yml:64` and four Swift comments are recorded as a follow-up (ticket:96-98); correct to leave, since this ticket changes no source or CI. |
| F7 (P3) skill discovery | **Resolved on recorded evidence.** | Ticket:74-75 records the `/skills` picker showing `ios-design [Skill]` in a fresh Codex session (coordinator's direct observation; I did not repeat it, by instruction not to involve Codex). I verified independently: `git ls-files -s .agents/skills/ios-design` → mode `120000`, target `../../.claude/skills/ios-design`, resolves. |

## Regression checks

- **STATE archive:** `cmp` against `git show 9b9feef:docs/STATE.md` still identical (95,261 bytes,
  unchanged mtime 13:16). **CLAUDE archive:** identical, as above.
- **Links/anchors:** scripted check over AGENTS, CLAUDE, README, STATE, DEVELOPMENT, archive
  README, the setup ticket and ticket 16 — none broken. `git diff --check` (worktree and index)
  clean; no trailing whitespace in untracked files.
- **Unexpected changes:** the only file touched beyond round 1's set is ticket 16 (five appended
  lines of provenance; nothing existing edited). `docs/DECISIONS.md` still differs only in T5/T6.
  No app, test, project, script or CI file is modified.
- **Config:** parsed comparison to the backup still shows exactly three differing key paths —
  `model_context_window`, `model_auto_compact_token_limit`, `tui.status_line`. No other values read.
- **Ticket accuracy:** the validation section (ticket:70-77) matches what I measured, including
  the STATE SHA-256 and my round-1 confirmation that `@AGENTS.md` loaded.

## Optional observations (not required for clear)

- `AGENTS.md:29-31`: the F6 edit left a short orphan line ("Preserve old handoffs in the archive");
  re-wrap the paragraph when next editing. Cosmetic.
- `docs/STATE.md:11-12` and ticket:3/:101 still say Claude review is pending. Update both to
  "Claude clear after 2 rounds (`claude-review.md`, `claude-review-2.md`)" in the same commit that
  lands this work, so STATE is not stale the moment it merges. Normal closing bookkeeping, not a defect.

Remaining steps are the author's/coordinator's under AGENTS:54-56: commit (including this report
and the staged symlink), push the branch, fast-forward `main`, push, confirm the remote tip.
