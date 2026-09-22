# Claude final review — ticket 07 (template visibility and scanning)

Reviewer: Claude (independent, AGENTS T6). Date: 2026-09-22. Status: **CLEAR** — see
"Clearance" at the end. Product code reviewed: **9f733a2**; evidence/docs checkpoint
**dcf445f** on `ericlee4992/ai-template-followup` (remote tip verified). No build, test,
simulator or device action by the reviewer.

Earlier records: [plan review](claude-followup-plan-review.md),
[code review with addenda 1–2](claude-followup-code-review.md).

## What was verified

Read in the implementation checkout: `git log`/`git status`, `git diff 51da414 9f733a2`
(product: `StartWorkoutView.swift` only; test: one `print` line in `assertDrawn`), the
working-tree test diff since 9f733a2 (two capture-only Start cases, no product change),
`results/followup/final-scope.sh` (selected cases), `final-scope.exit`, `final-scope.log`
summary lines and OCR stdout, `final-scope-summary.json`, `ios27-eager-grid.{exit,log}`,
`ios26-smoke.{exit,log}`, `final-build.exit`, `ios27-store-check.txt`, the ticket's evidence
sections, and 20 of the 24 curated PNGs opened as pictures (both members of every changed-screen
pair plus the rich-grid and empty-grid captures).

## Evidence — accepted

| Check | Actual | Reviewer note |
|---|---|---|
| Focused iOS 27 reproduction case (`testAllThreeGeneratedTemplatesInPopulatedListDefault`) | `ios27-eager-grid.exit` **0**; log: 1 passed, `TEST SUCCEEDED` | Run at 02:06 against the working tree that was committed as 9f733a2 at 02:08; the only product file changed in that commit is the one this run exercised, so the evidence transfers. Ticket should state this explicitly. |
| Final iOS 27 selected scope | `final-scope.exit` **0**; xcresult **53 passed / 0 failed / 0 skipped** (42 domain across 3 suites, 11 UI) | Selected list matches the ticket's named scope. The populated-default case is intentionally not repeated here; its evidence is the focused run above. |
| OCR gate | six `Rendered template OCR:` lines with the card titles and exercise text, three for the empty case and three for populated AccessibilityL | Satisfies the "non-empty pixels read" condition from Addendum 2. |
| iOS 26.5 smoke | `ios26-smoke.exit` **0**; 2 passed / 0 failed | Populated grid and default scanner flow; no earlier-runtime regression. |
| Clean simulator build | `clean-build.exit` **0**, `BUILD SUCCEEDED` | Correction from the first draft, which cited the wrong file. |
| Final incremental simulator build | `final-build.exit` **0**, `BUILD SUCCEEDED` | Run after the last product change. |
| Start capture cases (`testEmptyStartScreenDraws{Default,Accessibility}`) | `start-captures-final.exit` **0**; xcresult **2 passed / 0 failed / 0 skipped** | First attempt (`start-captures.exit` 65) failed only on Vision reading "Ask AI" as "Ask Al" at both sizes; the assertion word was changed to "Templates", the full label stays exact-asserted in both scan tests. Retained and documented; accepted. |
| Store integrity for the reproduction | four template names, 24 items | Refutes incomplete save. |
| Runtime warnings | 8 × "Invalid frame dimension" in the final-scope summary | Pre-existing, recorded in STATE as uninvestigated; not introduced here and not claimed resolved. |

Identical byte-for-byte captures (`ai-immediate-template-2/3-default`, `1/2-axl`, the three
`-default-empty`) are expected: one viewport holds several cards and the OCR asserts a
per-card region, so the same screenshot legitimately serves more than one card.

## Captures — reviewed against REVIEW.md

- **Workout, empty fixture, default and AXL** (`followup-start-*`, `followup-start-top-*`, all
  four from the single `start-captures-final` iOS 27 run, reopened at dcf445f): gym card with
  pin and unit chip, twin amber Start capsules (the accepted D54 exception), Templates,
  New Template…, "Ask AI for Templates" as a secondary grey capsule, caption. At AXL the label
  wraps to two whole lines inside the capsule; nothing truncates. The earlier incomplete default
  capture is not in the curated set and is documented in the ticket as rejected evidence.
- **Routine sheet, no gym, default and AXL** (`followup-no-gym-*`): header "Available
  equipment", native Gym picker reading "No gym" with disclosure, "Add Gym…", footnote "Choose
  or add a gym to save scanned machines.", then the toggles. At AXL the picker stacks its value
  under the label. Scan Machine correctly absent.
- **Routine sheet with gym, 0 and 2 machines** (`followup-empty-gym-*`,
  `followup-scanned-equipment-*`): header "Equipment at Routine Gym", picker, Add Gym…, "0/2
  saved machines" in secondary, Scan Machine as a plain tinted row with the viewfinder symbol.
  No accent fill; Generate remains the form's only prominent command. Same fixture at both sizes.
