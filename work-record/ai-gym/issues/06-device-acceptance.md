# 06 — Private device trial and recognition acceptance

Type: task
Status: ready-for-human — ticket 07 installed and launch-verified; physical acceptance remains

Software scope and decisions: [spec](../spec.md), D56–D58. Product `9f733a2` from source `7e96a82` is installed and remote launch verified September 22.

## Next action

The ticket 07 follow-up was installed and launch-verified September 22. **First check signing
expiry against current time** using STATE; profiles expire today (September 24) and were not
renewed. If expired, follow DEVELOPMENT's backup/signing/rebuild/launch procedure. This handoff
has not reconnected to the phone or renewed anything.

Then collect post-update phone feedback on immediate template visibility, scanning during setup,
preferences/equipment refresh and visual history confirmation, followed by the physical checks
below. None of this post-update feedback has yet been reported. Key/billing setup already works;
do not repeat it. Current phone/build/profile facts live in STATE.

## Installation — September 20, user authorized “can you install”

User confirmed the existing app opens and old workouts are present. Phone reachable/unlocked.
Fresh access-restricted full container backup at
`/Users/ericlee06/WorkoutTracker-Backups/2026-09-20-140830-before-ai`: 24 files,
26,745,283 bytes. Integrity checks passed on separate verification copies of all three SQLite
databases. SHA-256 manifest verified; original backup remains unchanged. No fresh portable
JSON/CSV export or restore test claimed; prior backups retained.

Reused `/tmp/wt-ai-device/Build/Products/Debug-iphoneos/WorkoutTracker.app` after checking
unchanged product source versus independently cleared `9b0a61a`, Terra/routine dylib symbols,
timestamp, app/widget signatures and profile IDs/expiry. Device build exit 0 re-read; full domain
773/773 passed with zero failures/skips re-read from xcresult. Existing targeted verification and
independent clearance apply: installation/docs only, no new code or test run required.

Same bundle `com.ericlee4992.workouttracker` installed successfully (exit 0), installation UUID
`EBE11998-8557-4752-A0DB-018B785BD11B`. Remote launch exit 0; process 9606 observed running
from the new bundle. App/widget profiles expire September 24 at 07:16:18 /07:16:20 UTC.
Actual logs/JSON/exits: main's ignored `work-record/ai-gym/results/device-install-20260920/`.

Copied the phone container again after launch. Store integrity passed; every pre-existing row,
attribute and relationship across all 15 app tables matches the fresh backup, ignoring internal
Z_OPT counters and normalizing Z_ENT numeric tags through entity names. All 23 workouts and
335 sets preserved. Comparison report and private stores remain beside the backup outside Git.
This establishes on-phone migration preservation, not visual acceptance or tested restore.

## Physical acceptance

- Labels and whole strength machines: verify proposed movement, visible brand/model evidence, generic fallback, retake and corrections on actual gym equipment. Two similar machines at a gym must remain distinct physical instances.
- Known limitation: the public g010 frontal whole-machine sample was misclassified across reasoning settings. This is not a recognition-accuracy pass. A printed generic movement title is now prevented from becoming a fabricated precise model even when AI labels it specific.
- Check first-use routine startup selects the sole compatible machine at the generating gym, remembers an existing compatible choice, and does not guess between several.
- Generate/review/edit a real weekly lifting/cardio routine; check available equipment and suitability. No starting weights are generated. Cardio starts only with an explicit tap; plans are not measured activity.
- Verify camera permission/denial, photo library, weak connection, API billing/authorization errors and cancellation on the phone. Simulator flows do not establish physical camera/GPS/HealthKit behavior.
- Existing [cardio physical acceptance](../../cardio/issues/02-device-acceptance.md) remains open separately. Restore testing remains unverified; public backend/App Store work and guides remain deferred.

## Comments

### September 22 — new-session handoff

User requested an updated, clear handoff and explicitly waived Claude review for this docs-only
task. Main and remote both started at `9d84c1d`; installed product remains `9b0a61a` from delivery
`0c87a6f`. No product edits, phone installation, profile renewal or API request in this handoff.

Re-read actual successful install/launch exits and JSON outcomes, prior build/test exit files,
the 15-table preservation report, and all 24 original backup hashes. Private backup unchanged;
prepared app and widget still exist with the September 24 profile expirations. Mac credential
file exists with mode 0600; contents not read. No local xcodebuild/xcresulttool process running.
Documentation checks cover local links, diff whitespace, status consistency and remote tip;
no app tests needed under DEVELOPMENT's docs-only verification scope.

After installation the user asked where to find the key. Provided Finder → Command-Shift-G →
`~/.config/workouttracker` → open `openai.env` in TextEdit → copy the value after
`OPENAI_API_KEY=` into phone Settings. No key entry, phone-side AI success, real gym recognition,
or post-update visual history confirmation has since been reported. Do not infer any of these
from successful Mac API tests or installation. Credits are already funded, not an open setup task.

