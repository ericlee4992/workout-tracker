# Codex cross-review round 2 — photo machine capture

Verdict: **do not merge**.

The round-1 gate stops the named NEWCO/MATRIX/Atlantis failures from being preselected, and the numeric identity, ambiguity, fuzzy-reuse, determinism, orientation, CI-image, create-new ordering, and module-placement fixes are real. But the asymmetric one-character rule introduced a new D23/D33 failure: a clean reading of four shipped rows preselects the wrong seeded UUID. The implementation also does not honor D33's “and no other known manufacturer” clause, and unknown hardware still does not lead with create-new as the ticket claims.

## Full-catalog replay

Scores below are from the current scorer against all 1,877 rows in `SeedCatalog.json`. “Preselected” means `CatalogMatcher.preselection(from:)`, not merely rank 1.

| Reading | First and runner-up | Preselected? |
|---|---|---|
| `NEWCO / PENDULUM SQUAT` | Nautilus Pendulum Squat **0.7601**; Watson PL Pendulum Squat **0.5858** | **No.** The wrong UUID is gated, but 0.7601 is above the 0.35 create-new threshold. |
| `MATRIX / PENDULUM SQUAT` | Matrix MG-PL80 Pendulum Squat **0.6544**; Nautilus Pendulum Squat **0.4941** (conflict) | **No.** |
| `ATLANTIS STRENGTH / PLATE LOADED BELT SQUAT / C-227` | Hammer Strength Plate Loaded Belt Squat **0.4706** (conflict); Atlantis D-227 Glute & Ham **0.4285** | **No.** Again, candidates rather than create-new lead. |
| `NAUTILUS / 5 STATION` | Nautilus 5 Station **1.0000**; Nautilus 4 Station **0.5420** | **Yes, correct.** |
| `ROGUE FITNESS / R-6 POWER RACK` | Rogue R-6 **0.7994**; Rogue R-4 **0.5427** | **No.** The digit distinguishes the rows, but the dropped `R` keeps the exact row below 0.85. `R 6` produces the same result. |
| `PRIME FITNESS / PRODIGY HLP SELECTORIZED RACK 2:1` | PRIME 2:1 **1.0000**; PRIME 4:1 **0.8647** | **Yes, correct** (gap 0.1353). |
| `LIFE FITNESS / INSIGNIA SERIES BACK EXTENSION` | Insignia Back Extension **1.0000**; plain Back Extension **0.8801** | **Yes, correct** (gap 0.1199). |
| two-machine Insignia Chest + Shoulder Press | Shoulder **0.9566**; Chest **0.9500** | **No** (gap 0.0066). |
| `LIFE FITNESS / INSIGNIA SERIES HIP ABDUCTION` | Abduction/Adduction combo **0.8539**; Adduction-only **0.7370** | **Yes, the combo row.** The adduction-only row no longer ties or preselects. |

### Clean-reading recall

- A clean reading of the **model name only** correctly preselects **0/1,877 (0%)**, by construction: `manufacturerMatched` is false even when the correct row is rank 1 and scores 0.90. A worn, cropped, or frame-only brand therefore always costs the convenience.
- A clean reading of the full **canonical manufacturer + exact model name** correctly preselects **1,788/1,877 (95.26%)**. Eighty-five get no preselection (65 margin failures, 20 score failures), and four preselect the wrong UUID.
- Brand spelling is exact rather than alias-aware. `ROGUE / R-6 POWER RACK` ranks the right row at **0.6994** but cannot preselect; `PRIME / ... 2:1` ranks the right row at **0.9000** but cannot preselect because `Fitness` is absent.

The manual fallback is safe and understandable: the row remains visible, the footer says nothing was picked, and the user can tap it and then `Use This`. I would accept that conservative two-tap fallback for genuinely missing brand evidence. I would not call the current trade calibrated, however: many real plates use a logo/short brand or omit the brand, and there are no real-photo measurements. At minimum, the product should explicitly accept 0% preselection in the brand-absent case and define tested aliases such as `ROGUE` and `PRIME`.

## Critical

### 1. Photo-side lone-letter deletion preselects four wrong seeded UUIDs on pristine labels

