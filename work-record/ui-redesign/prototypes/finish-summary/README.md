# Finish summary — native design previews

Question: should the finish sheet lead with a balanced metric recap, lifting results, or heart rate?
These are standalone, throwaway SwiftUI compositions for [ticket 17](../../issues/17-finish-summary-second-pass.md),
not production behavior. No SwiftData, HealthKit, phone data or product build is involved.

Open [comparison.html](comparison.html) to compare directions and switch between real default
and AccessibilityL screenshots, including scrolled sections. A/B/C share the same fixed
illustrative 48:12 workout. Data/math and placeholder buttons are not being tested.

`FinishSummaryPreview.swift` defines the views and Xcode previews. Its separate simulator app
reproduces the large-sheet presentation; `render.py` compiles that app with the iOS simulator SDK
and captures the native views at both system text sizes:

```sh
python3 work-record/ui-redesign/prototypes/finish-summary/render.py
```

Requires Xcode 27 and the existing booted WT-iPhone simulator (UDID in the script). The app
bundle is `com.workouttracker.design.finishsummary`; it does not overwrite WorkoutTracker.
The harness uses the project's palette, type styles and card radii as literals so it can remain
outside the production build. Production implementation must use the shared Theme/components.

Source branch: `ericlee4992/finish-summary-second-pass`, base `c7ef99b`.
Outcome: the user kept the current shipped screen, only reordering its metrics. No alternative
was selected. Implementation and its verification are on `ericlee4992/finish-summary-order`
(source `4d70d7d`), tracked in that branch's ticket 17.
Keep this exploratory source on its branch; port only the selected composition into product code.
