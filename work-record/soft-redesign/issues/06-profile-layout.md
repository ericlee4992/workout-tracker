# S6 — Profile like the prototype

Type: change
Status: **approved** (the user, 2026-11-08) — scheduled in Phase 2, **right before N3** (after N1, N2)
Implementer: Claude; Reviewer: Codex.
Spec: [soft-redesign](../spec.md); prototype `SoftProfileAndAdd.swift` (`SoftProfileScreen`, tag
`design/soft-approved-2026-11-07`). Decisions: D68 (five tabs).

## Why

The user (2026-11-08), looking at Phase 1 on the Simulator: "Why does the profile page look different from the design
we had earlier". S2 made the Profile tab by retitling the old Settings page (`SettingsView(title: "Profile")`), so every
setting sits inline; the approved prototype's Profile is a summary: an account card, short grouped rows that open
sub-pages, and Help. S2's ticket wording allowed the shortcut and no review compared it with the prototype (a miss).
The user chose to build it in Phase 2 right before N3, so N3 (Nutrition goals) and N9 (body weight, Apple Health) add
their rows straight into the new layout and Profile is laid out once.

## Scope (the groups approved by the user 2026-11-09, as proposed; Settings also carries N1's Safety copy)

- **Account card** on top: name and sign-in method (or **Sign in** when signed out), opening the account and training
  profile (today's account pages).
- **Settings group:** "Units, rest and appearance" → today's settings (units, appearance, working/warm-up rest, ask to
  update templates); Heart rate zones; Ask AI; Export & backup.
- **Goals & tracking group:** created here, filled by N3 (Nutrition goals) and N9 (Body weight goal, Apple Health).
- **Help:** Show Tour, What's New, Send Feedback; the app version at the bottom.
- The prototype's "Training" group (History / Gyms / Exercises) is **not** built: they are tabs in layout A (D68).
- Every existing setting stays reachable (checklist against today's `SettingsView`); identifiers kept or every test
  updated; captures light/dark × default/AX, side by side with the prototype; the tour's Profile step checked.

## Design (ios-design steps 1, 2, 4)

**Job.** Signed in: this screen exists so the user can reach any setting, their account or help in one tap; the eye
lands on the **account card** (top-leading, the only block with a large figure — the 64 pt disc). Signed out: the
same, the card reading "Sign In". No build server: no card; the eye lands on the Settings group. Runner-up: the
Settings group (rows, not cards; no accent). No call to action on this screen wears the accent.

**Initial viewport (default size), relative sizes:**

```
Profile                                   ← LookNavTitle (chrome), tour anchor
┌──────────────────────────────────────┐
│ (●64)  Alex Kim                    › │  ← account card: the largest block
│        Signed in with Apple          │
└──────────────────────────────────────┘
Settings
┌──────────────────────────────────────┐
│ ⚙ Units, rest and appearance       › │  ← equal rows, one surface, hairlines
│ ♥ Heart rate zones        185 bpm  › │
│ ✦ Ask AI                       On  › │
│ ↑ Export & backup                  › │  (subtitle: "This phone holds the only copy…" when no export)
└──────────────────────────────────────┘
Help
┌──────────────────────────────────────┐
│ Show Tour · What's New · Send Feedback│ (three rows)
└──────────────────────────────────────┘
Version 0.1.0 (9)                         ← footnote, secondary
```

Goals & tracking: no rows exist until N3, so the group is not drawn yet (an empty group is a tell); N3 adds it between
Settings and Help.

**Sub-pages.** *Units, rest and appearance* (pushed): today's Units tiles (still that page's bold element), Appearance,
Workout (rests, Ask to update templates), the one-time History update note. *Export & backup* (pushed): today's Export
card with counts and last export, the only-copy notice, and N1's Safety copy section. Heart rate zones and Ask AI open
their existing sheets.

**Every setting stays reachable (checklist against `SettingsView` before S6):** account → card ✓; units, appearance,
working/warm-up rest, ask to update templates, history note → Units, rest and appearance ✓; heart rate zones → row
(sheet) ✓; Ask AI → row (sheet) ✓; Export (+ only-copy notice) → Export & backup ✓; Safety copy → Export & backup ✓
(a restore failure is also shown on Profile, under Settings, so it is not hidden one level down); Show Tour, What's
New, Send Feedback → Help ✓.

