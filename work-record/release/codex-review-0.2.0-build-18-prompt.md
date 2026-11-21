Release review for Stacked 0.2.0 (18) (AGENTS.md T6; the `testflight-release` skill, step 6). Repository
/Users/ericlee06/.paseo/worktrees/1qmeipq9/today-pick-day, branch `ericlee4992/release-0.2.0-18` off `main` 08234d89.
Diff: `git diff 08234d89..HEAD` (the build number and this release's records). Contents since build 17:
`git diff 8812bfda..08234d89` (N16 pick a day on Today, which you reviewed clear in
work-record/nutrition/codex-review-n16.md / n16b.md; the rest is agent tooling and docs).

Check: CURRENT_PROJECT_VERSION 18 in every target and setting, MARKETING_VERSION unchanged 0.2.0; app and widget agree;
the release record work-record/release/0.2.0-build-18.md (contents complete and accurate vs the diff since 8812bfda —
every app change belongs to N16; the stored-format statement — no change, `approvedFingerprint` unchanged, nothing that
rewrites rows or preferences on first launch; the Gate S statement — none, the phone has build 17 installed (the user);
no server change; the What to Test note matches the feature and says nothing the code doesn't do; no What's New, as the
user chose); no secrets or personal data in the records. Build and run the Unit plan yourself (only simulator
WT-Redesign-2 EB4328A1-87BD-4850-A3B2-A6E604701F1C, `-derivedDataPath /tmp/wt-r18-codex`); the author's result is
build/results/r18-unit.xcresult. Modify nothing but the report. Write work-record/release/codex-review-0.2.0-build-18.md
with numbered findings (P0–P3, file:line, scenario, fix), what you ran, then exactly "Verdict: clear" or "Verdict: not clear".
