# Codex cross-review — photo machine capture

Verdict: **do not merge**. The scorer confidently preselects wrong catalog UUIDs on ordinary labels. That is the D23 history-splitting failure D33 was meant to prevent.

## Critical

### 1. Unknown or correctly branded hardware confidently selects the wrong manufacturer's short-name row

- **File/line:** `WorkoutTracker/Domain/CatalogMatcher.swift:91,117-120,124-157`; `WorkoutTrackerTests/CatalogMatcherTests.swift:132-135`
- **Violates:** D4, D23, D33; ticket 01 “unknown hardware scores below the create-new floor.”
- **Evidence:** Replaying this implementation against the shipped 1,877 rows:
  - `NEWCO PENDULUM SQUAT` → **0.97 Nautilus Pendulum Squat**.
  - `MATRIX PENDULUM SQUAT` → **0.94 Nautilus Pendulum Squat**; the correctly branded `Matrix MG-PL80 Pendulum Squat` is only 0.58.
  - `ATLANTIS STRENGTH / PLATE LOADED BELT SQUAT / C-227` → **0.92 Hammer Strength Plate Loaded Belt Squat**.
  All are preselected. `suggestsCreatingNew` is unreachable when an absent machine shares a complete generic model name with any short catalog row.
- **Cause:** unseen reading tokens have weight zero, model-name recall owns 85% of the score, and a manufacturer match is only an additive 0.10. A conflicting/unknown brand therefore barely matters. IDF over inventory rows is not calibrated evidence: a maker with 246 rows contributes a different brand weight from one with 1, and adding user rows retunes every score.
- **Smallest fix:** make preselection require a non-conflicting recognized manufacturer plus a clear top-vs-runner-up margin; give unseen reading tokens a nonzero/maximal weight. Tune negatives against the full shipped catalog, including known-brand model gaps. Keep IDF fixed to seeded rows or otherwise prove user additions cannot move the thresholds.

### 2. Tokenization deletes real identity fields and makes distinct catalog UUIDs identical

- **File/line:** `WorkoutTracker/Domain/MachineLabelText.swift:66-72`; `WorkoutTracker/Domain/CatalogMatcher.swift:63-69,117`
- **Violates:** D4, D23, D33.
- **Evidence:** single-character tokens are not always noise. Shipped identities depend on them:
  - `NAUTILUS 5 STATION` drops `5`; `4 Station`, `5 Station`, and `9 Station` all score 1.00, and lexical order preselects **4 Station**.
  - `ROGUE FITNESS R-6 POWER RACK` drops `R` and `6`; `R-4` and `R-6` both score 1.00, preselecting **R-4**.
  - PRIME's `HLP Selectorized Rack 2:1` and `4:1` both reduce to the same tokens and score 1.00.
- **Smallest fix:** retain numeric and model-code tokens, including meaningful one-character components. Filter OCR noise using line confidence/context, not a blanket length rule. Add a generator/test assertion that two shipped rows never normalize to the same matcher representation.

### 3. Subset and two-station readings create 1.00 wrong ties; no ambiguity gate exists

- **File/line:** `WorkoutTracker/Domain/CatalogMatcher.swift:124-169`
- **Violates:** D4, D23, D33.
- **Evidence:** `LIFE FITNESS INSIGNIA SERIES BACK EXTENSION` scores both `Life Fitness Back Extension` and the correct `Life Fitness Insignia Series Back Extension` at 1.00; lexical order preselects the short, wrong UUID. A photo between Insignia Chest Press and Shoulder Press gives both rows 1.00 and silently chooses Chest Press. The score rewards candidate-token coverage but barely penalizes unexplained reading evidence, then caps at 1.0 and discards the ambiguity.
- **Smallest fix:** never preselect a tie or near-tie. Use bidirectional/line-aware matching so a short subset cannot fully explain a longer prominent line, and treat mutually exclusive model-name lines as ambiguity rather than one bag of evidence.

