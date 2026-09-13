You are building a COMPETING visual design for this app, in parallel with another agent (Claude),
so the user can compare the two side by side. Same brief, your own taste. Do not look for or
copy the other agent's work (it is on a different branch and worktree).

THE BRIEF is work-record/ui-redesign/spec.md in this worktree — read it fully first. It is the
approved plan: the user's direction (bold, dark, card-based; dark only; ONE warm accent; muscle-
group colours + icons; stat tiles + rings; motion + haptics; illustrated SF-Symbol empty states),
the constraints (iOS 26 target; no third-party deps; the copy policy — no new explanatory text;
the visible strings and every accessibilityIdentifier the XCUITests depend on MUST stay), and
the ticket breakdown. The palette/values in the spec are Claude's picks — you are free to choose
your OWN accent, surfaces, radii, type and muscle-group colours as long as they honour the
user's direction. Make it look great.

YOUR SCOPE (tickets 01 + 02 of the spec only):
1. A design system under WorkoutTracker/Features/Design/ (tokens, card style, chips, stat tile,
   progress ring, button styles, empty state, haptics) and colour sets in Assets.xcassets; the
   app forced dark at the root (App/WorkoutTrackerApp.swift); accent everywhere the teal was.
2. The ACTIVE WORKOUT screen restyled: Features/ActiveWorkout/ActiveWorkoutView.swift,
   ExerciseEntryCard.swift, RestTimerBar.swift, HeartRateBar.swift — cards, set rows, rest ring,
   set-complete animation + haptic, plus the two known layout defects in the spec (preset chips'
   reachability; bar-mode plates-vs-total reading as two numbers). Keep the swipe-to-delete
   mechanics and List/.onMove exactly as they are (see the spec's risks).
3. Also restyle the START screen (Features/Start/StartWorkoutView.swift) if you have time — hero
   start button, gym card, template cards. Optional.

RULES:
- Work ONLY in this worktree, on the current branch. Commit as you go with clear messages.
- Simulator: do NOT use "WT-iPhone" (another agent is using it). Create your own:
    xcrun simctl create WT-iPhone-Codex "iPhone 17 Pro"   (any available iPhone type is fine)
  and pass -destination 'platform=iOS Simulator,name=WT-iPhone-Codex' to every xcodebuild.
- Tests are the regression net: after your changes, `xcodebuild test … -only-testing:WorkoutTrackerTests`
  must be green, and these UI classes must pass: CoreLoopUITests, BarbellUITests,
  ExercisePresetUITests, HeartRateUITests, WorkoutNameUITests, DumbbellCounterpartUITests.
  (UI classes take ~1 min per test; run them with -only-testing per class.)
- Do not touch docs/SPEC.md, docs/DECISIONS.md, docs/STATE.md or CLAUDE.md.
- SCREENSHOTS are the deliverable. Write a UI test class WorkoutTrackerUITests/CodexScreenshotUITests.swift
  whose tests build each screen with the existing fixtures (launch args -uiTestReset plus
  -uiTestHeartRate for a live fake heart-rate feed; create a gym + machine, start a workout, add
  an exercise, log two sets and complete one so the rest bar shows) and attach XCTAttachment
  screenshots named: codex-01-root, codex-02-active-workout, codex-02-active-workout-rest,
  codex-02-bar-mode (a barbell exercise with a bar chosen — see BarbellUITests for the flow),
  codex-04-start (if you did Start). Then export the PNGs:
    xcodebuild test … -only-testing:WorkoutTrackerUITests/CodexScreenshotUITests \
      -resultBundlePath work-record/ui-redesign/results/codex.xcresult
    xcrun xcresulttool export attachments --path work-record/ui-redesign/results/codex.xcresult \
      --output-path work-record/ui-redesign/screenshots/codex-raw
  and copy each PNG to work-record/ui-redesign/screenshots/codex/<attachment-name>.png (use
  manifest.json in the raw folder for the names). Commit the PNGs.
- When done, write work-record/ui-redesign/codex-design-report.md: your palette (hex values), the
  design choices you made and why, what you changed in each file, test results, and the list of
  screenshot files. Finish by committing everything.
