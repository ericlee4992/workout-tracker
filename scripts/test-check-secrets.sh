#!/bin/bash
# Regression test for scripts/check-secrets.sh (codex-review-03 #6–#8). Every synthetic secret is assembled at run
# time from pieces, so this file itself never looks like a secret to the scanner.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
cd "$tmp" && git init -q && git config user.email t@t && git config user.name t
cp "$here/check-secrets.sh" ./check.sh
printf 'seed\n' > seed && git add seed && git commit -qm seed
sk="sk""-proj-""$(printf 'a%.0s' {1..30})"
b64="MIGHAgEAMBMGByqGSM49AgEGCCqGSM49""AwEHBG0wawIBAQQg"
pem="-----BEGIN ""PRIVATE KEY-----"
fail=0
expect() {  # name, expected exit, file content
  local name="$1" want="$2" content="$3"
  printf '%s\n' "$content" > case.txt && git add case.txt
  local out; out=$(./check.sh --staged 2>&1); local got=$?
  git rm -q --cached case.txt && rm case.txt
  local leaked=0; [[ "$content" == *"$sk"* && "$out" == *"$sk"* ]] && leaked=1
  if [[ $got -ne $want || $leaked -ne 0 ]]; then echo "FAIL $name (exit $got, want $want, leaked $leaked)"; fail=1; else echo "ok   $name"; fi
}
expect "openai key"                1 "key = \"$sk\""
expect "plus-prefixed line"        1 "+\"$sk\""
expect "PEM on its own line"       1 "$pem"
expect "PEM escaped in a string"   1 "\"$pem\\n$b64\""
expect "PEM escaped with CRLF"     1 "{\"APPLE""_PRIVATE_KEY\": \"$pem\\r\\n$b64\\r\\n\"}"
expect "named secret, JSON"        1 "{\"TOKEN""_ENC_KEY\": \"$(printf 'Q%.0s' {1..44})\"}"
expect "named secret, spaced ="    1 "TOKEN""_ENC_KEY = $(printf 'Q%.0s' {1..44})"
expect "named secret, .dev.vars"   1 "OPENAI""_API_KEY=$sk"
expect "CSS mask-image name"       0 ".mask-image-linear-from-position-and-more { }"
expect "code, not a value"         0 "TOKEN""_ENC_KEY: btoa(String.fromCharCode(1))"
expect "empty .dev.vars example"   0 "TOKEN""_ENC_KEY="
expect "PEM regex in source"       0 "replace(/-----(BEGIN|END) PRIVATE KEY-----/g, \"\")"
# A staged file whose name looks like pathspec magic is still scanned (codex-review-03b #6).
printf 'x = "%s"\n' "$sk" > ':(glob)abc.txt' && git --literal-pathspecs add -- ':(glob)abc.txt'
out=$(./check.sh --staged 2>&1); got=$?
git --literal-pathspecs rm -q --cached -- ':(glob)abc.txt' && rm -- ':(glob)abc.txt'
if [[ $got -eq 1 && "$out" != *"$sk"* ]]; then echo "ok   pathspec-magic file name"; else echo "FAIL pathspec-magic file name ($got)"; fail=1; fi
# --all mode on a committed secret, and no leak in its output.
printf 'x = "%s"\n' "$sk" > committed.txt && git add committed.txt && git commit -qm c
out=$(./check.sh --all 2>&1); got=$?
if [[ $got -eq 1 && "$out" != *"$sk"* && "$out" == *"committed.txt:1"* ]]; then echo "ok   --all finds it without printing it"; else echo "FAIL --all ($got)"; fail=1; fi
exit $fail
