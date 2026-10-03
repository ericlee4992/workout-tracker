You are the independent reviewer (AGENTS.md T6) for the public-beta ticket 08 PRIVACY-POLICY DRAFT (not published;
the user still fills in placeholders and approves the wording). Claude wrote it. Repository:
/Users/ericlee06/orca/workspaces/Health App/public-beta, branch ericlee4992/beta-08-privacy-draft. Read
work-record/public-beta/privacy-policy-draft.md, work-record/public-beta/issues/08-external-testers.md, spec.md →
Accounts, AI through the server, Feedback, Testers and distribution; D60.

Check every factual statement in the policy and the App Privacy table against the code and the server on this branch
(main 7c70d14): what the app stores on the phone and sends anywhere (WorkoutTracker/, Config/ Info.plist strings,
HealthKit, location/motion, camera/photos, export), what the server stores and for how long (server/migrations,
server/src: accounts, identities, sessions, training_profiles, feedback + R2 + feedback_limits, ai_usage, ai_requests,
pending_revocations, prune/sweep timings), what goes to OpenAI and on what consent (the current app sends directly
with a device key until ticket 06's app switch — is the draft honest about which parts are "after ticket NN"?),
deletion coverage, and Apple's App Privacy categories (collected = leaves the device; linked; tracking). Flag
anything false, missing, overstated or understated, and any placeholder or open item that must be resolved before
publishing. You may not edit files other than the report.

Rules: no network calls to Cloudflare, OpenAI or Apple APIs (reading public documentation is fine), no wrangler
commands, no phone, Apple account or ~/WorkoutTracker-Backups access, no desktop control (`orca computer`). Write the
report to work-record/public-beta/codex-review-08.md: numbered findings with severity (P0 … P3), the policy line and
the code location, and a suggested correction; then a last line that is exactly "Verdict: clear" or
"Verdict: not clear".