**Strings (new or changed — the user's decision, approved as the prototype unless noted):** group headers "Settings",
"Help"; rows "Units, rest and appearance", "Heart rate zones", "Ask AI", "Export & backup" (*new — the prototype had no
export row; the ticket's scope named it*); account subtitle "Signed in with Apple/Google" (replaces the email; the
account page still shows the email); "Version 0.1.0 (9)" (*new*); the zone row's value "185 bpm" / "Not set"
(existing strings; the zone ladder stays in the sheet, not on Profile).

**Tells:** same container on everything — absent (one card for the account; rows in grouped lists). Chip where a
caption would do — absent. All-caps labels — absent (sentence-case group headers). Middle dots — absent. Accent
overuse — absent (no accent on this screen except the tab). Equal stacked blocks — deliberate: the groups are lists of
equal rows under a leading card (the accepted prototype composition). Phone-sized website — absent. Above the fold —
the account card and every Settings row are in the first viewport. Control dressed as primary — absent. Default-only
layout — rows wrap their titles at AX sizes; the value moves under the title (`LookRow` subtitle) where needed; checked
in AccessibilityL captures.

## Progress

Branch `ericlee4992/soft-06-profile` off `main` `5f8ff92` (N2 merged).

**Built (`b7e9c79`):** `ProfileTabView` (new root: account card, Settings rows, Help, version; `ProfileRow` moves the
value under the title at AX sizes; one VoiceOver element per row, e.g. "Ask AI, Sign In"); `SettingsView` is now the
"Units, rest and appearance" page; `ExportBackupView` (Export card, only-copy notice, Safety copy); the account card
(`SettingsAccountRow`) restyled like the prototype — 64 pt dark disc, name at title3, "Signed in with Apple/Google";
`SettingsZoneLadder` removed (unused: the zones sheet lists the zones). New ids: `profileSettings`,
`profileExportBackup`, `profileVersion`, `profileRestoreFailed`; every old id kept. Test helpers
`openProfileSettings()` / `openExportBackup()` in `TabNavigation.swift`; tests updated in FloodlightSettings, Export,
BackupExport, FloodlightFeedback, FloodlightTour, FloodlightWorkoutTab, SafetyCopy, RedesignScreenshot.

**Test scope (DEVELOPMENT → layout within the Profile area + moved settings):** build; every UI class that opens
Profile or a moved setting — AAAWarmUp, FloodlightSettings (captures: Profile root `s6-profile-*`, the two
sub-pages, light/dark × default/AXL), Export, FloodlightFeedback, FloodlightTour, SafetyCopy, FloodlightAccount,
FloodlightGoogle, FloodlightProfile, FloodlightAIAccess, FloodlightWhatsNew, and the named tests
RedesignScreenshot `testUnitSystemDefault/Accessibility`, `test05_settings`, HeartRate
`testZonesAreReachableFromSettings`, FloodlightWorkoutTab `testAppearanceReachesScreensAndSheets` (~73 tests,
3 workers). No unit change except removing an unused view.

**Results:** build exit 0. UI run (`s6-ui1.xcresult`, 3 workers): **72 passed, 1 failed, 1 skipped** (exit 65) — the
failure `FloodlightSettingsUITests/testTabRoundTripDropsTheFileCard` timed out waiting for the system share sheet's
Close button on parallel clone 3 (inside `cancelShareSheet()`, before anything S6 draws); **rerun serially ×3: 3/3
passed** (`s6-ui1-rerun.xcresult`, exit 0). The skip is `BackupExportUITests` (needs `WT_BACKUP_EXPORT=1`).
**Captures looked at** (scratchpad `s6-caps/named/`): Profile root light/dark × default/AXL with and without the
account (`s6-profile-*`, `profile-settings-signedin/out-*`), Export & backup (`s6-export-backup-*`), Units, rest and
appearance (`floodlight-09-x01-*`), the tour's Profile step (`tour-s6-*`). Every string whole at both sizes; at AXL the
row values sit under their titles; the account card is the first and largest block signed in and out.

**Verified:** build; the UI scope above (73 tests; the one clone failure passes serially ×3); captures.
**Not verified:** VoiceOver by a person; a real phone; the Goals & tracking group (N3/N9 add it).
**Known flaky:** `testTabRoundTripDropsTheFileCard` — the share sheet's Close button on a parallel clone (passes
serially).

## Comments
