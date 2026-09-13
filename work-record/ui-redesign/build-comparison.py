#!/usr/bin/env python3
"""Build the design-comparison artifact: before / Claude / Codex per screen, images inlined.
Usage: build-comparison.py <config.json> <out.html>
config: {"screens": [{"key": "...", "title": "...", "note": "..."}], "columns": [{"id": "before", "label": "Before", "dir": "...", "prefix": "redesign-"}, ...],
         "palettes": {"Claude": [["Accent", "#FF7A3D"], ...], "Codex": [...]}, "notes": {"Claude": "...", "Codex": "..."}}"""
import base64, io, json, sys, pathlib, html
from PIL import Image

cfg = json.load(open(sys.argv[1]))
out = pathlib.Path(sys.argv[2])
WIDTH = 480

def data_uri(path):
    im = Image.open(path).convert("RGB")
    ratio = WIDTH / im.width
    im = im.resize((WIDTH, int(im.height * ratio)), Image.LANCZOS)
    buf = io.BytesIO(); im.save(buf, "JPEG", quality=82, optimize=True)
    return "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode()

def find(col, key):
    d = pathlib.Path(col["dir"])
    for cand in [d / f"{col['prefix']}{key}.png", d / f"{key}.png"]:
        if cand.exists(): return cand
    for p in d.glob(f"*{key}*.png"): return p
    return None

sections = []
for screen in cfg["screens"]:
    cells = []
    for col in cfg["columns"]:
        p = find(col, screen["key"])
        if p:
            cells.append(f'<figure class="shot"><img src="{data_uri(p)}" alt="{html.escape(col["label"])}: {html.escape(screen["title"])}" loading="lazy"><figcaption>{html.escape(col["label"])}</figcaption></figure>')
        else:
            cells.append(f'<figure class="shot missing"><div class="ph">Not captured</div><figcaption>{html.escape(col["label"])}</figcaption></figure>')
    note = f'<p class="note">{html.escape(screen.get("note",""))}</p>' if screen.get("note") else ""
    sections.append(f'<section class="screen" id="{screen["key"]}"><h2>{html.escape(screen["title"])}</h2>{note}<div class="row">{"".join(cells)}</div></section>')

def palette_block(name, swatches, note):
    sw = "".join(f'<li><span class="chip" style="background:{c}"></span><span class="sw-name">{html.escape(n)}</span><code>{c}</code></li>' for n, c in swatches)
    return f'<div class="pal"><h3>{html.escape(name)}</h3><ul>{sw}</ul><p>{html.escape(note)}</p></div>'

palettes = "".join(palette_block(n, cfg["palettes"][n], cfg.get("notes", {}).get(n, "")) for n in cfg["palettes"])
toc = "".join(f'<a href="#{s["key"]}">{html.escape(s["title"])}</a>' for s in cfg["screens"])

