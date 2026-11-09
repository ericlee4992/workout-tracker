# Soft redesign S6 — independent Codex review, round 1

Reviewed 2026-11-09. Claude implemented; Codex reviewed `git diff 5f8ff92..17d8aef` on
`ericlee4992/soft-06-profile`, initially clean at `17d8aef682274c0c63830cc038321b938eb87f74`.
The later `d5cf753` changes only STATE. Independent builds/tests use a pinned snapshot under `/tmp/codex-s6/source/`.
Read AGENTS, STATE, S6 brief/ticket, Soft spec, D68, the approved `SoftProfileScreen` at
`design/soft-approved-2026-11-07`, and the code-review, SwiftUI and iOS design instructions. Spec and Standards were
reviewed independently. Only this report was written in the repository; no implementation edits, commit or push.

## Spec

**No findings.** Profile matches the approved account card → Settings → Help → version structure.
Omitting Training follows D68. Not drawing Goals & tracking until N3/N9 supply rows follows the ticket's explicit design.

Every old Settings control has a route: units/appearance/rests/template-update preference/history note on the pushed
Settings page; zones and Ask AI in their existing sheets; export counts/last export/only-copy notice and Safety copy
on Export & backup; account and Help on Profile. Restore failure remains visible directly on Profile as well.

Account deletion outcomes still reach alerts on the persistent Profile root after the account page dismisses.
Tour failures remain attached to Help while onboarding exists. Feedback construction remains tied to the current
account/session. Both only-copy notices use BackupStatus's single rule. The removed SettingsZoneLadder has no remaining
source caller; the zone details remain in the sheet.

The updated navigation helpers reach the moved pages. The export tab-roundtrip test deliberately uses openProfile,
not a helper that would repush Export & backup, preserving its retained-page assertion. The tour's no-escape check
now uses Profile's root landmark. The requested runtime scope passes, with the intentional live-feedback smoke skip recorded below.

**Spec: 0 findings.**

## Standards

**No findings.** The account remains the leading content element; peer Settings and Help rows
are grouped lists. The Soft spec's monochrome action and system type correctly supersede the older purple/Expanded
reference. ProfileRow remains a button with one title/value/subtitle label and hides decorative glyph names. Values
move beneath titles at accessibility sizes; text wraps. No unrelated modernization or smell-driven refactor requested.

README describes the new Profile structure and safety-copy route. Its existing screenshots do not depict changed
screens, so retaining them is appropriate. The new/changed visible strings are listed in the ticket.

**Standards: 0 findings.**

## Captures and evidence corrections

Viewed all four author contact sheets and full-resolution account/profile/subpage captures under the supplied
`s6-caps/` directory: signed-in light/dark Default/AccessibilityL, signed-out light Default, Profile lower content at
AccessibilityL, Export & backup in all four combinations, and Settings pages including the history note. The changed
content is readable, values stack at AccessibilityL, and scrolling exposes the lower rows/version.

The ticket's `tour-s6-*` reference is a labeling mistake: step 6 is History. The actual Profile step is **8 of 8**.
Exported and inspected `tour-s8-light-default`, `tour-s8-dark-default`, and `tour-s8-dark-AXL` from the author's result
into `/tmp/codex-s6/author-tour/`. They show the Profile title highlighted, the complete caption and reachable Done/
Skip controls. No product defect is demonstrated by the mislabeled evidence reference.

Also exported and inspected the independent run’s Profile root/top and lower content plus Export & backup at light
AccessibilityL and dark Default (`/tmp/codex-s6/captures/`). Text and commands remain readable, with lower content
reachable by scrolling. These agree with the author’s corresponding captures.

## Verified

WT-iPhone27 `47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`, iOS 27.0; preparation exit 0. `/tmp/codex-s6/verify.sh`,
runner PID 11942; all commands, logs, results and scope identifiers are under `/tmp/codex-s6/`. Existing Orca progress
tab reused; no new terminal. Simulator support/preferences/documents backed up before testing.

- Build for testing: exit 0, succeeded, 0 errors, 31 warnings (`build.xcresult`, `build-summary.json`).
- Unit plan, serial: 1163/1163, no failures/skips, exit 0 (`unit.xcresult`, `unit-summary.json`).
- Requested UI scope, three workers: **67 passed, 0 failed, 1 skipped out of 68**, **exit 0**, about 29.4 minutes
  (`ui.xcresult`, `ui-summary.json`, `ui-tests.json`). No serial rerun was needed because this run had no failures.
  The intentional skip is `FloodlightFeedbackUITests/testSmokeSendsToTheBuildsServer`, which requires
  `WT_FEEDBACK_SMOKE=1`. No real feedback was sent.
- Original simulator Application Support, Preferences and Documents restored while shut down; exact file/hash
  equality passed before and after boot (`restore-original.json`, `restore-original.status` **0**). Cleanup initially
  found the base simulator shut down after the parallel run; booting it to locate the container resolved that tooling
  precondition. This did not affect any test result.

Exact requested UI scope is in `ui-scope.json`: AAAWarmUp, FloodlightSettings, Export, FloodlightFeedback,
FloodlightTour, SafetyCopy, FloodlightAccount, FloodlightProfile, FloodlightAIAccess, FloodlightWhatsNew; plus the named
unit-system default, zones-from-Settings and cross-screen appearance tests. The initial run uses three workers.

All independent outcomes/counts above come from xcresults and shell-status files, not the provisional live log.

Author evidence read directly under
`/private/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-UI-design/f473a23d-3eaa-41a2-9817-2ebe24bda24e/scratchpad/`: `s6-ui1` has 72 passed,
1 failed, 1 skipped. Failure is `FloodlightSettingsUITests/testTabRoundTripDropsTheFileCard` in `cancelShareSheet` at
line 84, waiting for the system Close button. `s6-ui1-rerun` contains two logical tests/six executions: warm-up and the
failed case repeated three times; the target passes all three. The actual skipped case is the opt-in **live feedback smoke test**, not BackupExportUITests as the ticket says
(`s6-ui1-author-tests.json`). This is a second evidence-label correction, not a missing required UI flow. Numeric shell-status
files were absent; the ticket records exits 65 and 0 respectively. These result bundles and per-test run details were
inspected, not accepted from the ticket summary alone.

## Not verified

No physical-device check, human VoiceOver/Full Keyboard Access session, or full UI suite beyond the named scope.
Goals & tracking remains intentionally unbuilt for N3/N9. Fixture account/server flows do not establish live service
behavior. No phone installation, merge or release is claimed.

## Known flaky

The author’s parallel share-sheet Close-button failure passed its serial rerun three times and did not recur in the
independent 68-test scope. Retain it as the known parallel-clone flake; no independent failure was waived.
Unit results contain 55 runtime warnings; UI results contain none. The 31 build warnings have no source locations
in changed files. An interleaved debugger diagnostic briefly confused the live counter; the completed xcresult
confirms zero failed UI tests.

Spec: **0 findings**. Standards: **0 findings**. Clear for `17d8aef`; the later STATE-only commit does not change the reviewed product.

Verdict: clear
