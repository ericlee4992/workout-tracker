# N7 independent review — round 2

Reviewed by Codex on 2026-11-10. Branch `ericlee4992/nutrition-07-scan-food`; requested product/test tip `18458af553cb2df07c79afe5f0d17711e8ab5551`. The checkout began clean at that tip, then advanced externally to `da5548c` (STATE only; no product/test changes). Reviewed fixes `a6de2e5..18458af` against affected behavior in the whole N7 diff `76600c2..18458af`. Read AGENTS, the round-2 brief, prior review, N7 ticket/spec, relevant decisions including D82/D83, DEVELOPMENT and the applicable review/SwiftUI/SwiftData/design skills. Separate standards and spec passes completed. Only this report changes repository content; no commit, push, deployment, phone install or live inference request. No key inspected, printed or copied.

## Spec

### R2-S1 — P2: Earlier-day Delete/Undo leaves Open attached to the deleted entry

`WorkoutTracker/Features/Today/TodayView.swift:113–116,315–317`; `WorkoutTracker/Features/Food/Scan/ScanTodayPieces.swift:47–48,136`; `WorkoutTracker/Features/Food/Scan/FoodScanQueue.swift:142`.

Pick yesterday's meal photo, open its completed card, Delete Entry, tap Undo, then open the surviving card again. The queue retains the original `FoodEntry`. Deletion saves immediately (`Domain/FoodLog.swift:398–402`); Undo creates and returns a new object with the same UUID (`:407–425`), but Today discards that return value and never updates/removes the queue's reference. Consequently Open still targets the deleted object, not the restored entry; subsequent edits cannot reliably update the restored food. The new earlier-day UI test stops at the first editor opening, before Delete/Undo.

The card's `!entry.isDeleted` check does not establish liveness after a saved deletion. A scratch minimal SwiftData probe reproduced this on **iOS 27, WT-iPhone27**: after delete/save, the retained object has `isDeleted == false` and `modelContext == nil`; restoring a new object with the same UUID leaves the retained reference detached, and saving edits to it leaves the fetched restored record unchanged. Evidence: `/tmp/codex-n7b/deleted-model-probe.swift`, `deleted-model-probe-ios.log` / `.status` (**exit 0**); the same probe also passed on macOS. This establishes framework identity semantics plus the source-traced application defect, not an app end-to-end reproduction or a demonstrated crash.

**Fix:** reconcile completed cards with deletion and restoration. Remove/invalidate the deleted completion, then recreate/rebind the earlier-day completion using the actual object returned by `FoodLog.restore` (or resolve a stable ID against live queried entries). Test yesterday → Open → Delete → Undo → Open → edit/save → reopen, including preserved photo/items. D82's “tap to edit or delete, with Undo” must also hold for D83's original-date library photos. **Round-1 S2 is only partially fixed.**

### R2-S2 — P2: Cancel still accepts a pending hardware shutter callback

`WorkoutTracker/Features/Food/Scan/FoodScanFlow.swift:391–399,460–462` (also `:222`); supporting shared-camera path `WorkoutTracker/Features/Gyms/LabelCameraView.swift:230–236,258–268`.

Press the real shutter, then Cancel after `capturePhoto` starts but before its result arrives. Cancel cancels only `importTask`; `captureID` and the captured mode/frame tuple remain valid, including while the cover dismisses. A delayed `photo(_:)` therefore passes both identity checks and calls `send` → `onShot` → `FoodScanQueue.startPhoto`, uploading and automatically logging the meal after cancellation. The shared controller's stop invalidates focus waiting, but does not clear the already-pending photo/delegate callback; its delegate still forwards that result. Fixture capture is synchronous and cannot exercise this window.

**Fix:** invalidate the capture ID/context synchronously when Cancel is tapped and on disappearance, and reject callbacks once that camera/flow lifetime has ended. Add a delayed callback-after-cancel regression. Preserve the correct shutter-time mode snapshot. This is a source-traced race; no real-device capture race was reproduced. **The two original S5 paths (library import and label read) are fixed; cancellation is still incomplete for hardware capture.**

### Round-1 spec disposition

