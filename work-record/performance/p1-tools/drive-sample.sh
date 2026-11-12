#!/bin/bash
# usage: drive-sample.sh <label> <phase> <seconds> [P1_X=1 ...]  runs the driver and samples the app during <phase>
label=$1; phase=$2; secs=$3; shift 3
/tmp/p1/tools/drive.sh $label "$@" > /tmp/p1/drive-$label.summary &
dp=$!
for i in $(seq 1 600); do grep -q "P1MARK $phase" /tmp/p1/drive-$label.log 2>/dev/null && break; sleep 0.2; done
PID=$(pgrep -f "9E822EF6.*WorkoutTracker.app/WorkoutTracker -uiTest" | head -1)
sample $PID $secs -mayDie -file /tmp/p1/$label-$phase.sample.txt >/dev/null 2>&1
wait $dp; cat /tmp/p1/drive-$label.summary
python3 -I /tmp/p1/tools/samp.py /tmp/p1/$label-$phase.sample.txt WorkoutTracker 30
