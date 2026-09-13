"""Round 2 board (muscle maps): Main.dc.html from icons/claude2/*.svg (two-layer SVG) and
icons/codex2/*.png (grey body + red muscle on black → two masks)."""
import re
from pathlib import Path
HERE = Path(__file__).resolve().parent
ICONS = HERE.parents[1] / "icons"
FAM = ["chest", "back", "shoulders", "arms", "legs"]
BOLD = {"chest":"#FF6B7A","back":"#4DA8FF","shoulders":"#2ED3BC","arms":"#B98CFF","legs":"#7FE06B"}
CODEX = {"chest":"#FF70B6","back":"#4EB9FF","shoulders":"#4DE0D4","arms":"#B891FF","legs":"#84D65A"}
BG, CARD, TEXT, SEC, BODY = "#0B0D10", "#171B21", "#F6F3EC", "#B5B9C2", "#5B6472"

def claude_svg(fam, size, colour):
    body = re.search(r'<svg[^>]*>(.*)</svg>', (ICONS/"claude2"/f"{fam}.svg").read_text(), re.S).group(1)
    body = body.replace("BODY", BODY).replace("MUSCLE", colour)
    inner = round(size * 0.86, 1); off = round((size - inner) / 2, 1)
    return f'<svg width="{size}" height="{size}" viewBox="0 0 {size} {size}" xmlns="http://www.w3.org/2000/svg"><g transform="translate({off},{off}) scale({inner/48:.4f})">{body}</g></svg>'

def mask_span(file, size, colour):
    s = round(size*0.86)
    return f'<span style="position:absolute;left:{round((size-s)/2)}px;top:{round((size-s)/2)}px;width:{s}px;height:{s}px;-webkit-mask:url(\'{file}\') center/contain no-repeat;mask:url(\'{file}\') center/contain no-repeat;background:{colour}"></span>'

def codex_icon(fam, size, colour):
    return f'<span style="position:relative;display:inline-block;width:{size}px;height:{size}px">{mask_span(f"codex2-{fam}-body.png", size, BODY)}{mask_span(f"codex2-{fam}-muscle.png", size, colour)}</span>'

def tile(glyph_html, size, colour, tint):
    r = 8 if size <= 24 else 14
    bg = f"color-mix(in srgb, {colour} 16%, transparent)" if tint else "transparent"
    return f'<div style="width:{size}px;height:{size}px;border-radius:{r}px;background:{bg};display:flex;align-items:center;justify-content:center;overflow:hidden">{glyph_html}</div>'

def strip(kind, size, colours, tint=True):
    out = []
    for f in FAM:
        c = colours[f]
        g = claude_svg(f, size, c) if kind == "claude" else codex_icon(f, size, c)
        out.append(tile(g, size, c, tint))
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

def label(t): return f'<div style="font-size:11px;color:{SEC};text-transform:uppercase;letter-spacing:0.6px">{t}</div>'

def row(title, note, kind, colours):
    cells = f'''<div style="display:flex;flex-direction:column;gap:10px">{label("Detail · 40 pt")}{detail_header(strip(kind,40,colours))}</div>
<div style="display:flex;flex-direction:column;gap:10px">{label("Tile · 24 pt")}{template_tile(strip(kind,24,colours))}</div>
<div style="display:flex;flex-direction:column;gap:10px">{label("Large · 64 pt, no tile")}{strip(kind,64,colours,tint=False)}</div>'''
    return f'''<div style="display:flex;flex-direction:column;gap:14px;padding:24px 28px;border-top:1px solid rgba(255,255,255,0.07)">
<div style="display:flex;align-items:baseline;gap:14px"><div style="font-size:22px;font-weight:700;color:{TEXT}">{title}</div><div style="font-size:13px;color:{SEC}">{note}</div></div>
<div style="display:flex;gap:40px;align-items:flex-start">{cells}</div>
</div>'''

codex_ready = all((HERE/f"codex2-{f}-muscle.png").exists() for f in FAM)
rows = [row("Claude — muscle map", "grey body, the family's muscle filled · pecs · lats + traps · deltoids · bicep · quads", "claude", BOLD)]
rows.append(row("Codex — muscle map", "image-model body maps, grey body + red muscle split into two layers", "codex", CODEX) if codex_ready
            else f'<div style="padding:24px 28px;border-top:1px solid rgba(255,255,255,0.07);color:{SEC};font-size:13px">Codex — muscle map: generating…</div>')
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
<div style="font-size:28px;font-weight:800;color:{TEXT};letter-spacing:-0.5px">Muscle-family icons · round 2, muscle maps</div>
<div style="font-size:14px;color:{SEC}">A neutral body with the working muscle highlighted, after the user's references — on the template tile (24 pt), the detail (40 pt), and large. Round 1's silhouettes are on the second artboard.</div>
</div>
{"".join(rows)}
</div>
</x-dc>
</body>
</html>'''
(HERE/"Main.dc.html").write_text(html)
print("Main.dc.html written; codex_ready =", codex_ready)
