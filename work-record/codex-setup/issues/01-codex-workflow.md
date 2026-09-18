# 01 — Codex project workflow and context visibility

Status: resolved — validation passed; independent Claude review clear after two rounds

## Request and acceptance

2026-09-17: the user is switching primary implementation to Codex. They approved the proposed
shared `AGENTS.md`, short Claude pointer, current-only STATE with preserved history, separate
development runbook, Codex discovery of the iOS design skill, and independent Claude review.
They also requested either a one-million or 872K context window and a context-usage status line.

- Both agents reach one shared instruction source. Existing code/data/verification rules survive.
- Old STATE is preserved intact; decisions stay in DECISIONS, progress in existing ticket files,
  unresolved work remains discoverable, and historical instructions cannot masquerade as current.
- Fresh/resumed sessions can recover current scope, decisions, Git state, and verification
  from files without reading the whole transcript. T5/T6 record the workflow change.
- Configure a context window supported by this client, retain compaction headroom, preserve
  unrelated personal settings, and show live context usage in the CLI footer.
- No app code, tests, schema, phone installation, or CI behavior changes.

## Implementation

Branch `ericlee4992/codex-project-setup`, base `9b9feef`, isolated Orca worktree.

- `AGENTS.md` owns shared rules and checkpoint/resume steps; `CLAUDE.md` imports it.
- `docs/archive/STATE-2026-09-17-before-codex-setup.md` is a byte-for-byte snapshot of base STATE.
  `docs/archive/README.md` explains provenance and the historical status of its instructions.
- `docs/STATE.md` retains the latest shipped build, phone/backup facts, next product action, and
  open-work index. `docs/DEVELOPMENT.md` consolidates reusable commands and environment lessons.
- T5 records the document roles; T6 defaults to Codex implementing and Claude reviewing.
  README points to AGENTS. `.agents/skills/ios-design` is a relative symlink to the existing
  `.claude/skills/ios-design` folder; skill contents and historical paths remain unchanged.

## Personal configuration (outside Git)

Installed CLI `0.154.0`; Astra model metadata advertised default 272,000, maximum 872,000,
effective-context percentage 95. Chose the advertised maximum instead of assuming the API's
1.05M model window is available in this client.

`~/.codex/config.toml` now has `model_context_window = 872000` and
`model_auto_compact_token_limit = 780000`. Preserved existing footer items and appended
`context-used`, `context-remaining`, and `context-window-size` to `tui.status_line`.
The threshold is a chosen buffer, not an official model requirement. Configuration backup:
`~/.codex/config.toml.backup-20260917-131441`.

Validation so far: Python 3.11 TOML parsing; structural comparison shows no unrelated config
changes; `codex features list` loaded successfully. A fresh Orca Codex terminal displayed
`Context 0% used · Context 100% left · 872K window`; closed that verification terminal afterward.
This verifies client loading/display, not a synthetic request filling the entire window.
Existing sessions may need a Codex restart to pick up the new defaults.

References: [configuration](https://learn.chatgpt.com/docs/config-file/config-reference),
[AGENTS discovery](https://learn.chatgpt.com/docs/agent-configuration/agents-md),
[CLI footer](https://learn.chatgpt.com/docs/developer-commands?surface=cli).

## Preservation map

- All previous prose and progress: intact archived STATE; prior Git history also retained.
- Stable decisions: existing DECISIONS unchanged except explicit T5/T6 workflow amendments.
- Reusable gotchas: DEVELOPMENT (build/test, UI harness, install, signing, plist, CI, scanner tooling,
  background timing); archived incidents retain exact historical details.
- Outstanding work: STATE's open-work table covers scanner feedback/backlog, model-less picker,
  real-workout/history feedback, plate/stack math, supersets, drag/audit coverage, weight precision,
  migration fixture, heart-rate verification, watch, catalog gaps, release/collaborators, and CI.
- Superseded claims: STATE explicitly identifies fixed chart scoping/rest wrap, accepted template
  caption, and shipped app icon; it does not carry stale signing deadlines forward.

## Validation and review

Passed: byte comparison of STATE and CLAUDE archives against `9b9feef`, local Markdown links
and anchors, skill-symlink targets, and `git diff --check`. STATE archive SHA-256:
`f6ce2d833c2a60f6b7854979ef45ef1e83ad83712bb1367edf3c1a94d0428866`.
`git ls-files -s .agents/skills/ios-design` records mode `120000` (a symlink).
A fresh Codex CLI session's `/skills` → List skills, filtered with `ios`, displayed
`ios-design [Skill] Design, restyle or review a screen of this iPhone app …`.
Claude independently confirmed its startup context loaded the full imported AGENTS text.
App suites are unnecessary for documentation/configuration only.

## Claude round 1 response

[Review](../claude-review.md): two P2 and five P3 findings; no archive loss or config defect.

- F1: removed “remotely” from the install fact. `a49c8d1:docs/STATE.md` (before base `9b9feef`)
  does record “INSTALLED and launched on the phone at 03:17”. STATE now attributes the launch
  to that handoff; ticket 16 records its provenance. No new device verification is claimed.
- F2: restored caller/contract checks, gated-setting reachability, and sent-message assertions
  to AGENTS as general feature-closure rules.
- F3: restored calendar, workout naming, and the “Reclassified from …” feedback items; restored
  the fresh-export instruction and phone-only status of newer history.
- F4: DEVELOPMENT now includes enum predicate crash, idempotent migration gating, export-column
  compatibility, and order-dependent test lessons.
- F5: restored the code-commit build rule and archived original CLAUDE byte-for-byte too.
  Deliberately keep the remote URL discoverable with `git remote -v`, rather than duplicate it
  in instructions; README and the local issue-tracker guide retain their existing roles.
- F6: running-task details have one home in the ticket, linked from STATE; README's layout map
  includes the new docs. Minor follow-up: old CI/Swift comments still cite CLAUDE for build/domain
  rules, which remain reachable through its AGENTS import. Update those pointers when their
  files are next edited; this task changes no source or CI behavior.
- F7: directly verified Codex's skill picker and staged Git symlink mode, as recorded above.

Independent [round-2 re-review](../claude-review-2.md) is **CLEAR**, with no required changes
remaining. Final checks confirmed both archives byte-exact, all checked local links/anchors
valid, the skill discoverable, and only the three intended personal configuration fields
changed. Closing bookkeeping updates STATE to the completed setup and next product action.
The landing commit is discoverable with `git log -- work-record/codex-setup/`.

## 2026-09-18 project skill check

User asked whether Matt Pocock skills are installed in Codex. `skills-lock.json` records 35
entries from `mattpocock/skills`; all 35 corresponding `.agents/skills/<name>/SKILL.md` files
exist. Current Codex skill context includes research, tdd, code-review, grilling and
domain-modeling, among others. Project-local installation; the user-level skills directories
do not contain this collection. No installation or global configuration change was made.
