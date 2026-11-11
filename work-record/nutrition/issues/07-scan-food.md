# N7 — Scan Food camera: meal photo and food label

Type: feature
Status: **done — Codex clear (round 4), merged** (2026-11-10) — mock approved with D83's answers; the user: "skip backup steps for wiring N7"
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

**Review (Codex, 4 rounds — `work-record/nutrition/codex-review-n7*.md`):** round 1 not clear (8 × P2 + P3: signed-out
describe, earlier-day result, rounded item numbers, mode change during capture, stale import/label work, background
expiry, **photos outside the safety copy** → photo moved into a `FoodPhoto` row, Reduce Motion, README/privacy) — all
fixed in `cb9ef04`; round 2 (fresh Codex session) not clear (2 × P2: earlier-day card after Delete/Undo, Cancel during
a capture) — fixed in `d217517`; round 3 one P3 (empty state) — fixed in `16482c3`; **round 4 clear**.

**Evidence (final):** Unit plan 1,232/1,232 definitions (1,252 executions); ScanFood 13/13 + TodayFood 7/7 (Claude
`v4.xcresult`; Codex `/tmp/codex-n7d/ui.xcresult` 21/21 with warm-up); LogFood 5/5 + LogFoodFlow 5/5 (Claude `v2`,
Codex round 2); server 254/254 + tsc; test-plan check exit 0; live check (above).

Verified / Not verified / Known flaky:
- **Verified:** build; Unit plan; ScanFood, TodayFood, LogFood, LogFoodFlow UI classes; server tests; captures at
  light/Default and dark/AccessibilityL; the three food flows live on the local server; a 2 MB photo through the real
  safety copy and restore.
- **Not verified:** the physical camera (crop, focus, restart), a delayed iCloud photo import, iOS ending background
  time, live notifications, the app against a live server with a real sign-in, CloudKit, a phone install, the full UI
  suite (at R).
- **Known flaky:** `ScanFoodUITests.testADescriptionIsLoggedAtOnce` lost its first Log food tap twice under 2 parallel
  workers (rounds 1–2; passed serially); it now taps once more — cause not established.

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
"Sign in to scan food.", "Camera access is off" / "Allow the camera in
Settings, or choose a photo of your meal." / "Choose a photo", "Reading the label…", "From the label" / "Check the
numbers, name it, log it.", "Save to My foods", "Estimate “…”" / "Logs to Dinner", "Photo · 5 items",
"Items", "Add item", "Portion", "Weight", "Remove Item", "Delete Photo and Items".

**Decided (the user, 2026-11-10 → D83):** (1) option **A**, one entry named for the meal; (2) the name from the server
(add a meal name to the food-photo reply); (3) a description logged at once; (4) both camera entry points; (5) ask for
the notification permission on the first scan; (6) "More at 7:00 PM" (local time of the UTC reset) is fine; (7) a library
photo uses the time it was taken (its meal follows it); a camera photo uses now; (8) **no consent screen** ("just get rid
of the consent screen") — the camera opens straight after sign-in. Wiring drops option B and the mock
switcher. Still for the user: the new strings above.

**Wiring (2026-11-10, after D83; the user skipped the backup steps for this data change):**
- **Server:** the food-photo and food-describe replies gain `mealName` (≤ 60 characters; empty only without items) —
  `FOOD_ITEMS_SCHEMA`, both flows' instructions, `checkFoodItems`; `food-ai.test.ts` (254 server tests, tsc clean).
  Deployed at R with everything else.
- **Data (additive, approved fingerprint `15051efe…`):** `FoodEntry.photo` (external storage) and `FoodEntry.items`
  (cascade) + new `FoodEntryItem` (id, order, name, portion, grams?, calories, protein, carbs, fat). Delete/Undo carries
  the photo and items; the JSON export carries the items and `hasPhoto` (not the photo bytes).
- **Domain (`Domain/FoodScan.swift`):** replies checked as the server checks them (`FoodEstimate`, `FoodLabelReading`);
  a scan logged as ONE entry named for the meal, numbers = the items' sum; `update` replaces items and recomputes;
  `logLabel` (Save to My foods → `createFood` + log, else a one-off entry; source `.label`); `FoodScan.when` (a library
  photo's own time, never in the future; its meal follows); `PhotoDate` reads EXIF DateTimeOriginal (+ offset).
- **App:** `FoodScanQueue` (in memory) runs each request with a background task, logs on success, keeps a failure card,
  notifies when the app is not in front (permission asked on the first scan; never under UI tests); the camera is
  `LabelCameraView` with the food box mapped by `LabelFramingBox.visionRegion`; a meal photo sends the whole photo
  (≤ 1568 px, `EquipmentPhoto.jpeg`), a camera label only the box (`LabelCrop.jpeg`); PhotosPicker for the library;
  Today's rows show the thumbnail and open the items screen for a scan; the mock and its switcher are gone.

**Live check (2026-11-10 evening, Claude — the dev key copied into git-ignored `server/.dev.vars` for the run and
deleted after, never printed):** local `wrangler dev` with this branch's server (migrations through 0007, a local test
session), `gpt-6.1-terra`, non-personal Wikimedia Commons samples re-encoded as the app does (≤ 1568 px, JPEG 0.85):
"Salmon Poke Bowl (S) with Spicy mayo sauce - Kitokito.jpg" and "FDA Nutrition Facts Label 2016.png".

| Flow | Answer | Tokens in / out (reasoning) | Cost | Latency |
|---|---|---|---|---|
| food-photo | `mealName` "Salmon poke bowl", 11 items (salmon, rice, edamame, … spicy mayo) | 2,487 / 688 (190) | $0.0059 | 10.3 s |
| food-describe ("two scrambled eggs and a slice of buttered toast") | "Scrambled eggs and toast", 3 items | 315 / 204 (57) | $0.0013 | 3.7 s |
| food-label | exact: 2/3 cup (55g), 8 servings, 230 cal, P 3, C 37, F 8, sat 1, fiber 4, sugars 12, sodium 160 mg | 1,657 / 79 (0) | $0.0021 | 2.4 s |

The photo took 10 s (N6's plate: 5.4 s) — the progress card's percent stops at 95 until the answer, so a slow estimate
still reads as working. Not done: the app itself against the local server (it needs a real sign-in); the app's parsing
of these replies is covered by `FoodScanTests` (incl. the label's "(55g)" spelling).

**Own decisions (minor, logged for the user):** a scan still running when the app is quit is not resumed (its photo is
stored only once logged); a label picked from the library is sent whole (the user chose that picture; D53's box is the
camera's); a library photo's meal follows its time even from Log food's chosen meal; a new item left nameless is
dropped on Save; the export carries no photo bytes.

**New strings since the mock (for the user's OK):** notifications "Poke bowl logged" / "550 cal · Lunch" and the failure
card's title/detail; "Try naming the food and how much." (description, nothing found); "60 descriptions a day. More at
midnight."; "No connection. Try again." (description offline); "Something went wrong. Try again." (other failures);
label: "No label found" / "Fit the whole Nutrition Facts panel in the box.", "Couldn't read the label", "30 labels a
day. More at midnight.", "Sign in again, then try again."; camera: "No camera" / "Choose a photo of your meal instead.",
"That photo couldn't be opened.", "That photo couldn't be used. Try again."; "New item" (an unnamed item's row);
"Meal" (the items screen's title while the name is blank).

Verification (mock): `build-for-testing` exit 0; `ScanFoodUITests` (2 tests, 2 workers) — results in the session's
scratchpad; captures light/Default + dark/AXL looked at. Not verified: anything stored or sent (nothing is wired).

## Comments
