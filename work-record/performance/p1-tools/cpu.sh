#!/bin/bash
# usage: cpu.sh <pid> <seconds>  -> CPU% over the window from cumulative cputime
pid=$1; secs=$2
t() { ps -o time= -p $pid | awk -F'[:.]' '{ if (NF==3) print ($1*60+$2)+$3/100; else print ($1*3600+$2*60+$3)+$4/100 }'; }
a=$(t); sleep $secs; b=$(t)
python3 -c "print(f'cpu {($b-$a)/$secs*100:.1f}% over ${secs}s (cputime {$b-$a:.2f}s)')"
