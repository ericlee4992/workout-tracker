# 02 — Project skills for the release and the review round

Status: **done — Codex clear (round 2), merged into `main`**; branch `ericlee4992/workflow-skills` kept.
Type: task (docs / agent instructions only)

## The user's request (2026-11-18)

After a survey of agent-workflow skills (superpowers, Compound Engineering, Codex-review wrappers — none adopted: each
overlaps and conflicts with AGENTS.md's own workflow), Claude proposed turning the procedures repeated by hand into
project skills. The user: "build the release and review-round skills first" (the Gate S wizard comes later).

## Change

- `.claude/skills/review-round/SKILL.md` — one round of the independent Codex review (T6): self-check → checkpoint →
  brief (file names per round; what a first and a fix-round brief carry; the reviewer's simulator) → send to the one
  Codex agent → wait on the report's `Verdict:` line (no heavy runs meanwhile) → read and record. Each step ends on a
  completion criterion. The rules stay in AGENTS.md and tools-paseo; the skill points at them.
- `.claude/skills/testflight-release/SKILL.md` — every TestFlight upload in ten steps, from the user's choices to their
  App Store Connect steps. It **replaces** DEVELOPMENT's *TestFlight build checklist* (moved, not copied: that section
  is now a pointer), adding what builds 16–17 taught: merge `main` in the home checkout, the uniq check of the build
  number, Gate S before the install (keep the build out of Developer or turn off Automatic Updates), GitHub Tests after.
- Both model-invoked (the agent reaches them on its own: a release request, every review round).
  `.agents/skills/` symlinks so Codex reads the same files.
- Pointers: AGENTS.md (T6 line → review-round; *TestFlight builds* → testflight-release), DEVELOPMENT's checklist
  section, `scripts/testflight.sh`'s header.

## Verification (docs-only: consistency and links, per DEVELOPMENT → Verification scope)

- Every relative link in the two skills, AGENTS.md and DEVELOPMENT.md resolves (script check, 0 broken).
- Nothing of the old checklist is lost: each of its six steps maps to skill steps 1–10 (the export-options details stay
  in `scripts/testflight.sh`, where they live).
- No app code changed; no build or tests needed.

### Codex round 1 — not clear (4 × P2), fixed

[Report](../codex-review-02.md) (links 30/30, anchors 4/4, symlinks, frontmatter, secrets: clean).
1. *The T6 exception* (Codex as implementer, Claude reviews): review-round now names "the reviewer whoever T6 names",
   swaps the roles in that case, and says a reviewer with a brief follows the brief; testflight-release's ready check
   asks for "a clear verdict from its independent reviewer (T6)".
2. *Docs-only evidence*: the self-check's completion criterion records what actually ran for the scope DEVELOPMENT
   selects (tests: counts, exit codes, xcresult; docs: the checks); regression tests for code fixes; the brief's
   "what to run" says docs-only work is checks, no build.
3. *Gate S against the installed build*: step 2 separates the release's stored-format statement from the phone's Gate
   S, which compares against the build installed on the phone (STATE), carries skipped builds' format changes, and
   holds Gate S when the installed build is unknown.
4. *The detached archive checkout*: step 10 returns to the release worktree on the release branch before recording,
   and fast-forwards `main` from the home checkout as in step 7.
Verification: links re-checked (0 broken).

### Codex round 2 — clear

[Report](../codex-review-02b.md): all four findings resolved, no new ones (links 30/30, anchors 4/4, symlinks,
frontmatter, whitespace, secrets clean). Merged into `main` by fast-forward.

## Comments
