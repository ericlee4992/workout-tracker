# 05 — Profile page and training profile

Type: task
Status: mock **approved by the user 2026-10-03** (and the Ask AI decision); server side implemented; Codex review 05
**Codex clear (round 3, 2026-10-03)**; waiting for the user's go-ahead to merge.
Wiring (the page live, the editor saving, Ask AI prefill and save) waits on 03's app half (sign-in, the paid team).
Blocked by: 03
Implementer: Claude (the user's order 2026-10-03); Reviewer: Codex.
Branch: `ericlee4992/beta-05-profile` off `main`.
Spec: [spec.md](../spec.md) → *Profile page*. Decisions: D60 (amends D58), D52, D59.

## Goal

A real profile page for signed-in people, including a saved training profile that prefills Ask AI for Templates.

## Scope

- Profile page from Settings → Account: display name (editable), sign-in method and email, "Member since",
  **today's AI use** against each limit (placeholder until ticket 06 provides `/v1/ai/usage`), the training
  profile, Sign out, Delete account.
- **Training profile:** goals, experience, days per week, minutes per session, optional height and weight —
  the Ask AI for Templates inputs. Stored on the server (`PUT /v1/profile`); height and weight keep the value and
  unit entered (D52), validated against the same bounds Ask AI uses. Deleting the account deletes it.
- Ask AI for Templates prefills from the profile. **Decide in the mock with the user** whether edits made inside
  Ask AI offer "Save to profile" or stay transient (D58's default).
- No profile photo (Q4). No SwiftData schema change.

## Design (ios-design skill, steps 1–4)

**Job, state, bold element.**
- *Profile page, signed in:* exists so the tester can see who is signed in and today's AI use, and change the
  training profile in one tap; **the eye lands on Today's AI** — three figures (`statNumber`) against their limits,
  the one thing that changes day to day. The name is the page title (chrome). Runner-up: the training-profile card
  (Edit in its header). Account facts, Sign Out and Delete Account follow; Delete is the quiet destructive row last.
- *No training profile yet:* the card becomes one "Set Up Training Profile" tile (the invitation).
- *Editor:* a sheet with staged edits (Cancel / **Save**, the one accent command, enabled by a change); in Ask AI's
  own vocabulary (A01) so the two read as one form: goal + phrase chips, experience tiles, **the days-per-week
  figure** (bold, as in A01), minutes, then optional height and weight.
- *Settings → Account row:* the first thing on Settings — initials, name, email; signed out, "Sign In" with one line.

```
Profile (Default)                         Editor (sheet)
┌──────────────────────────────┐          ┌──────────────────────────────┐
│ ‹                            │          │ (Cancel) Training Profile [Save]
│ Alex Kim                     │ title    │ ┌ goal text ───────────────┐ │
│ alex@privaterelay…           │          │ ✓Build strength  +Build muscle│ chips
│ Today's AI   Resets at midnight         │ Experience [▮ Beg][▮ Int][▮ Exp]
│ ┌12/60──┐┌2/10───┐┌0/60───┐  │ ← bold   │ ┌ 4 days per week ─────────┐ │ ← bold
│ │scans  ││weeks  ││suggest.│  │          │ │ [1][2][3][4] 5  6  7      │ │
│ └───────┘└───────┘└────────┘ │          │ │ 45 minutes per session    │ │
│ Training profile        Edit │          │ └──────────────────────────┘ │
│ ┌ goal text ───────────────┐ │          │ Height and weight   Optional │
│ │ Experience  Intermediate │ │          │ ┌ Height  [5] ft [10] in   ┐ │
│ │ Schedule  4 days · 45 min│ │          │ └ Weight  [180] lb         ┘ │
│ │ Height  5 ft 10 in       │ │          └──────────────────────────────┘
│ └ Weight  180 lb ──────────┘ │
│ ✦ Fills in Ask AI for Templates.
│ Account: Name › / Signed in with / Email / Member since
│ [Sign Out]   [🗑 Delete Account…]
└──────────────────────────────┘
```
At AccessibilityL the three figures stack, label/value rows put the value under the label, and the editor's rows
stack as A01's do.

**Units (D52).** Height and weight are stored as entered: `{value, unit}` with unit cm or in (feet + inches stored as
total inches) for height, kg or lb for weight. An empty field takes the app's units; a stored value shows in its own
unit even if the app's units change. Ask AI converts only for its request (cm/kg, as today).

**Ask AI for Templates — decided by the user 2026-10-03: a "Save to my training profile" switch, on by default.**
Ask AI prefills from the profile; edits made there update the profile when the request is made unless the tester
turns the switch off (amends D58's transient default; record in DECISIONS with the wiring). Signed out, Ask AI is
unavailable anyway (it needs the server).

**The user's approval (2026-10-03):** the profile page, editor, Settings Account row and the proposed copy below,
**as shown** in the captures.

**Proposed copy (every string is the user's decision):** Settings row **Sign In** / *For AI and a training profile.*;
page sections **Today's AI** (*Resets at midnight*; *Paused* when the off switch is on), **Machine scans**, **Template
weeks**, **Exercise suggestions**, **Training profile** (**Edit**), *Fills in Ask AI for Templates.*, **Set Up
Training Profile** / *Goals, schedule, height and weight for Ask AI.*, **Account** (**Name**, **Signed in with**,
**Email**, **Member since**), **Sign Out**, **Delete Account…**; editor **Training Profile**, **Cancel / Save**,
**Experience**, **Height and weight** (*Optional*); Ask AI **Save to my training profile**, *Filled in from your
training profile.* The delete confirmation and sign-in sheets come with 03's app half.

**Tells.**
- Same container on everything — absent: figures are stat tiles, the training profile one panel (a group), facts a
  list, Sign Out a row, Delete a destructive row.
- A chip where a caption would do — absent (chips only where A01 has them: goal phrases).
- All-caps label above every section — absent.
- Middle-dot metadata — deliberate: "4 days · 45 min" (the app's stat-line idiom).
- Accent on so many things — the accent is the editor's Save and the Edit link (the app's header-action style); the
  selected experience tile and day cells are A01's selection state.
- Equal-weight stacked blocks — the three AI tiles are a stat strip of like figures (deliberate, as on History); the
  page's blocks differ in kind and size.
- Phone-sized website — absent; the first viewport carries the figures and the training profile.
- More than the job above the fold — the account facts sit below the fold on purpose (rarely needed).
- A control dressed as the primary — absent; Edit is a header link, Sign Out a plain row.
- Layout only at default size — AccessibilityL captured.

## UI first

Sample-data captures of the profile page and the training-profile editor, Default and AccessibilityL, light and
dark, approved by the user before wiring.

## Acceptance

- [x] Approved captures in `../captures/05/` (the user, 2026-10-03; `FloodlightProfileUITests` 4/4, result
      `prof-all.xcresult`, exit 0 — scratchpad evidence, summarized in Progress).
- [x] Server tests: profile validation, unit preservation, deletion (`test/profile.test.ts`; 195/195 after round 1).
- [ ] Prefill works in Ask AI for Templates; no change when signed out.
- [x] Targeted unit/UI tests (TrainingProfileTests 9/9; FloodlightProfileUITests 7/7 across `prof2` + `dbg2`; Ask AI and Settings regression 18/18 in `reg05`).

## Verification scope

Server unit tests; targeted app unit and UI tests (Settings, Ask AI for Templates entry); captures.

## Progress

### Mock — 2026-10-03 (Claude)

Branch `ericlee4992/beta-05-profile` off `main` `d761301` (07 and 06's server half merged). `Domain/TrainingProfile.swift`
(`TrainingProfile`, `BodyMeasure` with units as entered, `AccountProfile`); `Features/Account/ProfileView.swift` (the
page, `SettingsAccountRow`), `TrainingProfileEditor.swift` (built from A01's own controls), `ProfileSample.swift`
(sample data and the pushed screen; flags `-uiTestProfileSample`, `-uiTestProfileNoTraining`,
`-uiTestProfileSignedOut`, `-uiTestProfilePrefill`, all only under `-uiTestReset`); Settings shows the Account row only
under those flags; `AIRoutineSheet` prefills and `AIGoalsStep` shows the "Save to my training profile" mock only under
`-uiTestProfilePrefill`. **No networking, nothing reachable in a normal launch.** Capture test
`FloodlightProfileUITests` (4 tests: Settings signed out and in, the page, the editor, no training profile, Ask AI
prefilled; light/dark × Default/AccessibilityL) on WT-Onboarding: **4/4 passed** (exit 0); 50 captures in
[captures/05/](../captures/05/).

### Server side — 2026-10-03 (Claude)

`migrations/0005_training_profiles.sql`, `server/src/training.ts`, `GET /v1/profile` now returns `training` (or null);
`PUT /v1/profile` takes `displayName` and/or `training` (object to save, null to remove), checking both before writing
either; bounds as Ask AI's (goal 1–1,000 characters, experience, 1–7 days, 15–120 minutes, 50–250 cm, 20–400 kg —
converted only for the check); height/weight stored as entered (`cm`|`in`, `kg`|`lb`); conditional save while the
account exists; deletion removes it in claimDeletion's transaction. **Tests 190/190** (23 new in
`test/profile.test.ts`); mutations — bounds ignoring the unit, the name written before validation, an unconditional
save — each fail.

### Regression and unit tests — 2026-10-03 (Claude)

`TrainingProfileTests` (3: units as entered and their display/conversions, Ask AI's bounds at their edges, JSON as the
server takes it) + `AIRoutineFlowMathTests`: **13/13**. UI regression for the touched screens —
`FloodlightAIRoutineUITests` (AIRoutineSheet's model now comes from `ProfileSample.prefilledRoutineModel()`, a plain
model without the flag) **8/8** and `FloodlightSettingsUITests` (the Account row slot) **10/10**: one run, 18 UI + 13
unit, exit 0.

## Codex review 05 — response (round 1)

Report [codex-review-05.md](../codex-review-05.md) (HEAD `5909fe2`): **not clear**, 2 findings + record notes; all
accepted. Codex reran 190/190 and read the recorded Xcode results (4/4 captures; 31/31 regression).
1. **P2 inherited unit names; a failed combined PUT renamed anyway** — units are looked up in a `Map` (no inherited
   `toString`/`constructor`/`__proto__`), and a non-finite converted value is refused; PUT now commits the rename and
   the training write in **one D1 batch** (the old `setDisplayName` helper is gone). Tests: four inherited names → 400
   with name and profile unchanged; a training write failing at the database inside the batch → 500 with the old name
   and profile intact. Mutations: separate writes fail the atomic test; looking units up on a plain object is caught by
   the finite check too (two guards).
2. **P3 fractional values rounded in the app** — `BodyMeasure.display` shows values as entered ("82.5 kg",
   "5 ft 10.5 in", "177.25 cm"); the editor's cm, inches and weight fields take decimals (decimal pad; up to two
   decimals; comma or point) and keep their own text while typing, so "82." can become "82.5". Tests: display and
   parse cases (unit); `testEditorKeepsADecimalWeightAsTyped` types 82.5 lb, saves, and finds "82.5 lb" on the page (UI,
   passed). The captured states show whole numbers and are unchanged.
- **Parity:** `TrainingProfile.isValid` now matches the server's goal checks (non-blank after trimming, no control
  characters but tab/newlines, ≤ 1,000 characters); test added. `TrainingProfileTests` **5/5**.
- **Records:** README intro; acceptance boxes checked with their evidence; STATE refreshed.

## Codex review 05b — response (round 2)

Report [codex-review-05b.md](../codex-review-05b.md) (HEAD `3c86d78`): **not clear**, 2 P2s, both consequences of my
round-1 field change; accepted. Codex confirmed round 1's server fix (Map lookup, finite check, one-batch PUT) and the
goal parity, and read the recorded runs.
1. **P2 replacing feet lost the inches shown** — the editor now stages height and weight as text in `MeasureDraft`
   (Domain): feet and inches are read together from both current strings; clearing both clears the height.
2. **P2 shown ≠ saved (truncation to 2 decimals, inches clamped to 11.99; 3-decimal server values rounded on display)**
   — typed numbers are read strictly by `TypedNumber` (≤ 4 digits, optionally one or two decimals with a point or a
   comma); anything else, and 12 inches or more, is invalid: the field turns the destructive colour (VoiceOver: "not a
   valid entry") and Save stays off — nothing is truncated, clamped or carried. A field left as it was keeps the stored
   value exactly (a 82.567 kg server value survives an unrelated edit and save); display shows up to six stored
   decimals ("82.567 kg").
- Tests: `TrainingProfileTests` **9/9** (strict reading incl. "82.567", "82.", ".5", "12345"; feet/inches replacement,
  12 in refused, 11.99 accepted, clearing; untouched precision kept; empty fields take the app's units); UI
  `testReplacingFeetKeepsTheInches` (5 ft 10 → 6 ft 10, the page shows "6 ft 10 in") and
  `testTwelveInchesKeepsSaveOffAndClearingBothClearsTheHeight`; server: the route's 401 when the account is deleted
  between authentication and the batch (**196/196**).
- Records: STATE no longer says nothing unmerged holds work.
- Runs: `prof2.xcresult` — `TrainingProfileTests` 9/9 and the four capture tests + the decimal test passed; the two new
  UI tests first failed from a **test-helper** bug (a tap in the middle of the one-character feet field put the cursor
  before the "5", so typing made "65", which the editor correctly refused); the helper now taps at the trailing edge
  and asserts the field's value; `dbg2.xcresult`: the three editor tests **3/3** (exit 0). Captured states unchanged.

## Codex review 05c — round 3: clear

Report [codex-review-05c.md](../codex-review-05c.md) (HEAD `600561b`): **Verdict: clear**, no findings; Codex reran
196/196 and `tsc`, and read `prof2` (noting it was not wholly green: the two new tests failed there from the helper
bug) and `dbg2` (3/3 after the fix). Open (not this stage): the live wiring after 03's app half.

## Comments
