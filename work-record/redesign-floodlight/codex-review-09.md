# Ticket 09 — independent Codex review

**Verdict: not clear.** Two medium and three low findings. No critical or high findings.

Reviewed `ericlee4992/redesign-floodlight-exercises..HEAD`, **bf4363b0243e1d22e107ec53793ce223b24683a5 → bbe74db4a5ac6b3d3b478f16250c60629d6f729c**, on `ericlee4992/redesign-floodlight-settings`, in `/tmp/wt-floodlight/settings`. Claude implemented; Codex reviewed. The initial working tree was clean. This review changes only this report; no `xcodebuild` or `simctl` was run.

## Medium

### 1. Returning through another tab leaves Share pointing at a deleted file

**`WorkoutTracker/Features/Settings/ExportView.swift:88`**, with the Share action at line 194.

Export CSV, dismiss sharing, switch to History, then return to Workout. The tab's navigation stack retains Export and its `file` state (`RootView.swift:40`, `StartWorkoutView.swift:52`), but `onDisappear` has discarded the URL's directory. The retained card still offers Share for that deleted file. Its existence is never checked or restored. Ticket decision 2 permits deletion when leaving the screen, but the card must then be invalidated too. Clear the staged-file state together with cleanup, and cover this tab round trip. Also bind the delayed export task to the screen's lifetime so it cannot publish a new file after cleanup has already run.

### 2. A failed replacement loses the last file's cleanup handle

**`WorkoutTracker/Features/Settings/ExportView.swift:263`**, with cleanup at line 88.

Successfully build an export, dismiss sharing, then attempt another export whose collection, encoding or write fails. The catch sets `file = nil` without discarding the previously staged URL. `ExportFileWriter.write` deliberately preserves the old staging directory when the new write fails (`Domain/ExportFile.swift:57–62`). Leaving Export now cannot delete that old file because its only cleanup handle has been dropped. It remains until another successful export or OS temp cleanup, contrary to decision 2's screen-lifetime contract. Preserve ownership until explicit disposal; retaining the previous usable card on failure is another option. Test success → failed replacement → leave against the filesystem, not just the failure label.

## Low

### 3. Same-day tally stacks escape the panel's allocated strip

**`WorkoutTracker/Features/Settings/ExportView.swift:398–406`.**

The strip reserves 49 pt regardless of the number of workouts on a day, while every additional mark moves upward by 18 pt. The third mark starts at y = −6; the fourth starts at −24 and reaches the preceding last-export/count block. More workouts continue upward. The domain imposes no two-workouts-per-day limit. Allocate height from the maximum stack or use an explicitly bounded representation. The current capture fixture uses distinct days and the unit test checks only a two-mark stack, so neither exposes this layout failure.

### 4. The heart-rate card hides its zone thresholds from VoiceOver

**`WorkoutTracker/Features/Settings/SettingsView.swift:268–269`.**

The parent ignores its children and supplies only the maximum as its label, discarding the zone descriptions already provided by `SettingsZoneLadder` (`SettingsPieces.swift:225–227`). At a maximum of 185, sighted users see 102/120/139/157/176, while VoiceOver hears only “Heart rate zones, 185 bpm.” Include the threshold summary in the card label. This omission also exists in the prototype; the max-HR sheet still exposes the bounds after opening it, which limits the impact.

### 5. The neighbour export test no longer proves that sharing opens

**`WorkoutTrackerUITests/ExportUITests.swift:36–40`.**

The unrestricted `workout-tracker-…` query now matches the new file card as well as the share sheet. If Export writes a file and displays the card but never presents sharing, this assertion passes; its fallback swipe and final card/no-error assertions can pass too. Scope the assertion to the activity controller, as `FloodlightSettingsUITests` already does. The latter provides real CSV presentation coverage; this older test's claim of checking the share sheet is now misleading.

## Other checks and verification scope

- Canonical preference writes, both rest bounds/steps, the template-prompt inversion and its behavioral reader, HR resolution/bounds, D51 singular/plural, and Appearance retain their intended behavior. Key save/replace/remove, masking, independent consent keys and point-of-use gates are preserved. Decision 4 authorizes the removed disclosure; D56–D58 do not separately require that paragraph on Settings. Fixture activation requires reset, and fixture keys use the in-memory key store.
- Export recording is conditional on the activity controller's `completed` value; cancellation and the failure path do not update it. Both `@AppStorage` readers match `ExportRecord`'s reference-date encoding and keys, which reset clears. The timestamp is captured before collection, rather than when a potentially later share finishes. Pending uses the specified strict start-date boundary; the notice uses elapsed 72 hours. Tally day grouping uses the supplied calendar. No SwiftData schema or export payload changes were introduced.
- Per-device storage matches the explicit decision. Its timestamp describes a local export event, not proof that later-restored or synced older workouts, subsequent history edits, or every JSON-only object exist in that file. The count follows the approved “started since” definition. CSV remains a set ledger; JSON remains the complete backup. The new record must not be treated as restore/integrity verification.
- Existing prototype/actual comparisons and individual captures were inspected across light/dark and Default/AccessibilityL. Ordinary fixture layouts preserve the intended hierarchy and single filled command. Motion helpers, count changes, card transitions and scroll honor Reduce Motion; the inline title uses an allowed fade. The faint tally is decorative and hidden from accessibility. Remaining capture limits: the AXL no-key shot has “Off” above the viewport, and protected typing captures do not visually prove the keyboard layout. The key flow also never dismisses while On, so its final Off assertion alone does not prove On refresh after saving.
- Inspected actual exit files and xcresult summaries: `settings-build-1` exit **0**; `settings-ui-1` exit **65**, **11 passed / 3 failed** (including eight passing domain tests); `settings-ui-2` exit **65**, **9 / 2**; `settings-ui-3` exit **65**, **3 / 2**; `settings-ui-4` exit **0**, **2 / 0**. No skipped tests. These agree with the recorded failures and focused reruns. An externally started `settings-ui-5` had no completed exit/result at inspection and is not counted as passed.
- Targeted domain, Settings and adjacent-flow checks are appropriate under DEVELOPMENT; this ticket alone does not require a fresh full UI suite. Before clearance, add the two file-lifecycle cases above, check the corrected accessibility label and stacked-day layout, and complete the affected final-code checks already pending in the ticket. No additional unlisted product change was identified.
