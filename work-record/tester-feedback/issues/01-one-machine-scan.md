# 01 — One machine scan: remove "Read label on device"

Status: ready (Claude implements, Codex reviews — T6)
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

(none yet)
