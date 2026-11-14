# Stacked (repository name: Workout Tracker) — agent guide

## Start and resume

1. Read [docs/STATE.md](docs/STATE.md) for the current task, next action, installed build,
   and open work. Check the actual branch, HEAD, and working-tree changes before editing.
2. Read the active ticket under `work-record/`. Before changing product behavior, read the
   relevant parts of [SPEC](docs/SPEC.md) and [DECISIONS](docs/DECISIONS.md). Reopen a locked
   decision explicitly when the user changes it; record the reason and affected decisions.
3. After context compaction or a handoff, reread STATE and the active ticket, then verify their
   claims against Git, files, and test artifacts. Distinguish planned, implemented, tested,
   merged, and installed; each needs its own evidence.

## Where information belongs

| Information | Source of truth |
|---|---|
| Durable engineering and session rules | This file; `CLAUDE.md` imports it |
| Current task, next action, live install, unresolved work | [STATE](docs/STATE.md) |
| Product behavior and decision rationale | [SPEC](docs/SPEC.md), [DECISIONS](docs/DECISIONS.md) |
| Acceptance criteria, progress, failed approaches, review findings, test evidence | The relevant ticket and review files in `work-record/` |
| Build, test, install, and troubleshooting procedures | [DEVELOPMENT](docs/DEVELOPMENT.md) |
| Previous handoffs | [Archive index](docs/archive/README.md); historical evidence, not current instructions |
| Public overview: what the app does, its release status, build steps, folder layout | [README](README.md) (and [server/README](server/README.md) for the server) |

The repository is public and its README is the front page: when a ticket changes what the app does, its release
status, the build/test steps or the folder layout, update README (and its screenshots when screens changed visibly)
on the same branch before merging. Keep personal details, tester data and secrets out of it.

Keep STATE as a short current handoff. Update existing facts instead of prepending another
session transcript. **Its top says the newest state:** whenever STATE changes, rewrite the "Updated …" line under the
title and the first RESUME HERE bullets to match, then reread the top of the file before saying STATE is updated (a
stale header after "STATE updated" has happened twice). At meaningful checkpoints and before ending a session, record the exact
branch/commit, completed and remaining work, user decisions, verification scope/results, and
next action. For a running task, put its process identity and log/result paths in the ticket
and link it from STATE. Put detailed progress in the ticket and stable decisions in DECISIONS.
Preserve old handoffs in the archive when shortening STATE; keep every unresolved item in
STATE or an explicitly linked record.
Use one session per coherent task; checkpoint before starting a fresh session for another task.
Checkpoint continuously so any turn can be the session's last: after each ticket's review clears
and before each long build, test run or review, commit and push, then update STATE and the
ticket's handoff (branch map, verified vs. pending, next steps). When the user asks to hand off,
finish that checkpoint and reply with a one-paragraph resume prompt naming the checkout path —
work on a branch in another worktree keeps its STATE there, not in the main checkout.

## Code and data conventions

- Swift 5, SwiftUI, iOS 26+, iPhone portrait; no third-party runtime dependencies.
- `WorkoutTracker/Domain/` holds SwiftData models and pure logic, free of UI imports. Unit-test
  unit math, records, fallback selection, and other domain logic there.
- SwiftData stays CloudKit-compatible: UUID IDs, optional relationships, no `@Attribute(.unique)`.
- Stored weights retain the entered `(value, unit)` plus `normalizedKg`. Display conversions
  are plain numbers (D52); never silently rewrite entered units or values.
- Record/volume calculations respect load type (assisted: lower is better), exclude warmups,
  and use frozen history where the decisions require it. State the consequence in comments
  when violating a rule would split history or lose data.
- Xcode uses filesystem-synchronized buildable folders. Add files beneath the existing source
  or test folder; no `project.pbxproj` registration is needed.

## Workflow and verification

- Claude implements and Codex independently reviews (T6); if Codex implements, Claude reviews. The author does not
  supply the independent clearance. Give the reviewer the ticket, diff, relevant decisions, and evidence; resolve
  findings and re-review fixes.
