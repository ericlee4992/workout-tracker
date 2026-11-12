# usage: python3 -I samp.py <sample.txt> [binary=WorkoutTracker] [top=40]
# Inclusive sample counts per frame of <binary> on the main thread (outermost occurrence per path).
import re, sys, collections
path = sys.argv[1]; binname = sys.argv[2] if len(sys.argv) > 2 else 'WorkoutTracker'; top = int(sys.argv[3]) if len(sys.argv) > 3 else 40
lines = open(path).read().splitlines()
start = next(i for i,l in enumerate(lines) if 'Main Thread' in l)
mainTotal = int(re.search(r'(\d+) Thread', lines[start]).group(1))
pat = re.compile(r'^([ +!:|]*)(\d+) (.+?) +\(in ([^)]+)\)')
stack = []  # (depth, name)
incl = collections.Counter(); idle = 0
for l in lines[start+1:]:
    if re.match(r'^\s{4}\d+ Thread_', l): break
    m = pat.match(l)
    if not m: continue
    depth = len(m.group(1)); n = int(m.group(2)); name = m.group(3); b = m.group(4)
    while stack and stack[-1][0] >= depth: stack.pop()
    if b == binname and not any(s[1] == name for s in stack):
        incl[name] += n
    if name.startswith('mach_msg2_trap'): idle += n
    stack.append((depth, name))
print(f'main thread samples {mainTotal}, waiting in mach_msg {idle} -> busy ~{mainTotal-idle} ({(mainTotal-idle)*100/mainTotal:.0f}%)')
for name, c in incl.most_common(top):
    print(f'{c:6d} {c*100/mainTotal:5.1f}%  {name[:160]}')
