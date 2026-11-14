Review, same checkout, branch ericlee4992/release-script-agents (off main 1ba3d93c). Review `git diff 1ba3d93c..HEAD`.
Claude implemented it from the user's request (2026-11-14): take the useful parts of a Claude Code usage report —
(1) make TestFlight upload not depend on a hand-written file in /tmp, (2) a self-check list before Codex reviews,
(3) keep STATE's top current — and make AGENTS.md correct and up to date, with no wrong or unnecessary statements.

Check:
1. scripts/testflight.sh (bash): correctness and safety under `set -euo pipefail`; the archive checks (clean tree,
   one MARKETING_VERSION/CURRENT_PROJECT_VERSION across targets, app + widget versions, production https
   WTServerURL, WTGoogleClientID, signing team vs Config/Local.xcconfig); the upload (export options generated in a
   temp dir from WT_DEVELOPMENT_TEAM, plutil lint, exit 2 on "Failed to Use Accounts", success only on "Upload
   succeeded"); the team ID never written into the repo. Claude ran `archive` for real in release-build (ARCHIVE OK
   for 0.2.0 (14), then deleted) and tested `upload` with a stand-in for xcodebuild (success → 0, signed-out → 2,
   other failure → 1; the generated plist equals build 14's working one). Do NOT upload or archive yourself; you may
   run the script's argument/usage paths and shellcheck if installed, and read the 0.2.0-build-13/14 records.
2. docs/DEVELOPMENT.md TestFlight checklist steps 3–5 and the CI note: accurate to practice and to the script?
3. AGENTS.md: every statement true against the repo, DECISIONS (T6, D23, D52, D67), DEVELOPMENT, the tools-paseo file,
   the models' delete rules (Domain/Models.swift, Domain/Nutrition.swift), CI history (`gh run list --workflow
   tests.yml`), and links. Anything still wrong, contradictory, stale or unnecessary? Is the self-check list grounded
   in this repo's past Codex findings (work-record/**/codex-review*.md) and not generic filler? Leave the generated
   `<!-- graft:start -->` block alone unless it is wrong.
4. docs/STATE.md top rewrite: true, current, every unresolved item from the old RESUME HERE kept (the old block is
   preserved verbatim under History).

Rules: modify nothing except the report; no phone, Apple account, uploads or deploys. Write the report to
work-record/release/codex-review-release-script.md: numbered findings with severity (P0 … P3), file:line, the failure
scenario and a fix; what you ran; then a last line exactly "Verdict: clear" or "Verdict: not clear".