Next session starts with STATE and this ticket, checks Git, then asks for this device feedback.
If signing has expired, follow DEVELOPMENT renewal and backup instructions. Do not reopen
implementation tickets 01–05 or deferred public launch work without a new request or defect.

### September 22 — first routine trial feedback

User created three AI templates. The first two were absent even after scrolling to the top,
then appeared after restarting. User requests scanning from routine setup, a single AI machine/
label recognition path, and “Ask AI for Templates” entry wording. Authorized implementation in
ticket 07. This reports phone-side AI template generation, not physical scan accuracy, history
visual acceptance or cardio checks.


### September 22 — follow-up delivered, not installed

[Ticket 07](07-template-visibility-and-scanning.md) is verified, independently cleared and merged
on main (delivery **35842a2**, product **9f733a2**). It fixes iOS 27 blank template cards and adds
Scan Machine/gym selection to template setup with the renamed entry. The phone still has the
September 20 build. Next installation requires the usual fresh backup, signing/freshness and
launch checks; post-install feedback remains physical acceptance, not inferred from simulator runs.


### September 22 — follow-up installation (user: “install”)

Clean main/source **7e96a82**, reviewed product **9f733a2**, no product edits or schema change.
Fresh generic-iOS build `/tmp/wt-ai-followup-device-20260922`, actual exit **0 / BUILD SUCCEEDED**.
Verified new binary timestamp, Ask AI for Templates / scanner entry strings, eager-grid private
helper and scanner-auto-entry symbols; app/widget signatures, same bundle IDs, device provisioning
and required permission strings. Existing valid profiles reused; no renewal claimed.

Phone reachable; app not running. Fresh private full-container backup at
`/Users/ericlee06/WorkoutTracker-Backups/2026-09-22-before-ai-followup`: **27 files, 31,286,447
bytes**, access-restricted; SHA-256 manifest verified, three databases integrity `ok` on copies,
no unfinished workout. No new portable export or tested restore claimed.

Installation **exit 0 / success**, new bundle UUID **B3D551F5-560C-46B0-906B-A4B7489D58B9**,
September 22 ~02:50 EDT. First launch exit **0** (PID 17096). A later process check only showed
the widget, so launch was confirmed again: **exit 0**, PID **17112** then observed running from
the newly installed bundle. This verifies launch, not subsequent manual UI acceptance.

After-launch container copy/integrity passed. Comparison of **all 15 app tables** found every
pre-existing row, attribute and relationship unchanged (ignore Z_OPT; normalize Z_ENT via entity
names): **24 workouts, 343 sets, 2 templates** preserved. Original backup hashes remain unchanged.
Private verification copies and full preservation report stay beside the backup outside Git.
Build/install/launch/check logs, JSON and actual exits are in main's ignored
`work-record/ai-gym/results/device-install-20260922/`. Existing reviewed source and passing
verification apply; installation alone requires no new simulator suite under DEVELOPMENT T8.
No live API call or physical scanner/cardio acceptance claimed. Next: user trial feedback.


### September 24 — clean new-session handoff

User requested updated records before a new session and explicitly waived Claude review for this
docs-only handoff. Started from clean main **40f3f65**, live remote matched; handoff branch
`ericlee4992/session-handoff-sep24`. Product/source remain **9f733a2 /7e96a82**, installed September 22.
No product edits, phone connection, signing renewal, installation, API call or fresh test run.

Re-read actual build/install/launch/confirmation/copy exits (all 0), install/launch JSON success,
15-table preservation report, all **27** original backup hashes (unchanged), prepared app/widget
embedded profiles and prior successful xcresult summaries (53 +1 +2 +2 passed, zero failed/skipped).
Clean/final simulator build exits remain 0. Source/test trees match reviewed checkpoints; no local
xcodebuild/xctest/xcresulttool job active. Credential existence/mode checked without reading contents.
Profiles expire at the time in STATE; at the 05:08 UTC audit they had not yet expired. Next session
must evaluate current time, not assume either current launchability or a completed renewal.

Read-only audit of 31 checkouts: no tracked modifications. Untracked reviewer reports remain in
`ai-template-followup-review` (three reports, each byte-identical to the committed main copy),
`review-cardio-design` (two), `review-finish-summary-order` (three) and `review-session-handoff`
(one). These are retained review artifacts, not unfinished product implementation. Older details
remain in the codex-setup handoff record; no workspace or terminal was closed/cleaned.

Archived pre-handoff STATE byte-for-byte from **40f3f65**. Corrected stale current-status wording
in cardio acceptance and deferred work: latest launch and database preservation are verified;
post-update visual acceptance, backup restore and hardware checks remain open. No product decisions
reopened. Docs verification: local links, archive preservation, whitespace, status consistency,
source invariance and remote tip; no app build/test required under DEVELOPMENT's docs-only scope.