page = f"""<title>Workout Tracker Redesign Board</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:opsz,wght@12..96,500;12..96,700&family=IBM+Plex+Sans:wght@400;500;600&family=IBM+Plex+Mono:wght@400&display=swap">
<style>
:root {{
  --bg: #F3F1EC; --ink: #1C1B19; --ink-2: #5E5B55; --ink-3: #8E8A82; --rule: #DCD8D0; --panel: #FBFAF7;
  --accent: #2E5B78; --accent-soft: #DCE7EE;
  --display: "Bricolage Grotesque", "Avenir Next", "Helvetica Neue", sans-serif;
  --body: "IBM Plex Sans", "Helvetica Neue", Arial, sans-serif;
  --mono: "IBM Plex Mono", "SF Mono", Menlo, monospace;
}}
@media (prefers-color-scheme: dark) {{ :root:not([data-theme="light"]) {{
  --bg: #15161A; --ink: #ECEAE4; --ink-2: #ACA9A1; --ink-3: #7B7871; --rule: #2C2E34; --panel: #1D1F25; --accent: #8FB7D3; --accent-soft: #23303A; }} }}
:root[data-theme="dark"] {{
  --bg: #15161A; --ink: #ECEAE4; --ink-2: #ACA9A1; --ink-3: #7B7871; --rule: #2C2E34; --panel: #1D1F25; --accent: #8FB7D3; --accent-soft: #23303A; }}
* {{ box-sizing: border-box; }}
body {{ margin: 0; background: var(--bg); color: var(--ink); font-family: var(--body); font-size: 15px; line-height: 1.5; }}
header {{ padding: 40px 32px 24px; border-bottom: 1px solid var(--rule); }}
header .eyebrow {{ font-family: var(--mono); font-size: 12px; letter-spacing: .08em; text-transform: uppercase; color: var(--accent); }}
header h1 {{ font-family: var(--display); font-weight: 700; font-size: clamp(28px, 4vw, 44px); line-height: 1.05; margin: 8px 0 10px; text-wrap: balance; letter-spacing: -.01em; }}
header p {{ max-width: 62ch; color: var(--ink-2); margin: 0; }}
nav {{ display: flex; flex-wrap: wrap; gap: 8px 14px; padding: 14px 32px; border-bottom: 1px solid var(--rule); font-size: 13px; }}
nav a {{ color: var(--ink-2); text-decoration: none; padding: 4px 0; border-bottom: 2px solid transparent; }}
nav a:hover, nav a:focus-visible {{ color: var(--ink); border-bottom-color: var(--accent); outline: none; }}
.palettes {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 20px; padding: 28px 32px; border-bottom: 1px solid var(--rule); }}
.pal h3 {{ font-family: var(--display); font-weight: 700; font-size: 20px; margin: 0 0 10px; }}
.pal ul {{ list-style: none; margin: 0 0 10px; padding: 0; display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: 8px 14px; }}
.pal li {{ display: flex; align-items: center; gap: 8px; font-size: 13px; }}
.pal .chip {{ width: 22px; height: 22px; border-radius: 6px; border: 1px solid var(--rule); flex: none; }}
.pal .sw-name {{ color: var(--ink-2); }}
.pal code {{ font-family: var(--mono); font-size: 12px; color: var(--ink-3); margin-left: auto; }}
.pal p {{ margin: 0; color: var(--ink-2); font-size: 14px; max-width: 60ch; }}
main {{ padding: 8px 32px 48px; }}
.screen {{ padding: 28px 0 16px; border-bottom: 1px solid var(--rule); }}
.screen h2 {{ font-family: var(--display); font-weight: 700; font-size: 24px; margin: 0 0 4px; letter-spacing: -.01em; }}
.screen .note {{ margin: 0 0 14px; color: var(--ink-2); max-width: 70ch; }}
.row {{ display: grid; grid-template-columns: repeat(3, minmax(220px, 1fr)); gap: 20px; overflow-x: auto; }}
.shot {{ margin: 0; display: flex; flex-direction: column; gap: 8px; }}
.shot img {{ width: 100%; height: auto; border-radius: 22px; border: 1px solid var(--rule); background: #000; display: block; }}
.shot .ph {{ aspect-ratio: 9/19.5; border-radius: 22px; border: 1px dashed var(--rule); display: grid; place-items: center; color: var(--ink-3); font-size: 13px; background: var(--panel); }}
figcaption {{ font-family: var(--mono); font-size: 12px; letter-spacing: .06em; text-transform: uppercase; color: var(--ink-2); }}
.shot:nth-child(1) figcaption {{ color: var(--ink-3); }}
footer {{ padding: 20px 32px 40px; color: var(--ink-3); font-size: 13px; }}
@media (max-width: 720px) {{ header, nav, .palettes, main, footer {{ padding-left: 16px; padding-right: 16px; }} .row {{ grid-template-columns: repeat(3, 220px); }} }}
</style>
<header>
  <div class="eyebrow">Workout Tracker · UI redesign · {html.escape(cfg.get("date",""))}</div>
  <h1>Two takes on the dark, card-based redesign</h1>
  <p>{html.escape(cfg.get("intro",""))}</p>
</header>
<nav>{toc}</nav>
<div class="palettes">{palettes}</div>
<main>{"".join(sections)}</main>
<footer>{html.escape(cfg.get("footer",""))}</footer>
"""
out.write_text(page)
print(f"wrote {out} ({out.stat().st_size/1024:.0f} KB)")
