# Codex review — ticket 14 (What's New)

You are the independent reviewer (AGENTS.md T6); Claude implemented this. Review branch
`ericlee4992/beta-14-whats-new`, which sits on ticket 16's reviewed tip: `git diff 63a6058..HEAD` is ticket 14 (ticket
16 was cleared in `codex-review-16c.md`; do not re-review it except where 14 touches it — the Add Chart "Most used"
glyph changed from sparkles to a star).

Read first: `work-record/public-beta/issues/14-whats-new.md` (request, the user's decisions, build notes, verification),
D62 in `docs/DECISIONS.md`, `docs/DEVELOPMENT.md` → TestFlight build checklist step 2, `.claude/skills/ios-design/REVIEW.md`,
`WorkoutTracker/Features/Onboarding/OnboardingCoordinator.swift` (the welcome page's first-launch rule).

Check in particular:
1. **The launch rule** (`Domain/WhatsNew.swift`, `WorkoutTrackerApp.evaluateWhatsNew`): an existing tester updating from
   build 6 (no last-seen key; the welcome answered or workouts present) sees build 7's entry once; a fresh install
   never does and starts at its build; a workout in progress defers it and records nothing; later builds without an
   entry show nothing; the last-seen build is saved on dismissal only, never moves backwards; unknown store counts fail
   closed. Consider the order against the welcome page and the tour (same launch; RootView re-appearing after the tour),
   the live-workout cover, and the finish sheet — can two modal presentations collide?
2. **Tests stay unaffected:** under `-uiTestReset` the sheet appears only with `-uiTestWhatsNew`, and the last-seen key
   is cleared; no existing UI test can be covered by it.
3. **The sheet** (`Features/Onboarding/WhatsNewSheet.swift`) and the Settings row against the ios-design rules: one
   prominent button, glyph meanings (sparkles = AI elsewhere), Dynamic Type at AccessibilityL (look at
   `work-record/public-beta/captures/14/*.png`), VoiceOver (header trait, decorative glyphs hidden, identifiers).
4. Tests (`WorkoutTrackerTests/WhatsNewTests.swift`, `WorkoutTrackerUITests/FloodlightWhatsNewUITests.swift`) cover the
   claims; DEVELOPMENT/README match the code.

Run yourself on an iOS 27 simulator (WT-Floodlight `9E822EF6-DC67-4958-AEA2-D53D2D36D674`, your own `-derivedDataPath`
and `-resultBundlePath`): the build, and `-only-testing:WorkoutTrackerTests/WhatsNewTests`; report exit codes. UI tests
are optional; say if you skip them. Do not modify files other than the report; do not commit or push.

Write `work-record/public-beta/codex-review-14.md`: findings numbered P1/P2/P3 with file:line, failure scenario and fix;
end with exactly `Verdict: clear` or `Verdict: not clear`.

## Round 2

Round 1: [codex-review-14.md](codex-review-14.md), not clear (#1 unknown counts, #2 welcome + What's New together, #3
AXL last line). Fixes: the ticket's "round 1 — response" and `git diff 5aff73c..HEAD`. Check all three are closed and
nothing regressed; rerun the build and `WhatsNewTests` (new result path). Write
`work-record/public-beta/codex-review-14b.md`, ending with exactly `Verdict: clear` or `Verdict: not clear`. Do not
commit or push.
