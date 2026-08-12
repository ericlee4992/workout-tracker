# Cross-review round 2 — photo machine capture, after the round-1 fixes

You reviewed this feature in `.scratch/photo-machine-capture/codex-review.md` and said **do not
merge**: four critical ways to preselect a confidently wrong catalog UUID, plus higher/medium
findings. Everything has been changed in response. Verify the fixes, adversarially, and look for
what the fixes themselves broke.

Read `.scratch/photo-machine-capture/codex-review.md` first, then the current (uncommitted, branch
`photo-machine-capture`) sources:

- `WorkoutTracker/Domain/CatalogMatcher.swift` — rewritten scorer
- `WorkoutTracker/Domain/MachineLabelText.swift` — tokenization + brand/model guessing
- `WorkoutTracker/Features/Gyms/MachineLabelOCR.swift` — moved here, orientation + CIImage
- `WorkoutTracker/Features/Gyms/ImagePicker.swift` — `CaptureAvailability`
- `WorkoutTracker/Features/Gyms/ScanMachineLabelSheet.swift`
- `WorkoutTrackerTests/CatalogMatcherAdversarialTests.swift` (new), `CatalogMatcherTests.swift`,
  `MachineLabelOCRTests.swift`, `WorkoutTrackerUITests/ScanMachineLabelUITests.swift`

## What changed, so you can attack the right things

1. Unseen-in-catalog words now carry `unknownTokenWeight` (IDF of a once-seen word) instead of 0.
2. Score = `0.60 × name-token coverage + 0.30 × share of the plate's non-junk evidence explained +
   0.10 × manufacturer named`, multiplied by 0.6 when the plate names a *different* known brand.
3. `preselection(from:)` replaces `isConfident`: requires score ≥ 0.85 **and** the row's
   manufacturer named **and** no conflicting brand **and** ≥ 0.08 clear of the runner-up.
4. Catalog tokenization keeps single characters; the photo side drops lone letters, keeps digits.
5. Fuzzy matching is one-to-one (a reading token is consumed) and refuses to pair two words the
   catalog both knows.
6. Sorted reductions/iteration for determinism.

## Questions

- **Do the round-1 criticals actually die?** Replay them against `SeedCatalog.json`: NEWCO /
  MATRIX pendulum squat, Atlantis belt squat, `NAUTILUS 5 STATION`, Rogue `R-6`, PRIME `2:1`,
  Insignia back extension vs plain back extension, two-machine photo, hip abduction/adduction.
  Report the actual scores and whether anything is preselected.
- **False negatives — the new risk.** How often can a legitimate scan *not* be preselected now?
  Requiring the manufacturer to be named means a plate whose brand strip is worn, cropped, or
  simply absent (many machines put the brand on the frame, not the plate) never preselects. Is
  that the right trade, and is the fallback (tap the row yourself) acceptable? Sample real catalog
  rows and say what fraction would preselect from a clean reading of their own name.
- **New holes in the gate.** Can `manufacturerConflicts` be wrong — a brand word that is also a
  common English word or part of a model name (e.g. "Matrix", "Precor", "Titan", "Life")? Does the
  0.6 conflict multiplier interact badly with the 0.85 bar? Can a single-token brand appear
  incidentally and suppress the right row?
- **Tokenization fallout.** Keeping single characters raises IDF noise: are there catalog rows
  whose scores now depend on a stray `a` or `s`? Does `readingTokens` dropping lone letters lose a
  real identity (a plate that says `R 6` with a space)?
- **Fuzzy one-to-one.** Consumption order is weight-descending per row — can a high-weight token
  steal the reading token a lower-weight token needed, changing which row wins?
- **The rest.** Orientation mapping correctness; `CaptureAvailability` states; the create-new-first
  ordering; anything in the tests that still proves less than it claims.

## Output

`.scratch/photo-machine-capture/codex-review-2.md`: verdict (merge / do not merge), findings by
severity with file/line and smallest fix, and explicitly state which round-1 findings you consider
closed. Do not change code.
