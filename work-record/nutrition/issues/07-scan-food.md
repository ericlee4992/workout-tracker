# N7 — Scan Food camera: meal photo and food label

Type: feature
Status: **proposed** (2026-11-07) — awaiting the user's approval
Blocked by: N4, N6
Implementer: Claude; Reviewer: Codex (visible Orca terminal), to "clear".
Branch (when built): `ericlee4992/nutrition-07-scan-food` off `main`.
Spec: [nutrition](../spec.md). Decisions: D69, D73; D56 (photo consent), D53 (label crop).

## Goal

Point the camera at a meal or a nutrition label, check the estimate, and log it.

## Scope

- **Camera** with modes **Scan food | Barcode | Food label** (Barcode is wired in N8). Photo library pick as well.
- **Consent:** the first scan explains that the photo goes to the server for one estimate and is not kept there — a
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

Not started.

## Comments
