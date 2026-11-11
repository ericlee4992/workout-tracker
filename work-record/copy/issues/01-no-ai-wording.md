# C1 — No "AI" in the app's wording, except feature names

Type: task (copy)
Status: ready — next, **grouped with N9b** (the user, 2026-11-10: build C1 and N9b, then run the tests and the Codex review
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

## Comments
