#!/bin/bash
# Rejects key-shaped strings before they reach this PUBLIC repository (public beta ticket 03).
#   scripts/check-secrets.sh --staged   the staged changes (the pre-commit hook)
#   scripts/check-secrets.sh --all      every tracked file (CI)
# Patterns: PEM private keys with content, OpenAI / Anthropic / Cloudflare / AWS / GitHub / Google style keys, and
# a filled-in .dev.vars value. A match prints the file and line and exits 1; there is no allowlist — remove the secret.
set -euo pipefail
mode="${1:---staged}"
patterns=(
  '-----BEGIN [A-Z ]*PRIVATE KEY-----[[:space:]]*$'
  '(^|[^A-Za-z0-9_-])sk-[A-Za-z0-9_-]{20,}'
  '(^|[^A-Za-z0-9_-])sk-ant-[A-Za-z0-9_-]{20,}'
  '(^|[^A-Za-z0-9])AKIA[0-9A-Z]{16}'
  '(^|[^A-Za-z0-9])gh[pousr]_[A-Za-z0-9]{30,}'
  '(^|[^A-Za-z0-9])AIza[0-9A-Za-z_-]{35}'
  '(APPLE_PRIVATE_KEY|TOKEN_ENC_KEY|APPLE_KEY_ID|CLOUDFLARE_API_TOKEN|OPENAI_API_KEY)=[^[:space:]]{8,}'
)
joined=$(IFS='|'; echo "${patterns[*]}")
case "$mode" in
  --staged)
    hits=$(git diff --cached -U0 --no-color | grep -E '^\+[^+]' | grep -En -e "$joined" || true) ;;
  --all)
    hits=$(git ls-files -z | xargs -0 grep -EnI -e "$joined" -- 2>/dev/null || true) ;;
  *) echo "usage: $0 --staged|--all" >&2; exit 2 ;;
esac
if [[ -n "$hits" ]]; then
  echo "Possible secret — refusing (this repository is public):" >&2
  echo "$hits" | cut -c1-160 >&2
  exit 1
fi
echo "check-secrets: clean ($mode)"
