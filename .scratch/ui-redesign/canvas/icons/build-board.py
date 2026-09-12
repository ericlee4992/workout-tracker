"""Builds Main.dc.html — the muscle-family icon comparison board — from
../../icons/claude/*.svg (inline) and ../../icons/codex/*.png (as files entries)."""
import re, os, subprocess
from pathlib import Path
HERE = Path(__file__).resolve().parent
ICONS = HERE.parents[1] / "icons"
FAM = ["chest", "back", "shoulders", "arms", "legs"]
CUR = {"chest":"#F4939C","back":"#8ABCE5","shoulders":"#E6CF88","arms":"#C1A9EB","legs":"#A5CF9A"}
BOLD = {"chest":"#FF6B7A","back":"#4DA8FF","shoulders":"#2ED3BC","arms":"#B98CFF","legs":"#7FE06B"}
BG, CARD, INK, TEXT, SEC = "#0B0D10", "#171B21", "#15110B", "#F6F3EC", "#B5B9C2"

def claude_svg(fam, size, colour, on):
    body = re.search(r'<g fill="#FFFFFF">(.*)</g>', (ICONS/"claude"/f"{fam}.svg").read_text(), re.S).group(1)
    body = body.replace("#0B0D10", on).replace("#FFFFFF", colour)
    inner = round(size * 0.86, 1); off = round((size - inner) / 2, 1)
    return f'<svg width="{size}" height="{size}" viewBox="0 0 {size} {size}" xmlns="http://www.w3.org/2000/svg"><g transform="translate({off},{off}) scale({inner/48:.4f})" fill="{colour}">{body}</g></svg>'

def codex_img(fam, size):
    # white glyph png, tinted via CSS mask so the colour can change
    return f'<span style="display:inline-block;width:{round(size*0.66)}px;height:{round(size*0.66)}px;-webkit-mask:url(\'codex-{fam}.png\') center/contain no-repeat;mask:url(\'codex-{fam}.png\') center/contain no-repeat;background:currentColor"></span>'

def tile(glyph_html, size, colour, mode):
    r = 8 if size <= 24 else 14
    if mode == "tint":
        return f'<div style="width:{size}px;height:{size}px;border-radius:{r}px;background:color-mix(in srgb, {colour} 18%, transparent);display:flex;align-items:center;justify-content:center;color:{colour}">{glyph_html}</div>'
    return f'<div style="width:{size}px;height:{size}px;border-radius:{r}px;background:{colour};display:flex;align-items:center;justify-content:center;color:{INK}">{glyph_html}</div>'

def strip(kind, size, mode, colours):
    out = []
    for f in FAM:
        c = colours[f]
        on = CARD if mode == "tint" else c
        if kind == "claude": g = claude_svg(f, size, c if mode == "tint" else INK, on if mode=="tint" else c)
        else: g = codex_img(f, size)
        out.append(tile(g, size, c, mode))
    return f'<div style="display:flex;gap:{8 if size<=24 else 10}px">{"".join(out)}</div>'

def template_tile(strip_html):
    return f'''<div style="width:200px;background:{CARD};border:1px solid rgba(255,255,255,0.07);border-radius:24px;padding:12px;display:flex;flex-direction:column;gap:8px;box-sizing:border-box">
{strip_html}
<div style="font-size:17px;font-weight:700;color:{TEXT};line-height:22px">Whole Body</div>
<div style="font-size:12px;color:{SEC};line-height:16px">Bench Press · Lat Pulldown · Machine Shoulder Press · Dumbbell Curl · Leg Press · Abdominal Crunch</div>
</div>'''

def detail_header(strip_html):
    return f'''<div style="width:300px;background:{BG};padding:8px 0;display:flex;flex-direction:column;gap:12px">
<div style="font-size:34px;font-weight:700;color:{TEXT};letter-spacing:-0.4px;line-height:41px">Whole Body</div>
{strip_html}
</div>'''

