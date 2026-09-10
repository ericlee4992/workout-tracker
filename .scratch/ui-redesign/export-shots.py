#!/usr/bin/env python3
"""Copy xcresult attachment exports into a named folder: <out>/<attachment name>.png.
Usage: export-shots.py <raw-dir-with-manifest.json> <out-dir>"""
import json, shutil, sys, pathlib
raw, out = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)
manifest = json.load(open(raw / "manifest.json"))
count = 0
def walk(node):
    global count
    if isinstance(node, dict):
        if "exportedFileName" in node:
            name = node.get("suggestedHumanReadableName") or node.get("name") or node["exportedFileName"]
            base = name.split("_")[0] if name.startswith("redesign") or name.startswith("codex") else pathlib.Path(name).stem
            shutil.copy(raw / node["exportedFileName"], out / f"{base}.png"); count += 1
        for v in node.values(): walk(v)
    elif isinstance(node, list):
        for v in node: walk(v)
walk(manifest)
print(f"{count} screenshots -> {out}")