- **Self-check before every review round.** Reread your own diff as a hostile reviewer for the defect classes Codex
  keeps finding here, fix what you find, then send it:
  - *the wrong record*: a name, snapshot or value looked up from "the first match" instead of the exact entry, set or
    workout it belongs to (D23); two records sharing an identity (same timestamp, same id);
  - *matches that ignore fields*: "same content" or dedupe checks that compare only some fields, so a richer or
    different row matches — and gets changed or deleted;
  - *stale or overridden values*: an older value overwriting a newer one; a derived value (a portion's grams, a
    default) silently replacing what the user edited; state that is not refreshed at a day or week boundary;
  - *state that leaks or is lost*: edits surviving Cancel or a failed save, choices lost on a tab switch, a draft
    (unfrozen) entry read as if frozen or the reverse, a first-use row with no name;
  - *privacy and data safety*: Health or personal data reaching an AI prompt or the server; a safety copy, export or
    delete that misses a field or a relationship;
  - *errors read as absence*: a failed fetch or recovery treated as "nothing there";
  - *screens*: AccessibilityL layouts (stack, never truncate what is needed), Reduce Motion, empty states;
    full-history fetches per row or per render;
  - *claims*: README, ticket and doc comments that say more than the code does; a regression test for each fix.
- **Agent tooling: Paseo** (since 2026-11-11) — follow [tools-paseo](docs/agents/tools-paseo.md) for the Codex
  reviewer, the test progress tab, worktrees and handoff. The Orca setup is kept in
  [tools-orca](docs/agents/tools-orca.md); to switch back, point this line there.
- Keep **one Codex session** for every review round and ticket, visible to the user. Start a new one only when it is
  gone, stuck in an approval/error state, near its context limit, or in another worktree.
- **Checkout layout** (the user, 2026-11-06): the home checkout `…/orca/projects/Health App` stays on
  a clean `main` — update it, work elsewhere. Each task gets its own worktree on a short-lived
  branch off `main`; once that branch is merged and its record written, remove the worktree
  (the branch is kept). `…/workspaces/Health App/release-build` stays as the detached archive
  checkout for TestFlight builds. A session started in the home checkout and given a task hands
  it off: it creates the task's worktree with an agent and a brief, tells the user which
  workspace to open, and stops; reading files and answering questions there are fine. The
  tool-specific steps are in the agent tooling file above.
- Commit on the branch and push it. Once the required verification and review are clear,
  fast-forward `main` with `git merge --ff-only <branch>` and push `main`. The repository's
  established workflow does not require a PR. Confirm the remote contains the resulting tip.
