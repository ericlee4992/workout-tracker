# Current project state

Updated **2026-10-14** (04 in review round 2; 06 and 05 merged; 10 closed; TestFlight build 3 uploaded; build 2 on the phone). The previous STATE (Floodlight delivery, the Oct 10–11 free re-sign, the Oct 3 public-beta handoff) is
archived byte-for-byte: [STATE before TestFlight](archive/STATE-2026-10-13-before-testflight.md). Verify Git on resume.

## NOW: ticket 04 Google sign-in — Codex round-1 findings fixed; round 2 running; Google Cloud setup next

- **`main` = `1be0768`** (pushed): 06 and 05 merged (Codex clear), 10 closed without change. **TestFlight 0.1.0 (3)
  from `1be0768` uploaded 11:59 EDT** — the user adds it to "Developer" and installs; then the phone checks in tickets 06
  (each AI flow once) and 05 (Ask AI filled in; a changed day count saved).
- **Branch `ericlee4992/beta-04-google`** (pushed): server `POST /v1/auth/google`, app wiring without the SDK (PKCE iOS
  client), the approved "Sign in with Google" button. Codex round 1 (`codex-review-04.md`) was **not clear (5
  findings); all fixed** (`f879314`, `ef9372c`, `27dbf45`; details in the ticket). Server 221/221; unit Google +
  Account 32/32; UI FloodlightGoogle + FloodlightAccount 8/8; captures 4/4.
