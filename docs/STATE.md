# Current project state

Updated **2026-10-02** during public-beta ticket 01 (Prepare implemented; Codex review in progress). The Floodlight redesign was merged and
installed 2026-09-29; nothing changed on the phone or in the code since. The previous STATE (the per-ticket
redesign handoff, the September 22 installation, the AI/cardio open items) is archived byte-for-byte:
[STATE before Floodlight merge](archive/STATE-2026-09-29-before-floodlight-merge.md). Verify Git on resume.

## Delivered: the Floodlight redesign (merged and installed 2026-09-29)

- **`main`** was fast-forwarded to the commit that adds this STATE (pushed; the Orca worktree branch
  `ericlee4992/redesign-floodlight` points at the same commit). It contains every redesign ticket: 02 Workout tab,
  03 live workout, 04 finish receipt, 05 History, 06 Gyms, 07 Scan, 08 Exercises, 09 Settings, 10 Ask AI for
  Templates, 11 system surfaces (Live Activity, icon, `Theme`/`Legacy*` removed), 12 Cardio, 13 release candidate.
  Each was Codex clear; records `work-record/redesign-floodlight/issues/01…13-*.md`, reviews beside them,
  captures `work-record/redesign-floodlight/captures/`. Decisions: **D59** (replaces D54) lists the user's.
  The stacked `ericlee4992/redesign-floodlight-*` branches are all merged into `main` (kept on origin).
- **Release-candidate pass** ([ticket 13](../work-record/redesign-floodlight/issues/13-release-candidate.md)): unit
  919/919; full UI suite 227/229 on `796ffe5`. Both failures were date-dependent test defects (fixed), and every
  affected test was rerun green. One app fix: `WorkoutCalendar` re-anchors its month cursor, so a month that starts
  on a midnight DST jump no longer drops today's month (pre-existing; not reachable in New York). Codex review 13
  clear after 3 rounds.
- **Installed** 2026-09-29 ~09:30 EDT: the `rc-device-build-2` product of code `522c157` (identical to `main`'s
  code). Bundle `4F3321DC-F8CE-4CE3-82ED-93205BC859E1`; app and widget ran from it (PIDs 56986 / 56987). The first
  launch was refused until the user re-trusted the developer app on the phone (DEVELOPMENT → Provisioning expiry).
- **Signing:** Apple ID signed in to Xcode (team `X68M8SR6NA`). App profile `9919493b…` and widget profile
  `ba4e9c29…` both expire **2026-10-06 08:45 UTC (04:45 EDT)**. Renew before then per DEVELOPMENT; reinstalling
  the same binary does not extend them.
- **Backup** `~/WorkoutTracker-Backups/2026-09-29-before-floodlight/` (mode 0700): 27 files, 26,725,362 bytes,
  SHA-256 manifest, integrity `ok` on copies; **24 workouts, 343 sets, 2 templates**, 0 unfinished. After launch,
  a row-by-row comparison of all 15 tables (`preservation-report.json`) found every old row intact. The only
  change was the user's own gym pick (Noyes Fitness Center → 312 College Ave), confirmed by the user. The schema
  is unchanged. Older backups (Sep 17/18/20/22) remain.
- Phone: iPhone 15 Pro Max, iOS 27.0, UDID `00008130-001E10C01E62001C`, bundle `com.ericlee4992.workouttracker`.

## ACTIVE: public beta ("Stacked") — 01 phase A done (B–E wait on Apple); 02 merged; 03 server half merged

