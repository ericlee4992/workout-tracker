Round 2 of the CI/T6 review, same checkout, branch ericlee4992/ci-and-t6. Your round-1 report:
work-record/dev-speed/codex-review-ci.md (not clear: 1 P2, 2 P3). Review `git diff 92230256..HEAD` (fix commit b228c97c
plus this brief) and confirm nothing else regressed.

Fixes:
- #3 (P2): `ScannerCorpusHarness.measureTheCorpus` is now `.disabled(if: TestEnvironment.isCI && !readsSavedTranscriptions)`
  — skipped on CI only in the Vision mode; with SCANNER_LLM=1 it runs (it reads corpus/llm-readings.json, no Vision).
  Default CI scope is unchanged (SCANNER_LLM unset there): still the 9 skips. DEVELOPMENT's CI note says this.
- #1 (P3): README "Building" now describes the xcode-27 workflow (Xcode 27.2, Unit tests after each push to main) and
  the 9 local-only text-recognition tests; the Xcode 26.6 limitation stays as a fact.
- #2 (P3): STATE's merge command now uses `git -C "$H"` for pull, merge and push.

Author's evidence (WT-Floodlight 9E822EF6-DC67-4958-AEA2-D53D2D36D674, derived data build/dd-ci): build-for-testing
exit 0 (build/results/r2-build.log); MachineLabelOCRTests + ScannerCorpusHarness on the Unit plan —
flag off 11/11 passed (r2-off.xcresult); TEST_RUNNER_STACKED_CI=1 2 passed / 9 skipped (r2-on.xcresult);
TEST_RUNNER_STACKED_CI=1 + TEST_RUNNER_SCANNER_LLM=1 3 passed / 8 skipped (r2-llm.xcresult; no corpus photos in this
checkout, so the harness took its no-data return). A branch CI run was dispatched on b228c97c: run 43590959069 (in
progress when this was written; read it with `gh run view` if finished).

This round changes a test trait (non-UI) and docs: build and rerun the two affected suites yourself (flag off / on /
on + SCANNER_LLM) on WT-Redesign-2 (EB4328A1-87BD-4850-A3B2-A6E604701F1C), derived data /tmp/wt-ci-codex; no UI run.
Do not push or trigger workflows. Modify nothing but work-record/dev-speed/codex-review-ci-b.md, ending with exactly
"Verdict: clear" or "Verdict: not clear".
