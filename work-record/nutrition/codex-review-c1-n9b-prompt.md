# Codex review — C1 (no "AI" wording) + N9b (Apple Health), one review

You are the independent reviewer; Claude implemented. Same checkout as before:
`/Users/ericlee06/orca/workspaces/Health App/UI_design`, branch `ericlee4992/c1-n9b` (on `main` `ed4ec5a`). Review
`git diff ed4ec5a..HEAD`. The user asked for both tickets to be built, then tested and reviewed together.

Read first: `work-record/copy/issues/01-no-ai-wording.md` (C1: the approved scope, Progress with every rewritten line,
what was kept and why, the camera/photo-library wording left for the user) and
`work-record/nutrition/issues/09-body-weight-health.md` (N9b: Scope, approved usage strings, Progress "N9b built" —
design, own decisions 1–5, new strings, wireframe); decisions D71 (Burned shown, never added), D74 (the four Health
parts; dedupe by Health sample ids; follow edits/deletes), D52, D80, D83(8); `.claude/skills/ios-design/REVIEW.md`;
swiftui-pro / swiftdata-pro apply.

Check in particular:
1. **C1:** every user-facing string with "AI" outside the feature names (`rg -n '"[^"\n]*\bAI\b[^"\n]*"'
   WorkoutTracker -g '*.swift'`, multi-line strings and Info.plist keys too); the rewritten lines read correctly in
   their flows (e.g. `AIRoutineErrorText.split` / `ScanErrorText.shown` still give sensible text); tests moved.
2. **N9b sync** (`Domain/HealthNutritionSync.swift`, `Domain/HealthKitNutritionStore.swift`): the reconcile design —
   diff correctness (duplicates, zero macros, refused types, other apps' samples untouched), sync-id format and
   `HKMetadataKeySyncVersion` replacement, delete predicates (own source + sync ids), the pass loop (`dirty`, ≤ 3
   passes, a save during a pass, the `ModelContext.didSave` observer, debounce), `healthSampleID` written back without
   save loops, reading weights (own samples excluded by id / sync id / source; 365-day window; unit system; deleted in
   Health → removed), turning parts off, `refreshBurned` (day bounds; refused read = 0), `FoodDayMath.burned` max rule
   vs D71. HealthKit API use: authorization per part, `canWrite`, queries without read permission (own data only), the
   decision to write plain samples instead of a food correlation (own decision 1) — is the reasoning right?
3. **Wiring:** `WorkoutTrackerApp` (created per launch; never attached to the tour's sample world; scene-active pass),
   UI-test isolation (`HealthSync.forThisLaunch`: fake store + throwaway defaults under `-uiTestReset`), `TodayView`
   Burned and its `.task(id:)`, `BodyWeightView` (Health rows read-only; Log weight unit from the latest *app* entry),
   `ProfileTabView` row, `AppleHealthView` (toggle binding while a permission sheet is up, refused notes, AX layout).
4. **Usage strings** in `project.pbxproj` (iPhone app, Debug + Release) equal the approved wording in the N9 ticket
   (apostrophe typeset ’); Watch strings unchanged.
5. **Tests:** `HealthNutritionSyncTests` (15), `AppleHealthUITests` (4, in the ProfileAI plan via
   `scripts/test-plans.py`), the moved C1 expectations. Scope choice: AskAIUITests not run by Claude (no test reads a
   changed string) — say if you think it should be.

Per AGENTS' reviewer rule (round 1): build; Unit plan; `HealthNutritionSyncTests`; UI classes `AAAWarmUpUITests`,
`AppleHealthUITests`, `BodyWeightUITests`, `TodayFoodUITests`, `FloodlightProfileUITests`, `FloodlightScanUITests`,
`FloodlightAIRoutineUITests`, `NutritionGoalsUITests` (2 workers; rerun failures serially). Claude's evidence in
`/private/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-UI-design/20f5b25b-92e7-448e-a00d-dbd68fee92a9/scratchpad/`
(`c1n9b-health10`, `c1n9b-unit`, `c1n9b-ui1`, `c1n9b-ui2` `.xcresult`; captures `att1/`). WT-iPhone27 `47D21838-…` with
`scripts/prepare-test-simulator.sh <udid>` first; paths under `/tmp/codex-c1n9b/`. Claude runs nothing while you run.
Do not modify files other than the report; do not commit or push.

Write `work-record/nutrition/codex-review-c1-n9b.md`: findings P1/P2/P3 with file:line, failure scenario and fix; a
Verified / Not verified / Known flaky block; end with exactly `Verdict: clear` or `Verdict: not clear`.
