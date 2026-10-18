# 14 — In-app "What's New" for big changes

Type: feature
Status: Codex clear (2026-10-17, round 2); ships with ticket 16 in build 7
Blocked by: —
Spec: [spec.md](../spec.md). Decision: [D62](../../../docs/DECISIONS.md). Related: [DEVELOPMENT → TestFlight build
checklist](../../../docs/DEVELOPMENT.md#testflight-build-checklist); onboarding (ticket 02) for the existing first-launch flow.

## Request (the user, 2026-10-17)

"for things like fixing small bugs or adding small features, just the description on "What to Test" is fine.
However, for big new additions or changes to the app, when they first open the app, I want a window to pop up that
shows/describes the new features."

## Scope as understood

- When the app first opens after an update that has a What's New entry, show a one-time sheet describing the new
  features (title, a few short items, optionally an image), then never again for that version/build.
- Updates without an entry (small fixes) show nothing; the TestFlight "What to Test" note covers them.
- Not on a fresh install (the onboarding tour covers new people) — to confirm.
- Possibly a way to see it again later (e.g. Settings) — to decide.

## To decide in the design (with the user)

- Look: a sheet in Stacked's design (ios-design skill), with real captures at Default and AccessibilityL.
- Keyed per build number or per marketing version; how entries are written (in code, per release).
- Interaction with onboarding and with a workout in progress (never interrupt a live workout).

## Comments

**The user's decisions (2026-10-17).** Shown **only on updates** (a fresh install gets the guided tour instead);
**readable again from Settings** (a "What's New" row); this update's text **as drafted**: title "New: Progress";
"Pin any lift or cardio activity to the new Progress tab." / "Each chart shows your latest best and how far you've come
since your first session." / "Long-press a chart to change what it shows, move it or remove it."; button "Continue".
Still to design (with captures): the sheet's look; keyed per build or version; never over a live workout.

**Built (2026-10-17, Claude).** Branch `ericlee4992/beta-14-whats-new` off ticket 16's tip `63a6058` (16 is not merged
yet; both ship in build 7). `Domain/WhatsNew.swift`: the entries (build 7, the approved text), the launch rule
`WhatsNew.decide` (fresh install = the welcome page's own rule — never answered, no workout — records the current build
and shows nothing; an update shows the newest entry after the last build seen and at or before this one; a workout in
progress defers it with nothing recorded; fail-closed counts), last-seen build in UserDefaults
(`whatsNew.lastSeenBuild.v1`), saved on dismissal (Continue or a swipe) and never moving backwards.
`Features/Onboarding/WhatsNewSheet.swift`: the title (`largeTitle`), one row per line with a glyph in a raised disc,
Continue (`.lookPrimary`, the only prominent button). `WorkoutTrackerApp`: evaluated on the user's own RootView appear
(never in the tour's world); `-uiTestReset` clears the last-seen build and the sheet shows in UI tests only with
`-uiTestWhatsNew`. Settings → Help → **What's New** (newspaper glyph — sparkles mean AI here, so Add Chart's "Most used"
moved to a star too). DEVELOPMENT's TestFlight checklist says where an entry goes; README mentions it.
**Design notes:** the sheet follows the system What's New pattern (title, lines, one Continue at the foot); at
AccessibilityL the third line scrolls under Continue (the content is a scroll view; nothing is truncated).
**Verified:** build **BUILD SUCCEEDED**; `WhatsNewTests` **6 passed**; `FloodlightWhatsNewUITests` **5 passed** (captures
light/dark × Default/AXL in `captures/14/`, looked at; Continue closes; Settings opens it again; a test launch without
the argument never shows it); regression on WT-iPhone27 — full unit suite **1041 passed**, FloodlightSettingsUITests +
FloodlightTourUITests **20 tests, 0 failures**. The icon swap afterwards is visual only (build passed). Not exercised:
the real update path on a phone (build 6 → 7) — check it when build 7 installs.

**Codex review round 1 — response.** Report [codex-review-14.md](../codex-review-14.md) (HEAD `5aff73c`): **not clear**,
2 × P2, 1 × P3; the normal update path, baseline, monotonic recording, dismissal, test isolation, glyphs and docs
confirmed. All taken: (#1) the app decides only when **both** workout counts read (otherwise nothing shown, nothing
recorded), and a workout in progress now comes **first** in `WhatsNew.decide`, before any baseline is recorded. (#2) the
welcome's own rule (`OnboardingCoordinator.shouldShowWelcome`, reused — not re-written) wins on every launch it applies,
**even with a baseline**: an interrupted onboarding on build 7 then an update to build 9 shows only the welcome and records
9; the parameter is now `welcomeUnanswered`. Presentation level: `decide` returns no entry whenever the welcome applies,
so the app never requests both. (#3) each line carries `whatsNewItem`; the capture test scrolls until the last line's
bottom is above Continue, asserts it, and keeps an extra `…-axl-scrolled` capture. Unit `WhatsNewTests` **8 passed**
(new: `anUnansweredWelcomeWinsEvenWithABaseline`, `aWorkoutInProgressRecordsNothingEvenWithTheWelcomeUnanswered`). UI `FloodlightWhatsNewUITests` **5 passed** (exit 0); captures refreshed, incl. `whatsnew-14-{light,dark}-axl-scrolled.png`.

**Codex review round 2: clear.** [codex-review-14b.md](../codex-review-14b.md) (HEAD `803f425`). Remaining: merge with 16,
build 7, and the real update path on the phone (build 6 → 7 shows the sheet once).

**Merged, not uploaded (2026-10-17).** The user: "Merge only" — `main` fast-forwarded to the 14 branch tip (16 + 14);
build 7 is not built or uploaded yet. **What to Test note approved for build 7** ("Use this note"): "Build 7 adds a Progress tab. Tap + or Add Chart to pin any lift or cardio activity — each chart shows your latest best and how far you've come. Long-press a chart to change what it shows, move it or remove it; tap it for the full chart. A short What's New page introduces it once after updating (Settings → What's New shows it again). Otherwise as before: send anything odd from Settings → Send Feedback."
