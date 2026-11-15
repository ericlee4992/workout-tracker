# 01 — One machine scan: remove "Read label on device"

Status: implemented, in review (Claude implements, Codex reviews — T6); branch `ericlee4992/one-machine-scan`
Type: task

## The user's request (2026-11-14)

> When users used the read label on device feature, they said it's inaccurate and often can't read the manufacturer
> name correctly. So I just want to get rid of it, and just use one scan machine (using the GPT Terra).

## Today

- The machine form (`WorkoutTracker/Features/Gyms/MachineEditorSheet.swift:66-73`) offers two scans:
  **"Scan equipment…"** → `IdentifyEquipmentSheet` → the server's `scan-machine` flow on GPT-5.6 Terra (D56, D60;
  sign-in and photo consent), and **"Read label on device"** → `ScanMachineLabelSheet` (Vision + `CatalogMatcher` on
  the phone; D33–D35; its Ask AI was removed in scanner 07). Scan Machine on a gym page and in Ask AI for Templates is
  already GPT only.
- "Read label on device" → create-new opens `AddModelSheet` with the plate lines (`ScanDraft`,
  `MachineEditorSheet.swift:33-37, 170-181`). `ModelPicker` has its own `AddModelSheet` path, which stays.

## Change

1. Remove "Read label on device" and `ScanMachineLabelSheet`. The machine form keeps one scan — the GPT flow — and
   the manual **Catalog model** picker. Consider naming the one scan "Scan Machine" like the gym page (UI-first: show
   the form at default and AccessibilityL before changing wording; match the app's current screens).
2. Delete code and tests used **only** by the on-device machine scan. Check every caller first — some pieces are
   shared with Scan Machine or Scan Food and must stay: `LabelCameraView`, `ScanFixture`, `LabelReading`,
   `LabelCrop`, the scan step views under `Features/Gyms/Scan/`, `EquipmentIdentityResolution`. Likely only-on-device
   candidates (verify): `MachineLabelOCR`, `MachineLabelRepair`, `MachineLabelText`, `MachineLabelDictionary`,
   `CatalogMatcher` (+ `CatalogMatchIndex`), the scan path of `MachineEditorSheet` (`showingOfflineScanner`,
   `ScanDraft`); tests `MachineLabelOCRTests`, `CatalogMatcher*Tests`, `MachineLabelRepairTests`,
   `ScannerCorpusHarness`, `ScanMachineLabelUITests` (and any test plan / `scripts/test-plans.py` entry for them).
   Report anything ambiguous instead of guessing.
3. CI: the 9 tests GitHub skipped (on-device text recognition) go with this code. If no test needs
   `TestEnvironment.isCI` any more, remove it and `TEST_RUNNER_STACKED_CI` from `.github/workflows/tests.yml`, and
   update AGENTS.md's CI paragraph, DEVELOPMENT's CI note and README's Building section (they name the 9 skipped
   tests). The scanner-accuracy work record and corpus stay as history.
