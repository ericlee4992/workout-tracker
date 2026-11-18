Release review for Stacked 0.2.0 (17) (AGENTS.md T6; docs/DEVELOPMENT.md → TestFlight build checklist). Repository
/Users/ericlee06/.paseo/worktrees/1qmeipq9/machine-settings, branch `ericlee4992/release-0.2.0-17` off `main` b539c99e.
Diff: `git diff b539c99e..HEAD` (the build number and this release's records). Contents since build 16:
`git diff 0449f245..b539c99e` (machine-settings 01, which you reviewed clear in codex-review-01/01b).

Check: CURRENT_PROJECT_VERSION 17 in every target and setting, MARKETING_VERSION unchanged 0.2.0; app and widget agree;
the release record work-record/release/0.2.0-build-17.md (contents complete and accurate vs the diff since 0449f245;
the Gate S statement — a stored-format change; no server change; the What to Test note matches the feature and says
nothing the code doesn't do; no What's New, as the user chose); nothing else in the build changes the store or rewrites
rows on first launch; no secrets or personal data in the records. Build and run the Unit plan yourself (only simulator
WT-Redesign-2 EB4328A1-87BD-4850-A3B2-A6E604701F1C, `-derivedDataPath /tmp/wt-r17-codex`); the author's result is
build/results/r17-unit.xcresult. Modify nothing but the report. Write work-record/release/codex-review-0.2.0-build-17.md
with numbered findings (P0–P3, file:line, scenario, fix), what you ran, then exactly "Verdict: clear" or "Verdict: not clear".