- **Waiting on the user:** OK for the button's label in Google Sans Medium with Google's iOS spacing (a look change from
  the approved mock, made for Codex's branding finding; before/after shown 2026-10-14); then the **Google Cloud setup**
  (steps in the ticket) for the client ID.
- **Running:** Codex round 2 — Orca terminal "Review 04 round 2" (`term_67e73784-…`), prompt
  `work-record/public-beta/codex-review-04b-prompt.md`, report `codex-review-04b.md` (watch for its `Verdict:` line).
- **Next:** round 2 to "clear"; Google Cloud setup (Chrome-guided); client ID in `Config/Shared.xcconfig` +
  `server/wrangler.jsonc`; server redeploy (go-ahead); Simulator sign-in/out/delete; merge (go-ahead); then 11.
- **Workers Free:** scans use 15–45 ms CPU vs 10 ms (all succeeded); revisit before 08 (the user's call).
- **Server:** https://stacked-server.stacked-server.workers.dev (version `6450e294` seen in the logs on 2026-10-14).
  Secrets set by the user: APPLE_KEY_ID, APPLE_PRIVATE_KEY, TOKEN_ENC_KEY, OPENAI_API_KEY; `APPLE_TEAM_ID`
  `X68M8SR6NA` in `server/wrangler.jsonc`. The Sign in with Apple `.p8` is at `~/WorkoutTracker-Backups/keys/Auth.p8`
  (0600, never committed). Feedback: `node scripts/feedback.mjs list|show`. Cloudflare blocks Python's default
  user agent (error 1010) — send a curl-like `User-Agent` from scripts.

## Agreed order to external testers (the user, 2026-10-13)

1. **06 app half** — AI through the server: remove the OpenAI key screen, sign-in required for AI, daily limits;
   then the deployed max-size-scan CPU check and the adversarial check. *(Merged 2026-10-14; phone smoke with build 3.)* [ticket](../work-record/public-beta/issues/06-ai-proxy.md)
2. **10** — GPT-6.1 Sol. *Closed 2026-10-14 without change: not cheaper per request, slower; the user kept Terra.* [ticket](../work-record/public-beta/issues/10-model-sol.md)
3. **05 rest** — Ask AI prefill + "Save to my training profile". *Merged; build 3 uploaded 2026-10-14.* [ticket](../work-record/public-beta/issues/05-profile.md)
4. **04** — Google sign-in; the user creates the Google Cloud project/iOS OAuth client first (Claude guides in Chrome).
5. **11** — automatic safety copy of each tester's data before a store-changing update → **build 4**.
   Design questions are in the [ticket](../work-record/public-beta/issues/11-safety-copy.md).
6. **08** — external testers: privacy policy at `/privacy` and `/support`, App Privacy answers, external group, beta
   description, feedback email, Beta App Review, invites. **The user still owes:** legal name, support email,
   effective date, feedback retention (suggested 1 year), age statement (suggested "not for under 13"). Server
   hygiene: verify AI limits in production, rehearse the off switch, write down the D1 backup procedure. A
   release-candidate test pass.

## The phone

- iPhone 15 Pro Max, iOS 27.0, UDID `00008130-001E10C01E62001C`, bundle `com.ericlee4992.workouttracker`.
- **Uploaded, not yet installed: 0.1.0 (3) = `main` `1be0768`** (2026-10-14).
- **Installed: TestFlight Stacked 0.1.0 (2) = `main` `5836b68`** (uploaded 2026-10-13 23:17 EDT, in place over build 1;
  Automatic Updates **off**). No Gate S before it — no store change in `936b18f..5836b68` (the backup rule below).
  The user verified real Apple sign-in and signed-in feedback ("I confirm 03 works"); account deletion/Apple
  revocation was not separately itemised. Still uses the on-device OpenAI key for AI until 06's app half ships.
- **Builds:** bump the build number (next **4**; 10 occurrences in `project.pbxproj`), archive from a recorded `main`
  commit in `/tmp/wt-live02` (holds the paid-team `Config/Local.xcconfig`; `git checkout --detach <commit>` there),
  upload, add to internal group "Developer" by hand, the user installs from TestFlight. Auto-updates stay off.
- **Backups (the user, 2026-10-13: "yes skip the backup"):** Gate S only when an update changes what the phone stores
  — [DEVELOPMENT → When a backup is required](DEVELOPMENT.md). Otherwise check the diff against the installed commit
  and record it in the ticket. A direct USB copy of the TestFlight container worked once (2026-10-13); re-check before
  relying on it.
- **Latest backup:** `~/WorkoutTracker-Backups/2026-10-13-testflight/` (31 workouts, 411 sets; round trip exit 0).
  Captures need USB; the app stays closed; a failed process query proves nothing. Erase WT-Backup-01 after every use.
- Known: a long workout title truncates beside Cancel. Open: the minimized Live Activity's heart rate gets no
  recurring update (01b R3-P1); the home-screen widget was not checked on the TestFlight build.

## Tickets

| Ticket | State (evidence in each ticket) |
|---|---|
| 01 paid team + TestFlight | **Done** (App Store Connect "Stacked: Gym Log", Apple ID `6822152192`; group "Developer"). |
| 01b background mode | **Done**, merged. |
| 02 onboarding | **Done**, merged; on the phone. |
| 03 server + Sign in with Apple | **Done 2026-10-13**: deployed; app half Codex clear (round 3); build 2 verified by the user. |
| 04 Google sign-in | **Code done** (server + app; mock approved); review and the user's Google client ID pending. |
| 05 profile | **Done in code** (merged `1be0768`, Codex clear); phone check with build 3. |
| 06 AI proxy | **Merged**; deployed checks done; build 3 uploaded — phone smoke next. |
| 07 feedback | **Done**; live since build 2. |
| 08 external testers | Privacy draft merged, unpublished; waits on the user's answers (6th). |
| 09 App Store | Not started. |
| 10 model Sol | **Closed, no change** (the user kept Terra after measurements). |
| 11 safety copy | Ready (5th); design questions first. |

## Working conventions (in force)

One branch per ticket off `main`; Claude implements, Codex reviews to "clear" in a visible Orca terminal
(`orca terminal create --worktree current --title … --command 'codex "$(cat <prompt>)"'`; watch the report file for the
`Verdict:` line, not Orca's idle state). The user's go-ahead before every merge (`git merge --ff-only`, push, confirm
the remote). `scripts/check-secrets.sh --staged` before every commit (public repo). Secrets are typed or piped by the
user locally, never in chat or the repo; never ask for the OpenAI key. Decline desktop control (`orca computer …`); the
user accepts legal terms and Claude never enters credentials. Multi-class UI runs use
`-parallel-testing-enabled YES -parallel-testing-worker-count 3`; unit tests serial; every run gets unique
log/status/result paths; read the results before recording them. Show screenshots in Preview and by file. At each
ticket's end: update STATE and the ticket and give the user a resume prompt.

Simulators: **WT-Floodlight** `9E822EF6-DC67-4958-AEA2-D53D2D36D674` (iOS 27; targeted runs), **WT-Onboarding**
`2CEC4AD8-F702-421F-B3B2-D68C302A3453` (sample data only), **WT-Backup-01** `A3D88C6F-6426-427A-9A0E-CF11A93798B1`
(Gate S round trips; erase after every use).

## Still waiting on the user / not yet exercised

- Visual acceptance of the Floodlight redesign on the phone. Not exercised anywhere: VoiceOver by a person, Reduce
  Motion at runtime, real GPS and sensors on the redesigned cardio screens, Lock Screen commands on a device, a restore
  from a backup on a phone, a non-US simulator region.
- Scratch to remove when no longer needed (ask first): `/tmp/wt-resign` (detached `b83cf39`); `/tmp/wt-live02` is the
  archive checkout — keep it. The Codex terminal "Review 03 app half" can be closed.

## Found 2026-10-02 (pre-existing, not caused by the public-beta work)

- **iOS CI ("Tests" workflow) fails on every `main` run since the Floodlight merge `4765b76` (2026-09-29):** the build
  stops compiling `WorkoutTracker/Features/ActiveWorkout/LiveSetRow.swift` on the `macos-26` runner (Xcode 26); the same
  code builds and tests locally on Xcode 27. A runner-image/SDK mismatch to look at with the deferred hosted-CI work.
  The new "Server" workflow (secret scan + server tests, Linux) passed on `e455222`.
- **`AskAIUITests.testEditingGeneratedWeekKeepsRowsAndSavesOnlyOnce` fails on `main`** (found 2026-10-14 in ticket 06's
  runs; fails identically on `0998e40`, 2 of 2): the reorder drag does not move the exercise ("the dragged exercise
  leads the session"). Same follow-up ticket as below.
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
