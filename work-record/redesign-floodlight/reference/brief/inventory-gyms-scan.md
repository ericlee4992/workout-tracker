# Inventory — Gyms, machines, scanning, AI identity (redesign fact base)

Repo: `/Users/ericlee06/orca/projects/Health App`, branch `ericlee4992/redesign-visual-proposal`, HEAD `a0364f2`.
Read-only survey of `WorkoutTracker/Features/Gyms/*`, plus `Features/Settings/AskAISettingsSheet.swift`
(presented from the scanner) and the shared design primitives it uses. Nothing was edited or built.
Items marked **[J]** are UX judgments. Everything else is taken from the source.

---

## 0. Global context the redesign inherits

### 0.1 Theme and primitives used in this scope
- **The app is forced dark.** `WorkoutTracker/App/WorkoutTrackerApp.swift:85` sets `.preferredColorScheme(.dark)`. Theme doc comment: "Ink, graphite and amber."
- Colour tokens (`Features/Design/Theme.swift:5-22`; asset values):
  - accent `#FFB45E` (amber)
  - onAccent `#15110B`
  - background `#0B0D10`
  - card `#171B21`
  - elevated `#222831`
  - fill `#2B323C`
  - hairline white 7%
  - text `#F6F3EC`
  - secondary `#B5B9C2`
  - tertiary `#7F8793`
  - danger `#FF6B76`
  - unitKg `#97C7EE` (blue)
  - unitLb `#A8CDBF` (sage green)
- Radii: card 24, inner 16, field 10. Spacing: 4/8/12/16/24.
- Fonts:
  - `hero` = largeTitle rounded black
  - `stat` = title2 rounded bold
  - `cardTitle` = headline bold
  - `label` = caption2 semibold
- `.card()` (`Design/CardStyle.swift`) draws the card fill, a radius-24 rounded rectangle and a 1 pt hairline stroke. It also has an `elevated` level, which is unused in this scope.
- `.buttonStyle(.primary)` (`Design/ButtonStyles.swift:3-18`) is amber fill with onAccent text and a minimum height of 52. It fades to 0.35 opacity when disabled. When pressed it scales to 0.97 with `.snappy(0.2)`, and that scale is **disabled under Reduce Motion**.
- `.buttonStyle(.secondary)` (`:20-33`) uses the fill background, a minimum height of 44 and 0.65 fill opacity when pressed. It has no motion.
- `Chip` (`Design/Chip.swift`) is a capsule with a 12% tint background and caption semibold text. `UnitChip` / `UnitBadge` shows "kg" in blue or "lb" in green. `UnitBadge` is defined at `Start/StartWorkoutView.swift:405`.
- `EmptyState(title:symbol:)` (`Design/EmptyState.swift`) is a 128 pt ring around a 96 pt tinted disc, with the symbol in largeTitle amber and an extra `sparkle` glyph offset to the top-right. It sits above the title, set in `cardTitle`.
- `BrowseMenuOption` (`Features/BrowseMenuOption.swift`) is a menu Button that shows a checkmark `Label` when selected. It is used instead of `Picker` so every option can carry an accessibility id.
- **Haptics:** none in this scope. `Design/Haptics.swift` defines only workout feedback: setComplete, restDone and workoutStart.
- **Animations and transitions:** none in this scope, apart from the primary button press. Every scan phase swap is instant.
- **Dynamic Type:** only one explicit adaptation exists. On a machine row, the model chip becomes a wrapping caption at accessibility sizes (`GymsView.swift:132, 317-323`). Everything else relies on stock `List`/`Form` behaviour. There is no `ViewThatFits`. The viewfinder overlay, shutter, pill and tiles all have fixed pixel sizes.

### 0.2 How users reach this area
- **Tab root:** `RootView.swift:47-49`, `GymsView()` with `.tabItem { Label("Gyms", systemImage: "building.2") }`. It is the third of four tabs: Workout, History, Gyms, Exercises.
- Settings no longer lives in the Gyms tab. It moved behind the gear on the Workout tab (`StartWorkoutView.swift:105-115`, id `openSettings`). **Screenshots in `work-record/ui-redesign/screenshots/*/redesign-08-empty-gyms.png` and `redesign-06-gym-detail.png` are stale:** they show Settings at the foot of Gyms and pre-card rows.
- Components in this scope that are **reused outside the Gyms tab** (any restyle must still work there):
  - `MachineEditorSheet(gym:)` is used by:
    - `ActiveWorkout/MachinePickerSheet.swift:108`: the "Equipment" sheet → "Add Machine…"
    - `ActiveWorkout/AddByMachineSheet.swift:92`
    - `Templates/AIRoutineSheet.swift:75`, as `MachineEditorSheet(gym:, startsWithScanner: true)` behind "Scan Machine". It opens the AI scanner immediately.
  - `GymEditorSheet(onSave:)` is used by `Templates/AIRoutineSheet.swift:72` ("Add Gym…").
  - `machineDeleteActions`, `DeleteMachineMenuItem` and `deleteMachineConfirmation` are also used by `ActiveWorkout/AddByMachineSheet.swift:48,50,76`.
  - `AskAISettingsSheet` is also opened from Settings (`AppSettingsSection.swift:62-74`; row "Ask AI about plates" with value "On"/"Off", id `askAISettings`) and from `AIRoutineSheet.swift:70`.

### 0.3 Decisions that constrain the redesign (from `docs/DECISIONS.md`)
- **D2:** a gym's name, city and unit, and a machine's label and unit, are editable where they are shown.
- **D3:** picking a model supplies the machine label. The label is the movement, not the hardware.
- **D10:** deleting a machine archives it and makes it restorable. A model correction must ask whether it applies to the future only or to past workouts. Renaming a model never rewrites history.
- **D23:** grouping and filtering are display-only.
- **D24:** seeded models are read-only and cannot be renamed. A user's own models are labelled "Custom", not segregated.
- **D33:** a plate scan *proposes*. It shows the text it read, candidates with scores and a "none of these" option. It preselects only at score ≥0.85 **and** a matching brand **and** a margin of ≥0.08 over the runner-up. It never auto-applies.
- **D34 / D53 / D56:** the photo is never stored. AI is used only after explicit consent, the send is disclosed in plain words and the user makes the final confirmation. An editable proposal and the option to retake are essential.
- **D35:** create-new from a scan is a user-space model, prefilled and editable.
- **D38:** the machine's "usual" preset is preselected, never binding.

---

## 1. Gyms list — `GymsView`
- **File:** `Features/Gyms/GymsView.swift:4-61`. Row view `GymRow` at `:65-112`.
- **Presentation:** tab root. `NavigationStack(path: [UUID])` with the large title "Gyms".
- **Job:** list the gyms that are not archived, open one, or add one.
- **Data:** `@Query` of gyms where `!archived`, sorted by `name`. There are no other sorts, no search and no sections.

**Layout, top to bottom.** The list is a single `Section` with a hidden scroll background on `Theme.background`.
1. One card per gym (`GymRow`):
   - A 44×44 tile showing `mappin.and.ellipse` in title2 amber, on amber at 10% with radius 14. It is hidden from accessibility.
   - `gym.name` in `Theme.cardTitle`.
   - `gym.city` in caption secondary, only when set.
   - An HStack containing:
     - a `Chip` with `dumbbell.fill` and a monospaced count of `gym.activeMachines.count`. Its accessibility label is `"\(n) machine"` or `"\(n) machines"`.
     - `UnitBadge(gym.defaultUnit)` when set. Otherwise the text **"app default"** in caption tertiary, lowercase.
   - A trailing `chevron.right` in caption semibold tertiary.
   - The card is padded by 16. Row insets are 4 on top and bottom, with no separators and a clear background.