4. Privacy policy (`server/src/pages.ts:55-56`: "The app's own label reader works on your iPhone"; `:103-104`: "any
   text read from its label" for exercise suggestions): make it say what the app now does. **Deploying the server is
   the user's call** — ask before `wrangler deploy`, and follow DEVELOPMENT's server steps.
5. README: features and screenshots, if they show or mention the on-device reader.

## Decisions to record

A new D-number: the machine form's on-device label reader is removed (the user, 2026-11-14, testers: inaccurate,
misread manufacturers); one scan, Scan Machine (D56). Reopens D56's "On-device label reading/manual catalog entry
remain explicit offline alternatives" — **manual catalog entry stays the offline and signed-out path**; supersedes
D33–D35 where they describe the on-device scan sheet (D33's "the app proposes, the user confirms" still holds for
Scan Machine's result); D34's note about the on-device scan. Ask the user if anything here is not what they meant
(for example: should signed-out users see a "Sign in to scan" prompt where the second button was?).

## Acceptance

- The machine form shows one scan (the GPT flow) plus the catalog picker; no "Read label on device" anywhere.
- Signed out or offline, a machine can still be added and given a catalog model by hand; the scan's own sign-in /
  consent prompts are unchanged.
- No dead code, fixtures, identifiers or tests of the removed scan remain; shared pieces still serve Scan Machine and
  Scan Food (their UI tests pass).
- Docs (DECISIONS, SPEC if it mentions it, README, AGENTS/DEVELOPMENT CI lines, privacy page) match the code.
- `xcodebuild build` succeeds; the Unit plan passes; focused UI classes pass: the machine form, `FloodlightScanUITests`,
  the Scan Machine parts of `AskAIUITests`/`FloodlightAIAccessUITests`, `ScanFoodUITests`. After merge, GitHub's Tests
  run on `main` is green.

## Progress

### The user's answers (2026-11-14)

- **"Suggest exercises": remove it too.** New Model's AI suggestion appeared only for a plate the on-device reader had
  read (`plateLines` non-empty), so with the reader gone nothing could show it. Removed as unused, with its client,
  consent key and the profile's "Exercise suggestions" usage tile. The server's `model-exercises` flow **stays** for
  installed builds (server README says so); the privacy page names it as "earlier versions of the app only".
- **Signed out: no change.** One scan row for everyone; signed out it opens Scan Machine's own sign-in step.
- **Wording: "Scan Machine"** (from the before/after captures), like the gym page.

### What changed (`d1f9064e`)

- Machine form: one scan row "Scan Machine" (id `scanMachineLabel` kept) + Catalog model; the offline sheet, `ScanDraft`
  and its New Model path removed.
- Deleted (each checked for callers outside the removed path first): `ScanMachineLabelSheet`, `MachineLabelOCR`,
  `MachineLabelDictionary`, `CatalogMatcher` (+ `CatalogMatchIndex`, `CatalogMatch`), `MachineLabelRepair`,
  `MachineLabelText` (+ `LabelReading` — not shared after all: only the reader used it), `ScanScoreMeter`,
  `AskAI` (+ proposers), `ExerciseProposal` (+ `ExerciseCandidate`, `PlateDescription`, `AskAIError`),
  `AIFlow.modelExercises` + `modelExercisesBody`, `TerraAccess.exerciseConsentKey`. Tests: `MachineLabelOCRTests`,
  `CatalogMatcherTests`, `CatalogMatcherAdversarialTests`, `MachineLabelRepairTests`, `ScannerCorpusHarness`,
  `ExerciseProposalTests`, `TestEnvironment`, `ScanMachineLabelUITests`; the New Model suggestion UI tests
  (`FloodlightAIAccessUITests.captureNewModel`, `AskAIUITests.testManualModelSuggestionsRequireConsentAndKeepConfirmation`)
  and `FloodlightScanUITests`' Read Label captures (replaced by machine form captures `tf01-machine-form-*`).
- Kept (shared): `LabelCameraView`, `LabelFramingBox`, `LabelCrop` (+ rendering), `ImagePicker`, `CaptureAvailability`,
  the `Scan/` step views, `EquipmentIdentityResolution`, `AddModelSheet` (ModelPicker's path). `ScanFixture` (the
  rendered plate) moved to `Features/Gyms/Scan/ScanFixture.swift`; its `-uiTestScanFixture` flag (reader only) removed.
- After the deletions, a sweep of every identifier in the deleted files found nothing left referenced only by its
  definition. No `import Vision` remains in the app or tests.
- CI: `TEST_RUNNER_STACKED_CI` removed from `.github/workflows/tests.yml`; AGENTS, DEVELOPMENT and README's CI lines
  updated. `scripts/test-plans.py` / `GymsExercises.xctestplan` drop `ScanMachineLabelUITests` (`--check` passes).
- Docs: D88 (new); D33, D34, D35, D53, D56 annotated; SPEC line 30; README features + AI-section line; server README's
  `model-exercises` row.
- Privacy page (`server/src/pages.ts`): the "app's own label reader" sentence removed; exercise suggestions dropped from
  the feature list and named "earlier versions of the app only" in What is sent. **`POLICY_EFFECTIVE_DATE` is the
  `[effective date]` placeholder, so `npm run deploy` refuses until the user approves and the date is set to the
  deploy day.** Not deployed.

### Verification (author)

- Captures before/after (light default + AXL; after also dark): `build/captures/tf01-before/`, `tf01-after/`
  (gitignored; `FloodlightScanUITests/testCaptureMachineForm*`).
- `xcodebuild build-for-testing` exit 0 (`build/logs/bft-2.log`).
- Unit plan: **1291/1291 passed** (`build/results/tf01-unit.xcresult`; 1370 before — the 79 removed tests).
- Server: `npx vitest run` 341/341, `node --test` 4/4, `tsc --noEmit` clean.
- Focused UI (2 workers, `build/tf01-ui.sh`, log `build/logs/tf01-ui.log`, `build/results/tf01-ui.xcresult`):
  `FloodlightScanUITests`, `ScanFoodUITests`, `GymsFlowsUITests`, `TemplateMachinesUITests`,
  `FloodlightAIAccessUITests`, `FloodlightAccountUITests`, `FloodlightProfileUITests/testCaptureProfile*` (the AI
  usage tiles, now two) and the Scan Machine tests of `AskAIUITests` (generic scan, failure/rescan, scan during routine
  setup, routine scanner consent, edited label, the four identities, photo consent) — **73/73 passed, exit 0**
  (xcresult summary: 73 passed, 0 failed, 0 skipped).

**Verified:** build; Unit plan 1291/1291; server tests and typecheck; the 73 focused UI tests above; captures of the
form. **Not verified:** a live signed-in Scan Machine from the form on a phone (the fixture drives it; the code path
is unchanged); the privacy page live (not deployed — the user's go). **Known flaky:** none seen.

### Review round 1 (Codex, `codex-review-01.md`): changes requested → fixed

- **2 (P2) SPEC line 30** still described the private-trial phone key and a planned backend: now says requests go
  signed in through Stacked's server, which holds the OpenAI key (D60); the phone holds none and a leftover trial key is
  purged at launch.
- **1 (P3) stale comments**: `LabelCameraView` (region now described for `LabelCrop`), `ScanSteps` camera step (Scan
  Food's label box, not Read Label), `FloodlightAIAccessUITests` header (New Model suggestion removed).
- Codex's run: build, Unit 1291/1291, server checks, 4 extra New Model editor tests passed; focused UI 72/73 with
  `GymsFlowsUITests/testMachinePageEditsApplyAndDeleteCloses` failing once in the parallel run (blank name read as the
  placeholder; test and screen unchanged by this ticket) and passing 4/4 in a serial class rerun — **known flaky** under
  load (passed in the author's run too).
- Round 2 verification (author): docs/comments only → `xcodebuild build` exit 0; no test rerun needed.
