Release review for Stacked 0.2.0 (14), same checkout, branch ericlee4992/release-0.2.0-14 (off main 6dbaa303). Review
`git diff 6dbaa303..HEAD` and the release record work-record/release/0.2.0-build-14.md against docs/DEVELOPMENT.md →
"TestFlight build checklist" and your build-13 review's format (work-record/release/codex-review-0.2.0-build-13.md).

Check: every CURRENT_PROJECT_VERSION is 14 and MARKETING_VERSION 0.2.0 (all targets and configurations, and the built
plists); the claim of no stored-format change since build 13 (`git diff f6faa31f..HEAD` — any @Model, relationship,
schema or migration change would need Gate S) and no server change; that shipping no What's New entry is consistent
with WhatsNew.swift (what someone on build 12 or 13 sees); the What to Test note matches the two merged tickets
(live-workout 03, N15) and claims nothing they don't do; anything in the 14 commits since build 13 that should block a
release. Build and run what you need ONLY on WT-Redesign-2 (EB4328A1-87BD-4850-A3B2-A6E604701F1C), derived data
/tmp/wt-r14-codex. Do not archive, upload, deploy or push. Modify nothing but the report:
work-record/release/codex-review-0.2.0-build-14.md, ending with exactly "Verdict: clear" or "Verdict: not clear".
