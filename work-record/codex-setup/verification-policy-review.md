# Verification-policy review (T6, docs only)

Reviewer: Claude (independent; Codex authored). Written 2026-09-20.
Range `4a7cbc1..ad519c3` (`ericlee4992/verification-policy`, one commit, 9 Markdown files);
[ticket 02](issues/02-verification-policy.md); decision T8.

**Verdict: CLEAR for merge.** No P1/P2. Three P3 record notes for the parent; none blocks.

Scope of this review: diff read in full, `git diff --check`, a scripted relative-link/anchor
check, `rg` sweeps for leftover full-suite directives, symlink/import inspection. Per the
request and the policy itself, no build, test, simulator or device command was run.

## Checks

| Item | Result |
|---|---|
| Single source | AGENTS "Test scope" routes to `docs/DEVELOPMENT.md#verification-scope`; the old "full local UI suite before merging screen changes" sentence is gone. DECISIONS T8, STATE, both specs and the design skill link to the same anchor instead of restating rules. |
| Change classes | Table covers cosmetic UI, logic/units, new feature, shared/broad, docs-only. |
| Escalation | Full UI: major release candidate, broad/uncertain impact not boundable by targeted checks, explicit user request, planned periodic check at a stable checkpoint. Non-triggers named (routine edit, new file, new task, merge, phone install). Reason must be recorded; "no recurring job is implied". Matches the user's approval. |
| No extra permission | "Routine scope selection does not need separate user approval"; implementer selects and records, reviewer judges coverage. |
| Retained safeguards | Build-must-succeed bullet, actual exit codes/results, T6 independent review, schema/migration/backup/signing/binary-freshness/launch bullet all still in AGENTS; DEVELOPMENT's closing paragraph restates them. Install, provisioning and persistence sections unchanged. |
| Design skill | SKILL step 5 and REVIEW item 12 point to the policy; item 12 tells the reviewer to ask for broader tests only for a specific uncovered risk. Default/AccessibilityL captures still required. |
| Current specs | `cardio/spec.md` and `ui-redesign/spec.md` gates now defer to the policy, mark the 2026-09-20 supersession, and keep historical counts as history. |
| Generic skills | `.agents/` has no changes; `skills-lock.json` untouched. Only `implement/SKILL.md:11` ("full test suite once at the end") conflicts, and AGENTS explicitly ranks project policy above generic-skill wording. |
| Links | 65 relative links/anchors across the changed files, `CLAUDE.md` and the symlinked skill paths: 0 broken. Skill links `../../../docs/…` resolve identically via `.agents/skills/ios-design` (symlink → `../../.claude/skills/ios-design`, intact). |
| CLAUDE import | `CLAUDE.md` unchanged: `@AGENTS.md` plus STATE pointer. |
| Archives/history | `docs/archive/` has no diff; no resolved ticket or prior review was edited. |
| Phone/open work | STATE changes are the two header lines and one added tooling bullet. Installed build **8c71d27**, tests **dc08ea8**, UI tip **cda7fd4**, launch-not-verified note, ticket-02 device acceptance, profile expiry all preserved. |
| No code/config/CI | Nothing under `WorkoutTracker*/`, `.github/`, project or scheme files. |
| Facts | "about 51 minutes for 85 tests" matches ticket 06 (`3066s`, 85/85). |

## P3 notes (parent to handle; no re-review needed for these)

1. **Ticket lacks results.** `issues/02-verification-policy.md` lists planned checks and is
   still `Status: claimed`. AGENTS now says to record selected scope *and results*; add the
   outcomes (whitespace clean, link check, this review) and close the status at merge. STATE's
   tooling bullet likewise still describes the branch as pending.
2. **One open older ticket keeps suite wording.**
   `milestone-8-history-and-charts/issues/05-lock-screen.md:25` says "Verify the full suite
   still runs". It is tied to a concrete risk (a new target once broke every XCUITest), so it
   fits the broad-impact escalation and AGENTS precedence covers it; leave as is or annotate
   when that ticket is picked up.
3. **Cosmetic.** `docs/DEVELOPMENT.md:86` was rewrapped to 113 characters; REVIEW.md's intro
   (line 5) still says "gate tests with counts" while item 12 says "named tests/results with a
   scope rationale" — compatible, slightly different wording.

No source files modified; only this report was added.
