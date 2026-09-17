"""Ticket 16 — active-workout directions as phone artboards (390 × 844), the app's tokens."""
from pathlib import Path
HERE = Path(__file__).resolve().parent
CSS = (HERE.parent / "start" / "_common.css").read_text() + """
.phone { padding-top:54px; box-sizing:border-box; }
.nav { display:flex; align-items:center; justify-content:space-between; padding:0 16px; height:44px; }
.navl { display:flex; align-items:center; gap:14px; }
.pill { display:inline-flex; align-items:center; gap:6px; padding:0 12px; height:36px; border-radius:18px; background:#171B21; font-size:15px; font-weight:600; }
.danger { color:#FF5E7A; }
.amber { color:#FFB45E; }
.status { display:flex; align-items:center; justify-content:space-between; padding:6px 20px 0; }
.ring { width:32px; height:32px; border-radius:16px; border:4px solid #2B323C; border-top-color:#FFB45E; border-right-color:#FFB45E; box-sizing:border-box; }
.hr { display:flex; align-items:center; gap:10px; padding:10px 16px; margin:0 16px; }
.xcard { margin:0 16px; padding:16px; display:flex; flex-direction:column; gap:12px; }
.machine { display:flex; align-items:center; gap:10px; padding:10px 12px; border-radius:16px; background:#2B323C; }
.cols { display:grid; grid-template-columns:34px 1fr 118px 60px 34px; gap:8px; align-items:center; }
.colh { font-size:11px; letter-spacing:.6px; font-weight:600; color:#B5B9C2; text-transform:uppercase; }
.num { width:30px; height:30px; border-radius:15px; display:flex; align-items:center; justify-content:center; font-size:14px; font-weight:700; background:#2B323C; color:#F6F3EC; }
.num.done { background:rgba(255,180,94,0.18); color:#FFB45E; }
.field { height:40px; border-radius:10px; background:#222832; display:flex; align-items:center; justify-content:center; font-size:17px; font-weight:600; font-variant-numeric:tabular-nums; }
.field.unit { justify-content:space-between; padding:0 6px 0 12px; }
.ok { width:34px; height:34px; border-radius:17px; display:flex; align-items:center; justify-content:center; }
.ok.go { background:#FFB45E; color:#15110B; }
.ok.done { color:#FFB45E; }
.ok.todo { border:2px solid #3A4250; box-sizing:border-box; }
.dim { opacity:.55; }
.addset { display:flex; align-items:center; justify-content:center; gap:8px; height:44px; border-radius:14px; background:#222832; font-size:15px; font-weight:600; }
.footer { display:flex; gap:10px; padding:0 16px; }
.footer .secondary { flex:1; justify-content:center; }
.rest { position:absolute; left:16px; right:16px; bottom:34px; }
.capsule { display:flex; align-items:center; gap:12px; height:60px; padding:0 8px 0 8px; border-radius:30px; background:#FFB45E; color:#15110B; }
.disc { width:44px; height:44px; border-radius:22px; background:#15110B; color:#FFB45E; display:flex; align-items:center; justify-content:center; }
.capsule .t { display:flex; flex-direction:column; gap:1px; flex:1; }
.capsule .t b { font-size:20px; font-weight:800; font-variant-numeric:tabular-nums; line-height:22px; }
.capsule .t span { font-size:12px; font-weight:600; opacity:.8; }
.cbtn { height:40px; padding:0 14px; border-radius:20px; display:flex; align-items:center; font-size:15px; font-weight:700; white-space:nowrap; }
.cbtn.ghost { border:2px solid #15110B; box-sizing:border-box; }
.cbtn.solid { background:#15110B; color:#FFB45E; margin-right:2px; }
.band { display:flex; align-items:center; gap:10px; padding:8px 10px 8px 12px; border-radius:14px; background:#FFB45E; color:#15110B; }
.band b { font-size:17px; font-weight:800; font-variant-numeric:tabular-nums; }
.strip { display:flex; gap:8px; padding:0 16px; overflow:hidden; }
.tag { display:inline-flex; align-items:center; gap:6px; height:34px; padding:0 12px; border-radius:17px; background:#171B21; font-size:13px; font-weight:600; white-space:nowrap; border:1px solid rgba(255,255,255,0.07); }
.tag.on { border-color:#FFB45E; color:#FFB45E; }
.h2 { font-size:22px; line-height:28px; font-weight:800; }
.sect { padding:12px 20px 4px; }
.line { display:flex; align-items:center; gap:12px; padding:9px 20px; }
.line .n { width:26px; height:26px; border-radius:13px; display:flex; align-items:center; justify-content:center; font-size:13px; font-weight:700; background:#2B323C; }
.line .n.done { background:rgba(255,180,94,0.18); color:#FFB45E; }
.line .v { flex:1; font-size:17px; font-variant-numeric:tabular-nums; }
.line.cur { padding:8px 16px; margin:0 8px; border-radius:16px; background:#171B21; border:1px solid rgba(255,255,255,0.07); }
"""
CHECK = '<svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M3 8.5l3.2 3.2L13 5"/></svg>'
HOUR = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 3h12M6 21h12M7 3c0 5 5 6 5 9s-5 4-5 9M17 3c0 5-5 6-5 9s5 4 5 9"/></svg>'
HEART = '<svg width="16" height="16" viewBox="0 0 24 24" fill="#FF5E7A"><path d="M12 21s-7.5-4.6-9.5-9.2C1 7.8 3.6 4 7.3 4c2 0 3.5 1 4.7 2.6C13.2 5 14.7 4 16.7 4c3.7 0 6.3 3.8 4.8 7.8C19.5 16.4 12 21 12 21z"/></svg>'
PIN = '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#B5B9C2" stroke-width="2.2"><circle cx="12" cy="9" r="3"/><path d="M12 12v6M6 20c0-2 12-2 12 0"/></svg>'
GEAR = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#B5B9C2" stroke-width="2"><circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9l2.1 2.1M17 17l2.1 2.1M4.9 19.1L7 17M17 7l2.1-2.1"/></svg>'
CHEV = '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#F6F3EC" stroke-width="2.4" stroke-linecap="round"><path d="M6 9l6 6 6-6"/></svg>'

