# 09 — Floodlight: Settings

Type: feature (part of [01](01-implement-redesign.md), area order item 8)
Status: in progress
Implementer: Claude. Reviewer: Codex.
Branch: `ericlee4992/redesign-floodlight-settings` (scratch checkout `/tmp/wt-floodlight/settings`),
stacked on the ticket-08 exercises tip `bf4363b` (Codex clear). Nothing merged to `main`; nothing installed.

## User decisions (2026-09-28, asked in session)

1. **Last export is recorded when sharing finishes.** The date and format are stored only when the
   share sheet reports a completed action (Save to Files, AirDrop, Copy…), never on Cancel. Stored on
   this phone only (`@AppStorage`, like Appearance): no SwiftData or export-format change. It powers
   "N workouts since last export", the tally strip's export mark, "Last export <day> · CSV" on
   Settings, and the "This phone holds the only copy until you export." line, which rests for 3 days
   after an export.
2. **Export opens the share sheet at once, and the file card stays.** One tap on Export CSV / JSON
   builds the file and presents the share sheet as today; when it closes, the file card (name,
   counts, **Share**) stays so the same file can be shared again without rebuilding. The staged file
   is deleted when the next export replaces it or the screen goes away.
3. **The saved key shows as a masked hint, last 4 characters only** ("sk-…a1b2"; a key not starting
   "sk-" shows "…a1b2"; a key shorter than 8 characters shows no characters). Reverses the old
   sheet's "never shown back" rule for those 4 characters only.
4. **The Ask AI disclosure paragraph is dropped (prototype).** The sheet keeps the three permissions
   under "Send to OpenAI", the "OpenAI API data policies" link and "Kept in this phone’s keychain
   only." Gone: "GPT-5.6 Terra identifies equipment and drafts weekly routines… API usage is billed to
   your key. OpenAI may retain data under its API policies." and "Private trial: use your own OpenAI
   API key." D56–D58 consent behaviour is unchanged: three independent, revocable flags, each still
   asked for at the point of use.

Record decisions 1–4 with the D54 entry before merge.

## Scope

Ticket 01 area 8 in the approved Floodlight design. Reference: prototype captures taken 2026-09-28 into
`../reference/prototype-settings/{dark,light}/` (`LOOKS=final APPEARANCE=dark|light AXL=1 SETTLE=4
scripts/capture.sh all … X01 X01:p2 X01:p3 X01:metric X02 X02:noKey X02:typing X02:remove X03
X03:failure X03:done X03:exporting`, dark then light, one at a time).

1. **X01 Settings (pushed from the Workout tab's gear).** Large title "Settings" (inline title once
   scrolled). **Units (bold element):** two choice tiles, "Metric kg km" / "U.S. customary lb mi",
   the selected one outlined with a check; one notice "Logged sets keep the unit they were entered
   in." **Appearance:** System / Light / Dark as segmented pills. **Workout:** one list — Working
   rest and Warmup rest as m:ss stepper pills (0–10:00, 15 s), "Ask to update templates" switch (the
   inverse of `driftPromptSuppressed`). **Heart rate zones:** a pressable card — the maximum in bpm
   (or "Not set" + "Set up zones"), the five-zone ramp with each lower bound; opens the existing max
   heart rate sheet. **Ask AI:** a pressable card, On/Off; opens X02. **Export:** a pressable card,
   "N workouts · N sets" with "Last export <day> · <format>" under it, pushes X03; the only-copy
   notice under it (decision 1). **History update** (D51, only when sets moved): its own row at the end.
2. **X02 Ask AI (sheet).** Header "Ask AI" · **Done**. **Key card (bold element):** sparkles disc,
   "On" + the masked hint (decision 3) or "Off"; the secure field ("OpenAI API key" / "Replace the
   saved key"); **Save key** (filled) appears only once something is typed; "Kept in this phone’s
   keychain only." Save errors show in the card. **Send to OpenAI:** Equipment photos · Scan Machine,
   Routine details · Ask AI for Templates, Model details · Suggest exercises with AI (switches, applied
   at once), then "OpenAI API data policies" ↗. **Remove key** (destructive row, only with a key) now
   asks first: "Remove the saved key?" / "Ask AI turns off until you add a key." / Remove key.
   The sheet opens at its content height (drag up for full), full height at AX sizes.
3. **X03 Export (pushed).** Large title "Export". **Backup panel (bold element):** the count of
   workouts started after the last export (all workouts if never exported), "workout(s) since last
   export", "Last export <day> · <format>"; under it the tally strip — every workout a mark on a date
   line from the first workout to today, solid up to the export mark, faint after it (pulsing while a
   file is built; Reduce Motion: steady). A stat strip: Workouts · Sets (plus "N completed" when some
   sets are not completed, as the old summary said). The only-copy notice (emphasized). **Export CSV**
   (filled) and **Export JSON** (secondary). Done: the file card (glyph with a check, file name,
   "N workouts · N sets", **Share** filled; Export CSV steps down to secondary). Failure: the warning
   panel "Export failed: couldn’t save the file." with the system's reason under it (implementer's
   choice: the reason is kept, as the old footnote gave it, but on its own line so a long file name
   cannot break the headline).

