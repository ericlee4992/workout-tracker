Review, same checkout, branch ericlee4992/ci-and-t6 (off main d5abfdbf). Review `git diff d5abfdbf..HEAD`.
The user asked (2026-11-14): (1) make "Claude implements, Codex reviews" T6's official default; (2) fix GitHub CI's
Tests workflow, which had never passed.

What Claude found and did (commit messages carry each step): macos-26's Xcode 26.6 could not compile the app →
runs-on `xcode-27` (GitHub preview image) selecting Xcode 27.2 like the local Mac. The unit run then hung ~50 min on
two runs; a stack sample of the test host (taken by the workflow at 12 minutes) showed it blocked in Vision's
`VNRecognizeTextRequest` inside `MachineLabelOCRTests`, after "fopen failed for data file". The 8 tests that call
MachineLabelOCR.perform/read and `ScannerCorpusHarness.measureTheCorpus` are now `.disabled(if: TestEnvironment.isCI)`
(STACKED_CI via TEST_RUNNER_STACKED_CI). With a 120 s per-test allowance, 139 healthy tests timed out (they queue for the
main actor on the slower runner); now 600 s. Also: workflow_dispatch, a plain-iPhone simulator picker, the Unit test
plan, a 25-minute step cap, compiler errors printed on failure, artifact upload no longer failing the job.

Evidence: GitHub run 43588010018 (branch, workflow_dispatch) — success, "Test run with 1370 tests in 142 suites passed",
TEST SUCCEEDED; its xcodebuild-log artifact shows exactly the 9 skipped tests. Locally the Unit plan: 1370/1370 with
none skipped (build/results/ci-flag-off.xcresult) and 1370 with the 9 skipped under TEST_RUNNER_STACKED_CI=1
(ci-flag-on.xcresult). Earlier runs: 43577473013 (Duo, hung), 43582349374 (18 Pro, hung), 43584525482 (sample),
43587112895 (139 timeouts).

Check: the workflow's correctness and robustness (Xcode selection fallback, the picker, the heartbeat sampler, exit
codes through the pipeline, the env var reaching the test host); that skipping on CI is the narrowest honest choice
and is documented where people will see it; that no test that could run on CI is skipped; DECISIONS T6, AGENTS.md,
DEVELOPMENT and STATE wording (true, consistent, no stale statements). You may build and run unit tests only on
WT-Redesign-2 (EB4328A1-87BD-4850-A3B2-A6E604701F1C), derived data /tmp/wt-ci-codex; you may read GitHub runs with
`gh run view`; do not push or trigger workflows. Modify nothing but the report:
work-record/dev-speed/codex-review-ci.md, ending with exactly "Verdict: clear" or "Verdict: not clear".
