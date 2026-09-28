Independent review (T6) of ticket 09 of the Floodlight redesign: Settings, on branch
`ericlee4992/redesign-floodlight-settings`. Range: `ericlee4992/redesign-floodlight-exercises..HEAD`
(the branch is stacked on ticket 08's exercises branch, tip `bf4363b`). Claude implemented; you
review. Run in the checkout `/tmp/wt-floodlight/settings` and stay in it.

Read first: AGENTS.md; `work-record/redesign-floodlight/issues/01-implement-redesign.md` (user
decisions); `issues/09-settings.md` (scope, the user's four decisions of 2026-09-28 — last export
recorded only when the share sheet completes, per device; Export opens the share sheet at once and
keeps a file card with Share; the saved key shown as its last 4 characters; the Ask AI disclosure
paragraph dropped — kept rules and identifiers, prototype-only features, strings, tells,
verification); `.claude/skills/ios-design/REVIEW.md`; `reference/look-api.md`,
`reference/brief/constraints.md` §1–2; DECISIONS D25, D29, D45, D51, D52, D56, D57, D58 and the export
fidelity rules around `ExportCollector`/`ExportCSV`/`ExportJSON`. Prototype captures
`reference/prototype-settings/{dark,light}/`; prototype source (read-only)
`/Users/ericlee06/orca/workspaces/Health App/redesign-prototype/RedesignPrototype/Sources/Screens/Settings/`.
Actual captures: `captures/09/`. Old screens: `git show ericlee4992/redesign-floodlight-exercises:WorkoutTracker/Features/Settings/<file>`
(`AppSettingsSection.swift`, `ExportSection.swift`, `AskAISettingsSheet.swift`, `SettingsView.swift`).

Review for:
1. The export record (`Domain/ExportRecord.swift`, `ExportRecordTests`): recorded only on a completed
   share (`ShareSheet`'s `completed`), never on Cancel or a failed write; the date recorded (the
   build time, taken before the store is read) versus what the file actually holds; `pending`'s
   boundary; the 3-day notice rest; the tally (stacking, span, an export before the first workout,
   time zones / day boundaries); `@AppStorage` keys and encoding matching `ExportRecord.read/write`;
   cleared under `-uiTestReset`; nothing written into SwiftData or the export files. Is per-device
   storage right for a restored or CloudKit-synced store?
2. X03 (`ExportView`): the share sheet presented at once and again from the card's Share; the staged
   file's lifetime (discard on disappear, the next write's sweep, a second export while the first
   share sheet is up, leaving the screen mid-share); the busy state and double taps; the failure
   panel and `-uiTestExportFails` only active with `-uiTestReset`; the counts (`ExportCounts.fetch`)
   agreeing with the file's `snapshot.counts`; "N completed" semantics; Reduce Motion (pulse, count,
   card transition, scroll).
3. X01 (`SettingsView`): every control still writes the canonical `AppPreferences` row as the old
   section did (units, both rests with 0…600 / 15 s, the template prompt now inverted — check the
   inversion against every reader of `driftPromptSuppressed`); the heart-rate maximum and zone lower
   bounds against `MaxHeartRateResolver`/`HeartRateZones` (D45/D52); the max-HR sheet and the Ask AI
   sheet still present (sheets hung off a `ScrollView` now, not a `List` row); the Ask AI On/Off
   refresh on dismiss; the D51 note (canonical row, singular/plural); Appearance pills still driving
   the per-device setting; the export card's counts refreshing after an export.
4. X02 (`AskAISettingsSheet`, also presented from the AI routine sheet's `routineAISettings`): save /
   replace / remove through `AskAIKeyStore`; the masked hint never showing more than 4 characters
   (short keys, whitespace); Remove key confirmation; the three consents still independent
   `@AppStorage` flags with the same keys (D56–D58) and still asked for at the point of use; the full
   "Send … to OpenAI" accessibility labels; the fitted sheet detent at default and AX sizes and with
   the keyboard up; decision 4 (disclosure dropped) — anything D56–D58 still requires the Settings
   screen to say?
5. Identifiers and tests: kept/changed/new identifiers in the ticket versus the code; the neighbour
   tests updated (`ExportUITests`, `AskAIUITests` key settings, `HeartRateUITests`,
   `FloodlightWorkoutTabUITests` appearance, `RedesignScreenshotUITests` unit system/test05) — anything
   they no longer prove; `FloodlightSettingsUITests` assertions that could pass vacuously; the
   `-uiTestDesignSettings` fixture only active with `-uiTestReset` and the fixture key never reaching a
   real keychain.
6. Look and accessibility per REVIEW.md: one bold element per screen state (the unit tiles; On/Off;
   the pending count; Save key / Export CSV / Share as the single fill), light/dark, AXL layouts,
   VoiceOver (tile selected state, the stepper pills' adjustable value, the flood switch's
   representation, cards' combined labels, the decorative tally hidden), 44 pt targets, Reduce
   Motion, strings listed vs actual, contrast of the faint tally marks and tertiary captions.
7. Verification scope per DEVELOPMENT, and any product change ticket 09 does not list.

Do NOT run xcodebuild or simctl. Do not modify files other than the report. Report findings by
severity (critical / high / medium / low) with file:line and a concrete failure case, or say
"clear" in one paragraph. Write the report to `work-record/redesign-floodlight/codex-review-09.md`.
