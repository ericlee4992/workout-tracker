#!/bin/bash
# Rejects key-shaped text before it reaches this PUBLIC repository (public beta ticket 03; codex-review-03 #6–#8).
#   scripts/check-secrets.sh --staged   the staged version of every staged file (the pre-commit hook)
#   scripts/check-secrets.sh --all      every tracked file (CI)
# A match prints FILE:LINE and the detector's name — never the matched text (CI logs are public) — and exits 1.
# There is no allowlist: remove the secret. Regression test: scripts/test-check-secrets.sh.
set -euo pipefail
mode="${1:---staged}"
detectors=(
  "private-key|-----BEGIN [A-Z ]*PRIVATE KEY-----([[:space:]]*\$|(\\\\r)?\\\\n[A-Za-z0-9+/=]{16,}|[[:space:]]*[A-Za-z0-9+/=]{40,})"
  "sk-api-key|(^|[^A-Za-z0-9_-])sk-[A-Za-z0-9_-]{20,}"
  "aws-key|(^|[^A-Za-z0-9])AKIA[0-9A-Z]{16}"
  "github-token|(^|[^A-Za-z0-9])gh[pousr]_[A-Za-z0-9]{30,}"
  "google-key|(^|[^A-Za-z0-9])AIza[0-9A-Za-z_-]{35}"
  "named-secret|(APPLE_PRIVATE_KEY|TOKEN_ENC_KEY|APPLE_KEY_ID|CLOUDFLARE_API_TOKEN|OPENAI_API_KEY)[\"']?[[:space:]]*[:=][[:space:]]*[\"']?[A-Za-z0-9+/_=-]{16,}"
)
found=0
# One `git grep` per detector over every file at once. `--cached` reads the staged (index) version of each file, so
# the pre-commit check sees exactly what will be committed — whole files, no diff parsing (codex-review-03 #7).
scan() {  # args: extra git-grep options and pathspecs
  local entry name regex hit out rc
  for entry in "${detectors[@]}"; do
    name="${entry%%|*}"; regex="${entry#*|}"
    # Literal pathspecs: a staged file named like ":(glob)x" is that file, not a pattern (codex-review-03b #6).
    if out=$(git --literal-pathspecs grep -nIE -e "$regex" "$@" 2>/dev/null); then rc=0; else rc=$?; fi
    if [[ $rc -gt 1 ]]; then echo "check-secrets: git grep failed ($rc) — refusing rather than reporting clean" >&2; exit 2; fi
    while IFS= read -r hit; do
      [[ -n "$hit" ]] || continue
      echo "  ${hit}  [$name]" >&2   # FILE:LINE only — the matched text is never printed (codex-review-03 #8)
      found=1
    done < <(printf '%s\n' "$out" | cut -d: -f1,2)
  done
}

case "$mode" in
  --staged)
    staged=()
    while IFS= read -r -d '' file; do staged+=("$file"); done < <(git diff --cached --name-only --diff-filter=ACMR -z)
    [[ ${#staged[@]} -gt 0 ]] && scan --cached -- "${staged[@]}" ;;
  --all)
    scan ;;
  *) echo "usage: $0 --staged|--all" >&2; exit 2 ;;
esac
if [[ $found -ne 0 ]]; then
  echo "Possible secret above — refusing (this repository is public). The matched text is not shown." >&2
  exit 1
fi
echo "check-secrets: clean ($mode)"
