# Codex release review — 0.2.0 (12)

Reviewed 2026-11-12 on `ericlee4992/release-0.2.0-12`, HEAD
`1b5493536a467a51e2eace5968df0931b4948efd`, using `git diff a3ae3f70..HEAD` and the release record.
The checkout was clean at the start. No findings.

## Standards

All **10/10** native-target/configuration pairs have `CURRENT_PROJECT_VERSION = 12` and
`MARKETING_VERSION = 0.2.0`: app, widget, Watch, unit tests and UI tests, each Debug/Release.
Parsed target/configuration audit: `/tmp/codex-r12/versions.json`. The newly built simulator app, widget and unit-test
bundle plists also report **0.2.0 (12)**. Watch configuration was checked; its binary was not built.

The What's New permission line names only Scan Machine, exercise suggestions and Ask AI for Templates. This matches
D83/D85 and does not promise a prompt for food scanning or goal generation. The updated tests pin all nine items
and retain the UI assertion that the last item scrolls wholly above Continue. No assertions were weakened.

## Spec

The entry changes from build 11 to **12**, with the recorded title and nine lines. Six previous lines are retained
verbatim; the two replacements and one added permission line match the release record exactly. The change does not
silently discard the food, body-weight, visual-update or workout-performance information.

The unchanged decision/dismissal path behaves as required:

- Last-seen **10 or 11**, running build 12: select entry 12 with all nine items.
- Dismissal records **12**, so subsequent launches show nothing. As before, exiting before dismissal can show it again.
- Fresh install: show no notes and record baseline 12; after completing setup, no notes follow it.

Verified these cases with a temporary executable containing the current checked-in `WhatsNew.swift` and isolated
UserDefaults: `/tmp/codex-r12/WhatsNewRepro.swift`, `whatsnew-repro`, `whatsnew-repro.log`. The app's existing
on-dismiss marker and fresh-install baseline handling are unchanged.

### Cancellation-test rewrite

`GeneratedGoalsTests.aCancelledAskIsNotAFailure` still proves the intended behavior. It confirms the generator
started, cancels the pending request, waits for completion, asserts there is no pending state, cached failure or
cached plan, then verifies a second generator invocation succeeds.

The first generator can no longer return a successful plan after a finite 30-second delay: its only exit is a
throw from cancellation. That removes the former timing-dependent success outcome. The startup wait yields with
short sleeps and retains a bounded failure guard; it is not relying on the request finishing after a chosen delay.
The assertions are stronger (`asked == 1` before cancellation), not weaker. This remains a cancellation-then-retry
test, rather than a test of overlapping cancellation/navigation interleavings.

Inspected `/tmp/r12-iter.xcresult`: **12 tests × 10 repetitions = 120/120 passing runs**, no failures or skips.
The cancellation case specifically has **10/10 passing repetitions**. Summary and test tree retained in
`/tmp/codex-r12/author-iterations-summary.json` and `author-iterations-tests.json`.

## Verification

- Ran simulator preparation first on WT-Floodlight `9E822EF6-DC67-4958-AEA2-D53D2D36D674`.
  Independent runner `/tmp/codex-r12/run.sh`, PID **41975**, completed; fresh derived data `/tmp/codex-r12/dd`.
- Independent **build-for-testing**: **exit 0**, `/tmp/codex-r12/build.log`, `build.status`.
- Independent **Unit plan**: **1341/1341**, no failures or skips, **exit 0**, `/tmp/codex-r12/unit.xcresult`.
  Checked the actual status file and xcresult summary (`unit-summary.json`). The rewritten cancellation test passed
  in this full Unit run as well as in the supplied repeated run.
- **Inspected UI, not rerun**, as requested: `/tmp/r12-wn.xcresult` records AAAWarmUpUITests +
  FloodlightWhatsNewUITests **6/6**, no failures or skips. Both supplied UI/iteration logs have
  `TEST EXECUTE SUCCEEDED`; their release record reports exit 0. Summaries were read directly from both xcresults.
- Exported the supplied What's New captures to `/tmp/codex-r12/captures/`, with readable names in `captures-named/`.
  Inspected light/dark default and scrolled AccessibilityL captures. Nine items require scrolling; the final
  permission line is legible above Continue after scrolling, and Continue remains reachable. No reason found
  to repeat the UI run.
- Checked version metadata, approved strings, the full diff and `git diff --check`. Only this report was written
  in the checkout; no commits, deployments or live-account requests were made.

Verified: independent build — exit 0; independent Unit — 1341/1341, exit 0,
`/tmp/codex-r12/unit.xcresult`; supplied UI artifact inspected — 6/6; supplied iteration artifact inspected —
120/120 runs, including cancellation 10/10; version/copy/gating audits and captures.

Not verified: Release archive/upload, App Store Connect processing, phone installation/Gate S, Watch binary,
signed-in goal generation from a device, independent UI rerun or full UI suite. Gate S remains required before
build 12 reaches the phone because it carries N14's stored-format change.

Known flaky: the release record reports a failure of the previous finite-delay cancellation test. The rewritten
test passed the supplied ten repetitions and this independent Unit plan; no current-version flake was observed.

Standards: 0 findings. Spec: 0 findings.

Verdict: clear
