# 06 — Private device trial and recognition acceptance

Type: task
Status: open — device feedback received; ticket 07 addresses template visibility and setup flow

Software scope and decisions: [spec](../spec.md), D56–D58. Product `9b0a61a`, delivered on main `0c87a6f`, is installed and remote launch verified.

## Next action

User reports AI template creation on the phone on September 22. Address the missing-template display and setup-flow feedback in [ticket 07](07-template-visibility-and-scanning.md), then collect the remaining physical checks and post-update visual history confirmation. The tooling key saved on the Mac is not bundled or automatically provisioned to the phone; API credits were already funded and verified. Profiles expire September 24 at 03:16 EDT /07:16 UTC. Database preservation is verified below.

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
