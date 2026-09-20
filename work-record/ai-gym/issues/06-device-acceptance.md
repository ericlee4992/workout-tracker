# 06 — Private device trial and recognition acceptance

Type: task
Status: ready-for-human — installed and launch-verified; key setup and gym evidence outstanding

Software scope and decisions: [spec](../spec.md), D56–D58. Product `9b0a61a`, delivered on main `0c87a6f`, is installed and remote launch verified.

## Next action

Enter the OpenAI key in the new app’s Settings and perform the physical checks below. The tooling key saved on the Mac is not bundled or automatically provisioned to the phone; API credits were already funded and verified. Profiles expire September 24 at 07:16 UTC. Confirm the updated app's history visually; database preservation is verified below.

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
