# Claude review — Codex project setup (ticket 01)

Reviewer: Claude (independent, T6; not the author). 2026-09-17.
Scope: working tree of `ericlee4992/codex-project-setup` against base `9b9feef` (HEAD is still
`9b9feef`; every change is uncommitted) — tracked diffs (`CLAUDE.md`, `README.md`,
`docs/DECISIONS.md`, `docs/STATE.md`) and all untracked files (`AGENTS.md`,
`docs/DEVELOPMENT.md`, `docs/archive/`, `.agents/skills/ios-design`, `work-record/codex-setup/`),
plus the three approved fields of `~/.codex/config.toml`. No Xcode/device commands were run; nothing
outside this report was modified.

**Verdict: not clear yet — one P2 factual claim to fix and one P2 omitted rule to restore; the rest
are P3. No history was lost: everything flagged below still exists in the archive.**

## Verified clean

- **Archive bytes.** `git show 9b9feef:docs/STATE.md | cmp - docs/archive/STATE-2026-09-17-before-codex-setup.md`
  → identical; SHA-256 `f6ce2d83…0428866` on both; 95,261 bytes.
- **Links.** Every relative link and `#anchor` in AGENTS, CLAUDE, README, STATE, DEVELOPMENT,
  archive README and the ticket resolves (scripted check, GitHub slug rules). `git diff --check`
  clean; no trailing whitespace in the new files.
- **Claude import.** `@AGENTS.md` works: this session's loaded project instructions contained
  the full AGENTS text.
- **Skill link.** `.agents/skills/ios-design` → `../../.claude/skills/ios-design` (relative
  symlink, resolves; `SKILL.md`, `REFERENCE.md`, `REVIEW.md` present; frontmatter has
  `name`/`description`). One maintained copy, as AGENTS:72-73 says.
- **Config outside Git.** Parsed `config.toml` and the backup with `tomllib` and compared the
  flattened structures, printing values only for the approved keys. Exactly three differences:
  `model_context_window` absent → 872000; `model_auto_compact_token_limit` absent → 780000;
  `tui.status_line` gained `context-used`, `context-remaining`, `context-window-size` after the
  three existing items. 74 → 76 leaf keys; no other key path differs. Both files are mode 0600.
- **DECISIONS.** Only T5/T6 changed; both amendments are dated, keep the original text, and match
  what the user approved. T6's independent-review requirement is intact.
- **STATE facts spot-checked against ticket 16 / archive:** 72/72 at 03:53 EDT, "73 was a counting
  error", 27 UI gate, 4/4 + 1/1 after fixes, 22 invalid-frame warnings, profile to
  2026-09-24 07:16 UTC, export schema 9, 18 sets moved, 2026-09-04 backup, UDID/team/bundle ID.
  All supported.
