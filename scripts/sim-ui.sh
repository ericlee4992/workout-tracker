#!/bin/bash
# Simulator screen control for agents (agent-skills 03): MobileBuildMCP's CLI, pinned, with its Sentry telemetry off.
# usage: scripts/sim-ui.sh <mobilebuildmcp arguments…>   e.g. scripts/sim-ui.sh ui-automation --help
# Builds and tests stay DEVELOPMENT's xcodebuild procedures; use this only to look at and drive the simulator's screen.
set -euo pipefail
expected=2.7.1
export MOBILEBUILDMCP_SENTRY_DISABLED=true
command -v mobilebuildmcp >/dev/null || { echo "mobilebuildmcp missing: npm install -g mobilebuildmcp@$expected" >&2; exit 3; }
actual=$(mobilebuildmcp --version 2>/dev/null)
[ "$actual" = "$expected" ] || { echo "mobilebuildmcp $actual, expected $expected (the pinned version)" >&2; exit 3; }
exec mobilebuildmcp "$@"
