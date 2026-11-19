Round 2 of your review of agent-skills 03 (same rules as work-record/agent-skills/codex-review-03-prompt.md). Your
round-1 report: work-record/agent-skills/codex-review-03.md. The fixes: `git diff 440b6cc9..HEAD` — `scripts/sim-ui.sh`
now trusts only a daemon it started itself (marker with pid + version; the opt-out read from the process's own
environment; any other daemon stopped and replaced), DEVELOPMENT and the ticket name the temporary files and exclude the
device tools, and the trial runner is kept as work-record/agent-skills/03-trial-flow.sh. The ticket's "Codex round 1"
section lists the five daemon cases Claude ran live and the flow rerun.

Check that the wrapper closes the reused-daemon path (including races and failure branches: status unreadable, stop
fails, a pid reused by another process), that it keeps element refs between calls, and that the docs match. You may
run `bash -n`, `scripts/sim-ui.sh --version`, and `scripts/sim-ui.sh daemon status`; do not drive the simulator.
Write work-record/agent-skills/codex-review-03b.md ending with exactly "Verdict: clear" or "Verdict: not clear".
