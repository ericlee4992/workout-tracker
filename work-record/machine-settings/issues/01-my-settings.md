# 01 — My settings: a setup note per machine and exercise

Status: **real build in progress** (branch `ericlee4992/my-settings`) — the user approved the prototype 2026-11-17
("looks good. get started"). Codex reviews the real build.
Type: task (prototype done; tag `design/my-settings-prototype`)
Decision: [D91](../../../docs/DECISIONS.md) (approved).

## The request

Item 1 of [the competitor-gaps research](../../research/2026-11-13-competitor-gaps.md) ("machine setup notes (seat,
pins)" — requested in other apps, rarely delivered). On 2026-11-16 the user asked where it should go so it is
convenient and easy to navigate, and asked Claude and Fable for independent takes. Both proposed the same shape
(below); the user then decided the three open points:

1. **Per machine AND exercise** (the user, 2026-11-16): one note per gym machine (`MachineInstance`) × exercise.
2. **Name: "My settings"** (the user), not "Setup" — the machine page already has a "Setup" section.
3. **First-use hint: yes** (the user).

## The design (agreed)

- **Data:** one free-text note per gym machine × exercise. A cable tower used for rows and pushdowns holds a separate
  note for each; a single-exercise machine behaves like one note per machine. Never shared across gyms, across
  `EquipmentModel` or `Exercise`, and never keyed on preset. It is **current, not history**: not in the D23 snapshot,
  not shown in History, never sent to AI, left off the Lock Screen (space, and an injury note on a public surface).
  The real build's export and safety copy must carry it.