2. Button **"Add Gym…"** with the `plus` symbol. With zero gyms it uses `.primary` (hero); otherwise `.secondary` (`:53-60`). Row insets are 8.

**Controls**
- Tapping a gym row is a `Button` that appends `gym.id` to the path and pushes `GymDetailView`. This was done so the whole card is tappable (comment `:8-10`).
- "Add Gym…" opens `GymEditorSheet()` as a sheet.
- Gym rows have no swipe actions, no context menu and no reordering.

**States**
- **Empty (0 gyms):** only the primary "Add Gym…" button. There is **no `EmptyState` illustration and no explanatory copy.** **[J]** For a first-run screen, that makes it the barest state in the app.
- **Populated:** cards, then the secondary "Add Gym…".

**Accessibility ids:** `gymRow.<gym.name>`, `addGym`.

**Motion / haptics:** none.

**[J] Observations**
- The row shows only the name, city, machine count and unit. Nothing is shown about usage, such as the last workout here, the workout count or the "current gym" chosen on the Start screen. That makes the list static and "boring".
- The pin tile is identical for every gym, so there is no per-gym identity (colour, initial or photo).
- "app default" (list) vs. "App preference" (detail and editor) vs. "Gym default" (machine editor) is inconsistent terminology for the same fall-through concept.
- There is no way to reach archived gyms (see §2, Archive).

---

## 2. Gym detail — `GymDetailView`
- **File:** `GymsView.swift:114-391`.
- **Presentation:** pushed from the Gyms list (`navigationDestination(for: UUID.self)`, `:39-43`). The title is `gym.name`, displayed **inline**.
- **Job:** show a gym's settings and its machines; add, edit, correct, delete or restore machines; edit or archive the gym.

**Layout, top to bottom**
1. **Gym info section** (`:140-162`). The row background is `Theme.card` and separators use the hairline tint.
   - "Default unit" on the left and `UnitBadge` on the right, or **"App preference"** in secondary.
   - "City" on the left and the city on the right, or **"—"**, in secondary.
   - Button **"Edit Gym…"** (`pencil`) opens `GymEditorSheet(gym:)`. Id `editGym`.
2. **Machine sections** (`:167-183`), one per `CatalogSection` from `CatalogBrowsing.machineSections(rows, by: machineGrouping)`.
   - Header: `section.title ?? "Machines"` in `Theme.label`, secondary colour, uppercased. In A–Z mode the title is nil, so the header reads "MACHINES". In grouped modes the headers are exercise names or body areas, plus a trailing **"Uncategorized"** section (`CatalogBrowsing.swift:213`).
   - Grouping modes (`CatalogBrowsing.swift:45-58`):
     - "Exercise": by the names of the machine's `supportedExerciseIDs`, alphabetical.
     - "Body area": in the order Chest, Back, Shoulders, Biceps, Triceps, Forearms, Neck, Quads, Hamstrings, Glutes, Hips, Calves, Core, Full Body.
     - "A–Z": flat, and the default.
   - A multi-exercise machine appears in **every** matching section.
   - The mode is remembered in `AppPreferences.machineBrowseGrouping`.
   - Machines are `gym.activeMachines`, sorted by label (`EquipmentLifecycle.swift:25-30`).
   - **Machine row card** (`machineRow`, `:305-363`):
     - A 40×40 tile with `dumbbell.fill` in title3 semibold amber on amber at 10% with radius 14. It is identical for every machine.
     - `machine.label` in cardTitle.
     - The model: at standard sizes, `Chip { model.displayName }` with `lineLimit(1)` and a minimum scale factor of 0.85. At accessibility sizes, the same text as a caption in secondary. With no model, **"No model"** in caption tertiary.
     - A trailing `UnitBadge(machine.defaultUnit)`, only when the machine overrides the unit.
     - Padding 16, `.card()`, insets 4.
3. **Actions section** (`:185-215`)
   - When `activeMachines` is empty: `EmptyState(title: "No machines yet", symbol: "dumbbell")`.
   - Button **"Add Machine…"** (`plus`) in `.primary`, always the hero, id `addMachine`. It opens `MachineEditorSheet(gym:)`.
   - When there are archived machines: a NavigationLink `Label("Deleted machines (\(count))", systemImage: "trash")` on a card background, id `deletedMachines`. It pushes `DeletedMachinesView`.
   - Footer: **"The model is optional — a machine without one asks for the exercise when you log with it."**

**Toolbar** (`:221-243`): trailing `Menu` with the `ellipsis.circle` icon, id `gymMenu`, containing:
- Submenu **"Group Machines By"** → "Exercise", "Body area", "A–Z". Each is a `BrowseMenuOption` with a checkmark on the current mode and the id `machineGrouping.<rawValue>` (`exercise`, `bodyArea` or `alphabetical`).
- **"Edit Gym…"**, which does the same as the in-list button.
- **"Archive Gym"** (destructive). It archives **immediately, with no confirmation**, then `dismiss()`es back to the list (`:383-390`).

**Machine row interactions**
- **Tapping a machine row does nothing.** It is not a button or link. Everything is behind a swipe or a long-press.
- Trailing swipe (`MachineDeletion.swift:15-25`): **"Delete"** with the `trash` symbol, destructive, **no full swipe**, id `deleteMachine.<label>`. It opens the delete alert.
- Context menu (`:345-362`):
  - **"Edit Machine…"** → `MachineEditorSheet(gym:, machine:)`
  - **"Correct Model…"** → `MachineModelCorrectionSheet`
  - **"Rename Model…"**, only when the machine has a model and `!model.isSeeded`. It opens the Rename Model alert prefilled with the manufacturer and model name.
  - **"Delete Machine…"** (destructive) → the delete alert.

**Dialogs on this screen**
- **Delete machine alert** (`MachineDeletion.swift:32-47`). This is an alert, not a confirmationDialog, because an iOS 26 dialog dropped Cancel.
  - Title: `"Delete \(machine.label)?"`. The fallback is "Delete machine?".
  - Buttons: **"Delete Machine"** (destructive) and **"Cancel"**.
  - Message: **"It disappears from this gym. Workouts you already logged with it keep it."**
  - Commit archives the machine (`EquipmentLifecycle.archive`).
- **Rename Model alert** (`:257-271`)
  - Title: **"Rename Model"**.
  - Text fields: "Manufacturer" and "Model".
  - Buttons: **"Save"** and **"Cancel"**.
  - Message: **"History keeps the captured name."**
  - An empty field throws, and the error is swallowed by `assertionFailure`, so the rename is silently ignored in release.
- Sheets presented from this screen:
  - `MachineEditorSheet` (add)
  - `GymEditorSheet(gym:)` (edit)
  - `MachineEditorSheet(gym:, machine:)` (edit)
  - `MachineModelCorrectionSheet`

**States**
- No machines: the EmptyState is shown with the primary Add button below it.
- With machines, in A–Z mode or in grouped mode.
- Machines include model-less ones ("No model"), unit overrides and a multi-exercise machine repeated across sections.
- With or without deleted machines (the link is hidden when there are zero).
- At accessibility text sizes, the model shows as a caption instead of a chip.

**Accessibility ids:** `editGym`, `machineGrouping.<raw>`, `gymMenu`, `addMachine`, `deletedMachines`, `machineRow.<label>` (on the card, with `.contain`), `deleteMachine.<label>`.