def nav():
    return f'''<div class="nav"><div class="navl">{CHEV}<span class="danger body">Cancel</span></div><span class="headline">Seated Chest… <span class="tertiary">✎</span></span><span class="amber headline">Finish</span></div>'''

def status(ring=True):
    r = '<div class="ring"></div>' if ring else ''
    return f'''<div class="status"><span class="caption" style="display:flex;gap:6px;align-items:center">{PIN} Iron Temple · 12 min</span><span style="display:flex;align-items:center;gap:8px"><span class="caption amber" style="font-weight:700">3/8 sets</span>{r}</span></div>'''

def hr_strip():
    return f'''<div class="hr card"><span style="display:flex;align-items:center;gap:6px">{HEART}<b style="font-size:20px;font-variant-numeric:tabular-nums">128</b><span class="caption">bpm</span></span><span class="chip" style="background:rgba(165,207,154,0.14);color:#A5CF9A">Zone 3</span><span class="caption" style="margin-left:auto">142 cal</span></div>'''

def row(n, prev, w, reps, state):
    # state: done | cur | todo
    if state == "done":
        return f'<div class="cols dim"><div class="num done">{n}</div><span class="caption">{prev}</span><div class="field unit"><span>{w}</span><span class="chip lb">lb</span></div><div class="field">{reps}</div><div class="ok done">{CHECK}</div></div>'
    if state == "cur":
        return f'<div class="cols"><div class="num" style="background:#FFB45E;color:#15110B">{n}</div><span class="caption">{prev}</span><div class="field unit" style="background:#2B323C"><span>{w}</span><span class="chip lb">lb</span></div><div class="field" style="background:#2B323C">{reps}</div><div class="ok go">{CHECK}</div></div>'
    return f'<div class="cols dim"><div class="num">{n}</div><span class="caption">—</span><div class="field unit"><span>{w}</span><span class="chip lb">lb</span></div><div class="field">{reps}</div><div class="ok todo"></div></div>'

def card(title, machine, rows, add=True, extra=""):
    hdr = '<div class="cols"><span class="colh">Set</span><span class="colh">Previous</span><span class="colh">Weight</span><span class="colh">Reps</span><span></span></div>'
    return f'''<div class="xcard card"><div style="display:flex;align-items:center;justify-content:space-between"><span class="headline">{title}</span><span class="tertiary" style="font-size:18px">⋯</span></div>
<div class="machine">{GEAR}<div style="display:flex;flex-direction:column"><span class="body" style="font-weight:600;font-size:15px">{machine[0]}</span><span class="caption">{machine[1]}</span></div><span class="tertiary" style="margin-left:auto">›</span></div>
{hdr if rows else ""}{"".join(rows)}{extra}{'<div class="addset">+ Add Set</div>' if add else ''}</div>'''

def capsule():
    return f'''<div class="rest"><div class="capsule"><div class="disc">{HOUR}</div><div class="t"><b>1:58</b><span>Rest</span></div><div class="cbtn ghost">+15s</div><div class="cbtn solid">Skip</div></div></div>'''

