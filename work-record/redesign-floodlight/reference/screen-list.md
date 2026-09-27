# Full-app screen list (every screen and state that gets an artboard)

Artboard file = `project/<Name>.dc.html`. Width 430. Height 932 for a first-viewport screen,
taller when the point is the scroll (say so). Sheets are drawn as the iOS 26 sheet over a dimmed
parent (draw the parent as a simple dimmed silhouette, not a full copy) or full height when the
sheet is large-detent. "(I)" = interactive artboard. Inventory sources in `../brief/`.

## Row 1 — Workout tab (inventory-start-templates.md)
- W01-Home — idle, Iron Temple, 4 templates, this week (from the winning direction, refined)
- W02-Home-Live — a workout is running: the Start pair becomes the single "Resume workout" capsule
  (user's choice) with elapsed time + live pulse; other content dims/steps down
- W03-Home-FirstRun — no gym, no templates, no history: empty is an invitation (one action each)
- W04-GymMenu — the gym picker open over Home (gyms, No gym, Add Gym…, unit)
- W05-FinishAndStartNew — the "Finish It & Start New" confirmation when starting while one runs

## Row 2 — Templates (inventory-start-templates.md)
- T01-TemplateDetail — Push Day: families, stats (times run / last run / avg duration), Start,
  exercise rows "N sets · r, r, r reps" + rest, superset A/B grouping, Edit, Delete Template…
- T02-TemplateEditor — sheet: name, exercises (reorder handles, targets per set as compact
  steppers or number pills, not walls of −|+), rest default, planned cardio block, Cancel/Save
- T03-TemplateDrift — after finishing a changed template workout: Update Template / Update
  Values Only / Update Both / Keep Original / Don't ask again — each with a one-line consequence
  and a visual diff (e.g. "+1 set", "110 lb × 8") so the choice is obvious
- T04-SaveAsTemplate — name entry (from Finish or History), confirmation state

## Row 3 — Ask AI for Templates (full-screen flow; inventory-start-templates.md, ai-gym/spec)
- A01-AI-Goals — step 1: goals, experience, days/week, minutes/session, profile (height/weight
  optional) — stepped wizard with progress, NOT a 25-row form
- A02-AI-Equipment — step 2: gym select/add, "N saved machines" with Scan Machine, equipment
  checklist, cardio availability, the consent switch + AI settings link; Generate week primary
- A03-AI-Generating — progress state (animated, Reduce Motion alt) + error variant note
- A04-AI-WeekPreview — sessions as distinct cards (families maps, exercise count, minutes,
  cardio block), editable, "Save templates" primary (atomic save)
- A05-AI-DayEditor — one generated day: exercises (add/remove/reorder), sets×reps, rest,
  cardio block

## Row 4 — Live lifting (inventory-active-cardio.md)
- L01-Live — (I) the winning direction's live screen, refined
- L02-Live-SetStates — the set table vocabulary on one screen: warmup (W), working, failure (F),
  drop (D), a superset pair A/B, bar mode (bar + per side = total), prefilled vs typed vs done,
  swipe-to-delete revealed on one row, the set-type menu open on one marker
- L03-Live-NewBest — the moment a set beats the previous best (celebration, haptic note),
  plus the exercise card's "last time" comparison
- L04-Live-HRRest — heart-rate rest mode: rest ends below 110 bpm with 4:00 cap; show current
  bpm vs target, and the degraded "no heart rate reading — resting by the timer" variant
- L05-Live-Minimised+Menu — the entry menu (… : Rest settings, Previous performance, Change load
  type, Superset with next, Remove exercise) and the workout rename state
- L06-ExercisePicker — sheet: search, recent at this gym, grouped by body area, New Exercise…
- L07-AddByMachine — sheet: machines at Iron Temple (movement + model), Scan Machine, empty
  variant "No machines yet"
- L08-EquipmentSheet — entry equipment: machine vs free weight tags, preset chips, dumbbell
  counterpart offer, frozen consequence line
- L09-BarPicker — bar presets + per side → total (plain), plate math shown plainly
- L10-PreviousPerformance — three layers (This machine / Same model elsewhere / Any equipment),
  rep-count bests 1–12, 1RM, empty-layer messages
- L11-RestSettings — Timer vs Heart rate, working/warmup durations, HR threshold + cap
- L12-MaxHeartRate — zones setup: measured max vs age-based, zone table with bpm ranges
- L13-DiscardConfirm — Cancel workout (discard) confirmation + finishing with unticked rows notice

## Row 5 — Cardio (inventory-active-cardio.md, audit-cardio-ai-screens.md)
- C01-CardioPicker — 9 activities (Indoor Walk/Run/Cycle, Elliptical, Rowing, Stair Stepper,
  Outdoor Walk/Run/Cycle) with explicit Start; replace-consequence variant note
- C02-CardioLive — indoor run recording (Lifting | Cardio switch), time, distance, avg pace,
  current pace, HR, calories, planned target progress (20 min), recording pulse, Pause/End
- C03-CardioPaused — paused state clearly different (not one grey word)
- C04-CardioOutdoor — outdoor run live: GPS state (no map during workout — user rule)
- C05-CardioDistance — manual distance editor sheet + ended-segment summary card

## Row 6 — Finish (inventory-active-cardio.md)
- F01-Finish — the winning direction's finish summary, refined (full scroll)
- F02-Finish-Cardio — a mixed session / cardio finish with route map (routes allowed after finish)
- F03-Finish-NotSaved — nothing logged: "wasn't saved" state

## Row 7 — History (inventory-history.md)
- H01-History — month summary, calendar strip, rows (title, date/time, families, sets, time,
  PR count, unit badge, cardio distance + route thumb, Edited mark), grouped by week
- H02-Calendar — month grid sheet with training days (intensity), selected-day workout(s)
- H03-WorkoutDetail — strength session: hero, tiles (same order as Finish), HR graph + zones,
  exercises with snapshot equipment, set lines (W marks, bar breakdown), PR marks, per-exercise
  chart button, menu (Save as Template…, Delete) as visible actions, Edited mark, Add Exercise
- H04-WorkoutDetail-Cardio — outdoor run detail with route map, splits if derivable, HR
- H05-EditSet — edit logged set sheet (type, weight/unit, reps, delete set)
- H06-ProgressChart — Seated Chest Press: metric switch (Best set / Volume / 1RM), variation
  picker, chart with PR markers (y-axis not from 0), selected point, change since first, rep bests
- H07-History-Empty — empty state with one action

## Row 8 — Gyms (inventory-gyms-scan.md)
- G01-Gyms — gym cards (visits, last visit, machines count, unit), Add Gym…; No-gym note
- G02-Gyms-Empty — empty state
- G03-GymDetail — Iron Temple: stats, Scan Machine primary, machines grouped (movement label +
  model), per-machine last used / best, Deleted machines entry, Edit Gym…
- G04-MachineDetail — Chest Press 2: model, unit, usual preset, history on this machine (best,
  last used, times used), Edit, Delete (swipe/visible)
- G05-EditGym — New/Edit Gym sheet (name, city, default unit)
- G06-ModelPicker — catalog search (1,877 models), grouping/filter, New Model…
- G07-DeletedMachines — list with Restore, "Nothing deleted" variant

## Row 9 — Scan & AI identification (inventory-gyms-scan.md, audit-cardio-ai-screens.md)
- S01-ScanCamera — viewfinder with framing box, shutter, photo library, tips-free
- S02-PhotoConsent — the consent step (what leaves the phone), Allow photos and continue
  (a real button), policy link separate
- S03-Identifying — progress with the captured photo thumbnail
- S04-Result-Specific — matched machine: photo, brand/model, movement, confidence as visual
  state (not prose), editable fields, Add
- S05-Result-Ambiguous — candidate list to choose from (states visibly different from Specific)
- S06-Result-Generic — uncertain/new model: generic fallback, correction, Retake
- S07-ModelCorrection — correction sheet (past vs future application)

## Row 10 — Exercises (inventory-exercises-settings-design.md)
- E01-Exercises — search, grouped by body area with family colours, filter/grouping menu,
  rows show load type + last trained; tapping opens detail
- E02-ExerciseDetail — (new destination) records, mini chart, presets, load type, machines used
- E03-NewExercise — sheet: name, load type, muscle group, equipment tags
- E04-Presets — presets sheet: suggestions, add, rename, empty
- E05-LoadType — edit load type sheet with consequence line

## Row 11 — Settings (inventory-exercises-settings-design.md)
- X01-Settings — units (Metric / U.S. customary), rest defaults (m:ss), template prompts,
  heart-rate zones, Ask AI row (flag the stale "Ask AI about plates" label — propose a rename as
  a user decision), history update line, Export
- X02-AISettings — key (device Keychain), three consents, status
- X03-Export — CSV / JSON export, last export date, share

## Row 12 — System surfaces and accessibility
- Z01-LiveActivity — lock screen Live Activity (lifting with rest countdown; cardio) + Dynamic
  Island compact/expanded
- Z02-AppIcon — the app icon in the new language (1024 tile + home-screen context)
- Z03-Notification — rest complete notifications (timer / recovered / cap)
- Z04-Home-AXL — Home at AccessibilityL
- Z05-Live-AXL — Live at AccessibilityL