- **File/line:** `WorkoutTracker/Domain/MachineLabelText.swift:66-82`; `WorkoutTracker/Domain/CatalogMatcher.swift:86-116,235-258`; `WorkoutTrackerTests/CatalogMatcherAdversarialTests.swift:92-108`
- **Evidence:** the catalog keeps lone letters and charges their high IDF in `nameWeight`, while every photo discards them. Against the shipped corpus:
  - `HAMMER STRENGTH / ISO-LATERAL D.Y. ROW` preselects **Iso-Lateral Row 1.0000**. The correct D.Y. row is not even in the top six.
  - `HAMMER STRENGTH / ISO-LATERAL T-BAR ROW` preselects **Iso-Lateral Row 0.9290** over the correct T-Bar row **0.8477** (gap 0.0813, just over the gate).
  - `SORINEX / BASE CAMP RACK & A HALF` preselects **Base Camp Half Rack 1.0000** over the correct Rack & A Half **0.8661**.
  - `SORINEX / XL SERIES RACK & A HALF` preselects **XL Series Half Rack 1.0000** over the correct Rack & a Half **0.8512**.
- There are **88** seeded model names with lone alphabetic tokens. This is not just code-letter trivia: deleting the ordinary word `a` changes identity. A lone `s` in Hoist's `CMJ-6600-S` lowers the clean score to 0.8959; `R` lowers Rogue R-6 to 0.7994. The collision test proves only that two rows' **catalog** token bags differ; it never asks whether their photo representation can still reach them.
- **Smallest fix:** tokenize identity-bearing letter/code components symmetrically. Preserve lone letters when they are part of a hyphenated/dotted code (`R-6`, `D.Y.`, `-S`) and preserve catalog words such as `A` when dropping them would make two candidate identities collapse. Add a full-catalog invariant that feeds each canonical manufacturer/model through `readingTokens`, requires its own UUID to be rank 1, and forbids any wrong preselection.

## High

### 2. `manufacturerConflicts` allows an additional known brand through D33's gate

- **File/line:** `WorkoutTracker/Domain/CatalogMatcher.swift:133-138,179,260-270`; `docs/DECISIONS.md:41`
- **Evidence:** `conflicts` is true only when the named-manufacturer set does **not contain the row's own maker**. If the plate names both the row's maker and another maker, it is false. `LIFE FITNESS / INSIGNIA SERIES CHEST PRESS / MATRIX` names both manufacturers yet preselects the Life Fitness row at **0.9587** with `manufacturerConflicts == false`. D33 says the plate must name the row's manufacturer **and no other known one**. The brand guess has the same ambiguity on a top line: `knownBrand` returns its first longest match rather than rejecting multiple brands.
- No clean seeded manufacturer/model string incidentally names a second seeded manufacturer today (**0/1,877**), but the flat whole-photo bag is vulnerable to common single-token brands such as `Matrix` and `Hoist`, neighboring machines, and user-created manufacturer names. `Life` or `Titan` alone do not trigger today because their catalog manufacturers require the full two-token name.
- The 0.6 multiplier cannot itself pass the 0.85 gate: a correctly flagged conflicting row is capped at 0.6, and `preselection` rejects it anyway. Its practical effect is ranking/create-new suppression. A single incidental `Matrix`/`Hoist` with the true brand absent can therefore suppress the right row even though it is not identity evidence.
- **Smallest fix:** define conflict as `namedManufacturers` containing **any** maker other than `entry.manufacturer`; only accept/guess a brand when it is unique in the appropriate brand line. Add same-line and separate-line two-brand tests plus incidental-common-word tests.

### 3. Unknown hardware is no longer preselected, but still fails the create-new requirement

- **File/line:** `WorkoutTracker/Domain/CatalogMatcher.swift:146-150,212-215`; `WorkoutTracker/Features/Gyms/ScanMachineLabelSheet.swift:106-123`; `WorkoutTrackerTests/CatalogMatcherAdversarialTests.swift:40-71`
- **Evidence:** NEWCO's wrong Nautilus row scores 0.7601 and Atlantis's wrong Hammer row 0.4706, so `suggestsCreatingNew` is false for both. This contradicts issue 01's acceptance criterion that absent hardware score below the create-new floor and the spec's statement that the create-new action leads below 0.35. `unlistedHardwareLeadsToCreateNew` checks only `preselection == nil`; its name claims a behavior it never asserts.
- **Smallest fix:** make create-new recommendation a separately gated decision (unknown/conflicting brand and insufficient same-maker evidence should be strong signals), then assert `suggestsCreatingNew` for every full-catalog negative named in this review. Do not try to solve it only by raising the global 0.35 score floor.

