#!/bin/bash
# P1 idle loop: launch the heavy store (workout auto-opens), stay idle, report hitches, body counts, CPU.
# usage: idle-loop.sh <label> [seconds=20] [extra env assignments e.g. P1_NO_CARDIO_SAVE=1]
label=$1; secs=${2:-20}; shift 2 || shift $#
D=9E822EF6-DC67-4958-AEA2-D53D2D36D674
APP=/tmp/p1/dd/Build/Products/Release-iphonesimulator/WorkoutTracker.app
out=/tmp/p1/idle-$label.log
xcrun simctl install $D $APP
xcrun simctl terminate $D com.example.workouttracker 2>/dev/null
envs=(SIMCTL_CHILD_P1_PROBE=1); for e in "$@"; do envs+=("SIMCTL_CHILD_$e"); done
env "${envs[@]}" xcrun simctl launch --console-pspawn $D com.example.workouttracker -uiTestReset -uiTestPerfStore ${EXTRA_ARGS:-} > $out 2>&1 &
lp=$!
sleep 12
PID=$(pgrep -f "$D.*WorkoutTracker.app/WorkoutTracker -uiTest" | head -1)
: > /tmp/p1/mark; start=$(wc -l < $out)
cpu=$(/tmp/p1/tools/cpu.sh $PID $secs)
tail -n +$((start+1)) $out > $out.window
kill $lp 2>/dev/null
echo "== $label ($secs s idle in the open workout) $cpu"
echo "cardio saves: $(grep -c 'cardio save' $out.window)"
grep -o 'hitch [0-9]* ms' $out.window | awk '{n++; s+=$2; if($2>m)m=$2} END {printf "hitches >34ms: %d, total %d ms, worst %d ms\n", n, s, m}'
grep '5s bodies' $out.window | sed 's/.*5s bodies: /  5s: /'