- **Live workout card** (`ExerciseEntryCard`, right after the machine row, before the bar row): its own line — the
  note in full, wrapping at AccessibilityL, never truncated (not `EquipmentRow`'s 2-line subtitle). Shown only when a
  note exists. Tap → a small sheet with one text field, Cancel / Save (like `BarPickerSheet`); Cancel discards; the
  placeholder teaches the format ("Seat 4 · pad 2 · elbow hurt at 4"); saving a blank note removes it.
- **Card "⋯" menu:** "My Settings…", only when the entry has a machine.
- **First-use hint:** an "Add My Settings" chip on the card when this machine has no finished history for this
  exercise; gone once a note exists or after that first workout.
- **Machine page** (`MachineDetailView`, Setup section): a "My settings" row per supported exercise (one on a
  single-exercise machine, "My settings · <exercise>" rows on a station), each editable there. The machine page is
  reached from Gyms and Exercise detail only (not during a workout), so the card is the main editor.

## Progress

### 2026-11-16 — prototype (UI-first), waiting for the user

Branch `ericlee4992/machine-settings-prototype` off `main` `9d7ac436` (worktree
`~/.paseo/worktrees/1qmeipq9/machine-settings`). Built in the app itself (N13's precedent), so the approved views
become the real ones:

- `WorkoutTracker/Features/ActiveWorkout/MySettingsViews.swift` — the views to keep: `MySettingsCardLine`,
  `MySettingsAddChip`, `MySettingsMachineRow`, `MySettingsSheet`, `MySettingsCopy`. They take the note and closures
  and store nothing.
- `WorkoutTracker/Features/ActiveWorkout/MySettingsPrototype.swift` — **PROTOTYPE, throwaway**: the notes in memory,
  the sample world, the orange switcher. Hooks, each marked `PROTOTYPE (machine-settings 01)` and a no-op without the
  flag: `ExerciseEntryCard` (slot, menu item, sheet), `MachineDetailView` (rows, sheet, capture scroll),
  `ActiveWorkoutView` (switcher), `WorkoutTrackerApp.prepare` (seed).
- **Sample world** (Iron Temple, on the design sample's live Push Day): Chest Press 2 has a chest-press note; the
  Cable Station (five exercises) has notes for Triceps Pushdown ("…hurt my elbow at 4, stay at 3") and Cable Crossover;
  a new **Shoulder Press** machine on the Machine Shoulder Press card has no history (→ the chip); the Incline Press
  has history and no note (→ nothing shown); Lateral Raise has no machine (→ no menu item).

**Run:** `xcodebuild -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -destination 'platform=iOS
Simulator,id=47D21838-69A6-4BCB-AE90-B0D9C0AAA70B' -derivedDataPath build/dd-prototype build`, install the `.app`
on WT-iPhone27 and launch with
`-uiTestReset -uiTestDesignSample -uiTestDesignLive -uiTestDesignGyms -mySettingsPrototype`.
The orange "Prototype · …" capsule opens Live Workout, each machine page (Chest Press 2, Cable Station, Shoulder
Press, Incline Press), Appearance (System / Light / Dark) and Reset Sample Notes. Capture-only arguments:
`-mySettingsPrototypeFirst <exercise>`, `-mySettingsPrototypeEditor <exercise>`, `-mySettingsPrototypePage <machine>`,
`-mySettingsPrototypeScroll <points>`, `-mySettingsPrototypeCapture` (hides the switcher).

**Captures:** [`../captures/01-prototype/`](../captures/01-prototype/) — `1-card-note`, `2-card-hint`,
`3-card-station`, `4-editor`, `5-page-single`, `6-page-station`, each light/dark × default/AXL, and one contact sheet
per mode (`sheet-*.png`).

**Verified:** `xcodebuild build` exit 0 (WT-iPhone27, iOS 27); installed and launched on WT-iPhone27; the 24 captures
show the card line, the chip, the station card, the editor (opened through the card's sheet binding), and both
machine pages, in all four modes.
**Not verified:** no tests (prototype); taps were not driven by automation (no touch tool on this Mac) — the menu
item, chip and line all set the same binding the editor capture used; at AccessibilityL the live workout's rest slab
covers the lower part of a card until scrolled (existing layout).
**Known:** the hint's "gone after the first workout" cannot be shown in the prototype (finishing would use the sample
store, and the history pairs are read once at launch).

## Questions for the user

1. Convenience on the card: is the note line under the machine where you'd look, and is tap-to-edit enough?
2. The first-use chip: useful or noisy?
3. The station's per-exercise rows on the machine page: clear, or too many "Add…" rows?

## Real build (after approval)

Schema change (Gate S: DEVELOPMENT's migration + backup steps): a new owned row or field, cascade-deleted from
`MachineInstance` (AGENTS.md delete rules), CloudKit-compatible (UUID id, optional relationships, no
`@Attribute(.unique)`); export and the safety copy carry it; unit tests for the key (machine × exercise), first-use and
blank-removes; UI tests for card edit/cancel and the machine page; remove the prototype file and hooks; Codex review.

### 2026-11-17 — the real build

The user: "looks good. get started" (questions 1 and 3 answered by approval). Branch `ericlee4992/my-settings` off the
prototype branch (prototype kept at tag `design/my-settings-prototype`, `0916cc97`).

- **Data (stored-format change, Gate S):** `Domain/MachineSettings.swift` — `MachineSettingsNote` (`exerciseID`,
  `text`, `updatedAt`, `machine`), owned by `MachineInstance.settingsNotes` (`.cascade`), added to
  `WorkoutTrackerStore.modelTypes`. No `@Attribute(.unique)`; one row per machine × exercise is app-side, the canonical
  row (latest `updatedAt`, then `id`, `CanonicalRow`) counts, and **a blank canonical row is a cleared note** — so a
  cleared note can't let an older sync duplicate resurface, and a failed save is undone exactly (the row's text and
  date put back, or the new row removed; nothing pending). `MachineSettings.note(on:exerciseID:)` reads the machine's
  own rows (no fetch per render); `save(_:on:exerciseID:)`; `hasFinishedHistory(machineID:exerciseID:)` by the D23
  snapshot (the first-use chip).
- **Card** (`ExerciseEntryCard`): the line or the chip under the machine row; "My Settings…" in "⋯" when the entry
  has a machine; the sheet saves through `MachineSettings` and shows "Couldn't Save" on a failure (the text stays).
  The history check runs once per machine × exercise (`.task(id:)`); a failed check hides the chip (the menu still
  works).
- **Machine page:** a row per served exercise plus any other exercise the machine has a note for (a machine without
  a model used for something it doesn't list never hides a saved note).
- **Export v15:** `machineSettings` rows (id, machineID, exerciseID, text as stored, updatedAt) and the count; a
  note's exercise counts as referenced (D28). CSV unchanged. The safety copy copies the store files, so it carries
  the notes as it is.
- **Format guard:** `StoreFormatGuardTests.build16Fingerprint` `9d83c203…` (0.2.0 (12)–(16)); new
  `approvedFingerprint`; fixture `Fixtures/Build16.store` (written by `9d83c203…`-format code — the prototype build,
  no model change — with `-uiTestDesignSample -uiTestDesignGyms -uiTestDesignHistory`, WAL checkpointed, single file)
  + `MachineSettingsMigrationTests`.
- **Fixture:** `-uiTestDesignMySettings` (with Live + Gyms): the three sample notes and the Shoulder Press machine.
- **Prototype removed:** `MySettingsPrototype.swift` and its hooks.
- **Tests:** `MachineSettingsTests` (key, update, blank, duplicates, failed save ×2, cascade, archive, history,
  snapshot, export v15, v14 decode), `MachineSettingsMigrationTests`; `MySettingsUITests` (card Cancel/Save/clear,
  chip → line, menu item, station rows, single row, captures ×4) in the Workout plan.

## Comments

### 2026-11-16 — the user: keep the first-use hint as is

The user asked why the Machine Shoulder Press card shows "Add My Settings" and the Incline Press doesn't (the
Incline Press has sample history; the chip is first-use only). Offered: (1) keep it first-use only, the "⋯" menu and
the machine page otherwise, or (2) show it whenever there is no note, with a per-machine "Not needed". **The user:
"keep it as is."** Known trade-off: a machine used before the feature never shows the chip; its note is added from
"⋯ → My Settings…" or the machine page. Question 2 above is settled; 1 and 3 are still open.
