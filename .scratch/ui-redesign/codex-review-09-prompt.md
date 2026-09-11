Round 1 (T6) of UI-redesign ticket 09 — the last one: empty states, the app icon, the Live
Activity tint, docs — on the Ink / Amber design system (which YOU built; Claude built this
ticket, so you review). Ticket: .scratch/ui-redesign/issues/09-empty-states-icon-live-activity.md;
the plan: .scratch/ui-redesign/spec.md ticket 09 (NOTE two documented deviations: amber, not the
plan's coral, for the icon and the Live Activity — D54 is amber). Boundary: main..HEAD on branch
ui-redesign-09 (main = f340a75, ticket 08).

Files: WorkoutTracker/Features/ActiveWorkout/AddByMachineSheet.swift, MachinePickerSheet.swift,
Features/Gyms/MachineDeletion.swift (EmptyState), scripts/render-app-icon.py (new) +
WorkoutTracker/Assets.xcassets/AppIcon.appiconset/{AppIcon.png,Contents.json},
WorkoutTrackerWidget/WorkoutActivityView.swift, docs/SPEC.md ("Visual design"), docs/DECISIONS.md
(D54 final), docs/STATE.md.
Screenshots: .scratch/ui-redesign/screenshots/09/ (08-empty-history, 08-empty-gyms, 01-root) and
the icon PNG itself.

Scope:
1. EmptyState inside a `List` row (AddByMachine, MachinePicker, DeletedMachines): the component
   is `frame(maxWidth: .infinity)` + 24 pt padding; on a SHEET's list is it the right weight, or
   too tall for "No machines yet" above an "Add Machine…" button? `MachineDeletionUITests`
   reads `staticTexts["No machines yet"]` and `["Nothing deleted"]` — still staticTexts?
2. The icon: read scripts/render-app-icon.py — is the geometry sound (plates symmetric, bar
   under the plates, nothing outside 1024²), is the PNG opaque RGB (iOS rejects alpha in app
   icons), does Contents.json's single universal 1024 entry with "filename" satisfy Xcode 26's
   single-size icon? Look at the PNG: does it read as a dumbbell at 60 pt?
3. Live Activity: `activityBackgroundTint(#0B0D10)` + `activitySystemActionForegroundColor`
   (amber) + amber gym label / compact figure; the heart stays `.red`. On the lock screen the
   system may blur/tint the background — is an opaque near-black tint right, or should it keep
   some transparency (the old value was `black.opacity(0.35)`)? Any Dynamic Island region
   where amber on the island's black fails contrast?
4. Docs: SPEC.md's new "Visual design" paragraph and the D54 addendum — accurate against what
   shipped in 01–09 (list any claim you cannot verify from the tree)?
5. Copy policy: every string byte-identical? Any `ContentUnavailableView` or plain "No … yet"
   left in the app (grep)?

Do NOT run xcodebuild or simctl (the simulator is in use). Review by inspection; verification is
in the ticket. Report by severity with file:line, or say "clear" in one paragraph. Do not modify
source files. Write to .scratch/ui-redesign/codex-review-09.md
