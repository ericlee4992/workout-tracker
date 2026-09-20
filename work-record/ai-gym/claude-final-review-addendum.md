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