**[J] Observations**
- Machine rows are dead to a tap. There is no machine detail screen: nothing shows its exercises, last use, PRs per machine or preset. This is the largest "missing detail" in the scope.
- Actions are hidden in a context menu with 3–4 items. Users must discover the long-press.
- "Edit Gym…" appears twice (in the list row and in the ⋯ menu).
- The gym header is a settings form: unit and "City —" come first, which looks unfinished when the city is empty. There is no hero, stats, workout count, last visited date or machine count summary.
- "Archive Gym" is instant and irreversible from the UI. Archived gyms have **no restore path anywhere in the app** (only machines have one).
- The grouping control is two menus deep. Every machine has the same dumbbell icon, and the model chip truncates long catalog names.
- The footer copy explains an edge case at the foot of every gym.
- `Gym.notes` exists in the model (`Domain/Models.swift`, Gym) but is **never shown or edited** anywhere.

---

## 3. Deleted machines — `DeletedMachinesView`
- **File:** `Features/Gyms/MachineDeletion.swift:61-109`.
- **Presentation:** pushed from "Deleted machines (N)". The title is **"Deleted Machines"**, inline.
- **Job:** restore machines that were archived.

**Layout**
- One card per `gym.archivedMachines`, sorted by label:
  - `machine.label` in cardTitle
  - `model?.displayName ?? "No model"` in caption secondary
  - a trailing **"Restore"** button in `.secondary`, id `restoreMachine.<label>`
- **Empty state:** `EmptyState(title: "Nothing deleted", symbol: "trash")`. It is reachable only by restoring the last machine while on the screen, because the entry link is hidden at zero.
- Footer: **"A restored machine returns to the pickers as it was. Your history never left."**

**Behaviour**
- Restore is immediate (`EquipmentLifecycle.restore`). The row disappears with the default list animation, with no toast or haptic.
- There is no permanent delete. Errors go to `assertionFailure` only.

**[J] Observations**
- There is no deletion date and no workout count ("used in N workouts"). Nothing confirms a restore.
- It is a dead end once empty.

---

## 4. New Gym / Edit Gym — `GymEditorSheet`
- **File:** `GymsView.swift:396-482`.
- **Presentation:** a sheet (default large, no detents) wrapping `NavigationStack` → `Form`.
- **Reached from:**
  - "Add Gym…" (new)
  - "Edit Gym…" in the gym detail row or ⋯ menu (edit)
  - "Add Gym…" in the AI routine sheet (new, with `onSave`)
- **Title:** **"New Gym"** or **"Edit Gym"**, inline.
- **Toolbar:** **"Cancel"** (cancellation) and **"Add"** / **"Save"** (confirmation). The confirm button is disabled while the trimmed name is empty. Id `saveGym`.

**Layout**
1. If a save failed, `Text(saveFailure)` in red appears at the top.
2. Section:
   - TextField placeholder **"Name"**, id `gymName`
   - TextField placeholder **"City (optional)"**
3. Section:
   - Picker **"Default unit"** with options **"App preference"** (nil), **"kg"** and **"lb"**. Id `gymUnitPicker`. It uses the stock menu picker style.
   - Footer, new gym: **"Leave on App preference to fall through to your app-wide unit."**
   - Footer, edit: **"Changing this affects future sets only — sets already logged keep the unit you entered them in."**

**Commit semantics**
- Create inserts a `Gym` with the trimmed name and a city that becomes nil when blank.
- Edit goes through `EquipmentLifecycle.update`.
- Both then call `onSave` and dismiss. Cancel discards. Dismissing by swipe also discards, with no guard.

**[J] Observations**
- It is a stock form with no preview of the gym card.
- "fall through" is developer wording.
- Notes, location, photo and colour are not captured.

---

## 5. New Machine / Edit Machine — `MachineEditorSheet`
- **File:** `GymsView.swift:488-750`.
- **Presentation:** a sheet wrapping `NavigationStack` → `Form`.
- **Reached from:**
  - Gym detail: "Add Machine…" (new) and the context menu "Edit Machine…" (edit)
  - The active workout "Equipment" sheet and "Add by Machine" sheet (new)
  - The AI routine sheet's "Scan Machine" (new, `startsWithScanner: true`, which auto-opens the AI scanner on appear, `:660`)
- **Title:** **"New Machine"** or **"Edit Machine"**, inline.
- **Toolbar:** **"Cancel"**, and **"Add"** / **"Save"**, disabled while the trimmed label is empty. Id `saveMachine`.

**Layout, top to bottom**
1. Section: TextField **"Label (e.g. “Chest press by the window”)"**, id `machineLabel`.
2. Model section:
   - **New machine** (`:531-552`):
     - NavigationLink row **"Catalog model"** with the trailing value `model?.displayName ?? "None"` in secondary. Id `catalogModel`. It pushes `ModelPickerView` (§6).
     - Button `Label("Scan equipment…", systemImage: "camera.viewfinder")`, id `scanMachineLabel`. It opens the **AI scanner**, `IdentifyEquipmentSheet` (§9).
     - Button **"Read label on device"**, with no icon, id `scanLabelOffline`. It opens the **on-device OCR scanner**, `ScanMachineLabelSheet` (§10).
   - **Edit machine** (`:554-565`):
     - A read-only row "Catalog model" with `machine.model.displayName` or "None".
     - Footer: **"Use “Correct Model…” on the machine to change this — it asks whether to apply the correction to past workouts."**
3. **Exercises section**, shown only when `model == nil` (`:567-577`). Its header is **"Exercises"**.
   - A plain Text row for each recognized exercise.
   - NavigationLink **"Choose exercises"**, which pushes `AIExerciseSelection` (§11).
   - When the AI identified a specific model: `"\(manufacturer) \(modelName)"` in secondary.
4. `Text(saveFailure)` in red, when a save fails. It sits between sections.
5. **Preset section**, shown only when the model or recognized set serves exactly one exercise and that exercise has presets (`:579-595`).
   - Header: **"Preset"**.
   - Picker **"Usually"** with **"Ask each time"** (nil) and the preset names, sorted by (order, name). Id `machinePresetPicker`.
   - Footer: **"Preselected when you log on this machine — you can switch in one tap. Records are kept separately for each preset."**
6. Section: Picker **"Default unit"** with **"Gym default"** (nil), **"kg"** and **"lb"**. Id `machineUnitPicker`.

**Behaviour**
- Picking a model auto-fills the label with the *movement* when the model serves exactly one exercise; otherwise with the model name (`MachineLabelDefaults`). It overwrites only a label the sheet itself wrote (`modelDerivedLabel`, D3).
- An AI result sets the label (or keeps a hand-edited one), sets the recognized exercises and sets or clears the model through `EquipmentIdentityResolution` (`:624-637`).
- An on-device result: "Use This" sets the model. Create-new opens `AddModelSheet` prefilled (`:638-649`).
- **Save for a new machine** (`:722-743`). When there is no model but an AI identification, the result is resolved again:
  - `catalog` → use that model
  - `newModel` → insert a *custom* `EquipmentModel` with the recognized exercises
  - `generic` / `ambiguous` → no model
  - `recognizedExerciseIDs` are stored only when the model has no exercises.
- **Save for an edit** updates the label, unit, preset and recognized exercises.
- Cancel discards. Nothing is persisted until Add or Save.

**States**
- New vs. edit.
- Model: none, catalog, custom, or set by a scan.
- AI-identified specific (shows the brand and model line).
- Preset section present or absent.
- Save failure.
- Opened with the scanner auto-launched.

