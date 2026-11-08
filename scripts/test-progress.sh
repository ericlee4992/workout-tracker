#!/bin/bash
# Live progress of an xcodebuild test run, for a visible Orca terminal tab.
# usage: scripts/test-progress.sh <xcodebuild log> <expected test count> [title]
# Counts the log's "Test case '…' passed/failed" lines every 5 s; exits when the run prints its
# final "** TEST … **" line. The expected count is an estimate (the selected classes' `func test`
# count); parameterised tests may make the real total a little larger.
log=$1; total=${2:-0}; title=${3:-Tests}
start=$(date +%s)
while true; do
  passed=$(grep -cE "^Test case '.*' passed" "$log" 2>/dev/null || true)
  failed=$(grep -cE "^Test case '.*' failed" "$log" 2>/dev/null || true)
  passed=${passed:-0}; failed=${failed:-0}
  done=$((passed + failed))
  mins=$(( ($(date +%s) - start) / 60 ))
  bar=""
  if [ "$total" -gt 0 ]; then
    pct=$(( done * 100 / total )); [ $pct -gt 100 ] && pct=100
    fill=$(( pct / 5 )); bar="["; for i in $(seq 1 20); do [ $i -le $fill ] && bar+="#" || bar+="."; done; bar+="] $pct%"
  fi
  clear
  echo "$title — running ${mins} min (this tab started watching then)"
  echo
  echo "  $done of ~$total done   $bar"
  echo "  passed: $passed   failed: $failed"
  if [ "$failed" -gt 0 ]; then
    echo; echo "  Failed so far:"
    grep -E "^Test case '.*' failed" "$log" | sed -E "s/^Test case '([^']*)'.*/    - \1/" | tail -12
  fi
  final=$(grep -E "\*\* TEST (EXECUTE )?(SUCCEEDED|FAILED) \*\*" "$log" 2>/dev/null | tail -1)
  if [ -n "$final" ]; then echo; echo "  Finished: $final"; exit 0; fi
  sleep 5
done
