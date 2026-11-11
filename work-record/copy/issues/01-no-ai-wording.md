# C1 — No "AI" in the app's wording, except feature names

Type: task (copy)
Status: **done — Codex clear (C1 clear from round 1; the combined review cleared in round 3), merged with N9b** (2026-11-11) — **grouped with N9b** (the user, 2026-11-10: build C1 and N9b, then run the tests and the Codex review
once for both, as one task; one branch)
Implementer: Claude; Reviewer: Codex, to "clear".
Decision: D83 (8) extended app-wide by the user, 2026-11-10: "get rid of all wordings that say using ai since the users
of the app already know that app is using ai for things."

## Scope (wording approved by the user, 2026-11-10)

**Keep — feature names:** "Ask AI", "Ask AI for Templates", "Asking AI…", "Ask AI about this plate", "Today's AI".

**"with AI" phrases:**
- "Sign in to identify equipment with AI." → "Sign in to identify equipment." (`Features/Gyms/Scan/ScanSteps.swift`)
- "Sign in to create routines with AI." → "Sign in to create routines." (`Features/Templates/AIRoutine/AIEquipmentStep.swift`)
- "Suggest exercises with AI" → "Suggest exercises" (`Features/Gyms/ModelPicker.swift`, `Features/Settings/AskAISettingsSheet.swift`)
- "Suggested by AI" → "Suggested" (`Features/Gyms/Scan/ScanExercisePicker.swift`)
- "Used for your nutrition goals, heart rate zones and AI suggestions." → "…heart rate zones and suggestions."
  (`Features/Nutrition/PersonalDetailsView.swift`)