Not in this ticket: the max heart rate sheet's restyle (L12, a live-workout sheet); the prototype's
capture variants and paging helpers; the study looks' branches.

## Prototype features the real app lacked (approved with the prototype; each can be vetoed)

- Units as tiles, the unit notice; Appearance as pills (was a menu).
- "Ask to update templates" (was "Suppress template update prompts", inverted).
- Heart-rate zone ramp on the row; the Ask AI row renamed from "Ask AI about plates" (ticket 01 user
  decision in the prototype).
- Export as its own screen: the backup panel and tally strip (decision 1), stat strip, file card
  with Share (decision 2), the warning-panel failure.
- X02: key-first card with the masked hint (decision 3), Save key appearing once typed, short
  permission labels under one header, Remove key confirmation, disclosure dropped (decision 4).

## Domain (derived on read, unit-tested)

`Domain/ExportRecord.swift` — the per-device last-export record and the backup readouts:
- `ExportRecord` (`lastExportAt`, `format`; `@AppStorage` keys `exportLastAt` / `exportLastFormat`,
  cleared under `-uiTestReset`).
- `BackupStatus.pending(workoutDates:lastExport:)`, `showsOnlyCopyNotice(lastExport:now:)` (3 days),
  `lastExportLine`, `tallyMarks(dates:now:calendar:)` (day index from the first workout, stack within
  the day, span), `exportDay`.
- `AskAIKeyHint.masked(_:)` (decision 3).

## Screen jobs, bold element, wireframes (ios-design steps 1–2)

- **X01:** exists to set how the app measures and behaves; the eye lands on the Units tiles (top).
  Runner-up (Appearance) is plain pills; the cards below are quiet rows.
- **X02 with a key:** exists to see Ask AI is on and change its permissions; the eye lands on "On"
  and the hint. Without a key: on "Off" and the field; Save key is the one filled command once typed.
- **X03:** exists to back up; the eye lands on the pending count (top), the thumb on Export CSV (the
  one filled command). Done: on the file card's Share.

```
X01                          X02 (sheet)                  X03
┌──────────────────────┐    ┌──────────────────────┐     ┌──────────────────────┐
│ <                    │    │      Ask AI    (Done)│     │ <                    │
│ Settings             │    │┌────────────────────┐│     │ Export               │
│ Units                │    ││(✦) On              ││     │┌────────────────────┐│
│┌─────────┐┌════════┐ │    ││    sk-…a1b2        ││     ││ 7 workouts since   ││
││Metric   │║US cust✓║ │    ││────────────────────││     ││   last export      ││
││kg km    │║lb mi   ║ │    ││[Replace saved key] ││     ││ ▮▮▮▮▮▮▮|▯▯▯ ▯      ││
│└─────────┘└════════┘ │    ││🔒 Kept in keychain ││     │└────────────────────┘│
│ ⚖ Logged sets keep…  │    │└────────────────────┘│     │[22 Workouts|335 Sets]│
│ Appearance           │    │ Send to OpenAI       │     │ ▯ This phone holds…  │
│ [System|Light|Dark]  │    │┌────────────────────┐│     │[■■ Export CSV ■■■■■] │
│ Workout              │    ││Equipment photos (●)││     │[   Export JSON     ] │
│┌────────────────────┐│    ││Routine details  (●)││     │┌────────────────────┐│
││Working rest [-2:00+]││    ││Model details    (○)││     ││✓ workout-tracker…  ││
││Warmup rest [-1:00+]││    ││Data policies     ↗ ││     ││ [■■■ Share ■■■]    ││
││Ask to update    (●)││    │└────────────────────┘│     │└────────────────────┘│
│└────────────────────┘│    │[🗑 Remove key       ]│     └──────────────────────┘
│[♥ HR zones 185 bpm >]│    └──────────────────────┘
```

Relative sizes: X01 the unit figures `heroNumber` (the one hero per state), the HR maximum `statNumber`;
X02 "On/Off" `bigNumber`; X03 the pending count `heroNumber`, stats `statNumber`.

## Tells (ios-design step 4)

- Same container on everything: absent — tiles only for the unit choice; one list for Workout; a
  card per destination row (Heart rate, Ask AI, Export) because each opens something with internal
  structure (the ramp, the status, the counts); section headers and notices sit on the ground.