### 4. Substring junk rules classify 73 real seeded model names as plate furniture

- **File/line:** `WorkoutTracker/Domain/MachineLabelText.swift:88-112,167-180`; `WorkoutTracker/Domain/CatalogMatcher.swift:170-178`
- **Evidence:** `normalized.contains` makes `min` match every `Abdominal` (57 rows), `rev` match `Reverse` (13), `max` match Gym80 Basic Max Rack, and `weight stack` match Rogue's two Weight Stack Slingers. `guessModelName` then has no usable model line and can fall back to the entire multiline reading, including the manufacturer. In scoring, the same line is removed from the “plate evidence” denominator, defeating the new bidirectional-explanation term and potentially inflating generic subsets.
- **Smallest fix:** match junk words/phrases at token boundaries and distinguish actual rating/warning patterns from model names. Assert that every shipped manufacturer/model line is non-junk, then add representative `Abdominal`, `Reverse`, `Max`, and `Weight Stack Slinger` guess/scoring tests.

## Medium

### 5. Greedy fuzzy consumption is deterministic but not a maximum one-to-one assignment

- **File/line:** `WorkoutTracker/Domain/CatalogMatcher.swift:235-249,288-309`
- **Evidence:** weight-descending iteration can consume a reading token needed by a less flexible later token. For example, with a higher-weight catalog token `cart`, lower-weight `bark`, and unseen OCR tokens `bart cars`, `cart` chooses lexical `bart` although it could use `cars`; `bark` can use only `bart`, so greedy covers one token where a valid one-to-one assignment covers both. If the early token is a manufacturer token, it can steal evidence without contributing name coverage. I did not find this in the required shipped replays, but the algorithmic hole is real and scores can change with it.
- **Smallest fix:** reserve exact matches first, then compute the small per-row maximum-weight bipartite assignment for fuzzy edges (including coverage/explanation value and a stable tie-break). Add the flexible-token/constrained-token regression.

### 6. Capture availability still loses the promised explanation on important transitions

- **File/line:** `WorkoutTracker/Features/Gyms/ImagePicker.swift:11-40`; `WorkoutTracker/Features/Gyms/ScanMachineLabelSheet.swift:69-79,188-205,214-244`
- **Evidence:** if `.notDetermined` becomes denied while the picker is being presented, a nil picker callback dismisses the whole scan sheet instead of re-resolving authorization and showing Settings/photos/manual actions. With no camera, the library is immediately presented over the reason; canceling it also dismisses the scanner before the reason is seen. On the denied screen, `Try the camera again` calls `preferred`, which opens the photo library while still labeled as a camera retry. `.restricted` is folded into `.cameraDenied` and offers Settings even when policy cannot be changed there.
- **Smallest fix:** re-resolve availability after a nil/cancel callback; keep the sheet open on the explicit availability screen; label actions by what they actually open; distinguish denied from restricted if Settings is not a remedy. Add state/transition tests for authorized, not-determined→denied, denied, restricted, and no-camera.

### 7. The new tests still prove less than the resolution notes claim

- **File/line:** `WorkoutTrackerTests/CatalogMatcherAdversarialTests.swift:40-108`; `WorkoutTrackerTests/MachineLabelOCRTests.swift:122-153`; `WorkoutTrackerUITests/ScanMachineLabelUITests.swift:24-102`; `.scratch/photo-machine-capture/issues/03-verification.md:32-40`
- **Evidence:** there are no full-catalog scoring assertions for Rogue R-6 or PRIME 2:1; the identity invariant uses catalog-side tokens and misses finding 1; unknown-hardware tests do not assert create-new ordering; the OCR tests cover only `.left` plus CI backing, not right/upside-down/mirrors or a representative scuffed/glare/angled fixture; and create-new UI verification stops at prefilled fields without saving/linking the user model or proving `isSeeded == false`. The round-1 UI relationship assertion is improved and does prove the saved machine's model subtitle.
- **Smallest fix:** add the corpus self-reading/wrong-preselection invariant and explicit replay scores/gates, complete the orientation matrix, keep a small transformed/real plate fixture set, and finish the create-new path through exercise selection, model save, machine save, relaunch/store verification, and `isSeeded == false`.

