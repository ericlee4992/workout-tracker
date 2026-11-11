# Codex review — nutrition N7 (Scan Food: meal photo, food label, describe)

You are the independent reviewer; Claude implemented. Read AGENTS.md first. Checkout
`/Users/ericlee06/orca/workspaces/Health App/UI_design`, branch `ericlee4992/nutrition-07-scan-food` (off `main`
`76600c2`). Review `git diff 76600c2..HEAD` (the mock commits are in it; the mock code itself was replaced by the wiring).

Read first: `work-record/nutrition/issues/07-scan-food.md` (scope, mock v1, Decided → D83, Wiring, Live check, Own
decisions, new strings), decisions **D82, D83** (and D53 label crop, D60 accounts, D73 labels, D75 limits, D78 no
"Estimated", D52 plain numbers), `work-record/nutrition/spec.md`, DEVELOPMENT's migration rules,
`.claude/skills/ios-design/REVIEW.md` for the screens; swiftui-pro / swiftdata-pro apply (project rules override).
Note D83 (7): **no consent screen** for Scan Food (the user's decision, reopening D56's pattern for food only).

Check in particular:
1. **Server** (`server/src/ai.ts`, `server/test/food-ai.test.ts`): `mealName` in `FOOD_ITEMS_SCHEMA` (strict schema:
   required), both instructions, `checkFoodItems` (≤ 60, blank only without items). Run `npm test` and `npx tsc
   --noEmit` in `server/` (this worktree's `server/node_modules` is a symlink to N6's worktree, excluded locally).
2. **Data change** (`Domain/Nutrition.swift`, `Models.swift`, `StoreFormatGuardTests`): `FoodEntry.photo`
   (`.externalStorage`), `FoodEntry.items` (`.cascade`, inverse), new `FoodEntryItem` — additive and CloudKit-safe?
   New `approvedFingerprint` (the user: "skip backup steps for wiring N7" — the approval and the skipped backup are
   theirs). Does `NutritionMigrationTests` still prove the shipped format opens? Export: `FoodEntryRow.items` /
   `hasPhoto` (v12 unreleased, not bumped — agree?); photo bytes not exported.
3. **Domain** (`Domain/FoodScan.swift`, `FoodScanTests`): reply parsing mirrors the server's bounds; one entry per scan
   with totals = Σ items; `update` deletes replaced items (no orphans) and recomputes; `DeletedEntry`/`restore` carry
   photo + items; `logLabel` both ways; `FoodScan.when` (library photo time, clamp to now, meal follows);
   `PhotoDate` EXIF parsing incl. offset.
4. **Queue** (`Features/Food/Scan/FoodScanQueue.swift`): main-actor isolation of the Task, background task begin/end,
   cancellation on Remove, retry, logging into the context passed in (is Today's `modelContext` the right one?), error
   mapping (limit with its reset time — server day is New York midnight), the notification permission asked once and
   never under UI tests, notifying only when not active; what is lost if the app is killed mid-scan (accepted in the
   ticket — agree?).
5. **Camera flow** (`FoodScanFlow.swift`): the label crop — the food box mapped with `LabelFramingBox.visionRegion`
   from the SwiftUI frame; is the `LabelCameraView` preview really the same size/aspect-fill as the GeometryReader
   (safe areas)? `LabelCameraController.capture` still focuses on Scan Machine's box centre (harmless?). Library pick
   (`PhotosPicker`, `loadTransferable(Data)`, EXIF date), meal choice rules (camera: Log food's chip or the time;
   library: the photo's time), the label read Task (stale replies after Retake), sign-in sheet, camera-off.
6. **Screens:** Today (`TodayView`, `TodayFood`'s rows: a scan shows its thumbnail and opens `ScanEntryEditor`;
   `ScanPendingCard`), `ScanEntryEditor`/`ScanItemEditor` (staged edits; the item editor writes back on disappear —
   any path that loses or double-applies an edit? a nameless new item dropped on Save), `LabelFoodView`, Log food's
   camera button and estimate row, the camera button beside the pill (`LogFoodPill(scan:)`).
7. **Tests:** `ScanFoodUITests` (5 behaviour tests + 2 capture tests on the `-uiTestTerra` fixture:
   `FoodScanFixture`, `-uiTestFoodScanFail`, `-uiTestFoodScanHold`, `-uiTestFoodScanNoCamera`), the touched
   `TodayFoodUITests`, `LogFoodUITests`, `LogFoodFlowUITests`.

Claude's evidence (scratchpad
`/private/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-UI-design/987d2e07-f1f0-4854-a4f2-1db12bf762c0/scratchpad/`):
`u2.xcresult` (nutrition unit suites), `b1.xcresult`/`b2.xcresult` (behaviour), `c1.xcresult` then `c2.xcresult` (captures after
the label-step fix; PNGs in `w/` and `w2/`, sheets in `n7-wired/`), `v1.xcresult` (ScanFood + TodayFood + LogFood +
LogFoodFlow, 2 workers: 21 passed, 3 failed — all the label step, fixed in `e6e6421`; `b3.xcresult` the label test
after the fix).

Per AGENTS' reviewer rule (round 1): build; run the Unit plan; run as UI classes (2 workers): `AAAWarmUpUITests`,
`ScanFoodUITests`, `TodayFoodUITests`, `LogFoodUITests`, `LogFoodFlowUITests` (rerun failures serially before judging).
Run on **WT-iPhone27** `47D21838-69A6-4BCB-AE90-B0D9C0AAA70B` (`scripts/prepare-test-simulator.sh <id>` first), paths
under `/tmp/codex-n7/`. Show progress in the existing Orca tab "Test progress (Claude r2)"
`term_ac1339dc-202d-4c10-bab3-b528de726cbd` once it is back at its prompt — do not open a new terminal. Do not modify
files other than the report; do not commit or push; never print or copy the OpenAI key.

Write `work-record/nutrition/codex-review-n7.md`: findings P1/P2/P3 with file:line, failure scenario and fix; a
Verified / Not verified / Known flaky block; end with exactly `Verdict: clear` or `Verdict: not clear`.