- "Sign in to use AI." — kept (no clear rewording; Claude's proposal, not objected to).

**Error messages starting with "AI…"** (`Domain/AIServerClient.swift`, `TerraAPI.swift`, `AIRoutine.swift`,
`PlateTranscription.swift`, `Features/Gyms/…`): drop the subject, e.g. "AI took too long. Try again." → "Took too long.
Try again."; "AI is paused right now. You can continue manually." → "Scanning is paused right now. You can continue
manually." (or the flow's own noun); "AI could not identify this equipment. …" → "Couldn't identify this equipment. …".
Each rewritten line is listed here before merge.

## Acceptance

1. No user-facing string outside the feature names above says "AI" (a grep over string literals, listed in this ticket).
2. UI tests that read these strings move with them (search `WorkoutTrackerUITests` for each old string).
3. Captures of the changed screens; Codex clear.

## Progress

**Built (Claude, 2026-11-10, branch `ericlee4992/c1-n9b`).** Rewritten lines:

| Where | Before | After |
|---|---|---|
| `Gyms/Scan/ScanSteps.swift` | Sign in to identify equipment with AI. | Sign in to identify equipment. |
| `Templates/AIRoutine/AIEquipmentStep.swift` | Sign in to create routines with AI. | Sign in to create routines. |
| `Gyms/ModelPicker.swift`, `Settings/AskAISettingsSheet.swift` | Suggest exercises with AI | Suggest exercises |
| `Gyms/Scan/ScanExercisePicker.swift` (VoiceOver) | Suggested by AI | Suggested |
| `Nutrition/PersonalDetailsView.swift` | …heart rate zones and AI suggestions. | …heart rate zones and suggestions. |
| `Onboarding/Tour.swift` | Your profile: units, appearance, AI and backups… | Your profile: units, appearance, Ask AI and backups… |
| `Gyms/ScanMachineLabelSheet.swift` | What AI read | What Ask AI read |
| `Gyms/ScanMachineLabelSheet.swift` | AI could not find a name plate in the box. | Couldn't find a name plate in the box. |
| `Gyms/ModelPicker.swift` | AI could not tell which exercises this machine serves. | Couldn't tell which exercises this machine serves. |
| `Gyms/Scan/ScanResultStep.swift` | AI could not identify this equipment. Try a clearer angle… | Couldn't identify this equipment. Try a clearer angle… |
| `Domain/AIServerClient.swift` | Too many AI tries today. Try again after … | Too many tries today. Try again after … |
| 〃 | Another AI request is still running. … | Another request is still running. … |
| 〃 | AI is paused right now. You can continue manually. | This feature is paused right now. You can continue manually. |
| 〃 | AI took too long. Try again. | Took too long. Try again. |
| 〃 | AI is unavailable right now. Try again later. | This feature is unavailable right now. Try again later. |
| 〃 | AI could not help with this request. … | Couldn't help with this request. … |
| 〃, `Domain/TerraAPI.swift` | AI returned an incomplete or invalid result. … | Got an incomplete or invalid result. … |
| 〃 | AI couldn't take this request. Continue manually. | Couldn't take this request. Continue manually. |
| `Domain/AIRoutine.swift` | AI returned an invalid session. Try generating again. | A generated session was invalid. Try generating again. |
| 〃 | AI returned unavailable equipment or invalid targets. … | The generated week used unavailable equipment or invalid targets. … |
| `Domain/PlateTranscription.swift` | AI declined to read this photo. | Couldn't read this photo. |
| 〃 | AI's answer could not be read. | The answer could not be read. |

**Own decisions (Claude):** the shared server errors carry no flow, so "paused" / "unavailable" say "This feature"
rather than a flow noun. **Kept** (feature names or approved): "Sign in to use AI."; "Ask AI needs a connection…" and
the other `PlateTranscription` lines that start with the feature name; "Make a template, or ask AI for a week, in Train."
(the feature, lower-case in a sentence); the fixture-only "AI calls: N" tally (`AskAI.fixtureIsEnabled`, UI tests only).

**Grep (acceptance 1):** `rg -n '"[^"\n]*\bAI\b[^"\n]*"' WorkoutTracker -g '*.swift'` minus comments and the feature
names leaves only the three kept lines above.

**Not changed — for the user:** the camera and photo-library permission prompts (`INFOPLIST_KEY_NSCameraUsageDescription`
/ `…PhotoLibraryUsageDescription`) say "With your permission, AI identification sends the photo through Stacked's server
to OpenAI…". They are privacy disclosures (what leaves the phone, to whom), so Claude left them; they also mention only
equipment, not food photos (N7). Proposed if wanted: "Photograph equipment, its label or your food. With your
permission, the photo goes through Stacked's server to OpenAI to be identified; the app keeps only the photos you log
with food." Server privacy page (`server/src/pages.ts`) keeps "AI features" — it describes them.

**Tests moved:** `AIServerClientTests` (`linesTheUserApproved`, the scan / routine split expectations),
`AIRoutineFlowMathTests.errorTextSplitsWhatFromWhatToDo`. No UI test reads a changed string
(`FloodlightScanUITests` reads the "Suggested" header, which the VoiceOver label now matches).

**Verification (one pass for C1 + N9b, 2026-11-10; scope per DEVELOPMENT — a new feature: its tests plus adjacent flows;
C1: the flows whose text changed).** Build-for-testing exit 0. `HealthNutritionSyncTests` 15 × 10 = 150/150
(`/private/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-UI-design/20f5b25b-92e7-448e-a00d-dbd68fee92a9/scratchpad/c1n9b-health10.xcresult`); Unit plan 1,247/1,247 (`c1n9b-unit`); `AppleHealthUITests` + warm-up 5/5
(`c1n9b-ui1`, captures looked at: `att1/`); BodyWeight, TodayFood, FloodlightProfile, FloodlightScan,
FloodlightAIRoutine, NutritionGoals + warm-up 65/65, 2 workers (`c1n9b-ui2`). AskAIUITests not run: no test there reads a
changed string; the changed error lines are unit-tested.

```
Verified: HealthNutritionSyncTests 150/150, Unit plan 1,247/1,247, AppleHealthUITests 5/5, affected UI classes 65/65 — exit 0 each
Not verified: the real HealthKit store (permission sheets, sync-version replacement, deletes) — the Simulator/phone check at R; AskAIUITests; VoiceOver by a person
Known flaky: none seen
```

## Comments
