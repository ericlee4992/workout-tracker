# N1 — Automatic safety copy before a stored-format change

Type: task
Status: **done — Codex clear (round 3), merged into `main` 2026-11-09**; approved (the user, 2026-11-09: "all as proposed" — every row of the table below, and the failed-copy
behaviour: tell the user, offer Continue or Quit, wording shown for approval); this is [public-beta ticket 11](../../public-beta/issues/11-safety-copy.md), now scheduled
Blocked by: S4 (Phase 1 done first)
Implementer: Claude; Reviewer: Codex (visible Orca terminal), to "clear".
Branch (when built): `ericlee4992/nutrition-01-safety-copy` off `main`.
Spec: [nutrition](../spec.md); [public-beta spec → Data safety](../../public-beta/spec.md). Related: D28, DEVELOPMENT →
*When a backup is required*; `StoreFormatGuardTests` (ticket 11's guard, in `main`).

## Why

N2 is the first update since the beta began that changes what the phone stores. Testers cannot make backups; the
user deferred ticket 11 "until the first stored-format change" (2026-10-14). It must ship with or before N2 — in the
combined release it ships in the same build.

## Goal

Before the app opens its store with a new data format for the first time, it saves a complete copy of the user's data
on the phone, without the user doing anything, and offers a way back.

## Decided with the user (2026-11-09: all as proposed)

| Question | Proposal |
|---|---|
| What the copy is | Both: the store files (`.store`, `-wal`, `-shm`, copied before the container opens) for an exact restore, and the D28 JSON export as a portable fallback |
| When | Only when the recorded stored-format version differs from this build's; never on ordinary launches. Also before Import replaces data, if that is not already protected |
| Where | Application Support / `SafetyCopies/` (included in the iPhone's own iCloud or computer backup, not shown in Files) |
| How long | The last 2 copies; older ones deleted after a successful copy |
| Restore | Profile → "Restore data from before the update" (shown only when a copy exists), with a confirmation that names the copy's date; restore replaces the current store and relaunches |
| Space | The user's store is about 27 MB; two copies plus JSON ≈ 80 MB at most today |

## Acceptance

- [ ] A simulated format change on the Simulator makes exactly one copy before the store opens; an ordinary launch
      makes none.
- [ ] Restoring the copy brings back every row (`compare_stores.py` against the pre-update capture).
- [ ] A failed copy (disk full, simulated) does not open the new format silently: the app tells the user and offers to
      continue or quit (wording to approve).
- [ ] The copy never leaves the phone; old copies are pruned as decided.
- [ ] Codex clear.

## Verification scope

Persistence → unit tests for the version check, copy, prune and restore; a Simulator rehearsal with a real old store
(WT-Backup-01, erased after use); the Settings/Profile UI test for the restore row.

## Code map

- Container creation: `WorkoutTracker/App/` (the app's `ModelContainer`); `Domain/ExportJSON.swift`, `ExportSnapshot.swift`.
- `WorkoutTrackerTests/StoreFormatGuardTests.swift`.

## Progress

Branch `ericlee4992/nutrition-01-safety-copy` (off `main` `52c1270`).

**Decisions while building (2026-11-09):**
- **Files only (the user, asked 2026-11-09).** The JSON half of "both" cannot be made from the *old* data by the new
  build — it can only read the data after converting it, the step the copy protects — and the app has no Import. The
  copy is the store's `.store` / `-wal` / `-shm`; Export still makes JSON at any time.
- **"When" is read from the store itself:** `NSPersistentStoreCoordinator.metadataForPersistentStore` +
  `isConfiguration(withName:compatibleWithStoreMetadata:)` against the app's model — exactly "would this open convert
  the data", with no version number to keep in step. An existing store whose metadata cannot be read also gets a copy.
  First rows rewritten at launch without a format change (repairs, backfills) are not a format change — DEVELOPMENT's
  review by hand still covers them.
- **Restore happens at the next launch, before the store opens** (iOS cannot restart an app, and replacing the files of
  an open SQLite store would corrupt it): Profile → confirm → "Close Stacked to finish" (with Cancel Restore) → on the
  next open the files are swapped (staged beside the store first, so a failure part-way leaves today's data), then
  "Data restored". Restored files are not copied again on that open. Restoring brings back old-format files, so the same
  build converts them again: restore is for a later build that fixes a bad conversion, or for data a conversion lost.
- **A failed copy:** the store stays closed; Try Again or Continue Without a Copy. ("Quit" became Try Again: iOS has no
  supported way for an app to quit itself; closing the app from the app switcher does the same.)
- **Where/how many:** Application Support/`SafetyCopies` (in the iPhone's iCloud or computer backup, not in Files); the
  newest 2; a copy waiting to be restored is never pruned; a free-space check first (files + 10 MB); an interrupted copy
  never counts (written under a hidden name, renamed when complete).
- Debug builds only: `-safetyCopyRehearsal` treats a launch as a format change (the Simulator rehearsal).

**Code:** `Domain/SafetyCopy.swift` (`SafetyCopies`: check, make, list, prune, schedule/cancel/perform restore;
`SafetyCopyLaunch.run`), `App/StoreGate.swift` (opens the store behind the copy; UI-test fixtures
`-uiTestSafetyCopy`, `-uiTestSafetyCopyFails`), `WorkoutTrackerApp` (start-up work moved to `prepare(_:)`, run when the
gate opens the store), `Features/Settings/SafetyCopyViews.swift`, `WorkoutTrackerStore.defaultStoreURL` /
`safetyCopies` / `appVersion`. No model change (`StoreFormatGuardTests` unchanged).

**Screens (ios-design):**
- *Copy failed (launch):* exists so the user can choose to retry or go on, in one tap; the eye lands on the title, the
  thumb on Try Again (the one filled command); Continue Without a Copy is the quiet second.
- *Settings → Safety copy (only when a copy exists):* one row, the newest copy and its date; the confirmation names the
  date again; Restore is destructive red.
- *Close Stacked to finish:* the title is the message; Cancel Restore the only command. An overlay over the app (a
  full-screen cover bound to this state dismissed the "Data restored" alert — found in the rehearsal).
- Tells: no cards in cards; no accent beyond the one filled button; no paragraphs beyond the two short lines.

**Strings — approved by the user 2026-11-09 ("Approve as shown"):** "Couldn't save a safety copy" · "This update changes how Stacked stores your
data. It saves a copy on this iPhone first — that didn't work." · "Your data hasn't been changed." · the reason, e.g.
"Not enough free space: the copy needs 48 MB, this iPhone has 12 MB free." · "Try Again" · "Continue Without a Copy" ·
"Safety copy" · "Restore data from before the update" · "Copy from Nov 9, 2026 at 1:30 PM" · "Restore data from Nov 9,
2026?" · "Your data goes back to how it was before the update. Anything logged since then is removed." · "Restore" ·
"The restore didn't work: <reason> Your data is unchanged." · "Close Stacked to finish" · "Your data from Nov 9, 2026
comes back the next time you open Stacked." · "Cancel Restore" · "Data restored" · "Your data is back to how it was on
Nov 9, 2026."

**Evidence (WT-Floodlight, session scratchpad `m/`):**
- `SafetyCopyTests` (18, real SQLite stores written through Core Data — SwiftData has no public close, and a store it
  still held changed under the copy, which the copy rightly refused): `-test-iterations 10` → **180/180, exit 0**
  (`n1-safety3.xcresult`).
- **Simulator rehearsal** (the design-sample store, 6 workouts / 58 sets / 1 gym, put in the app's real store location;
  the simulator's own store backed up and put back byte for byte afterwards): launch with `-safetyCopyRehearsal` →
  **exactly one copy**; an ordinary launch → **no new copy**; all workouts and the gym deleted with the app closed (a
  bad conversion's stand-in) → restore scheduled → next launch: **`compare_stores.py` exit 0 — every row of 15 tables
  back, preferences unchanged**; no copy of the restored files; "Data restored" shown and staying (`rehearsal/`).
- Unit plan **1134/1134, exit 0**, 101 s (`n1-unit.xcresult`).
- `SafetyCopyUITests` 7 + warm-up, serial: 8/8 after the fix (`n1-ui1` found the Settings row never appeared — its
  `.task` sat on an empty group; `n1-ui2` 6/6 re-run); captures light/dark × Default/AccessibilityL of all four
  screens checked: every string whole, one filled command.

## Comments
- **UI scope** (3 workers): warm-up + `SafetyCopyUITests` + `FloodlightSettingsUITests` (Settings changed) +
  `CoreLoopUITests` (start-up changed) + `ExportUITests` (the neighbouring row): **28/28, exit 0**, 962 s
  (`n1-ui3.xcresult`).
- `StoreFormatGuardTests` (its messages now point at N1) + `SafetyCopyTests`: **22/22, exit 0** (`n1-guard.xcresult`).

### Codex round 1 — [not clear](../codex-review-n1.md) (P1, 2 × P2, P3), all accepted and fixed

(The first Codex session died on an API "Bad Request" after its checks — all passing: its own rehearsal on
WT-iPhone27, 18 metadata checks incl. a simulated N2 lightweight migration and WAL-only metadata, UI 17/17; a fresh
session wrote the report from those results.)
1. **P1 — a restore that failed part-way could lose data** (current files deleted before the copy's were moved in; a
   failed move opened an empty store). The swap is now a transaction: stage the copy's files beside the store → consume
   the request (a failure here touches nothing) → write `restore-journal.json` → set the current files aside as
   `.replaced-*` (never deleted before the end) → move the copy's in → **deleting the journal is the commit** → sweep.
   Any failure before the commit rolls back to the set-aside files; a crash leaves the journal and the next launch rolls
   back before anything opens the store. If the rollback itself fails, the store stays closed (`.blocked`: "Couldn't
   finish the restore", Try Again only — never Continue).
2. **P2 — Cancel Restore could fail silently**, leaving the request armed. `cancelRestore()` now throws; the waiting
   screen stays and says "Couldn't cancel the restore: …". Found while fixing: a restore whose staging failed also left
   the request armed while the app opened. Rule now: **the store never opens while a restore request is armed** — a
   failure withdraws the request, and one that cannot be withdrawn blocks the open.
3. **P2 — the waiting screen did not isolate the app underneath** (the UIKit tab bar stayed reachable). Tried:
   `.disabled` + no hit testing + `.accessibilityHidden` under the overlay — a probe still found the Train tab in the
   accessibility tree (`.accessibilityHidden` does not reach the UIKit tab bar, as the tour notes). Now a real
   full-screen presentation (`fullScreenCover(item:)` with a real binding, attached to `mainApp`'s inner view — not the
   view with the "Data restored" alert, which the earlier constant-bound cover had dismissed); iOS keeps touch and
   VoiceOver inside a full-screen presentation. The UI test asserts the Train tab is not hittable and a tap where the tab
   bar is changes nothing (XCUITest's tree still lists the presenter's elements, so "exists" is not the measure).
   Re-checked on the Simulator: "Data restored" still shows and stays.
4. **P3 — README**: a "safety copy before data changes" line, marked on `main`, not yet in TestFlight.

**New strings (for the user's approval):** "Couldn't finish the restore" · "Stacked couldn't finish restoring your
data." · "It won't open your data until this is sorted out, so nothing gets mixed up." · "Couldn't cancel the
restore: <reason>".

**Round-2 evidence (WT-Floodlight):** `SafetyCopyTests` 24 (+7 failure-path tests: a failing set-aside move, a
failing move-in, a crash mid-swap undone at the next launch, an undo that fails → blocked then recovered, a request
that cannot be cleared → blocked, a failing cancel, a committed swap leaves nothing) × 10 → **250/250, exit 0**
(`n1r2-safety2.xcresult`); Unit plan **1140/1140, exit 0** (`n1r2-unit.xcresult`).
Warm-up + `SafetyCopyUITests` (incl. the new isolation assertions) + `CoreLoopUITests`, serial: **17/17, exit 0**
(`n1r2-ui2.xcresult`); the waiting screen's four captures re-checked.

### Codex round 2 — [not clear](../codex-review-n1b.md) (3 × P1, recovery edge cases), all accepted and fixed

Round 1's fixes confirmed (its own SafetyCopyTests 250/250, UI 8/8, the original failure regressions pass). Three
recovery cases reproduced against the production source:
1. **Leftovers of an earlier restore** (`.replaced-*` that its sweep could not remove) were taken for a later restore's
   set-aside files → a failing later restore "recovered" to older data. Each swap now tags its files
   (`.replaced-<tag>-…`, `.restoring-<tag>-…`) and the journal records the tag; recovery touches only that swap's files.
2. **An unreadable journal** read as "nothing to undo" (`try?`) → an empty store opened. Recovery now distinguishes a
   missing journal from one it cannot read or decode, and the latter blocks the open (journal and set-aside files kept);
   a journal naming anything but a plain store file name also blocks.
3. **The journal kept an absolute folder** → after the container moved, recovery found nothing and cleared the journal.
   It now keeps names only and recovers beside the store's current location; before changing anything it checks every
   original is either still in place or set aside — a missing one blocks.

Evidence: `SafetyCopyTests` 28 (+4: consecutive restores with unswept leftovers, unreadable journal → blocked then
recovered, damaged journal → blocked, relocated container recovered) × 10 → **290/290, exit 0**
(`n1r3-safety.xcresult`); Unit plan **1144/1144, exit 0** (`n1r3-unit.xcresult`). No UI change this round.

### Codex round 3 — [clear](../codex-review-n1c.md)

0 findings on both axes; its three round-2 reproductions now pass against `a0c0384` (and the control), its own
`SafetyCopyTests` × 10 passed. Merged into `main` (fast-forward), 2026-11-09.

**Verified:** `SafetyCopyTests` 28 × 10 → 290/290; Unit plan 1144/1144; `SafetyCopyUITests` + warm-up + CoreLoop 17/17;
UI scope (Settings, Export) 28/28 before the round-1 fixes; the Simulator rehearsal (one copy, none on an ordinary
launch, restore → `compare_stores.py` exit 0); Codex's own rehearsal on WT-iPhone27 and 18 metadata checks.
**Not verified:** a real phone (Gate S at the release), an iCloud/computer backup restore, a human VoiceOver pass of
the waiting screen, a process kill during a real swap (simulated by the journal tests).
**Known flaky:** none seen. **Open for the user:** the four round-1 strings ("Couldn't finish the restore", its two
lines, "Couldn't cancel the restore: …") were added after the wording approval — shown to the user for approval.
