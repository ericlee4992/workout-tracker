# Release script and agent guide — Codex review

Reviewed 2026-11-14 on `ericlee4992/release-script-agents`, HEAD
`fcbf4c0d50ec10ea03ca28e465b04e10c3161def`, diff `1ba3d93c..HEAD`. Starting checkout was clean. Reviewed the brief,
release records, DEVELOPMENT, AGENTS, STATE, decisions and relevant source/review history. Only this report changed.

## Standards

1. **P2 — Reconcile the implementer default with the decision being cited.** `AGENTS.md:62` says Claude implements
   and Codex reviews, while `docs/DECISIONS.md:74` (T6) explicitly says the user's default is Codex implements,
   Claude reviews. Following both sources now gives contradictory assignments. If the new default is intended,
   explicitly update T6 with its reason/current authorization while retaining independent review in either
   direction; otherwise retain the existing default. Do not cite T6 as supporting the opposite rule.

2. **P2 — Qualify the privacy self-check so it does not prohibit approved goal generation.** `AGENTS.md:75–76`
   lists Health **or personal data reaching an AI prompt/server** as a defect without qualification. D85 expressly
   sends signed-in goal-setup answers to generate nutrition goals; `server/src/pages.ts:40–41,107–109` describes
   sex, age, height and app-entered weight in that approved payload. An agent applying this checklist literally
   could remove or block intended behavior. Check for **unauthorized** disclosure and scope the separate Health-data
   prohibition accurately; cite the goal-setup exception. This correction does not require changing D85 or adding
   a new permission flow.

3. **P3 — Make the CI history statement match the retrieved evidence.** `AGENTS.md:113–116` says “216 runs since
   2026-09” and describes cancellations as hangs. `gh run list --workflow tests.yml --limit 1000` returns **216**
   runs beginning **2026-08-18**, with **143 failures and 73 cancellations**; **201** are since September. No run
   succeeded, so that central claim is supported. Cancellation alone does not establish a hang—the workflow also
   cancels superseded runs. Use the actual dates/statuses (or a less brittle dated summary). Limit the “red is not
   news” guidance to the known failure signature rather than implying new failure modes can be ignored.

4. **P3 — Keep outstanding phone checks explicit in the active handoff.** `docs/STATE.md:12–25` replaces the old
   pending checks with a generic reference to earlier releases' steps, then lists strings and App Privacy as open.
   The first signed-in Korean search/barcode, first signed-in Generate Goals request, and P1 phone checks
   (acceptance 1–2) remain unverified in the preserved old RESUME block; no completion evidence was added here.
   They now sit only in the section labelled superseded. Add a compact current bullet naming these still-open
   checks, with links to their tickets/release records. Keep the old text as history, but do not make future sessions
   infer current obligations from superseded instructions.

The other guide changes are supported: D23/D52/D67, the Models/Nutrition delete rules, CLAUDE.md's AGENTS import,
and Paseo tooling agree with the documented behavior. The self-check categories are grounded in this repository's
findings—e.g. live-workout 03's wrong entry/draft names, N15's partial matching and overwritten weight, P1's typed
values/history reads, N1's recovery failures, and N14's privacy/preview issues. The privacy wording in #2 is the
overgeneralization, not a reason to remove the checklist.

## Spec / script correctness

5. **P2 — Verify the approved production endpoint, not merely HTTPS.** `scripts/testflight.sh:71–75` accepts every
   `https://` URL except those containing lowercase `localhost` or `127.0.0.1`, then prints “production https”.
   A leftover Local.xcconfig override pointing to a staging Worker, HTTPS tunnel or private host therefore passes
   `ARCHIVE OK`. `Config/Shared.xcconfig:19–21` explicitly allows a local override and identifies the production
   Worker. Compare the archived URL against the approved production endpoint (or an explicit trusted allowlist),
   and reject mismatches. DEVELOPMENT step 4 currently promises a stronger check than the script performs.

6. **P2 — Require the widget before accepting the archive.** `scripts/testflight.sh:62–63` silently skips an
   unmatched `PlugIns/*.appex` glob. If the embed-widget build phase is removed or misconfigured, an archive with
   only the app still passes all subsequent checks and prints `ARCHIVE OK`. Require the expected widget bundle
   and its identifier, then verify its version/build. Checking whichever extensions happen to exist does not
   fulfill the documented app-and-widget check.

The export-options construction otherwise matches the working build-13/14 records: `app-store-connect`, upload,
automatic signing, validated team ID, and `manageAppVersionAndBuildNumber=false`. It is generated under `mktemp`,
linted and removed on exit; no team value is hard-coded into the new repository files. The upload command's status
is captured outside `errexit`, and ordinary command/marker failures are handled. The archive's existing app version,
Google-client presence and signing-team comparisons are sensible, subject to the missing guards above.

Non-blocking robustness note: account-error text is tested before exit 0 plus “Upload succeeded” (`:115–120`). A
mixed warning/success log would produce exit 2 and invite a redundant retry. Consider prioritizing authoritative
success before classifying failed attempts. The available release records do not establish that mixed-log case,
so this is not counted as a finding.

## Verification

- Independently ran `bash -n scripts/testflight.sh`: exit **0**.
- Independently ran the no-argument, `--help`, missing-upload-argument and nonexistent-archive paths: each exited
  **1** with usage guidance, before signing/account commands. ShellCheck is **not installed**.
- `git diff --check 1ba3d93c..HEAD`: exit **0**.
- Checked relative file links in AGENTS, DEVELOPMENT and STATE: **none missing**.
- Compared the old RESUME block to its archived copy: all content is preserved after removing the added nesting
  indentation and blank-line differences. It is not byte-identical, but no old bullet text was lost; #4 concerns
  which outstanding work remains current.
- Inspected every Models.swift/Nutrition.swift `@Relationship` rule cited by the guide; cascade/nullify descriptions
  agree with source. Read the release records and checklist against the script.
- Queried CI directly: 216 Tests runs, 143 failed/73 cancelled/0 successful. The
  [latest Tests run](https://github.com/ericlee4992/workout-tracker/actions/runs/43544209014) uses **Xcode 26.6** and
  reports a failed `LiveSetRow.swift` compile command; its artifact upload also timed out. This supports the known
  runner-build problem, not a diagnosis of every historical failure/cancellation. The latest **five Server runs
  succeeded**, including [the latest Server run](https://github.com/ericlee4992/workout-tracker/actions/runs/43544208747).

No app build or simulator suite was warranted for this script/documentation-only change. Per the brief, I did not
run archive/upload paths, including mocked archive/upload execution, or access a phone/Apple account. The author's
reported real archive and mocked-upload outcomes were not independently repeated; #5–6 are source-level guard
failures, not claimed runtime archive reproductions.

Verified: shell syntax; four safe argument paths; diff whitespace; relative links; preserved STATE content;
          decisions/model/tooling consistency; live CI history and relevant run logs.
Not verified: real or mocked archive/upload execution; signing/account interaction; ShellCheck; runtime negative
              cases for the new guards; phone/device behavior.
Known flaky: none exercised; historical CI failures/cancellations are described above, not treated as passing tests.

Standards: 4 findings (2 P2, 2 P3). Spec: 2 findings (both P2).

Verdict: not clear
