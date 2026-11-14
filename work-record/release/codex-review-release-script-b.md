# Release script and agent guide — Codex review, round 2

Reviewed 2026-11-14 on `ericlee4992/release-script-agents`, HEAD
`5a5559558ca236e5ad475d6ed2998fb934f52c23`, diff `fcbf4c0d..HEAD`. Starting checkout was clean. Only this report
changes repository content. No archive, upload, deployment, phone access or Apple-account interaction was performed.

## Standards

1. **P2 — Include build 11 in the pending Gate S condition.** `docs/STATE.md:25–26` now requires Gate S before
   installing build 12 or later only “if the phone is still on build 10 or older”. Build 12 introduced a stored-format
   change **on top of build 11**: the build-12 release record explicitly requires Gate S, and N14's ticket
   (`work-record/nutrition/issues/14-ai-goals.md:78–82`) records build 11's `d339bba6…` fingerprint changing to
   `9d83c203…` and migration from `Build11.store`. A phone on build 11 also needs that backup before installing
   12/13/14. Change the condition to “build 11 or older”, or describe it in terms of the installed store format.
   This is a new error in the otherwise useful restored phone-check bullet.

The four round-1 documentation findings are otherwise resolved:

- Role wording preserves T6's recorded default and distinguishes explicit ticket assignments/recent practice.
- The privacy self-check is scoped to sharing beyond approved decisions and names D85's exception.
- CI dates/counts match the previously retrieved 216-run history, and unfamiliar failures still require review.
- Active STATE again names P1, Generate Goals and Korean-food device checks with working links; only the Gate S
  threshold above needs correction.

Relative links in AGENTS, DEVELOPMENT and STATE resolve. Diff whitespace and shell syntax checks pass.

## Spec / script correctness

No remaining script finding. The two round-1 archive defects are resolved and independently exercised:

- `WTServerURL` must exactly equal the production endpoint parsed from `Config/Shared.xcconfig`.
- The expected embedded `WorkoutTrackerWidget.appex` must exist and have `<app identifier>.widget`; app and widget
  versions/builds are checked.

`archive` calls the shared `check` before printing `ARCHIVE OK`. The existing Google-client and signing-team
checks remain in place. Upload now recognizes exit 0 plus “Upload succeeded” before inspecting account-error
text, addressing the previous mixed-warning robustness note. DEVELOPMENT describes the script accurately.

## Verification

Executed the **new branch's script** by absolute path with the detached `release-build` checkout as its working
directory, so the checks read that checkout's existing version and signing configuration. Used only the authorized
`check` command against the existing archive:
`/tmp/r14-release/Stacked-0.2.0-14-20634c0f.xcarchive`.

| Case | Result |
|---|---|
| Original build-14 archive | exit 0, `CHECK OK` |
| Copy with staging HTTPS server | exit 1, production-server mismatch |
| Copy missing the expected widget | exit 1, missing-widget error |
| Copy with wrong widget identifier | exit 1, identifier mismatch |
| Copy with widget build 999 | exit 1, expected 0.2.0 (14) mismatch |
| Copy restored to its original contents | exit 0, `CHECK OK` |

All six checks matched their expected exit and message. Only a reviewer-created temporary archive copy was
modified, then removed. The original app/widget plist SHA-256 hashes were unchanged before/after; the original
archive was retained. Logs and `results.json` are in
`/var/folders/f_/qhy5xsds1h9bs0wf1wkdnx9w0000gn/T/release-script-r2-review-vqb3s0r3/`.

Also independently ran:

- `bash -n scripts/testflight.sh`: exit 0.
- No arguments, missing `check` argument, nonexistent `check` path, and missing `upload` argument: all exit 1 with
  usage guidance, before account operations.
- `git diff --check fcbf4c0d..HEAD`: exit 0.
- Relative file-link check for the three edited guides: none missing.

ShellCheck remains unavailable. No real or mocked archive/upload execution was performed. Upload's success and
account classification were reviewed statically; the author's stand-in results were not independently rerun.
No app build or simulator tests are warranted by this script/documentation-only round.

Verified: six archive-check cases, syntax, safe argument paths, links, whitespace, and resolution of all prior findings.
Not verified: actual archive/upload execution; mocked upload outcomes; account/signing changes; phone behavior;
              corrected Gate S threshold above.
Known flaky: none exercised.

Standards: 1 new P2. Spec: 0 findings.

Verdict: not clear