### 4. Fuzzy matching reuses one OCR token as evidence for multiple different model tokens

- **File/line:** `WorkoutTracker/Domain/CatalogMatcher.swift:127-138,185-205`
- **Violates:** D4, D23, D33.
- **Evidence:** each catalog token independently searches the same reading `Set`. `abduction` can cover itself and fuzzy-cover `adduction`; `LIFE FITNESS INSIGNIA SERIES HIP ABDUCTION` therefore scores both the combo `Hip Abduction / Adduction` and the distinct `Hip Adduction` row at 1.00. The first/last-character guard also admits semantic neighbors (`hammer`↔`jammer`, `rack`↔`hack`) while missing plausible two-end OCR damage such as `HOIST`→`NOISI`.
- **Smallest fix:** make fuzzy assignment one-to-one, reject matches between known catalog vocabulary terms, and use OCR alternatives/confusion pairs rather than raw edit distance as identity evidence. Fuzzy-only evidence should not qualify a row for preselection without a margin.

## High

### 5. Camera orientation is discarded; valid `UIImage`s without `cgImage` are called unreadable

- **File/line:** `WorkoutTracker/Features/Gyms/ScanMachineLabelSheet.swift:192-203`; `WorkoutTracker/Domain/MachineLabelOCR.swift:44-53,63-78`
- **Violates:** D33; ticket 02 capture/read path.
- **Evidence:** `image.imageOrientation` is never passed to Vision. Portrait, rotated, or upside-down camera/HEIC data is handled as `.up`, so OCR and `maxY` line order are not trustworthy. A CIImage-backed `UIImage` is converted to `noTextFound` without attempting to render it.
- **Smallest fix:** pass the correct `CGImagePropertyOrientation` to `VNImageRequestHandler`; render CIImage-backed inputs through `CIContext`. Test right/left/upside-down and CIImage-backed inputs.

### 6. Permission-denied and no-camera behavior does not meet the ticket

- **File/line:** `WorkoutTracker/Features/Gyms/ImagePicker.swift:15-20,34-39`; `WorkoutTracker/Features/Gyms/ScanMachineLabelSheet.swift:178-190`
- **Violates:** ticket 02: “permission denied, no camera ... handled with a stated reason and a way forward.”
- **Evidence:** availability silently changes `.preferred` to the photo library, despite the spec requiring the reason to be stated. Camera/photo authorization is never inspected, so denied/restricted states are delegated to `UIImagePickerController` with no app-owned recovery state.
- **Smallest fix:** resolve availability and authorization before presenting. Show the reason and explicit `Choose from photos` / Settings / manual-entry actions.

## Medium

### 7. Ranking is not deterministic across hash seeds

- **File/line:** `WorkoutTracker/Domain/CatalogMatcher.swift:117-120,195-203`; `WorkoutTrackerTests/CatalogMatcherTests.swift:118-125`
- **Violates:** ticket 01 deterministic-ranking acceptance criterion.
- **Evidence:** floating-point `readingWeight` reduces an unordered `Set`; `nearestToken` also iterates a `Set` and breaks on the first distance-1 candidate. Equal-distance candidates can have different IDF weights, changing the score and possibly order across launches. Calling the function twice in one process does not test this.
- **Smallest fix:** sort tokens before reduction/search and tie-break fuzzy candidates by `(distance, token)`; test equivalent indexes/readings constructed in different orders.

### 8. “Lead with create new” only changes copy; the candidate action still comes first

- **File/line:** `WorkoutTracker/Features/Gyms/ScanMachineLabelSheet.swift:96-152`
- **Violates:** feature spec “below 0.35 the sheet leads with create new.”
- **Evidence:** `suggestsCreatingNew` changes only the section header/footer. Candidate rows and `Use This` remain above `None of these — create new`.
- **Smallest fix:** below the floor, put/emphasize create-new before candidate acceptance and label the list as optional weak alternatives.

### 9. New-brand guessing searches the entire flattened photo, not the brand line