- **Test scope:** follow [DEVELOPMENT — Verification scope](docs/DEVELOPMENT.md#verification-scope).
  Use targeted checks for routine changes; reserve the full UI suite for the escalation cases
  there. This policy governs new work over blanket full-suite instructions in older tickets,
  specs or generic skills. Record the selected scope and results in the ticket. Inspect actual
  exit codes and results, not another agent's summary. Docs-only work uses consistency/link
  checks; device installation alone does not require a full UI run.
- **Named scopes and reporting:** pick the scope as a test plan or named tests per DEVELOPMENT's
  [tiers](docs/DEVELOPMENT.md#tiers-and-test-plans), run `scripts/prepare-test-simulator.sh` first, and end each
  ticket's evidence with its Verified / Not verified / Known flaky block.
- **What the reviewer reruns:** Codex builds and runs the affected unit tests itself every round. It reruns UI tests
  in round 1 (the ticket's focused classes) and later only when a fix changes UI behaviour or UI test code; for a
  docs-only or non-UI fix round it inspects the author's xcresult (exit code, counts, failures) instead of repeating
  the run, and says so in its report.
- Code commits must preserve a successful `xcodebuild build`. Before closing a feature, check
  internal functions and doc comments against their callers. Verify gated settings are reachable
  and mirrored messages are actually sent; testing only the gate or receiver misses these defects.
- **Local verification is the gate.** GitHub CI's Tests workflow runs after each push to `main` but has never passed
  (216 runs since 2026-09, every one failed or hung and was cancelled; checked 2026-11-14). Now the hosted runner's
  toolchain fails to compile the app (first error in `LiveSetRow.swift`) that builds locally on Xcode 27. A red Tests
  run is therefore not news about a change; fixing the runner is open in STATE. The Server workflow passes.
- **TestFlight builds:** follow DEVELOPMENT's [TestFlight build checklist](docs/DEVELOPMENT.md#testflight-build-checklist);
  `scripts/testflight.sh` archives (with its checks) and uploads. Whether to release, the version number, What's New
  and the What to Test note are the user's decisions.
- Before schema changes or device installation, follow DEVELOPMENT's migration, backup,
  signing, binary freshness, and launch checks. Current phone facts live only in STATE.

## Task-specific guides

- **Screen design, restyling, or review:** match the app's current screens — their colours, type,
  controls and patterns — not the ios-design skill (the user, 2026-11-13: it is outdated; it still
  describes the Floodlight look that D67's Soft look replaced). Never cite the skill as a reason for a
  change or a finding. Show real default/AccessibilityL captures for UI decisions. The skill
  ([.agents/skills/ios-design/SKILL.md](.agents/skills/ios-design/SKILL.md)) stays for reference only.
- **SwiftUI or SwiftData code, writing or reviewing:** the vendored `swiftui-pro` and
  `swiftdata-pro` skills apply; these project rules override them. Keep Swift 5 language mode
  and the existing concurrency style. Layout targets iPhone portrait; apply iPad, iPhone Duo and
  resizability advice only when a ticket asks. Keep each relationship's delete rule in
  `Domain/Models.swift` and `Domain/Nutrition.swift`: catalog and context links into history (exercise, preset,
  machine, gym; a saved food behind an entry or a meal item) `.nullify`, so history survives; owned rows (workout →
  entries, cardio, sensor samples; entry → sets; template → items; exercise → presets; food entry → items, photo; saved
  meal → items) `.cascade`. Schema changes follow DEVELOPMENT's migration and backup steps. Fonts, spacing and colour
  come from the app's current screens (above). Report
  modernisation and file splits as separate findings, outside the ticket's diff. Pinned source
  and update steps: [DEVELOPMENT](docs/DEVELOPMENT.md#vendored-agent-skills).
- **Ticket creation or updates:** [issue tracker](docs/agents/issue-tracker.md);
  **triage:** [triage labels](docs/agents/triage-labels.md).
- **Domain terminology or architectural decisions:** [domain guide](docs/agents/domain.md);
  `CONTEXT.md` and `docs/adr/` are created lazily by the domain-modeling workflow.
- **Build/test/install failure:** [DEVELOPMENT](docs/DEVELOPMENT.md), then the relevant ticket
  or archived incident. Read the scanner's prior cross-reviews before changing its matcher.

## Graft usage in this project

Complete Start and resume above before using the generated Graft section. Graft supplies
navigation candidates; SPEC/DECISIONS define behavior and current source/tests establish facts.
Use `rg` for text/file searches, and read enough source and callers to verify a proposed edit.
Static caller maps may be incomplete for SwiftUI, SwiftData macros and dynamic dispatch.
These project rules take precedence over the generated section's reading restrictions and
claims of exactness. Setup, scope and fallback: [DEVELOPMENT](docs/DEVELOPMENT.md#graft-code-navigation).

<!-- graft:start -->
## Graft — repo context graph

This repo is indexed in `graft/`: small linked markdown nodes that explain each
system and carry exact file:line spans, kept in sync with the code through git.

For ANY task here — understanding how something works, finding where code lives,
or scoping a change — get context from the graph before grepping or opening
source files. Re-ask freely (it's cheap) and reuse literal identifiers you
already have (symbol, error string, file name) as the query. New to this repo?
Run `graft map` first — a token-budgeted orientation (dir clusters, hubs,
hotspots), no LLM, no key.

- Run `graft ask "<your question>" --source` → ranked nodes with the relevant
  code spans inlined (each hit's ≤8-line crux by default; `--full` for whole
  definitions when the crux isn't enough). Match the tool to the task shape:
  for understanding or editing, the top node IS the answer — cite its
  `covers:` file:line spans and edit straight from `--source`. For
  exhaustive tasks ("every occurrence / every caller of this pattern"), ranked
  results are top-N, not complete — run `graft grep "<literal>"` instead
  (exhaustive over indexed files, grouped by enclosing symbol), falling back
  to raw `grep -rn` only for unindexed files.
- `graft skeleton <file>` → every definition's signature + span, ~10× cheaper
  than reading the file; use it to skim an API surface.
- `graft callers <symbol>` gives precomputed, exact edges — who calls this.
  Add `--direction out` for what it calls, or `--depth N` to walk
  transitively for the full blast radius. For structural questions, skip
  ranking and use this directly.
- Or browse: `graft/INDEX.md` lists every node; follow the links.
- Monorepos and folders of multiple repos rank fairly across sub-projects —
  hits carry `[scope/]` labels naming which one they're from. Narrow with
  `graft ask "<task>" --in <scope>/` once you know where you're working.

If a returned span is truncated ("+N more lines"), open the file at that exact
range before finalizing. Only open source files when a node genuinely lacks a
needed detail, and then at the exact file:line the node points to — never
re-read whole files.

After big code changes, refresh the graph with `graft build` (deterministic,
no API key, $0).
<!-- graft:end -->
