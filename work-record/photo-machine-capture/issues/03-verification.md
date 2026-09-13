# 03 — Verification and documentation

Status: resolved
Blocked by: 01, 02

## Acceptance criteria

- [x] One XCUITest: New Machine → Scan label… → (fixture image) → the right catalog model is
      preselected → Use This → the machine saves with that model attached. One test; the UI suite
      already runs ~7.5 minutes.
- [x] A second, cheap assertion in the same test: "None of these — create new" reaches the New
      Model sheet with the manufacturer and model fields prefilled.
- [x] `docs/DECISIONS.md`: D33 (a scan proposes, the user confirms), D34 (photos are read and
      discarded), D35 (unmatched scans create user-space models, never seeded-looking rows).
- [x] `docs/SPEC.md`: the taxonomy/recording sections say scanning exists and what it can and
      cannot identify.
- [x] `docs/STATE.md`: status, test counts, and the camera-permission gotcha (a missing usage
      string is a crash, not a prompt).
- [x] Full suite green, re-run independently.
- [x] Codex cross-review (T6) before merge, with the review prompt aimed at the matcher's failure
      modes — a wrong-but-confident match is the defect that matters here.

## Resolution (2026-08-11)

`WorkoutTrackerUITests/ScanMachineLabelUITests.swift` — two tests: scan → confident row
preselected → Use This → machine saved under the scanned name; and scan → create-new → New Model
sheet prefilled with "Life Fitness" / "Insignia Series Chest Press".

Decisions D33–D35 recorded; SPEC taxonomy notes scanning and what it cannot identify.
Suite: **272 unit + 12 UI tests**.

## Codex cross-review round 1 (2026-08-11)

Verdict "do not merge" — four critical matcher defects, all real, all fixed (see tickets 01/02).
Test gaps the review named are closed: `CatalogMatcherAdversarialTests` runs the negatives against
the shipped catalog instead of a six-row fixture, `MachineLabelOCRTests` covers rotated and
`CIImage`-backed photos, and the UI test now asserts the persisted machine→model *relationship*
(the row subtitle is `machine.model?.displayName`), not just the defaulted label.

Suite after the fixes: **284 unit + 12 UI tests**.

## Codex cross-review round 2 (2026-08-11)

Verdict "do not merge"; one critical (photo-side token asymmetry), three high, three medium — all
addressed. Test claims tightened where the review said they overreached:

- full-catalog **self-recognition invariant** (sampled every 13th row) — rank 1 and no wrong
  preselection, the check that would have caught both rounds' identity defects;
- explicit shipped-catalog assertions for Rogue `R-6`, PRIME `2:1`, Hoist `CMJ-6600-S`, Sorinex
  `Rack & A Half`, two-brand plates, and create-new leading for NEWCO and Atlantis;
- every shipped name asserted **not** to read as plate furniture;
- orientation matrix extended to upside-down, plus `CIImage`-backed photos;
- the create-new UI path now runs to completion — link an exercise, save the model, save the
  machine — and proves the result is user-space by asserting `Rename Model…` is offered, which
  only appears for `isSeeded == false`.

Two test methods rather than the one the ticket asked for: the accept path and the create-new path
each need their own launch, and folding them into one test would make a failure in the first hide
the second. ~60s of UI time for the pair.

Suite: **296 unit + 12 UI tests**.
