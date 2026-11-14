# CI and T6 — Codex review, round 2

Reviewed 2026-11-14 on `ericlee4992/ci-and-t6`, target `92230256..0b1e201d46e07f6bc731a96c577b8c724e36beab`.
The checkout began clean at `50b92ab8`; `0b1e201d` only corrected STATE's recorded tip during review. The functional
fix is `b228c97c`. Only this report is changed by the reviewer; no pushes or workflow dispatches.

**Final report — all three findings resolved. Independent build and all three local modes pass.**

## Standards

No findings. README now describes the working Xcode-27/Xcode-27.2 CI workflow and its normal nine-test exclusion.
DEVELOPMENT explicitly documents the corpus harness's saved-transcription exception. STATE's handoff uses
`git -C "$H"` for pull, merge and push, and continues to distinguish branch verification from pending merge/main
verification. These resolve the two round-1 P3 findings. T6 remains consistent with AGENTS.

## Spec

No findings. The round-1 P2 is resolved: the corpus harness is disabled only for CI **and** Vision mode.
`readsSavedTranscriptions` is shared by the trait and the execution branch, so `SCANNER_LLM=1` consistently enables
the existing Vision-free path. Normal CI still skips the same nine tests; local execution remains enabled.
The existing no-data return, transcription loading, matcher behavior and Vision execution code are unchanged.
No app/UI code or workflow steps changed in this round.

## Verification

Independent build/tests use only WT-Redesign-2 `EB4328A1-87BD-4850-A3B2-A6E604701F1C`, prepared before each run;
derived data `/tmp/wt-ci-codex`; evidence `/tmp/wt-ci-review-r2/`.

| Check | Result |
|---|---|
| `build-for-testing`, WorkoutTracker scheme | exit 0, `build.log` / `build.exit` |
| Unit plan, MachineLabelOCRTests + ScannerCorpusHarness, flags unset | **11 passed, 0 skipped, 0 failed**, exit 0, `off.xcresult` |
| Same suites, `TEST_RUNNER_STACKED_CI=1` | **2 passed, 9 skipped, 0 failed**, exit 0, `on.xcresult` |
| Same suites, CI flag plus `TEST_RUNNER_SCANNER_LLM=1` | **3 passed, 8 skipped, 0 failed**, exit 0, `llm.xcresult` |
| Diff whitespace, test-plan consistency, relative documentation links | passed |

Author's three xcresult summaries were inspected directly: `r2-off` 11 passed/0 skipped, `r2-on` 2 passed/9 skipped,
`r2-llm` 3 passed/8 skipped; all report success with no failures. This checkout has no corpus photos, so an enabled
harness takes its no-data return; these runs verify trait/env selection, not populated-transcription processing.
All three independent summaries and exit files were inspected. In the CI-plus-transcription log,
`measureTheCorpus` starts and passes while exactly the eight Vision tests skip, confirming the intended exception.

The new [GitHub branch run 43590959069](https://github.com/ericlee4992/workout-tracker/actions/runs/43590959069)
targets `b228c97c`; it was still in progress when inspected. Workflow/test files are unchanged from that commit to
the reviewed HEAD. The previous green-run evidence remains recorded in round 1; this run's result must be read
before merge, as STATE directs. No workflow was triggered by this reviewer. No UI run is needed for this test-trait
and documentation-only change.

Verified: independent build exit 0; affected suites in all three modes, exit 0, result bundles under
          `/tmp/wt-ci-review-r2/`; source review; author's three-mode summaries; documentation checks.
Not verified: hosted rerun completion (still in progress at the last check); populated corpus mode; post-merge main run.
Known flaky: hosted Vision limitation remains explicitly scoped; no failures observed in the local checks.

Standards: 0 findings. Spec: 0 findings. Code review is clear; the owner still needs to read the pending hosted run
before merging and verify the subsequent main run, as recorded in STATE.

Verdict: clear