| Finding | Disposition | Evidence |
|---|---|---|
| S1 — signed-out description/recovery | **Fixed** | `LogFoodView.swift:190` gates Estimate before queueing, retaining words; queue preserves `.signedOut`; Today presents Sign In and retries the same scan on signed-in dismissal. Tests cover initial gate and expired-session Sign In presentation; real authentication/retry remains unverified. |
| S2 — earlier-day completion unreachable | **Partially fixed** | Completion stays with Open and retains its original date. R2-S1 above prevents clearance of its Delete/Undo lifecycle. |
| S3 — untouched item values rounded | **Fixed** | `ScanEntryEditor.swift:217–243,248–259`: exact stored values via `EditableNumber`, optional grams and blank/invalid rules preserved. New unit cases exercise the helpers used by write-back. |
| S4 — changing mode changes pending shot | **Fixed** | `FoodScanFlow.swift:383–399`: capture snapshots mode/frame/view size; mode/library controls lock while pending; send receives mode explicitly and excludes Barcode. Runtime delayed hardware capture remains unverified. |
| S5 — stale import/label work | **Fixed for the reported paths; related cancellation gap remains** | Owned import/read tasks cancel on close/Retake and check cancellation; label success and failure compare an attempt UUID. R2-S2 covers the remaining hardware callback path. Delayed iCloud/identical-byte overlap scenarios were source-reviewed, not executed. |
| S6 — background expiration | **Fixed in source** | `FoodScanQueue.swift:85–100,219–237`: expiration cancels work, leaves retryable failure, and synchronously ends the assertion; the normal task's defer shares an idempotent end. [Apple's contract](https://developer.apple.com/documentation/uikit/uiapplication/beginbackgroundtask(withname:expirationhandler:).md) confirms the main-thread expiration callback and required cleanup. OS expiration was not injected. |

**Spec: two P2 findings; no P1 or additional P3.**

## Standards

- **T1 — fixed:** `Nutrition.swift:96–100,156–166` uses optional owned `FoodPhoto` with inline `Data`, explicit cascade/inverse, UUID/defaults; the model is registered. The actual generated app model is used by `SafetyCopyTests.aMealPhotoComesBackWholeFromACopy`: all 2,000,000 bytes go through production make/scheduleRestore/performPendingRestore after deleting the original store folder. The external-storage guard checks every app-model attribute. Cascade/Undo is covered by `FoodScanTests`.
- **Storage design:** a separate photo row is reasonable for Today's all-entry query and avoids putting every blob directly in the entry row; thumbnails cache by entry UUID. This is a design rationale, not a measured guarantee about SwiftData faulting. Schema shape follows project CloudKit conventions. The brief's “≤ ~600 KB” is **not an enforced bound**: `EquipmentPhoto.jpeg` (`IdentifyEquipmentSheet.swift:360–367`) caps dimensions/quality only. CloudKit synchronization and payload compatibility are not verified. JSON photo omission remains intentional and documented.
- **T2 — fixed in source:** the queue no longer supplies animation transactions; Today gates its `scans.revision` animation on Reduce Motion and selects opacity-only transitions. Remove supplies no forced animation. Runtime Reduce Motion was not separately exercised.
- **T3 — fixed:** README describes automatic photo/description logging, retained photos, item editing, labels and JSON limitations. The updated 603-pixel Log food screenshot visibly includes its camera button. The held privacy/support draft distinguishes food actions from training permissions; no removed consent screen was reintroduced.
- **Test-plan mapping:** ScanFoodUITests is now assigned to TodayTrain; check result recorded below.
- **D83 reset wording:** corrected to New York midnight; UI still formats the server's reset timestamp locally.

**Standards: the three original findings are fixed; no separate new standards defect.** The lifecycle defects above also affect safe UI/data ownership and are not counted twice. Unrelated API modernization/file splits are outside this fix review.

## Verification

Xcode **27.2 (27B52)**; **WT-iPhone27 `47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`, iOS 27.0**. Prepared before the first run and again before the serial rerun. Fresh `build-for-testing` into `/tmp/codex-n7b/dd`; subsequent tests used those unchanged binaries. Commands/process logs are retained in `/tmp/codex-n7b/run.py`, `runner.log`, `runner.pid`, `serial.py`, `serial-runner.log` and `serial-runner.pid`. Progress was shown in the existing requested Orca tab; no new terminal was opened.

- **Build:** exit **0**, `build.log` / `build.status`.
- **Unit plan, serial:** **1,232/1,232 definitions, 1,252 successful executions, 0 failed, 0 skipped**, exit **0**. `unit.xcresult`, `unit-summary.json`, `unit-tests.json`, `unit.log` / `.status`. Inspected individual passing results for both new safety-copy cases and both item-number cases, not just the author's counts.
- **UI, five named classes from Full, two workers:** **27/28 passed, 1 failed, 0 skipped**, exit **65**. ScanFood **9/10**, TodayFood **7/7**, LogFood **5/5**, LogFoodFlow **5/5**, warm-up **1/1**. `ui.xcresult`, `ui-summary.json`, `ui.log` / `.status`. `testADescriptionIsLoggedAtOnce` failed at **ScanFoodUITests.swift:172**, waiting for `logFoodSearch` after tapping the pill, before submitting a description; inspected `ui-failure.json`. This matches round 1's failure point. The new initial-sign-out, expired-session Sign In and earlier-day Open tests all passed.
- **Serial UI rerun, unchanged binaries:** warm-up plus the entire ScanFood class **11/11 passed** (ScanFood **10/10**, warm-up **1/1**), **0 failures, 0 skips**, exit **0**. `ui-serial.xcresult`, `ui-serial-summary.json`, `ui-serial.log` / `.status`. Every requested UI case has passing evidence; the original failed run remains preserved.
- **Server:** `npm test` **254/254 Vitest cases in 7 files plus 4/4 script tests**, exit **0**; `npx tsc --noEmit` exit **0**. `server.log` / `.status`, `tsc.log` / `.status`. No live API request/key used.
- **Test-plan consistency:** `python3 scripts/test-plans.py --check` exit **0**, `test-plans.log` / `.status`. `git diff --check a6de2e5..18458af` also passed.
- **Captures:** exported fresh ScanFood PNG attachments and their manifest to `/tmp/codex-n7b/attachments/`. Opened the light/default and dark/AccessibilityL logged-entry captures and the dark/AccessibilityL label-facts capture; their text/numbers are readable. Also inspected the author's light/default and dark/AccessibilityL progress-card captures and the updated README screenshot. These fixtures do not verify physical capture timing or cancellation.
- **Author evidence independently inspected:** `u4.xcresult` reports **1,232 definitions / 1,252 executions**, no failures/skips; `v2.xcresult` **27/27**, no failures/skips; `rd.xcresult` **1/1**. Saved their summaries as `author-u4-summary.json`, `author-v2-summary.json`, `author-rd-summary.json`. Reviewer runs above establish this round's gate independently.

Verified: fresh build **exit 0**; Unit **1,232/1,232 definitions / 1,252 executions**, **exit 0**, `/tmp/codex-n7b/unit.xcresult`; TodayFood/LogFood/LogFoodFlow **17/17** plus warm-up in `/tmp/codex-n7b/ui.xcresult`; ScanFood **10/10** plus warm-up **1/1**, **exit 0**, `/tmp/codex-n7b/ui-serial.xcresult`; server **254 Vitest + 4 script tests**, typecheck and test-plan check **exit 0**; fresh/supplied captures inspected. The scratch SwiftData identity probe ran on iOS 27 and macOS, **exit 0**. All evidence is under `/tmp/codex-n7b/`.

Not verified: the actual app's earlier-day Delete/Undo/reopen sequence (the finding combines application source with a minimal SwiftData reproduction); real shutter callback-after-cancel, camera crop/focus/restart, delayed iCloud import or overlapping identical-image label requests; OS background expiration; runtime Reduce Motion; live authentication followed by successful scan retry; real notifications/permissions; app-to-live-server behavior; CloudKit synchronization/payload bounds; an installed-app large-photo restore; full UI suite or phone installation. These were not exercised by the fixture UI tests. No backup-step omission is a finding: the user's waiver remains honored.

Known flaky: `ScanFoodUITests.testADescriptionIsLoggedAtOnce` again failed at the Log food navigation wait in the two-worker run and passed in the complete serial class rerun without source/binary changes. Its precise cause is not established. Preserve both bundles and follow up on navigation stability alongside the same failure recorded in [round 1](codex-review-n7.md); this round's serial pass does not erase the initial failure. No other test failed this round.

Standards: **0 new findings**; T1–T3 resolved. Spec: **2 P2 findings**, concerning earlier-day Delete/Undo and late hardware capture after Cancel. Resolve both and independently re-review the fixes before clearance.

Verdict: not clear
