# Codex review — release R (build 10): release texts, README, privacy page, one test fix

You are the independent reviewer; Claude prepared it. Branch `ericlee4992/release-r` off `main` `3ad9dca`. Review
`git diff 3ad9dca..HEAD` plus the privacy page as it will go live: `git diff 0191b3f HEAD -- server/src/pages.ts`
(0191b3f = the live October 15 policy).

Read first: `work-record/nutrition/issues/11-combined-release.md` (Checklist, Progress: cost re-check, the user's
decisions, the approved What's New / What to Test texts, full UI suite results), D62 (release notes), D76, D72–D75,
D78–D83 as needed; AGENTS (README rules); `docs/DEVELOPMENT.md` → TestFlight build checklist.

Check:
1. **What's New** (`Domain/WhatsNew.swift` build 10) and **What to Test** (ticket): match the approved wording exactly;
   every claim true of the app on this branch (e.g. "scan a barcode or a label", goals in Profile, Apple Health,
   "Profile → Send Feedback" exists); no "AI" wording outside feature names (C1); `WhatsNewTests`,
   `FloodlightWhatsNewUITests` (4 lines, the AXL scroll check).
2. **Privacy page** (`server/src/pages.ts`): every statement matches the code and deployment — what stays on the
   iPhone (food, photos, goals, body weight, personal details), Apple Health reads/writes (N9b), the food AI flows
   (N6/N7: what is sent, no consent prompt, not stored), barcodes and search (N8: what goes to Open Food Facts / USDA,
   the 30-day shared cache linked to no account, the hashed search key, daily counts and their pruning/deletion),
   processors list, deletion. Note anything the code does that the page omits. The effective date is still a
   placeholder (the user sets it; the predeploy guard refuses until then).
3. **README** (and `server/README.md`): accurate for this branch; the new Today picture; release-status marks.
4. **Test fix** `WorkoutTrackerUITests/WorkoutNameUITests.swift` (`closeReceipt()`): the failure diagnosis in the
   ticket and the fix.

Per AGENTS' reviewer rule: build; Unit plan; UI: `AAAWarmUpUITests`, `FloodlightWhatsNewUITests`,
`WorkoutNameUITests` (2 workers). You may inspect Claude's full-suite xcresult
(`/private/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-UI-design/8bffdecc-0105-4db5-8c71-05a754a21832/scratchpad/r-full.xcresult`,
`r-rerun.xcresult`, `r-name.xcresult`, `r-wn.xcresult`) rather than rerunning the full suite. Paths under
`/tmp/codex-r/`. Claude runs nothing while you run. Do not modify files other than the report; do not commit or push.

Write `work-record/nutrition/codex-review-r.md`: findings P1/P2/P3 with file:line, failure scenario and fix; Verified /
Not verified / Known flaky; end with exactly `Verdict: clear` or `Verdict: not clear`.