def row(title, note, kind, colours, current_imgs=None):
    if current_imgs:
        cells = f'''<div style="display:flex;flex-direction:column;gap:10px"><div style="font-size:11px;color:{SEC};text-transform:uppercase;letter-spacing:0.6px">Detail · 40 pt (capture)</div><img src="current-detail-strip.png" style="width:360px;border-radius:8px" /></div>
<div style="display:flex;flex-direction:column;gap:10px"><div style="font-size:11px;color:{SEC};text-transform:uppercase;letter-spacing:0.6px">Tile · 24 pt (capture)</div><img src="current-tile-strip.png" style="width:240px;border-radius:8px" /></div>'''
    else:
        cells = f'''<div style="display:flex;flex-direction:column;gap:10px"><div style="font-size:11px;color:{SEC};text-transform:uppercase;letter-spacing:0.6px">Detail · 40 pt · tint</div>{detail_header(strip(kind,40,"tint",colours))}</div>
<div style="display:flex;flex-direction:column;gap:10px"><div style="font-size:11px;color:{SEC};text-transform:uppercase;letter-spacing:0.6px">Tile · 24 pt · tint</div>{template_tile(strip(kind,24,"tint",colours))}</div>
<div style="display:flex;flex-direction:column;gap:10px"><div style="font-size:11px;color:{SEC};text-transform:uppercase;letter-spacing:0.6px">Solid tiles (alternative)</div>{strip(kind,40,"solid",colours)}<div style="height:6px"></div>{template_tile(strip(kind,24,"solid",colours))}</div>'''
    return f'''<div style="display:flex;flex-direction:column;gap:14px;padding:24px 28px;border-top:1px solid rgba(255,255,255,0.07)">
<div style="display:flex;align-items:baseline;gap:14px"><div style="font-size:22px;font-weight:700;color:{TEXT}">{title}</div><div style="font-size:13px;color:{SEC}">{note}</div></div>
<div style="display:flex;gap:40px;align-items:flex-start">{cells}</div>
</div>'''

codex_ready = all((ICONS/"codex"/f"{f}.png").exists() for f in FAM)
codex_note = (ICONS/"codex"/"README.md").read_text().strip().splitlines()[0][:160] if (ICONS/"codex"/"README.md").exists() else "generating…"
rows = [
    row("Current", "SF Symbols · pastel at 14 % — what is on the phone", "current", CUR, current_imgs=True),
    row("Claude", "hand-drawn silhouettes · one cut-line language across the five · bolder hues at 18 %", "claude", BOLD),
]
if codex_ready:
    codex_colours = dict(BOLD)
    readme = (ICONS/"codex"/"README.md").read_text() if (ICONS/"codex"/"README.md").exists() else ""
    for f in FAM:
        m = re.search(rf'{f}[^#\n]*?(#[0-9A-Fa-f]{{6}})', readme, re.I)
        if m: codex_colours[f] = m.group(1).upper()
    rows.append(row("Codex", "image-model silhouettes, white-on-black converted to masks · Codex's five colours", "codex", codex_colours))
else:
    rows.append(f'<div style="padding:24px 28px;border-top:1px solid rgba(255,255,255,0.07);color:{SEC};font-size:13px">Codex — generating…</div>')

html = f'''<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
  <style>
    body {{ margin: 0; font-family: -apple-system, "SF Pro Text", "SF Pro Display", system-ui, sans-serif; background: {BG}; color: {TEXT}; -webkit-font-smoothing: antialiased; }}
    a {{ color: #FFB45E; }} a:hover {{ color: #E69A3F; }}
  </style>
</helmet>
<div style="width:1180px;background:{BG};display:flex;flex-direction:column">
<div style="padding:28px 28px 18px;display:flex;flex-direction:column;gap:6px">
<div style="font-size:28px;font-weight:800;color:{TEXT};letter-spacing:-0.5px">Muscle-family icons</div>
<div style="font-size:14px;color:{SEC}">Chest · Back · Shoulders · Arms · Legs — on the template tile (24 pt) and the template detail (40 pt), in the app's ink and card colours.</div>
</div>
{"".join(rows)}
</div>
</x-dc>
</body>
</html>'''
(HERE/"Main.dc.html").write_text(html)
print("Main.dc.html written; codex_ready =", codex_ready)
