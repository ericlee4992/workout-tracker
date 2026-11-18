---
name: testflight-release
description: Build and upload a TestFlight release of Stacked — when the user says to release, ship or upload a build — from their choices through the reviewed release branch, the archive, the upload and their App Store Connect steps.
---

# TestFlight release

Every upload, in order. Whether to release, the version, What's New and the What to Test note are the user's
decisions (AGENTS.md); everything else here is yours. The last release record —
the highest-numbered `work-record/release/<version>-build-<build>.md` — is the template and says which commit the
last build came from.

## 1. The user's choices

Ask in one go: the **version and build** (build = the last + 1; the version stays unless they say otherwise), whether
the build gets an in-app **What's New** (D62: a big new feature or change gets one, small fixes and features the note
only — offer your call, and ask when unsure), and the **What to Test** note. Draft the note from the tickets since the
last build: plain words ("Build N adds…", "Fixed…"), then what to try, ending "Send anything odd from Profile → Send
Feedback." The user may edit it.

Done when: the user has answered all three.

## 2. Ready check

- Every ticket since the last build is merged into `main` with a clear Codex verdict.
- **Contents:** `git diff --stat <last build's commit>..origin/main -- WorkoutTracker WorkoutTrackerWidget
  WorkoutTrackerWatch Config server` — every app change belongs to a listed ticket.
- **Stored format:** did `StoreFormatGuardTests.approvedFingerprint` change since the last build, or anything that
  rewrites stored rows or preferences on first launch? Then **Gate S** on the user's phone before it installs this
  build (DEVELOPMENT → *Container backup and restore*); otherwise "no Gate S" and why.
- **Server:** a change under `server/` is deployed before the upload (`server/README.md`); otherwise "no server change".

Done when: contents, Gate S and server each have an answer backed by the diff.

## 3. Branch and numbers

Branch `ericlee4992/release-<version>-<build>` off `origin/main`. Raise `CURRENT_PROJECT_VERSION` at **every**
occurrence in `WorkoutTracker.xcodeproj/project.pbxproj` (and `MARKETING_VERSION` when the version changes).
`grep -E "CURRENT_PROJECT_VERSION|MARKETING_VERSION" WorkoutTracker.xcodeproj/project.pbxproj | sort | uniq -c` shows
one value of each across all targets.

With a What's New: append a `WhatsNewEntry` to `WhatsNew.entries` (`WorkoutTracker/Domain/WhatsNew.swift`) with
**this build's number** and the user's approved title and lines. It shows once to people updating to this build or
later — not on a fresh install, not over a workout in progress — and stays in Settings → What's New.

Done when: the uniq count shows a single build and version.

## 4. Verify

`scripts/prepare-test-simulator.sh`, then the Unit plan (`-testPlan Unit`); with a What's New also
`FloodlightWhatsNewUITests` (`-uiTestWhatsNew`) and its captures.

Done when: exit 0 with counts from the xcresult.

## 5. Release record

`work-record/release/<version>-build-<build>.md`, in the last record's shape: the user's choices, Contents (each ticket
linked), the Gate S and server statements, What's New, the What to Test note **verbatim**, the Evidence block, and a
*Build and upload* section to fill in. Commit and push the branch.

Done when: the record is pushed.

## 6. Release review

One round of the `review-round` skill on the release branch. The brief asks the reviewer to check: the build number in
every target and setting, app and widget agreeing; the record against the diff since the last build; the Gate S and
server statements; a note that says nothing the code doesn't do; nothing else in the build that rewrites the store.
The reviewer builds and runs the Unit plan.

Done when: `Verdict: clear`, written into the record's *Build and upload*.

## 7. Merge

`main` is checked out in the home checkout (`~/orca/projects/Health App`), so fast-forward it there: `git fetch`,
`git merge --ff-only origin/<release branch>`, `git push origin main`.

Done when: `git ls-remote origin refs/heads/main` prints the release branch's tip.

## 8. Archive

In the detached archive checkout `~/orca/workspaces/Health App/release-build` (clean, with `Config/Local.xcconfig`):
`git checkout --detach origin/main`, then `scripts/testflight.sh archive` (output under
`/tmp/stacked-release-<version>-<build>/`). It refuses a dirty checkout or targets that disagree, and checks the
archive: the widget embedded as `<app id>.widget`; app and widget version and build; `WTServerURL` exactly the
production server in `Config/Shared.xcconfig`; `WTGoogleClientID` present; signed by the team in `Local.xcconfig`.
`scripts/testflight.sh check <archive>` reruns the checks.

Done when: the script prints `ARCHIVE OK` and the archive path.

## 9. Upload

In the same checkout: `scripts/testflight.sh upload <the .xcarchive>`. **Exit 2** means Xcode is not signed in to App
Store Connect: the user signs in at Xcode → Settings → Accounts (an agent cannot enter the password or code), then
rerun the upload on the same archive.

Done when: `UPLOAD OK`, with the time.

## 10. Record and hand over

Add the archive and upload lines and the user's next steps to the record; rewrite STATE's top (the *Updated* line and
the first RESUME HERE bullet: the build, the time, Gate S or not). Commit, push and fast-forward `main` again, then
watch GitHub Tests on `main` (`gh run list --workflow tests.yml --branch main`).

Tell the user, in plain words:

1. Apple processes the build in 10–30 min.
2. **Developer** (internal) → Builds → + → the build → Add (no review). With Gate S, the backup comes **before** the
   install: keep the build out of Developer, or turn off Automatic Updates for Stacked in TestFlight, until it is done.
3. **Friends** (external) → Builds → + → the build → Next → paste the What to Test note → Submit for Review.

Neither group adds new builds automatically. You may select and fill in App Store Connect; the user clicks Add and
Submit.

Done when: the record, STATE and `main` show the upload, and the user has their steps.
