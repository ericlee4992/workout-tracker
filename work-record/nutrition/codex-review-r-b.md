# Release R independent review — round 2

Reviewed by Codex on 2026-11-11. Clean checkout on `ericlee4992/release-r`, HEAD
`7a30c142296def75240cf1ce7778eb8edb5a9f36`; reviewed `7fa84cd..7a30c14`. Read AGENTS, STATE, the round-2 brief,
release ticket and previous report. Separate standards and spec passes completed. Only this report changes the
checkout. No commit, push, deployment, migration, upload, credential access or physical-phone installation.

## Spec

No P1/P2/P3 findings. **S1–S3 are fixed.**

- **S1 — navigation:** the privacy/support pages now name Profile → Send Feedback, Profile → Ask AI,
  Profile → Export & backup → Export, and Profile's account card → Delete Account. These match
  `ProfileTabView`, `ExportBackupView`, `ProfileScreen` and `ProfileView`. The remaining Settings reference correctly
  points to **iOS Settings → Apple Account → Sign in with Apple**, rather than an in-app screen.
- **S2 — account requirement:** support now includes online food database lookups (barcodes and search) alongside
  AI features, and explicitly keeps manual workout/food logging available without an account. This matches the
  authenticated food routes and the app's sign-in gates.
- **S3 — nutrition lifecycle:** the privacy page now describes JSON's food log, foods/meals, nutrition goals, body
  weights and personal details, explicitly excludes meal-photo bytes, and keeps CSV's sets/cardio scope separate.
  The uninstall exception includes workouts, body weights and food nutrition saved to Apple Health. These statements
  match the export model/collector and Health write types.

The added account-deletion statement also matches the code: `ProfileView`'s destructive action reaches
`ProfileScreen.delete()` and `AccountStore.deleteAccount()`. Successful deletion clears account/session state;
it does not delete the local workout or nutrition store.

## Standards

No P1/P2/P3 findings or additional baseline-smell findings.

The new `&amp;` entities correctly render the Export & backup label in HTML. The changes introduce no dynamic user
input into either page. The only app-source change is a comment in `WhatsNew.swift`, now naming Profile → What's New;
release-note wording and executable app behavior are unchanged. The named paths were checked against their actual
navigation destinations and deletion callback, not only their labels.

Privacy approval and the effective date remain pending. `POLICY_EFFECTIVE_DATE` is still `[effective date]`, and the
predeploy guard is unchanged from the round-1 check. Deployment, App Privacy confirmation, Gate S, build-number bump,
archive/upload and phone checks remain separate release steps recorded in the ticket.

## Verification

Fresh server checks and app build completed as directed. Xcode **27.2**; simulator build destination WT-iPhone27
**`47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`**. Prepared the simulator, then ran `xcodebuild build` into
`/tmp/codex-r-r2/dd`. **No Unit or UI rerun**: app behavior and test sources are unchanged, and the brief expressly
requires only the build for the app comment change.

Evidence root: **`/tmp/codex-r-r2/`**. Commands/process identity: `run.py`, `runner.pid/.log`, `server-run.py`,
`server-runner.pid/.log`, `tested-head.txt`, `*.command.json`.

| Fresh check | Result | Evidence under the root |
|---|---|---|
| Server `npx tsc --noEmit` | exit **0** | `typecheck.log/.status` |
| Server `npm test` | Vitest **283/283**, script tests **4/4**, exit **0** | `server-tests.log/.status` |
| App `xcodebuild build` | exit **0** | `build.log/.status` |
| Diff whitespace | exit **0** | `diff-check.log/.status` |
| Test/plan/project source unchanged | empty diff, exit **0** | `tests-unchanged.log/.status` |

Rechecked the prior reviewer evidence in `/tmp/codex-r/`: Unit **1,284/1,284**, exit **0**, and focused UI **8/8**,
exit **0**, with no failures/skips. Those bundles and their captured statuses remain present; these are prior results,
not fresh executions. The full-suite counts, follow-up results, captures and recorded flakes remain detailed in
`codex-review-r.md`.

Spec: **0 findings**. Standards: **0 findings**. The three round-1 copy findings are resolved.

Verified: fresh server type-check exit **0**; server **283/283** plus script **4/4**, exit **0**; app build exit **0**;
updated paths and export/Health/account statements checked against source; diff/test-source checks exit **0**.
Evidence: `/tmp/codex-r-r2/`. Prior Unit/UI evidence rechecked without rerunning.

Not verified: fresh Unit/UI execution or captures this round; live deployed pages, provider/account configuration,
production data deletion, Gate S, physical-device behavior, App Privacy submission, archive or TestFlight upload.
The user's privacy approval and effective date remain pending. No deployment was attempted.

Known flaky: none observed in this round's executed checks. Prior full-suite UI flakes and follow-up evidence remain
in `codex-review-r.md`; UI was not rerun this round.

Verdict: clear