def phone(inner):
    return f'''<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
  <style>
{CSS}
  </style>
</helmet>
<div class="phone">{inner}</div>
</x-dc>
</body>
</html>'''

chest_rows = [row(1, "60 lb × 10", "60", "10", "done"), row(2, "60 lb × 10", "60", "10", "cur"), row(3, "—", "60", "10", "todo")]
lat_rows = [row(1, "—", "80", "10", "todo"), row(2, "—", "80", "10", "todo")]

# A — the set is the hero; resting
A = phone(f'''{nav()}{status()}<div style="height:10px"></div>{hr_strip()}<div style="height:12px"></div>
{card("Seated Chest Press", ("Chest Press", "Life Fitness Insignia Series"), chest_rows)}<div style="height:12px"></div>
{card("Lat Pulldown", ("Lat Pulldown", "Hammer Strength"), [], add=False)}<div style="height:12px"></div>
<div class="footer"><span class="secondary">+ Add Exercise</span><span class="secondary">Add by Machine</span></div><div style="height:96px"></div>
{capsule()}''')
# A without rest: the current set's amber control is the only amber command
A2 = phone(f'''{nav()}{status()}<div style="height:10px"></div>{hr_strip()}<div style="height:12px"></div>
{card("Seated Chest Press", ("Chest Press", "Life Fitness Insignia Series"), chest_rows)}<div style="height:12px"></div>
{card("Lat Pulldown", ("Lat Pulldown", "Hammer Strength"), lat_rows, add=True)}<div style="height:12px"></div>
<div class="footer"><span class="secondary">+ Add Exercise</span><span class="secondary">Add by Machine</span></div>''')
# B — one exercise at a time
def bigrow(n, w, reps, state):
    if state == "done":
        return f'<div class="cols dim" style="grid-template-columns:36px 1fr 78px 44px;min-height:52px"><div class="num done">{n}</div><div class="field unit" style="height:48px"><span>{w}</span><span class="chip lb">lb</span></div><div class="field" style="height:48px">{reps}</div><div class="ok done">{CHECK}</div></div>'
    if state == "cur":
        return f'<div class="cols" style="grid-template-columns:36px 1fr 78px 44px;min-height:52px"><div class="num" style="background:#FFB45E;color:#15110B">{n}</div><div class="field unit" style="height:48px;background:#2B323C"><span>{w}</span><span class="chip lb">lb</span></div><div class="field" style="height:48px;background:#2B323C">{reps}</div><div class="ok go">{CHECK}</div></div>'
    return f'<div class="cols dim" style="grid-template-columns:36px 1fr 78px 44px;min-height:52px"><div class="num">{n}</div><div class="field unit" style="height:48px"><span>{w}</span><span class="chip lb">lb</span></div><div class="field" style="height:48px">{reps}</div><div class="ok todo"></div></div>'