Planned 2026-10-01/02 with the user: **[spec](../work-record/public-beta/spec.md)** (answers Q1–Q14), decision
**D60** (reopens SPEC's no-backend/no-accounts line, D5, D41, D53, D56, D58), tickets
[`work-record/public-beta/issues/01…09`](../work-record/public-beta/issues/). The planning is on `main` (`bab270b`,
fast-forwarded at the user's request). In short: Stacked; optional Apple/Google accounts with a training profile,
workouts stay on the phone; a Cloudflare Worker + D1 server; all AI on the user's key through it (60/10/60 a day,
off switch, no key on phones); onboarding; in-app feedback; the user on internal TestFlight now.

**Ticket 01** ([01](../work-record/public-beta/issues/01-paid-team-testflight.md)) — worktree
`/Users/ericlee06/orca/workspaces/Health App/public-beta`, branch **`ericlee4992/beta-01-paid-team`**; Prepare was
**fast-forwarded into `main` (`907b81b`) on 2026-10-02 at the user's go-ahead** (pushed). **Implemented and verified locally (Prepare):** team from `Config/Local.xcconfig` (pbxproj and the
installer), home-screen name Stacked, `ITSAppUsesNonExemptEncryption`; `scripts/container-tools/`
(`verify_container.py` with `--expect`/`--export`, `compare_stores.py` with preferences, `compare_trees.py`);
DEVELOPMENT → *Container backup and restore* (Gate S stable backup, Gate P phone copy preflight, the TestFlight
backup bridge); the restore rehearsed on the Simulator with negatives; the Apple Support draft (send only after the
gates). **Codex review 01: not clear** (2 P2, 4 P1); **round 2 (01b): not clear** (1 P1, 1 P2) — both addressed (the
Simulator export round trip, `compare_exports.py`, `simulator_export.sh`, `BackupExportUITests`); **round 3 (01c): not
clear** (1 P2: date-shaped text normalized) — addressed; **round 4 (01d): clear**. The review terminal is closed
in the Orca terminal "Codex review — beta 01". **Not done:** phases A–E (phone, Apple account). Simulator
**WT-Backup-01** `A3D88C6F-6426-427A-9A0E-CF11A93798B1` (Gate S's disposable round-trip Simulator) was erased after the
clearance (exit 0); erase it after every later use (it receives copies of the user's data). Evidence under this session's scratchpad `…/scratchpad/b01/` (ephemeral; results are in the ticket).

**Phone (2026-10-02, ticket 01 phase A):** Gate S and Gate P passed (25 workouts, 355 sets; backup
`~/WorkoutTracker-Backups/2026-10-02-phase-a/`); the free signing was renewed and `main` `b83cf39`'s code installed in
place (home-screen name **Stacked**), every row and preference preserved. Profiles now expire **2026-10-09 03:52 EDT**
(07:52 UTC). The Apple ID is signed in to Xcode again (it had been signed out); the phone is registered to the
Personal Team again. The paid enrollment was **pending** on 2026-10-02. The bundle ID is probably held by the free Personal
Team (the user chose to keep it and ask Apple Support if refused). iOS cannot upgrade across teams, so the data
moves by Gate S → delete → install → restore → compare.

**Ticket 02 (onboarding)** — branch `ericlee4992/beta-02-onboarding`, **fast-forwarded into `main` (`4823d46`) on
2026-10-02 at the user's go-ahead** (pushed). Not yet on the phone (it reaches the phone with ticket 01's TestFlight build). The
user changed the plan after seeing a walkthrough prototype: **one welcome page, then a guided tour of the real app on a
temporary in-memory sample world** (spec Q8b, D60). Implemented: `Features/Onboarding/` (WelcomeView, Tour,
OnboardingCoordinator, TourSampleStore), Settings → Help → Show Tour, the welcome only on a fresh phone with no workouts
(never on the user's phone; never in UI tests unless `-uiTestOnboarding`). The app under the tour is disabled and
untouchable; the tour never opens a workout, camera, AI, Export, a sheet or Settings. **Codex clear after 2 rounds.**
Tests: unit 930/930 (whole target, before the round-1 fixes) + `OnboardingTests` 6/6; `FloodlightTourUITests` 10/10;
adjacent UI suites 57/60 then History 7/8 — **3 pre-existing UI failures** (two History chart captures at
`FloodlightHistoryUITests.swift:100`, likely date-dependent; the CoreLoop model picker at :274) **fail identically on
`main`** without ticket 02: a separate follow-up. Simulator **WT-Onboarding** `2CEC4AD8-F702-421F-B3B2-D68C302A3453`
(sample data only).

**Ticket 03 (server and Sign in with Apple)** — branch `ericlee4992/beta-03-server-apple`; the server half was
**fast-forwarded into `main` on 2026-10-02 at the user's go-ahead** (the app half will be its own branch). The **server half** is done and **Codex clear after 4 rounds**: `server/` (Cloudflare Worker + D1;
Sign in with Apple with the exchanged identity bound to the user, sessions, profile name, sign-out, deletion claimed in
one transaction with queued revocation and an hourly retry, stub pages; 48/48 tests in the Workers runtime with a fake
Apple), `scripts/check-secrets.sh` + its regression test (14 cases), CI `.github/workflows/server.yml`. **Not done:**
the user's Cloudflare account, D1 creation, secrets, the first deploy (steps in `server/README.md`); the app half
(capability, account client, Settings Account row, onboarding sign-in) waits on the paid team.

## Next action

1. **Phase A done 2026-10-02.** If the paid move (D) is not done by then, renew again **before 2026-10-09 03:52 EDT**
   (plan: Oct 7–8), behind Gate S as in the ticket.
2. When Apple approves the enrollment: ticket 01 phases B–E (gated as in the ticket; the user approves the delete).
3. Still waiting on the user from before: visual acceptance of the Floodlight redesign on the phone (feedback as
   tickets under `work-record/redesign-floodlight/`). Not yet exercised anywhere: VoiceOver by a person, Reduce
   Motion at runtime, real GPS and sensors on the redesigned cardio screens, Lock Screen commands on a device, a
   restore from a backup on a phone (Simulator only so far), a non-US simulator region.

## Found 2026-10-02 (pre-existing, not caused by the public-beta work)

- **iOS CI ("Tests" workflow) fails on every `main` run since the Floodlight merge `4765b76` (2026-09-29):** the build
  stops compiling `WorkoutTracker/Features/ActiveWorkout/LiveSetRow.swift` on the `macos-26` runner (Xcode 26); the same
  code builds and tests locally on Xcode 27. A runner-image/SDK mismatch to look at with the deferred hosted-CI work.
  The new "Server" workflow (secret scan + server tests, Linux) passed on `e455222`.
- **Three UI tests fail on `main` too** (ticket 02's regression run): `FloodlightHistoryUITests` light/dark captures at
  `:100` ("a multi-day series draws", likely date-dependent since the month changed) and
  `CoreLoopUITests.testModelPickerFiltersAndSearchesDownToOneModel` (:274, the known model-picker flake). A small
  follow-up ticket.

## Still open from before the redesign (unchanged; details in the archived STATE)

- [AI ticket 06 — private device acceptance](../work-record/ai-gym/issues/06-device-acceptance.md): after the
  September 22 update, the phone checks were never reported. These cover all generated templates visible without a
  restart, Scan Machine inside template setup, preserved preferences and equipment, and old history visible. Also
  gym recognition and routine feedback. Do not ask for the OpenAI key in chat; the Mac credential
  `~/.config/workouttracker/openai.env` (0600) is not bundled.
- [Cardio hardware checks](../work-record/cardio/issues/02-device-acceptance.md): pause/reconnect, phone-position
  accuracy, background GPS, mixed sessions. The Watch companion has never been built or installed.
- [Deferred work](../work-record/deferred-work.md): scanner/picker, history/calculation, supersets, precision,
  migration/restore, HR, Watch, catalog, public launch and CI follow-ups. Non-failing invalid-frame warnings, the
  hosted CI runner hang, and actual Orca workspace Sleep also remain deferred.

## Other sessions and scratch state (do not clean without asking)

- The main checkout `/Users/ericlee06/orca/projects/Health App` is on `ericlee4992/redesign-visual-proposal`
  (a separate Codex session's visual proposal, superseded by the Floodlight decision; not merged).
- **Worktree clean-up 2026-10-01 (user's choice):** removed every clean, pushed or merged checkout — the eleven
  `/tmp/wt-floodlight/*` scratch checkouts and sixteen older Orca worktrees (ai-gym-and-routines, ai-template-followup,
  cardio-*, codex-project-setup, compact-start-outdoor, finish-summary-*, restore-start-capsules,
  review-cardio-implementation, session-handoff*, sets-completion-ring, verification-policy); their branches remain in
  Git and on origin. `/tmp/wt-floodlight/` keeps `results/` (test logs, xcresults), `shots/`, the runner scripts and
  `dd-device/` (the binary installed on 2026-09-29); the other derived data was deleted.
- **Kept for a later look (not removed):** worktrees whose branches exist only on this Mac, some with uncommitted
  files — `ai-schema-baseline`, `ai-template-followup-review`, `cardio-api-research`, `redesign-prototype` (the
  tappable Simulator prototype of the Floodlight look; one uncommitted file), and the `review-*` checkouts (Codex/Claude
  review reports, some untracked). Save or push before removing any of them. `redesign-floodlight` (the redesign's
  Orca worktree, identical to `main`) can be closed once no session runs in it. Simulator **WT-Floodlight**
  `9E822EF6-DC67-4958-AEA2-D53D2D36D674` (iOS 27); WT-iPhone27 / WT-iPhone kept for regression and compatibility.
- The Graft index is a git-ignored local cache per checkout: rebuilt in this worktree 2026-10-01 (graft 0.18.0); the
  main checkout's is older (`graft build` refreshes it).
- **Branches on origin with commits not in `main`, all deliberately unmerged records** (nothing else is unmerged):
  `ericlee4992/redesign-visual-proposal` (4, the superseded 09-24 visual proposal, the main checkout's branch),
  `ericlee4992/cardio-design-prototype` (3, 09-17 cardio prototypes), `ericlee4992/finish-summary-second-pass` (3,
  09-17 finish-summary exploration), `ericlee4992/review-cardio-implementation` (3, 09-18 review records),
  `ui-redesign-16-active-workout` (1, a ticket-16 docs note). Every `redesign-floodlight*` branch is in `main`.
