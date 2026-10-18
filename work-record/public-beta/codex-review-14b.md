# Ticket 14 — review, round 2

Reviewed `git diff 5aff73c..803f425` against all three prior findings and the ticket's response.
HEAD: `803f425a1b8af744cf3f3b8a1e63e053b4e628e3`. No remaining findings in the reviewed fixes.

1. **Prior P2 #1 — resolved.** **Location:** `WorkoutTracker/App/WorkoutTrackerApp.swift:214–225`;
   `WorkoutTracker/Domain/WhatsNew.swift:53–56`.
   Both workout-count fetches must now succeed before a decision or persistence occurs; either error returns without
   showing or recording notes. The decision function also checks a workout in progress before baseline recording.
   The new precedence test covers the previously unsafe combination of unfinished workout and unanswered welcome.
   Fetch-error handling was verified by source inspection, not injected store failures.

2. **Prior P2 #2 — resolved.** **Location:** `WorkoutTracker/Domain/WhatsNew.swift:55–59`;
   `WorkoutTracker/App/WorkoutTrackerApp.swift:222–224`.
   The caller reuses the welcome's existing rule. An unanswered welcome suppresses notes even when an older baseline
   exists, so the interrupted-build-7/onboarding-to-build-9 case requests only Welcome. Baseline persistence remains
   monotonic through `markSeen`; returning from the tour does not request that build's notes. The new regression
   explicitly covers the existing-baseline case. Normal update selection and dismissal recording are preserved.

3. **Prior P3 #3 — resolved.** **Location:** `WorkoutTracker/Features/Onboarding/WhatsNewSheet.swift:37–38`;
   `WorkoutTrackerUITests/FloodlightWhatsNewUITests.swift:43–53`.
   Items now have a combined accessibility element and identifier. The capture test checks three items, scrolls the
   last item above Continue, and asserts its bottom boundary before taking an additional AccessibilityL image.
   Personally opened both `captures/14/whatsnew-14-{light,dark}-axl-scrolled.png`: the entire final item, including
   "remove it.", is visible above Continue. Decorative glyphs remain hidden and the header trait remains intact.

No additional standards or specification regression identified. The reset-test opt-in, Settings surface, approved
copy, glyph meanings and release-note procedure remain unchanged. No further corrections requested for these findings.

Verification personally performed with **Xcode 27.1 (27A9275)** on **WT-Floodlight, iOS 27.0**:

```sh
xcodebuild -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -sdk iphonesimulator \
  -configuration Debug -destination 'platform=iOS Simulator,id=9E822EF6-DC67-4958-AEA2-D53D2D36D674' \
  -derivedDataPath /tmp/wt-review16-dd -resultBundlePath /tmp/wt-review14-20261017-r2/build.xcresult build

xcodebuild test -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -sdk iphonesimulator \
  -configuration Debug -destination 'platform=iOS Simulator,id=9E822EF6-DC67-4958-AEA2-D53D2D36D674' \
  -derivedDataPath /tmp/wt-review16-dd -resultBundlePath /tmp/wt-review14-20261017-r2/unit.xcresult \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  -only-testing:WorkoutTrackerTests/WhatsNewTests
```

Build: **exit 0, BUILD SUCCEEDED**. Unit suite: **exit 0, TEST SUCCEEDED; 8 passed / 0 failed / 0 skipped**, confirmed
from actual status files, logs and `xcresulttool get test-results summary`. Artifacts:
`/tmp/wt-review14-20261017-r2/{build,unit}.{log,status,xcresult}`. Optional UI execution was **skipped**; visual review
used the refreshed committed captures. No phone-update or live-cover/finish-sheet runtime verification is claimed.
`git diff --check` passed. Only this report was added; no commit or push.

Verdict: clear