**Accessibility ids:** `machineLabel`, `catalogModel`, `scanMachineLabel`, `scanLabelOffline`, `machinePresetPicker`, `machineUnitPicker`, `saveMachine`.

**[J] Observations**
- There are three parallel ways to set the model: the "Catalog model" link, "Scan equipment…" and "Read label on device". They differ in style (link, labelled button, bare button), and it is unclear which scanner to use. The differences (AI/online vs. on-device/offline) are never explained.
- Once a model is chosen, the served exercises are invisible (the Exercises section hides).
- The recognized exercises list is plain uninteractive text.
- A save error floats unanchored between sections.
- The scan is the most "magical" moment in the app, yet it sits as a row in a settings form.
- The placeholder's example text does not match the D3 rule ("the movement, not the hardware"). That rule is explained only in code.

---

## 6. Catalog model picker — `ModelPickerView`
- **File:** `GymsView.swift:786-1027`.
- **Presentation:** pushed inside the host sheet's NavigationStack, from `MachineEditorSheet` ("Catalog model") and `MachineModelCorrectionSheet` ("Correct model").
- **Title:** **"Catalog Model"**, inline.
- **Search:** `.searchable` with the prompt **"Search manufacturer or model"**. Token matching is order-independent and punctuation-folded.
- **Job:** pick one of about 1,900 seeded models plus user models, or none.

**Layout**
1. A **"None"** row, with a checkmark when the selection is nil. Tapping it selects nil and pops.
2. When a category filter is active: a row `Label(filterSummary, systemImage: "line.3.horizontal.decrease.circle.fill")` in caption secondary. The summary is `"<Body area> · <Equipment type>"`. A trailing **"Clear"** button in caption semibold, id `clearModelFilters`.
3. Sections from `CatalogBrowsing.browse(index, filter, grouping)`, with a header when the title is non-nil.
   - Groupings: "Manufacturer" (default), "Body area", "Equipment type", "A–Z".
   - Rows with no category go under **"Uncategorized"**.
   - **Row** (`modelButton`, `:903-935`):
     - `row.displayName` ("Manufacturer Model")
     - A caption subline in secondary: **"Custom"** when the model is not seeded, then the equipment type label, then the body areas joined by " · ". These are separate Texts with a spacing of 6 and no separator between groups.
     - A trailing checkmark when selected.
     - Id `modelOption.<displayName>`.
     - Tapping selects and pops.
4. Final section:
   - When there are no results: **"No models match"** in secondary, id `noModelsMatch`.
   - Button **"New Model…"** (`plus`) in `.secondary`, which opens `AddModelSheet` (blank). Creating a model selects it and pops.
   - Footer: **"Can't find the machine's model? Add it — your models live alongside the catalog."**

**Toolbar:** a trailing Menu labelled **"Browse"**. Its icon is `line.3.horizontal.decrease.circle`, or `.fill` when filters are active. Id `modelBrowseMenu`. It contains:
- **"Group By"** → Manufacturer / Body area / Equipment type / A–Z, id `modelGrouping.<raw>`.
- **"Body Area"** → **"All body areas"** (id `modelFilter.bodyArea.all`) plus the areas present (id `modelFilter.bodyArea.<area>`).
- **"Equipment Type"** → **"All types"** (id `modelFilter.type.all`) plus the types (id `modelFilter.type.<raw>`). The labels are "Selectorized", "Plate-loaded", "Cable & functional", "Rack, Smith & bench" and "Bodyweight station".
- **"Clear Filters"** (`xmark.circle`), only when filters are active.
- Grouping and filters persist in AppPreferences.

**States**
- Default grouped by manufacturer (about 23 sections).
- Filtered, with the summary row.
- Searching.
- No results.
- Selection checkmarks on None or on a row.

**Accessibility ids:** as listed above, plus `noModelsMatch`.

**[J] Observations**
- It is a very long stock list with no manufacturer logos, no imagery and no section index or scrubber.
- The filters are buried three menus deep. There are no visible filter chips.
- The row subline mixes the "Custom" tag, the type and the areas with inconsistent separators.
- The row does not show the exercises the model serves.
- The page offers no scan entry, although a scan is the faster route.

---

## 7. New Model — `AddModelSheet`
- **File:** `GymsView.swift:1031-1257`.
- **Presentation:** a sheet wrapping `NavigationStack` → `Form`.
- **Reached from:**
  - `ModelPickerView` "New Model…" (blank)
  - `MachineEditorSheet` after the on-device scanner's "Add this as a new model", "None of these — create new" or "Enter it by hand". These prefill the manufacturer and model name from the plate and carry `plateLines`, except "Enter it by hand", which passes empty values.
- **Title:** **"New Model"**, inline.
- **Toolbar:** **"Cancel"** (it also cancels any AI request in flight) and **"Add"**, disabled unless the manufacturer and model are non-blank **and** at least one exercise is linked. Id `saveNewModel`.

**Layout**
1. Section:
   - TextField **"Manufacturer"**
   - TextField **"Model"**
   - Picker **"Equipment type"** with **"Not set"** plus the five type labels. Id `newModelEquipmentType`.
2. **AI suggest section**, only when `plateLines` is non-empty **and** `AskAI.isAvailable` (a key is stored). In practice it appears only after an on-device scan that led to create-new.
   - Idle: Button **"Suggest exercises with AI"**, id `newModelSuggestExercises`.
   - In progress: `ProgressView` with **"Asking AI…"**, id `newModelSuggestStatus`.
   - Default footer: **"Sends the manufacturer and model above, the plate's text and this exercise list (names and muscle groups) to OpenAI (GPT-5.6 Terra), with your key; it picks from the list and you keep the final say."**
   - After a result, the footer shows the note instead (id `newModelSuggestNote`): **"AI could not tell which exercises this machine serves."** or the error's description (§12).
   - On success, the proposed exercises are ticked, with a reason under each.
3. **Exercises section**
   - Header: **"Exercises"**.
   - Every exercise in the app, as tap-to-toggle rows showing the name and, when an AI reason exists and the row is ticked, the reason in caption secondary (id `newModelExerciseReason.<name>`). A checkmark shows in the tint colour. Id `newModelExercise.<name>`.
   - Footer: **"Link at least one exercise this model serves — multi-exercise stations can link several."**

**Consent alert:** **"Send model details to OpenAI?"**
- Buttons: **"Allow and send"** (sets consent and sends) and **"Cancel"**.
- Message: **"Sends the typed manufacturer/model, plate text and exercise names to OpenAI. You can revoke this in Settings. OpenAI API data policies apply."**
- It is shown on the first tap when `openai.exerciseConsent.v1` is false.
- If consent is revoked while a request is in flight, the request is abandoned.

**Commit:** Add inserts the `EquipmentModel` (not seeded, exercise ids in catalog order), calls `onCreate` and dismisses. A save error is swallowed by `assertionFailure`. Cancel, swipe-dismiss and Add all cancel the paid request.

**States:** blank, prefilled, AI-available, asking, AI success with reasons, AI empty, AI error, needs consent, Add disabled.

**[J] Observations**
- The exercise list is the whole catalog with **no search**, and the ticked rows are scattered through it.
- There is no preview of the resulting model.
- Equipment type is a picker, not visual choices.

---

## 8. Correct Model — `MachineModelCorrectionSheet`
- **File:** `Features/Gyms/MachineModelCorrectionSheet.swift:7-59`.
- **Presentation:** a sheet reached from the gym detail machine context menu **"Correct Model…"**.
- **Title:** **"Correct Model"**, inline. The toolbar has only **"Cancel"**.

