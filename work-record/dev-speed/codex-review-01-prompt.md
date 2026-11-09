# Codex review — dev-speed 01 (testing workflow)

You are the independent reviewer; Claude implemented. Read AGENTS.md first (its testing bullets changed in this
ticket). Checkout `/Users/ericlee06/orca/workspaces/Health App/UI_design`, branch
`ericlee4992/dev-01-testing-workflow` (off `main` `4204fbc`).

Review `git diff 4204fbc..HEAD`. Read first: `work-record/dev-speed/issues/01-testing-workflow.md` (plan, acceptance,
Progress with the measurements, root causes and evidence), then DEVELOPMENT → Verification scope / Tiers and test
plans / Build and test / Simulator and UI-test pitfalls.

Check in particular:
1. **App change — `WorkoutTracker/Domain/RestTimer.swift` `UserNotificationScheduler`:** notification-center calls
   moved to one private serial queue. Is the diagnosis right (the two spindumps: main thread in
   `removePendingNotificationRequests` under `CardioSession.start` → `RestTimerService.skip`)? Does the queue keep
   every remove/add in call order across `schedule` / `cancel` (rest start, +15 s, skip, finish, cancel paths)? Any
   caller that relied on `cancel()` having completed synchronously (e.g. a check of pending requests right after)?
   Thread-safety of `UNUserNotificationCenter` from a background queue; Swift 5 / existing concurrency style; the
   latent race the ticket claims it closes. The reproduction is in the ticket (daemon paused: old build fails at
   `CardioUITests.swift:58`, new build passes) — repeat it if you can (find the device's `usernotificationsd` under its
   `launchd_sim`, `kill -STOP`, run the test, **always `kill -CONT` after**).
2. **The 85 polling loops** (`WorkoutTrackerUITests/*`): `for _ in 0..<N where C { body }` →
   `for _ in 0..<N { guard C else { break }; body }`. Confirm the rewrite is semantics-preserving apart from stopping
   at the first success: same bound, same body, no condition with side effects, the assertion after each loop kept,
   multi-line conditions intact. Is any assertion weakened or any coverage lost?
3. **Test plans** (`TestPlans/*.xctestplan`, the scheme's `<TestPlans>`, `scripts/test-plans.py`): every UI class in
   exactly one area plan; Full (default) still runs both targets; `-only-testing` in CI (`.github/workflows/tests.yml`)
   and `scripts/container-tools/simulator_export.sh` (with `TEST_RUNNER_WT_BACKUP_EXPORT`) still select the same
   tests; `codeCoverage: false` harms nothing; `--check` catches an unmapped class.
4. **`AAAWarmUpUITests`**: launch-only, runs first; does XCTest's class order make that true for serial and parallel
   runs?
5. **Scripts:** `scripts/prepare-test-simulator.sh` (the keyboard preference diagnosis: clones copy
   `HardwareKeyboardLastSeen` / `AutomaticMinimizationEnabled`), `scripts/explore.sh` (bundle lookup, permissions,
   `-appearance`, `set -euo pipefail` with empty arrays), `scripts/test-progress.sh` (Swift Testing and serial XCTest
   lines).
6. **Docs:** DEVELOPMENT and AGENTS rules — consistent with each other and with STATE; the reviewer-rerun rule; the
   reporting block; no stale warm-up instruction left in DEVELOPMENT/AGENTS (STATE is updated at the handoff).

Run on **WT-iPhone27** `47D21838-69A6-4BCB-AE90-B0D9C0AAA70B` (Claude uses WT-Floodlight), paths under
`/tmp/codex-dev01/`: first `scripts/prepare-test-simulator.sh 47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`; `build-for-testing`;
`python3 scripts/test-plans.py --check`; the **Unit** plan (`-testPlan Unit`); UI serially
(`-parallel-testing-enabled NO`): `WorkoutTrackerUITests/AAAWarmUpUITests`, `WorkoutTrackerUITests/CardioUITests`,
`WorkoutTrackerUITests/FloodlightAIRoutineUITests/testGoalsNumberPadsHaveAppDone`. Read Claude's xcresults for the
rest (session scratchpad `/private/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-UI-design/b075476f-cb86-4797-a96b-088b73936c7a/scratchpad/m/`:
`unit-full`, `unit-plan`, `ui-cardio`, `ui-cardio2`, `par1`, `par2`, `stop-old`, `stop-fixed`). Show progress in the
existing Orca tab "Test progress (Claude r2)" `term_ac1339dc-202d-4c10-bab3-b528de726cbd` once it is back at its
prompt (`bash scripts/test-progress.sh <log> <count> "<title>"`) — do not open a new terminal. Do not modify files
other than the report; do not commit or push.

Write `work-record/dev-speed/codex-review-01.md`: findings P1/P2/P3 with file:line, failure scenario and fix; end
with exactly `Verdict: clear` or `Verdict: not clear`.
