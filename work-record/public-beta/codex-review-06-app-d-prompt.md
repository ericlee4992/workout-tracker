Round 4: re-review public-beta ticket 06's app half (branch ericlee4992/beta-06-ai-proxy-app, HEAD after 8ec380e) for
your round-3 findings C1 and C2 (codex-review-06-app-c.md). Claude's response is the ticket's *Codex review 06-app-c —
response (round 3)*; the diff since your review is `git diff 8ec380e..HEAD`. Check both are closed in code and
tests, that the UI-test-only sample sign-in (`completeSampleSignIn`, `-uiTestSampleSignIn`) cannot run outside the
sample store / `-uiTestReset`, and that nothing regresses.

Evidence (root /tmp/wt-floodlight/results/06app/): `build6.log`; `unit5.xcresult` (992/992); `ui4.xcresult` (the two
session UI tests on this build, 2/2); `ui3.xcresult`/`ui3.status` (the five affected classes on the round-2 build —
read `ui3.status` when present).

Do not run builds, simulators or devices, and do not call the deployed server; modify nothing but your report. Write
work-record/public-beta/codex-review-06-app-d.md with Standards and Spec sections, findings ranked P1–P3 with
file:line, ending with exactly "Verdict: clear" or "Verdict: not clear".
