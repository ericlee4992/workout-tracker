# usage: python3 -I phases.py <xcodebuild log> <probe log>  -> hitches and body counts per phase
import re, sys, collections
marks = [(m.group(1), float(m.group(2))) for m in re.finditer(r'P1MARK (\w+) ([\d.]+)', open(sys.argv[1]).read())]
events = []
for l in open(sys.argv[2]):
    m = re.match(r'\[DEBUG-p1\] ([\d.]+) (.*)', l)
    if m: events.append((float(m.group(1)), m.group(2)))
seen = []
for i, (name, t0) in enumerate(marks):
    if name in seen or name == 'end': continue
    seen.append(name)
    t1 = marks[i+1][1] if i + 1 < len(marks) else 1e18
    hs = [int(re.search(r'hitch (\d+)', e).group(1)) for t, e in events if t0 <= t < t1 and e.startswith('hitch')]
    saves = sum(1 for t, e in events if t0 <= t < t1 and e.startswith('cardio save'))
    print(f'{name:7s} {t1-t0:5.1f}s  hitches {len(hs):3d}  frozen {sum(hs):6d} ms ({sum(hs)*100/((t1-t0)*1000):4.0f}%)  worst {max(hs) if hs else 0:5d} ms  cardio saves {saves}')