- Chips: absent.
- All-caps labels: absent.
- Middle-dot metadata: deliberate for "22 workouts · 335 sets" and "Last export Sep 12 · CSV" (the
  frozen summary line).
- Accent everywhere: absent — violet fills only Save key / Export CSV / Share (one per state);
  switches are the neutral flood switch, selection is an outline.
- Equal full-width blocks: deliberate for the two unit tiles (equal choices); X03 leads with the panel.
- Phone-sized website: absent.
- Control dressed as primary: absent — Done is a glass capsule, Remove key a quiet destructive row.
- Only survives default size: answered by AXL captures (unit tiles stack, rows stack their trailing
  steppers, the backup count stacks over its label, the stat strip becomes rows, the sheet opens
  full height).

## Rules and identifiers kept

Kept: `openSettings`, `appearanceSetting` (now the pills; options are buttons "System"/"Light"/
"Dark"), `appUnitPreference` (the tile group; tiles `appUnitPreference.<raw>`), `heartRateZonesSettings`,
`askAISettings`, `dumbbellMoveNote`, `exportCSV`, `exportJSON`, `exportFailure`, `askAIStatus`, `askAIKeyField`,
`askAISaveKey`, `askAIRemoveKey`, switch labels "Send equipment photos to OpenAI" / "Send routine
details to OpenAI" / "Send model details to OpenAI" (accessibility labels).
Changed: `exportSummary` (a footnote under the Export header) → the `exportSettings` card, whose
label starts with the same count text.
New: `exportSettings` (the card), `exportPending`, `exportFileCard`, `exportShare`, `globalWorkingRest`,
`globalWarmupRest`, `askToUpdateTemplates`, `askAIDone`, `askAIKeyHint`.
Rules: D25 (units never rewrite entered values — the notice says so), D45/D52 (plain bpm), D51 note,
D56–D58 (consents independent/revocable; key device-only), export fidelity (the files are unchanged:
`ExportCollector`/`ExportCSV`/`ExportJSON` untouched).

## New / changed visible strings

New: "Units", "Metric"/"U.S. customary" tile words "kg km"/"lb mi", "Logged sets keep the unit they
were entered in.", "Workout", "Working rest", "Warmup rest", "Ask to update templates", "Set up zones",
"Ask AI" (row), "Export" (section), "Last export <day> · <format>", "History update" subtitle "N sets
moved to dumbbell exercises" with the date trailing, "workout(s) since last export", "Workouts", "Sets",
"N completed", "Export failed: couldn’t save the file.", "Share", "Send to OpenAI", "Equipment photos",
"Routine details", "Model details", "Scan Machine", "Ask AI for Templates", "Suggest exercises with
AI", "Remove the saved key?", "Ask AI turns off until you add a key.".
Changed: "Ask AI about plates" → "Ask AI"; "Suppress template update prompts" → "Ask to update
templates" (inverted); "Working rest · 2:00" → the row + pill; "App unit preference" menu → tiles;
the three "Send … to OpenAI" toggle titles → short labels (accessibility labels keep the full words).
Removed: the Ask AI disclosure paragraph and "Private trial…" footer (decision 4); the "Permissions" /
"Key" section headers; "Counting…".

## Tests (planned)

- Unit `ExportRecordTests`: pending (never exported, exported, same-instant boundary), notice rest (3
  days), tally marks (day index, stacking, span), last-export line, key hint masking.
- UI: new `FloodlightSettingsUITests` — captures X01 (top, paged to the end, metric), X02 (with key,
  no key, typing, remove confirmation), X03 (idle, done card, failure) light/dark × Default/AXL; flows:
  units tile switches and persists; rest steppers; the template switch writes the inverse; Ask AI save
  → On + hint, remove asks first; export → share sheet → completed action records the last export
  (pending 0, the card's line) and Cancel does not; failure under `-uiTestExportFails`.
- Updated neighbours: `ExportUITests`, `AskAIUITests` key settings (×2), `HeartRateUITests` zones row,
  `FloodlightWorkoutTabUITests` appearance, `RedesignScreenshotUITests` test05_settings and the unit
  switcher.

## Verification

Runner `/tmp/wt-floodlight/set-run.sh <name> build|test …` (NEW derived data `/tmp/wt-floodlight/dd-settings`);
logs, `.exit` files and result bundles `/tmp/wt-floodlight/results/settings-*`.

## Progress

- 2026-09-28: resumed in a fresh session; verified the branch (settings = exercises tip `bf4363b`,
  pushed, clean; nothing merged or installed). Read ticket 01/08, the prototype Settings area and the
  real Settings code; prototype captured (dark: exit 0, 24 PNGs, all with content). User decisions 1–4
  recorded. Ticket written.
