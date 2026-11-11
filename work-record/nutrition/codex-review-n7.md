# N7 independent review — round 1

Reviewed by Codex on 2026-11-10. Branch `ericlee4992/nutrition-07-scan-food`, HEAD `a6de2e572ce44b030eeaedf113c4a787913c379c`; diff `76600c2..a6de2e5`. Read AGENTS, STATE, N7's ticket and D82/D83, including the approved removal of food consent screens and automatic logging. Separate standards and spec passes completed. Only this report changes project content. No commit, push, deployment, phone install or live inference request; no key was printed, copied or inspected.

## Spec

### S1 — P2: Signed-out descriptions have no sign-in recovery

`WorkoutTracker/Features/Food/LogFoodView.swift:185–189`; `Scan/FoodScanQueue.swift:91–103`; `Scan/ScanTodayPieces.swift:144–145`.

The Estimate row always queues the description and dismisses Log food. Signed out, its client is nil; the queue throws `.signedOut` but converts it to `.other`. The resulting card only offers Try again, which repeats with another nil client. An expired session also loses its actionable authentication error. N7 requires signed-out → sign-in, and the camera already has that gate.

**Fix:** gate Describe through sign-in and preserve a signed-out queue failure with sign-in/retry recovery for expired sessions. Keep the description/photo available while authenticating. Test both initially signed-out submission and a session expiring during a request; fixture-success tests bypass this path.

### S2 — P2: A photo from a previous day has no reachable completion

`Scan/FoodScanFlow.swift:74–78`; `Scan/FoodScanQueue.swift:116–120`; `Features/Today/TodayView.swift:246–247`.

Pick yesterday's meal photo while the app is active. D83 correctly gives the entry yesterday's timestamp. On success the queue removes its pending card, Today excludes the past-dated entry, and foreground notifications are suppressed. There is no completed card or route to edit that result; History food is not implemented in this checkout. The existing library test uses a photo from today, so it misses this case.

**Fix:** retain an actionable completion/open-entry card or navigate to the dated result while preserving the original timestamp. Do not move the entry to today to hide the problem. Test a previous-day library photo: its nutrition must remain on that day and its result must remain reachable for inspection/editing (D82/D83).

### S3 — P2: Inspecting an item silently rounds stored numbers

`Scan/ScanEntryEditor.swift:219–236`.

On appearance every numeric field is formatted through `FoodNumber.text`; every disappearance reparses those strings into the draft. Open an item with 0.333 g or 27.456 protein, go Back untouched, then save the meal: the values become 0.33 / 27.46 and the meal's totals are recomputed from them. This repeats the stored-precision issue fixed in N4/N9a.

**Fix:** use `EditableNumber` or lossless edit serialization for untouched fields, including optional grams. Add an editor round-trip regression. The exact formatter/parser probe in `/tmp/codex-n7/item-precision.swift` and `.log` reproduces the rounding; the on-disappear write and parent save are source-traced.

### S4 — P2: Changing mode during capture changes what gets submitted

`Scan/FoodScanFlow.swift:294,367–377,411–423`.

A shutter request stores only a UUID. Mode buttons remain enabled, and the capture callback reads the current mode and geometry. Tap the Food label shutter, then select Scan food during the camera's focus delay: the callback can send the whole image and auto-log a meal instead of cropping/reading the label. Switching to Barcode can discard the completed shot instead. The fixture branch completes synchronously and does not exercise this race.

**Fix:** snapshot mode, frame and view size with each capture request, or disable all conflicting controls while it is pending. Process that immutable capture context, not mutable current UI state. Add a delayed-capture regression for mode changes.

### S5 — P2: Cancel/Retake do not invalidate outstanding async work

`Scan/FoodScanFlow.swift:89–127,396–406,428`.

Two paths share this lifetime problem. A slow PhotosPicker transfer runs in an unretained Task: Cancel dismisses the flow, but completion still calls `send`/`onShot`, allowing upload and automatic logging after cancellation. Label reads are also unowned; Retake clears state but does not cancel the old request. Choosing the same image again makes the JPEG-equality guard admit the old response, so an old success/failure can navigate or overwrite the newer attempt.

**Fix:** own the import/read tasks, cancel and invalidate them on Cancel/Retake/dismissal, and guard every completion by a generation/request identity. Byte equality is not request identity. Test a delayed import followed by Cancel and two overlapping label requests using identical bytes, including an old failure arriving during the new attempt.

### S6 — P2: Background-task expiration is not handled

`Scan/FoodScanQueue.swift:72–78`.