## Low

### 8. Documentation/test-count drift and non-blocking design smells remain

- **File/line:** `docs/STATE.md:19-22`; `.scratch/photo-machine-capture/issues/03-verification.md:23-40`; `WorkoutTracker/Features/Gyms/ScanMachineLabelSheet.swift:302-330`
- `STATE.md` still says 272 unit tests while issue 03 says 284 after the fixes. Ticket 03 asks for one XCUITest with a cheap second assertion, but the implementation uses two test methods, hence two launches and two full Vision scans.
- Standards review found no documented-standard violation. Judgment calls only: the raw `(UUID, manufacturer, modelName)` tuple is repeated as an unnamed catalog-identity data clump; `ScanMachineLabelSheet.swift` mixes production flow with test fixture artwork; and name-plate rendering is duplicated between that file and `MachineLabelOCRTests.swift`.
- **Smallest fix:** reconcile the recorded counts/verification wording; use a named matcher input type; move and share the fixture renderer when next touched.

## Round-1 finding status

| Round-1 finding | Round-2 status |
|---|---|
| 1. Unknown/conflicting brands preselect rival short-name rows | **Partially closed.** The named wrong UUIDs are no longer preselected. The promised create-new-floor behavior is not closed (finding 3 above), and manufacturer conflict has a multi-brand hole (finding 2). |
| 2. Single-character identity deletion | **Not closed.** Digits now distinguish Nautilus and PRIME, but asymmetric letter deletion creates four clean-input wrong preselection failures and makes Rogue R-6 a false negative. |
| 3. Subset/two-station 1.00 ties, no ambiguity gate | **Closed for the reported cases.** Insignia beats plain Back Extension by 0.1199; the two-station photo has only 0.0066 separation and is not preselected. |
| 4. Reusing one OCR token for multiple catalog tokens | **Closed for the reported case.** Hip Adduction no longer ties. Greedy assignment still has the distinct hole in finding 5. |
| 5. Orientation discarded / CIImage rejected | **Closed in implementation.** The direct eight-case UIImage→CG orientation mapping is correct, CI images render through `CIContext`, and redraw fallback is upright. Test coverage remains partial. |
| 6. Permission denied / no camera silently fall through | **Partially closed.** Initial denied state has a reason and routes forward; cancellation and not-determined→denied transitions still fail it. |
| 7. Hash-seed nondeterminism | **Closed.** Reductions, candidate iteration, and tie-breaks are sorted; forward/reversed corpus tests agree. |
| 8. Create-new action did not lead | **Closed in the UI** when `suggestsCreatingNew` is true. Calibration prevents the important unknown cases from reaching that state. |
| 9. Brand guessing searched the whole flattened photo | **Closed for the original incidental-rest-of-photo bug.** It checks the first usable line first and requires uniqueness elsewhere; multiple brands on the first line remain ambiguous but are not rejected. |
| 10. Tests proved only happy paths | **Partially closed.** Full-catalog adversarial, rotated/CI, and persisted-relationship coverage improved; finding 7 lists the remaining overclaims. |
| 11. Spec said 0.75 while code/D33 said 0.85 | **Closed.** The feature spec now says 0.85. |
| 12. Vision adapter lived in Domain | **Closed.** It is under `Features/Gyms`; Domain remains Foundation-only pure logic. |

## Review axes

### Standards

No hard CLAUDE.md violation was found. The domain/UI placement, no-third-party rule, and generated-Info.plist project edits conform. The three low-severity smells recorded in finding 8 are judgment calls, not merge blockers.

### Spec

The blocking spec failures are: wrong UUID preselection from photo/catalog token asymmetry; D33's “no other known manufacturer” gate not implemented; and absent hardware not producing the specified create-new lead. Junk parsing, availability transitions, and verification claims are partial implementations. No material scope creep was found.

## Verification note

`git diff --check` passes. I replayed the scorer independently from the current source against `SeedCatalog.json`, including the full 1,877-row clean-reading sweep. An Xcode build/test run could not complete in this sandbox because CoreSimulatorService has no available simulator runtimes; with derived data redirected to `/tmp`, compilation began but asset-catalog compilation failed on that same runtime outage. No source code was changed.
