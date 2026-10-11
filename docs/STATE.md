# Current project state

Updated **2026-10-10** (re-sign + live-workout fixes session; see *NOW* below). Before that: 2026-10-03, after tickets 07, 06's server half, 05's mock + server side and the 08 policy draft.
The previous STATE (the per-ticket
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
- **Superseded on the phone 2026-10-02** by ticket 01 phase A (see ACTIVE). **Installed** 2026-09-29 ~09:30 EDT: the `rc-device-build-2` product of code `522c157` (identical to `main`'s
  code). Bundle `4F3321DC-F8CE-4CE3-82ED-93205BC859E1`; app and widget ran from it (PIDs 56986 / 56987). The first
  launch was refused until the user re-trusted the developer app on the phone (DEVELOPMENT → Provisioning expiry).
- **Signing (superseded: renewed 2026-10-02 to 2026-10-09 03:52 EDT, see ACTIVE):** Apple ID signed in to Xcode (team `X68M8SR6NA`). App profile `9919493b…` and widget profile
  `ba4e9c29…` both expire **2026-10-06 08:45 UTC (04:45 EDT)**. Renew before then per DEVELOPMENT; reinstalling
  the same binary does not extend them.
- **Backup** `~/WorkoutTracker-Backups/2026-09-29-before-floodlight/` (mode 0700): 27 files, 26,725,362 bytes,
  SHA-256 manifest, integrity `ok` on copies; **24 workouts, 343 sets, 2 templates**, 0 unfinished. After launch,
  a row-by-row comparison of all 15 tables (`preservation-report.json`) found every old row intact. The only
  change was the user's own gym pick (Noyes Fitness Center → 312 College Ave), confirmed by the user. The schema
  is unchanged. Older backups (Sep 17/18/20/22) remain.
- Phone: iPhone 15 Pro Max, iOS 27.0, UDID `00008130-001E10C01E62001C`, bundle `com.ericlee4992.workouttracker`.

## NOW (2026-10-11): phone re-signed with the two live-workout fixes

- **Apple has not approved** (the user, 2026-10-10). Free profiles expired 2026-10-09 03:52 EDT; Xcode has since
  emptied `~/Library/Developer/Xcode/UserData/Provisioning Profiles/` (nothing to move aside).
- **Backup done (Gate S adapted; the expired app cannot launch, so no in-app JSON export)** in
  `~/WorkoutTracker-Backups/2026-10-10-resign/` over USB: a successful process query with no app process
  (`processes-before.json`, 476 processes); `capture-1` and `capture-2` (`verify_container.py` ok; capture 2
  `--expect` capture 1: restore set 4/4 identical); `compare_stores.py` against `2026-10-02-phase-a/after-renewal`
  (`since-10-02.txt`): **no old row missing**; added rows only (29 workouts vs 25, 393 sets vs 355) and ordinary
  changed fields (preferences' selected gym, gym-exercise memory timestamps/machine) — exit 1 only for those
  changes. Round trip of capture 1 on WT-Backup-01 (build-for-testing of `b83cf39`, the installed code): exit 0,
  29 workouts · 393 sets (`roundtrip-export.json`). **WT-Backup-01 erased.** Failed Wi-Fi logs in `superseded-wifi/`.
- **[live-workout-fixes](../work-record/live-workout-fixes/issues/) 01 + 02 merged to `main` (`f6e48f3`)** at the
  user's go-ahead ("merge both fixes into the build"): the weight box's unit is a label with `lb | kg` in the
  keyboard bar; a red Cancel beside minimize (a trash symbol at accessibility sizes — the user accepted the build as
  it stood), the Discard row gone. Codex clear on both (01 round 2, 02 round 2). Combined targeted run after the
  rebase: 32/32 on WT-Floodlight `9E822EF6…` (iOS 27; WT-iPhone is iOS 26.5 and no longer matches).
- **Built and installed `main` `71dda6c`'s code (`f6e48f3` + a STATE commit) 2026-10-10 23:58:** generic build with
  `-allowProvisioningUpdates -allowProvisioningDeviceRegistration`, exit 0; new profiles — app and widget both expire
  **2026-10-18 03:57 UTC (Oct 17, 11:57 PM EDT)**, both list the phone; the dylib carries `keyboardUnit` and no
  "Discard Workout…". `devicectl device install` exit 0 (`install.log`). **Remote launch refused**: FBSOpenApplication
  error 3, "profile has not been explicitly trusted by the user" (`launch.log`) — the same as 2026-09-29.
  **The user trusted it and the app runs (2026-10-11)**: they used the live workout and confirmed the keyboard-bar
  `lb | kg` switch works on the phone (a first "nothing happens" report was withdrawn; simulator reproductions of
  plain, dumbbell and barbell-without-bar rows all switched). No SwiftData schema change between `b83cf39` and
  `main` (only Codable/plain types added), so the store opened in place.
  **Installed build: `main` `8bc418b` (code `f6e48f3`), profiles to 2026-10-18 03:57 UTC.**
  Left (low risk, next time the phone is on USB with the app closed): a post-launch capture and
  `compare_stores.py capture-2 <after>`; the phone is back on Wi-Fi, where copies fail.
- **Re-sign again before Oct 17, 11:57 PM EDT** if Apple has not approved by then (same procedure; USB).
- Known, accepted: a long workout title truncates beside Cancel at the default size (seen with "Seated Che…").
- Scratch checkouts to remove once installed: `/tmp/wt-resign` (detached `b83cf39`), `/tmp/wt-live02`.

## ACTIVE: public beta ("Stacked") — handoff of 2026-10-03

**Checkout:** Orca worktree `/Users/ericlee06/orca/workspaces/Health App/public-beta`, branch
**`ericlee4992/beta-08-privacy-draft`** — the ticket 08 privacy-policy draft (docs only; Codex clear, 3 rounds),
**merged into `main`** at the user's go-ahead like tickets 07, 06 (server half) and 05 (mock + server side), all on
2026-10-03; no branch holds unmerged public-beta work. Start new work on a fresh branch off `main`.
`Config/Local.xcconfig` (git-ignored) is present in this checkout (free team).

Plan: **[spec](../work-record/public-beta/spec.md)** (the user's answers Q1–Q14 and Q8b), decision **D60**, tickets
[`work-record/public-beta/issues/01…09`](../work-record/public-beta/issues/). Stacked; optional Apple/Google accounts with
a training profile, workouts stay on the phone; a Cloudflare Worker + D1 server; AI on the user's key through it
(60/10/60 a day, off switch); onboarding; in-app feedback; the user on internal TestFlight first.

| Ticket | State (evidence in each ticket) |
|---|---|
| 01 paid team + TestFlight | Prepare merged (Codex clear, 4 rounds). **Phase A done on the phone 2026-10-02.** B–E wait on Apple's enrollment approval (pending; Xcode shows only the Personal Team). |
| 02 onboarding | **Merged** (`4823d46`; Codex clear, 2 rounds): welcome page + guided tour on an in-memory sample world; Settings → Help → Show Tour. Not on the phone yet (comes with 01's TestFlight build). |
| 03 server + Sign in with Apple | **Server half merged** (`e455222`; Codex clear, 4 rounds; 48/48 tests; secret scan + Server CI green on GitHub). **Not deployed.** App half (capability, account client, Settings Account row, onboarding sign-in) needs the paid team. |
| 04 Google sign-in | Held: needs the user's Google Cloud project/OAuth client (and 03's app half). |
| 07 feedback | **Merged** (`60ebd25`, 2026-10-03; Codex clear, 3 rounds): form + copy approved by the user (captures `captures/07/`), server `POST /v1/feedback` + R2 + limits + deletion queue, app client and form. Not deployed; the row is hidden until `WT_SERVER_URL` is set; signed-in sending waits on 03's app half. |
| 06 AI proxy | **Server half merged** (`d761301`; Codex clear, 4 rounds): `/v1/ai/{scan-machine,routine-week,model-exercises}`, `/v1/ai/usage`, limits, off switch (`scripts/ai.mjs`), counts-only logs. Open: app switch (after 03's app half); before external testers, a deployed CPU check of a max-size scan and an adversarial check (ticket 06 acceptance). |
| 05 profile | **Merged** (`7c70d14`; Codex clear, 3 rounds): mock approved by the user (captures `captures/05/`; Ask AI gets a "Save to my training profile" switch, on by default), server side (`GET/PUT /v1/profile` training, units as entered). Wiring waits on 03's app half. |
| 08 external testers | **Privacy-policy + App Privacy draft** (`work-record/public-beta/privacy-policy-draft.md`) merged, Codex clear (3 rounds), unpublished. Needs the user's legal name, support email, date, age statement, feedback/download/export retention and two App Privacy choices; then the draft's release gates. |
| 09 App Store | Not started. |

**The user's order of 2026-10-03 is complete:** 07 feedback (merged), 06 AI proxy server half (merged), 05 profile
mockups (approved) + server side (merged), 08 privacy-policy draft (Codex clear, unpublished). Each ticket's record
holds its design, evidence and Codex rounds. Conventions kept: one branch per ticket off `main`, Claude implementing,
Codex reviewing to "clear" in a visible Orca terminal, the user's go-ahead before every merge, UI-first for screens.
The user did **not** choose (for now) the pre-existing failures below.

**Deadlines and the phone:** free-team profiles expire **2026-10-09 03:52 EDT** — if Apple has not approved by
Oct 7–8, renew again with the user and the phone, behind Gate S (ticket 01 phase A, DEVELOPMENT → *Container backup and
restore*). Installed: `main` `b83cf39`'s code (home-screen name Stacked), 25 workouts / 355 sets; latest verified backup
`~/WorkoutTracker-Backups/2026-10-02-phase-a/`. Phone facts above (UDID, iOS 27.0).

**Waiting on the user:** Apple's enrollment approval (then ticket 01 B–E; the user approves the delete); a free
Cloudflare account and the first deploy (`server/README.md`); later a Google Cloud OAuth client (04); the Floodlight
visual acceptance on the phone (below).

**Working conventions from this effort:** Codex reviews run in a visible Orca terminal (`orca terminal create … --command
'codex "$(cat <prompt>)"'`), the next round is sent to the same terminal, and a background watcher waits for the report
file and for approval prompts *after* the last "You approved"/"Ran" (old prompts stay in the scrollback). Approve only
narrow commands the prompt invited; **decline desktop control** (`orca computer …`) — it drives the user's screen.
Review prompts and reports live beside the tickets (`work-record/public-beta/codex-review-*`). Before every commit:
`scripts/check-secrets.sh --staged` (the repository is public). Simulators: **WT-Onboarding**
`2CEC4AD8-F702-421F-B3B2-D68C302A3453` (sample data only), **WT-Backup-01** `A3D88C6F-6426-427A-9A0E-CF11A93798B1`
(Gate S round trips; erased — erase after every use, it receives copies of the user's data). This session's scratchpad
evidence is ephemeral; every result is recorded in the tickets.

## Next action

1. **The user's order is done** (07 → 06 server half → 05 mockups + server side, 08 policy draft). What remains needs
   the user or Apple: **Apple's enrollment** (then 01 B–E, 03's app half — which unblocks 05's wiring, 06's app switch,
   signed-in feedback — and 04 with a Google OAuth client); **the first Cloudflare deploy** (`server/README.md`: D1,
   `wrangler r2 bucket create stacked-feedback`, secrets incl. `OPENAI_API_KEY`; then the deployed checks in ticket 06's
   acceptance and the privacy draft's gates); **the privacy-policy decisions** (ticket 08).
2. **FIRST, ask the user (checked 2026-10-10): the free-team profiles expired 2026-10-09 03:52 EDT.** Did Apple
   approve the enrollment, and was the free signing renewed? If neither, the installed app no longer launches on the
   phone until re-signed: renew with the user and the phone per ticket 01 phase A — Gate S backup first; reinstalling
   the same binary does not extend it. Original note: renewal before 2026-10-09 03:52 EDT if Apple has not approved (Gate S,
   ticket 01 phase A).
3. Still waiting on the user from before: visual acceptance of the Floodlight redesign on the phone. Not yet exercised
   anywhere: VoiceOver by a person, Reduce Motion at runtime, real GPS and sensors on the redesigned cardio screens,
   Lock Screen commands on a device, a restore from a backup on a phone, a non-US simulator region.

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
