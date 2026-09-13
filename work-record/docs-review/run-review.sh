#!/bin/bash
REPO="/Users/ericlee06/orca/projects/Health App"
cd "$REPO" || exit 1
BRIEF="$REPO/work-record/docs-review/brief.md"
OUT="$REPO/work-record/docs-review/codex-review.md"
if [ ! -s "$BRIEF" ]; then echo "FATAL: brief missing or empty at $BRIEF"; exit 1; fi
echo "Codex cross-review of docs commits 0cdcd19 + 43ee775 — started $(date '+%Y-%m-%d %H:%M')"
echo "Brief: $BRIEF ($(wc -l < "$BRIEF") lines)"
echo
codex exec --sandbox read-only "$(cat "$BRIEF")" 2>&1 | tee "$OUT"
RC=${PIPESTATUS[0]}
echo
if [ "$(wc -c < "$OUT")" -lt 500 ]; then echo "!!! SUSPICIOUS: review output under 500 bytes — treat as FAILED"; fi
echo "=== Codex review finished — exit $RC — $(date '+%H:%M') ==="
