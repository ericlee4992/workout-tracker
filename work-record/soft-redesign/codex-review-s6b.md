# Soft redesign S6 — independent Codex review, round 2

Reviewed 2026-11-09. Claude implemented; Codex reviewed `git diff 17d8aef..c452791` against D80 and the S6 ticket’s
“Regrouped” section. Target `c4527919849d064d1c73f85386d1f67aeffd739f`; checkout `ericlee4992/soft-06-profile` was clean at `efe4b19`, which changes
only STATE after the target. Builds/tests use a pinned snapshot under `/tmp/codex-s6b/source/`. Only this report
was written in the repository; no implementation changes, commit, push or merge.

## Spec

**No findings.** The account card is followed by Goals & tracking (Heart rate zones), Settings (Preferences,
Ask AI, Export & backup), Help and version, as D80 requires. The zone row retains its action, status and identifier.
Preferences uses the same title constant for the row and its destination. Personal details is expressly N3 work,
recorded in its ticket; it is correctly absent from S6. Account/Help presentations, export/safety-copy access and
all Preferences controls remain connected. Updated UI-test comments follow the rename; helpers still use unchanged
identifiers. Runtime checks support these routes, with the known parallel-clone failure rerun serially as recorded below.

**Spec: 0 findings.**

## Standards

**No findings.** The new grouping uses the existing Soft components and accessibility layout; it adds no
new persistence or dependencies. ProfileRow still exposes one button label, with values below titles at accessibility
sizes. The account remains the leading content element. D80 is the explicit user-approved change to the earlier
prototype grouping; it is not an unexplained departure. Goals & tracking and Preferences are recorded in the ticket.
No unrelated modernization or heuristic refactor requested.

**Standards: 0 findings.**

## Captures

Read both author contact sheets in `s6-caps2/` and inspected full-resolution signed-in Profile in light/dark at
Default/AccessibilityL, signed-out Profile in light/dark AccessibilityL, scrolled Profile lower content, Preferences
in all four combinations including lower accessibility pages, and the actual tour step 8 in light/dark Default and
dark AccessibilityL. Labels are whole, values stack, the lower export notice/Help/version remain reachable by
scrolling, and the tour caption/highlight/Done control fit. Also exported and inspected the independent run’s Profile top/lower content and Preferences at light AccessibilityL,
and Profile/Preferences at dark Default (`/tmp/codex-s6b/captures/`). These match the reviewed author renders; no
visual regression was found.

## Verified

WT-iPhone27 `47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`, iOS 27.0. Simulator preparation exit 0. Commands/logs/results:
`/tmp/codex-s6b/`; `verify.sh`, runner PID 44151. Existing Orca progress tab reused; no new terminal. Support,
Preferences and Documents were backed up before testing.

- Rebuild for testing: exit 0, succeeded, 0 errors, 31 warnings (`build.xcresult`, `build-summary.json`).
- Unit plan, serial: 1163/1163, no failures/skips, exit 0 (`unit.xcresult`, `unit-summary.json`).
- Initial requested UI scope, three workers: **32 passed / 1 failed / 0 skipped out of 33**, **exit 65**, about
  15 minutes (`ui.xcresult`, `ui-summary.json`). The failure is the known share-sheet Close-button timeout, detailed below.
- Serial rerun of AAAWarmUpUITests and the failed case: **2/2 passed**, no failures/skips, **exit 0**
  (`ui-serial.xcresult`, `ui-serial-summary.json`; `serial.sh`, PID `53302`, completed). No source or test changes
  were made between runs.
- Original simulator Application Support, Preferences and Documents restored while shut down; exact file/hash
  equality passed before and after reboot (`restore-original.json`, `restore-original.status` **0**).

Exact UI scope is recorded in `ui-scope.json`: AAAWarmUpUITests, FloodlightSettingsUITests,
FloodlightProfileUITests, FloodlightTourUITests, HeartRateUITests/testZonesAreReachableFromSettings and
RedesignScreenshotUITests/test05_settings; initial run uses three workers.

Author `s6-ui2.xcresult` under
`/private/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-UI-design/f473a23d-3eaa-41a2-9817-2ebe24bda24e/scratchpad/`
was read directly: 34 passed,
0 failed/skipped. The extra case beyond this requested 33-test scope is RedesignScreenshotUITests/testUnitSystemDefault.
The ticket records exit 0; no standalone numeric shell-status file was present. Independent counts/exits above come
from our own xcresults and shell-status files.

## Not verified

No physical-device, human VoiceOver/Full Keyboard Access or live-service check, and no full UI suite beyond the named
scope. Personal details, nutrition goals and N9 rows remain future work. Round 1 covers unchanged adjacent flows;
this report does not re-approve future implementation or substitute for the user’s remaining wording/merge approval.
No phone installation, merge or release is claimed.

## Known flaky

`FloodlightSettingsUITests/testTabRoundTripDropsTheFileCard` failed on parallel clone 2 at
`FloodlightSettingsUITests.swift:84`, inside `cancelShareSheet()`, waiting for the system
`header.closeButton`. Per-test xcresult details confirm the same failure location recorded in round 1; the test
passed unchanged in the required serial rerun. Treat this as the known parallel-clone share-sheet flake, not a
regrouping defect. The other 32 requested cases passed initially.

Unit results contain 55 runtime warnings. Initial and serial UI results contain none. The 31 build warnings have
no locations in changed files. No additional failure was ignored or waived.

Spec: **0 findings**. Standards: **0 findings**. Clear for `c452791`; the later STATE-only commit does not change the reviewed product.

Verdict: clear
