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

## ACTIVE: public beta ("Stacked") — ticket 01 Prepare implemented, in Codex review

Planned 2026-10-01/02 with the user: **[spec](../work-record/public-beta/spec.md)** (answers Q1–Q14), decision
**D60** (reopens SPEC's no-backend/no-accounts line, D5, D41, D53, D56, D58), tickets
[`work-record/public-beta/issues/01…09`](../work-record/public-beta/issues/). The planning is on `main` (`bab270b`,
fast-forwarded at the user's request). In short: Stacked; optional Apple/Google accounts with a training profile,
workouts stay on the phone; a Cloudflare Worker + D1 server; all AI on the user's key through it (60/10/60 a day,
off switch, no key on phones); onboarding; in-app feedback; the user on internal TestFlight now.

**Ticket 01** ([01](../work-record/public-beta/issues/01-paid-team-testflight.md)) — worktree
`/Users/ericlee06/orca/workspaces/Health App/public-beta`, branch **`ericlee4992/beta-01-paid-team`** (pushed; not
merged). **Implemented and verified locally (Prepare):** team from `Config/Local.xcconfig` (pbxproj and the
installer), home-screen name Stacked, `ITSAppUsesNonExemptEncryption`; `scripts/container-tools/`
(`verify_container.py` with `--expect`/`--export`, `compare_stores.py` with preferences, `compare_trees.py`);
DEVELOPMENT → *Container backup and restore* (Gate S stable backup, Gate P phone copy preflight, the TestFlight
backup bridge); the restore rehearsed on the Simulator with negatives; the Apple Support draft (send only after the
gates). **Codex review 01: not clear** (2 P2, 4 P1) — all addressed in the ticket's response; **round 2 pending**
in the Orca terminal "Codex review — beta 01". **Not done:** phases A–E (phone, Apple account). Simulator
**WT-Beta01** `A3D88C6F-6426-427A-9A0E-CF11A93798B1` holds a copy of the user's 09-29 data — delete it once the review
is clear. Evidence under this session's scratchpad `…/scratchpad/b01/` (ephemeral; results are in the ticket).

**Phone facts are unchanged:** the free-team build from 2026-09-29 is installed; profiles expire **2026-10-06
04:45 EDT**. The paid enrollment was **pending** on 2026-10-02. The bundle ID is probably held by the free Personal
Team (the user chose to keep it and ask Apple Support if refused). iOS cannot upgrade across teams, so the data
moves by Gate S → delete → install → restore → compare.

## Next action

1. **Codex review 01, round 2** → fix until "clear" → merge `ericlee4992/beta-01-paid-team` into `main` only with the
   user's go-ahead → delete WT-Beta01.
2. **Phase A by 2026-10-05 18:00 EDT at the latest** (plan: Oct 4), unless D is done: Gate S → Gate P → free
   renewal → install → compare. Needs the user and the unlocked phone.
3. When Apple approves the enrollment: ticket 01 phases B–E (gated as in the ticket; the user approves the delete).
4. Still waiting on the user from before: visual acceptance of the Floodlight redesign on the phone (feedback as
   tickets under `work-record/redesign-floodlight/`). Not yet exercised anywhere: VoiceOver by a person, Reduce
   Motion at runtime, real GPS and sensors on the redesigned cardio screens, Lock Screen commands on a device, a
   restore from a backup on a phone (Simulator only so far), a non-US simulator region.

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
