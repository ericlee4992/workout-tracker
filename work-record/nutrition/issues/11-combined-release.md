# R — The combined release (Phase 1 + Phase 2) to testers

Type: task
Status: **in progress** (2026-11-11) — the user: "lets work on R now"; branch `ericlee4992/release-r`
Blocked by: S1–S4, N1–N10
Implementer: Claude; Reviewer: Codex for the release notes, README and privacy changes.
Spec: [soft-redesign](../../soft-redesign/spec.md), [nutrition](../spec.md). Decisions: D76; D62 (release notes).

## Goal

Ship the Soft redesign and nutrition together as one TestFlight build (build **10** unless another ships first).

## Checklist

1. **Cost re-check:** the food flows' real cost per request (N6) against the limits; the user confirms.
2. **Full UI suite** — release candidate (DEVELOPMENT → *When to run the full UI suite*); about an hour; **ask the
   user first**. Record named failures; known flakes listed in STATE.
3. **What's New** (D62: a big change) and the tester **What to Test** note; the user approves both.
4. **README** and its screenshots (AGENTS: screens and features changed); server README for the new endpoints.
5. **Server deploy:** the N6/N8 flows, the D1 cache migration, `USDA_API_KEY` set by the user, the approved privacy
   page; backup of D1 first (ticket 08's procedure).
6. **App Store Connect:** App Privacy answers updated (diet data, photos), the user confirms; Beta App Review for
   Friends (new data types may be reviewed again).
7. **Gate S** on the user's phone (the stored format changes): USB backup, round trip, then install.
8. **Build:** bump to 10, archive from the recorded `main` commit in `…/Health App/release-build`, upload, Developer
   group, the user's phone check (incl. the safety copy made on first launch, Health permissions), then Friends.
9. Update STATE, SPEC (nutrition and the new tabs), and this ticket with the evidence.

## Progress

**2026-11-11 (Claude), after N8 merged.** Checklist state:

1. **Cost re-check** — recorded live checks (N6, N7; `gpt-6.1-terra`, $1/1M in, $5/1M out): food-photo $0.0041–0.0059,
   food-label $0.0021–0.0023, food-describe $0.0013–0.0015 a request; training flows $0.0018–0.0061. One person at
   every daily limit (60 scans, 10 weeks, 60 suggestions, 30 photos, 30 labels, 60 descriptions) ≈ **$0.74 a day**.
   N8 adds no AI cost (Open Food Facts and USDA are free; USDA's key allows 1,000 requests an hour, the cache cuts
   repeats). **The user (2026-11-11): keep the limits as they are.**
2. Full UI suite — the user's go (2026-11-11). Running at `32165f7` (app unchanged since N8's merge `3ad9dca`):
   `-testPlan Full -only-testing:WorkoutTrackerUITests`, 2 workers, 386 tests, WT-Floodlight; xcresult
   `/private/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-UI-design/8bffdecc-0105-4db5-8c71-05a754a21832/scratchpad/r-full.xcresult`.
   **Result: 381 passed, 3 failed, 2 skipped of 386, exit 65.** Skipped by design: `BackupExportUITests` (the
   installed store, device-only) and `FloodlightFeedbackUITests.testSmokeSendsToTheBuildsServer` (the live server).
   Failures rerun serially (`r-rerun.xcresult`): `FloodlightLiveUITests.testACompletedSetCanBeCorrectedInPlace`
   ("102." for "102.5" — typing under parallel load) and `LogFoodFlowUITests.testManualAddLogsCaloriesAloneAnd…`
   ("2 servings", known) **passed**; `WorkoutNameUITests.testRenamingFromHistoryIsAMarkedEdit` failed again — a test
   defect: it tapped the receipt's Done mid-presentation (dropped; the sheet stayed over History), which
   `HistoryEditingUITests` already guards. Fixed with the same wait (`closeReceipt()`, both tests of the class);
   `WorkoutNameUITests` × 3 iterations serial: passed, exit 0 (`r-name.xcresult`). No app defect found.

   ```
   Verified: Full UI plan 381/386 parallel (exit 65) + the 3 failures: 2 pass serially, 1 test fixed and passes ×3
   Not verified: BackupExportUITests and the feedback smoke test (skipped by design; device / live server)
   Known flaky: FloodlightLiveUITests.testACompletedSetCanBeCorrectedInPlace, LogFoodFlowUITests "2 servings" (parallel only)
   ```
3. **What's New and What to Test approved as drafted (the user, 2026-11-11: "both yes").** What's New entry build 10
   in `WhatsNew.entries`; `WhatsNewTests` + `FloodlightWhatsNewUITests` 13/13 serial, exit 0 (`r-wn.xcresult`;
   captures light/dark × Default/AccessibilityL checked: all four lines above Continue, scrolled at AXL).
   Privacy page: **still waiting** — approval and effective date.
4. README: Today picture added (`docs/readme/today.png`, dark, default size, food + goals sample, 603 px), the food
   and barcode/search text (N8). Server README has the N6/N8 endpoints. The "not yet in TestFlight" marks change when
   build 10 is in TestFlight.
   **Codex R round 1 (`codex-review-r.md`): not clear — 3 P3, privacy/support copy:** S1 paths said "Settings →"
   (now Profile → Send Feedback / Ask AI / Export &amp; backup → Export / the account card → Delete Account); S2
   "account needed only for the AI features" (now also online food lookup; hand logging works without); S3 export and
   deletion text now name the nutrition data (JSON carries food, foods/meals, goals, body weights, personal details,
   not meal photos; Health keeps workouts, body weights and food nutrition). Fixed; server 283/283 + tsc.
5.–9. Not started — need the user (privacy approval + date before the deploy; App Privacy; Gate S on the phone).

### Draft — What's New (build 10, in-app, once after updating)

Title: **New: Food, and a fresh look**
- fork.knife — Log food from Today: search, scan a barcode or a label, or take a photo of your meal.
- target — Set calorie and protein goals; Today shows what's left.
- scalemass — Track your body weight, with Apple Health if you like.
- paintbrush — A softer look across the app, with a new Profile.

### Draft — What to Test (TestFlight, build 10)

"Build 10 adds food logging and a new look. Tap Log food on Today to search, scan a barcode or label, or photograph a
meal; set goals in Profile. Your workouts and templates should be just as before (the app makes a safety copy first).
Send anything odd from Profile → Send Feedback."

### Privacy page changes since the live version (October 15, 2026) — for approval with a new effective date

N6/N9: what's stored on the iPhone now includes food, goals, body weight, personal details; Apple Health reads/saves
weight, saves food totals, reads active energy; meal photos are kept with their entry; the food AI features (photo,
label, description) are sent only when used, no separate prompt. N8: "Barcodes and food search" (barcode numbers and
search words go to Open Food Facts and USDA through the server; 30-day shared cache linked to no account; searches
kept only as a one-way code; daily counts removed after ~2 days); both listed as processors. Exact text:
`git diff 0191b3f HEAD -- server/src/pages.ts`.

## Comments
