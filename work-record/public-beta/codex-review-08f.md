# Codex independent review — ticket 08, round 6

Reviewed 2026-10-15 on `ericlee4992/beta-08-testers`, HEAD `c7d47dd6bc63f8dc52a80f2ab4c162487c0c6816`, using `git diff f14607e..HEAD`. The working tree was initially clean. Read STATE, the ticket's response to 08e, the three open findings and the changed decision/procedure/code. Checked the sole changed policy sentence against the restore instructions. STATE still describes round 4; Git and the ticket establish this round's scope.

No new findings. The numbered entries below close 08e's open findings; their severities identify the resolved issues. Only this report was edited. No service API calls, wrangler commands, phone/Apple-account/backup-directory access or desktop control were performed.

## Standards

1. **08e #1 (P2) — closed.** **Locations:** `server/scripts/feedback.mjs:34–35,68–89`; `server/README.md:166–169`. Cleanup now removes copies **15 days old or older**, inclusively, and the operating rule requires a run at intervals no longer than 15 days while downloads exist. The download session must record the next cleanup date in STATE. Together these support the policy's 30-day maximum: a file just short of the age threshold at one run is removed by the next run, no more than 15 days later. The exact-threshold case is also fixed. Age deletion still precedes the database query; a query failure keeps only younger copies. **Verification:** evaluated the actual function and constant with an in-memory filesystem, clock and database stub. The 14/15/20-day boundary, staggered runs just before days 15 and 30, database failure, missing feedback and local-mode liveness isolation all passed. No further correction requested. This is code plus a manual operating commitment, not an installed background scheduler; clearance depends on following that recorded cadence.

2. **08e #2 (P2) — closed against the revised restore promise.** **Locations:** `server/README.md:136–151`; `server/src/pages.ts:137–141`. Step 4 now deletes **every restored session**, so a session deleted by sign-out cannot regain validity merely because it was unexpired in the backup. This supports the added policy phrase “sign everyone out.” The procedure preserves evidence before restore, reconciles accounts, feedback and training profiles, reruns retention, then takes a second evidence export and repeats the account/feedback/profile comparison before switching. It expressly acknowledges the remaining gap and requires notifying affected testers, or all testers when the affected set is unknown. The page promises reconciliation of identifiable deletions and notification about uncertainty; it no longer promises that deleted data can never reappear. The procedure supports that narrower statement. No further correction requested. The AI pause is not a freeze of all writes, the second export does not eliminate the final gap, and an in-place restore is not isolated from traffic; those limitations are covered by the revised reappearance/notification terms rather than treated as solved by the two exports. This is a procedure review, not evidence of an executed restore.

## Spec

3. **08e #8 (P2) — closed.** **Location:** `docs/DECISIONS.md:217`. D61 now separates the user's supplied answers from Claude's proposed operational terms, explicitly marks those proposals as awaiting approval with the wording, preserves the earlier stronger download/restore commitments, explains why they were narrowed, and names the reviews that prompted the changes. The relaxed terms are no longer presented as settled user choices. No further correction requested. Their approval remains the existing release gate; this review does not supply it.

## Verification and remaining release gates

- Targeted in-memory checks exercised this round's changed cleanup logic without accessing actual downloads or executing the CLI's wrangler wrapper. `git diff --check f14607e..HEAD` passed.
- The server request handlers, session/feedback sweep implementations, configuration and test files are unchanged from round 5. The personally observed **225/225 passing server tests** recorded in 08e remain the relevant server evidence; the full suite was not repeated for the CLI threshold and documentation changes. The cron query bound remains 38. No app build or UI/device run was performed.
- The only policy-text change in this diff adds global sign-out to the restore paragraph; step 4's deletion of every session supports it. The prior fixes for local/production download separation, training-profile wording, session-record expiry, support-page exceptions and menu directions remain intact.
- Clearance is for the reviewed source, wording and written procedures. It is not confirmation of user approval, deployment, an operational cleanup schedule, a rehearsed restore, installed build 5 or completed App Privacy answers. The intentional effective-date placeholder and the remaining release gates recorded in 08d/08e still apply.

Standards: 0 open findings; both prior findings closed. Spec: 0 open findings; the prior finding closed. All three findings carried forward from round 5 are resolved.

Verdict: clear
