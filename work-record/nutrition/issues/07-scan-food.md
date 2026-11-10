# N7 — Scan Food camera: meal photo and food label

Type: feature
Status: **mock v1 shown** (2026-11-10) — awaiting the user's approval of the mock
Blocked by: N4, N6
Implementer: Claude; Reviewer: Codex (visible Orca terminal), to "clear".
Branch (when built): `ericlee4992/nutrition-07-scan-food` off `main`.
Spec: [nutrition](../spec.md). Decisions: D69, D73; D56 (photo consent), D53 (label crop).

## Goal

Point the camera at a meal or a nutrition label, check the estimate, and log it.

## Scope

- **Camera** with modes **Scan food | Barcode | Food label** (Barcode is wired in N8). Photo library pick as well.
- ~~**Consent:**~~ *removed by the user 2026-11-10 (D83): no consent screen.* Was: the first scan explains that the photo goes to the server for one estimate and is not kept there — a
  logged meal photo stays on the phone with its entry (D82) — (D56's
  pattern); sign-in required for AI (as today).
- **Meal photo → progress card → logged at once (D82, the user 2026-11-10, from a reference screenshot):** Today's
  log shows a card — the blurred photo with an estimated percent ring, "Analyzing image", skeleton lines, "We'll notify
  you when done!" (a notification if the app is in the background when it finishes); the result is logged straight
  away and the card becomes the entry: photo thumbnail, name, time, calories, macros. Tap → the items screen: each item
  editable (name, portion, grams, calories, macros) or removable, Add item, totals, plain numbers (D78), meal; delete
  with Undo. The photo is kept on the phone with the entry (an additive stored field; deleted with the entry).
  *Was:* a review screen with Log ("nothing is logged without Log").
  Open for the build: one entry per item under the photo, or one grouped entry named for the meal (the reference shows
  one, "Poke Bowl") — mock both.
- **Food label →** cropped to the label (D53's crop) → the Selected food screen (N4) prefilled with the label's
  serving and numbers, Save to My foods offered.
- **Describe what you ate** (the Log Food field, N4) → food-describe → the same review screen.
- **Failure states:** no camera permission, nothing recognised (offer Manual Add), daily limit reached (shows when it
  resets), offline / server error (retry), signed out (sign in).

## Acceptance

1. Each mode on the Simulator with fixture responses (UI tests with a stubbed server), including every failure state.
2. A real scan of a sample meal and a sample label on the Simulator or phone (no personal photos in the repo).
3. Captures (default / AccessibilityL, light / dark); Codex clear.

## Code map

- `Domain/ScanMachine.swift`, `LabelCrop.swift`, `AIServerClient.swift` (patterns to reuse); new `Features/Food/Scan*`.
- Prototype: `Screens/Scan`.

## Progress

**Mock v1 (2026-11-10, branch `ericlee4992/nutrition-07-scan-food`) — sent to the user for approval; nothing wired.**
Sample data in memory only (`Features/Food/Scan/FoodScanMock.swift`, launch flag `-scanFoodMock`); the meal, label
and barcode "photos" are drawn in code (no personal photos). A yellow sliders button on Today (mock only) switches the
photo-entry option, how the next scan ends, signed in, camera allowed and photo consent.

- **Entry points:** a round camera button beside Today's Log food pill (D68 has no floating +; one tap to the camera),
  and a camera in Log food's bar. **Describe what you ate:** typing in Log food's search (All) shows "Estimate
  “…”" / "With AI · logs to <meal>" above the results; it is logged at once like a photo, its card on Today.
- **Camera (full screen, always dark):** Cancel; the drawn feed; a frame per mode (meal: square; label: the tall crop
  box, outside dimmed harder — D53; barcode: a wide band, no shutter — N8); a hint line; three equal mode tiles
  Scan food | Barcode | Food label; library · shutter · flash. Before it: Sign in (signed out). ~~The photo consent~~ — removed
  (D83). Camera off: "Camera access is off", Choose a photo / Open Settings.
- **Meal photo (D82):** the camera closes at once; Today's log shows the card (blurred photo, percent ring rising over
  ~5 s, "Analyzing image", skeleton lines, "We'll notify you when done!"), which becomes the entry in its meal. The fuel
  card and day rings count it. Failure cards in its place: No food found (Retake, Manual Add), Daily limit reached (Manual
  Add), Couldn't analyze (Try again); × removes the card.