**Layout**
1. Section:
   - NavigationLink row **"Correct model"** with the trailing value `model?.displayName ?? "None"`, which pushes `ModelPickerView`.
   - Footer: **"Choose whether existing workout snapshots for this exact machine should also move to the corrected model."**
2. Section with two plain buttons, each of which **commits and dismisses**:
   - **"Future Workouts Only"** → `.futureOnly`
   - **"Apply to Past Workouts Too"** → `.applyToPast`, which rewrites the snapshot model id and name on this machine's past entries.

**Details:** the sheet is preloaded with the current model on appear. There are no accessibility ids. Errors go to `assertionFailure` only.

**[J] Observations**
- The scope buttons are enabled even when the model is unchanged.
- It does not say how many past workouts or sets would move. That is the key fact for the decision.
- "Correct model" is used both as the row label and the title.
- There is no before → after visual.

---

## 9. AI scanner — `IdentifyEquipmentSheet` ("Scan equipment…")
- **File:** `Features/Gyms/IdentifyEquipmentSheet.swift:6-216`.
- **Presentation:** a sheet containing a `NavigationStack`, opened from `MachineEditorSheet`.
- **Title:** **"Scan Equipment"**, or **"AI Proposal"** once a proposal exists (`:55`), inline.
- **Toolbar:**
  - **"Cancel"** cancels any work and dismisses.
  - A keyboard toolbar with **"Done"**, id `dismissEquipmentKeyboard`.
- **Job:** take one photo of a machine or its label, send it to OpenAI "GPT-5.6 Terra", and let the user edit and confirm an identity plus its exercises. **Nothing is saved here** (doc comment `:5`).

**State machine.** The states are checked in this order in `body` (`:27-53`).

### 9a. Consent (photo consent not given)
Shown when `@AppStorage("openai.photoConsent.v1")` is false. It is a Form with one Section:
- **"Send equipment photos to OpenAI?"** in the headline font.
- **"Each scan sends the full photo, including any people or screens in frame, and the exercise catalog to OpenAI for identification. The app does not save the photo. OpenAI’s API data policies apply."**
- Link **"OpenAI data policies"** → `https://developers.openai.com/api/docs/guides/your-data`.
- Button **"Allow photos and continue"**, id `allowAIPhotos`. It sets consent and calls `start()`.

### 9b. No API key
Shown when `TerraAccess.client == nil`. It is a Form with:
- **"Add your OpenAI API key to identify equipment with Terra."**
- Button **"Open AI Settings"**, id `scannerAISettings`. It opens `AskAISettingsSheet` (§13). On dismiss, `start()` runs again.
- **"You can also cancel and choose a catalog model manually."** in secondary.

### 9c. Busy / AI in progress
- Centred `ProgressView("Identifying equipment…")`.
- Button **"Take another photo"**, id `scanRescan`. It cancels and resets.
- The Terra request timeout is 60 s (`Domain/TerraAPI.swift`). There is no progress detail, no photo thumbnail and no cancel beyond this button and the toolbar Cancel.

### 9d. Capture (default after consent + key)
A `VStack(spacing: 12)` with bottom padding:
1. When an error exists: `Text(error)` in `Theme.secondary`, padded, id `scanAIError`. It is **not styled as an error** (no red, no icon).
2. When `started`, the camera is usable and this is not a fixture: `LabelCameraView` fills the available space (not full-bleed; it keeps the safe area). **No framing box is drawn** here, unlike §10. Otherwise a large `camera.viewfinder` symbol fills the space as a placeholder, for example when the camera is denied or unavailable.
3. **"Scan a machine or its label"** in the callout font.
4. HStack with `.bordered`:
   - **"Take photo"** (`camera`), id `scanShutter`. It is disabled while a capture is pending, or when the camera is unavailable (outside fixtures).
   - **"Flash"** (`bolt`). It toggles the torch. **There is no on/off visual state**, because the symbol never changes. It is disabled in fixtures.
5. **"Choose a photo instead"** (default style), id `scanChoosePhoto`. It opens the system photo library (`ImagePicker`). Picking a photo sends it straight to identification. Cancelling returns to capture.

**Timeout:** 10 s after the shutter tap, the message becomes **"The camera did not return a photo. Try again."**

**Permission-denied / no camera:** the error shows the reason from `CaptureAvailability` (§14). The shutter is disabled and the placeholder symbol shows. There is **no "Open Settings" link** in this sheet, unlike §10.

### 9e. Result / AI Proposal (`result`, `:110-162`)
A Form with `.scrollDismissesKeyboard(.interactively)`:
- When `identity == "uncertain"`, a top row: **"AI could not identify this equipment. Try a clearer angle or choose its exercises below."**
- Section, header **"Equipment"**:
  - Caption **"Name"** above TextField **"Machine name"** (multi-line axis), id `identifiedMachineLabel`. Editing it sets `labelWasEdited`.
  - When `identity == "specific"`:
    - Caption **"Manufacturer"** + TextField "Manufacturer"
    - Caption **"Model"** + TextField "Model"
    - `visibleText` (the text the AI read) in caption secondary, **unlabelled**
    - A plain Button **"Use generic identity"**, which clears the brand and model and sets identity to generic
  - Footer, by resolution (`EquipmentIdentityResolution`):
    - catalog → **"Matches catalog: \(model.displayName)"**
    - newModel → **"Will add new model: \(manufacturer) \(name)"**
    - ambiguous → **"Multiple catalog identities match. This will be saved without a model; you can choose one later."**
    - generic → **"Saved as this gym’s machine, with no model claimed."**
- Section **"Exercises"**:
  - Plain text rows for the effective exercises. These are the catalog model's exercises when it has some, otherwise the AI-proposed ones.
  - When there is no catalog match with exercises: NavigationLink **"Change exercises"**, which pushes `AIExerciseSelection`.
- Section:
  - **"Use this equipment"** in `.primary`, id `scanUseCandidate`. It is disabled when the name is blank or there are no exercises. It trims the name, forces ambiguous/generic to generic, calls `onIdentify` and dismisses. **Nothing is persisted.** The user still has to tap Add in the machine editor.
  - **"Take another photo"**, id `scanRescan`.

**Identity values:** "specific", "generic" or "uncertain". The response is validated: at most 6 exercises, and those must be seeded ids. A "specific" answer without a brand, model or visible text is demoted to generic. A movement-only model name (for example "Chest Press") resolves to generic.

**Lifecycle**
- `onAppear` starts when consent is given.
- `onDisappear` cancels.
- Revoking consent in Settings cancels and clears the proposal.
- The photo is re-encoded to JPEG, at most 1568 px on the long side, quality 0.85, with EXIF/GPS stripped (`EquipmentPhoto`, `:235-245`).

**Errors shown in capture:** see §12 (TerraError).

**Accessibility ids:** `allowAIPhotos`, `scannerAISettings`, `scanRescan` (in both busy and result), `dismissEquipmentKeyboard`, `scanAIError`, `scanShutter`, `scanChoosePhoto`, `identifiedMachineLabel`, `scanUseCandidate`.

**Motion / haptics:** none. There is no shutter flash, no capture animation, no haptic on success, and instant swaps between states.

