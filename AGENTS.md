# Workout Tracker — agent guide

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

Keep STATE as a short current handoff. Update existing facts instead of prepending another
session transcript. At meaningful checkpoints and before ending a session, record the exact
branch/commit, completed and remaining work, user decisions, verification scope/results, and
next action. For a running task, put its process identity and log/result paths in the ticket
and link it from STATE. Put detailed progress in the ticket and stable decisions in DECISIONS.
Preserve old handoffs in the archive when shortening STATE; keep every unresolved item in
STATE or an explicitly linked record.
Use one session per coherent task; checkpoint before starting a fresh session for another task.

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

- Codex is the default implementer; Claude independently reviews (T6). If Claude implements,
  Codex reviews. The author does not supply the independent clearance. Give the reviewer the
  ticket, diff, relevant decisions, and evidence; resolve findings and re-review fixes.
- Use short-lived branches off `main`. When agents are active simultaneously, use separate
  checkouts; use `orca-cli` for Orca-managed worktrees and terminals.
- Commit on the branch and push it. Once the required verification and review are clear,
  fast-forward `main` with `git merge --ff-only <branch>` and push `main`. The repository's
  established workflow does not require a PR. Confirm the remote contains the resulting tip.
- Build/test commands and detached-run instructions are in DEVELOPMENT. Run relevant tests
  for code changes; run the full local UI suite before merging screen changes. Inspect the
  actual exit code and result, not another agent's summary. For docs-only changes, check links,
  archive preservation, and consistency rather than rebuilding the app.
- Code commits must preserve a successful `xcodebuild build`. Before closing a feature, check
  internal functions and doc comments against their callers. Verify gated settings are reachable
  and mirrored messages are actually sent; testing only the gate or receiver misses these defects.
- CI runs unit tests on PRs and pushes to `main`; in this no-PR workflow it runs after merge.
  Local verification is the gate. The user deferred the hanging hosted runner investigation.
- Before schema changes or device installation, follow DEVELOPMENT's migration, backup,
  signing, binary freshness, and launch checks. Current phone facts live only in STATE.

## Task-specific guides

- **Screen design, restyling, or review:** read
  [.agents/skills/ios-design/SKILL.md](.agents/skills/ios-design/SKILL.md), including its
  `REFERENCE.md` and `REVIEW.md` as directed. This path links to the single maintained skill in
  `.claude/skills/ios-design/`. Show real default/AccessibilityL captures for UI decisions.
- **Ticket creation or updates:** [issue tracker](docs/agents/issue-tracker.md);
  **triage:** [triage labels](docs/agents/triage-labels.md).
- **Domain terminology or architectural decisions:** [domain guide](docs/agents/domain.md);
  `CONTEXT.md` and `docs/adr/` are created lazily by the domain-modeling workflow.
- **Build/test/install failure:** [DEVELOPMENT](docs/DEVELOPMENT.md), then the relevant ticket
  or archived incident. Read the scanner's prior cross-reviews before changing its matcher.