- **File/line:** `WorkoutTracker/Domain/MachineLabelText.swift:113-133`
- **Violates:** D35's “brand is known” canonicalization rule.
- **Evidence:** any known manufacturer's token set anywhere in a two-station photo wins. Equal-length brand matches have no explicit tie-break. This can canonicalize a genuinely new top-line brand as a neighboring known brand instead of preserving it.
- **Smallest fix:** identify a unique known brand on the top/prominent brand line; on multiple known brands or only incidental whole-photo matches, preserve the editable top non-junk line.

### 10. Tests prove the clean happy path, not the claims made about production risk

- **File/line:** `WorkoutTrackerTests/CatalogMatcherTests.swift:19-44,118-142`; `WorkoutTrackerTests/MachineLabelOCRTests.swift:21-55,112-156`; `WorkoutTrackerUITests/ScanMachineLabelUITests.swift:49-68,71-95`
- **Violates:** tickets 01 and 03 verification claims; T6's independent-check intent.
- **Evidence:** the unknown-hardware test uses six rows and masks finding 1. The OCR image is clean, axis-aligned system text with perfect contrast; it proves plumbing, not photographs, rotations, scuffs, glare, or language-correction behavior. The UI save assertion finds the machine's label, which was defaulted from the candidate; it does not prove the persisted `model` relationship. Create-new checks only prefill, never save/link/`isSeeded == false`.
- **Smallest fix:** add full-catalog adversarial negatives and identity-collision fixtures; add a small checked-in set of representative transformed/real plate crops with no retained runtime photo; verify saved UUID relationships from a relaunch or test-store query. Keep the rendered fixture as a smoke test.

## Low

### 11. The feature spec still says 0.75 while D33 and code use 0.85

- **File/line:** `work-record/photo-machine-capture/spec.md:74-77`; `docs/DECISIONS.md:41`; `WorkoutTracker/Domain/CatalogMatcher.swift:104`
- **Violates:** T5 source-of-truth consistency.
- **Smallest fix:** change the stale spec value to 0.85 after replacing the unsafe calibration above.

### 12. Vision orchestration is filed as pure domain logic

- **File/line:** `WorkoutTracker/Domain/MachineLabelOCR.swift:1-78`; `CLAUDE.md:15,29`
- **Violates:** repository layout standard (`Domain/` is value types/pure logic, free of UI/platform orchestration).
- **Smallest fix:** move the Vision adapter to `Features/Gyms` (or an infrastructure folder); keep `LabelReading`, normalization, and matching in `Domain`.

## Fine

- `CatalogMatcher.editDistance`'s row-minimum early exit is a valid bounded Levenshtein optimization; no false-`nil` defect found. `Array(Set(...)).sorted()` at index construction is ordered before downstream use; that particular `Set` is fine. POSIX folding avoids locale drift.
- `usesLanguageCorrection = false` is defensible for catalog brands/codes. The missing evidence is photographic testing, not the setting by itself.
- D34 is respected: the image is held only while processing and is not written to SwiftData or disk.
- Acceptance re-fetches the selected UUID and handles deletion (`ScanMachineLabelSheet.swift:232-245`). `Use This` is effectively idempotent under a double tap; initial picker cancel safely returns to the machine sheet.
- Create-new writes `isSeeded: false` (`GymsView.swift:917-925`) and the existing picker labels it `Custom`; it cannot masquerade as seeded. User-model dedup is explicitly deferred by SPEC/D4, so lack of dedup is not a violation in this feature.
- `-uiTestScanFixture` is acceptable: ticket 02 explicitly requires it and `-uiTestReset` establishes the production launch-argument precedent. The privacy-key edits in `project.pbxproj` do not register files and do not violate the synchronized-folder rule.

Verification note: `git diff --check` passes. A targeted Xcode test rerun could not start because CoreSimulatorService was unavailable in this sandbox; the findings above come from source inspection and replaying the scorer arithmetic against `SeedCatalog.json`.