**[J] Observations**
- This is the app's showpiece, and it is the plainest screen:
  - bordered system buttons under a letterboxed camera, with no framing guide
  - a spinner-only wait of up to 60 s
  - the result as a settings Form
  - the primary button left-aligned inside a Form row (visible in `work-record/ai-gym/screenshots/ai-scan-proposal-default.png`)
  - the captured photo never shown back, so the user cannot compare it with the proposal
  - no confidence cue
  - "AI Proposal" as a title
  - the resolution outcome (match / new model / generic), the most important fact, buried in a footer
- The torch has no state. Errors look like body text.
- There are two confirmations in a row: "Use this equipment", then "Add".
- The AI exercise picker silently ignores a 7th selection.

---

## 10. On-device label scanner — `ScanMachineLabelSheet` ("Read label on device")
- **File:** `Features/Gyms/ScanMachineLabelSheet.swift:24-653`.
- **Presentation:** a sheet containing a `NavigationStack`, opened from `MachineEditorSheet`.
- **Title:** **"Scan Label"**, inline.
- **Toolbar:**
  - **"Cancel"** dismisses.
  - A trailing torch toggle, shown **only in the scanning phase and when the device has a torch**. The icon is `bolt.fill` when on and `bolt.slash` when off. Id `scanTorch`.
- **Job:** read the name plate offline with Vision OCR, rank catalog models and let the user confirm one or create a new model (D33/D34/D35).
- **Callbacks:** `onUseModel(EquipmentModel)` and `onCreateNew(manufacturer, modelName, plateLines)`.

**Phases** (`Phase`, `:58-64`)

### 10a. `idle`
- A List row `Label("Starting the camera…", systemImage: "camera")` in secondary, id `scanStatus`.
- On start: camera → scanning; no camera → the photo library opens immediately; denied/restricted → failed(reason).

### 10b. `scanning` (viewfinder)
- The full-bleed camera (`ignoresSafeArea(edges: .bottom)`), or under test a black rectangle with "Fixture plate" (id `scanFixtureViewfinder`).
- **Framing box overlay** (`LabelFramingBox`):
  - a white stroke at 0.9 opacity, 2 pt, radius 10
  - width 94% of the view (capped at 0.9 × height × 2), aspect 2:1
  - centred at 42% of the height
  - id `scanFramingBox`
  - It is the exact OCR region. Nothing outside it is read.
- Bottom stack, spacing 14, bottom padding 24:
  - A pill with **"Fit the name plate in the box"**, or **"Reading…"** while capturing. White callout text on black at 55% opacity with radius 12. Id `scanStatus`.
  - The **shutter**: a 74 pt white ring (4 pt stroke) around a 60 pt white disc. It shows a black `ProgressView` while capturing. Accessibility label **"Take photo"**, id `scanShutter`. It is disabled while capturing.
  - **"Choose a photo instead"** in `.bordered` with a white tint, id `scanChoosePhoto`. It is disabled while capturing and opens the photo library.
