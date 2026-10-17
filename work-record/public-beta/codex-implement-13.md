# Ticket 13 implementation — replacement design, 2026-10-17

Stopped after the one attempt permitted by `codex-implement-13b-prompt.md`. The replacement design did not pass
keyboard-layout verification. This is an implementation blocker report, not independent clearance.

## Changes

- AIGoalsStep draws its own compact GlassCapsuleButton Done (`dismissRoutineKeyboard`) while a field is focused;
  removes its keyboard toolbar; puts Next in a separate keyboard-ignoring bottom overlay.
- Keeps Return → end editing, `.submitLabel(.done)`, and newline normalization (pasted line breaks become spaces).
- Reverts tap-outside/control dismissal, ScrollViewReader, notifications, field IDs and `safeAreaInset` experiments.
  TrainingProfileEditor, its added regression, and README match `2dd305c` byte-for-byte.
- Updates Goals tests for the replacement behavior; keeps AskAI's exact-value wait and Return helper. Updates the
  ticket's decision/acceptance/progress and corrects STATE's `main` to `df6f0bc`. Other screens' toolbar risk remains
  an explicit follow-up. No domain, storage, server, phone or App Store Connect changes; no merge.

## Commands and results

Xcode **27.1 (27A9275)**; WT-iPhone27, iPhone 15 Pro Max, iOS **27.0**, device
`47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`. Artifact root `/tmp/wt-beta13-20261017-r10/`.

```sh
defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool false
xcodebuild -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -sdk iphonesimulator \
  -configuration Debug -destination 'platform=iOS Simulator,id=47D21838-69A6-4BCB-AE90-B0D9C0AAA70B' \
  -derivedDataPath /tmp/wt-beta13-dd -resultBundlePath /tmp/wt-beta13-20261017-r10/build.xcresult build

xcodebuild test -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -sdk iphonesimulator \
  -configuration Debug -destination 'platform=iOS Simulator,id=47D21838-69A6-4BCB-AE90-B0D9C0AAA70B' \
  -derivedDataPath /tmp/wt-beta13-dd -resultBundlePath /tmp/wt-beta13-20261017-r10/focused.xcresult \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  -only-testing:WorkoutTrackerUITests/FloodlightAIRoutineUITests/testGoalsDoneRevealsPinnedNext \
  -only-testing:WorkoutTrackerUITests/FloodlightAIRoutineUITests/testGoalsNumberPadsHaveAppDone \
  -only-testing:WorkoutTrackerUITests/FloodlightAIRoutineUITests/testGoalsReturnDismissesWithoutANewline \
  -only-testing:WorkoutTrackerUITests/FloodlightAIRoutineUITests/testCaptureGoalsKeyboardLightDefault \
  -only-testing:WorkoutTrackerUITests/FloodlightAIRoutineUITests/testCaptureGoalsKeyboardDarkDefault \
  -only-testing:WorkoutTrackerUITests/FloodlightAIRoutineUITests/testCaptureGoalsKeyboardLightAccessibility \
  -only-testing:WorkoutTrackerUITests/FloodlightAIRoutineUITests/testCaptureGoalsKeyboardDarkAccessibility

xcrun xcresulttool get test-results summary --path /tmp/wt-beta13-20261017-r10/focused.xcresult
xcrun xcresulttool export attachments --path /tmp/wt-beta13-20261017-r10/focused.xcresult \
  --output-path /tmp/wt-beta13-20261017-r10/attachments
defaults delete com.apple.iphonesimulator ConnectHardwareKeyboard
defaults read com.apple.iphonesimulator ConnectHardwareKeyboard
```

Build/test stdout and stderr were redirected to `build.log` / `focused.log`; each actual exit code was saved to
`build.status` / `focused.status` without a pipeline. Build **exit 0, `** BUILD SUCCEEDED **`**. Focused tests
**exit 65, `** TEST FAILED **`, 7 tests: 1 passed / 6 failed / 0 unexpected / 0 skipped**. Read the final lines
and xcresult summary personally. Build exec session 29624 and test session 2762 are finished.

1. Return-dismiss passed, including unchanged goal text and hittable Next after dismissal.
2. All four Goals capture tests failed the app Done's distance from the reported keyboard: **52 pt**, test maximum
   **20 pt**. Earlier checks found one hittable Done, software keys and keyboard height >200 pt.
3. The fixed-Next test found its resting y=834 unchanged, but keyboard top reported y=976 (below the 932-pt screen).
   The test failed before tapping Done. This inconsistent geometry does not establish correct keyboard behavior.
4. Height's bounds were **y=518…562**, Done **y=559…603**; the field failed the entirely-above-Done assertion.
   Weight was not reached.

The subsequent preference read confirms the key is absent, restoring the original state (recorded in
`keyboard-preference-after.txt`). `git diff --check` and the staged secret check pass. Source scope was checked
against `2dd305c`; the product change is confined to AIGoalsStep.

## Captures and remaining work

Opened and looked at all four PNGs in [captures/13](captures/13/README.md):

- `captures/13/beta-13-goals-keyboard-light-default.png`
- `captures/13/beta-13-goals-keyboard-dark-default.png`
- `captures/13/beta-13-goals-keyboard-light-axl.png`
- `captures/13/beta-13-goals-keyboard-dark-axl.png`

They show Goals and fixed Next, but **neither software keys nor Done** despite AX assertions. They are explicitly
labelled failed-attempt evidence, not valid keyboard captures. The prior r4 images were moved to
`/tmp/wt-beta13-20261017-r10/rejected-r4-captures/`. No weight-focused or intentional keyboard-closed capture was
reached. Do not infer the rendering cause from these observations alone.

Per the user's stop rule, no further layout variant, relaxed assertion, rerun or broader suite was attempted.
AskAIUITests, the full FloodlightAIRoutineUITests and FloodlightProfileUITests remain unrun for this replacement;
old-design results do not validate it. No independent review, merge or phone installation. A new user direction
is required before further implementation.

Branch: `ericlee4992/beta-13-goals-keyboard`. Final implementation commit: `915b84ec8681673a6b203d7f609c1dbddbab0738` (pushed).
The handoff adds only this report, ticket/STATE updates and failed-attempt captures; the commit containing this
report is the final documentation checkpoint (`git log -1 --format=%H -- work-record/public-beta/codex-implement-13.md`).

Status: blocked — first replacement-layout attempt failed Done/keyboard and focused-height verification