big_rows = [bigrow(1, "60", "10", "done"), bigrow(2, "60", "10", "cur"), bigrow(3, "60", "10", "todo")]
B = phone(f'''{nav()}
<div class="strip" style="margin-top:6px"><span class="tag on">1 · Chest Press</span><span class="tag">2 · Lat Pulldown</span><span class="tag">+</span></div>
<div style="display:flex;align-items:center;gap:10px;padding:14px 20px 0"><span class="caption">{PIN} Iron Temple · 12 min</span><span class="caption" style="margin-left:auto;display:flex;align-items:center;gap:6px">{HEART}<b style="color:#F6F3EC">128</b> · Zone 3</span></div>
<div style="padding:10px 20px 0"><div class="h2">Seated Chest Press</div><div class="caption" style="margin-top:2px">Chest Press · Life Fitness Insignia Series</div></div>
<div class="xcard card" style="margin-top:14px;gap:14px">{"".join(big_rows)}<div class="addset">+ Add Set</div>
<div class="band"><span style="display:flex;align-items:center;gap:8px">{HOUR}<b>1:58</b><span class="caption" style="color:#15110B;opacity:.75">rest</span></span><div style="margin-left:auto;display:flex;gap:6px"><div class="cbtn ghost" style="height:34px">+15s</div><div class="cbtn solid" style="height:34px">Skip</div></div></div></div>
<div style="display:flex;justify-content:space-between;align-items:center;padding:16px 20px"><span class="caption">1 of 2</span><span class="secondary">Next: Lat Pulldown ›</span></div>''')
# C — timeline
C = phone(f'''{nav()}
<div class="status"><span class="caption">{PIN} Iron Temple · 12 min · <span class="amber" style="font-weight:700">3/8 sets</span></span><span class="caption" style="display:flex;align-items:center;gap:6px">{HEART}<b style="color:#F6F3EC">128</b> · Zone 3</span></div>
<div class="sect headline">Seated Chest Press <span class="caption" style="font-weight:400">· Chest Press</span></div>
<div class="line"><div class="n done">1</div><span class="v dim">60 lb × 10</span><span class="amber">{CHECK}</span></div>
<div class="line cur"><div class="n" style="background:#FFB45E;color:#15110B">2</div><div class="field unit" style="width:112px;background:#2B323C"><span>60</span><span class="chip lb">lb</span></div><div class="field" style="width:58px;background:#2B323C">10</div><span style="flex:1"></span><div class="ok go">{CHECK}</div></div>
<div style="padding:6px 16px 4px"><div class="band"><span style="display:flex;align-items:center;gap:8px">{HOUR}<b>1:58</b><span class="caption" style="color:#15110B;opacity:.75">rest</span></span><div style="margin-left:auto;display:flex;gap:6px"><div class="cbtn ghost" style="height:34px">+15s</div><div class="cbtn solid" style="height:34px">Skip</div></div></div></div>
<div class="line dim"><div class="n">3</div><span class="v">— × —</span><div class="ok todo" style="width:26px;height:26px"></div></div>
<div class="line"><span class="caption" style="padding-left:38px">+ Add Set</span></div>
<div class="sect headline">Lat Pulldown <span class="caption" style="font-weight:400">· Hammer Strength</span></div>
<div class="line dim"><div class="n">1</div><span class="v">— × —</span><div class="ok todo" style="width:26px;height:26px"></div></div>
<div class="line dim"><div class="n">2</div><span class="v">— × —</span><div class="ok todo" style="width:26px;height:26px"></div></div>
<div style="display:flex;gap:18px;padding:14px 20px"><span class="body amber" style="font-weight:600">+ Exercise</span><span class="body" style="font-weight:600;color:#B5B9C2">by Machine</span></div>''')
for name, html in [("DirectionA", A), ("DirectionAIdle", A2), ("DirectionB", B), ("DirectionC", C)]:
    (HERE / f"{name}.dc.html").write_text(html)
(HERE / "Main.dc.html").write_text(A)
import json
json.dump({
  "artboards": [
    {"file": "Main.dc.html", "x": 0, "y": 0, "w": 390, "h": 844, "title": "A · The set is the hero (resting)"},
    {"file": "DirectionAIdle.dc.html", "x": 520, "y": 0, "w": 390, "h": 844, "title": "A · logging, no rest"},
    {"file": "DirectionB.dc.html", "x": 1040, "y": 0, "w": 390, "h": 844, "title": "B · One exercise at a time"},
    {"file": "DirectionC.dc.html", "x": 1560, "y": 0, "w": 390, "h": 844, "title": "C · Timeline"},
    {"file": "DirectionA.dc.html", "x": 0, "y": 1000, "w": 390, "h": 844, "title": "A · (same as Main, kept for the record)"},
  ],
  "annotations": [
    {"id": "brief", "x": 0, "y": -170, "w": 520, "text": "Active workout, second pass. Three structures, same fixture: 12 min in, set 2 of Seated Chest Press is next, a 1:58 rest running, heart rate 128 in zone 3.\nA keeps today's structure and fixes the hierarchy: the big elapsed number, the amber Add Exercise and the amber ring all step down; the current set's tick and the rest capsule are the only amber things. The rest is the Start screen's capsule shape, so Skip and +15s cannot wrap.\nB shows one exercise at a time with bigger rows and an exercise strip on top.\nC collapses done sets to one line and puts the rest right under the set you just finished.\nTab bar, nav bar and icons are stand-ins; the real ones stay."},
  ],
  "launch": {"view": "canvas"}
}, open(HERE / "canvas.json", "w"), indent=2)
# plain board for the PNG
board = "".join(f'<div style="display:flex;flex-direction:column;gap:10px"><div style="font:600 13px -apple-system,system-ui;color:#B5B9C2">{t}</div><div style="border:1px solid #2B323C;border-radius:8px;overflow:hidden;width:390px;height:844px;position:relative">{h.split("<x-dc>")[1].split("</x-dc>")[0].replace("<helmet>","").replace("</helmet>","")}</div></div>'
    for t, h in [("A · The set is the hero (resting)", A), ("A · logging, no rest", A2), ("B · One exercise at a time", B), ("C · Timeline", C)])
(HERE / "board.html").write_text(f'<!doctype html><html><head><meta charset="utf-8"><style>{CSS} html{{background:#0B0D10}} body{{padding:24px}}</style></head><body><div style="display:flex;gap:28px;align-items:flex-start">{board}</div></body></html>')
print("artboards written")
