# Addendum to Claude final review — C1 / U1 / U2 follow-up

Reviewed: **9b0a61a** (`ericlee4992/ai-gym-and-routines`) against my cleared tip 2daaa2b, on review
branch `ericlee4992/review-ai-gym-polish`. The [final review](claude-final-review.md) stays
authoritative for all untouched code, captures and accepted private-trial limitations. No build,
test or simulator job was run here; no source changed.

## Code — CLEAR

The product diff is exactly the three recommended items and nothing else
(`WorkoutTemplates.swift`, `IdentifyEquipmentSheet.swift`, `AIRoutineSheet.swift`, one test).

- **C1 resolved.** `machine = remembered ?? (compatible.count == 1 ? compatible.first : nil)`
  (`WorkoutTemplates.swift:168-169`). The remembered machine is already restricted to active
  machines by `rememberedMachine`, so archived equipment cannot return. The extended test is
  discriminating: after `Press B`'s links are emptied, the only link-compatible machine is
  `Press A`, so the old code would have chosen A; the assertion requires the remembered B. Unique,
  ambiguous (unassigned) and remembered cases remain asserted. D58 and the spec now say
  "remembered active machine, otherwise the sole compatible active machine".
- **U1 resolved in code.** Name / Manufacturer / Model captions sit above each wrapping field; the
  label field keeps its `identifiedMachineLabel` identifier, focus binding and `labelWasEdited`
  setter, so the edited-label behaviour and its UI test selector are unchanged.
- **U2 resolved.** Singular "exercise" when the count is 1.

No new findings. Round-2/final lows and C2 (38 movement-named seeded models resolve model-less via
the AI path — still worth one sentence in D56) are unchanged.

## Evidence read

`polish-units`: exit 0, log "30 tests in 2 suites passed", TEST SUCCEEDED. `device-polish`: exit 0,
BUILD SUCCEEDED. Both read from the feature checkout's results directory.

## Pending — evidence/UI clearance for this delta NOT yet given

`polish-ui` (13 targeted cases) was still running when this was written. To close, I need the
completed capture commit plus, read from artifacts: `polish-ui` exit file, log TEST line and
xcresult summary; and updated Default + AccessibilityL PNGs for exactly these changed states —
proposal generic, catalog match, new model and ambiguous (captions visible, long model text still
wrapping, action buttons still reachable at AXL), and week preview showing "1 exercise". All other
captures from the final review stand. The private-trial merge clearance in the final review
applies to 2daaa2b; it extends to 9b0a61a once the items above are confirmed. Phone install remains
outside clearance.

## Final evidence update — ad03de9 (appended)

Reviewed on branch `ericlee4992/review-ai-gym-polish-evidence`, cut from **ad03de9**. The diff
9b0a61a → ad03de9 touches **no product, test or project file** — only screenshots, gallery and
records — so the code clearance above carries over unchanged. No build/test/simulator job was run
and no source was edited; artifacts were read directly.

**Evidence read.** `polish-ui-exit.txt` = 0; log "Executed 13 tests, with 0 failures", TEST
SUCCEEDED; xcresult summary Passed, 13 / 13, 0 failed, 0 skipped. `polish-units` 30/30 exit 0 and
`device-polish` BUILD SUCCEEDED exit 0 as recorded earlier. (`polish-ui` started ~90 s before
9b0a61a was committed, i.e. on the same working tree; the captures themselves show the new captions
and singular wording, so the run exercised the reviewed code.)

**Captures inspected (actual PNGs, Default and AccessibilityL).** Proposal generic, catalog match,
new model and ambiguous now show visible **Name / Manufacturer / Model** captions above each
field; the long model name still wraps to two lines at AXL with nothing truncated; resolution
footers unchanged; the scrolled action captures show "Use this equipment" and "Take another photo"
reachable at AXL in the specific, new-model, ambiguous and uncertain states. Week preview reads
"1 exercise · 1 cardio" at both sizes. U1 and U2 are closed. Gallery now holds 54 PNGs; captures I
did not re-open retain the final review's clearance.

**Records.** D56 (DECISIONS line 142) states the movement-only seeded-name consequence (C2);
ticket 05 records U3–U5 and G1–G2 as accepted non-blocking follow-ups; D58/spec describe the
remembered-machine-first rule.

One note, non-blocking: the regenerated `ai-planned-cardio-axl.png` is partly covered by the
system Motion & Fitness permission alert, so it no longer shows the planned-cardio Start row
cleanly. The clean AXL capture of that state exists at 2daaa2b and the code for that row is
unchanged, so my clearance of that state stands; restore or re-take the clean image when convenient
(record it with U3).

### Final verdict

| Area | Verdict at ad03de9 (product 9b0a61a) |
|---|---|
| Code | **CLEAR** |
| Test/build evidence | **CLEAR** |
| UI captures | **CLEAR for private trial** |
| **Private-trial merge to `main`** | **CLEARED** — `git merge --ff-only`, push, confirm the remote tip, watch post-merge CI (full unit suite) |
| Phone install | **Not cleared** — needs the user's confirmation that the installed build opens with history intact, a fresh backup, and valid signing (expires 2026-09-24 07:16 UTC) |
| Recognition accuracy / public release | **Not claimed, not cleared** — fallible private-trial limitation; backend required before any other user |

No open blocking findings from the spec review, round 1, round 2, the final review or this addendum.
