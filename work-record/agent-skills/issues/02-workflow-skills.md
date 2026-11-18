# 02 — Project skills for the release and the review round

Status: **in review** (branch `ericlee4992/workflow-skills` off `main` `d02d414d`).
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