- **Capture:** one still, with a one-shot focus and exposure on the box centre (up to 1.0 s budget; `LabelCameraView.swift:165-221`). The timeout is 8 s → **"The camera did not respond. Try again, or choose a photo."** There is no flash, no sound (beyond the system's) and no haptic.

### 10c. `reading`
- A List row with `ProgressView` and **"Reading the label…"**, id `scanStatus`.

### 10d. `results` (`resultsContent`, `:282-406`). It is a List.
1. When `captureNotice` is set (camera unavailable → library used): `Label(notice, systemImage: "info.circle")` in footnote secondary.
2. Section:
   - Header: **"What the camera read"**, or **"What AI read"** when the source is `.ai`.
   - Body: `results.reading.text` (lines joined by newlines) in monospaced footnote secondary, id `scanReadingText`.
   - Footer, in fixtures only: **"AI calls: N"** (id `scanAskAICalls`).
3. **Ask AI section.** It is shown only when the source is the camera, nothing was preselected, a crop exists and `AskAI.transcriber != nil`. **In production `AskAI.transcriber` returns nil (`AskAI.swift:115-118`), so this section is never shown outside the `-uiTestAskAI` fixture.** It is legacy UI.
   - Button **"Ask AI about this plate"** (id `scanAskAI`), or a progress row with **"Asking AI…"** (id `scanAskAIStatus`).
   - Footer: the note (id `scanAskAINote`), for example **"AI could not find a name plate in the box."** or an error. Otherwise **"Sends the plate inside the box (plus a small margin around it) to Claude, with your key, and ranks what it reads here."**
4. **Lead-with-create-new.** This applies when there are no matches, the best score is below 0.35, there is a brand conflict, or less than 80% of the text is explained.
   - Section with the Button **"Add this as a new model"**, id `scanCreateNew`.
   - Footer: **"Nothing in the catalog looks like this label."** when there are zero matches, otherwise **"Nothing in the catalog is a close match for this label."**
5. **Candidates** (up to 5, ranked):
   - Each row shows `match.modelName` with `match.manufacturer` below it in caption secondary. A trailing score such as **"87%"** is shown in caption monospaced digits, tertiary. A checkmark shows when selected. Id `scanCandidate.<modelName>`. Tapping a row selects it (it does not commit).
   - Header: **"Weak alternatives"** when leading with create-new, otherwise **"Catalog models"**.
   - Footer, nothing selected: **"Nothing is picked for you here — the reading was not clear enough to choose between these. Tap the machine you are standing at."**
   - Footer, something selected: **"Check the machine in front of you before accepting — records are kept per model, so the wrong one splits your history."**
6. Actions section:
   - **"Use This"**, disabled until a selection exists, id `scanUseCandidate`. It commits: `onUseModel` and dismiss.
   - **"None of these — create new"**, when not leading with create-new, id `scanCreateNew`.
   - Rescan: **"Scan again"** when the camera is allowed, otherwise **"Choose another photo"**.
   - With no matches, only the rescan section is shown.

### 10e. `failed(message)` (`failureContent`, `:425-450`)
- `Label(message, systemImage: "exclamationmark.triangle")`, id `scanStatus`.
- Section:
  - **"Open Settings"**, a Link to the app settings, shown only when the camera was denied.
  - **"Choose from photos"**.
  - **"Try the camera again"**, only when the camera is allowed.
  - **"Enter it by hand"**, id `scanCreateNew`. It calls `onCreateNew("", "", [])` and opens a blank New Model sheet.
- Messages that can appear here:
  - CaptureAvailability reasons (§14)
  - "The camera did not respond. Try again, or choose a photo."
  - "Could not read the equipment catalog."
  - "That photo could not be opened."
  - "Could not read the photo: …"
  - "No text found in that photo."
  - "This device has no usable camera."
  - "Could not open the camera: …"
  - "The camera is not ready yet."
  - "The camera is not running."
  - "Could not take the photo: …"
  - "The photo could not be read."
  - "That model is no longer in the catalog."
  - "Could not open that model: …"
  - "The camera is unavailable." (fallback)

**Picker cancel:** cancelling the library picker from the idle phase re-resolves the reason and shows failed, or dismisses when there is no reason.

**Accessibility ids:** `scanTorch`, `scanStatus` (reused in 4 phases), `scanFramingBox`, `scanFixtureViewfinder`, `scanShutter`, `scanChoosePhoto`, `scanReadingText`, `scanAskAICalls`, `scanAskAIStatus`, `scanAskAI`, `scanAskAINote`, `scanCreateNew` (3 places), `scanCandidate.<name>`, `scanUseCandidate`.

**[J] Observations**
- This scanner's viewfinder, with its box, pill and custom shutter, is visually far richer than the AI scanner's (§9). The two scanners share ids but look like two different apps.
- The results are a stock list with raw percentages. There is no photo or crop thumbnail beside the reading, and the reading is a monospaced dump.
- The dead Ask AI branch still carries Claude/Anthropic copy, while production AI is OpenAI.
- Three buttons in the failure state are stacked plain rows.

---

## 11. Exercise chooser — `AIExerciseSelection`
- **File:** `IdentifyEquipmentSheet.swift:218-232`.
- **Presentation:** pushed from the `MachineEditorSheet` "Choose exercises" link and the AI proposal "Change exercises" link.
- **Title:** **"Exercises"**. It has `.searchable` with the default prompt.

**Layout:** a List of every `Exercise`, filtered by a case-insensitive name match. Each row is a Button with the name (`Theme.text`) and a checkmark when selected.

**Behaviour**
- Toggling a row writes through the binding live. Going back is the commit; there is no Done.
- There is a **hard maximum of 6** selections. A 7th tap does nothing, with no message.
- There are no accessibility ids and no sections, muscle groups or selected-first ordering.

**[J] Observations:** it is a bare list. The limit is silent. The list does not show which exercises the AI proposed.

---

## 12. Error copy surfaced in this scope (verbatim)
- **TerraError** (`Domain/TerraAPI.swift`):
  - "Check your OpenAI key and model access in Settings." (401/403)
  - "OpenAI usage is limited. Check API credits or try again later." (429)
  - "OpenAI is unavailable (<status>). Try again later."
  - "OpenAI took too long. Try again."
  - "Could not reach OpenAI. Check your connection or continue manually."
  - "AI could not help with this request. Change the request or continue manually."
  - "AI returned an incomplete or invalid result. Try again or continue manually."
- **PlateTranscriptionError** (`Domain/PlateTranscription.swift:71-80`; legacy or fixture Ask AI and the exercise proposer stub):
  - "Ask AI needs a connection — you look offline."
  - "Ask AI took too long. Try again when the signal is better."
  - "Ask AI's key was rejected. Check it in Settings."
  - "AI declined to read this photo."
  - "Ask AI is unavailable right now (<status>)."
  - "AI's answer could not be read."
- **Keychain:** "Could not save the key to the keychain (<status>)."

---

## 13. Ask AI settings — `AskAISettingsSheet` (the key store and Terra access UI)
- **File:** `Features/Settings/AskAISettingsSheet.swift:8-78`.
- **Presentation:** a sheet containing a `NavigationStack`.
- **Reached from:**
  - IdentifyEquipmentSheet "Open AI Settings"
  - the Settings row **"Ask AI about plates"** ("On"/"Off", id `askAISettings`)
  - the AI routine sheet
- **Title:** **"Ask AI"**, inline. The toolbar has **"Done"** (confirmation) only.

**Layout**
1. Section:
   - `LabeledContent("Ask AI")` with the value **"On"** or **"Off"** (whether a key is stored), id `askAIStatus`.
   - Footer: **"GPT-5.6 Terra identifies equipment and drafts weekly routines and suggests exercises from model details. Photos and routine details are sent to OpenAI only with your permission. API usage is billed to your key. OpenAI may retain data under its API policies."**
2. Section **"Permissions"**:
   - Toggle **"Send equipment photos to OpenAI"** (`openai.photoConsent.v1`)
   - Toggle **"Send routine details to OpenAI"** (`openai.routineConsent.v1`)
   - Toggle **"Send model details to OpenAI"** (`openai.exerciseConsent.v1`)
   - Link **"OpenAI API data policies"**
3. Section, header **"Key"**:
   - SecureField with the placeholder **"Replace the saved key"** when a key exists, otherwise **"OpenAI API key"**. No autocapitalisation or autocorrect. Id `askAIKeyField`.
   - **"Save key"**, disabled when the field is blank, id `askAISaveKey`.
   - **"Remove key"** (destructive), only when a key exists, id `askAIRemoveKey`.
   - Footer: the failure text, or **"Kept in this phone’s keychain only. Private trial: use your own OpenAI API key."**

**Backing storage**
- `AskAIKeyStore` (`Gyms/AskAIKeyStore.swift`) keeps the key in the Keychain generic password `<bundle>.askai` / `openai-api-key`, accessible after first unlock on this device only. An empty write deletes it. UI tests use an in-memory slot.
- `TerraAccess` (`Gyms/TerraAccess.swift`) holds the three consent keys and the fixtures. `client` is non-nil when a key exists.

**States:** key saved or not; each consent on or off; save failure. The key is never displayed back.

**[J] Observations**
- The Settings entry is still named "Ask AI about plates", which is stale because it now covers routines and exercises.
- The status reflects only whether a key exists, not whether it is valid. There is no "Test key" button.

---

## 14. Camera / photo infrastructure (not screens, but they shape states)
- **`CaptureAvailability`** (`ImagePicker.swift:11-53`) resolves to one of:
  - `camera` (including notDetermined, which raises the system prompt)
  - `noCamera`: **"This device has no camera — pick a photo of the name plate instead."**
  - `cameraDenied`: **"Camera access is off for Workout Tracker. Turn it on in Settings, or pick a photo you already took."** (Settings can help)
  - `cameraRestricted`: **"Camera access is restricted on this device. Pick a photo of the name plate instead."**
- **`ImagePicker`** (`ImagePicker.swift:61-129`) wraps UIKit `UIImagePickerController` for the camera or photo library, with editing off. It is **system UI and not restylable**. It calls back exactly once; nil means the user cancelled.
- **`LabelCameraView` / `LabelCameraController`** (`LabelCameraView.swift`):
  - `AVCaptureSession` with the `.photo` preset and an aspect-fill preview on black
  - continuous autofocus restricted to near range
  - portrait rotation of 90°
  - the torch controlled by the `torchOn` flag
  - the session stops when the view disappears
  - no focus reticle, no shutter animation
- **`LabelFramingBox`** (`LabelFramingBox.swift`) is the pure geometry that the §10 overlay and the OCR region share. Any redesign of the box must keep the drawn box identical to the region that is read.
- **`LabelCrop.jpeg`** (`LabelCropRendering.swift`) produces the crop for the legacy Ask AI path.
- **`MachineLabelOCR`** runs Vision in accurate mode, en-US, with language correction off. It sorts lines top to bottom.
- **`MachineLabelDictionary`** is a spell-check helper for reading repair. It has no UI.

---

## 15. Accessibility ids pinned by UI tests
Counts are the number of files in `WorkoutTrackerUITests/` containing the literal. Keep these ids, or update the tests.
- `gymRow` 7, `addGym` 7, `gymName` 7, `saveGym` 7
- `addMachine` 7, `machineLabel` 7, `saveMachine` 7
- `catalogModel` 6, `modelOption` 5
- `gymUnitPicker` 2, `machineRow` 2, `scanLabelOffline` 2, `saveNewModel` 2, `scanShutter` 2, `scanUseCandidate` 2, `scanCreateNew` 2
- These appear in 1 file each:
  - `editGym`, `deletedMachines`, `deleteMachine`, `restoreMachine`
  - `scanMachineLabel`, `machinePresetPicker`, `machineUnitPicker`
  - `clearModelFilters`, `modelBrowseMenu`, `modelFilter`
  - `newModelSuggest*`, `newModelExercise`
  - `allowAIPhotos`, `scanRescan`, `dismissEquipmentKeyboard`, `scanAIError`, `identifiedMachineLabel`
  - `scanFramingBox`, `scanReadingText`, `scanCandidate`
- The redesign screenshot harness is `WorkoutTrackerUITests/RedesignScreenshotUITests.swift`. The relevant tests are `test06_gymsAndExercises`, `test06_gymsLargeText` and `test08_emptyStates`.

---

## 16. Cross-cutting UX judgments [J]
1. **No machine detail.** A machine is the core noun of this app ("gym/machine-aware logger"), yet it has no page of its own: nothing shows its exercises, history, PRs, usual preset or last used date. Editing hides behind a long-press.
2. **Gym detail is a settings form with a list under it**, not a place. There is no summary: workouts here, last visit, machine count, body-area coverage.
3. **Two scanners with different design languages** and unclear naming ("Scan equipment…" vs. "Read label on device"). The AI one, the primary path, is the least designed.
4. **Stock `Form`/`List` everywhere after the top level.** The editor sheets, model picker, results, correction and settings all have default iOS styling. Only the two top-level lists use cards.
5. **Terminology drift:** "App preference" / "app default" / "Gym default"; "Delete" (UI) vs. archive (data); "Ask AI" (Settings title) vs. "Terra" / "OpenAI" (copy) vs. "Claude" (legacy footer).
6. **Irreversible or silent actions:**
   - Archive Gym has no confirmation and no restore.
   - Rename Model with an empty field fails silently.
   - The correction scope is applied with one tap and no impact count.
   - The 6-exercise limit is silent.
   - Save errors in `AddModelSheet`, correction, restore and archive only `assertionFailure`.
7. **No feedback moments:** no haptics or motion on adding a gym or machine, capturing a photo, an AI result arriving, restoring, or deleting.
8. **Iconography is uniform:** the same pin for every gym and the same dumbbell for every machine. Nothing uses the equipment type (selectorized, plate-loaded, cable…), which is data the catalog already has.
9. **Dynamic Type:** there is only one explicit adaptation. The camera overlay controls and pill are fixed-size.

---

## 17. Flat checklist — every screen and state in scope

**Gyms list (tab root)**
- [ ] Gyms list — populated (cards; "Add Gym…" secondary)
- [ ] Gyms list — empty (primary "Add Gym…" only; no illustration)
- [ ] Gym row card (name, optional city, machine count chip, unit badge / "app default", chevron)

**Gym detail**
- [ ] Gym detail — info section (Default unit / City / "Edit Gym…")
- [ ] Gym detail — machines A–Z ("MACHINES" header)
- [ ] Gym detail — grouped by Exercise (with "Uncategorized")
- [ ] Gym detail — grouped by Body area (with "Uncategorized")
- [ ] Gym detail — no machines (EmptyState "No machines yet" + primary "Add Machine…")
- [ ] Gym detail — with deleted machines link "Deleted machines (N)"
- [ ] Gym detail — footer copy
- [ ] Machine row card — with model chip / "No model" / unit override badge
- [ ] Machine row card — accessibility text size (model as caption)
- [ ] Gym ⋯ menu (Group Machines By ▸ Exercise / Body area / A–Z; Edit Gym…; Archive Gym)
- [ ] Archive Gym (immediate, pops to the list)
- [ ] Machine swipe action "Delete"
- [ ] Machine context menu (Edit Machine…, Correct Model…, Rename Model… (custom only), Delete Machine…)
- [ ] Delete machine alert ("Delete <label>?")
- [ ] Rename Model alert

**Deleted machines**
- [ ] Deleted Machines — list with "Restore"
- [ ] Deleted Machines — empty ("Nothing deleted")

**Gym editor**
- [ ] New Gym sheet (Add disabled / enabled; new-gym footer)
- [ ] Edit Gym sheet (Save; edit footer)
- [ ] Gym editor — save failure text
- [ ] Gym editor — reused from the AI routine sheet

**Machine editor**
- [ ] New Machine sheet — no model (Exercises section with "Choose exercises")
- [ ] New Machine sheet — catalog model chosen (label auto-derived)
- [ ] New Machine sheet — after an AI scan (recognized exercises; "Manufacturer Model" line when specific)
- [ ] New Machine sheet — Preset section ("Usually")
- [ ] New Machine sheet — save failure
- [ ] New Machine sheet — opened with the scanner auto-launched (AI routine)
- [ ] Edit Machine sheet (read-only model + "Correct Model…" footer; Save)

**Catalog model picker**
- [ ] Catalog Model picker — default grouped by manufacturer
- [ ] Catalog Model picker — other groupings (Body area / Equipment type / A–Z)
- [ ] Catalog Model picker — filter summary row + "Clear"
- [ ] Catalog Model picker — searching
- [ ] Catalog Model picker — "No models match"
- [ ] Catalog Model picker — Browse menu (Group By / Body Area / Equipment Type / Clear Filters)
- [ ] Catalog Model picker — "None" row selected

**New model**
- [ ] New Model sheet — blank (from the picker)
- [ ] New Model sheet — prefilled from a scan, with the AI suggest button
- [ ] New Model sheet — asking AI
- [ ] New Model sheet — AI ticks with reasons
- [ ] New Model sheet — AI empty or error note
- [ ] New Model sheet — consent alert "Send model details to OpenAI?"
- [ ] New Model sheet — Add disabled (no exercise linked)

**Correct model**
- [ ] Correct Model sheet (model row; "Future Workouts Only" / "Apply to Past Workouts Too")

**AI scanner**
- [ ] AI scanner — photo consent
- [ ] AI scanner — no API key ("Open AI Settings")
- [ ] AI scanner — capture: live camera
- [ ] AI scanner — capture: camera unavailable / denied / restricted placeholder + reason text
- [ ] AI scanner — capture: error text (timeout / Terra error)
- [ ] AI scanner — torch toggled (no visual state today)
- [ ] AI scanner — photo library picker (system UI)
- [ ] AI scanner — busy "Identifying equipment…"
- [ ] AI Proposal — specific, matches catalog
- [ ] AI Proposal — specific, will add new model
- [ ] AI Proposal — ambiguous
- [ ] AI Proposal — generic
- [ ] AI Proposal — uncertain (top notice; empty name; no exercises → Use disabled)
- [ ] AI Proposal — keyboard up with the "Done" toolbar
- [ ] AI Proposal — after "Use generic identity"

**Exercise chooser**
- [ ] Exercises chooser (AIExerciseSelection) — search, toggles, silent max of 6

**On-device scanner**
- [ ] On-device scanner — idle "Starting the camera…"
- [ ] On-device scanner — viewfinder with framing box, pill, shutter, "Choose a photo instead", torch
- [ ] On-device scanner — capturing ("Reading…" pill, shutter spinner)
- [ ] On-device scanner — reading "Reading the label…"
- [ ] On-device results — capture notice row
- [ ] On-device results — "What the camera read" / "What AI read"
- [ ] On-device results — preselected candidate (Catalog models; selected footer)
- [ ] On-device results — no preselection (unselected footer)
- [ ] On-device results — lead with create-new ("Add this as a new model" + "Weak alternatives")
- [ ] On-device results — zero matches (create-new + rescan only)
- [ ] On-device results — Ask AI button / asking / note (fixture-only in production)
- [ ] On-device results — rescan variants ("Scan again" / "Choose another photo")
- [ ] On-device failed — camera denied (with "Open Settings")
- [ ] On-device failed — restricted / no camera / timeout / OCR / catalog errors ("Choose from photos", "Try the camera again", "Enter it by hand")

**Ask AI settings**
- [ ] Ask AI settings — no key / key saved (Remove key) / save failure / permission toggles
- [ ] Settings entry row "Ask AI about plates" (On/Off) — lives in Settings, opens this sheet