- **Capture** (`followup-capture-*`): "Scan a machine or its label", Take photo, Flash
  (disabled under fixture), Choose a photo instead. Whole at AXL.
- **Proposal** (`followup-proposal-*`): editable Name, footer "Saved as this gym's machine, with
  no model claimed.", exercises, "Use this equipment" as the single amber fill, "Take another
  photo" tinted. Whole at AXL.
- **New Machine** (`followup-machine-editor-*`): label prefilled "Chest press", Catalog model
  None, Scan equipment…, Read label on device, exercise, Default unit, Cancel/Add. Whole at AXL.
- **Rich grid, populated, default** (`ai-immediate-template-1-default`): Day 1, Day 2, Day 3 and
  Whole Body all drawn, equal column widths, New Template… below. Compare with the before
  capture where the first row was blank. **AXL** (`-1-axl`, `-3-axl`): one column, every card
  whole, order preserved.
- **Empty grid, default** (`-default-empty`): three short cards and New Template… in a 2×2.

REVIEW items 1–11: no finding. Item 12: the record is complete once the outstanding list below
is closed. Advisory judgement, unchanged from Addendum 1: uneven cards in a row are centred
rather than top-aligned; that matches the previous grid and is not a change for this ticket.

## Code — final position

- `StartWorkoutView.swift` eager rows: as reviewed in Addendum 1; no change since. Root cause
  stated as nested `LazyVGrid` inside one List row not instantiating first-row cells on iOS 27
  after insertion; the one-variable experiment (layout only) turned the exact case red to green
  with the store contents unchanged. D58's isolated atomic save and duplicate-submit guard are
  untouched.
- Scanning/setup/copy: as reviewed in the code review; F1 resolved by tests in 51da414, F2
  resolved by evidence (no auto-entry retry on either runtime), F3–F5 recorded in the ticket.
- No schema, export or stored-property change; export schema stays 11.

## Outstanding items — all closed at dcf445f

1. `start-captures-final`: exit 0, 2 passed; both Start pairs replaced from that run and
   reopened by the reviewer. Closed.
2. dcf445f commits the two capture-only tests, the PNGs, the gallery, ticket, STATE and the
   archive entry. `git diff 9f733a2 dcf445f -- WorkoutTracker/` is empty, so the product
   evidence transfers; the ticket says so. Remote tip is dcf445f. Closed.
3. Ticket records the focused-run provenance (working tree later committed as 9f733a2, product
   diff limited to `StartWorkoutView.swift`), the origin of every curated Start capture, and
   the earlier 26.5 attempts with their actual failing lines 79 and 131 and what each meant.
   Closed.
4. STATE names branch, product checkpoint 9f733a2, main at 5a894da pending clearance, installed
   product unchanged and this follow-up **not installed**, the September 24 signing expiry, the
   retained invalid-frame warning, and no active build/test job. Closed.

## Clearance

Product **9f733a2** with evidence and documentation checkpoint **dcf445f** is cleared by the
independent reviewer for fast-forward of `main` under the repository's no-PR workflow:
build, selected domain and UI scope, exact reproduction turned green on the affected runtime,
earlier-runtime compatibility smoke, paired default/AccessibilityL captures, decisions
(D56 unchanged, D58 amendment recorded), SPEC and ticket record all consistent with the
reviewed source. Scope note: 42 domain tests and 14 distinct iOS 27 UI cases plus 2 iOS 26.5
cases, all with actual exit 0 and zero failed/skipped; the invalid-frame runtime warning
remains deferred as before.

**Docs-only addendum, 1ff72d1.** Verified `git diff dcf445f 1ff72d1`: ten added lines in
`docs/DEVELOPMENT.md` under "Simulator and UI-test pitfalls", no product or test change, remote
tip 1ff72d1. The two lessons are accurate to the ticket 07 record: match the simulator runtime
to the phone OS (SDK list is not the runtime list; the bug reproduced on iOS 27 and passed on
26.5, and `WT-iPhone27` is now the regression gate), and treat a stalled optional
`simctl diagnose` collection as a separate child process while still requiring the actual
xcodebuild exit and a completed xcresult. Docs-only verification per DEVELOPMENT (links and
consistency) is sufficient. The clearance above extends to fast-forwarding `main` to
**1ff72d1**: product 9f733a2, tested capture code dcf445f, documentation 1ff72d1.

Not covered by this clearance, unchanged from ticket 06: phone installation (which needs the
DEVELOPMENT backup, signing-expiry and fresh-binary checks first), physical recognition
accuracy, cardio hardware checks, and visual history confirmation on the phone. The reviewer
did not merge, push or install.
