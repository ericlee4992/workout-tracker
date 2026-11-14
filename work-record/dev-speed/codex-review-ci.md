# CI and T6 — Codex review

Reviewed 2026-11-14 on `ericlee4992/ci-and-t6`, final review HEAD
`922302561286d2ddcc231a61f325160ade03b807`, diff `d5abfdbf..HEAD`. The checkout began clean at `0b04776d`;
`92230256` added only the STATE handoff during review. Workflow/test code is unchanged from the successful
GitHub run's `b448b6b3`. Only this report was modified by the reviewer. No pushes or workflow dispatches.

## Standards

1. **P3 — Update the public build/test overview for the fixed CI workflow.** `README.md:134–135` still presents
   the hosted Xcode-26 compiler failure as an open issue in STATE. The branch now uses Xcode 27.2 and has a green
   hosted run, but README says nothing about that or the local-only Vision coverage. Update the Building section
   to describe the current workflow and its exclusions. This is required by AGENTS' same-branch README rule for
   build/test changes; the historical Xcode-26 limitation can remain labelled as history.

2. **P3 — Make the handoff merge command executable.** `docs/STATE.md:27` has
   `git -C "…/orca/projects/Health App" pull --ff-only && merge --ff-only … && push`. The `-C` option applies only
   to the first Git process; the next commands are standalone `merge` and `push`, so the documented sequence cannot
   finish the merge. Repeat `git -C <home>` for each command, or explicitly change directory and invoke `git pull`,
   `git merge`, and `git push`. No merge/push was attempted in this review.

T6 and AGENTS otherwise agree on the user-authorized Claude-implements/Codex-reviews default and preserve
independent review when the roles reverse. DEVELOPMENT and the updated STATE accurately distinguish the passing
branch run from the pending merge/main run. Relative documentation links resolve.

## Spec / test coverage

3. **P2 — Preserve the corpus harness's Vision-free transcription mode on CI.**
   `WorkoutTrackerTests/ScannerCorpusHarness.swift:61` disables the entire method whenever `STACKED_CI=1`, before
   the existing `SCANNER_LLM == "1"` branch (`:79–85,100–104`). That documented mode reads saved transcriptions and
   exercises CatalogMatcher without calling Vision. Running it with both CI and transcription flags now skips it
   even though the diagnosed API is not used. Restrict the skip to the Vision-dependent mode, or separate that
   mode from the transcription/matcher check. Keep the existing no-corpus behavior explicit and adjust the documented
   skip count if the resulting scope changes. This is broader than the brief's requested narrowest honest exclusion.
   It does **not** invalidate the reported default CI success: the normal GitHub checkout has only the manifest,
   so the harness would otherwise exit without measuring photos there.

All eight disabled MachineLabelOCRTests actually invoke `MachineLabelOCR.perform/read`; their two pure matcher/index
tests remain enabled. The CI flag is confined to test sources and the workflow; production app code is unchanged.

## Workflow and failure evidence

No additional workflow correctness finding. The Xcode choice, simulator preference, Unit plan, diagnostic sampler,
timeout limits and failure propagation were inspected. `pipefail` plus the explicit failure branch preserves a
failed xcodebuild; making artifact upload nonfatal does not override a failed test step. The 25-minute step cap and
600-second test allowance are explicit. The sampler's failure is nonfatal and its files are included in artifacts.

Independently read GitHub run metadata, logs and downloaded artifacts:

- [43588010018](https://github.com/ericlee4992/workout-tracker/actions/runs/43588010018): **success**, commit
  `b448b6b3`, workflow_dispatch on this branch; `xcode-27-arm64`, **Xcode 27.2**, **iPhone 18 Pro**. The job ran
  approximately 19½ minutes. Its build log reports 1370 registered tests, exactly nine named skips, and
  `TEST SUCCEEDED`. The workflow/test files have no diff from this commit to the reviewed HEAD.
- [43584525482](https://github.com/ericlee4992/workout-tracker/actions/runs/43584525482): downloaded the stack sample.
  It contains blocked MachineLabelOCRTests calls through `MachineLabelOCR.perform` into
  `VNRecognizeTextRequest`, supporting a Vision-specific hosted-runner problem.
- [43587112895](https://github.com/ericlee4992/workout-tracker/actions/runs/43587112895): **failure**, with **139**
  recorded 120-second time-limit issues. Raising the allowance subsequently produced the successful run without
  changing those tests' assertions.
- GitHub's [image announcement](https://github.com/actions/runner-images/issues/14404) confirms the `xcode-27`
  public-preview label. The documented future move to a GA image is appropriate.

Artifacts are under `/tmp/wt-ci-review/green/`, `/tmp/wt-ci-review/sample/`, and `/tmp/wt-ci-review/timeouts/`.
This evidence supports the eight OCR exclusions; it does not establish that the harness's transcription-only mode
needs exclusion (#3), or diagnose every historical cancelled run.

## Independent local verification

Used only WT-Redesign-2 `EB4328A1-87BD-4850-A3B2-A6E604701F1C`, prepared before build/tests. Derived data
`/tmp/wt-ci-codex`; logs, exit files and result bundles `/tmp/wt-ci-review/`.

| Scope | Result |
|---|---|
| `build-for-testing`, WorkoutTracker scheme | exit 0, `build.log` / `build.exit` |
| Unit plan restricted to MachineLabelOCRTests + ScannerCorpusHarness; CI/transcription flags unset | **11/11 passed**, 0 skipped/failed, exit 0, `flag-off.xcresult` |
| Same two suites with `TEST_RUNNER_STACKED_CI=1` | **2 passed, 9 skipped, 0 failed**, exit 0, `flag-on.xcresult` |
| Workflow `run` blocks parsed with `bash -n`; embedded picker parsed as Python | passed |
| Diff whitespace, test-plan consistency, relative documentation links | passed |

Both independent xcresult summaries were inspected, confirming that the flag reaches the test host and normal
local OCR tests remain enabled. No corpus photos are present in this checkout, so the unflagged corpus harness
exercised its existing no-data return and wrote no corpus report. The optional transcription-mode finding is
source-traced; that mode was not executed with a populated corpus.

Also directly inspected the author's full Unit results: `ci-flag-off.xcresult` **1370 passed, 0 skipped**;
`ci-flag-on.xcresult` **1361 passed, 9 skipped**; neither has failures. The changed suites were rerun independently
instead of duplicating the unchanged full suite. No UI code changed, so no UI run was needed.

Verified: independent build; affected unit suites with flag off/on; hosted green-run metadata/log/skip list;
          Vision stack sample and timeout evidence; workflow syntax and docs consistency checks.
Not verified: a new workflow dispatch or post-merge main run; alternate-image/Xcode fallback execution on GitHub;
              populated transcription-only corpus execution; full local Unit/UI suites in this review.
Known flaky: hosted Vision execution hangs on the recorded runs and is explicitly excluded; the safe-mode
             over-exclusion remains finding #3. No failures occurred in the independent local runs.

Standards: 2 P3 findings. Spec: 1 P2 finding.

Verdict: not clear
