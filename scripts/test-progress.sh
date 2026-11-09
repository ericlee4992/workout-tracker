#!/bin/bash
# Live progress of an xcodebuild test run, for a visible Orca terminal tab.
# usage: scripts/test-progress.sh <xcodebuild log> <expected test count> [title]
# Counts the log's XCTest "Test case" (parallel) and "Test Case" (serial) passed/failed lines and Swift Testing "✔ Test … passed" /
# "✘ Test … failed after" lines every 5 s — live, provisional counts; exits 15 s after the run prints its
# final "** TEST … **" line. The expected count is an estimate (the selected classes' `func test`
# count); parameterised tests may make the real total a little larger.
log=$1; total=${2:-0}; title=${3:-Tests}
start=$(date +%s)
while true; do
  # `✔ Test run with N tests … passed after` is Swift Testing's run summary, not a test.
  passed=$(grep -E "^(Test [Cc]ase '.*' passed|✔ Test .* passed after)" "$log" 2>/dev/null | grep -cv "^✔ Test run with" || true)
  failed=$(grep -cE "^(Test [Cc]ase '.*' failed|✘ Test .* failed after)" "$log" 2>/dev/null || true)
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
    grep -E "^(Test [Cc]ase '.*' failed|✘ Test .* failed after)" "$log" \
      | sed -E "s/^Test [Cc]ase '([^']*)'.*/    - \1/; s/^✘ Test (.*) failed after.*/    - \1/" | tail -12
  fi
  final=$(grep -E "\*\* TEST (EXECUTE )?(SUCCEEDED|FAILED) \*\*" "$log" 2>/dev/null | tail -1)
  if [ -n "$final" ]; then
    # A parallel run keeps printing result lines after its final marker: count on until the log has been quiet for
    # 15 s (codex-review-01 #6). Even then these are console counts — the xcresult summary is the result.
    size=$(wc -c < "$log"); quiet=$((quiet + 5)); [ "$size" != "${lastsize:-}" ] && quiet=0; lastsize=$size
    if [ "$quiet" -ge 15 ]; then
      echo; echo "  Finished: $final"
      echo "  (counts from the log; the real result is the xcresult summary)"; exit 0
    fi
  fi
  sleep 5
done