The task begins a UIKit background assertion without an expiration handler and ends it only after the network await returns. If a slow/offline request outlasts the available background budget, the defer has not run. Apple requires ending the assertion before expiration and documents app termination otherwise. The accepted loss of an in-flight scan when the user quits is not permission to leave a background assertion overdue. [Apple's background-task contract](https://developer.apple.com/documentation/uikit/uiapplication/beginbackgroundtask(withname:expirationhandler:).md).

**Fix:** handle expiration by cancelling/deferring the request, leaving a retryable state, and ending the assertion exactly once; share an idempotent cleanup path with normal completion and Remove. Test with an injected expiration event. This is a source/API-contract finding, not a reproduced device termination.

## Standards

### T1 — P2: External photo resources are omitted from safety copies

`WorkoutTracker/Domain/Nutrition.swift:94`, interacting with `Domain/SafetyCopy.swift:83–85,105,219`.

N7 introduces externally stored photo data, but SafetyCopies copies and restores only `.store`, `-wal` and `-shm`. Once a photo is externalized, a later safety copy cannot restore it if its original external resource is subsequently deleted/replaced. Remaining resources beside the current database can conceal the defect during a superficial restore.

**Reproduced:** a standalone macOS SwiftData model with the same `.externalStorage` attribute wrote a 2,000,000-byte payload into an external resource. Linked the repository's actual `SafetyCopy.swift` into the probe and ran `make`, `scheduleRestore` and `performPendingRestore` into a fresh directory. The restored record existed, but its data read as only **38 bytes**, versus **2,000,000** from the original. The actual manifest listed only the three SQLite files. Evidence: `/tmp/codex-n7/external-photo-probe.swift`, `actual-safety-copy-probe.log`, `photo-original/`, `photo-restored/`. This is a minimal-model storage probe, not an installed-app migration rehearsal.

**Fix:** include store-owned external resources in copy manifests, verification, staged restore and rollback, or choose storage compatible with the existing complete-copy contract. Add a large external-payload round-trip test through the actual copy/restore code. The user waived performing backup steps during wiring; that does not waive correctness of the existing restore feature. Intentional omission of photo bytes from JSON export is a separate choice.

### T2 — P2: Completion, failure and removal ignore Reduce Motion

`Scan/FoodScanQueue.swift:118,122,125`; `Scan/ScanTodayPieces.swift:121`; `Features/Today/TodayView.swift:255`.

The queue and Remove action use unconditional `.snappy` transactions, while pending cards use a scale transition. Scan completion/failure/removal therefore moves/reflows content with Reduce Motion enabled. Guards on the progress ring/shimmer do not cover these mutations.

**Fix:** move the animation decision to the observing view or otherwise gate the transaction and transition using Reduce Motion; use no movement or opacity when enabled. Verify completion, failure and Remove under that setting.

### T3 — P3: Update the public description and changed Log food screenshot

`README.md:64` and `docs/readme/log-food.png` are unchanged by N7.

The public overview omits Scan Food, automatic photo/description logging, retained local meal photos, item editing and label handling. Its Log food screenshot also predates the new camera button. AGENTS requires the feature description and changed-screen screenshots on the same branch.

**Fix:** add an accurate unreleased N7 description and retake the Log food image with sample data. State the JSON photo-export limitation. Release documentation also needs to reconcile `server/src/pages.ts:90–91,184`, which still promises first-use consent and Settings opt-outs for every feature, with D83's food-specific exception. Correct the held privacy draft rather than reintroducing the consent screen the user explicitly removed.

S3–S5 also constitute standards issues (stored-value preservation and ownership of asynchronous UI work); they are shared findings, not separate fixes.

## Other assessment and verification limits

- The server's required `mealName`, nonempty-name check when items exist and 60-character bound are wired for photo and describe. Client parsing keeps an intentional older-reply name fallback. No model, quota or transport-policy change was introduced here.
- New SwiftData declarations are additive, use defaults/optional relationships and a cascade inverse for owned items. The shipped-format migration tests pass. Keeping unreleased export v12 is reasonable: new items/hasPhoto fields are optional. Photo bytes are intentionally absent from portable JSON; do not call that a photo-complete backup.
- Normal item replacement deletes old owned rows; totals are recomputed; Delete/Undo carries item values/ids and photo data. Queue execution and supplied-context writes remain main-actor isolated. Normal Remove cancellation checks prevent late queue logging.
- The crop uses the food frame mapped by the shared aspect-fill helper, and the live preview has the same layout bounds in source. The shared camera's focus center (0.42 of height) is slightly below the food frame center (0.40), still inside that frame; it does not determine the crop. No confirmed safe-area crop defect is asserted.
- Real camera restart after Retake/library dismissal remains unverified: the reused controller stops on disappearance and starts in its initial configuration. Verify that lifecycle on a device; fixture camera tests cannot establish it. No speculative restart finding is counted.
- Server reset timestamps are rendered in the user's zone; the actual server day is New York, not the “UTC” parenthetical in D83. The implementation follows the server timestamp. The in-memory queue's loss on a user-initiated app quit is a recorded decision, not a separate finding.
- Inspected the author's Today/status, items/description and corrected label boards in `n7-wired/`. The captured default/AXL states are readable. They do not exercise the cancellation/race, prior-day result or storage scenarios above.

## Verification

Xcode **27.2 (27B52)**; WT-iPhone27 **47D21838-69A6-4BCB-AE90-B0D9C0AAA70B**, iOS 27.0. Prepared the simulator; freshly rebuilt into the existing `/tmp/codex-n4/dd` cache; tests used unchanged binaries. Evidence under `/tmp/codex-n7/`.

- Build: **exit 0**, `build.log` / `build.status`.
- Unit plan, serial: **1,228/1,228 definitions passed; 1,248 successful executions**, **0 failures, 0 skips**, **exit 0**, `unit.xcresult`, `unit-summary.json`, `unit.log`, `unit.status`.
- Server: `npx tsc --noEmit` **exit 0**; `npm test` **254/254 Vitest tests in 7 files**, then **4/4 script tests**, **exit 0** (`tsc.log/.status`, `server.log/.status`). No live API key was used.
- UI first pass, five named classes from Full (not the full suite), two workers: **24/25 passed, 1 failed, 0 skips**, **exit 65**, `ui.xcresult`, `ui-summary.json`, `ui.log`, `ui.status`. ScanFoodUITests **6/7**, TodayFoodUITests **7/7**, LogFoodUITests **5/5**, LogFoodFlowUITests **5/5**, warm-up **1/1**. `testADescriptionIsLoggedAtOnce` failed waiting for `logFoodSearch` after tapping the pill (`ScanFoodUITests.swift:132`), before submitting a description; details in `ui-failure.json`.
- Reprepared the simulator and reran warm-up + the entire ScanFoodUITests class serially, unchanged binaries: **8/8 passed** (ScanFood **7/7**, warm-up **1/1**), **0 failures, 0 skips**, **exit 0**, `ui-serial.xcresult`, `ui-serial-summary.json`, `ui-serial.log`, `ui-serial.status`. Every requested UI case has passing evidence; retain the original failed run.
- Fresh serial PNG attachments exported to `/tmp/codex-n7/attachments/` with `manifest.json`. Opened the logged-entry light/default capture and the scrolled label-food dark/AXL capture; the entry/thumbnail and label nutrition facts are readable. These are fixture captures, not evidence of hardware crop or delayed-import correctness.
- Test-plan consistency: **exit 1** (`test-plans.log/.status`): `ScanFoodUITests` is in no area plan. Add it to `scripts/test-plans.py`'s appropriate area and regenerate the plans. Explicit named-class execution does not fix this future coverage gap.
- Author results inspected directly: `u2` **62 definitions** (parameterized executions account for the ticket's 66); `b1` **4 passed/1 failed**, `b2` **1/1**; `c1` and `c2` **2/2** each; `v1` **21/24**; `b3` **1/1** after the label fix. Reviewer reruns below use the final reviewed source.

Verified: fresh build **exit 0**; Unit **1,228 definitions / 1,248 executions**, **exit 0**, `/tmp/codex-n7/unit.xcresult`; server typecheck and **254 Vitest + 4 script tests**, **exit 0**; TodayFood/LogFood/LogFoodFlow **17/17** in `/tmp/codex-n7/ui.xcresult`; ScanFood **7/7** plus warm-up **1/1**, **exit 0**, `/tmp/codex-n7/ui-serial.xcresult`; supplied/fresh captures inspected. The actual SafetyCopies probe reproduced missing external bytes. The test-plan check remains **failed (exit 1)**.

Not verified: the source-derived race/auth/prior-day scenarios in end-to-end UI; runtime Reduce Motion or background expiration; real camera crop/focus/restart and delayed iCloud photo transfer; app-to-live-server behavior (the ticket's live check was server-side); live notifications/permissions; CloudKit synchronization; installed-app large-photo backup/restore; full UI suite or a phone install. The actual SafetyCopies/minimal-model probe is described precisely above. No backup-step omission is a finding.

Known flaky: the description integration test failed at navigation in parallel and passed in the complete serial ScanFood class rerun without changes. Its precise cause was not established; preserve both bundles and track it with the existing UI reliability notes. No other UI failure or simulator connection error occurred in this review.

There are **eight distinct P2 defects and one P3 documentation finding**, with S3–S5 shared across the standards/spec axes, plus the failing test-plan consistency check. No P1 is asserted. N7 is not ready for independent clearance.

Verdict: not clear
