# Cross-review request — photo machine capture (scan a name plate)

You are reviewing work written by Claude, per decision **T6**: solo project, so this is the only
independent check that exists. Be adversarial, not agreeable. Terse. No praise. Do not change code.

## Context to read first

1. `CLAUDE.md`, `docs/STATE.md`, `docs/SPEC.md`, `docs/DECISIONS.md` (**D33–D35 are new**; D4, D23,
   D24 and D27 are the ones this feature can violate).
2. `.scratch/photo-machine-capture/spec.md` and `issues/01..03`.
3. The change: **uncommitted** on branch `photo-machine-capture`. `git status --short` lists the
   modified files; the new files are untracked, so read them directly:
   - `WorkoutTracker/Domain/MachineLabelText.swift`
   - `WorkoutTracker/Domain/CatalogMatcher.swift`
   - `WorkoutTracker/Domain/MachineLabelOCR.swift`
   - `WorkoutTracker/Features/Gyms/ScanMachineLabelSheet.swift`
   - `WorkoutTracker/Features/Gyms/ImagePicker.swift`
   - `WorkoutTrackerTests/CatalogMatcherTests.swift`, `WorkoutTrackerTests/MachineLabelOCRTests.swift`
   - `WorkoutTrackerUITests/ScanMachineLabelUITests.swift`
   - diffs in `WorkoutTracker/Features/Gyms/GymsView.swift` and `WorkoutTracker.xcodeproj/project.pbxproj`

## The defect that matters

A **confident wrong match**. D23 keys history, prefill and PRs on the model UUID, so accepting the
wrong catalog row splits the user's own training history — the damage duplicate catalog identities
did in codex-review-4. Attack that first:

1. **Scoring.** Can a wrong row clear `confidentScore` (0.85) and be preselected? Construct
   readings that do it — stablemates sharing a series name, short model names, a manufacturer whose
   name is also a common word, a row whose name is a subset of another's, plate text that names two
   machines (a photo taken between two stations). Is IDF over the catalog the right corpus? What
   about a manufacturer with 400 rows versus one with 3?
2. **Thresholds.** 0.85 / 0.35 / 0.25 are tuned against fixtures in the tests. Which realistic
   input embarrasses them? Is `suggestsCreatingNew` reachable when it should be?
3. **Fuzzy matching.** `nearestToken` requires a shared first *or* last character and weight ≥ 1.5,
   distance ≤ 1 (short) / 2 (long). What real OCR error does that miss, and what wrong pairing does
   it admit? Is `editDistance`'s early exit correct (a bounded Levenshtein that returns nil)?
4. **Determinism and purity.** Same reading + same index ⇒ same ranking? Any hidden dependence on
   dictionary iteration order, locale, or `Set` ordering? (`CatalogMatchIndex` iterates a `Set`
   during construction — does anything downstream depend on that order?)
5. **The reading itself.** `MachineLabelOCR` orders lines by `boundingBox.maxY`. Correct for a
   rotated or upside-down photo? Is dropping single-character tokens right? Is
   `usesLanguageCorrection = false` defensible? Does anything retain the image (D34)?
6. **The UI path.** `ScanMachineLabelSheet` presents an `ImagePicker` sheet from `onAppear` and
   builds the catalog index on the main actor. Failure modes: permission denied, user cancels,
   picker returns a non-`cgImage`-backed image (HEIC/CIImage), the model is deleted between ranking
   and acceptance, double-tap on Use This, a scan started from a sheet the user then dismisses.
7. **D35 / D4.** Can a scan produce a row that looks seeded, or a duplicate of an existing model?
   Should create-new dedupe against the user's existing models? Is the manufacturer guess's
   canonical-spelling rule right when the plate's brand is genuinely a *new* brand?
8. **Tests.** What do they claim that they do not prove? Is the rendered-label fixture so clean
   that it proves nothing about real photographs? Is the `-uiTestScanFixture` hook in production
   code acceptable, given `-uiTestReset` precedent?

## Output

`.scratch/photo-machine-capture/codex-review.md`: findings ranked by severity, each with
file/line, the decision it violates, and the smallest fix. Say plainly if something is fine.