- **Both options for a photo's entries (open):** A — one entry named for the meal (thumbnail, name, time, macros, cal);
  B — the photo as a header ("Photo · 5 items", time, total) with each item its own entry under it.
- **Items screen** (tap the entry; staged, Cancel / Save): photo with its time, Name (option A), meal chips, total as the
  hero + macros, Items (name, portion · grams · macros, cal → item editor: Name, Portion, Weight, calories and macros,
  Remove Item), Add item, Delete Entry (with Undo on Today). In option B an item opens on its own (Cancel / Save).
- **Food label:** shutter → "Reading the label…" over the cropped label (Take another photo) → "From the label": the
  label thumbnail, Name (needed) and Brand, Servings stepper, Serving and Servings per container as printed, the total
  hero + macros, Other nutrition facts shown open, **Save to My foods** on, **Log to <meal>**; Retake in the bar.

**ios-design.** Today with a scan: the eye stays on the fuel card's hero; the card is the log's first item, the photo its
anchor. Camera: the shutter is the one bold control; the mode tiles are a state (white fill), not commands. Label food:
the total is the hero, Log the one primary. Tells: same container on everything — absent (the card is a group: photo +
status; items are a list); chips — deliberate (meal choice only); all-caps — absent; middle dots — deliberate (the
entry lines "12:40 PM · P 36 · C 70 · F 14 g", as N5's rows); accent overuse — absent (the action colour only on the shutter,
the same `ScanShutterStyle` as Scan Machine, and the existing Log food pill); equal stacked blocks — absent; above the fold — the card is in
the first viewport after the log header; control as primary — absent; default-size-only — absent (AXL captures: the card
stacks photo over text, rows stack, the percent is capped inside its ring).

**New strings for the user's OK:** "Scan food" (camera button label), "Analyzing image" / "Analyzing description",
"We'll notify you when done!", "No food found" / "Try a closer photo, or add it by hand.", "Daily limit reached" /
"30 meal photos a day. More at 7:00 PM.", "Couldn't analyze" / "No connection. Your photo is kept until you try
again.", Retake / Try again, "Fit your meal in the frame" / "Point at a barcode" / "Fit the Nutrition Facts in the box",
"Sign in to scan food with AI.", "Camera access is off" / "Allow the camera in
Settings, or choose a photo of your meal." / "Choose a photo", "Reading the label…", "From the label" / "Check the
numbers, name it, log it.", "Save to My foods", "Estimate “…”" / "With AI · logs to Dinner", "Photo · 5 items",
"Items", "Add item", "Portion", "Weight", "Remove Item", "Delete Photo and Items".

**Decided (the user, 2026-11-10 → D83):** (1) option **A**, one entry named for the meal; (2) the name from the server
(add a meal name to the food-photo reply); (3) a description logged at once; (4) both camera entry points; (5) ask for
the notification permission on the first scan; (6) "More at 7:00 PM" (local time of the UTC reset) is fine; (7) a library
photo uses the time it was taken (its meal follows it); a camera photo uses now; (8) **no consent screen** ("just get rid
of the consent screen") — the camera opens straight after sign-in. Wiring drops option B and the mock
switcher. Still for the user: the new strings above.

Verification (mock): `build-for-testing` exit 0; `ScanFoodUITests` (2 tests, 2 workers) — results in the session's
scratchpad; captures light/Default + dark/AXL looked at. Not verified: anything stored or sent (nothing is wired).

## Comments