- **Superseded items correctly not revived:** chart preset pooling (fixed 2026-09-03), template
  caption (kept 09-11), rest-bar AXL wrap (ticket 16), app icon (shipped in redesign ticket 09 —
  the archive's "none exists" line is older), the `ui-redesign-codex` worktree and
  `finish-graph-and-plain-numbers` pointer (both already gone: `git worktree list`, `git branch -a`).

## Open-work reconciliation (archive → STATE table)

Present and linked: ticket-16 reaction and next screen / App Store; scanner gym report, Ask AI
key entry, bigger box; ROC-IT alias, generic-word floor, tickets 04/07, "read the matcher reviews";
model-less machine picker; delete/restore feedback; bar-mode questions, preset chips, export over
real history; real HR graph density; plate math / stack increments; superset reorder, History
grouping, weak D48 test; drag UI test, load-type catalog audit; `Format.weight` 62.25 → 62.3;
`LegacyStore.store` at `5239ef2`; DOB toggle, revised zones unseen, recovery-vs-cap sound,
background early recovery; watch free test, pair/stream/mirror/wake; catalog gaps; Developer
Program, privacy/usage strings/export compliance, collaborator → D5/T6; CI hang deferred; JSON
restore (DECISIONS:81). Gaps are F3 below.

## Findings

### F1 — P2 — STATE claims a remote launch that no record supports
`docs/STATE.md:40` says `0b6515f` was "installed **and remotely launched** 2026-09-17 03:17 EDT".
The archived handoff (archive:5-10, :36-40), ticket 16 (`16-active-workout-second-pass.md:3`) and
the last eight commit messages say only *installed*; "launch" appears nowhere in ticket 16 or its
two Codex reviews. Earlier installs recorded launch separately each time, and twice recorded a
refusal (phone locked). This is a claim introduced by condensation, and it breaks the rule the
same change adds (AGENTS:11-12; DEVELOPMENT:102-104: "A successful install does not establish
successful launch"). Fix: say "installed 03:17 EDT; launch not recorded — the user opens it", unless
Codex has evidence, in which case cite it in ticket 16.

### F2 — P2 — The repo's most repeated defect rule is no longer in any current document
The archive calls the absence-of-a-caller / contract-vs-caller family "the single most reliable
defect shape here" — nine instances, found by review and by the user, never by tests — with three
standing instructions: grep for uncalled internal funcs and re-read doc comments against callers
before closing (archive:421-428, :701-707); when a feature is gated on a setting, assert the
setting is reachable (archive:608-612); for mirror/watch code assert the message is *sent*
(archive:830-831). The only survivor is half a sentence scoped to background alarms
(DEVELOPMENT:162). The ticket's acceptance says existing verification rules survive
(01-codex-workflow.md:12). With Codex now implementing and Claude reviewing, this belongs in
AGENTS "Workflow and verification" as one or two lines (it is a review rule, not a runbook step).

### F3 — P3 — Open-work rows that lost items
- `docs/STATE.md:63` (real history / summary): the archive's unseen-by-anyone list also had the
  moved session's "Reclassified from …" line, the History calendar, and naming a workout
  (archive:382-385). Add them, or add the archive anchor as a second link on that row — the
  milestone-9 folder it links to does not record that these are still unseen.
- `docs/STATE.md:43`: the archive's standing instruction "Re-export after any session worth
  keeping" and "that phone holds the only copy of the training history" (archive:653, :662-663)
  was reduced to a date. The last reported backup is 13 days and several sessions old; a short
  "stale — ask for a fresh export before any risky install" keeps the intent. DEVELOPMENT:85-87
  covers only schema/history migrations.

### F4 — P3 — Reusable lessons that the ticket says moved to DEVELOPMENT but did not
The preservation map (01-codex-workflow.md:60-61) says reusable gotchas are in DEVELOPMENT. These
are in the archive only (archive:429-446): a captured enum in a SwiftData `#Predicate` is a
*launch crash*; a data migration needs a per-launch idempotent gate, not a one-shot version gate
(the rationale is in D51, the rule is nowhere current); reusing an export column is a silent format
change — append; a test green in the full suite can be order-dependent. The first three touch the
user's real store and the backup format, which AGENTS:63-64 treats as the high-care area. Four
bullets in DEVELOPMENT would close it. Not lost — only undiscoverable without reading the archive.

### F5 — P3 — Rules from the old CLAUDE.md with no current home
- "Commits must not break `xcodebuild build`" (base CLAUDE.md, Workflow) — dropped.
- The remote (`github.com/ericlee4992/workout-tracker`, private) was named in the old CLAUDE.md
  issue-tracker section; `docs/agents/issue-tracker.md` does not carry it. Recoverable from
  `git remote -v`, so minor.
- The old CLAUDE.md itself is preserved only in Git history, not in `docs/archive/`. Acceptable
  (archive README:15 says Git retains earlier revisions), but one row in the archive table naming
  `git show 9b9feef:CLAUDE.md` would make that preservation explicit, which is what the user asked for.

### F6 — P3 — Document-ownership ambiguities
- Mid-run test identity: AGENTS:26-27 puts a running task's process identity and log/result paths
  in **STATE**; DEVELOPMENT:37-38 puts the script, PID, commit, log and result path in the
  **ticket**. Pick one (suggest: ticket holds the detail, STATE holds a one-line pointer).
- `README.md:66` still lists `docs/` as SPEC, DECISIONS and STATE ("where the project is right
  now") — no DEVELOPMENT or archive, and the layout table has no AGENTS row, although README:71 now
  points at AGENTS. Human-facing only.
- Pointers that now resolve only indirectly, left alone because this ticket forbids code/CI
  changes: `.github/workflows/tests.yml:64` cites CLAUDE.md for `WT-iPhone` (now DEVELOPMENT:26-29);
  four Swift comments cite CLAUDE.md for the Domain rule (now AGENTS:35-36, still reached through
  the import). Record as a follow-up rather than fixing here.

### F7 — P3 — Codex skill discovery is asserted, not evidenced
The ticket records the symlink (01-codex-workflow.md:31-32) but no observation of Codex listing
`ios-design`. Every other folder under `.agents/skills/` carries `agents/openai.yaml`; this one
does not. AGENTS:70-73 gives Codex the path explicitly, so the skill is reachable either way, but
the acceptance item is "Codex discovery". Check it in a fresh Codex session and write the result
into the ticket, as was done for the 872K footer. Also commit the link as a symlink (mode 120000)
and confirm `git ls-files -s` shows that after staging.

## Notes, no action required

- The 872K verification is display/loading only, and the ticket says so (01-codex-workflow.md:48-49). Accurate.
- Ticket status "validation and independent Claude review pending" (01-codex-workflow.md:3, :70-71)
  is accurate as of this review; update it with the fixes and a re-review of F1/F2.
- The old per-ticket Orca review recipe (archive:195-198, :331-334) is archive-only; with roles
  reversed DEVELOPMENT:156-157 is a sufficient pointer.
- All work is uncommitted at `9b9feef`. AGENTS:54 expects a branch commit and push before the
  fast-forward; the author does that after re-review, not this reviewer.

## To clear

Fix F1 and F2; address or explicitly decline F3–F7 in the ticket; then request a re-review of the
changed lines.
