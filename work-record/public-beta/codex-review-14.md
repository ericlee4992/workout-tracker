# Ticket 14 — What's New review

Reviewed `git diff 63a6058..5aff73c` at HEAD `5aff73c00d2de26ac6417aaa54425c16d0a10144` against ticket 14, D62,
the TestFlight checklist, onboarding behavior and the iOS design rules. Ticket 16's cleared implementation was not
re-reviewed beyond the changed Most used glyph.

1. **P2 — Unknown store counts do not consistently fail closed.**
   **Location:** `WorkoutTracker/App/WorkoutTrackerApp.swift:214–221`; `WorkoutTracker/Domain/WhatsNew.swift:49`.
   Replacing each failed count with 1 does not guarantee the documented "nothing shown, nothing recorded" result.
   If the all-workout query fails but the unfinished query succeeds with zero, the app treats the install as
   established and can show pending notes. Conversely, with welcome unanswered, a successful zero total count and
   a failed unfinished count reach the fresh-install branch, which records the build before checking
   `workoutInProgress`. **Fix:** require both count fetches to succeed before calling the decision function, returning
   without presentation or persistence otherwise. Cover each query failing independently; ensure the live-workout
   deferral takes precedence over immediate recording.

2. **P2 — Unanswered onboarding can request Welcome and What's New simultaneously.**
   **Location:** `WorkoutTracker/Domain/WhatsNew.swift:49–54`;
   `WorkoutTracker/App/WorkoutTrackerApp.swift:169–177,217–223`.
   A fresh build 7 launch records last-seen 7 before Welcome is answered. If the user terminates there and later
   updates to a build with a newer entry, Welcome is still required: the key is false and there are no workouts.
   However, `decide(currentBuild: 9, lastSeen: 7, freshInstall: true, workoutInProgress: false)` returns entry 9,
   because the fresh-install suppression only applies when last-seen is nil. The same appearance callback thus
   sets both `showsWelcome` and `whatsNew`, requesting competing modal presentations. **Fix:** give the
   unanswered-welcome condition precedence even with an existing baseline, while recording monotonically and
   respecting unknown-count/live-workout deferral. Add this interrupted-onboarding/update case using the existing
   build-7/build-9 fixtures, plus a presentation-level check that only the welcome flow is requested.

3. **P3 — The AccessibilityL evidence does not establish that the last item is fully readable.**
   **Location:** `WorkoutTrackerUITests/FloodlightWhatsNewUITests.swift:35–41`;
   `work-record/public-beta/captures/14/whatsnew-14-{light,dark}-axl.png`.
   Both supplied AccessibilityL captures partially hide the final "remove it." line behind Continue. The content
   is a ScrollView, so this is not proof that the text is unreachable, but the capture test never scrolls or verifies
   that final line above the pinned button. The iOS design capture rule requires every content block shown whole.
   **Fix:** scroll the last item fully into the visible area, assert its bottom is above Continue, and retain an
   additional light/dark AccessibilityL capture demonstrating that state.

Other checked behavior: normal build-6 upgraders with an answered welcome or existing workouts qualify for entry 7;
fresh first launches establish a baseline; seen entries do not repeat on later entry-less builds; ordinary pending
entries defer while a workout is unfinished. Dismissal recording is monotonic and occurs in the automatic sheet's
`onDismiss`, covering Continue and swipe dismissal. A fresh welcome-to-tour return retains the recorded baseline.
The production lifecycle is not exercised by the forced `-uiTestWhatsNew` path; the current tests therefore do not
cover the count errors or competing-welcome case above. Optional UI execution was skipped, so live-cover/finish-sheet
reappearance ordering was not runtime-verified in this review.

Inspected all four committed PNGs. Default layouts show the approved copy, Continue is the sole prominent action,
the title has a header trait, decorative glyphs are hidden from VoiceOver, and identifiers match the tests. The
newspaper Settings glyph and star for Most used avoid the AI meaning of sparkles. README and DEVELOPMENT describe
the implemented surface and entry-authoring procedure. Under `-uiTestReset`, the key is cleared and automatic
presentation requires the explicit What's New argument, preserving existing tests' ordinary launch behavior.

Verification personally performed with **Xcode 27.1 (27A9275)** on **WT-Floodlight, iOS 27.0**:

```sh
xcodebuild -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -sdk iphonesimulator \
  -configuration Debug -destination 'platform=iOS Simulator,id=9E822EF6-DC67-4958-AEA2-D53D2D36D674' \
  -derivedDataPath /tmp/wt-review16-dd -resultBundlePath /tmp/wt-review14-20261017/build.xcresult build

xcodebuild test -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -sdk iphonesimulator \
  -configuration Debug -destination 'platform=iOS Simulator,id=9E822EF6-DC67-4958-AEA2-D53D2D36D674' \
  -derivedDataPath /tmp/wt-review16-dd -resultBundlePath /tmp/wt-review14-20261017/unit.xcresult \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  -only-testing:WorkoutTrackerTests/WhatsNewTests
```

Build: **exit 0, BUILD SUCCEEDED**. Unit suite: **exit 0, TEST SUCCEEDED; 6 passed / 0 failed / 0 skipped**, confirmed
from actual status files, logs and `xcresulttool get test-results summary`. Artifacts:
`/tmp/wt-review14-20261017/{build,unit}.{log,status,xcresult}`. `git diff --check` passed. Only this report was added;
no commit, push, phone installation or server action.

Verdict: not clear
